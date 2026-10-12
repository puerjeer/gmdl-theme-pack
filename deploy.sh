#!/usr/bin/env bash
# Reversible, fail-closed deployment for the GMDL theme pack.
# Contract: docs/spec/modules/deploy.sh.md
set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_PATH=""
NGINX_MAIN_CONF="${NGINX_MAIN_CONF:-}"
NGINX_PREFIX="${NGINX_PREFIX:-}"
NGINX_BIN="${NGINX_BIN:-nginx}"
RELOAD_CMD="${RELOAD_CMD:-}"
REPO_DIR="${SCRIPT_DIR}"
BRANCH="main"
DRY_RUN=0
PREFIX_SET=0
RELOAD_ARGS=()
CUSTOM_RELOAD_ARGS=0
PRE_HEAD=""
PULLED_HEAD=""
BACKUP_PATH=""
TMP_CONFIG=""
RESTORE_TMP=""
LOCK_TARGET=""
LOCK_FD=""
LOCK_HELD=0
ORIGINAL_META=""
NGINX_ARGS=()

usage() {
  cat <<'USAGE'
Usage: bash deploy.sh --config <absolute-vhost.conf> --nginx-main-conf <absolute-nginx.conf> [options]

Required:
  -c, --config PATH             Existing absolute active vhost configuration
  -m, --nginx-main-conf PATH    Existing assembled Nginx/OpenResty main config
Options:
  -p, --nginx-prefix PATH       Optional Nginx prefix (empty means omit -p)
  -b, --branch NAME             Fast-forward branch (default: main)
  -d, --repo-dir PATH           Git repository (default: this script's repository)
  -x, --nginx-bin PATH          Syntax-test executable (default: NGINX_BIN or nginx)
  -r, --reload-cmd PATH         Reload executable (default: --nginx-bin)
  -a, --reload-arg ARG          Repeatable reload argument (default: -s reload)
  -n, --dry-run                 Validate and report without pull, backup, config write, or reload
  -h, --help                    Show this help
USAGE
}

usage_error() {
  printf 'ERROR: %s\n' "$1" >&2
  usage >&2
  exit 2
}

while (($#)); do
  case "$1" in
    -c|--config) (($# >= 2)) || usage_error "missing value for $1"; CONFIG_PATH="$2"; shift 2 ;;
    -m|--nginx-main-conf) (($# >= 2)) || usage_error "missing value for $1"; NGINX_MAIN_CONF="$2"; shift 2 ;;
    -p|--nginx-prefix) (($# >= 2)) || usage_error "missing value for $1"; NGINX_PREFIX="$2"; PREFIX_SET=1; shift 2 ;;
    -b|--branch) (($# >= 2)) || usage_error "missing value for $1"; BRANCH="$2"; shift 2 ;;
    -d|--repo-dir) (($# >= 2)) || usage_error "missing value for $1"; REPO_DIR="$2"; shift 2 ;;
    -x|--nginx-bin) (($# >= 2)) || usage_error "missing value for $1"; NGINX_BIN="$2"; shift 2 ;;
    -r|--reload-cmd) (($# >= 2)) || usage_error "missing value for $1"; RELOAD_CMD="$2"; shift 2 ;;
    -a|--reload-arg) (($# >= 2)) || usage_error "missing value for $1"; RELOAD_ARGS+=("$2"); CUSTOM_RELOAD_ARGS=1; shift 2 ;;
    -n|--dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage_error "unknown option: $1" ;;
  esac
done

if [[ -z "${RELOAD_CMD}" ]]; then RELOAD_CMD="${NGINX_BIN}"; fi
if ((CUSTOM_RELOAD_ARGS == 0)); then RELOAD_ARGS=(-s reload); fi

exit_handler() {
  local rc=$?
  trap - EXIT
  if [[ -n "${TMP_CONFIG:-}" && -e "${TMP_CONFIG}" ]]; then rm -f -- "${TMP_CONFIG}" || true; fi
  if [[ -n "${RESTORE_TMP:-}" && -e "${RESTORE_TMP}" ]]; then rm -f -- "${RESTORE_TMP}" || true; fi
  if [[ -n "${LOCK_FD:-}" && "${LOCK_FD}" =~ ^[0-9]+$ ]]; then exec {LOCK_FD}<&- || true; fi
  if ((LOCK_HELD)); then printf 'INFO: deployment lock released: %s\n' "${LOCK_TARGET}" >&2; fi
  exit "${rc}"
}
trap exit_handler EXIT

resolve_executable() {
  local requested="$1" resolved
  if [[ "${requested}" == */* ]]; then
    [[ -x "${requested}" && ! -d "${requested}" ]] || return 1
    realpath -e -- "${requested}"
  else
    resolved="$(command -v -- "${requested}")" || return 1
    [[ -x "${resolved}" && ! -d "${resolved}" ]] || return 1
    printf '%s\n' "${resolved}"
  fi
}

main_includes_target() {
  local main_dir line include_path match resolved include_re quote_char
  include_re="^[[:space:]]*include[[:space:]]+(\"[^\"]+\"|'[^']+'|[^[:space:];]+)[[:space:]]*;[[:space:]]*$"
  main_dir="$(dirname -- "${NGINX_MAIN_CONF}")"
  while IFS= read -r line || [[ -n "${line}" ]]; do
    line="${line%%#*}"
    [[ "${line}" =~ ^[[:space:]]*include[[:space:]]+ ]] || continue
    if [[ ! "${line}" =~ ${include_re} ]]; then
      printf 'ERROR: malformed active include directive in main Nginx config: %s\n' "${line}" >&2
      return 1
    fi
    include_path="${BASH_REMATCH[1]}"
    quote_char="${include_path:0:1}"
    if [[ "${quote_char}" == '"' || "${quote_char}" == "'" ]]; then
      include_path="${include_path:1:${#include_path}-2}"
    fi
    include_path="${include_path#"${include_path%%[![:space:]]*}"}"
    include_path="${include_path%"${include_path##*[![:space:]]}"}"
    [[ -n "${include_path}" ]] || continue
    if [[ "${include_path}" != /* ]]; then include_path="${main_dir}/${include_path}"; fi
    if [[ "${include_path}" == *\** || "${include_path}" == *\?* || "${include_path}" == *\[* ]]; then
      while IFS= read -r match; do
        [[ -n "${match}" ]] || continue
        resolved="$(realpath -m -- "${match}")"
        [[ "${resolved}" == "${CONFIG_PATH}" ]] && return 0
      done < <(compgen -G "${include_path}" || true)
    else
      resolved="$(realpath -m -- "${include_path}")"
      [[ "${resolved}" == "${CONFIG_PATH}" ]] && return 0
    fi
  done < "${NGINX_MAIN_CONF}"
  return 1
}

asset_token_stats() {
  local asset="$1"
  awk -v asset="${asset}" '
    function occurrences(hay, needle,    n, pos, found) {
      n = 0; pos = 1
      while ((found = index(substr(hay, pos), needle)) > 0) {
        n++
        pos += found - 1 + length(needle)
      }
      return n
    }
    {
      line = $0
      sub(/[[:space:]]+#.*/, "", line)
      if (line ~ /^[[:space:]]*#/) next
      if (line !~ /^[[:space:]]*sub_filter[[:space:]]/) next
      mentions += occurrences(line, asset)
      marker = asset "?v="
      pos = 1
      while ((found = index(substr(line, pos), marker)) > 0) {
        start = pos + found - 1
        value_start = start + length(marker)
        tail = substr(line, value_start)
        token_len = 0
        token_count++
        if (match(tail, /^[[:alnum:]_-]+/)) {
          token_len = RLENGTH
          next_char = substr(tail, token_len + 1, 1)
          if (next_char != "" && next_char != "\"" && next_char != ";" && next_char != "\\" && next_char != ">" && next_char != "&" && next_char != " " && next_char != "\t") malformed++
        } else {
          malformed++
        }
        pos = value_start + token_len
      }
    }
    END { printf "%d|%d|%d\n", mentions, token_count, malformed }
  ' "${CONFIG_PATH}"
}

validate_asset_tokens() {
  local asset stats mentions tokens malformed
  for asset in gmdl-dark.css gmdl-ui.js gmdl-feat.js; do
    stats="$(asset_token_stats "${asset}")" || return 1
    IFS='|' read -r mentions tokens malformed <<< "${stats}"
    if [[ "${mentions}" -ne 1 || "${tokens}" -ne 1 || "${malformed}" -ne 0 ]]; then
      printf 'ERROR: expected exactly one valid current sub_filter token for %s; found mentions=%s, version_tokens=%s, malformed=%s\n' "${asset}" "${mentions}" "${tokens}" "${malformed}" >&2
      return 1
    fi
  done
}

calculate_asset_hashes() {
  local asset output digest
  for asset in gmdl-dark.css gmdl-ui.js gmdl-feat.js; do
    [[ -f "${REPO_DIR}/${asset}" && -r "${REPO_DIR}/${asset}" ]] || {
      printf 'ERROR: shipped asset is missing or unreadable: %s\n' "${asset}" >&2
      return 1
    }
    output="$(sha256sum -- "${asset}")" || {
      printf 'ERROR: asset hash computation failed for %s\n' "${asset}" >&2
      return 1
    }
    digest="${output%%[[:space:]]*}"
    [[ "${digest}" =~ ^[0-9a-fA-F]{64}$ ]] || {
      printf 'ERROR: asset hash output is invalid for %s\n' "${asset}" >&2
      return 1
    }
    case "${asset}" in
      gmdl-dark.css) CSS_HASH="${digest:0:8}" ;;
      gmdl-ui.js) UI_HASH="${digest:0:8}" ;;
      gmdl-feat.js) FEAT_HASH="${digest:0:8}" ;;
    esac
  done
}

rewrite_config_to_stage() {
  awk -v css="${CSS_HASH}" -v ui="${UI_HASH}" -v feat="${FEAT_HASH}" '
    function replace_token(line, asset, hash,    marker, pos, found, start, value_start, tail, token_len, out) {
      marker = asset "?v="; pos = 1; out = ""
      while ((found = index(substr(line, pos), marker)) > 0) {
        start = pos + found - 1
        value_start = start + length(marker)
        tail = substr(line, value_start)
        token_len = 0
        if (match(tail, /^[[:alnum:]_-]+/)) token_len = RLENGTH
        out = out substr(line, pos, start - pos + length(marker)) hash
        pos = value_start + token_len
      }
      return out substr(line, pos)
    }
    {
      line = $0
      clean = line
      sub(/[[:space:]]+#.*/, "", clean)
      if (clean ~ /^[[:space:]]*sub_filter[[:space:]]/) {
        line = replace_token(line, "gmdl-dark.css", css)
        line = replace_token(line, "gmdl-ui.js", ui)
        line = replace_token(line, "gmdl-feat.js", feat)
      }
      print line
    }
  ' "${CONFIG_PATH}" > "${TMP_CONFIG}"
}

rollback_and_exit() {
  local reason="$1" status current_head owner_group mode restored_meta
  local rollback_ok=1
  set +e
  printf 'ERROR: %s\n' "${reason}" >&2
  if [[ -z "${BACKUP_PATH}" || ! -f "${BACKUP_PATH}" ]]; then
    printf 'CRITICAL: no preflight backup is available; manual recovery required.\n' >&2
    exit 1
  fi

  RESTORE_TMP="${CONFIG_PATH}.rollback.tmp.$$"
  if ! cp -p -- "${BACKUP_PATH}" "${RESTORE_TMP}"; then
    printf 'CRITICAL: could not stage rollback configuration; manual recovery required.\n' >&2
    exit 1
  fi
  owner_group="${ORIGINAL_META% *}"
  mode="${ORIGINAL_META##* }"
  if ! chown "${owner_group}" "${RESTORE_TMP}" || ! chmod "${mode}" "${RESTORE_TMP}"; then
    printf 'CRITICAL: could not preserve rollback configuration metadata; manual recovery required.\n' >&2
    exit 1
  fi
  if ! cmp -s "${RESTORE_TMP}" "${BACKUP_PATH}"; then
    printf 'CRITICAL: rollback staging bytes differ from backup; manual recovery required.\n' >&2
    exit 1
  fi
  restored_meta="$(stat -c '%u:%g %a' -- "${RESTORE_TMP}")" || exit 1
  if [[ "${restored_meta}" != "${ORIGINAL_META}" ]]; then
    printf 'CRITICAL: rollback staging metadata mismatch; manual recovery required.\n' >&2
    exit 1
  fi
  if ! mv -f -- "${RESTORE_TMP}" "${CONFIG_PATH}"; then
    printf 'CRITICAL: atomic rollback rename failed; manual recovery required.\n' >&2
    exit 1
  fi
  RESTORE_TMP=""
  if ! cmp -s "${CONFIG_PATH}" "${BACKUP_PATH}"; then
    printf 'CRITICAL: restored active configuration differs from backup; manual recovery required.\n' >&2
    exit 1
  fi
  restored_meta="$(stat -c '%u:%g %a' -- "${CONFIG_PATH}")" || exit 1
  if [[ "${restored_meta}" != "${ORIGINAL_META}" ]]; then
    printf 'CRITICAL: restored active configuration metadata mismatch; manual recovery required.\n' >&2
    exit 1
  fi
  printf 'INFO: active configuration restored byte-for-byte from %s\n' "${BACKUP_PATH}" >&2

  if [[ -n "${PULLED_HEAD}" ]]; then
    status="$(GIT_OPTIONAL_LOCKS=0 git status --porcelain 2>&1)"
    if [[ $? -ne 0 ]]; then
      printf 'CRITICAL: refusing automatic reset because post-pull worktree status could not be verified; manual recovery required.\n' >&2
      rollback_ok=0
    elif [[ -n "${status}" ]]; then
      printf 'CRITICAL: refusing automatic reset because post-pull worktree is dirty; manual recovery required.\n' >&2
      rollback_ok=0
    else
      current_head="$(git rev-parse HEAD 2>&1)"
      if [[ $? -ne 0 ]]; then
        printf 'CRITICAL: refusing automatic reset because current HEAD could not be verified; manual recovery required.\n' >&2
        rollback_ok=0
      elif [[ "${current_head}" != "${PULLED_HEAD}" ]]; then
        printf 'CRITICAL: refusing automatic reset because HEAD drift no longer matches PULLED_HEAD; manual recovery required.\n' >&2
        rollback_ok=0
      elif ! git reset --hard "${PRE_HEAD}"; then
        printf 'CRITICAL: git reset to PRE_HEAD failed; manual recovery required.\n' >&2
        rollback_ok=0
      else
        printf 'INFO: clean expected revision reset to PRE_HEAD %s\n' "${PRE_HEAD}" >&2
      fi
    fi
  fi

  NGINX_ARGS=(-t -c "${NGINX_MAIN_CONF}")
  if [[ -n "${NGINX_PREFIX}" ]]; then NGINX_ARGS+=(-p "${NGINX_PREFIX}"); fi
  if ! "${NGINX_BIN}" "${NGINX_ARGS[@]}"; then
    printf 'CRITICAL: restored configuration syntax verification failed; manual recovery required.\n' >&2
    rollback_ok=0
  else
    printf 'INFO: restored assembled configuration passed syntax verification.\n' >&2
  fi
  if ! "${RELOAD_CMD}" "${RELOAD_ARGS[@]}"; then
    printf 'CRITICAL: recovery reload failed; manual recovery required.\n' >&2
    rollback_ok=0
  else
    printf 'INFO: recovery reload completed.\n' >&2
  fi
  if ((rollback_ok)); then
    printf 'INFO: rollback completed safely; deployment exits non-zero.\n' >&2
  else
    printf 'CRITICAL: rollback requires manual follow-up.\n' >&2
  fi
  exit 1
}

# Minimal repository checks are needed to resolve the metadata lock. The lock is
# acquired before examining porcelain status or any deployment input paths.
[[ -d "${REPO_DIR}" ]] || usage_error "repository directory does not exist: ${REPO_DIR}"
REPO_DIR="$(realpath -e -- "${REPO_DIR}")"
cd -- "${REPO_DIR}"
GIT_TOP="$(git rev-parse --show-toplevel 2>/dev/null)" || usage_error "repository directory is not a Git worktree: ${REPO_DIR}"
GIT_TOP="$(realpath -e -- "${GIT_TOP}")"
[[ "${GIT_TOP}" == "${REPO_DIR}" ]] || usage_error "--repo-dir must name the Git worktree root: ${GIT_TOP}"
GIT_DIR="$(git rev-parse --absolute-git-dir 2>/dev/null)" || usage_error "cannot resolve Git metadata directory"
GIT_DIR="$(realpath -e -- "${GIT_DIR}")"
[[ -d "${GIT_DIR}" && "${GIT_DIR}" != "${REPO_DIR}" ]] || usage_error "resolved Git metadata directory is invalid: ${GIT_DIR}"
command -v flock >/dev/null 2>&1 || usage_error "flock is required but not available on PATH"
LOCK_TARGET="${GIT_DIR}"
exec {LOCK_FD}<"${GIT_DIR}"
if ! flock -n "${LOCK_FD}"; then
  printf 'ERROR: deployment lock is already held: %s\n' "${LOCK_TARGET}" >&2
  exit 1
fi
LOCK_HELD=1

if ! PRE_DEPLOY_STATUS="$(GIT_OPTIONAL_LOCKS=0 git status --porcelain)"; then
  printf 'ERROR: unable to verify worktree cleanliness; deployment halted before pull.\n' >&2
  exit 1
fi
if [[ -n "${PRE_DEPLOY_STATUS}" ]]; then
  printf 'ERROR: repository worktree is dirty; deployment halted before pull.\n' >&2
  exit 1
fi

[[ -n "${CONFIG_PATH}" ]] || usage_error "--config is required"
[[ "${CONFIG_PATH}" == /* ]] || usage_error "--config must be an absolute path"
[[ -n "${NGINX_MAIN_CONF}" ]] || usage_error "--nginx-main-conf or NGINX_MAIN_CONF is required"
[[ "${NGINX_MAIN_CONF}" == /* ]] || usage_error "--nginx-main-conf must be an absolute path"
[[ -f "${CONFIG_PATH}" && -r "${CONFIG_PATH}" && -w "${CONFIG_PATH}" ]] || usage_error "config must exist and be readable/writable: ${CONFIG_PATH}"
[[ -f "${NGINX_MAIN_CONF}" && -r "${NGINX_MAIN_CONF}" ]] || usage_error "main Nginx configuration does not exist or is unreadable: ${NGINX_MAIN_CONF}"
CONFIG_PATH="$(realpath -e -- "${CONFIG_PATH}")"
NGINX_MAIN_CONF="$(realpath -e -- "${NGINX_MAIN_CONF}")"
[[ -w "$(dirname -- "${CONFIG_PATH}")" ]] || usage_error "config directory is not writable: $(dirname -- "${CONFIG_PATH}")"
if ! main_includes_target; then
  printf 'ERROR: main Nginx config %s does not include target vhost %s.\n' "${NGINX_MAIN_CONF}" "${CONFIG_PATH}" >&2
  exit 1
fi

[[ "${BRANCH}" != "" ]] || usage_error "branch name cannot be empty"
git check-ref-format --branch "${BRANCH}" >/dev/null 2>&1 || usage_error "invalid Git branch name: ${BRANCH}"
git show-ref --verify --quiet "refs/heads/${BRANCH}" || usage_error "target branch does not exist locally: ${BRANCH}"
NGINX_BIN="$(resolve_executable "${NGINX_BIN}")" || usage_error "nginx syntax-test executable is not executable or on PATH"
RELOAD_CMD="$(resolve_executable "${RELOAD_CMD}")" || usage_error "reload executable is not executable or on PATH"
command -v sha256sum >/dev/null 2>&1 || usage_error "sha256sum is required but not available on PATH"
PRE_HEAD="$(git rev-parse HEAD)"
ORIGINAL_META="$(stat -c '%u:%g %a' -- "${CONFIG_PATH}")"

if ((DRY_RUN)); then
  if ! calculate_asset_hashes || ! validate_asset_tokens; then
    printf 'ERROR: dry-run validation failed; no pull, backup, configuration write, or reload was performed.\n' >&2
    exit 1
  fi
  printf 'DRY-RUN: preflight passed for branch %s at %s; asset tokens and assembled config inputs are valid.\n' "${BRANCH}" "${PRE_HEAD}"
  printf 'DRY-RUN: no pull, backup, configuration replacement, lock file, or service reload was performed.\n'
  exit 0
fi

BACKUP_PATH="${CONFIG_PATH}.bak.$(date +%Y%m%d%H%M%S).$$"
if ! cp -p -- "${CONFIG_PATH}" "${BACKUP_PATH}"; then
  printf 'ERROR: failed to create timestamped configuration backup: %s\n' "${BACKUP_PATH}" >&2
  exit 1
fi
printf 'INFO: preflight backup created: %s\n' "${BACKUP_PATH}"

# Step 1: fast-forward pull and immediately capture the pulled revision.
if ! git pull --ff-only origin "${BRANCH}"; then
  printf 'ERROR: git pull --ff-only failed; active config left unchanged and no Git reset was performed.\n' >&2
  exit 1
fi
if ! PULLED_HEAD="$(git rev-parse HEAD)" || [[ -z "${PULLED_HEAD}" ]]; then
  printf 'ERROR: pull succeeded but PULLED_HEAD could not be verified; active config remains unchanged. Manual repository review is required; no reset was attempted.\n' >&2
  exit 1
fi
printf 'INFO: PULLED_HEAD recorded immediately after pull: %s\n' "${PULLED_HEAD}"

# Step 2: hash all three shipped assets.
if ! calculate_asset_hashes; then
  rollback_and_exit "asset hash computation failed; starting safe rollback"
fi

# Step 3: validate exact current token cardinality, then stage in the vhost dir.
if ! validate_asset_tokens; then
  rollback_and_exit "sub_filter asset token cardinality validation failed; starting safe rollback"
fi
TMP_CONFIG="${CONFIG_PATH}.tmp.$$"
if ! rewrite_config_to_stage; then
  rollback_and_exit "failed to generate staged vhost configuration; starting safe rollback"
fi
if ! chown "${ORIGINAL_META% *}" "${TMP_CONFIG}" || ! chmod "${ORIGINAL_META##* }" "${TMP_CONFIG}"; then
  rollback_and_exit "failed to preserve owner/group/mode on staged vhost configuration"
fi
STAGED_META="$(stat -c '%u:%g %a' -- "${TMP_CONFIG}")" || rollback_and_exit "could not verify staged configuration metadata"
if [[ "${STAGED_META}" != "${ORIGINAL_META}" ]]; then
  rollback_and_exit "staged configuration metadata differs from original"
fi
if ! mv -f -- "${TMP_CONFIG}" "${CONFIG_PATH}"; then
  rollback_and_exit "atomic same-directory vhost replacement failed"
fi
TMP_CONFIG=""
printf 'INFO: vhost asset tokens updated atomically in %s\n' "${CONFIG_PATH}"

# Step 4: test the assembled main configuration with a safe argument array.
NGINX_ARGS=(-t -c "${NGINX_MAIN_CONF}")
if [[ -n "${NGINX_PREFIX}" ]]; then NGINX_ARGS+=(-p "${NGINX_PREFIX}"); fi
if ! "${NGINX_BIN}" "${NGINX_ARGS[@]}"; then
  rollback_and_exit "assembled Nginx configuration syntax test failed; starting safe rollback"
fi

# Step 5: reload with an executable and array-only argument passing.
if ! "${RELOAD_CMD}" "${RELOAD_ARGS[@]}"; then
  rollback_and_exit "service reload failed; starting safe rollback"
fi

printf 'INFO: deployment succeeded for branch %s at %s.\n' "${BRANCH}" "${PULLED_HEAD}"
