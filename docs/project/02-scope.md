# 02 — Scope
<!-- Stage 2 of 8 governance documents -->
<!-- Project: gmdl-theme-pack-agent · Branch: project/antigravity-overhaul -->
<!-- Last updated: 2026-10-13 (Documentation Scope Rebaseline) -->

> [!NOTE]
> **Scope Rebaseline Notice (2026-10-13):**
> Mainline engineering on `project/antigravity-overhaul` is strictly focused on four product work packages (A, B, C, D)
> for eventual publication to `main`.
> **Internet Archive (IA) audio discovery is commissioned for this active run** as an isolated deliverable on its own
> dedicated branch: `poc/ia-audio-discovery` ([`docs/spec/IA-POC-BRANCH-PLAN.md`](../spec/IA-POC-BRANCH-PLAN.md)).
> Zero IA code shall merge into `main`. Specifications are canonicalized strictly under `docs/spec/`. No production code has started.

---

## 1. Project Scope Statement

The `gmdl-theme-pack` project delivers reverse-proxy-injected styling, accessibility, deployment automation, and portable configuration enhancements for `go-music-dl` without modifying upstream Go code.
The scope encompasses:
1. Reversible automated deployment tooling (`deploy.sh`) with lock-first preflight, atomic configuration updates, deterministic safe rollback, and a 12-case offline mock test harness.
2. Shared glassmorphism styling across both light and dark modes, fully preserving dark mode aesthetics.
3. Mobile personalization floating region layout with touch target ergonomics, non-modal ARIA accessibility, keyboard operability, and measured horizontal overflow containment.
4. Portable preference export/import adhering to a strict `GMDL1:` JSON schema requiring all nine settings keys exactly once (excluding background images).
5. A commissioned, isolated browser-side audio discovery proof-of-concept developed on a dedicated branch `poc/ia-audio-discovery` passing 10 deterministic unit tests.

### 1.1 Target-Dated Project Milestones (Planning Estimates)
*(Disclaimer: All dates and times below are planning estimates for this autonomous run, not owner commitments).*

| Milestone ID | Target Milestone Description | Estimated Target Date | Gate Dependency |
|---|---|---|---|
| **M1** | Specification Review & Stage 7 Quality Plan Completion | 2026-10-13 14:00 UTC+08 | Task 2 review passed; `docs/project/07-quality-test-plan.md` reviewed |
| **M2** | Mainline Implementation & Smoke Test Verification (WP-A, B, C, D) | 2026-10-13 16:30 UTC+08 | Future milestone (not executed): Stage 7 passed; planned `scripts/smoke.sh` verified; planned 12 deploy mock tests pass |
| **M3** | Isolated IA PoC Implementation & Host-Side Publication Transfers | 2026-10-13 18:00 UTC+08 | Future milestone (not executed): Mainline verified; planned 10 IA unit tests pass; `main` & `poc/ia-audio-discovery` pushed |

---

## 2. In Scope Deliverables

| Item ID | Deliverable / Area | Description |
|---|---|---|
| **WP-A** | Reversible Deployment Automation (`deploy.sh`) | Shell script implementing lock-first preflight, clean tree check, path validation, `$PRE_HEAD` capture, and backup, followed by exact five-step sequence: (1) `git pull --ff-only` immediately followed on success within the same step by recording `PULLED_HEAD=$(git rev-parse HEAD)` (pull failure leaves active configuration untouched, though timestamped preflight backup may exist); (2) compute asset hash query-strings (`?v=`); (3) fail-closed atomic config update; (4) `nginx -t`; (5) graceful reload. Includes deterministic safe rollback on any post-pull failure (restore config; reset code only if tree clean and HEAD equals `$PULLED_HEAD`; refuse reset if dirty or mismatched) and 12-condition offline mock test harness. Production execution is not in scope. |
| **WP-B** | Shared Glass Styling | Cross-mode glass styling for both dark (`html.dark.glass`) and light (`html.glass:not(.dark)`) modes while preserving existing dark appearance, contrast, and user preferences. Explicitly chosen and documented over a full redesign. |
| **WP-C** | Mobile Personalization Region & Keyboard Usability | Non-modal floating region (`role="region"`, `aria-label`, trigger `aria-controls` & `aria-expanded`), touch-sized controls (≥44px), full keyboard operability without focus trapping, and Escape key dismissal with focus return to trigger button. Acceptance includes measured `scrollWidth <= clientWidth` at 320×568, 375×812, 390×844, 768×1024, and 1280×800. |
| **WP-D** | Copyable Preference Export / Import | Single strict format (`GMDL1:{"v":1,"settings":...}`), strict JSON schema validation requiring all nine keys exactly once, fail-closed rejection of duplicate member names (at envelope and settings levels), unknown keys, wrong types/ranges, and oversized input without mutating storage or DOM. The implementation must use a token-aware duplicate detector comparing decoded JSON member names (e.g. `"theme"` and `"\u0074heme"`) without third-party dependencies or `eval()`. Explicitly limited to `gmdl-ui` appearance settings; uploaded `gmdl-bgimg` is excluded with an explicit notice. Zero arbitrary key injection. |
| **WP-IA** | Commissioned IA PoC Branch Deliverable | Isolated implementation on fresh branch `poc/ia-audio-discovery` branched from `126853a` (never accessing `/workspace/gmdl-theme-pack-poc`). Standalone adapter (`gmdl-ia.js`) and 10 deterministic tests (`gmdl-ia.test.js`). Independent acceptance verification and separate branch push. |
| **SPEC** | Canonical Specification Package | [`docs/spec/SPEC.md`](../spec/SPEC.md), [`docs/spec/ARCHITECTURE.md`](../spec/ARCHITECTURE.md), [`docs/spec/MODULES.md`](../spec/MODULES.md) (canonical index), per-module contracts under `docs/spec/modules/` (`gmdl-dark.css.md`, `gmdl-ui.js.md`, `gmdl-feat.js.md`, `openresty-vhost-example.conf.md`, `deploy.sh.md`), and [`docs/spec/IA-POC-BRANCH-PLAN.md`](../spec/IA-POC-BRANCH-PLAN.md). |
| **LOG** | Model Routing Log | [`docs/spec/progress/model-routing.log`](../spec/progress/model-routing.log) tracking model transitions, provenance, inspection cadence, schedule status, and fallback guardrails. |
| **TEST** | Quality Plan & Tests (Future Phases) | `docs/project/07-quality-test-plan.md`, `scripts/smoke.sh`, and unit tests (strictly after spec review). |
| **GOV** | Project Governance & Status | Updated Stages 01–06, 08, `TASKS.md`, `HANDOFF.md`, `docs/BASELINE.md`, `docs/ISSUE-TRIAGE.md`, `docs/research/IA-POC-EVIDENCE.md`. |

---

## 3. Out of Scope Exclusions

| Item ID | Item | Reason & Boundary |
|---|---|---|
| **OS-01** | Merging IA Code into `main` | Strict isolation invariant: IA audio discovery is developed and pushed solely on branch `poc/ia-audio-discovery`. It shall never merge into `main` or exist on mainline `project/antigravity-overhaul`. |
| **OS-02** | Accessing Exploratory PoC Worktree | Accessing `/workspace/gmdl-theme-pack-poc` is forbidden. Work on `poc/ia-audio-discovery` must branch freshly from baseline `126853a`. |
| **OS-03** | Live Production Deployment Execution | Executing `deploy.sh` against live production servers is not authorized by current scope. Local script creation and mock harness testing are in scope; live deployment requires future explicit authorization and working server credentials. |
| **OS-04** | Upstream Go Source Code Changes | Architectural boundary; all enhancements delivered via reverse proxy injection. |
| **OS-05** | Direct Push from Local Clone | Standalone clone origin is local; final publication is executed via host-side transfer to `puerjeer/gmdl-theme-pack` branch `main` (and `poc/ia-audio-discovery`). |
| **OS-06** | Full App Redesign | Unrelated redesign is out of scope; shared glass styling path is explicitly chosen and constrained. |
| **OS-07** | Exporting Background Image Data (`gmdl-bgimg`) | Large base64 image strings are excluded from export codes to prevent payload bloat and memory stalls; remains device-local. |
| **OS-08** | Use of `eval()` or Arbitrary Key Ingestion | Strict security invariant; only schema-validated `gmdl-ui` keys are parsed and written. Base64 and raw-JSON alternatives rejected. |
| **OS-09** | Third-Party npm Runtime Dependencies | Zero npm package dependencies permitted. |
| **OS-10** | Upstream Issues #242–#233 Code Changes | Triaged as resolved upstream or out of scope. |
| **OS-11** | Access to External Worktrees | Strictly confined to `/workspace/gmdl-theme-pack-agent` during this phase. |

---

## 4. Deferred (Gate-Gated)

| Item ID | Item | Gate Dependency |
|---|---|---|
| **D-01** | Wikimedia Commons Integration | Requires: (1) playable audio format filter excluding MIDI, (2) strict size cap excluding large uncompressed files (e.g. >150 MB WAV), and (3) machine-verifiable licensing. Strictly deferred across all branches. |

---

## 5. Currently Blocked / Unverified Checks

> [!NOTE]
> The following items are marked **currently BLOCKED/UNVERIFIED** rather than permanent blocks, as missing local tools or temporary live site errors do not prove impossibility. Local upstream verification is distinct from remote/live verification.

| Item | Reason / Status | Workaround / Fallback |
|---|---|---|
| Local upstream UI loopback verification | Upstream binary digest in GitHub v1.1.1 API (`sha256:be7b...`) does not match legacy digest found in prior task context (provenance unverified); binary neither downloaded nor executed. Requires download-time `sha256sum` check against official digest before any execution. | Gated until Stage 7 quality test plan defines and reviews loopback execution procedure. |
| Server-side `nginx -t` validation | No local `nginx`/`openresty` binary in sandbox environment | Marked **currently BLOCKED/UNVERIFIED**; planned future offline verification after `deploy.sh` and its mock harness are authored. In this phase, no script or mock harness exists and no mock condition has run. |
| Live-site visual testing | `https://music.archfox.eu.cc/music` returns 404 / unavailable | Marked **currently BLOCKED/UNVERIFIED**; planned local viewport and DOM fixture verification after UI implementation in Task 4. Not run in this phase, while the live endpoint remains blocked/unverified. |
| Physical mobile device testing | No physical mobile hardware connected to sandbox | Marked **currently BLOCKED/UNVERIFIED**; planned simulated viewport checks (320×568 through 1280×800). No viewport test suite has run in this documentation-only phase. |
| Production SSH / Server Access | Server credentials and host environment not configured | Marked **currently BLOCKED/UNVERIFIED**; script parameterised for future host execution. |

---

## 6. Architectural Boundary Diagram

```
┌────────────────────────────────────────────────────────────────────────┐
│  MAINLINE SCOPE (Branch: project/antigravity-overhaul -> main)         │
│                                                                        │
│  OpenResty Reverse Proxy                                               │
│  ┌───────────────────────┐                                             │
│  │ deploy.sh Automation  │ ──► [lock preflight] ──► [git pull --ff]    │
│  │ (12 mock conditions)  │ ──► [hash ?v=] ──► [atomic conf] ──► reload │
│  └───────────────────────┘                                             │
│               │ (sub_filter injection)                                 │
│               ▼                                                        │
│  Client Assets (Browser Runtime)                                       │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │ gmdl-dark.css   Shared Glass Styling (Light + Dark modes)       │   │
│  │ gmdl-ui.js      Non-modal floating region (Touch + ARIA + Esc)  │   │
│  │                 Preference Export/Import (GMDL1 strict contract)│   │
│  │ gmdl-feat.js    Daily Recommend & Pagination (Unchanged)        │   │
│  └─────────────────────────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────────────┐
│  COMMISSIONED ISOLATED POC (Branch: poc/ia-audio-discovery)            │
│                                                                        │
│  - Standalone adapter: gmdl-ia.js (10 deterministic tests)             │
│  - Fresh isolated worktree branched from 126853a                       │
│  - NEVER merged to main; pushed to poc/ia-audio-discovery              │
└────────────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────────────┐
│  DEFERRED / OUT OF SCOPE                                               │
│                                                                        │
│  Wikimedia Commons       Deferred                                      │
│  go-music-dl Go Source   Unmodified                                    │
│  Production Server Run   currently BLOCKED/UNVERIFIED (local mock only)│
│  Exploratory Worktree    /workspace/gmdl-theme-pack-poc (NEVER touch)  │
└────────────────────────────────────────────────────────────────────────┘
```
