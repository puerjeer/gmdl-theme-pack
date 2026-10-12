# Module Contract: `deploy.sh`
<!-- Project: gmdl-theme-pack-agent · Branch: project/antigravity-overhaul -->
<!-- Stage: Task 2 — Module Contract (Canonical) -->
<!-- Date: 2026-10-13 -->

## 1. Overview & Architectural Role

`deploy.sh` is an automated, reversible deployment script designed to run on the web server host.
It automates the preflight audit, pull, asset versioning, configuration update, syntax verification, reload, and rollback sequence for `gmdl-theme-pack` with zero manual version editing, automated configuration backups, and deterministic safe rollback.

---

## 2. CLI Invocation & Parameter Interface

```bash
bash deploy.sh --config <path-to-vhost.conf> --nginx-main-conf <path-to-nginx.conf> [options]
```

### 2.1 Command-Line Options
| Option | Long Flag | Required / Default | Description |
|---|---|---|---|
| `-c` | `--config` | **Required** (no guessing) | Absolute path to the active OpenResty/Nginx virtual host configuration file. |
| `-m` | `--nginx-main-conf` | **Required** (or env `NGINX_MAIN_CONF`) | Absolute path to the main OpenResty/Nginx configuration file that includes the target vhost. |
| `-p` | `--nginx-prefix` | Optional (or env `NGINX_PREFIX`) | Path to Nginx server prefix directory (`-p <prefix>`). |
| `-b` | `--branch` | Default: `main` | Target git branch to pull (`--ff-only`). |
| `-d` | `--repo-dir` | Default: current repo root | Working directory of the repository clone. |
| `-n` | `--dry-run` | Default: `false` | Simulates deployment without pulling Git, creating backups, modifying configuration, or reloading services. It still acquires the Git metadata directory lock read-only; no lock file is created. |
| `-x` | `--nginx-bin` | Default: `nginx` (or env `NGINX_BIN`) | Executable path for Nginx/OpenResty binary used for syntax validation. Verified executable; quoted in invocations. |
| `-r` | `--reload-cmd` | Default: value of `--nginx-bin` | Executable path for service reload binary. Quoted; never invoked through `eval` or treated as a multiword shell command. |
| `-a` | `--reload-arg` | Repeatable (default: `-s reload`) | Argument passed to reload executable. Collected into Bash array `RELOAD_ARGS+=("$ARG")` and invoked as `"$RELOAD_CMD" "${RELOAD_ARGS[@]}"`. Supports multi-argument invocations (e.g., `--reload-cmd systemctl --reload-arg reload --reload-arg openresty`). |
| `-h` | `--help` | — | Displays usage summary. |

*Safety Invariant:* The script does **not** guess or hardcode a production configuration path as a default; `--config` must point to a verified existing file, and `--nginx-main-conf` must point to a verified existing main configuration that includes `--config`. Binary paths (`--nginx-bin`, `--reload-cmd`) must point to verified executables (`[[ -x "$PATH" ]]` or resolved via `command -v`). Contradictory freeform string commands (such as `--test-cmd`) are disallowed.

---

## 3. Execution Phases & Sequencing

### 3.1 Phase 0: Preflight Integrity & Lock Acquisition
Before any modifications occur:
1. **Concurrency Lock in Git Metadata:** Acquire the single-instance lock with `flock` on a read-only file descriptor for the verified non-worktree Git metadata directory from `git rev-parse --absolute-git-dir` (never the tracked/worktree root) **before** checking worktree cleanliness. This avoids creating or truncating a lock file, including in dry-run mode. Ensure lock release on every exit path via an EXIT trap. Lock acquisition/release must leave `git status --porcelain` completely clean.
2. **Clean Worktree Check:** Run `GIT_OPTIONAL_LOCKS=0 git status --porcelain` and explicitly verify its exit status. The environment override prevents an otherwise read-only status query from refreshing the Git index. Require successful execution and empty output; if Git cannot establish status (non-zero exit, even with empty stdout), fail closed and halt. Also halt if any untracked or uncommitted changes exist.
3. **Parameter & Path Verification:** Verify specified `--config` file exists and is writable. Verify repository directory and branch exist.
4. **Main Configuration & Inclusion Verification:** Verify `--nginx-main-conf` file exists, is readable, and contains a syntactically complete active `include` directive with exactly one path argument and a terminating semicolon, referencing the target `--config` vhost file path (or resolving symlinks/relative paths cleanly). Malformed include lines do not count as a match; if no valid include references the target vhost, abort immediately fail-closed.
5. **Command Check:** After path/include validation and before state capture, backup, or pull, verify required binaries (`git`, `flock`, `sha256sum`, and test/reload commands) are available/executable; missing `sha256sum` must fail preflight, not trigger a post-pull rollback. `git` and `flock` are necessarily invoked earlier to locate/acquire the metadata lock, and their failures must also fail closed.
6. **State Capture:** Record exact pre-deploy commit hash:
   `PRE_HEAD=$(git rev-parse HEAD)`
7. **Configuration Backup:** Create timestamped backup of the active configuration file as a separate snapshot (not the working staging file):
   `BACKUP_PATH="${CONFIG_PATH}.bak.$(date +%Y%m%d%H%M%S)"`
   `cp -p "$CONFIG_PATH" "$BACKUP_PATH"`
   *Failure boundary:* If preflight halts or pull fails, the active configuration is left completely untouched (though this separate backup file may already exist). No git reset is performed for pre-pull failures.

### 3.2 Phase 1: Core Five-Step Deployment Sequence
Following successful preflight:
1. **Step 1 — Fast-Forward Pull (`git pull --ff-only`):**
   Execute `git pull --ff-only origin "$BRANCH"`.
   Immediately record expected revision within this same step on success:
   `PULLED_HEAD=$(git rev-parse HEAD)`
   *If pull fails:* Halt immediately. Active configuration is left completely untouched (though preflight backup exists); no git reset is executed; release lock and exit 1.
   *If pull succeeds but `$PULLED_HEAD` cannot be captured:* Halt before hashing or active-config modification, emit an explicit manual-recovery diagnostic, and do not reset because the pulled revision cannot be proven. The preflight backup may exist; the repository may have advanced and must not be destructively reset without a known `PULLED_HEAD`.
2. **Step 2 — Asset Hash Computation:**
   Compute 8-character SHA-256 short hashes for shipped assets:
   - `CSS_HASH=$(sha256sum gmdl-dark.css | cut -c1-8)`
   - `UI_HASH=$(sha256sum gmdl-ui.js | cut -c1-8)`
   - `FEAT_HASH=$(sha256sum gmdl-feat.js | cut -c1-8)`
   *If hashing fails:* Invokes the **Automatic Safe Rollback Routine** (Step 2 is a post-pull failure).
3. **Step 3 — Fail-Closed Atomic Config Update:**
   - **Same-Directory Staging:** Create temporary staging file in the active vhost configuration's own directory (e.g. `"${CONFIG_PATH}.tmp.$$"`) to guarantee atomic same-filesystem rename (`mv`).
   - **Ownership & Mode Preservation:** Inspect original owner, group, and permissions (`stat -c '%u:%g %a' "$CONFIG_PATH"`) and apply them to the staged file (`chown` / `chmod`); fail closed if metadata preservation cannot be confirmed.
   - **Exact Token Occurrence Validation:** Inspect the active configuration before replacement and require exactly one current `sub_filter` asset-version token occurrence for each of `gmdl-dark.css`, `gmdl-ui.js`, and `gmdl-feat.js` (matching the reference structure in `openresty-vhost-example.conf`). If any token count is zero, multiple, or unexpected, fail closed immediately without mutating or replacing the active configuration file.
   - **Atomic Replacement:** Atomically replace configuration file:
     `mv "$TMP_CONFIG" "$CONFIG_PATH"`
4. **Step 4 — Real Assembled Configuration Syntax Verification (`nginx -t`):**
   Execute syntax test against the real assembled configuration context that includes the target vhost, rather than an isolated vhost fragment, using a safe argument array (avoiding fragile unquoted parameter expansions and supporting `set -u` strict mode):
   ```bash
   NGINX_ARGS=(-t -c "$NGINX_MAIN_CONF")
   if [[ -n "${NGINX_PREFIX:-}" ]]; then
     NGINX_ARGS+=(-p "$NGINX_PREFIX")
   fi
   "$NGINX_BIN" "${NGINX_ARGS[@]}"
   ```
   *If syntax test fails:* Trigger the **Automatic Safe Rollback Routine**.
5. **Step 5 — Graceful Reload:**
   Execute service reload by invoking the validated executable path and safe argument array:
   ```bash
   "$RELOAD_CMD" "${RELOAD_ARGS[@]}"
   ```
   *(Default args: `-s reload`; custom args e.g. `systemctl` with `reload` and `openresty`). Never uses `eval` or unquoted string splitting.*
   *If reload fails:* Trigger the **Automatic Safe Rollback Routine**.

---

## 4. Automatic Safe Rollback & Recovery Routine

When an error occurs during Step 2 (hashing), Step 3 (config update), Step 4 (syntax test), or Step 5 (reload):
1. **Atomic Restore of Configuration:**
   Do not overwrite the active configuration directly with a non-atomic `cp -p`. Execute atomic restoration staging in the active vhost's own directory, verifying metadata and byte-for-byte identity against the preflight backup snapshot:
   ```bash
   RESTORE_TMP="${CONFIG_PATH}.rollback.tmp.$$"
   cp -p "$BACKUP_PATH" "$RESTORE_TMP"
   stat_orig=$(stat -c '%u:%g %a' "$CONFIG_PATH" 2>/dev/null || stat -c '%u:%g %a' "$BACKUP_PATH")
   chown "${stat_orig% *}" "$RESTORE_TMP"
   chmod "${stat_orig#* }" "$RESTORE_TMP"
   # Byte-exact verification and metadata equality
   if ! cmp -s "$RESTORE_TMP" "$BACKUP_PATH"; then
     echo "FATAL: rollback staging content differs from preflight backup snapshot" >&2
     exit 1
   fi
   if [[ $(stat -c '%u:%g %a' "$RESTORE_TMP") != "$stat_orig" ]]; then
     echo "FATAL: rollback staging metadata mismatch against target configuration" >&2
     exit 1
   fi
   mv "$RESTORE_TMP" "$CONFIG_PATH"
   ```
   If restoration staging, byte-exact `cmp -s` verification, metadata validation, or atomic rename fails, log a critical error and halt fail-closed.
2. **Conditional Safe Code Reset:**
   - Inspect post-pull worktree cleanliness: check if `git status --porcelain` is empty.
   - Inspect current HEAD: verify HEAD equals the recorded `$PULLED_HEAD`.
   - **If clean and expected:** Execute `git reset --hard "$PRE_HEAD"`.
   - **If dirty or unexpected:** **Refuse automatic reset**, emit a critical recovery warning, and do NOT destroy uncommitted or unexpected changes. Never blindly reset a dirty tree. Never rely on `ORIG_HEAD`.
3. **Verify Restored Configuration Syntax:**
   Re-run real assembled configuration syntax test on the restored configuration using the same safe argv array (`"$NGINX_BIN" "${NGINX_ARGS[@]}"`).
4. **Restore Service Traffic:**
   Execute `"$RELOAD_CMD" "${RELOAD_ARGS[@]}"` to ensure live traffic remains served by the verified configuration.
5. **Release Concurrency Lock:**
   Lock is cleared via EXIT trap on all paths.
6. **Report & Exit:**
   Print diagnostic report detailing rollback status and exit with non-zero exit code (`1`).

---

## 5. Mock Testing Matrix & Offline Verification

Production execution is **NOT authorized** by the current scope.
The script must be verified offline via a deterministic mock test harness validating at least 12 distinct conditions:
1. `MOCK-01`: Standard successful deployment executes in exact five-step order (preflight → pull + record PULLED_HEAD → all three asset hashes → config → test → reload); every hash precedes config replacement.
2. `MOCK-02`: Concurrency lock contention halts second instance cleanly.
3. `MOCK-03`: A read-only lock on the verified Git metadata directory from `git rev-parse --absolute-git-dir` is released after success/failure, leaves porcelain clean, creates no lock file, and the dry-run subcase creates no backup, config write, pull, reload, reset, or filesystem artifact.
4. `MOCK-04`: Dirty working tree halts preflight with zero file mutations and zero reset; assert metadata-lock acquisition precedes the dirty check. Also inject a failing `git status --porcelain` that emits no stdout and require a specific fail-closed refusal, with no pull/backup or other deployment effects. During dry-run, perturb a tracked file's mtime, then prove Git index bytes and metadata remain unchanged and status runs with `GIT_OPTIONAL_LOCKS=0`.
5. `MOCK-05`: Pull failure halts before config modification; active config unchanged; no git reset performed. Also inject a successful pull followed by `git rev-parse HEAD` failure; require stop before hashing/config changes and explicitly refuse reset when `PULLED_HEAD` is unknown.
6. `MOCK-06`: Post-pull asset hashing failure (Step 2) invokes safe rollback routine.
7. `MOCK-07`: Staging file created in vhost directory with verified same-filesystem atomic rename and owner/group/mode preservation for both deployment staging (`.tmp.$$`) and rollback restoration staging (`.rollback.tmp.$$`). Rollback restoration verifies byte-for-byte identity against backup snapshot (`cmp -s`) and metadata equality before atomic rename.
8. `MOCK-08`: Token cardinality violation (zero, multiple, or unexpected current `sub_filter` asset-version token count for `gmdl-dark.css`, `gmdl-ui.js`, or `gmdl-feat.js`; expected count is exactly 1 per asset) halts config update fail-closed before active file is modified.
9. `MOCK-09`: Syntax test verifies real assembled configuration arguments via safe argv array (`-t -c "$NGINX_MAIN_CONF"` and optional `-p "$NGINX_PREFIX"`), ensuring target vhost inclusion is verified. Subchecks cover unset, empty, and whitespace-containing prefixes; malformed include text with trailing junk; non-executable `--nginx-bin` and `--reload-cmd`; missing `sha256sum` with positive lock-before-status evidence and no `PRE_HEAD` capture; and syntax-failure recovery. All invalid-input cases must fail before pull or backup/config mutation.
10. `MOCK-10`: Simulated reload failure triggers atomic config restoration (staged, `cmp -s` verified, atomic rename) and recovery reload using `"$RELOAD_CMD" "${RELOAD_ARGS[@]}"` (asserting exact argv array, including multi-argument systemctl-style reload invocations).
11. `MOCK-11`: Safe code reset correctly returns to `$PRE_HEAD` on clean tree matching `$PULLED_HEAD`.
12. `MOCK-12`: Code reset is safely **refused** when tree is dirty or current HEAD differs from `$PULLED_HEAD`.

---

## 6. Observable Acceptance Criteria

- **AC-DEP-01:** Preflight acquires exclusive `flock` on a read-only descriptor for the verified Git metadata directory before checking cleanliness, leaves no lock file, and explicitly requires `GIT_OPTIONAL_LOCKS=0 git status --porcelain` to exit successfully with empty output; a status command failure fails closed even if stdout is empty, and the Git index is not refreshed. Preflight verifies paths and a complete valid `include` directive, then verifies required command availability/executability before state capture, backup, or pull. Dry-run uses the same read-only directory lock and creates no backup, configuration write, or Git index mutation.
- **AC-DEP-02:** Pull failure exits immediately leaving active configuration untouched; no git reset executed. If pull succeeds but `PULLED_HEAD` capture fails, stop before hashing/config mutation, report manual review, and do not reset an unverified revision.
- **AC-DEP-03:** Deployment core sequence strictly follows five numbered steps: (1) `git pull --ff-only` with immediate recording of `$PULLED_HEAD` → (2) asset hashing → (3) atomic config staging → (4) real assembled config syntax test via safe argv array (`NGINX_ARGS=(-t -c "$NGINX_MAIN_CONF")` with conditional `${NGINX_PREFIX:-}`) → (5) reload via safe argv array `"$RELOAD_CMD" "${RELOAD_ARGS[@]}"`.
- **AC-DEP-04:** Post-pull failure during Step 2 (hashing), 3 (config update), 4 (syntax test), or 5 (reload) automatically restores preflight configuration via atomic restore staging in vhost directory with verified byte-for-byte identity (`cmp -s`), metadata equality, and atomic rename, then attempts recovery reload.
- **AC-DEP-05:** Staging file is created in target vhost directory, preserves file ownership and permissions, and validates exact asset token cardinality (exactly one current `sub_filter` asset-version token per each shipped asset: `gmdl-dark.css`, `gmdl-ui.js`, `gmdl-feat.js`; zero or multiple fails) before atomic replacement.
- **AC-DEP-06:** Syntax verification tests real assembled configuration context (`-c NGINX_MAIN_CONF [-p NGINX_PREFIX]`), asserting full argument vector in offline mock harness, including unset, empty, and whitespace-containing prefix cases, as well as multi-argument custom reload commands.
- **AC-DEP-07:** Automatic git reset executes only if the post-pull worktree is completely clean and matches `$PULLED_HEAD`; safely refuses reset on dirty tree or revision mismatch.
- **AC-DEP-08:** The Git metadata directory lock is acquired through a read-only descriptor, is held through the full operation, and is demonstrably released on every exit path via EXIT trap; no persistent lock file is created.
- **AC-DEP-09:** Offline mock harness passes all 12 conditions deterministically, including missing-`sha256sum` preflight with lock-order/no-state-capture proof, status-failure fail-closed, and dry-run Git-index invariance.
- **AC-DEP-10:** `bash -n deploy.sh` and `bash -n scripts/deploy-mock.sh` both pass syntax validation (2026-10-13 05:53 UTC+08).
