# Project Tasks — Implementation Plan v2.1
<!-- Project: gmdl-theme-pack-agent · Branch: project/antigravity-overhaul -->
<!-- Last updated: 2026-10-13 06:38 (both final reviews passed; hourly read-only schedule active) -->

## Operational Model & Governance Constraints
- **Authoritative Baseline Scope:** Strictly limited to four core product work packages (A: Deployment Automation, B: Shared Glass Styling, C: Mobile & Keyboard Accessibility, D: Preference Export/Import) plus project documentation and testing on `project/antigravity-overhaul`.
- **Commissioned IA PoC Branch Deliverable:** Internet Archive (IA) audio discovery is **commissioned for this active run** on its own dedicated branch: `poc/ia-audio-discovery` ([`docs/spec/IA-POC-BRANCH-PLAN.md`](docs/spec/IA-POC-BRANCH-PLAN.md)). Work executes in a fresh isolated worktree branched from `126853a` (never accessing `/workspace/gmdl-theme-pack-poc`). Zero IA code shall merge into `main`. Wikimedia Commons remains deferred.
- **Execution Authority:** The owner has authorized autonomous implementation and enabled repository content-write/push capability. No routine owner-approval checkpoints exist between tasks. Before any GitHub publication, present the exact final branch/file summary for owner review and obtain approval, preserving the previously agreed final-review gate. Publish mainline only to `main` and IA only to `poc/ia-audio-discovery`; never merge IA into `main`.
- **Preserved Ordering Invariant:** Specification Package → Internal Coordinator Review → Stage 7 Quality Test Plan (`docs/project/07-quality-test-plan.md`) → Internal Review/Acceptance of Stage 7 → Smoke Automation (`scripts/smoke.sh`) → Code. No implementation work starts until the smoke script is authored and passes.
- **Current Task Phase Status:** Tasks 1–5 are complete locally. Task 4's final UI acceptance remains 29/29 enhancement, 8/8 baseline, 11/11 authentic screenshot pairs, and five viewport touch/keyboard audits. Task 5 v2.1 passes deployment mocks 12/12 and final smoke 10/0; tests prove index-invariant dry-run, fail-closed status and pulled-HEAD capture, missing-sha before state capture, exact hash order, rollback/reset, and lock ordering. Task 6 remains isolated on `poc/ia-audio-discovery` at `126853a`; v2.1 suite passes 10/10 with stale resolve and reject each arriving after the newer track is already playing. Both final independent re-reviews passed; only owner review of the exact publication payload remains pending. Production deployment remains out of scope.
- **Git Boundaries:** Mainline work is confined to `/workspace/gmdl-theme-pack-agent`; IA work is confined to `/workspace/gmdl-theme-pack-ia-agent` on its isolated branch. Never read or modify `/workspace/gmdl-theme-pack`, `/workspace/gmdl-theme-pack-project`, or `/workspace/gmdl-theme-pack-poc`. Use the authorized GitHub connector/host-side transfer only after acceptance: mainline to `main`, IA only to `poc/ia-audio-discovery`; never merge or push IA to `main`.

---

## Model Routing & Cadence Checklist

At every task start and major phase boundary, the coordinator performs the following verification:
- [ ] Inspect the model selection picker and provider notice status.
- [ ] Verify active model operational health (Current: Gemini 3.8 Flash Medium).
- [ ] Log any actual model switch in `docs/spec/progress/model-routing.log` with timestamp (+08), from→to, reason, and provenance (`app-verified` vs `user-reported`).
- [x] **Hourly Self-Check Schedule:** Service-confirmed active for this task; `intervalSeconds=3600`, timezone `Asia/Taipei`, title `每小時 GMDL 主線與 IA PoC 唯讀狀態自檢`. Detail is report-only and prohibits edits, deployment, external service calls, commits, and pushes. Verified by read-only status at 2026-10-13 06:34:41 UTC+08.
- [ ] **Community Free-Model Fallback Status:** **NOT TRIGGERED** (Do NOT install anything now).
  - *Emergency protocol if Gemini Flash becomes unavailable:* First inspect exact README/scripts of `delhiiitian/antigravity-free`, then `999Toth999/free-antigravity`.
  - Use ONLY official provider free-tier key sources; NEVER log secrets.
  - Community fallback is restricted to drafting, decomposition, and routine implementation only; independent final review and gate sign-off must wait for Claude or Gemini 3.8 Flash.
  - Record trigger status and effects in `docs/spec/progress/model-routing.log`.

---

## Numbered Task Breakdown

### Task 1 — Governance Rebaseline & Baseline Audit (Phase 0)
- **Status:** ✅ Completed (2026-10-13)
- **Deliverables:**
  - `docs/project/01-requirements.md` (re-baselined with SMART goals)
  - `docs/project/02-scope.md` (re-baselined with Milestones)
  - `docs/project/03-stakeholders.md` (re-baselined with Mendelow Grid)
  - `docs/project/04-raci.md` (re-baselined with IA PoC branch row)
  - `docs/project/05-risk-register.md` (re-baselined with 1-5 scoring & heatmap)
  - `docs/project/06-project-plan.md` (re-baselined with approach & dependencies)
  - `docs/project/08-status.md` (re-baselined status)
  - `docs/ISSUE-TRIAGE.md` (cleaned)
  - `docs/BASELINE.md` (maintained)
  - `docs/research/IA-POC-EVIDENCE.md` (clarified as PoC research only; cleaned)
  - `TASKS.md` & `HANDOFF.md`
- **Constraints:** Documentation only. No production code, tests, or scripts modified. Baseline verified at `126853a`.
- **Acceptance Gate:** All governance documents aligned; `node --test gmdl-ui.test.js` passes 8/0/0; `git diff --check` passes.

---

### Task 2 — Product Specification & Module Contracts (Phase 1)
- **Status:** ✅ Completed & Accepted following Coordinator Review (2026-10-13)
- **Deliverables:**
  - [`docs/spec/SPEC.md`](docs/spec/SPEC.md) — Comprehensive product spec with observable acceptance criteria for work packages A, B, C, D.
  - [`docs/spec/ARCHITECTURE.md`](docs/spec/ARCHITECTURE.md) — Canonical architecture specification: injection model, versioned caching, safe rollback, non-modal accessibility, strict preference contract.
  - [`docs/spec/MODULES.md`](docs/spec/MODULES.md) — Canonical module index.
  - [`docs/spec/modules/gmdl-dark.css.md`](docs/spec/modules/gmdl-dark.css.md) — Dual-mode glass styling & responsive CSS contract.
  - [`docs/spec/modules/gmdl-ui.js.md`](docs/spec/modules/gmdl-ui.js.md) — Non-modal floating region, keyboard accessibility & strict GMDL1 JSON preference contract requiring all 9 keys exactly once.
  - [`docs/spec/modules/gmdl-feat.js.md`](docs/spec/modules/gmdl-feat.js.md) — Contract documenting existing unchanged feature behavior.
  - [`docs/spec/modules/openresty-vhost-example.conf.md`](docs/spec/modules/openresty-vhost-example.conf.md) — Reference reverse proxy vhost specification.
  - [`docs/spec/modules/deploy.sh.md`](docs/spec/modules/deploy.sh.md) — Reversible deployment workflow specification with lock-first preflight, `PRE_HEAD`/`PULLED_HEAD`, safe rollback, and 12 offline mock test conditions.
  - [`docs/spec/IA-POC-BRANCH-PLAN.md`](docs/spec/IA-POC-BRANCH-PLAN.md) — Current-run plan for isolated branch `poc/ia-audio-discovery`.
  - [`docs/spec/progress/model-routing.log`](docs/spec/progress/model-routing.log) — Maintained model routing and schedule log.
- **Constraints:** Documentation and specifications ONLY. No production code, tests, or scripts written. Stage 7 (`07-quality-test-plan.md`) was absent during Task 2 and was drafted only after Task 2 acceptance; `scripts/smoke.sh` was NOT created.
- **Acceptance Gate:** Specification package complete, canonicalized under `docs/spec/`; accepted by coordinator on 2026-10-13.

---

### Task 3 — Quality Test Plan & Smoke Automation (Phase 2)
- **Status:** ✅ Completed (Stage 7 accepted 2026-10-13 04:20 UTC+08; Smoke Script verified 04:23 UTC+08)
- **Deliverables:**
  - Sub-task 3A: `docs/project/07-quality-test-plan.md` — Quality plan derived from Task 2 specifications, including authentic upstream UI loopback testing procedure. (Draft complete).
  - Sub-task 3B: Internal coordinator review of Stage 7. (Accepted 2026-10-13 04:20 UTC+08; RTM covers all 68 source acceptance IDs).
  - Sub-task 3C: `scripts/smoke.sh` — Executable test utility implementing accepted phase-aware checks. (Created, syntax-checked, and current-phase run passed 7/0; future suites explicitly deferred).
  - Update `docs/project/08-status.md`.
- **Ordering Constraint:** `07-quality-test-plan.md` must be written and reviewed by the coordinator *before* creating `scripts/smoke.sh`.
- **Acceptance Gate:** ✅ `bash scripts/smoke.sh` exits 0; conditional wiring fail-closed probe passed; blocked/future items honestly flagged.

---

### Task 4 — Mainline UI Enhancements (Phase 3)
- **Status:** ✅ Final acceptance reconfirmed after hitbox remediation (2026-10-13 05:29 UTC+08)
- **Deliverables:**
  - **WP-B (Shared Glass Styling):** Update `gmdl-dark.css` and `gmdl-ui.js` to enable glass styling in both light and dark modes, preserving dark mode aesthetics and user preferences.
  - **WP-C (Mobile & Keyboard Usability):** Non-modal floating region (`role="region"`), touch targets (≥44px), ARIA states (`aria-controls`, `aria-expanded`), Tab navigation without modal traps, and Escape key dismissal with focus return to trigger button.
  - **WP-D (Preference Export / Import):** Implemented controls `#gmdl-export-code`, `#gmdl-import-code`, `#gmdl-import-btn`, and `#gmdl-import-status` in the existing personalization region. Single strict format (`GMDL1:{"v":1,"settings":...}`), deterministic key serialization order (`v`, `settings`; settings: `theme`, `accent`, `bg`, `style`, `text`, `lyric`, `glow`, `blur`, `glass`), strict schema validation requiring all 9 keys exactly once, token-aware duplicate member name rejection with decoded JSON member name comparison (e.g. `"theme"` and `"\u0074heme"`) at envelope and settings levels without relying on `JSON.parse` alone, safe error handling, round-trip guarantee; `gmdl-bgimg` excluded with explicit UI notice; zero `eval()`.
  - **Test Suite Separation & Accounting (Executed vs Planned):** Baseline `gmdl-ui.test.js` passes 8/0/0; `gmdl-ui-enhancements.test.js` completed test-first (red 3/26; final green 29/29); final smoke passes 10/0. All 11 authentic before/after screenshots were reviewed; five actual viewports pass zero-overflow, non-overlap, and pointer close; all visible controls meet 44×44 and each swatch passes four-edge hit tests; real Chromium Enter/Tab/Escape and 2px focus indication pass. Visual manifests and browser audit are outside Git at `/workspace/gmdl-theme-pack-visual-evidence/`.
- **Constraints:** Zero upstream Go changes; `gmdl-feat.js` remains unchanged; `gmdl-ui.test.js` passes 8/0/0.
- **Acceptance Gate:** Coordinator final acceptance complete after 29/29 enhancement tests, baseline 8/8, smoke 10/0, JS syntax/whitespace checks, byte-identical `gmdl-feat.js`, 11/11 paired authentic screenshots, five viewport geometry/touch measurements, real pointer close and keyboard verification.

---

### Task 5 — Reversible Deployment Automation (Phase 4)
- **Status:** ✅ Offline implementation, 12/12 v2.1 mock acceptance, smoke 10/0, and final independent re-review complete locally (2026-10-13 06:38 UTC+08; no production execution)
- **Deliverables:**
  - **WP-A (`deploy.sh`):** Standalone bash script executing read-only metadata lock, `GIT_OPTIONAL_LOCKS=0` clean-tree checks (preventing index refresh), path verification, `git` / `flock` / `sha256sum` / nginx / reload command checks before backup/pull, `$PRE_HEAD` capture, and backup, followed by the exact five-step sequence. Pull failure or immediate `PULLED_HEAD` capture failure halts before hashing/config mutation; an unknown pulled revision is never reset and produces a manual-recovery diagnostic.
  - Automated timestamped backup creation before modification (`vhost.conf.bak.<timestamp>`).
  - Deterministic safe rollback covering any post-pull failure (hashing, config update, syntax test, reload): restore config via atomic restore staging (`.rollback.tmp.$$`) with byte-exact `cmp -s` verification and metadata equality before atomic rename; reset code ONLY if post-pull tree is clean and HEAD equals `$PULLED_HEAD`; refuse destructive reset if dirty or mismatched revision. Release lock on all exits via EXIT trap.
  - Offline harness `scripts/deploy-mock.sh` covers all 12 cases. The v2.1 expected-red showed only the two new assertions failing (MOCK-03 optional-lock/index invariant; MOCK-05 pulled-HEAD capture diagnostic), then the final run passed 12/12. Coverage includes byte+metadata invariant `.git/index` during a forced-stale-mtime dry-run; optional-lock disabled status; lock ordering; missing-`sha256sum` before `PRE_HEAD`; safe manual-review stop after unknown pulled HEAD; token cardinality; rollback and reset guards. Final smoke passed 10/0 at 06:38:05. No live service/production claim.
- **Constraints:** Produce and locally test script only; DO NOT run against production servers. Missing server credentials remain currently BLOCKED/UNVERIFIED.
- **Acceptance Gate:** `bash -n deploy.sh`, `bash -n scripts/deploy-mock.sh`, 12/12 offline mock behavioral cases, full smoke 10/0, and `git diff --check` pass. No production execution.

---

### Task 6 — Commissioned IA PoC Branch Implementation (Phase 5)
- **Status:** ✅ Final independent re-review passed; implementation and 10/10 v2.1 tests locally green (isolated worktree only; owner publication review pending)
- **Deliverables:**
  - Isolated worktree `/workspace/gmdl-theme-pack-ia-agent` on branch `poc/ia-audio-discovery`, branched directly from authorized baseline `126853a` (never accessing `/workspace/gmdl-theme-pack-poc`); only `gmdl-ia.js` and `gmdl-ia.test.js` are currently untracked there.
  - `gmdl-ia.test.js` — 10 deterministic offline tests. Initial 0/10 missing-module red was followed by two audit-driven red phases (2/10 and 1/10 failures), each converted to 10/10 green.
  - `gmdl-ia.js` — Standalone namespace-based adapter with anonymous IA search/metadata fetch, fail-closed license/format/size/path filters, immutable validator-issued playback candidates, preserved path-segment whitespace, and native Audio pause/end/error state transitions.
  - Both files pass syntax checks and the 10/10 offline suite; tests cover malformed responses, rejected JSON, immutable allow-list candidates, native pause/end, synchronous/asynchronous play errors, and old play Promise resolve **and** reject each arriving after the new track is already playing. Final independent review found no code/test blocker. No live API request was made.
  - Push to remote branch `poc/ia-audio-discovery` and report whether push succeeds.
- **Constraints:** Zero IA code on `project/antigravity-overhaul` or `main`. Never merge into `main`.
- **Acceptance Gate:** Final independent review plus 10/10 offline tests and clean syntax; then present exact branch/file payload for owner review before the branch-only push. Never merge or publish IA to `main`.

---

### Task 7 — Viewport & Integration Verification (Phase 6)
- **Status:** ⏳ Pending (Post-Task 5/6 Gate)
- **Deliverables:**
  - Viewport verification audit covering: `320×568`, `375×812`, `390×844`, `768×1024`, and `1280×800` measuring `document.documentElement.scrollWidth <= document.documentElement.clientWidth`.
  - Audit of touch target bounds (≥44px), keyboard navigation, and Escape dismissal.
  - Viewport verification record documented.
- **Constraints:** Honestly mark physical-device and live-site tests as **currently BLOCKED/UNVERIFIED**.
- **Acceptance Gate:** Measured zero horizontal overflow across all five target viewports; Escape key and keyboard accessibility verified.

---

### Task 8 — Release Readiness & Host-Side Publications (Phase 7)
- **Status:** ⏳ Pending (Final Phase)
- **Deliverables:**
  - Final diff audit against baseline HEAD `126853a` on `project/antigravity-overhaul`.
  - Release-Readiness checklist verification (RR-01 through RR-10).
  - Update `HANDOFF.md` with final commit hashes.
  - Execute host-side commit transfer to `puerjeer/gmdl-theme-pack` branch `main`.
  - Verify separate push of `poc/ia-audio-discovery`.
- **Acceptance Gate:** All RR checklist items verified; exact final payload presented for owner review/approval; then report each authorized branch transfer separately.

---

## Blocked / Unverified Status

| Check | Label | Explanation |
|---|---|---|
| Local upstream UI loopback verification | **PASS — authentic before/after complete** | Official digest-verified v1.1.1 binary and localhost-only nginx proxy; 11 before/11 after captures and five-view geometry/keyboard audit complete. |
| Production/reference `nginx -t` validation | **currently BLOCKED/UNVERIFIED** | Local nginx-extras is installed and the isolated proxy config passed `nginx -t`; production host/include context is unavailable. |
| Live-site visual testing | **currently BLOCKED/UNVERIFIED** | `https://music.archfox.eu.cc/music` returns 404. |
| Physical mobile device testing | **currently BLOCKED/UNVERIFIED** | No hardware available; headless authentic-page geometry, pointer, touch and keyboard audit passed across five specified viewports, but this is not hardware testing. |
| Production SSH / Server Access | **currently BLOCKED/UNVERIFIED** | Consolidated input checklist maintained in `HANDOFF.md`. |
| Wikimedia Commons feature | **DEFERRED** | Gated on format, size, and licensing proof. |
