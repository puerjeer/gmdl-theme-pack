#!/usr/bin/env bash
# Phase-aware, offline quality gate for gmdl-theme-pack.
# Contract: docs/project/07-quality-test-plan.md §8 (accepted 2026-10-13).
set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd -P)"
cd "$ROOT_DIR"

if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
  printf '[FAIL] Not inside a Git worktree: %s\n' "$ROOT_DIR" >&2
  exit 2
fi

FAILURES=0
PASS_COUNT=0
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/gmdl-smoke.XXXXXX")" || {
  printf '[FAIL] Could not create temporary directory.\n' >&2
  exit 2
}
trap 'rm -rf -- "$TEMP_DIR"' EXIT

pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  printf '[PASS] %s\n' "$1"
}

fail() {
  FAILURES=$((FAILURES + 1))
  printf '[FAIL] %s\n' "$1" >&2
}

run_check() {
  local label="$1"
  shift
  printf '[RUN ] %s\n' "$label"
  if "$@"; then
    pass "$label"
  else
    fail "$label (exit $?)"
  fi
}

printf 'gmdl-theme-pack smoke checks\n'
printf 'Repository: %s\n' "$ROOT_DIR"
printf 'Mode: deterministic local checks; no network, live server, or SSH calls\n\n'

# Phase 1: always-required documentation and baseline checks.
printf '== Phase 1: required baseline checks ==\n'

printf '[RUN ] UTF-8 text whitespace and line-ending audit\n'
if python3 - "$ROOT_DIR" <<'PY'
from pathlib import Path
import os
import subprocess
import sys

root = Path(sys.argv[1])
raw = subprocess.check_output(
    ["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"],
    cwd=root,
)
paths = [os.fsdecode(item) for item in raw.split(b"\0") if item]
known_text_suffixes = {".md", ".js", ".sh", ".json", ".css", ".conf", ".log", ".txt"}
scanned = []
errors = []
crlf_files = []

for name in paths:
    path = root / name
    if not path.is_file():
        continue
    data = path.read_bytes()
    # NUL-containing files are binary and outside this text-only audit.
    if b"\0" in data:
        continue
    suffix = path.suffix.lower()
    known_text = suffix in known_text_suffixes or suffix == ""
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError:
        if known_text:
            errors.append(f"{name}: expected UTF-8 text but decoding failed")
        continue

    scanned.append(name)
    if b"\r\n" in data:
        crlf_files.append(name)
    for line_number, line in enumerate(text.splitlines(), start=1):
        if line.rstrip(" \t") != line:
            errors.append(f"{name}:{line_number}: trailing spaces or tabs")

for name in crlf_files:
    errors.append(f"{name}: CRLF line endings")

print(f"  Scanned {len(scanned)} UTF-8 text files.")
if errors:
    for item in errors:
        print(f"  ERROR: {item}")
    raise SystemExit(1)
print("  No trailing whitespace, CRLF, or invalid UTF-8 in expected text files.")
PY
then
  pass 'UTF-8 text whitespace and line-ending audit'
else
  fail 'UTF-8 text whitespace and line-ending audit'
fi
run_check 'git diff --check' git diff --check

printf '[RUN ] Relative Markdown link integrity\n'
if python3 - "$ROOT_DIR" <<'PY'
from pathlib import Path
from urllib.parse import unquote
import os
import re
import subprocess
import sys

root = Path(sys.argv[1])
raw = subprocess.check_output(
    ["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"],
    cwd=root,
)
paths = [os.fsdecode(item) for item in raw.split(b"\0") if item]
link_re = re.compile(r"!?\[[^\]]*\]\(([^)]+)\)")
checked = 0
broken = []
markdown_files = []

for name in paths:
    source = root / name
    if not source.is_file() or source.suffix.lower() != ".md":
        continue
    try:
        text = source.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        broken.append((name, "Markdown file is not UTF-8"))
        continue
    markdown_files.append(name)
    for raw_target in link_re.findall(text):
        target = raw_target.strip()
        # Support angle-bracket destinations and ordinary destinations with an optional title.
        if target.startswith("<") and ">" in target:
            target = target[1:target.index(">")]
        else:
            target = target.split()[0] if target else ""
        if not target or target.startswith(("#", "http://", "https://", "mailto:", "tel:", "data:")):
            continue
        target = unquote(target.split("#", 1)[0].split("?", 1)[0])
        if not target:
            continue
        checked += 1
        if target.startswith("/"):
            candidate = root / target.lstrip("/")
        else:
            candidate = source.parent / target
        if not candidate.exists():
            broken.append((name, target))

print(f"  Checked {checked} relative links across {len(markdown_files)} Markdown files.")
if broken:
    for source, target in broken:
        print(f"  ERROR: {source}: missing target {target}")
    raise SystemExit(1)
print("  No broken relative Markdown targets.")
PY
then
  pass 'Relative Markdown link integrity'
else
  fail 'Relative Markdown link integrity'
fi

run_check 'node --check gmdl-ui.js' node --check gmdl-ui.js
run_check 'node --check gmdl-feat.js' node --check gmdl-feat.js

printf '[RUN ] Baseline unit tests (exactly 8 pass / 0 fail / 0 skipped)\n'
if node --test --test-reporter=tap gmdl-ui.test.js >"$TEMP_DIR/baseline.tap" 2>&1; then
  cat "$TEMP_DIR/baseline.tap"
  if grep -qx '# tests 8' "$TEMP_DIR/baseline.tap" \
    && grep -qx '# pass 8' "$TEMP_DIR/baseline.tap" \
    && grep -qx '# fail 0' "$TEMP_DIR/baseline.tap" \
    && grep -qx '# skipped 0' "$TEMP_DIR/baseline.tap"; then
    pass 'Baseline unit tests (8/0/0)'
  else
    fail 'Baseline unit tests did not report exactly 8/0/0'
  fi
else
  cat "$TEMP_DIR/baseline.tap"
  fail 'Baseline unit tests exited non-zero'
fi

printf '[RUN ] Baseline feature file identity against 126853a\n'
if git cat-file -e '126853a^{commit}' 2>/dev/null \
  && git diff --quiet 126853a -- gmdl-feat.js; then
  pass 'gmdl-feat.js unchanged from baseline 126853a'
else
  fail 'gmdl-feat.js differs from baseline 126853a or baseline commit is missing'
fi

# Phase 2: execute only suites whose implementation artifacts now exist.
printf '\n== Phase 2: conditional future suites ==\n'
if [[ -f gmdl-ui-enhancements.test.js ]]; then
  run_check 'node --test gmdl-ui-enhancements.test.js' node --test gmdl-ui-enhancements.test.js
else
  printf '[INFO] UI enhancement suite: NOT YET IMPLEMENTED (deferred to Task 4)\n'
fi

if [[ -f deploy.sh ]]; then
  run_check 'bash -n deploy.sh' bash -n deploy.sh
  if [[ -f scripts/deploy-mock.sh ]]; then
    run_check 'bash scripts/deploy-mock.sh' bash scripts/deploy-mock.sh
  else
    fail 'deploy.sh exists but required scripts/deploy-mock.sh harness is missing'
  fi
elif [[ -f scripts/deploy-mock.sh ]]; then
  run_check 'bash -n scripts/deploy-mock.sh' bash -n scripts/deploy-mock.sh
  printf '[RUN ] Deployment harness TDD red-phase contract (deploy.sh absent; exactly 12 expected blocked cases)\n'
  if bash scripts/deploy-mock.sh >"$TEMP_DIR/deploy-mock-red.tap" 2>&1; then
    cat "$TEMP_DIR/deploy-mock-red.tap"
    fail 'Deployment harness unexpectedly passed while deploy.sh is absent'
  else
    cat "$TEMP_DIR/deploy-mock-red.tap"
    red_summary='Summary: Total=12 | Passed=0 | Failed=12'
    case_fail_count="$(grep -c '^FAIL \[MOCK-' "$TEMP_DIR/deploy-mock-red.tap" || true)"
    missing_script_count="$(grep -c 'deploy.sh not found at ' "$TEMP_DIR/deploy-mock-red.tap" || true)"
    if grep -qx "$red_summary" "$TEMP_DIR/deploy-mock-red.tap" \
      && [[ "$case_fail_count" -eq 12 ]] \
      && [[ "$missing_script_count" -eq 12 ]]; then
      pass 'Deployment harness TDD red-phase contract (12/12 blocked only by absent deploy.sh)'
    else
      fail 'Deployment harness did not report exactly the expected 12-case TDD red state'
    fi
  fi
else
  printf '[INFO] deploy.sh & mock harness: NOT YET IMPLEMENTED (deferred to Task 5)\n'
fi

printf '\nSummary: %d passed check(s), %d failed check(s).\n' "$PASS_COUNT" "$FAILURES"
if (( FAILURES != 0 )); then
  exit 1
fi
printf 'Smoke checks passed for all active deliverables.\n'
