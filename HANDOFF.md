# Project Handoff & Coordinator Transition
<!-- Project: gmdl-theme-pack-agent · Branch: project/antigravity-overhaul -->
<!-- Last updated: 2026-10-13 06:38 (both final reviews passed; hourly read-only schedule active) -->

## 1. Current State Summary

- **Workspace Path:** `/workspace/gmdl-theme-pack-agent`
- **Git Branch:** `project/antigravity-overhaul` (Mainline)
- **Commissioned PoC Branch:** `poc/ia-audio-discovery` (Isolated Current Run)
- **Hourly Status Check:** Active recurring schedule, interval 3600 seconds, timezone `Asia/Taipei`; read-only checks of both worktrees only. It must not edit files, deploy, access external services, commit, or push. Service-confirmed at 2026-10-13 06:34:41 UTC+08.
- **Baseline Git HEAD:** `126853a`
- **Worktree State:** Mainline Task 4 final acceptance: enhancement 29/29, baseline 8/8, 11 authentic before/after pairs, and five viewport touch/keyboard/geometry checks; `gmdl-feat.js` unchanged. Task 5 v2.1 mocks pass 12/12 and final smoke passed 10/0 at 06:38:05, including index byte+metadata invariance, fail-closed pulled-HEAD capture, and missing-sha-before-state-capture. Independent final deployment review passed; no production execution is authorized. Task 6 remains isolated at `/workspace/gmdl-theme-pack-ia-agent`, branch `poc/ia-audio-discovery` based at `126853a`; v2.1 tests cover arbitrary-URL rejection, path-space encoding, immutable allow-list candidates, native pause/end, malformed/error paths, and stale prior Promise resolve/rejection after the new track is already playing; latest suite passes 10/10. Independent IA final review passed; owner publication review remains pending. No live Archive.org requests were made.
- **Active Task Phase:** Tasks 1–5 are locally green and independently reviewed; Task 6 implementation/tests are locally green and independently reviewed on the isolated worktree, pending the required owner review before branch publication. No cross-branch merge is planned; IA must never enter `main` or the mainline branch.
- **Active AI Model:** Gemini 3.8 Flash (Medium). Operational and healthy.
- **Model Routing Log:** Maintained at [`docs/spec/progress/model-routing.log`](docs/spec/progress/model-routing.log).
- **Subagent Delegation Run Summary:** The final read-only deployment review passed with no medium/high findings; its low helper-status hygiene observation was addressed by disabling optional locks in all six fixture cleanup queries. Deployment mocks pass 12/12 and final smoke passes 10/0. The final IA review found no code/test blocker; both stale resolve and reject now settle after current `playing`, and the suite passes 10/10. No live external requests or production actions were made.

---

## 2. Next Immediate Task & Commissioned Work Breakdown

**Completed Task 3 — Quality Test Plan & Smoke Automation (Phase 2)**
- Stage 7 accepted at 04:20 UTC+08; RTM maps all 68 source acceptance IDs.
- `scripts/smoke.sh` passed current-phase checks (7 passed, 0 failed) at 04:23; fail-closed conditional wiring probes passed at 04:24. Temporary stubs were removed.
- A separate 04:26:14 coordinator-executed/reported smoke run again passed 7/0, documented the 8/0/0 baseline, 31 scanned text files and 55/23 valid links, confirmed `gmdl-feat.js` unchanged, and correctly flagged future suites as not implemented; it was not an agent run.

✅ **Completed Task 4 — Mainline UI Enhancements (Phase 3)** *(WP-B, WP-C, WP-D)*
- Final independent acceptance passed after hitbox remediation: enhancement 29/29, baseline 8/8, full smoke 10/0, JS syntax and whitespace checks; `gmdl-feat.js` unchanged.
- The initial 320×568 pointer overlap was fixed by scoped CSS; the final 1px/2px swatch-border inconsistency was corrected and remeasured. All 30 visible controls per viewport are ≥44×44px; all ten swatches pass four-edge hit tests at five viewports. Final local visual gate passed with all 11 paired real-page captures, geometry/pointer checks and browser keyboard tests. The dark-glass 320×568 pair has only 50 RGB antialiasing pixels different (mean 0.00044); no visible regression. Evidence: `/workspace/gmdl-theme-pack-visual-evidence/`.

✅ **Completed Task 5 — Reversible Deployment Automation (Phase 4)** *(WP-A; local-only and mock-only)*
- `deploy.sh` implements read-only Git metadata-directory locking; `GIT_OPTIONAL_LOCKS=0` status checks; fail-closed status/HEAD capture; path/include and pre-backup/pull command checks; index-invariant dry-run; exact asset-token cardinality; atomic staging/rollback; and conditional reset.
- TDD evidence: initial expected-red 12/12 failures were solely due to the absent target; v2.1 red isolated MOCK-03 index-write and MOCK-05 unknown pulled-HEAD cases; after fixes, `bash -n` and MOCK-01..12 pass 12/12, and final smoke passed 10/0 at 06:38:05. Do not run against production or use SSH.
- Seven host inputs remain unverified for any later live deployment; no production execution in this phase.

👉 **Commissioned Task 6 — Isolated IA PoC Branch Implementation (Phase 5)** *(implementation/test and independent review green; owner publication review pending)*
- **Branch & Worktree:** Isolated worktree `/workspace/gmdl-theme-pack-ia-agent`, branch `poc/ia-audio-discovery` directly from baseline `126853a`, currently containing only the two PoC files (never accessing `/workspace/gmdl-theme-pack-poc`).
- **Deliverables:** Standalone adapter module `gmdl-ia.js` and 10 deterministic unit tests in `gmdl-ia.test.js`.
- **Testing:** Original TDD red proof 0/10 when the module was absent; audit-driven regression red phases reproduced URL bypass and whitespace trimming; latest `node --check` and 10/10 v2.1 suite pass. Tests use fetch stubs only and cover malformed responses, rejected JSON, immutable allow-list candidates, native pause/end, sync/async errors, and stale prior Promise resolve/reject that arrive only after a newer track is already playing. No live network calls.
- **Audit:** Two medium issues and low follow-up coverage/path encoding issues from read-only reviewers have been remediated; the final independent re-review passed with no remaining code/test blocker.
- **Publication & Isolation:** Not yet pushed; publication follows coordinator code acceptance and owner review/approval of the exact final payload. **Absolute isolation invariant:** Zero IA implementation code on `project/antigravity-overhaul` or publication target `main`; absolute no-merge and no-push to `main`.

---

## 3. Consolidated Future Deployment Input Checklist

> [!NOTE]
> **Action Boundary Notice:**
> Do **NOT** ask the project owner for these credentials now. The local script and mock implementation are complete; no production deployment is authorized. Only if the owner later authorizes live deployment will the following seven consolidated inputs be required:

| # | Deployment Input Parameter | Purpose | Status |
|---|---|---|---|
| 1 | **Target Hostname / URL** | Remote target domain or IP (e.g. `music.archfox.eu.cc`) | **currently BLOCKED/UNVERIFIED** |
| 2 | **Authorized SSH Access Method & User** | Remote user, port, and SSH key identity for server connection | **currently BLOCKED/UNVERIFIED** |
| 3 | **Remote Repository Clone Path** | Target absolute path on the server where the repo is cloned | **currently BLOCKED/UNVERIFIED** |
| 4 | **Target Vhost Include File Path (`--config`)** | Absolute path to the active site vhost conf file to update with asset version hashes | **currently BLOCKED/UNVERIFIED** |
| 5 | **Main Nginx/OpenResty Config Path (`--nginx-main-conf`)** | Absolute path to top-level configuration containing `events`/`http` contexts and including the target vhost | **currently BLOCKED/UNVERIFIED** |
| 6 | **Optional Nginx Prefix Path (`--nginx-prefix`)** | Optional working prefix directory (`-p`) for relative configuration directives | **currently BLOCKED/UNVERIFIED** |
| 7 | **Nginx Binary Path & Reload Executable (`--nginx-bin` / `--reload-cmd`)** | Verified executable path used to test syntax and reload service (`--reload-arg` collected into argv array) | **currently BLOCKED/UNVERIFIED** |

### 3.1 Canonical Five-Step Core Deployment Sequence & Rollback Contract

When a future live deployment is specifically authorized, `deploy.sh` executes lock-first preflight (`flock` on a read-only descriptor for the verified Git metadata directory from `git rev-parse --absolute-git-dir`, before checking cleanliness; no lock file is created), then checks porcelain, verifies `sha256sum` and required executables before backup/pull, captures `$PRE_HEAD`, verifies the main config contains a complete valid include directive for the target vhost, and creates a timestamped backup. Dry-run uses the same read-only directory lock and creates no file artifacts. The exact five numbered core steps follow:
1. `git pull --ff-only`: Fast-forward pull of target branch, immediately followed within this same step by recording `PULLED_HEAD=$(git rev-parse HEAD)` on success. (If pull fails, halt immediately; active configuration is left completely untouched, although the timestamped preflight backup file may already exist, and NO git reset is performed).
2. **Compute Asset Hashes:** Compute short SHA-256 asset hash query-strings (`?v=<hash>`) for shipped assets (`gmdl-dark.css`, `gmdl-ui.js`, `gmdl-feat.js`).
3. **Fail-Closed Atomic Config Update:** Staging file replacement created in target vhost directory (`${CONFIG_PATH}.tmp.$$`, guaranteeing same-filesystem atomic `mv`), verifying and preserving file ownership and permissions (`stat` + `chown`/`chmod`), and verifying exact asset token cardinality (exactly one current `sub_filter` asset-version token each for `gmdl-dark.css`, `gmdl-ui.js`, and `gmdl-feat.js`; zero, multiple, or unexpected counts fail closed before active file is replaced).
4. `nginx -t`: Validate configuration syntax in real assembled configuration context using a safe bash argument array:
   ```bash
   NGINX_ARGS=(-t -c "$NGINX_MAIN_CONF")
   if [[ -n "${NGINX_PREFIX:-}" ]]; then
     NGINX_ARGS+=(-p "$NGINX_PREFIX")
   fi
   "$NGINX_BIN" "${NGINX_ARGS[@]}"
   ```
5. **Graceful Service Reload:** Trigger service reload via safe argv array: `"$RELOAD_CMD" "${RELOAD_ARGS[@]}"` (defaults to `"$NGINX_BIN" -s reload` or custom e.g. `systemctl reload openresty`).

**Deterministic Safe Rollback Routine:**
If any post-pull failure occurs during Step 2 (hashing), Step 3 (config update), Step 4 (syntax test), or Step 5 (reload):
- Immediately stage active configuration restoration from the preflight backup into a temporary staging file in the target vhost directory (`${CONFIG_PATH}.rollback.tmp.$$`), preserve ownership/mode, verify byte-for-byte content identity (`cmp -s "$RESTORE_TMP" "$BACKUP_PATH"`) and metadata equality against target configuration, and atomically rename into place (`mv`). Fail closed and log if unverified.
- Conditionally reset code to `$PRE_HEAD` ONLY if the post-pull worktree is completely clean (`git status --porcelain` is empty) AND current HEAD still equals `$PULLED_HEAD`; refuse destructive reset if dirty or if current HEAD differs from `$PULLED_HEAD`. Never use `ORIG_HEAD` or reset unknown state.
- Test restored config syntax in real assembled context using the safe argv array (`"$NGINX_BIN" "${NGINX_ARGS[@]}"`) and attempt recovery service reload via `"$RELOAD_CMD" "${RELOAD_ARGS[@]}"`.
- Release lock on all exits via EXIT trap. (Governed by [`docs/spec/modules/deploy.sh.md`](docs/spec/modules/deploy.sh.md) with 12 mock test conditions).

### 3.2 Canonical Preference Contract & Test Suite Separation
- **Strict Format:** Literal prefix `GMDL1:` followed by compact JSON envelope. Keys serialized deterministically: envelope `"v"`, `"settings"`; settings `"theme"`, `"accent"`, `"bg"`, `"style"`, `"text"`, `"lyric"`, `"glow"`, `"blur"`, `"glass"`.
- **Duplicate Key Rejection:** Token-aware scanner rejects duplicate member names fail-closed at envelope and settings levels without third-party dependencies or `eval()` / `Function()`.
- **Accessible Feedback & Invariance Proof:** On invalid import payload, feedback is presented strictly through dedicated status node `#gmdl-import-status` (`role="status"`, `aria-live="polite"`). All other application state remains completely unchanged: `localStorage` (`gmdl-ui`, `gmdl-bgimg`), active classes (`.dark`, `.glass`), CSS custom properties, and settings controls. Automated tests assert error text on `#gmdl-import-status` while snapshotting all storage and remaining settings DOM to prove 100% identity.
- **Concrete UI Journey (Planned Interface Contract):** Existing baseline code contains launcher `#gmdl-ui-btn` and `#gmdl-ui-panel`; export/import controls (`#gmdl-export-code`, `#gmdl-import-code`, `#gmdl-import-btn`, `#gmdl-import-status`) are to-be-implemented in Task 4. Personalization floating region on source generates/copies code; target floating region pastes code and applies immediately without reload. Background image excluded with visible notice.
- **Test Suite Separation & Status Accounting (Executed vs Planned):**
  - **Executed in this phase:** Baseline 8 unit tests in `gmdl-ui.test.js` pass (8 pass / 0 fail / 0 skipped).
  - **Planned future suites (NOT executed / no code or harness exists):** New feature regressions in `gmdl-ui-enhancements.test.js`; 12 offline deployment mock test conditions (`MOCK-01` through `MOCK-12`); 10 isolated IA PoC unit tests in `gmdl-ia.test.js`. Never claim feature work or mock cases were executed in this phase.

---

## 4. Model Routing & Cadence Checklist

- **Hourly Self-Check Schedule (Coordinator-Verified):** An active hourly self-check schedule is confirmed expiring at `2026-10-13 06:30 Asia/Taipei` (UTC+08). Runs are strictly **report-only**: they report selected model, provider notices, and availability status, but must **never** switch the active model, send background work, modify files, or trigger fallback installation. No new schedule shall be created, edited, or extended.
- **Phase Boundary Verification:** Inspect model picker and provider notice status at the start of Task 3 and subsequent phases.
- **Log switches:** Record every model switch in `docs/spec/progress/model-routing.log` with timestamp (+08), from→to, reason, and provenance (`app-verified` vs `user-reported`).
- **Community Free-Model Fallback:**
  - Status: **NOT TRIGGERED** (Install nothing now).
  - If Gemini Flash becomes unavailable: inspect `delhiiitian/antigravity-free` README/scripts first, then `999Toth999/free-antigravity`.
  - Use ONLY official provider free-tier key sources; never log secrets.
  - Community fallback is strictly for drafting/decomposition/routine implementation; final independent review waits for Claude or Gemini 3.8 Flash.
  - Record trigger/not-triggered status and effects in `model-routing.log`.

---

## 5. Strict Operating Boundaries & Invariants

1. **Workspace Isolation:** Confine all work strictly to `/workspace/gmdl-theme-pack-agent`. Never read or modify `/workspace/gmdl-theme-pack`, `/workspace/gmdl-theme-pack-project`, or `/workspace/gmdl-theme-pack-poc`.
2. **Upstream Source Code:** Never modify upstream Go code. All enhancements are delivered via reverse proxy injection.
3. **No Unreviewed Stages:** Never create `scripts/smoke.sh` before `docs/project/07-quality-test-plan.md` is reviewed.
4. **Test Suite Baseline:** `gmdl-ui.test.js` exercises existing accent rules and must remain untouched at 8 pass / 0 fail / 0 skipped.
5. **IA Branch Commissioning & Isolation:** IA PoC is commissioned for this run on branch `poc/ia-audio-discovery` ([`docs/spec/IA-POC-BRANCH-PLAN.md`](docs/spec/IA-POC-BRANCH-PLAN.md)), branched freshly from `126853a`. Zero IA code on `main`; never merge into `main`.
6. **Publication Target:** Authorized targets are `puerjeer/gmdl-theme-pack` branch `main` and branch `poc/ia-audio-discovery` via host-side transfer. Autonomous execution is authorized; no ordinary approval checkpoints.

---

## 6. Verification Commands

```bash
# Whitespace and formatting check
git diff --check

# Syntax checks on production JS assets
node --check gmdl-ui.js
node --check gmdl-feat.js

# Baseline unit test execution
node --test gmdl-ui.test.js

# Verification of documentation and spec tree
find docs -type f | sort
```

---

## 7. Blocked / Unverified Checks Summary

- Local upstream UI loopback verification: **baseline verified; after-implementation comparison pending** (official digest-verified v1.1.1 binary and loopback-only nginx proxy are running; injection and 11 baseline captures are recorded).
- Reference/production `nginx -t`: **currently BLOCKED/UNVERIFIED** (local nginx-extras is installed and the isolated visual-test config passed syntax validation; the production host/include context is unavailable).
- `https://music.archfox.eu.cc/music`: **currently BLOCKED/UNVERIFIED** (Returns 404).
- Physical mobile device verification: **currently BLOCKED/UNVERIFIED** (Planned simulated viewport checks; not run in this phase).
- Production deployment execution: **currently BLOCKED/UNVERIFIED** (Server credentials pending).
