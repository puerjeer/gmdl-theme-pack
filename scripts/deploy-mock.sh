#!/usr/bin/env bash
# ==============================================================================
# scripts/deploy-mock.sh — Offline Deterministic Mock Test Harness for deploy.sh
# Project: gmdl-theme-pack-agent · Branch: project/antigravity-overhaul
# Canonical Contracts:
#   - docs/spec/modules/deploy.sh.md
#   - docs/project/07-quality-test-plan.md (§3.1 MOCK-01..MOCK-12)
#
# Executes 12 isolated, offline behavioral test cases (MOCK-01 through MOCK-12)
# using temporary local Git repositories, temporary OpenResty/Nginx config files,
# and PATH-instrumented wrapper binaries. Never touches network, SSH, sudo, or
# host configurations. Cleans all temporary directories on EXIT.
# ==============================================================================

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DEPLOY_SCRIPT="${REPO_ROOT}/deploy.sh"
ORIG_PATH="${PATH}"

MASTER_TMP="$(mktemp -d "${TMPDIR:-/tmp}/gmdl-deploy-mock.XXXXXX")"

cleanup_all() {
  if [[ -n "${MASTER_TMP:-}" && -d "${MASTER_TMP}" ]]; then
    rm -rf "${MASTER_TMP}"
  fi
}
trap cleanup_all EXIT

TOTAL_CASES=0
PASS_CASES=0
FAIL_CASES=0
declare -a CASE_RESULTS=()

record_pass() {
  local id="$1"
  local desc="$2"
  TOTAL_CASES=$((TOTAL_CASES + 1))
  PASS_CASES=$((PASS_CASES + 1))
  CASE_RESULTS+=("PASS | ${id} | ${desc}")
  printf 'PASS [%s]: %s\n' "${id}" "${desc}"
}

record_fail() {
  local id="$1"
  local desc="$2"
  local reason="$3"
  TOTAL_CASES=$((TOTAL_CASES + 1))
  FAIL_CASES=$((FAIL_CASES + 1))
  CASE_RESULTS+=("FAIL | ${id} | ${desc} — ${reason}")
  printf 'FAIL [%s]: %s (%s)\n' "${id}" "${desc}" "${reason}"
}

# ------------------------------------------------------------------------------
# Sandbox Builder: Creates isolated bare origin, worktree clone, vhost/main
# configs, and instrumented PATH wrappers in $SANDBOX_DIR.
# ------------------------------------------------------------------------------
setup_sandbox() {
  local case_id="$1"
  SANDBOX_DIR="${MASTER_TMP}/${case_id}"
  mkdir -p "${SANDBOX_DIR}/bin" "${SANDBOX_DIR}/etc/conf.d"

  MOCK_EVENT_LOG="${SANDBOX_DIR}/events.log"
  : > "${MOCK_EVENT_LOG}"

  MOCK_REAL_GIT="$(command -v git)"
  MOCK_REAL_FLOCK="$(command -v flock)"
  MOCK_REAL_SHA256SUM="$(command -v sha256sum)"
  MOCK_REAL_MV="$(command -v mv)"
  MOCK_REAL_CMP="$(command -v cmp)"
  MOCK_REAL_STAT="$(command -v stat)"
  MOCK_REAL_CHOWN="$(command -v chown)"
  MOCK_REAL_CHMOD="$(command -v chmod)"

  # 1. Create instrumented git wrapper
  cat > "${SANDBOX_DIR}/bin/git" <<'EOF'
#!/usr/bin/env bash
echo "GIT|$*" >> "${MOCK_EVENT_LOG}"

if [[ "${1:-}" == "pull" ]]; then
  echo "STEP1_PULL|$*" >> "${MOCK_EVENT_LOG}"
  if [[ "${MOCK_FAIL_PULL:-0}" == "1" ]]; then
    echo "mock git pull failure injected" >&2
    exit 1
  fi
  "${MOCK_REAL_GIT}" "$@"
  rc=$?
  if [[ $rc -eq 0 ]]; then
    echo "1" > "${SANDBOX_DIR}/pull_done"
  fi
  exit $rc
fi

if [[ "${1:-}" == "rev-parse" && "${2:-}" == "--absolute-git-dir" ]]; then
  echo "GIT_DIR|$*" >> "${MOCK_EVENT_LOG}"
  out="$("${MOCK_REAL_GIT}" "$@")"
  rc=$?
  echo "GIT_DIR_RESULT|${out}" >> "${MOCK_EVENT_LOG}"
  printf '%s\n' "${out}"
  exit $rc
fi

if [[ "${1:-}" == "rev-parse" && "${2:-}" == "HEAD" ]]; then
  if [[ -f "${SANDBOX_DIR}/pull_done" && ! -f "${SANDBOX_DIR}/pulled_head_recorded" && "${MOCK_FAIL_PULLED_HEAD:-0}" == "1" ]]; then
    echo "REV_PARSE_HEAD_FAILURE" >> "${MOCK_EVENT_LOG}"
    echo "mock pulled HEAD capture failure injected" >&2
    exit 73
  fi
  out="$("${MOCK_REAL_GIT}" "$@")"
  rc=$?
  echo "REV_PARSE_HEAD|${out}" >> "${MOCK_EVENT_LOG}"
  printf '%s\n' "${out}"
  if [[ -f "${SANDBOX_DIR}/pull_done" && ! -f "${SANDBOX_DIR}/pulled_head_recorded" ]]; then
    echo "1" > "${SANDBOX_DIR}/pulled_head_recorded"
    if [[ "${MOCK_AFTER_PULLED_HEAD_DIRTY:-0}" == "1" ]]; then
      echo "dirty-after-pull" > "${PWD}/untracked-post-pull.txt"
    fi
    if [[ "${MOCK_AFTER_PULLED_HEAD_DRIFT:-0}" == "1" ]]; then
      "${MOCK_REAL_GIT}" commit --allow-empty -m "post-pull drift commit" >/dev/null 2>&1
    fi
  fi
  exit $rc
fi

if [[ "${1:-}" == "reset" ]]; then
  echo "GIT_RESET|$*" >> "${MOCK_EVENT_LOG}"
  "${MOCK_REAL_GIT}" "$@"
  exit $?
fi

if [[ "${1:-}" == "status" && "${2:-}" == "--porcelain" ]]; then
  echo "GIT_STATUS_OPTIONAL_LOCKS|${GIT_OPTIONAL_LOCKS:-unset}" >> "${MOCK_EVENT_LOG}"
  if [[ "${MOCK_FAIL_STATUS:-0}" == "1" ]]; then
    echo "GIT_STATUS_FAILURE" >> "${MOCK_EVENT_LOG}"
    echo "mock git status failure injected" >&2
    exit 71
  fi
  out="$("${MOCK_REAL_GIT}" "$@")"
  rc=$?
  if [[ -z "${out}" ]]; then
    echo "GIT_STATUS_CLEAN" >> "${MOCK_EVENT_LOG}"
  else
    echo "GIT_STATUS_DIRTY" >> "${MOCK_EVENT_LOG}"
  fi
  printf '%s' "${out}"
  exit $rc
fi

"${MOCK_REAL_GIT}" "$@"
EOF
  chmod +x "${SANDBOX_DIR}/bin/git"

  # 2. Create instrumented sha256sum wrapper
  cat > "${SANDBOX_DIR}/bin/sha256sum" <<'EOF'
#!/usr/bin/env bash
echo "STEP2_HASH|$*" >> "${MOCK_EVENT_LOG}"
if [[ "${MOCK_FAIL_HASH:-0}" == "1" ]]; then
  echo "mock sha256sum failure injected" >&2
  exit 1
fi
"${MOCK_REAL_SHA256SUM}" "$@"
EOF
  chmod +x "${SANDBOX_DIR}/bin/sha256sum"

  # 3. Create instrumented cmp wrapper
  cat > "${SANDBOX_DIR}/bin/cmp" <<'EOF'
#!/usr/bin/env bash
echo "CMP|$*" >> "${MOCK_EVENT_LOG}"
"${MOCK_REAL_CMP}" "$@"
EOF
  chmod +x "${SANDBOX_DIR}/bin/cmp"

  # 4. Create instrumented chown & chmod wrappers
  cat > "${SANDBOX_DIR}/bin/chown" <<'EOF'
#!/usr/bin/env bash
echo "CHOWN|$*" >> "${MOCK_EVENT_LOG}"
"${MOCK_REAL_CHOWN}" "$@"
EOF
  chmod +x "${SANDBOX_DIR}/bin/chown"

  cat > "${SANDBOX_DIR}/bin/chmod" <<'EOF'
#!/usr/bin/env bash
echo "CHMOD|$*" >> "${MOCK_EVENT_LOG}"
"${MOCK_REAL_CHMOD}" "$@"
EOF
  chmod +x "${SANDBOX_DIR}/bin/chmod"

  # 5. Create instrumented mv wrapper
  cat > "${SANDBOX_DIR}/bin/mv" <<'EOF'
#!/usr/bin/env bash
args=()
for a in "$@"; do
  if [[ "$a" != -* ]]; then
    args+=("$a")
  fi
done
src="${args[0]:-}"
dst="${args[1]:-}"
meta=""
if [[ -n "$src" && -e "$src" ]]; then
  meta="$("${MOCK_REAL_STAT}" -c '%u:%g %a' "$src" 2>/dev/null || true)"
fi
echo "MV|${src}|${dst}|${meta}" >> "${MOCK_EVENT_LOG}"
  "${MOCK_REAL_MV}" "$@"
EOF
  chmod +x "${SANDBOX_DIR}/bin/mv"

  # 6. Create instrumented flock wrapper; resolve an FD lock back to its target.
  cat > "${SANDBOX_DIR}/bin/flock" <<'EOF'
#!/usr/bin/env bash
lock_target=""
for arg in "$@"; do
  if [[ "$arg" =~ ^[0-9]+$ ]]; then
    candidate="$(readlink "/proc/${PPID}/fd/${arg}" 2>/dev/null || true)"
    if [[ -n "$candidate" ]]; then
      lock_target="$(realpath -m -- "$candidate")"
      break
    fi
  elif [[ -d "$arg" ]]; then
    lock_target="$(realpath -m -- "$arg")"
    break
  fi
done
echo "FLOCK_PATH|${lock_target}|$*" >> "${MOCK_EVENT_LOG}"
exec "${MOCK_REAL_FLOCK}" "$@"
EOF
  chmod +x "${SANDBOX_DIR}/bin/flock"

  # 6. Create mock-nginx binary
  cat > "${SANDBOX_DIR}/bin/mock-nginx" <<'EOF'
#!/usr/bin/env bash
has_t=0
has_s_reload=0
for ((i=1; i<=$#; i++)); do
  arg="${!i}"
  if [[ "$arg" == "-t" ]]; then
    has_t=1
  fi
  if [[ "$arg" == "reload" ]]; then
    has_s_reload=1
  fi
done

if [[ $has_t -eq 1 ]]; then
  cnt=0
  if [[ -f "${SANDBOX_DIR}/nginx_t_count" ]]; then
    cnt="$(cat "${SANDBOX_DIR}/nginx_t_count")"
  fi
  cnt=$((cnt + 1))
  echo "$cnt" > "${SANDBOX_DIR}/nginx_t_count"
  echo "STEP4_NGINX_T|${cnt}|$#|$*" >> "${MOCK_EVENT_LOG}"
  : > "${SANDBOX_DIR}/nginx_t_argv_${cnt}.log"
  idx=0
  for a in "$@"; do
    printf 'ARG[%d]=%s\n' "$idx" "$a" >> "${SANDBOX_DIR}/nginx_t_argv_${cnt}.log"
    idx=$((idx + 1))
  done
  if [[ "${MOCK_FAIL_NGINX_T:-0}" == "1" && $cnt -eq 1 ]]; then
    echo "nginx: [emerg] simulated syntax validation failure" >&2
    exit 1
  fi
  exit 0
fi

if [[ $has_s_reload -eq 1 ]]; then
  cnt=0
  if [[ -f "${SANDBOX_DIR}/reload_count" ]]; then
    cnt="$(cat "${SANDBOX_DIR}/reload_count")"
  fi
  cnt=$((cnt + 1))
  echo "$cnt" > "${SANDBOX_DIR}/reload_count"
  echo "STEP5_RELOAD|${cnt}|$#|$*" >> "${MOCK_EVENT_LOG}"
  : > "${SANDBOX_DIR}/reload_argv_${cnt}.log"
  idx=0
  for a in "$@"; do
    printf 'ARG[%d]=%s\n' "$idx" "$a" >> "${SANDBOX_DIR}/reload_argv_${cnt}.log"
    idx=$((idx + 1))
  done
  if [[ "${MOCK_FAIL_FIRST_RELOAD:-0}" == "1" && $cnt -eq 1 ]]; then
    echo "nginx: [emerg] simulated reload failure" >&2
    exit 1
  fi
  exit 0
fi

echo "NGINX_OTHER|$#|$*" >> "${MOCK_EVENT_LOG}"
exit 0
EOF
  chmod +x "${SANDBOX_DIR}/bin/mock-nginx"

  # 7. Create mock-systemctl binary for custom multi-arg reload testing
  cat > "${SANDBOX_DIR}/bin/mock-systemctl" <<'EOF'
#!/usr/bin/env bash
cnt=0
if [[ -f "${SANDBOX_DIR}/reload_count" ]]; then
  cnt="$(cat "${SANDBOX_DIR}/reload_count")"
fi
cnt=$((cnt + 1))
echo "$cnt" > "${SANDBOX_DIR}/reload_count"
echo "STEP5_RELOAD|${cnt}|$#|$*" >> "${MOCK_EVENT_LOG}"
: > "${SANDBOX_DIR}/reload_argv_${cnt}.log"
idx=0
for a in "$@"; do
  printf 'ARG[%d]=%s\n' "$idx" "$a" >> "${SANDBOX_DIR}/reload_argv_${cnt}.log"
  idx=$((idx + 1))
done
if [[ "${MOCK_FAIL_FIRST_RELOAD:-0}" == "1" && $cnt -eq 1 ]]; then
  echo "systemctl: simulated reload failure" >&2
  exit 1
fi
exit 0
EOF
  chmod +x "${SANDBOX_DIR}/bin/mock-systemctl"

  # 8. Initialize bare origin repo and local clone worktree
  ORIGIN_REPO="${SANDBOX_DIR}/origin.git"
  SEED_REPO="${SANDBOX_DIR}/seed"
  WORK_REPO="${SANDBOX_DIR}/work"

  "${MOCK_REAL_GIT}" init --bare -q "${ORIGIN_REPO}"
  "${MOCK_REAL_GIT}" init -q "${SEED_REPO}"
  "${MOCK_REAL_GIT}" -C "${SEED_REPO}" config user.email "test@example.local"
  "${MOCK_REAL_GIT}" -C "${SEED_REPO}" config user.name "Mock Tester"
  "${MOCK_REAL_GIT}" -C "${SEED_REPO}" checkout -q -b main

  printf '/* initial dark css v1 */\nbody { color: #111; }\n' > "${SEED_REPO}/gmdl-dark.css"
  printf '/* initial ui js v1 */\nconsole.log("ui v1");\n' > "${SEED_REPO}/gmdl-ui.js"
  printf '/* initial feat js v1 */\nconsole.log("feat v1");\n' > "${SEED_REPO}/gmdl-feat.js"

  "${MOCK_REAL_GIT}" -C "${SEED_REPO}" add gmdl-dark.css gmdl-ui.js gmdl-feat.js
  "${MOCK_REAL_GIT}" -C "${SEED_REPO}" commit -q -m "initial baseline commit"
  "${MOCK_REAL_GIT}" -C "${SEED_REPO}" remote add origin "${ORIGIN_REPO}"
  "${MOCK_REAL_GIT}" -C "${SEED_REPO}" push -q -u origin main

  # Clone worktree at PRE_HEAD
  "${MOCK_REAL_GIT}" clone -q -b main "${ORIGIN_REPO}" "${WORK_REPO}"
  "${MOCK_REAL_GIT}" -C "${WORK_REPO}" config user.email "deploy@example.local"
  "${MOCK_REAL_GIT}" -C "${WORK_REPO}" config user.name "Deploy Runner"
  EXPECTED_PRE_HEAD="$("${MOCK_REAL_GIT}" -C "${WORK_REPO}" rev-parse HEAD)"

  # Push an upstream release commit to origin so git pull --ff-only advances HEAD
  printf '/* updated dark css v2 */\nbody { color: #222; }\n' > "${SEED_REPO}/gmdl-dark.css"
  printf '/* updated ui js v2 */\nconsole.log("ui v2");\n' > "${SEED_REPO}/gmdl-ui.js"
  printf '/* updated feat js v2 */\nconsole.log("feat v2");\n' > "${SEED_REPO}/gmdl-feat.js"
  "${MOCK_REAL_GIT}" -C "${SEED_REPO}" add gmdl-dark.css gmdl-ui.js gmdl-feat.js
  "${MOCK_REAL_GIT}" -C "${SEED_REPO}" commit -q -m "release v2 assets"
  "${MOCK_REAL_GIT}" -C "${SEED_REPO}" push -q origin main
  EXPECTED_PULLED_HEAD="$("${MOCK_REAL_GIT}" -C "${SEED_REPO}" rev-parse HEAD)"

  EXPECTED_CSS_HASH="$("${MOCK_REAL_SHA256SUM}" "${SEED_REPO}/gmdl-dark.css" | cut -c1-8)"
  EXPECTED_UI_HASH="$("${MOCK_REAL_SHA256SUM}" "${SEED_REPO}/gmdl-ui.js" | cut -c1-8)"
  EXPECTED_FEAT_HASH="$("${MOCK_REAL_SHA256SUM}" "${SEED_REPO}/gmdl-feat.js" | cut -c1-8)"

  # 9. Create temporary vhost config and main nginx.conf
  VHOST_CONF="${SANDBOX_DIR}/etc/conf.d/music.vhost.conf"
  MAIN_CONF="${SANDBOX_DIR}/etc/nginx.conf"

  cat > "${VHOST_CONF}" <<'EOF'
server {
    listen 443 ssl;
    server_name music.archfox.eu.cc;
    location / {
        proxy_pass http://127.0.0.1:9981;
        expires -1;
        proxy_set_header Accept-Encoding "";
        sub_filter "</head>" "<link rel=\"stylesheet\" href=\"/gmdl-dark.css?v=12\"><script src=\"/gmdl-ui.js?v=10\" defer></script><script src=\"/gmdl-feat.js?v=2\" defer></script></head>";
        sub_filter_once on;
    }
}
EOF
  cp -p "${VHOST_CONF}" "${SANDBOX_DIR}/vhost.orig.snapshot"

  cat > "${MAIN_CONF}" <<EOF
worker_processes 1;
http {
    include ${VHOST_CONF};
}
EOF

  MOCK_NGINX="${SANDBOX_DIR}/bin/mock-nginx"
  MOCK_SYSTEMCTL="${SANDBOX_DIR}/bin/mock-systemctl"
  : > "${MOCK_EVENT_LOG}"
}

create_no_sha256sum_path() {
  local path_dir="${SANDBOX_DIR}/bin-no-sha256sum"
  local tool source_path
  local tools=(bash cat chmod chown cmp cp date dirname awk flock git grep head mktemp mv readlink realpath rm sed stat tail touch)
  mkdir -p "${path_dir}"
  for tool in "${tools[@]}"; do
    if [[ -x "${SANDBOX_DIR}/bin/${tool}" ]]; then
      source_path="${SANDBOX_DIR}/bin/${tool}"
    else
      source_path="$(command -v "${tool}")"
    fi
    [[ -n "${source_path}" && -x "${source_path}" ]] || { printf 'ERROR: missing helper command for no-sha256sum test PATH: %s\n' "${tool}" >&2; return 1; }
    ln -s -- "${source_path}" "${path_dir}/${tool}"
  done
}

run_deploy_in_sandbox() {
  if [[ ! -f "${DEPLOY_SCRIPT}" ]]; then
    return 127
  fi
  local deploy_path="${SANDBOX_DIR}/bin:${ORIG_PATH}"
  if [[ "${MOCK_NO_SHA256SUM:-0}" == "1" ]]; then
    deploy_path="${SANDBOX_DIR}/bin-no-sha256sum"
  fi
  MOCK_DEPLOY_OUT="${SANDBOX_DIR}/deploy_output.log"
  : > "${MOCK_DEPLOY_OUT}"
  env \
    -u NGINX_PREFIX \
    -u NGINX_MAIN_CONF \
    -u NGINX_BIN \
    -u RELOAD_CMD \
    -u RELOAD_ARGS \
    -u CONFIG_PATH \
    -u BRANCH \
    -u REPO_DIR \
    PATH="${deploy_path}" \
    SANDBOX_DIR="${SANDBOX_DIR}" \
    MOCK_EVENT_LOG="${MOCK_EVENT_LOG}" \
    MOCK_REAL_GIT="${MOCK_REAL_GIT}" \
    MOCK_REAL_FLOCK="${MOCK_REAL_FLOCK}" \
    MOCK_REAL_SHA256SUM="${MOCK_REAL_SHA256SUM}" \
    MOCK_REAL_MV="${MOCK_REAL_MV}" \
    MOCK_REAL_CMP="${MOCK_REAL_CMP}" \
    MOCK_REAL_STAT="${MOCK_REAL_STAT}" \
    MOCK_REAL_CHOWN="${MOCK_REAL_CHOWN}" \
    MOCK_REAL_CHMOD="${MOCK_REAL_CHMOD}" \
    MOCK_FAIL_PULL="${MOCK_FAIL_PULL:-0}" \
    MOCK_FAIL_PULLED_HEAD="${MOCK_FAIL_PULLED_HEAD:-0}" \
    MOCK_FAIL_STATUS="${MOCK_FAIL_STATUS:-0}" \
    MOCK_FAIL_HASH="${MOCK_FAIL_HASH:-0}" \
    MOCK_FAIL_NGINX_T="${MOCK_FAIL_NGINX_T:-0}" \
    MOCK_FAIL_FIRST_RELOAD="${MOCK_FAIL_FIRST_RELOAD:-0}" \
    MOCK_AFTER_PULLED_HEAD_DIRTY="${MOCK_AFTER_PULLED_HEAD_DIRTY:-0}" \
    MOCK_AFTER_PULLED_HEAD_DRIFT="${MOCK_AFTER_PULLED_HEAD_DRIFT:-0}" \
    bash "${DEPLOY_SCRIPT}" "$@" >"${MOCK_DEPLOY_OUT}" 2>&1
}

require_deploy_script() {
  local id="$1"
  local desc="$2"
  if [[ ! -f "${DEPLOY_SCRIPT}" ]]; then
    record_fail "${id}" "${desc}" "deploy.sh not found at ${DEPLOY_SCRIPT}"
    return 1
  fi
  return 0
}

git_metadata_lock_path() {
  "${MOCK_REAL_GIT}" -C "${WORK_REPO}" rev-parse --absolute-git-dir
}

# ==============================================================================
# MOCK-01: Full Success Path in Exact 5-Step Order
# ==============================================================================
test_mock_01() {
  local id="MOCK-01"
  local desc="Full Success Path in Exact 5-Step Order (pull+PULLED_HEAD -> hash -> atomic config -> nginx -t -> reload)"
  require_deploy_script "${id}" "${desc}" || return

  setup_sandbox "${id}"
  run_deploy_in_sandbox \
    --config "${VHOST_CONF}" \
    --nginx-main-conf "${MAIN_CONF}" \
    --repo-dir "${WORK_REPO}" \
    --branch main \
    --nginx-bin "${MOCK_NGINX}"
  local rc=$?
  if [[ $rc -ne 0 ]]; then
    record_fail "${id}" "${desc}" "expected exit 0, got ${rc}"
    return
  fi

  local line_pull line_pulled_head line_hash line_hash_last line_mv line_t line_reload
  line_pull="$(grep -n '^STEP1_PULL|' "${MOCK_EVENT_LOG}" | head -n1 | cut -d: -f1)"
  line_pulled_head="$(grep -n "^REV_PARSE_HEAD|${EXPECTED_PULLED_HEAD}$" "${MOCK_EVENT_LOG}" | head -n1 | cut -d: -f1)"
  line_hash="$(grep -n '^STEP2_HASH|' "${MOCK_EVENT_LOG}" | head -n1 | cut -d: -f1)"
  line_hash_last="$(grep -n '^STEP2_HASH|' "${MOCK_EVENT_LOG}" | tail -n1 | cut -d: -f1)"
  line_mv="$(grep -n "^MV|${VHOST_CONF}\.tmp\.[0-9]*|${VHOST_CONF}|" "${MOCK_EVENT_LOG}" | head -n1 | cut -d: -f1)"
  line_t="$(grep -n '^STEP4_NGINX_T|1|' "${MOCK_EVENT_LOG}" | head -n1 | cut -d: -f1)"
  line_reload="$(grep -n '^STEP5_RELOAD|1|' "${MOCK_EVENT_LOG}" | head -n1 | cut -d: -f1)"

  if [[ -z "$line_pull" || -z "$line_pulled_head" || -z "$line_hash" || -z "$line_hash_last" || -z "$line_mv" || -z "$line_t" || -z "$line_reload" ]]; then
    record_fail "${id}" "${desc}" "missing one or more of the 5 core deployment events in event log"
    return
  fi

  if ! (( line_pull < line_pulled_head && line_pulled_head < line_hash && line_hash_last < line_mv && line_mv < line_t && line_t < line_reload )); then
    record_fail "${id}" "${desc}" "events out of order: pull=${line_pull} head=${line_pulled_head} hash=${line_hash} mv=${line_mv} t=${line_t} reload=${line_reload}"
    return
  fi

  if ! grep -Fqx 'STEP1_PULL|pull --ff-only origin main' "${MOCK_EVENT_LOG}" ||
     [[ "$(grep -c '^STEP1_PULL|' "${MOCK_EVENT_LOG}")" -ne 1 || "$(grep -c '^STEP2_HASH|' "${MOCK_EVENT_LOG}")" -ne 3 || "$(grep -c '^STEP4_NGINX_T|' "${MOCK_EVENT_LOG}")" -ne 1 || "$(grep -c '^STEP5_RELOAD|' "${MOCK_EVENT_LOG}")" -ne 1 || "$(grep -c "^MV|${VHOST_CONF}\.tmp\." "${MOCK_EVENT_LOG}")" -ne 1 ]] ||
     grep -q '^GIT_RESET|' "${MOCK_EVENT_LOG}"; then
    record_fail "${id}" "${desc}" "success path did not use the exact pull argv and one-and-only expected core events"
    return
  fi

  local backup_files=()
  while IFS= read -r -d '' backup; do backup_files+=("${backup}"); done < <(find "$(dirname "${VHOST_CONF}")" -maxdepth 1 -type f -name "$(basename "${VHOST_CONF}").bak.*" -print0)
  if [[ "${#backup_files[@]}" -ne 1 ]] || ! "${MOCK_REAL_CMP}" -s "${backup_files[0]:-}" "${SANDBOX_DIR}/vhost.orig.snapshot"; then
    record_fail "${id}" "${desc}" "expected one byte-exact timestamped preflight backup"
    return
  fi

  local expected_reload_argv=$'ARG[0]=-s\nARG[1]=reload'
  if [[ ! -f "${SANDBOX_DIR}/reload_argv_1.log" || "$(cat "${SANDBOX_DIR}/reload_argv_1.log")" != "${expected_reload_argv}" ]]; then
    record_fail "${id}" "${desc}" "default reload argument vector was not exactly [-s, reload]"
    return
  fi

  local c_css c_ui c_feat tok_css tok_ui tok_feat val_css val_ui val_feat
  c_css="$(grep -o 'gmdl-dark\.css' "${VHOST_CONF}" | wc -l)"
  c_ui="$(grep -o 'gmdl-ui\.js' "${VHOST_CONF}" | wc -l)"
  c_feat="$(grep -o 'gmdl-feat\.js' "${VHOST_CONF}" | wc -l)"
  if [[ "$c_css" -ne 1 || "$c_ui" -ne 1 || "$c_feat" -ne 1 ]]; then
    record_fail "${id}" "${desc}" "expected exactly 1 occurrence per asset in vhost config, got css=${c_css} ui=${c_ui} feat=${c_feat}"
    return
  fi

  tok_css="$(grep -o 'gmdl-dark\.css?v=[^"'"'"'\\> ]*' "${VHOST_CONF}" || true)"
  tok_ui="$(grep -o 'gmdl-ui\.js?v=[^"'"'"'\\> ]*' "${VHOST_CONF}" || true)"
  tok_feat="$(grep -o 'gmdl-feat\.js?v=[^"'"'"'\\> ]*' "${VHOST_CONF}" || true)"
  val_css="${tok_css#*\?v=}"
  val_ui="${tok_ui#*\?v=}"
  val_feat="${tok_feat#*\?v=}"

  if [[ ! "$val_css" =~ ^[0-9a-f]{8}$ || "$val_css" != "${EXPECTED_CSS_HASH}" ]]; then
    record_fail "${id}" "${desc}" "gmdl-dark.css version token (${val_css}) is not exact 8-hex-char match for ${EXPECTED_CSS_HASH}"
    return
  fi
  if [[ ! "$val_ui" =~ ^[0-9a-f]{8}$ || "$val_ui" != "${EXPECTED_UI_HASH}" ]]; then
    record_fail "${id}" "${desc}" "gmdl-ui.js version token (${val_ui}) is not exact 8-hex-char match for ${EXPECTED_UI_HASH}"
    return
  fi
  if [[ ! "$val_feat" =~ ^[0-9a-f]{8}$ || "$val_feat" != "${EXPECTED_FEAT_HASH}" ]]; then
    record_fail "${id}" "${desc}" "gmdl-feat.js version token (${val_feat}) is not exact 8-hex-char match for ${EXPECTED_FEAT_HASH}"
    return
  fi

  record_pass "${id}" "${desc}"
}

# ==============================================================================
# MOCK-02: Single-Instance Lock Contention
# ==============================================================================
test_mock_02() {
  local id="MOCK-02"
  local desc="Single-Instance Lock Contention Halts Second Instance Cleanly"
  require_deploy_script "${id}" "${desc}" || return

  setup_sandbox "${id}"
  local lock_path
  lock_path="$(git_metadata_lock_path)"

  (
    exec 9<"${lock_path}"
    flock -n 9 || exit 1
    sleep 2
  ) &
  local holder_pid=$!
  sleep 0.2

  run_deploy_in_sandbox \
    --config "${VHOST_CONF}" \
    --nginx-main-conf "${MAIN_CONF}" \
    --repo-dir "${WORK_REPO}" \
    --branch main \
    --nginx-bin "${MOCK_NGINX}"
  local rc=$?
  wait "${holder_pid}" 2>/dev/null || true

  if [[ $rc -eq 0 ]]; then
    record_fail "${id}" "${desc}" "expected non-zero exit when Git metadata directory lock is held, got 0"
    return
  fi

  if ! grep -Fq "FLOCK_PATH|${lock_path}|" "${MOCK_EVENT_LOG}"; then
    record_fail "${id}" "${desc}" "deploy did not attempt flock on the held Git-metadata lock path ${lock_path}"
    return
  fi
  if [[ ! -s "${SANDBOX_DIR}/deploy_output.log" ]] ||
     ! grep -Eiq 'deployment lock.*(already held|busy|locked)|lock.*(already held|busy|contended)' "${SANDBOX_DIR}/deploy_output.log"; then
    record_fail "${id}" "${desc}" "non-zero exit lacked a lock-contention-specific diagnostic"
    return
  fi

  if grep -q '^STEP1_PULL|' "${MOCK_EVENT_LOG}" || grep -q '^STEP2_HASH|' "${MOCK_EVENT_LOG}" || grep -q '^STEP4_NGINX_T|' "${MOCK_EVENT_LOG}" || grep -q '^STEP5_RELOAD|' "${MOCK_EVENT_LOG}" || grep -q '^MV|' "${MOCK_EVENT_LOG}" || grep -q '^GIT_RESET|' "${MOCK_EVENT_LOG}"; then
    record_fail "${id}" "${desc}" "contended instance must halt before pull or config mutation"
    return
  fi

  if [[ -n "$(GIT_OPTIONAL_LOCKS=0 "${MOCK_REAL_GIT}" -C "${WORK_REPO}" status --porcelain)" ]]; then
    record_fail "${id}" "${desc}" "git status --porcelain dirty after lock contention"
    return
  fi

  if ! "${MOCK_REAL_CMP}" -s "${VHOST_CONF}" "${SANDBOX_DIR}/vhost.orig.snapshot"; then
    record_fail "${id}" "${desc}" "active config was mutated during lock contention"
    return
  fi

  record_pass "${id}" "${desc}"
}

# ==============================================================================
# MOCK-03: Git Metadata Lock Isolation & Re-acquisition Invariant
# ==============================================================================
test_mock_03() {
  local id="MOCK-03"
  local desc="Read-Only Metadata Lock, Clean Porcelain, Re-acquisition & Index-Invariant Dry-Run"
  require_deploy_script "${id}" "${desc}" || return

  # Part (a): Successful run
  setup_sandbox "${id}-ok"
  run_deploy_in_sandbox \
    --config "${VHOST_CONF}" \
    --nginx-main-conf "${MAIN_CONF}" \
    --repo-dir "${WORK_REPO}" \
    --branch main \
    --nginx-bin "${MOCK_NGINX}"
  local rc_ok=$?
  local lock_path git_dir index_path index_hash_before index_meta_before index_hash_after index_meta_after
  lock_path="$(git_metadata_lock_path)"
  git_dir="$("${MOCK_REAL_GIT}" -C "${WORK_REPO}" rev-parse --absolute-git-dir)"

  if [[ $rc_ok -ne 0 ]]; then
    record_fail "${id}" "${desc}" "subcase (a) expected exit 0, got ${rc_ok}"
    return
  fi
  if ! grep -q '^GIT_DIR|rev-parse --absolute-git-dir$' "${MOCK_EVENT_LOG}"; then
    record_fail "${id}" "${desc}" "deploy.sh did not resolve the Git metadata directory via git rev-parse --absolute-git-dir"
    return
  fi
  if [[ "${lock_path}" != "${git_dir}" ]] || ! grep -Fqx "GIT_DIR_RESULT|${git_dir}" "${MOCK_EVENT_LOG}" || ! grep -Fq "FLOCK_PATH|${lock_path}|" "${MOCK_EVENT_LOG}"; then
    record_fail "${id}" "${desc}" "successful run did not lock the exact resolved Git metadata directory"
    return
  fi
  if [[ -n "$(GIT_OPTIONAL_LOCKS=0 "${MOCK_REAL_GIT}" -C "${WORK_REPO}" status --porcelain)" ]]; then
    record_fail "${id}" "${desc}" "git status --porcelain dirty after exit 0"
    return
  fi
  if ! flock -n "${lock_path}" true; then
    record_fail "${id}" "${desc}" "directory lock not released after exit 0"
    return
  fi
  if [[ -e "${lock_path}/deploy.lock" ]]; then
    record_fail "${id}" "${desc}" "persistent deploy.lock file unexpectedly created"
    return
  fi

  # Part (b): Failing run (Step 4 syntax error)
  setup_sandbox "${id}-fail"
  lock_path="$(git_metadata_lock_path)"
  git_dir="${lock_path}"
  MOCK_FAIL_NGINX_T=1 run_deploy_in_sandbox \
    --config "${VHOST_CONF}" \
    --nginx-main-conf "${MAIN_CONF}" \
    --repo-dir "${WORK_REPO}" \
    --branch main \
    --nginx-bin "${MOCK_NGINX}"
  local rc_fail=$?
  if [[ $rc_fail -eq 0 ]]; then
    record_fail "${id}" "${desc}" "subcase (b) expected non-zero exit on syntax failure"
    return
  fi
  if ! grep -Fqx "GIT_DIR_RESULT|${git_dir}" "${MOCK_EVENT_LOG}" || ! grep -Fq "FLOCK_PATH|${lock_path}|" "${MOCK_EVENT_LOG}"; then
    record_fail "${id}" "${desc}" "failing run did not lock the exact resolved Git metadata directory"
    return
  fi
  if [[ -n "$(GIT_OPTIONAL_LOCKS=0 "${MOCK_REAL_GIT}" -C "${WORK_REPO}" status --porcelain)" ]]; then
    record_fail "${id}" "${desc}" "git status --porcelain dirty after failure exit"
    return
  fi
  if ! flock -n "${lock_path}" true; then
    record_fail "${id}" "${desc}" "directory lock not released after failure exit"
    return
  fi

  # Part (c): Dry-run acquires the directory lock but makes no file/config/backup/reload changes.
  setup_sandbox "${id}-dry-run"
  lock_path="$(git_metadata_lock_path)"
  index_path="${WORK_REPO}/.git/index"
  if [[ ! -f "${index_path}" ]]; then
    record_fail "${id}" "${desc}" "dry-run fixture has no Git index to snapshot"
    return
  fi
  # Force the tracked asset stat cache to be stale so an ordinary status refresh would rewrite index.
  touch -d '@1234567890' "${WORK_REPO}/gmdl-ui.js"
  index_hash_before="$(sha256sum "${index_path}" | awk '{print $1}')"
  index_meta_before="$(stat -c '%u:%g:%a:%s:%y' "${index_path}")"
  run_deploy_in_sandbox \
    --config "${VHOST_CONF}" \
    --nginx-main-conf "${MAIN_CONF}" \
    --repo-dir "${WORK_REPO}" \
    --branch main \
    --nginx-bin "${MOCK_NGINX}" \
    --dry-run
  local rc_dry=$?
  if [[ ${rc_dry} -ne 0 ]]; then
    record_fail "${id}" "${desc}" "dry-run subcase expected exit 0, got ${rc_dry}"
    return
  fi
  if ! grep -Fq "FLOCK_PATH|${lock_path}|" "${MOCK_EVENT_LOG}" || [[ "$(grep -c '^STEP2_HASH|' "${MOCK_EVENT_LOG}")" -ne 3 ]]; then
    record_fail "${id}" "${desc}" "dry-run did not hold the Git metadata lock and validate all three assets"
    return
  fi
  if ! grep -Fqx 'GIT_STATUS_OPTIONAL_LOCKS|0' "${MOCK_EVENT_LOG}"; then
    record_fail "${id}" "${desc}" "dry-run git status did not disable optional Git index writes"
    return
  fi
  if grep -q '^STEP1_PULL|' "${MOCK_EVENT_LOG}" || grep -q '^STEP4_NGINX_T|' "${MOCK_EVENT_LOG}" || grep -q '^STEP5_RELOAD|' "${MOCK_EVENT_LOG}" || grep -q '^MV|' "${MOCK_EVENT_LOG}" || grep -q '^GIT_RESET|' "${MOCK_EVENT_LOG}" || compgen -G "${VHOST_CONF}.bak.*" >/dev/null || [[ -e "${lock_path}/deploy.lock" ]]; then
    record_fail "${id}" "${desc}" "dry-run performed a pull, backup, config/reload mutation, reset, or lock-file write"
    return
  fi
  index_hash_after="$(sha256sum "${index_path}" | awk '{print $1}')"
  index_meta_after="$(stat -c '%u:%g:%a:%s:%y' "${index_path}")"
  if [[ "${index_hash_after}" != "${index_hash_before}" || "${index_meta_after}" != "${index_meta_before}" || -e "${WORK_REPO}/.git/index.lock" ]]; then
    record_fail "${id}" "${desc}" "dry-run changed Git index bytes or metadata, or left index.lock"
    return
  fi
  if ! "${MOCK_REAL_CMP}" -s "${VHOST_CONF}" "${SANDBOX_DIR}/vhost.orig.snapshot" || [[ -n "$(GIT_OPTIONAL_LOCKS=0 "${MOCK_REAL_GIT}" -C "${WORK_REPO}" status --porcelain)" ]] || ! flock -n "${lock_path}" true; then
    record_fail "${id}" "${desc}" "dry-run changed active config/worktree or failed to release the metadata lock"
    return
  fi

  record_pass "${id}" "${desc}"
}

# ==============================================================================
# MOCK-04: Dirty Working Tree Preflight Check
# ==============================================================================
test_mock_04() {
  local id="MOCK-04"
  local desc="Dirty or Unverifiable Working Tree Fails Preflight with Zero File Mutations and Zero Reset"
  require_deploy_script "${id}" "${desc}" || return

  setup_sandbox "${id}"
  local lock_path line_lock line_dirty line_status_lock line_status_failure rc_status
  lock_path="$(git_metadata_lock_path)"
  echo "uncommitted local change" >> "${WORK_REPO}/gmdl-ui.js"
  cp -p "${MAIN_CONF}" "${SANDBOX_DIR}/main.orig.snapshot"

  run_deploy_in_sandbox \
    --config "${VHOST_CONF}" \
    --nginx-main-conf "${MAIN_CONF}" \
    --repo-dir "${WORK_REPO}" \
    --branch main \
    --nginx-bin "${MOCK_NGINX}"
  local rc=$?

  if [[ $rc -eq 0 ]]; then
    record_fail "${id}" "${desc}" "expected non-zero exit on dirty worktree, got 0"
    return
  fi

  line_lock="$(grep -n -F "FLOCK_PATH|${lock_path}|" "${MOCK_EVENT_LOG}" | head -n1 | cut -d: -f1)"
  line_dirty="$(grep -n '^GIT_STATUS_DIRTY$' "${MOCK_EVENT_LOG}" | head -n1 | cut -d: -f1)"
  if [[ -z "${line_lock}" || -z "${line_dirty}" ]] || ! (( line_lock < line_dirty )); then
    record_fail "${id}" "${desc}" "metadata lock was not observed strictly before dirty-tree status check"
    return
  fi

  if grep -q '^STEP1_PULL|' "${MOCK_EVENT_LOG}" || grep -q '^STEP2_HASH|' "${MOCK_EVENT_LOG}" || grep -q '^GIT_RESET|' "${MOCK_EVENT_LOG}" || grep -q '^MV|' "${MOCK_EVENT_LOG}" || grep -q '^STEP4_NGINX_T|' "${MOCK_EVENT_LOG}" || grep -q '^STEP5_RELOAD|' "${MOCK_EVENT_LOG}"; then
    record_fail "${id}" "${desc}" "dirty preflight must not pull, reset, or rename files"
    return
  fi

  if ! "${MOCK_REAL_CMP}" -s "${VHOST_CONF}" "${SANDBOX_DIR}/vhost.orig.snapshot"; then
    record_fail "${id}" "${desc}" "active config was mutated on dirty worktree"
    return
  fi
  if ! "${MOCK_REAL_CMP}" -s "${MAIN_CONF}" "${SANDBOX_DIR}/main.orig.snapshot" || [[ "$("${MOCK_REAL_GIT}" -C "${WORK_REPO}" diff --name-only)" != "gmdl-ui.js" ]] || [[ -n "$("${MOCK_REAL_GIT}" -C "${WORK_REPO}" ls-files --others --exclude-standard)" ]]; then
    record_fail "${id}" "${desc}" "dirty preflight mutated main config or worktree state beyond the intentional test edit"
    return
  fi
  if compgen -G "${VHOST_CONF}.bak.*" >/dev/null; then
    record_fail "${id}" "${desc}" "dirty preflight created a backup despite halting before preflight completion"
    return
  fi

  if ! grep -q "uncommitted local change" "${WORK_REPO}/gmdl-ui.js"; then
    record_fail "${id}" "${desc}" "dirty local modification in worktree was destroyed"
    return
  fi

  # Subcase: an empty stdout from a failing git status must not be treated as a clean tree.
  setup_sandbox "${id}-status-command-failure"
  lock_path="$(git_metadata_lock_path)"
  cp -p "${MAIN_CONF}" "${SANDBOX_DIR}/main.orig.snapshot"
  MOCK_FAIL_STATUS=1 run_deploy_in_sandbox \
    --config "${VHOST_CONF}" \
    --nginx-main-conf "${MAIN_CONF}" \
    --repo-dir "${WORK_REPO}" \
    --branch main \
    --nginx-bin "${MOCK_NGINX}"
  rc_status=$?
  if [[ ${rc_status} -eq 0 ]] || [[ ! -s "${SANDBOX_DIR}/deploy_output.log" ]] || ! grep -Eiq 'unable to verify.*(clean|worktree)|cannot determine.*(clean|worktree)' "${SANDBOX_DIR}/deploy_output.log"; then
    record_fail "${id}" "${desc}" "failing git status with empty stdout was not rejected with a specific fail-closed diagnostic"
    return
  fi
  line_status_lock="$(grep -n -F "FLOCK_PATH|${lock_path}|" "${MOCK_EVENT_LOG}" | head -n1 | cut -d: -f1 || true)"
  line_status_failure="$(grep -n '^GIT_STATUS_FAILURE$' "${MOCK_EVENT_LOG}" | head -n1 | cut -d: -f1 || true)"
  if [[ -z "${line_status_lock}" || -z "${line_status_failure}" ]] || ! (( line_status_lock < line_status_failure )); then
    record_fail "${id}" "${desc}" "status-command failure was not observed after the Git metadata lock"
    return
  fi
  if grep -q '^STEP1_PULL|' "${MOCK_EVENT_LOG}" || grep -q '^STEP2_HASH|' "${MOCK_EVENT_LOG}" || grep -q '^STEP4_NGINX_T|' "${MOCK_EVENT_LOG}" || grep -q '^STEP5_RELOAD|' "${MOCK_EVENT_LOG}" || grep -q '^MV|' "${MOCK_EVENT_LOG}" || grep -q '^GIT_RESET|' "${MOCK_EVENT_LOG}" || compgen -G "${VHOST_CONF}.bak.*" >/dev/null; then
    record_fail "${id}" "${desc}" "status-command failure had pull, backup, hashing, mutation, reload, or reset side effects"
    return
  fi
  if ! "${MOCK_REAL_CMP}" -s "${VHOST_CONF}" "${SANDBOX_DIR}/vhost.orig.snapshot" || ! "${MOCK_REAL_CMP}" -s "${MAIN_CONF}" "${SANDBOX_DIR}/main.orig.snapshot" || [[ -n "$(GIT_OPTIONAL_LOCKS=0 "${MOCK_REAL_GIT}" -C "${WORK_REPO}" status --porcelain)" ]]; then
    record_fail "${id}" "${desc}" "status-command failure changed config or worktree state"
    return
  fi

  record_pass "${id}" "${desc}"
}

# ==============================================================================
# MOCK-05: Pull Failure Active-Config Guarantee
# ==============================================================================
test_mock_05() {
  local id="MOCK-05"
  local desc="Pull or Pulled-HEAD Capture Failure Halts Before Hash/Config and Never Resets Unknown State"
  require_deploy_script "${id}" "${desc}" || return

  setup_sandbox "${id}"
  MOCK_FAIL_PULL=1 run_deploy_in_sandbox \
    --config "${VHOST_CONF}" \
    --nginx-main-conf "${MAIN_CONF}" \
    --repo-dir "${WORK_REPO}" \
    --branch main \
    --nginx-bin "${MOCK_NGINX}"
  local rc=$?

  if [[ $rc -eq 0 ]]; then
    record_fail "${id}" "${desc}" "expected non-zero exit when git pull fails"
    return
  fi

  if ! grep -q '^STEP1_PULL|' "${MOCK_EVENT_LOG}"; then
    record_fail "${id}" "${desc}" "expected git pull attempt in event log"
    return
  fi
  if ! grep -Fqx 'STEP1_PULL|pull --ff-only origin main' "${MOCK_EVENT_LOG}" || [[ "$(grep -c '^STEP1_PULL|' "${MOCK_EVENT_LOG}")" -ne 1 ]]; then
    record_fail "${id}" "${desc}" "failed pull did not use exactly git pull --ff-only origin main"
    return
  fi

  if grep -q '^STEP2_HASH|' "${MOCK_EVENT_LOG}" || grep -q '^MV|' "${MOCK_EVENT_LOG}" || grep -q '^GIT_RESET|' "${MOCK_EVENT_LOG}" || grep -q '^STEP4_NGINX_T|' "${MOCK_EVENT_LOG}" || grep -q '^STEP5_RELOAD|' "${MOCK_EVENT_LOG}" || grep -q "^REV_PARSE_HEAD|${EXPECTED_PULLED_HEAD}$" "${MOCK_EVENT_LOG}"; then
    record_fail "${id}" "${desc}" "pull failure must not hash, update config, or execute git reset"
    return
  fi

  if ! "${MOCK_REAL_CMP}" -s "${VHOST_CONF}" "${SANDBOX_DIR}/vhost.orig.snapshot"; then
    record_fail "${id}" "${desc}" "active config was modified after pull failure"
    return
  fi

  # Subcase: pull succeeds but the immediately required PULLED_HEAD capture fails.
  setup_sandbox "${id}-head-capture-failure"
  cp -p "${MAIN_CONF}" "${SANDBOX_DIR}/main.orig.snapshot"
  MOCK_FAIL_PULLED_HEAD=1 run_deploy_in_sandbox \
    --config "${VHOST_CONF}" \
    --nginx-main-conf "${MAIN_CONF}" \
    --repo-dir "${WORK_REPO}" \
    --branch main \
    --nginx-bin "${MOCK_NGINX}"
  local rc_capture=$?
  if [[ ${rc_capture} -eq 0 ]] || [[ ! -s "${SANDBOX_DIR}/deploy_output.log" ]] || ! grep -Eiq 'PULLED_HEAD could not be verified.*manual|unable to capture.*PULLED_HEAD.*manual' "${SANDBOX_DIR}/deploy_output.log"; then
    record_fail "${id}" "${desc}" "failed PULLED_HEAD capture did not stop with a manual-recovery diagnostic"
    return
  fi
  if ! grep -Fqx 'STEP1_PULL|pull --ff-only origin main' "${MOCK_EVENT_LOG}" || ! grep -q '^REV_PARSE_HEAD_FAILURE$' "${MOCK_EVENT_LOG}" || grep -q '^STEP2_HASH|' "${MOCK_EVENT_LOG}" || grep -q '^MV|' "${MOCK_EVENT_LOG}" || grep -q '^GIT_RESET|' "${MOCK_EVENT_LOG}" || grep -q '^STEP4_NGINX_T|' "${MOCK_EVENT_LOG}" || grep -q '^STEP5_RELOAD|' "${MOCK_EVENT_LOG}"; then
    record_fail "${id}" "${desc}" "HEAD-capture failure was not observed after pull or was followed by hash/config/reload/reset"
    return
  fi
  if ! "${MOCK_REAL_CMP}" -s "${VHOST_CONF}" "${SANDBOX_DIR}/vhost.orig.snapshot" || ! "${MOCK_REAL_CMP}" -s "${MAIN_CONF}" "${SANDBOX_DIR}/main.orig.snapshot"; then
    record_fail "${id}" "${desc}" "active or assembled config changed when pulled HEAD could not be verified"
    return
  fi

  record_pass "${id}" "${desc}"
}

# ==============================================================================
# MOCK-06: Post-Pull Asset Hashing Failure Rollback
# ==============================================================================
test_mock_06() {
  local id="MOCK-06"
  local desc="Post-Pull Asset Hashing Failure (Step 2) Invokes Safe Rollback Routine"
  require_deploy_script "${id}" "${desc}" || return

  setup_sandbox "${id}"
  MOCK_FAIL_HASH=1 run_deploy_in_sandbox \
    --config "${VHOST_CONF}" \
    --nginx-main-conf "${MAIN_CONF}" \
    --repo-dir "${WORK_REPO}" \
    --branch main \
    --nginx-bin "${MOCK_NGINX}"
  local rc=$?

  if [[ $rc -eq 0 ]]; then
    record_fail "${id}" "${desc}" "expected non-zero exit when Step 2 asset hashing fails"
    return
  fi
  if [[ ! -s "${SANDBOX_DIR}/deploy_output.log" ]] || ! grep -Eiq 'asset.*hash.*(fail|error)|hashing.*(fail|error)' "${SANDBOX_DIR}/deploy_output.log"; then
    record_fail "${id}" "${desc}" "missing an asset-hash-specific failure diagnostic"
    return
  fi

  if ! grep -q "^MV|${VHOST_CONF}\.rollback\.tmp\.[0-9]*|${VHOST_CONF}|" "${MOCK_EVENT_LOG}"; then
    record_fail "${id}" "${desc}" "rollback did not stage and rename .rollback.tmp.<pid> in vhost directory"
    return
  fi

  if ! grep -q "^CMP|-s ${VHOST_CONF}\.rollback\.tmp\.[0-9]* ${VHOST_CONF}\.bak\." "${MOCK_EVENT_LOG}"; then
    record_fail "${id}" "${desc}" "rollback did not verify byte-for-byte identity via cmp -s against backup"
    return
  fi

  if ! grep -q "^GIT_RESET|reset --hard ${EXPECTED_PRE_HEAD}$" "${MOCK_EVENT_LOG}"; then
    record_fail "${id}" "${desc}" "rollback did not git reset --hard to PRE_HEAD"
    return
  fi

  local line_hash line_cmp line_restore line_reset line_retest line_recovery_reload
  line_hash="$(grep -n '^STEP2_HASH|' "${MOCK_EVENT_LOG}" | head -n1 | cut -d: -f1)"
  line_cmp="$(grep -n "^CMP|-s ${VHOST_CONF}\.rollback\.tmp\.[0-9]* ${VHOST_CONF}\.bak\." "${MOCK_EVENT_LOG}" | head -n1 | cut -d: -f1)"
  line_restore="$(grep -n "^MV|${VHOST_CONF}\.rollback\.tmp\.[0-9]*|${VHOST_CONF}|" "${MOCK_EVENT_LOG}" | head -n1 | cut -d: -f1)"
  line_reset="$(grep -n '^GIT_RESET|' "${MOCK_EVENT_LOG}" | head -n1 | cut -d: -f1)"
  line_retest="$(grep -n '^STEP4_NGINX_T|1|' "${MOCK_EVENT_LOG}" | head -n1 | cut -d: -f1)"
  line_recovery_reload="$(grep -n '^STEP5_RELOAD|1|' "${MOCK_EVENT_LOG}" | head -n1 | cut -d: -f1)"
  if [[ -z "${line_hash}" || -z "${line_cmp}" || -z "${line_restore}" || -z "${line_reset}" || -z "${line_retest}" || -z "${line_recovery_reload}" ]] || ! (( line_hash < line_cmp && line_cmp < line_restore && line_restore < line_reset && line_reset < line_retest && line_retest < line_recovery_reload )); then
    record_fail "${id}" "${desc}" "hash-failure rollback events are missing or out of order"
    return
  fi

  local cur_head
  cur_head="$("${MOCK_REAL_GIT}" -C "${WORK_REPO}" rev-parse HEAD)"
  if [[ "${cur_head}" != "${EXPECTED_PRE_HEAD}" ]]; then
    record_fail "${id}" "${desc}" "HEAD after rollback (${cur_head}) != PRE_HEAD (${EXPECTED_PRE_HEAD})"
    return
  fi

  if ! "${MOCK_REAL_CMP}" -s "${VHOST_CONF}" "${SANDBOX_DIR}/vhost.orig.snapshot"; then
    record_fail "${id}" "${desc}" "restored vhost config does not match preflight snapshot"
    return
  fi

  record_pass "${id}" "${desc}"
}

# ==============================================================================
# MOCK-07: Same-Directory Staging/Rename Calls & Metadata Equality
# ==============================================================================
test_mock_07() {
  local id="MOCK-07"
  local desc="Same-Directory Staging/Rename Calls (.tmp.\$\$ & .rollback.tmp.\$\$), Metadata Preservation & cmp -s Verification"
  require_deploy_script "${id}" "${desc}" || return

  setup_sandbox "${id}"
  "${MOCK_REAL_CHMOD}" 0640 "${VHOST_CONF}"
  local expected_meta
  expected_meta="$("${MOCK_REAL_STAT}" -c '%u:%g %a' "${VHOST_CONF}")"

  MOCK_FAIL_NGINX_T=1 run_deploy_in_sandbox \
    --config "${VHOST_CONF}" \
    --nginx-main-conf "${MAIN_CONF}" \
    --repo-dir "${WORK_REPO}" \
    --branch main \
    --nginx-bin "${MOCK_NGINX}"
  local rc=$?

  if [[ $rc -eq 0 ]]; then
    record_fail "${id}" "${desc}" "expected non-zero exit on injected syntax failure"
    return
  fi

  if ! grep -q "^MV|${VHOST_CONF}\.tmp\.[0-9]*|${VHOST_CONF}|${expected_meta}$" "${MOCK_EVENT_LOG}"; then
    record_fail "${id}" "${desc}" "forward staging .tmp.<pid> did not preserve exact owner:group mode (${expected_meta}) before atomic mv"
    return
  fi

  if ! grep -q "^MV|${VHOST_CONF}\.rollback\.tmp\.[0-9]*|${VHOST_CONF}|${expected_meta}$" "${MOCK_EVENT_LOG}"; then
    record_fail "${id}" "${desc}" "rollback staging .rollback.tmp.<pid> did not preserve exact owner:group mode (${expected_meta}) before atomic mv"
    return
  fi

  local line_cmp line_rb_mv
  line_cmp="$(grep -n "^CMP|-s ${VHOST_CONF}\.rollback\.tmp\.[0-9]* ${VHOST_CONF}\.bak\." "${MOCK_EVENT_LOG}" | head -n1 | cut -d: -f1)"
  line_rb_mv="$(grep -n "^MV|${VHOST_CONF}\.rollback\.tmp\.[0-9]*|${VHOST_CONF}|" "${MOCK_EVENT_LOG}" | head -n1 | cut -d: -f1)"
  if [[ -z "$line_cmp" || -z "$line_rb_mv" ]] || ! (( line_cmp < line_rb_mv )); then
    record_fail "${id}" "${desc}" "cmp -s verification must execute before atomic rollback mv"
    return
  fi

  local final_meta
  final_meta="$("${MOCK_REAL_STAT}" -c '%u:%g %a' "${VHOST_CONF}")"
  if [[ "${final_meta}" != "${expected_meta}" ]]; then
    record_fail "${id}" "${desc}" "final vhost metadata (${final_meta}) != original (${expected_meta})"
    return
  fi

  if ! "${MOCK_REAL_CMP}" -s "${VHOST_CONF}" "${SANDBOX_DIR}/vhost.orig.snapshot"; then
    record_fail "${id}" "${desc}" "final vhost content differs from original snapshot"
    return
  fi

  record_pass "${id}" "${desc}"
}

# ==============================================================================
# MOCK-08: Asset Token Cardinality Violation Across All Shipped Assets
# ==============================================================================
verify_mock_08_fixture() {
  local target="$1"
  local kind="$2"
  local asset expected actual
  local assets=("gmdl-dark.css" "gmdl-ui.js" "gmdl-feat.js")
  for asset in "${assets[@]}"; do
    expected=1
    if [[ "${asset}" == "${target}" ]]; then
      case "${kind}" in
        zero) expected=0 ;;
        duplicate) expected=2 ;;
        unexpected) expected=1 ;;
        *) return 1 ;;
      esac
    fi
    actual="$(grep -oF "/${asset}?v=" "${VHOST_CONF}" | wc -l)"
    if (( actual != expected )); then
      printf 'fixture token-count mismatch: asset=%s kind=%s expected=%s actual=%s\n' "${asset}" "${kind}" "${expected}" "${actual}" >&2
      return 1
    fi
  done
  if [[ "${kind}" == "unexpected" ]] && ! grep -Fq "/${target}?v=\\\"" "${VHOST_CONF}"; then
    echo "fixture lacks the required empty version token for ${target}" >&2
    return 1
  fi
  return 0
}

verify_mock_08_subcase() {
  local sub_label="$1"
  local snapshot_file="$2"
  local rc="$3"

  if [[ $rc -eq 0 ]]; then
    MOCK_08_ERR="expected non-zero exit for ${sub_label}, got 0"
    return 1
  fi
  if [[ ! -s "${SANDBOX_DIR}/deploy_output.log" ]] || ! grep -Eiq 'exactly one.*(token|occurrence)|token.*(cardinality|count|occurrence)' "${SANDBOX_DIR}/deploy_output.log"; then
    MOCK_08_ERR="${sub_label} did not emit a token-cardinality-specific diagnostic"
    return 1
  fi
  if ! grep -q '^STEP1_PULL|' "${MOCK_EVENT_LOG}"; then
    MOCK_08_ERR="${sub_label} did not execute Step 1 git pull before token validation"
    return 1
  fi
  if ! grep -q "^REV_PARSE_HEAD|${EXPECTED_PULLED_HEAD}$" "${MOCK_EVENT_LOG}"; then
    MOCK_08_ERR="${sub_label} did not capture PULLED_HEAD after Step 1 pull"
    return 1
  fi
  if ! grep -q '^STEP2_HASH|' "${MOCK_EVENT_LOG}"; then
    MOCK_08_ERR="${sub_label} did not reach Step 2 asset hashing before Step 3 token validation"
    return 1
  fi
  if grep -q "^MV|${VHOST_CONF}\.tmp\." "${MOCK_EVENT_LOG}"; then
    MOCK_08_ERR="${sub_label} executed forward atomic mv despite token cardinality violation"
    return 1
  fi
  if ! grep -q "^CMP|-s ${VHOST_CONF}\.rollback\.tmp\.[0-9]* ${VHOST_CONF}\.bak\." "${MOCK_EVENT_LOG}"; then
    MOCK_08_ERR="${sub_label} rollback did not verify .rollback.tmp.<pid> via cmp -s"
    return 1
  fi
  local line_rb_mv line_first_t line_first_reload
  line_rb_mv="$(grep -n "^MV|${VHOST_CONF}\.rollback\.tmp\.[0-9]*|${VHOST_CONF}|" "${MOCK_EVENT_LOG}" | head -n1 | cut -d: -f1)"
  if [[ -z "${line_rb_mv}" ]]; then
    MOCK_08_ERR="${sub_label} rollback did not atomically restore vhost config"
    return 1
  fi
  line_first_t="$(grep -n '^STEP4_NGINX_T|' "${MOCK_EVENT_LOG}" | head -n1 | cut -d: -f1)"
  line_first_reload="$(grep -n '^STEP5_RELOAD|' "${MOCK_EVENT_LOG}" | head -n1 | cut -d: -f1)"
  if [[ -n "${line_first_t}" ]] && (( line_first_t < line_rb_mv )); then
    MOCK_08_ERR="${sub_label} executed forward nginx -t before failing closed in Step 3"
    return 1
  fi
  if [[ -n "${line_first_reload}" ]] && (( line_first_reload < line_rb_mv )); then
    MOCK_08_ERR="${sub_label} executed forward reload before failing closed in Step 3"
    return 1
  fi
  if ! grep -q "^GIT_RESET|reset --hard ${EXPECTED_PRE_HEAD}$" "${MOCK_EVENT_LOG}"; then
    MOCK_08_ERR="${sub_label} rollback did not execute safe git reset --hard to PRE_HEAD"
    return 1
  fi
  if ! "${MOCK_REAL_CMP}" -s "${VHOST_CONF}" "${snapshot_file}"; then
    MOCK_08_ERR="${sub_label} did not preserve pre-test active config bytes"
    return 1
  fi
  local cur_head
  cur_head="$("${MOCK_REAL_GIT}" -C "${WORK_REPO}" rev-parse HEAD)"
  if [[ "${cur_head}" != "${EXPECTED_PRE_HEAD}" ]]; then
    MOCK_08_ERR="${sub_label} final HEAD (${cur_head}) != PRE_HEAD (${EXPECTED_PRE_HEAD})"
    return 1
  fi
  return 0
}

test_mock_08() {
  local id="MOCK-08"
  local desc="Zero, Multiple, or Unexpected sub_filter Asset-Token Cardinality Rejected Fail-Closed Across All 3 Assets"
  require_deploy_script "${id}" "${desc}" || return

  MOCK_08_ERR=""
  local assets=("gmdl-dark.css" "gmdl-ui.js" "gmdl-feat.js")
  for asset in "${assets[@]}"; do
    # Subcase (a): Zero occurrences of $asset token
    setup_sandbox "${id}-${asset}-zero"
    sed -i "s|/${asset}?v=[0-9a-zA-Z_]*|/removed-asset|g" "${VHOST_CONF}"
    if ! verify_mock_08_fixture "${asset}" zero; then
      record_fail "${id}" "${desc}" "zero-token fixture precondition failed for ${asset}"
      return
    fi
    cp -p "${VHOST_CONF}" "${SANDBOX_DIR}/vhost.zero.snapshot"

    run_deploy_in_sandbox \
      --config "${VHOST_CONF}" \
      --nginx-main-conf "${MAIN_CONF}" \
      --repo-dir "${WORK_REPO}" \
      --branch main \
      --nginx-bin "${MOCK_NGINX}"
    if ! verify_mock_08_subcase "${asset} zero-token" "${SANDBOX_DIR}/vhost.zero.snapshot" "$?"; then
      record_fail "${id}" "${desc}" "${MOCK_08_ERR}"
      return
    fi

    # Subcase (b): Multiple (2) occurrences of $asset token
    setup_sandbox "${id}-${asset}-dup"
    sed -i "s|/${asset}?v=[0-9a-zA-Z_]*|/${asset}?v=12\" data-dup=\"/${asset}?v=12|g" "${VHOST_CONF}"
    if ! verify_mock_08_fixture "${asset}" duplicate; then
      record_fail "${id}" "${desc}" "duplicate-token fixture precondition failed for ${asset}"
      return
    fi
    cp -p "${VHOST_CONF}" "${SANDBOX_DIR}/vhost.dup.snapshot"

    run_deploy_in_sandbox \
      --config "${VHOST_CONF}" \
      --nginx-main-conf "${MAIN_CONF}" \
      --repo-dir "${WORK_REPO}" \
      --branch main \
      --nginx-bin "${MOCK_NGINX}"
    if ! verify_mock_08_subcase "${asset} duplicate-token" "${SANDBOX_DIR}/vhost.dup.snapshot" "$?"; then
      record_fail "${id}" "${desc}" "${MOCK_08_ERR}"
      return
    fi

    # Subcase (c): Unexpected/malformed sub_filter asset token (empty ?v= value)
    setup_sandbox "${id}-${asset}-unexpected"
    sed -i "s|/${asset}?v=[0-9a-zA-Z_]*|/${asset}?v=|g" "${VHOST_CONF}"
    if ! verify_mock_08_fixture "${asset}" unexpected; then
      record_fail "${id}" "${desc}" "empty-value token fixture precondition failed for ${asset}"
      return
    fi
    cp -p "${VHOST_CONF}" "${SANDBOX_DIR}/vhost.unexpected.snapshot"

    run_deploy_in_sandbox \
      --config "${VHOST_CONF}" \
      --nginx-main-conf "${MAIN_CONF}" \
      --repo-dir "${WORK_REPO}" \
      --branch main \
      --nginx-bin "${MOCK_NGINX}"
    if ! verify_mock_08_subcase "${asset} empty-value-token" "${SANDBOX_DIR}/vhost.unexpected.snapshot" "$?"; then
      record_fail "${id}" "${desc}" "${MOCK_08_ERR}"
      return
    fi
  done

  record_pass "${id}" "${desc}"
}

# ==============================================================================
# MOCK-09: Assembled Configuration Syntax Verification & Prefix Argv Matrix
# ==============================================================================
test_mock_09() {
  local id="MOCK-09"
  local desc="Assembled Config Syntax Argv, Strict Include Preflight, Prefix Variants & Failure Rollback"
  require_deploy_script "${id}" "${desc}" || return

  # Subcase 9a: Prefix unset
  setup_sandbox "${id}-unset"
  run_deploy_in_sandbox \
    --config "${VHOST_CONF}" \
    --nginx-main-conf "${MAIN_CONF}" \
    --repo-dir "${WORK_REPO}" \
    --branch main \
    --nginx-bin "${MOCK_NGINX}"
  if [[ $? -ne 0 ]]; then
    record_fail "${id}" "${desc}" "subcase 9a (unset prefix) failed"
    return
  fi
  local expected_9a=$'ARG[0]=-t\nARG[1]=-c\nARG[2]='"${MAIN_CONF}"
  if [[ "$(cat "${SANDBOX_DIR}/nginx_t_argv_1.log")" != "${expected_9a}" ]]; then
    record_fail "${id}" "${desc}" "subcase 9a argv mismatch: $(tr '\n' ' ' < "${SANDBOX_DIR}/nginx_t_argv_1.log")"
    return
  fi

  # Subcase 9b: Prefix empty string
  setup_sandbox "${id}-empty"
  run_deploy_in_sandbox \
    --config "${VHOST_CONF}" \
    --nginx-main-conf "${MAIN_CONF}" \
    --nginx-prefix "" \
    --repo-dir "${WORK_REPO}" \
    --branch main \
    --nginx-bin "${MOCK_NGINX}"
  if [[ $? -ne 0 ]]; then
    record_fail "${id}" "${desc}" "subcase 9b (empty prefix) failed"
    return
  fi
  local expected_9b=$'ARG[0]=-t\nARG[1]=-c\nARG[2]='"${MAIN_CONF}"
  if [[ "$(cat "${SANDBOX_DIR}/nginx_t_argv_1.log")" != "${expected_9b}" ]]; then
    record_fail "${id}" "${desc}" "subcase 9b argv mismatch when prefix is empty"
    return
  fi

  # Subcase 9c: Prefix containing whitespace
  setup_sandbox "${id}-space"
  local ws_prefix="${SANDBOX_DIR}/openresty site prefix"
  mkdir -p "${ws_prefix}"
  run_deploy_in_sandbox \
    --config "${VHOST_CONF}" \
    --nginx-main-conf "${MAIN_CONF}" \
    --nginx-prefix "${ws_prefix}" \
    --repo-dir "${WORK_REPO}" \
    --branch main \
    --nginx-bin "${MOCK_NGINX}"
  if [[ $? -ne 0 ]]; then
    record_fail "${id}" "${desc}" "subcase 9c (whitespace prefix) failed"
    return
  fi
  local expected_9c=$'ARG[0]=-t\nARG[1]=-c\nARG[2]='"${MAIN_CONF}"$'\nARG[3]=-p\nARG[4]='"${ws_prefix}"
  if [[ "$(cat "${SANDBOX_DIR}/nginx_t_argv_1.log")" != "${expected_9c}" ]]; then
    record_fail "${id}" "${desc}" "subcase 9c whitespace prefix argv mismatch: $(tr '\n' ' ' < "${SANDBOX_DIR}/nginx_t_argv_1.log")"
    return
  fi

  # Subcase 9d: Syntax failure rollback
  setup_sandbox "${id}-fail"
  MOCK_FAIL_NGINX_T=1 run_deploy_in_sandbox \
    --config "${VHOST_CONF}" \
    --nginx-main-conf "${MAIN_CONF}" \
    --repo-dir "${WORK_REPO}" \
    --branch main \
    --nginx-bin "${MOCK_NGINX}"
  if [[ $? -eq 0 ]]; then
    record_fail "${id}" "${desc}" "subcase 9d expected non-zero exit on syntax failure"
    return
  fi
  if ! "${MOCK_REAL_CMP}" -s "${VHOST_CONF}" "${SANDBOX_DIR}/vhost.orig.snapshot"; then
    record_fail "${id}" "${desc}" "subcase 9d did not restore vhost config after syntax failure"
    return
  fi
  if ! grep -q '^STEP4_NGINX_T|2|' "${MOCK_EVENT_LOG}" || ! grep -q '^STEP5_RELOAD|1|' "${MOCK_EVENT_LOG}"; then
    record_fail "${id}" "${desc}" "subcase 9d did not re-verify restored config syntax and reload service"
    return
  fi
  local line_9d_fail line_9d_cmp line_9d_mv line_9d_reset line_9d_retest line_9d_reload
  line_9d_fail="$(grep -n '^STEP4_NGINX_T|1|' "${MOCK_EVENT_LOG}" | cut -d: -f1)"
  line_9d_cmp="$(grep -n "^CMP|-s ${VHOST_CONF}\.rollback\.tmp\.[0-9]* ${VHOST_CONF}\.bak\." "${MOCK_EVENT_LOG}" | cut -d: -f1)"
  line_9d_mv="$(grep -n "^MV|${VHOST_CONF}\.rollback\.tmp\.[0-9]*|${VHOST_CONF}|" "${MOCK_EVENT_LOG}" | cut -d: -f1)"
  line_9d_reset="$(grep -n '^GIT_RESET|' "${MOCK_EVENT_LOG}" | cut -d: -f1)"
  line_9d_retest="$(grep -n '^STEP4_NGINX_T|2|' "${MOCK_EVENT_LOG}" | cut -d: -f1)"
  line_9d_reload="$(grep -n '^STEP5_RELOAD|1|' "${MOCK_EVENT_LOG}" | cut -d: -f1)"
  if [[ -z "${line_9d_fail}" || -z "${line_9d_cmp}" || -z "${line_9d_mv}" || -z "${line_9d_reset}" || -z "${line_9d_retest}" || -z "${line_9d_reload}" ]] || ! (( line_9d_fail < line_9d_cmp && line_9d_cmp < line_9d_mv && line_9d_mv < line_9d_reset && line_9d_reset < line_9d_retest && line_9d_retest < line_9d_reload )); then
    record_fail "${id}" "${desc}" "subcase 9d rollback/recovery events are missing or out of order"
    return
  fi
  local expected_9d_argv=$'ARG[0]=-t\nARG[1]=-c\nARG[2]='"${MAIN_CONF}"
  if [[ "$(cat "${SANDBOX_DIR}/nginx_t_argv_1.log")" != "${expected_9d_argv}" || "$(cat "${SANDBOX_DIR}/nginx_t_argv_2.log")" != "${expected_9d_argv}" ]]; then
    record_fail "${id}" "${desc}" "subcase 9d initial/recovery nginx argv mismatch"
    return
  fi
  local expected_9d_reload=$'ARG[0]=-s\nARG[1]=reload'
  if [[ "$(cat "${SANDBOX_DIR}/reload_argv_1.log")" != "${expected_9d_reload}" ]]; then
    record_fail "${id}" "${desc}" "subcase 9d recovery reload argv mismatch"
    return
  fi

  # Subcase 9e: Missing-include / invalid --nginx-main-conf rejected in preflight before pull or config mutation
  setup_sandbox "${id}-no-include"
  local bad_main_conf="${SANDBOX_DIR}/etc/nginx-no-include.conf"
  cat > "${bad_main_conf}" <<'EOF'
worker_processes 1;
http {
    # vhost include intentionally omitted
}
EOF
  run_deploy_in_sandbox \
    --config "${VHOST_CONF}" \
    --nginx-main-conf "${bad_main_conf}" \
    --repo-dir "${WORK_REPO}" \
    --branch main \
    --nginx-bin "${MOCK_NGINX}"
  if [[ $? -eq 0 ]]; then
    record_fail "${id}" "${desc}" "subcase 9e expected non-zero exit when --nginx-main-conf does not include vhost"
    return
  fi
  if [[ ! -s "${SANDBOX_DIR}/deploy_output.log" ]] || ! grep -Eiq 'main.*(config|conf).*does not include.*(vhost|config)|main config.*must include' "${SANDBOX_DIR}/deploy_output.log"; then
    record_fail "${id}" "${desc}" "subcase 9e lacked a missing-vhost-include-specific diagnostic"
    return
  fi
  if grep -q '^STEP1_PULL|' "${MOCK_EVENT_LOG}" || grep -q '^STEP2_HASH|' "${MOCK_EVENT_LOG}" || grep -q '^MV|' "${MOCK_EVENT_LOG}" || grep -q '^GIT_RESET|' "${MOCK_EVENT_LOG}"; then
    record_fail "${id}" "${desc}" "subcase 9e must fail closed in preflight before pull, hash, config mv, or git reset"
    return
  fi
  if ! "${MOCK_REAL_CMP}" -s "${VHOST_CONF}" "${SANDBOX_DIR}/vhost.orig.snapshot"; then
    record_fail "${id}" "${desc}" "subcase 9e mutated active vhost config"
    return
  fi
  if compgen -G "${VHOST_CONF}.bak.*" >/dev/null; then
    record_fail "${id}" "${desc}" "subcase 9e created a backup before rejecting the missing include"
    return
  fi
  if [[ "$("${MOCK_REAL_GIT}" -C "${WORK_REPO}" rev-parse HEAD)" != "${EXPECTED_PRE_HEAD}" ]]; then
    record_fail "${id}" "${desc}" "subcase 9e altered worktree HEAD"
    return
  fi

  # Subcase 9f: a target path followed by trailing junk is not a valid include directive.
  setup_sandbox "${id}-malformed-include"
  local malformed_main_conf="${SANDBOX_DIR}/etc/nginx-malformed-include.conf"
  cat > "${malformed_main_conf}" <<EOF
worker_processes 1;
http {
    include ${VHOST_CONF}; trailing-junk
}
EOF
  run_deploy_in_sandbox \
    --config "${VHOST_CONF}" \
    --nginx-main-conf "${malformed_main_conf}" \
    --repo-dir "${WORK_REPO}" \
    --branch main \
    --nginx-bin "${MOCK_NGINX}"
  if [[ $? -eq 0 ]]; then
    record_fail "${id}" "${desc}" "subcase 9f accepted malformed include syntax with trailing junk"
    return
  fi
  if [[ ! -s "${SANDBOX_DIR}/deploy_output.log" ]] || ! grep -Eiq 'malformed.*include|include.*malformed|does not include' "${SANDBOX_DIR}/deploy_output.log"; then
    record_fail "${id}" "${desc}" "subcase 9f lacked a malformed-include-specific diagnostic"
    return
  fi
  if grep -q '^STEP1_PULL|' "${MOCK_EVENT_LOG}" || grep -q '^STEP2_HASH|' "${MOCK_EVENT_LOG}" || grep -q '^STEP4_NGINX_T|' "${MOCK_EVENT_LOG}" || grep -q '^STEP5_RELOAD|' "${MOCK_EVENT_LOG}" || grep -q '^MV|' "${MOCK_EVENT_LOG}" || grep -q '^GIT_RESET|' "${MOCK_EVENT_LOG}" || compgen -G "${VHOST_CONF}.bak.*" >/dev/null; then
    record_fail "${id}" "${desc}" "subcase 9f failed to reject malformed include before deployment actions/backup"
    return
  fi
  if ! "${MOCK_REAL_CMP}" -s "${VHOST_CONF}" "${SANDBOX_DIR}/vhost.orig.snapshot" || [[ "$("${MOCK_REAL_GIT}" -C "${WORK_REPO}" rev-parse HEAD)" != "${EXPECTED_PRE_HEAD}" ]]; then
    record_fail "${id}" "${desc}" "subcase 9f modified active config or Git HEAD"
    return
  fi

  # Subcase 9g: non-executable nginx test binary is rejected before backup/pull.
  setup_sandbox "${id}-invalid-nginx-bin"
  local invalid_nginx="${SANDBOX_DIR}/missing/nginx"
  run_deploy_in_sandbox \
    --config "${VHOST_CONF}" \
    --nginx-main-conf "${MAIN_CONF}" \
    --repo-dir "${WORK_REPO}" \
    --branch main \
    --nginx-bin "${invalid_nginx}"
  local rc_9g=$?
  if [[ ${rc_9g} -eq 0 ]] || [[ ! -s "${SANDBOX_DIR}/deploy_output.log" ]] || ! grep -Eiq 'nginx syntax-test executable is not executable or on PATH' "${SANDBOX_DIR}/deploy_output.log"; then
    record_fail "${id}" "${desc}" "subcase 9g did not specifically reject non-executable --nginx-bin"
    return
  fi
  if grep -q '^STEP1_PULL|' "${MOCK_EVENT_LOG}" || grep -q '^STEP2_HASH|' "${MOCK_EVENT_LOG}" || grep -q '^STEP4_NGINX_T|' "${MOCK_EVENT_LOG}" || grep -q '^STEP5_RELOAD|' "${MOCK_EVENT_LOG}" || grep -q '^MV|' "${MOCK_EVENT_LOG}" || grep -q '^GIT_RESET|' "${MOCK_EVENT_LOG}" || compgen -G "${VHOST_CONF}.bak.*" >/dev/null || ! "${MOCK_REAL_CMP}" -s "${VHOST_CONF}" "${SANDBOX_DIR}/vhost.orig.snapshot"; then
    record_fail "${id}" "${desc}" "subcase 9g had deployment side effects before executable preflight rejection"
    return
  fi

  # Subcase 9h: non-executable reload command is rejected before backup/pull.
  setup_sandbox "${id}-invalid-reload-cmd"
  local invalid_reload="${SANDBOX_DIR}/missing/reload"
  run_deploy_in_sandbox \
    --config "${VHOST_CONF}" \
    --nginx-main-conf "${MAIN_CONF}" \
    --repo-dir "${WORK_REPO}" \
    --branch main \
    --nginx-bin "${MOCK_NGINX}" \
    --reload-cmd "${invalid_reload}"
  local rc_9h=$?
  if [[ ${rc_9h} -eq 0 ]] || [[ ! -s "${SANDBOX_DIR}/deploy_output.log" ]] || ! grep -Eiq 'reload executable is not executable or on PATH' "${SANDBOX_DIR}/deploy_output.log"; then
    record_fail "${id}" "${desc}" "subcase 9h did not specifically reject non-executable --reload-cmd"
    return
  fi
  if grep -q '^STEP1_PULL|' "${MOCK_EVENT_LOG}" || grep -q '^STEP2_HASH|' "${MOCK_EVENT_LOG}" || grep -q '^STEP4_NGINX_T|' "${MOCK_EVENT_LOG}" || grep -q '^STEP5_RELOAD|' "${MOCK_EVENT_LOG}" || grep -q '^MV|' "${MOCK_EVENT_LOG}" || grep -q '^GIT_RESET|' "${MOCK_EVENT_LOG}" || compgen -G "${VHOST_CONF}.bak.*" >/dev/null || ! "${MOCK_REAL_CMP}" -s "${VHOST_CONF}" "${SANDBOX_DIR}/vhost.orig.snapshot"; then
    record_fail "${id}" "${desc}" "subcase 9h had deployment side effects before executable preflight rejection"
    return
  fi

  # Subcase 9i: a PATH that deliberately omits sha256sum must fail preflight.
  setup_sandbox "${id}-missing-sha256sum"
  create_no_sha256sum_path || { record_fail "${id}" "${desc}" "subcase 9i could not build the no-sha256sum PATH"; return; }
  MOCK_NO_SHA256SUM=1 run_deploy_in_sandbox \
    --config "${VHOST_CONF}" \
    --nginx-main-conf "${MAIN_CONF}" \
    --repo-dir "${WORK_REPO}" \
    --branch main \
    --nginx-bin "${MOCK_NGINX}" \
    --reload-cmd "${MOCK_SYSTEMCTL}"
  local rc_9i=$?
  if [[ ${rc_9i} -eq 0 ]] || [[ ! -s "${SANDBOX_DIR}/deploy_output.log" ]] || ! grep -Eiq 'sha256sum is required but not available on PATH' "${SANDBOX_DIR}/deploy_output.log"; then
    record_fail "${id}" "${desc}" "subcase 9i did not specifically reject missing sha256sum"
    return
  fi
  local lock_path_9i line_lock_9i line_status_9i
  lock_path_9i="$(git_metadata_lock_path)"
  line_lock_9i="$(grep -n -F "FLOCK_PATH|${lock_path_9i}|" "${MOCK_EVENT_LOG}" | head -n1 | cut -d: -f1 || true)"
  line_status_9i="$(grep -n '^GIT_STATUS_CLEAN$' "${MOCK_EVENT_LOG}" | head -n1 | cut -d: -f1 || true)"
  if [[ -z "${line_lock_9i}" || -z "${line_status_9i}" ]] || ! (( line_lock_9i < line_status_9i )); then
    record_fail "${id}" "${desc}" "subcase 9i did not prove Git metadata lock acquisition before the status/sha256sum preflight"
    return
  fi
  if grep -q '^REV_PARSE_HEAD|' "${MOCK_EVENT_LOG}"; then
    record_fail "${id}" "${desc}" "subcase 9i captured PRE_HEAD before rejecting missing sha256sum"
    return
  fi
  if grep -q '^STEP1_PULL|' "${MOCK_EVENT_LOG}" || grep -q '^STEP2_HASH|' "${MOCK_EVENT_LOG}" || grep -q '^STEP4_NGINX_T|' "${MOCK_EVENT_LOG}" || grep -q '^STEP5_RELOAD|' "${MOCK_EVENT_LOG}" || grep -q '^MV|' "${MOCK_EVENT_LOG}" || grep -q '^GIT_RESET|' "${MOCK_EVENT_LOG}" || compgen -G "${VHOST_CONF}.bak.*" >/dev/null || ! "${MOCK_REAL_CMP}" -s "${VHOST_CONF}" "${SANDBOX_DIR}/vhost.orig.snapshot" || [[ -n "$(GIT_OPTIONAL_LOCKS=0 "${MOCK_REAL_GIT}" -C "${WORK_REPO}" status --porcelain)" ]]; then
    record_fail "${id}" "${desc}" "subcase 9i had deployment side effects when sha256sum was missing"
    return
  fi

  record_pass "${id}" "${desc}"
}

# ==============================================================================
# MOCK-10: Simulated Reload Failure & Multi-Argument Recovery Reload
# ==============================================================================
test_mock_10() {
  local id="MOCK-10"
  local desc="Simulated Reload Failure Triggers Staged Restore (cmp -s) & Multi-Arg Recovery Reload"
  require_deploy_script "${id}" "${desc}" || return

  setup_sandbox "${id}"
  MOCK_FAIL_FIRST_RELOAD=1 run_deploy_in_sandbox \
    --config "${VHOST_CONF}" \
    --nginx-main-conf "${MAIN_CONF}" \
    --repo-dir "${WORK_REPO}" \
    --branch main \
    --nginx-bin "${MOCK_NGINX}" \
    --reload-cmd "${MOCK_SYSTEMCTL}" \
    --reload-arg reload \
    --reload-arg openresty
  local rc=$?

  if [[ $rc -eq 0 ]]; then
    record_fail "${id}" "${desc}" "expected non-zero exit when initial reload fails"
    return
  fi
  if [[ ! -s "${SANDBOX_DIR}/deploy_output.log" ]] || ! grep -Eiq 'reload.*(fail|error)|failed.*reload' "${SANDBOX_DIR}/deploy_output.log"; then
    record_fail "${id}" "${desc}" "missing a reload-failure-specific diagnostic"
    return
  fi

  local expected_reload_argv=$'ARG[0]=reload\nARG[1]=openresty'
  if [[ ! -f "${SANDBOX_DIR}/reload_argv_1.log" || "$(cat "${SANDBOX_DIR}/reload_argv_1.log")" != "${expected_reload_argv}" ]]; then
    record_fail "${id}" "${desc}" "initial reload argv mismatch"
    return
  fi

  if [[ ! -f "${SANDBOX_DIR}/reload_argv_2.log" || "$(cat "${SANDBOX_DIR}/reload_argv_2.log")" != "${expected_reload_argv}" ]]; then
    record_fail "${id}" "${desc}" "recovery reload was not invoked with exact multi-arg array [reload, openresty]"
    return
  fi

  if ! grep -q "^CMP|-s ${VHOST_CONF}\.rollback\.tmp\.[0-9]* ${VHOST_CONF}\.bak\." "${MOCK_EVENT_LOG}"; then
    record_fail "${id}" "${desc}" "reload failure rollback did not run cmp -s on .rollback.tmp.<pid>"
    return
  fi

  if ! "${MOCK_REAL_CMP}" -s "${VHOST_CONF}" "${SANDBOX_DIR}/vhost.orig.snapshot"; then
    record_fail "${id}" "${desc}" "active config not restored to preflight snapshot after reload failure"
    return
  fi

  local line_reload_fail line_restore_cmp line_restore_mv line_reset line_retest line_recovery_reload
  line_reload_fail="$(grep -n '^STEP5_RELOAD|1|' "${MOCK_EVENT_LOG}" | cut -d: -f1)"
  line_restore_cmp="$(grep -n "^CMP|-s ${VHOST_CONF}\.rollback\.tmp\.[0-9]* ${VHOST_CONF}\.bak\." "${MOCK_EVENT_LOG}" | cut -d: -f1)"
  line_restore_mv="$(grep -n "^MV|${VHOST_CONF}\.rollback\.tmp\.[0-9]*|${VHOST_CONF}|" "${MOCK_EVENT_LOG}" | cut -d: -f1)"
  line_reset="$(grep -n '^GIT_RESET|' "${MOCK_EVENT_LOG}" | cut -d: -f1)"
  line_retest="$(grep -n '^STEP4_NGINX_T|2|' "${MOCK_EVENT_LOG}" | cut -d: -f1)"
  line_recovery_reload="$(grep -n '^STEP5_RELOAD|2|' "${MOCK_EVENT_LOG}" | cut -d: -f1)"
  if [[ "$(grep -c '^STEP5_RELOAD|' "${MOCK_EVENT_LOG}")" -ne 2 || -z "${line_reload_fail}" || -z "${line_restore_cmp}" || -z "${line_restore_mv}" || -z "${line_reset}" || -z "${line_retest}" || -z "${line_recovery_reload}" ]] || ! (( line_reload_fail < line_restore_cmp && line_restore_cmp < line_restore_mv && line_restore_mv < line_reset && line_reset < line_retest && line_retest < line_recovery_reload )); then
    record_fail "${id}" "${desc}" "rollback events are missing or out of order after initial reload failure"
    return
  fi
  if [[ "$("${MOCK_REAL_GIT}" -C "${WORK_REPO}" rev-parse HEAD)" != "${EXPECTED_PRE_HEAD}" ]]; then
    record_fail "${id}" "${desc}" "clean matching PULLED_HEAD failure did not reset worktree to PRE_HEAD"
    return
  fi

  record_pass "${id}" "${desc}"
}

# ==============================================================================
# MOCK-11: Conditional Safe Reset on Clean Head Matching PULLED_HEAD
# ==============================================================================
test_mock_11() {
  local id="MOCK-11"
  local desc="Safe Code Reset Returns to PRE_HEAD When Tree Is Clean and HEAD == PULLED_HEAD"
  require_deploy_script "${id}" "${desc}" || return

  setup_sandbox "${id}"
  MOCK_FAIL_NGINX_T=1 run_deploy_in_sandbox \
    --config "${VHOST_CONF}" \
    --nginx-main-conf "${MAIN_CONF}" \
    --repo-dir "${WORK_REPO}" \
    --branch main \
    --nginx-bin "${MOCK_NGINX}"
  local rc=$?

  if [[ $rc -eq 0 ]]; then
    record_fail "${id}" "${desc}" "expected non-zero exit on post-pull failure"
    return
  fi

  if grep -q 'ORIG_HEAD' "${MOCK_EVENT_LOG}"; then
    record_fail "${id}" "${desc}" "rollback must never rely on ORIG_HEAD"
    return
  fi

  if ! grep -q "^GIT_RESET|reset --hard ${EXPECTED_PRE_HEAD}$" "${MOCK_EVENT_LOG}"; then
    record_fail "${id}" "${desc}" "expected git reset --hard ${EXPECTED_PRE_HEAD}"
    return
  fi

  local final_head
  final_head="$("${MOCK_REAL_GIT}" -C "${WORK_REPO}" rev-parse HEAD)"
  if [[ "${final_head}" != "${EXPECTED_PRE_HEAD}" ]]; then
    record_fail "${id}" "${desc}" "worktree HEAD (${final_head}) was not reset to PRE_HEAD (${EXPECTED_PRE_HEAD})"
    return
  fi

  record_pass "${id}" "${desc}"
}

# ==============================================================================
# MOCK-12: Refusal of Destructive Reset (Distinct Dirty & Drift Subcases)
# ==============================================================================
test_mock_12() {
  local id="MOCK-12"
  local desc="Safe Rollback Refuses Destructive git reset on Post-Pull Dirty Tree (12a) or HEAD Drift (12b)"
  require_deploy_script "${id}" "${desc}" || return

  # Subcase 12a: Worktree becomes dirty after pull
  setup_sandbox "${id}-dirty"
  MOCK_AFTER_PULLED_HEAD_DIRTY=1 MOCK_FAIL_NGINX_T=1 run_deploy_in_sandbox \
    --config "${VHOST_CONF}" \
    --nginx-main-conf "${MAIN_CONF}" \
    --repo-dir "${WORK_REPO}" \
    --branch main \
    --nginx-bin "${MOCK_NGINX}"
  local rc_dirty=$?
  if [[ $rc_dirty -eq 0 ]]; then
    record_fail "${id}" "${desc}" "subcase 12a expected non-zero exit"
    return
  fi
  if grep -q '^GIT_RESET|' "${MOCK_EVENT_LOG}"; then
    record_fail "${id}" "${desc}" "subcase 12a executed git reset despite dirty post-pull worktree"
    return
  fi
  if [[ ! -f "${WORK_REPO}/untracked-post-pull.txt" ]]; then
    record_fail "${id}" "${desc}" "subcase 12a destroyed untracked post-pull file"
    return
  fi
  if ! "${MOCK_REAL_CMP}" -s "${VHOST_CONF}" "${SANDBOX_DIR}/vhost.orig.snapshot"; then
    record_fail "${id}" "${desc}" "subcase 12a did not restore vhost config"
    return
  fi
  if [[ ! -s "${SANDBOX_DIR}/deploy_output.log" ]] ||
     ! grep -Eiq 'critical|warning|manual' "${SANDBOX_DIR}/deploy_output.log" ||
     ! grep -Eiq 'refus(ing|ed).*reset.*(dirty|uncommitted|worktree)' "${SANDBOX_DIR}/deploy_output.log"; then
    record_fail "${id}" "${desc}" "subcase 12a did not emit critical manual-recovery warning for dirty post-pull tree"
    return
  fi
  if [[ "$("${MOCK_REAL_GIT}" -C "${WORK_REPO}" rev-parse HEAD)" != "${EXPECTED_PULLED_HEAD}" ]]; then
    record_fail "${id}" "${desc}" "subcase 12a changed HEAD despite refusing reset on dirty tree"
    return
  fi

  # Subcase 12b: HEAD drifts away from PULLED_HEAD after pull
  setup_sandbox "${id}-drift"
  MOCK_AFTER_PULLED_HEAD_DRIFT=1 MOCK_FAIL_NGINX_T=1 run_deploy_in_sandbox \
    --config "${VHOST_CONF}" \
    --nginx-main-conf "${MAIN_CONF}" \
    --repo-dir "${WORK_REPO}" \
    --branch main \
    --nginx-bin "${MOCK_NGINX}"
  local rc_drift=$?
  if [[ $rc_drift -eq 0 ]]; then
    record_fail "${id}" "${desc}" "subcase 12b expected non-zero exit"
    return
  fi
  if grep -q '^GIT_RESET|' "${MOCK_EVENT_LOG}"; then
    record_fail "${id}" "${desc}" "subcase 12b executed git reset despite HEAD != PULLED_HEAD"
    return
  fi
  local drifted_head
  drifted_head="$("${MOCK_REAL_GIT}" -C "${WORK_REPO}" rev-parse HEAD)"
  if [[ "${drifted_head}" == "${EXPECTED_PRE_HEAD}" || "${drifted_head}" == "${EXPECTED_PULLED_HEAD}" ]]; then
    record_fail "${id}" "${desc}" "subcase 12b did not preserve drifted HEAD commit"
    return
  fi
  if ! "${MOCK_REAL_CMP}" -s "${VHOST_CONF}" "${SANDBOX_DIR}/vhost.orig.snapshot"; then
    record_fail "${id}" "${desc}" "subcase 12b did not restore vhost config"
    return
  fi
  if [[ ! -s "${SANDBOX_DIR}/deploy_output.log" ]] ||
     ! grep -Eiq 'critical|warning|manual' "${SANDBOX_DIR}/deploy_output.log" ||
     ! grep -Eiq 'refus(ing|ed).*reset.*(head.*(drift|match|different)|pulled_head|revision)' "${SANDBOX_DIR}/deploy_output.log"; then
    record_fail "${id}" "${desc}" "subcase 12b did not emit critical manual-recovery warning for HEAD drift"
    return
  fi

  record_pass "${id}" "${desc}"
}

# ==============================================================================
# Execute All 12 Cases & Print Summary
# ==============================================================================
main() {
  printf '==============================================================================\n'
  printf 'GMDL Deployment Offline Mock Harness (MOCK-01..MOCK-12)\n'
  printf 'Target Script: %s\n' "${DEPLOY_SCRIPT}"
  printf '==============================================================================\n'

  test_mock_01
  test_mock_02
  test_mock_03
  test_mock_04
  test_mock_05
  test_mock_06
  test_mock_07
  test_mock_08
  test_mock_09
  test_mock_10
  test_mock_11
  test_mock_12

  printf '==============================================================================\n'
  printf 'Summary: Total=%d | Passed=%d | Failed=%d\n' "${TOTAL_CASES}" "${PASS_CASES}" "${FAIL_CASES}"
  printf '==============================================================================\n'

  if [[ "${FAIL_CASES}" -ne 0 || "${TOTAL_CASES}" -ne 12 ]]; then
    exit 1
  fi
  exit 0
}

main "$@"
