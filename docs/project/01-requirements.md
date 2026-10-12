# 01 — Requirements
<!-- Stage 1 of 8 governance documents -->
<!-- Project: gmdl-theme-pack-agent · Branch: project/antigravity-overhaul -->
<!-- Last updated: 2026-10-13 (Documentation Scope Rebaseline) -->

> [!NOTE]
> **Rebaseline Notice (2026-10-13):**
> This document defines authoritative project requirements in accordance with owner instructions.
> Mainline focus is strictly concentrated on four core product work packages (A: Deployment Automation,
> B: Shared Glass Styling, C: Mobile/Keyboard Accessibility, D: Preference Export/Import) plus project documentation and tests.
> **Internet Archive (IA) audio discovery is commissioned for this active run** as an isolated deliverable on its own
> dedicated branch ([`docs/spec/IA-POC-BRANCH-PLAN.md`](../spec/IA-POC-BRANCH-PLAN.md) targeting `poc/ia-audio-discovery`),
> strictly isolated from `main`. Specifications are canonicalized under `docs/spec/`. No production code has started.

---

## 1. Project Purpose & SMART Goal

### 1.1 Purpose
The `gmdl-theme-pack-agent` project hardens, refines, and delivers the reverse-proxy-injected
frontend theme and personalization suite for [go-music-dl](https://github.com/guohuiyuan/go-music-dl),
providing reversible deployment automation, cross-mode glass styling, mobile accessibility,
portable preferences, and an isolated browser-side audio discovery proof-of-concept on a dedicated branch.

### 1.2 SMART Project Goal
Deliver a fully verified, regression-free frontend theme pack across the four mainline work packages
on branch `project/antigravity-overhaul` (ready for host-side publication to `main`), alongside an independently
tested, isolated PoC branch (`poc/ia-audio-discovery`) passing all 10 deterministic IA unit tests,
by an estimated planning target of **2026-10-13 18:00 UTC+08**.
*(Disclaimer: This deadline is a planning estimate for this autonomous run, never an owner commitment).*

### 1.3 Project Assumptions
1. **Upstream Immutability:** Upstream `go-music-dl` Go source code is treated as an immutable external binary; all UI enhancements must be deliverable via reverse-proxy injection.
2. **Local Development Isolation:** No live production server access or credentials exist; all deployment scripts and reverse-proxy configurations must be verified using planned local mock harnesses and syntax checkers after the script and harness exist. Currently, no deployment script or mock harness exists, and the 12 mock test conditions remain planned and unexecuted in this phase.
3. **Storage Availability:** Standard browser `localStorage` is accessible and writable in client browsers.
4. **Branch Decoupling:** Mainline `project/antigravity-overhaul` must never contain IA production code; IA PoC development occurs solely on a fresh worktree/branch `poc/ia-audio-discovery`.

### 1.4 Open Questions
1. **Production Host Parameters:** Specific remote SSH user, host key, and server paths remain unconfigured; consolidated checklist is tracked in `HANDOFF.md` for future live deployment.
2. **Upstream Release Binary Port:** Whether upstream binary defaults to port 8080 or another port under `./music-dl web` without flags remains unverified in official excerpts; loopback test procedure will be defined in Stage 7.

---

## 2. Background & Architecture Context

The theme pack is delivered to client browsers via OpenResty/nginx `sub_filter` and static location
directives without modifying upstream Go source code.
The repository maintains:

| File | Role |
|---|---|
| `gmdl-dark.css` | Stylesheet supplying dark theme variables, component styles, and glass effects |
| `gmdl-ui.js` | UI enhancement module managing personalization panel, settings persistence, and DOM mutations |
| `gmdl-feat.js` | Feature pack module adding daily recommend song shortcuts and load-more behavior (unchanged) |
| `openresty-vhost-example.conf` | Reference reverse-proxy virtual host configuration for OpenResty/nginx |

### Upstream Verification & Provenance Context
- Upstream documentation confirms `./music-dl web` and default path `/music`. (Official README excerpts did not independently prove default port 8080).
- GitHub official v1.1.1 release API lists `go-music-dl_linux_amd64.tar.gz` with digest `sha256:be7b828096a23b7401d69649484ece667ed588116a6039bb8f55e0f4df7c5949`. The legacy digest found in prior task context (`1a4fc4d0fa67c0e0d73fb6cebd8918c1e6998f2f23c7ee19ebacbb27f5f07d0a`; provenance unverified) does NOT match and must never be used to validate or run assets. Before any future execution, download-time local `sha256sum` verification of the archive against the official GitHub digest is strictly required.
- No binary has been downloaded or executed. Upstream UI loopback testing is planned only after Stage 7 documents and reviews the procedure; the live public site and production deployment remain separately **currently BLOCKED/UNVERIFIED**.

---

## 3. Functional Requirements

### FR-01 — Work Package A: Reversible Deployment Automation (`deploy.sh`)

The project **shall** provide an automated shell script (`deploy.sh`) establishing a robust, reversible deployment workflow:

- **FR-01a — Preflight Safety Integrity:** Before initiating deployment mutations, `deploy.sh` must:
  1. Acquire an exclusive single-instance process lock before checking tree cleanliness (preventing concurrency races). The lock path must be derived from Git metadata (`git rev-parse --git-path deploy.lock` or verified non-worktree metadata path), ensuring `git status --porcelain` is left completely clean. Ensure lock is released on every exit path via an EXIT trap.
  2. Require a clean git working tree (`git status --porcelain` is empty). Abort immediately if dirty.
  3. Verify branch, repository path, and `--config` file path exist (without guessing default production paths).
  4. Verify `--nginx-main-conf` (or env `NGINX_MAIN_CONF`) exists, is readable, and contains an active `include` directive referencing `--config`. If the main config does not include the target vhost, abort immediately fail-closed. Verify optional `--nginx-prefix` (or env `NGINX_PREFIX`) directory if specified.
  5. Verify required binaries (`git`, `sha256sum`, and verified executable paths `--nginx-bin` / `--reload-cmd`).
  6. Capture exact pre-deploy commit hash (`PRE_HEAD=$(git rev-parse HEAD)`).
  7. Create a timestamped backup of the active configuration file (`vhost.conf.bak.<timestamp>`).
- **FR-01b — Strict Five-Step Core Execution Sequence:** Following preflight, execute in exact linear order:
  1. `git pull --ff-only`: Fast-forward pull of target branch, immediately followed within this same step by recording `PULLED_HEAD=$(git rev-parse HEAD)` on success. (If pull fails, exit non-zero immediately; active configuration is left completely untouched, although the timestamped preflight backup file may already exist, and NO git reset is performed).
  2. Compute short SHA-256 asset hash query-string versions (`?v=<hash>`) for `gmdl-dark.css`, `gmdl-ui.js`, and `gmdl-feat.js`.
  3. Fail-closed atomic configuration update via temporary staging file created in the target vhost directory (same-filesystem atomic `mv`). The script verifies and preserves original owner, group, and permissions mode (fail-closed if cannot be preserved) and verifies exact asset token cardinality (exactly one current `sub_filter` asset-version token each for `gmdl-dark.css`, `gmdl-ui.js`, and `gmdl-feat.js`; zero, multiple, or unexpected counts fail closed) before atomic replacement.
  4. Test real assembled configuration syntax via `nginx -t` using safe argv array (`"$NGINX_BIN"` with `NGINX_ARGS=(-t -c "$NGINX_MAIN_CONF")` and conditional `${NGINX_PREFIX:-}`), asserted in the planned mock harness.
  5. Graceful service reload via safe argv array (`"$RELOAD_CMD" "${RELOAD_ARGS[@]}"`).
- **FR-01c — Deterministic Safe Rollback Routine:** If any post-pull failure occurs during hashing (Step 2), config update (Step 3), syntax testing (Step 4), or reload (Step 5):
  1. Atomically restore active configuration: copy backup snapshot to restore staging file in target vhost directory (`${CONFIG_PATH}.rollback.tmp.$$`), preserve owner/group/mode, verify byte-for-byte content identity (`cmp -s "$RESTORE_TMP" "$BACKUP_PATH"`), verify metadata equality against target configuration, and atomically rename into place (`mv`). Fail closed and log if restore staging, byte-exact verification, or rename cannot be verified.
  2. Conditionally reset working tree to `$PRE_HEAD` ONLY if the post-pull worktree is completely clean (`git status --porcelain` is empty) AND current HEAD still equals the recorded `$PULLED_HEAD`; refuse reset if dirty or if current HEAD differs from `$PULLED_HEAD`. Never use `ORIG_HEAD` or reset unknown state.
  3. Verify restored configuration syntax in the real assembled context via `nginx -t` using the safe argv array (`"$NGINX_BIN" "${NGINX_ARGS[@]}"`).
  4. Attempt service reload to restore live traffic using `"$RELOAD_CMD" "${RELOAD_ARGS[@]}"`.
  5. Return non-zero error status.
- **FR-01d — Offline Mock Verification:** The script shall be verified offline via a planned deterministic mock harness covering all 12 distinct failure/success conditions (`MOCK-01` through `MOCK-12`). Production execution is **not** authorized. In this phase, the 12 mock cases remain planned specifications only (unexecuted).

### FR-02 — Work Package B: Shared Glass Styling (Dark & Light Modes)

- **FR-02a — Dual-Mode Glass:** Provide a shared glass styling system (`backdrop-filter`, translucent surfaces, refined borders) operational in both dark mode (`html.dark.glass`) and light mode (`html.glass:not(.dark)`).
- **FR-02b — Preservation of Dark Mode Visuals:** Existing dark mode aesthetics, contrast ratios, and color grading must remain visually preserved without unwanted alterations.
- **FR-02c — Preference Continuity:** User selections for blur intensity (`--glass-b` / `S.blur`), glass opacity (`--glass-a` / `S.glass`), and accent color swatches must apply consistently across both modes.
- **FR-02d — Architectural Choice:** Explicitly choose and document this shared glass styling path rather than attempting an unrelated full redesign.

### FR-03 — Work Package C: Mobile Personalization Region & Keyboard Accessibility

- **FR-03a — Non-Modal Floating Region Semantics:** Container `#gmdl-ui-panel` is an accessible floating region with `role="region"` and `aria-label="个性化外观设置"`. It is non-modal (`aria-modal="true"` and `aria-haspopup="dialog"` are omitted).
- **FR-03b — Trigger Semantics:** Trigger `#gmdl-ui-btn` exposes `aria-controls="gmdl-ui-panel"` and dynamic `aria-expanded="false"` / `"true"`.
- **FR-03c — Keyboard Operability & Escape Dismissal:** Tab and Shift+Tab navigate freely without modal focus trapping; pressing `Escape` while open closes the panel and restores focus to `#gmdl-ui-btn`.
- **FR-03d — Touch Target Ergonomics:** Interactive buttons, swatches, and controls must provide a minimum 44×44px interactive area.
- **FR-03e — Measured Viewport Acceptance:** Acceptance requires measured `document.documentElement.scrollWidth <= document.documentElement.clientWidth` across five viewports: `320×568`, `375×812`, `390×844`, `768×1024`, and `1280×800`. Applying `overflow-x: hidden` alone is not treated as proof of responsive adaptation.

### FR-04 — Work Package D: Copyable Preference Export / Import

- **FR-04a — Single Strict Format & Deterministic Serialization:** Preferences must use literal prefix `GMDL1:` followed by canonical, compact JSON envelope: `GMDL1:{"v":1,"settings":{...}}`. Base64 alternatives and raw-JSON envelopes without prefix are strictly rejected. Keys must be serialized in deterministic order: envelope keys `"v"`, `"settings"`; settings keys `"theme"`, `"accent"`, `"bg"`, `"style"`, `"text"`, `"lyric"`, `"glow"`, `"blur"`, `"glass"`.
- **FR-04b — Strict Schema Validation & Duplicate Key Rejection:**
  1. Validate `v === 1` and require all nine settings keys (`theme`, `accent`, `bg`, `style`, `text`, `lyric`, `glow`, `blur`, `glass`) exactly once.
  2. Reject missing keys as well as extra or unknown keys.
  3. **Duplicate Key Rejection with Decoded Escapes:** Standard `JSON.parse` silently overwrites duplicate object keys. Therefore, duplicate member names are rejected fail-closed on the original payload before/while decoding at both the envelope level (e.g., duplicate `v`, duplicate `settings`) and the nested `settings` level (e.g., duplicate `theme`, duplicate `accent`). The detector must compare decoded JSON member names (treating `"theme"` and `"\u0074heme"` as duplicates). A token-aware duplicate-key detector or duplicate-detecting parser must be used, requiring no third-party runtime dependencies and zero `eval()` / `new Function()`.
- **FR-04c — Security & Anti-Eval Invariant:** Zero use of `eval()`, `new Function()`, or arbitrary object assignment. Reject any unknown keys or prototype properties (`__proto__`, `constructor`) fail-closed.
- **FR-04d — Safe Failure Handling & Dedicated Status Node:** Accessible feedback is provided strictly via one dedicated status node `#gmdl-import-status` (`role="status"`, `aria-live="polite"`). On invalid input, only this node's text is updated with the error notification. All stored appearance/background preferences (`gmdl-ui`, `gmdl-bgimg`), document classes, CSS variables, panel input states, and DOM focus remain 100% unchanged. Automated tests snapshot storage and settings DOM, explicitly excluding only `#gmdl-import-status` (asserting it receives error text) and asserting 100% invariance of all storage and settings DOM state.
- **FR-04e — Round-Trip Fidelity:** `importCode(exportCode())` produces 100% identical configuration state.
- **FR-04f — Scope Boundary for Background Image:** Export/import strictly excludes uploaded background image data (`gmdl-bgimg`). Device-local persistence is maintained with an explicit user notice.
- **FR-04g — Concrete User Journey:** Personalization panel on source device generates/copies code; target device panel pastes code into `#gmdl-import-code` and clicks `#gmdl-import-btn`; `#gmdl-import-status` reflects outcome without full reload.

### FR-05 — Feature Module & Upstream Invariants

- **FR-05a — Unchanged Behavior for `gmdl-feat.js`:** Existing feature extensions (daily recommend songs button and blank-search pagination) remain unchanged in functionality.
- **FR-05b — Zero Upstream Modifications:** No changes to upstream `go-music-dl` Go source code are permitted.

### FR-06 — IA PoC Current-Run Isolated Deliverable

- **FR-06a — Commissioned Isolated Branch Work:** Internet Archive audio discovery is active current-run scope commissioned on branch `poc/ia-audio-discovery`.
- **FR-06b — Mainline Isolation Invariant:** `gmdl-ia.js` and `gmdl-ia.test.js` shall NOT be merged into `main` or exist on `project/antigravity-overhaul`. Work executes in a fresh isolated worktree/branch branched from `126853a` (never accessing `/workspace/gmdl-theme-pack-poc`).
- **FR-06c — Acceptance & Branch Push:** Requires passing all 10 deterministic tests in `gmdl-ia.test.js`, syntax checks, and a separate branch push to `poc/ia-audio-discovery` (reporting whether the push succeeds).
- **FR-06d — Wikimedia Commons Deferred:** Wikimedia Commons integration remains deferred pending verified gates.

---

## 4. Non-Functional Requirements

- **NFR-01a — Baseline Preservation:** Existing unit test suite `gmdl-ui.test.js` must remain intact at 8 pass / 0 fail / 0 skipped. (Currently executed and passing).
- **NFR-01b — Enhancement Suite Separation:** Dedicated planned suite `gmdl-ui-enhancements.test.js` shall house new regressions for glass variables, floating region keyboard/ARIA interactions, deterministic export serialization, duplicate key rejection with decoded JSON escapes, and side-effect-free snapshot verification. (Currently planned only; unexecuted in this phase. Never claim the entire feature work is covered by baseline 8).
- **NFR-01c — Mock Deployment Suite:** Planned mock harness shall cover all 12 specified test conditions (`MOCK-01` through `MOCK-12`). (Specified only; currently unexecuted).
- **NFR-01d — IA Unit Suite:** Planned IA unit test suite (`gmdl-ia.test.js`) on `poc/ia-audio-discovery` shall pass 10/10 deterministic tests without live network calls. (Planned only; currently unexecuted).

### NFR-02 — Code Quality & Linting
- **NFR-02a:** All JavaScript files must pass syntax compilation (`node --check <file>`).
- **NFR-02b:** `git diff --check` must report zero whitespace errors.
- **NFR-02c:** Zero lines matching `ERROR` in production JavaScript files.

### NFR-03 — Governance & Phased Execution
- **NFR-03a:** Execution strictly follows the ordering rule: Product Specification → Internal Coordinator Review → Stage 7 Quality Test Plan (`docs/project/07-quality-test-plan.md`) → Internal Review of Stage 7 → Smoke Script (`scripts/smoke.sh`).
- **NFR-03b:** Stop for internal coordinator review after completing specifications; do not draft Stage 7, `smoke.sh`, or start implementation prematurely.

### NFR-04 — Autonomous Publication Authorization
- **NFR-04a:** The final publication target for mainline is `puerjeer/gmdl-theme-pack` branch `main` via host-side transfer.
- **NFR-04b:** The final publication target for the isolated PoC is branch `poc/ia-audio-discovery`.
- **NFR-04c:** The owner has explicitly pre-authorized autonomous execution and final push upon passing all acceptance gates.
- **NFR-04d:** The coordinator pauses only for human-only inputs, paid actions, protected workflows, or irreversible decisions.

---

## 5. Acceptance Criteria Summary

| ID | Criterion | Verification Method |
|---|---|---|
| AC-01 | Baseline tests pass cleanly (8 pass, 0 fail, 0 skipped) | `node --test gmdl-ui.test.js` |
| AC-02 | Production JS files pass syntax validation | `node --check gmdl-ui.js gmdl-feat.js` |
| AC-03 | Repository formatting and whitespace pass | `git diff --check` |
| AC-04 | Reversible `deploy.sh` specification with lock-first preflight, `PRE_HEAD`/`PULLED_HEAD`, and 12 mock tests | [`docs/spec/modules/deploy.sh.md`](../spec/modules/deploy.sh.md) |
| AC-05 | Shared glass styling specified for dark and light modes | [`docs/spec/SPEC.md`](../spec/SPEC.md) & [`docs/spec/modules/gmdl-dark.css.md`](../spec/modules/gmdl-dark.css.md) |
| AC-06 | Mobile panel non-modal accessibility specified with 5 measured viewport checks | [`docs/spec/SPEC.md`](../spec/SPEC.md) & [`docs/spec/modules/gmdl-ui.js.md`](../spec/modules/gmdl-ui.js.md) |
| AC-07 | Versioned preference export/import defined with strict GMDL1 JSON schema requiring all 9 keys exactly once and rejecting duplicate member names | [`docs/spec/SPEC.md`](../spec/SPEC.md) & [`docs/spec/modules/gmdl-ui.js.md`](../spec/modules/gmdl-ui.js.md) |
| AC-08 | IA PoC commissioned for current run on isolated branch `poc/ia-audio-discovery` | [`docs/spec/IA-POC-BRANCH-PLAN.md`](../spec/IA-POC-BRANCH-PLAN.md) |
| AC-09 | All documentation reflects canonical `docs/spec/` paths and 2026-10-13 rebaseline | Stage docs 01–06, 08, TASKS, HANDOFF |
| AC-10 | Specification package completed and ready for internal coordinator review | Stop before Stage 7 & smoke script |

---

## 6. Out of Scope

See [`02-scope.md`](02-scope.md) for the detailed scope boundary and deferred items.
