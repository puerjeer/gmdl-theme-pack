# 06 — Project Plan
<!-- Stage 6 of 8 governance documents -->
<!-- Project: gmdl-theme-pack-agent · Branch: project/antigravity-overhaul -->
<!-- Last updated: 2026-10-13 (Documentation Scope Rebaseline) -->

## 1. Project Overview & Target Identity

| Attribute | Value |
|---|---|
| Workspace Repository | `/workspace/gmdl-theme-pack-agent` |
| Working Branch | `project/antigravity-overhaul` (Mainline) |
| Commissioned PoC Branch | `poc/ia-audio-discovery` (Isolated Current-Run Branch) |
| Baseline Git HEAD | `126853a` |
| Plan Version | v2.1 (Authoritative Mainline Rebaseline & Current-Run IA PoC) |
| Plan Date | 2026-10-13 |
| Final Publication Targets | Mainline to `puerjeer/gmdl-theme-pack` branch `main`; PoC to `poc/ia-audio-discovery` |
| Execution Authority | Autonomous execution and publication authorized; pauses only for human-only inputs/secrets/paid actions |

---

## 2. Development Approach & Engineering Rationale

### Gated, Risk-Based Iterative & Test-Driven Development (TDD)
The project employs a strictly gated, risk-based iterative development approach:
- **Contract-First Specification:** Interfaces, schemas, and rollback safety invariants are rigorously specified before writing implementation code.
- **Strict Quality Gating:** Specifications must pass internal coordinator review before drafting the Stage 7 Quality Test Plan (`docs/project/07-quality-test-plan.md`), and Stage 7 must pass review before creating test runner utilities (`scripts/smoke.sh`).
- **Test-Driven Red-Green Cycle:** New modules (preference export/import validation, deployment mock harness, and IA adapter) are developed against deterministic unit tests that fail red before implementation and pass green upon completion.
- **Architectural Isolation:** High-risk experimental audio discovery is isolated on a dedicated branch (`poc/ia-audio-discovery`), guaranteeing zero contamination of mainline production assets.

---

## 3. Dated Project Milestones & Dependency Mapping

### 3.1 Project Milestones (Planning Estimates)
*(Disclaimer: All dates and times below are planning estimates for this autonomous run, never owner commitments).*

| Milestone ID | Target Milestone Description | Estimated Target Date | Core Gate Deliverable |
|---|---|---|---|
| **M1** | Specification Review & Quality Test Plan Acceptance | 2026-10-13 14:00 UTC+08 | Task 2 review approved (Accepted 2026-10-13 03:51 UTC+08); Stage 7 (`07-quality-test-plan.md`) reviewed (Pending) |
| **M2** | Mainline Work Packages & Smoke Verification (WP-A, B, C, D) | 2026-10-13 16:30 UTC+08 | Future milestone (not executed): planned `scripts/smoke.sh` exits 0; planned 12 deploy mock tests pass; planned 5 viewports pass |
| **M3** | Isolated IA PoC Branch & Host-Side Publication Transfers | 2026-10-13 18:00 UTC+08 | Future milestone (not executed): planned `poc/ia-audio-discovery` passes 10 planned IA tests; `main` & PoC pushed |

### 3.2 Explicit Dependency Mapping

```
[Task 2 Specifications]
       │
       ▼ (Dependency 1: Spec Review Gate — ACCEPTED 2026-10-13)
[Task 3 Quality Test Plan & Smoke Automation]
       │
       ├─────────────────────────────────────────────┐
       ▼ (Dependency 2: Mainline Quality Gate)       ▼ (Dependency 3: Branch Isolation Gate)
[Task 4 Mainline UI (WP-B, C, D)]             [Task 6 Commissioned IA PoC Branch]
       │                                             │ (Fresh branch from 126853a)
       ▼                                             │ (10 unit tests gmdl-ia.test.js)
[Task 5 Deployment Automation (WP-A)]                │ (Standalone adapter gmdl-ia.js)
       │                                             │
       ▼                                             ▼
[Task 7 Viewport Verification Audit]          [Task 6 Verification & Push to poc/ia...]
       │                                             │
       └──────────────────────┬──────────────────────┘
                              ▼ (Dependency 4: Release Gate)
                       [Task 8 Release Readiness & Host-Side Publication]
```

1. **Dependency 1 (Spec Gate):** Task 3 (`07-quality-test-plan.md`) cannot start until Task 2 specifications pass internal coordinator review.
2. **Dependency 2 (Smoke Gate):** Tasks 4, 5, and 6 cannot begin implementation until `scripts/smoke.sh` is reviewed and exits 0 on the clean baseline.
3. **Dependency 3 (Isolation Gate):** Task 6 (IA PoC) must branch freshly from baseline `126853a` on `poc/ia-audio-discovery`, completely isolated from mainline Task 4/5 changes, and must never merge into `main`.
4. **Dependency 4 (Release Gate):** Final host-side transfers (mainline to `main` and PoC to `poc/ia-audio-discovery`) require all verification checklists (RR-01 through RR-10) to pass.

---

## 4. Linear Task Breakdown

### Task 1 — Governance Rebaseline & Baseline Audit (Phase 0)
- **Status:** ✅ Completed (2026-10-13)
- **Deliverables:** Rebaselined governance stages 01–06, 08; `docs/BASELINE.md`; `docs/ISSUE-TRIAGE.md`; `docs/research/IA-POC-EVIDENCE.md`; `TASKS.md`; `HANDOFF.md`.
- **Acceptance Gate:** Governance aligned; baseline tests pass 8/0/0; `git diff --check` clean.

---

### Task 2 — Product Specification & Module Contracts (Phase 1)
- **Status:** ✅ Completed & Accepted by Coordinator (2026-10-13 03:51 UTC+08)
- **Deliverables:**
  - `docs/spec/SPEC.md` — Detailed product specifications for work packages A, B, C, D with observable acceptance criteria.
  - `docs/spec/ARCHITECTURE.md` — Canonical architecture: injection model, versioning, lock-first rollback, non-modal accessibility, strict preference contract.
  - `docs/spec/MODULES.md` — Canonical module index.
  - Per-module contracts: `gmdl-dark.css.md`, `gmdl-ui.js.md`, `gmdl-feat.js.md`, `openresty-vhost-example.conf.md`, `deploy.sh.md`.
  - `docs/spec/IA-POC-BRANCH-PLAN.md` — Current-run plan for isolated branch `poc/ia-audio-discovery`.
  - `docs/spec/progress/model-routing.log` — Model transitions, inspection cadence, coordinator-verified schedule, fallback guardrails.
- **Constraints:** Documentation only. No code or scripts written. Stage 7 and `smoke.sh` were NOT created during Task 2.
- **Acceptance Gate:** Specification package complete, canonicalized under `docs/spec/`; accepted following coordinator review on 2026-10-13 03:51 UTC+08. Basis: 22 Markdown files audited with 0 broken relative links and 0 trailing whitespace; 12 risks with 5×5 map; 15 RACI rows with 1 A and >=1 R; corrected deployment CLI/rollback/token cardinality/schema and evidence boundaries; existing baseline `node --test gmdl-ui.test.js` = 8 pass, 0 fail, 0 skipped; both source syntax checks pass. (Timed-out delegated auditor recorded accurately as pending/timed out; decision rendered via coordinator file-level audit).

---

### Task 3 — Quality Test Plan & Smoke Automation (Phase 2)
- **Status:** ⏳ Current Task (Sub-task 3A Stage 7 Draft Complete; Sub-task 3B Coordinator Review Pending; Sub-task 3C Smoke Script Deferred)
- **Deliverables:**
  - Sub-task 3A: `docs/project/07-quality-test-plan.md` — Stage 7 document defining verification matrix for mainline work packages and authentic upstream UI loopback testing procedure. (Draft complete). Must include explicit unit test requirements covering:
    1. Rejection of duplicate key within `settings` object (at least a repeated `"theme"` key) and within envelope object (at least repeated `"v"` or `"settings"`).
    2. Accessible error feedback strictly via dedicated status node `#gmdl-import-status` (`role="status"`, `aria-live="polite"`), asserting error text while snapshotting all storage (`localStorage`) and remaining settings DOM to prove 100% identity without side effects.
    3. Planned deployment offline mock test suite covering all 12 conditions (`MOCK-01` through `MOCK-12`), asserting real assembled configuration syntax testing via safe bash argv array (`NGINX_ARGS=(-t -c "$NGINX_MAIN_CONF")` with conditional `${NGINX_PREFIX:-}`), safe reload argv array `"$RELOAD_CMD" "${RELOAD_ARGS[@]}"`, and atomic rollback restoration staging (`.rollback.tmp.$$`) with byte-exact `cmp -s` verification.
  - Sub-task 3B: Internal coordinator review of Stage 7.
  - Sub-task 3C: `scripts/smoke.sh` — Test utility script verifying unit tests, syntax, and mock deployment.
  - Update `docs/project/08-status.md`.
- **Ordering Constraint:** `07-quality-test-plan.md` must be written and reviewed *before* creating `scripts/smoke.sh`.
- **Acceptance Gate:** `bash scripts/smoke.sh` exits 0; blocked items honestly flagged.

---

### Task 4 — Mainline UI Enhancements (Phase 3)
- **Status:** ⏳ Pending (Post-Task 3 Gate)
- **Deliverables:**
  - **WP-B (Shared Glass Styling):** Refactor `gmdl-dark.css` and `gmdl-ui.js` for dual-mode glass, preserving dark visuals.
  - **WP-C (Mobile & Keyboard Usability):** Non-modal floating region (`role="region"`), touch targets (≥44px), ARIA states (`aria-controls`, `aria-expanded`), Tab navigation without modal traps, and Escape key dismissal with focus return to trigger button.
  - **WP-D (Preference Export / Import):** Single strict format (`GMDL1:{"v":1,"settings":...}`), deterministic key serialization order (`v`, `settings`; settings: `theme`, `accent`, `bg`, `style`, `text`, `lyric`, `glow`, `blur`, `glass`), strict schema validation requiring all 9 keys exactly once, token-aware duplicate member name rejection with decoded JSON member name comparison (e.g. `"theme"` and `"\u0074heme"`) at envelope and settings levels without relying on `JSON.parse` alone, safe error handling, round-trip guarantee; `gmdl-bgimg` excluded with explicit UI notice; zero `eval()`.
  - **Test Suite Separation & Accounting:** Existing unit test suite `gmdl-ui.test.js` remains intact at 8 pass / 0 fail / 0 skipped. New regression tests for Work Packages B, C, and D shall be implemented in dedicated planned suite `gmdl-ui-enhancements.test.js` (including repeated key rejections such as repeated `theme` or repeated `v`, and side-effect-free snapshot invariance; currently planned and not yet executed). The project never claims the entire feature work is covered by baseline 8 or that the enhancement suite is executed in this phase.
- **Constraints:** Zero upstream Go changes; `gmdl-feat.js` remains unchanged; `gmdl-ui.test.js` passes 8/0/0.
- **Acceptance Gate:** `node --test` passes; `node --check` passes; `git diff --check` exits 0.

---

### Task 5 — Reversible Deployment Automation (Phase 4)
- **Status:** ⏳ Pending (Post-Task 4 Gate)
- **Deliverables:**
  - **WP-A (`deploy.sh`):** Standalone bash script executing lock-first preflight, clean tree check, path verification, `--nginx-bin` / `--reload-cmd` executable verification, `$PRE_HEAD` capture, and backup, followed by exact five-step sequence: (1) `git pull --ff-only`, immediately recording `PULLED_HEAD=$(git rev-parse HEAD)` within the same step on success (pull failure leaves active config untouched, though timestamped preflight backup may exist); (2) compute asset hashes; (3) fail-closed atomic config update in vhost directory verifying exactly one current `sub_filter` token per shipped asset with metadata preservation; (4) real assembled config `nginx -t` via safe argv array (`"$NGINX_BIN"` with `NGINX_ARGS=(-t -c "$NGINX_MAIN_CONF")` and conditional `${NGINX_PREFIX:-}`); (5) graceful reload via safe argv array `"$RELOAD_CMD" "${RELOAD_ARGS[@]}"`.
  - Automated timestamped backup creation before modification (`vhost.conf.bak.<timestamp>`).
  - Deterministic safe rollback covering any post-pull failure (hashing, config update, syntax test, reload): restore config via atomic restore staging (`.rollback.tmp.$$`) with byte-exact `cmp -s` verification and metadata equality before atomic rename; reset code ONLY if post-pull tree is clean and HEAD equals `$PULLED_HEAD`; refuse destructive reset if dirty or mismatched revision. Release lock on all exits via EXIT trap.
  - Planned offline mock test harness covering all 12 specified test conditions (`MOCK-01` through `MOCK-12`). *(Planned future harness; NOT executed in this phase).*
- **Constraints:** Produce and locally test script only; DO NOT run against production servers.
- **Acceptance Gate:** Planned mock rollback and dry-run tests exit 0.

---

### Task 6 — Commissioned IA PoC Branch Implementation (Phase 5)
- **Status:** ⏳ Pending (Post-Task 3 Gate; Parallel or Sequenced)
- **Deliverables:**
  - Fresh isolated worktree/branch `poc/ia-audio-discovery` branched from authorized baseline `126853a` (never accessing `/workspace/gmdl-theme-pack-poc`).
  - `gmdl-ia.test.js` — 10 deterministic unit tests covering IA search query building, format filtering, size cap (50 MiB), license allow-list, audio URL generation, and player state transitions.
  - `gmdl-ia.js` — Standalone adapter module implementing browser-side IA discovery and playback.
  - Independent PoC acceptance verification (`node --test gmdl-ia.test.js` 10/10 pass).
  - Push to remote branch `poc/ia-audio-discovery` and report whether push succeeds.
- **Constraints:** Zero IA code on `project/antigravity-overhaul` or `main`. Never merge into `main`.
- **Acceptance Gate:** 10 IA tests pass; syntax clean; separate branch push verified.

---

### Task 7 — Viewport & Integration Verification (Phase 6)
- **Status:** ⏳ Pending (Post-Task 4/5 Gate)
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
  - Update `HANDOFF.md` with final commit hashes for host-side transfer.
  - Execute host-side transfer to `puerjeer/gmdl-theme-pack` branch `main`.
  - Verify separate push of `poc/ia-audio-discovery`.
- **Acceptance Gate:** All RR checklist items verified; both branch transfers reported.

---

## 5. Delegation Plan & Worktree Conflict Boundaries

### 5.1 Subagent & Worktree Capabilities Reference
Official Antigravity 2.0 architecture supports `invoke_subagent` with `Workspace` modes (`inherit`, `branch`, `share`) and Projects "New Worktree Mode" for concurrent process isolation (referencing `https://antigravity.google/docs/subagents/` and `https://antigravity.google/docs/projects/`).
*Runtime Principle:* Actual capability must be demonstrated in the live session, not inferred from documentation alone.

### 5.2 Implementation Delegation Partitioning
To prevent file collision and concurrent write conflicts during implementation:
1. **Worktree 1 (UI + CSS Bundle):** Tasks 4 (WP-B, WP-C, WP-D) operate together in one isolated worktree because they co-modify `gmdl-dark.css` and `gmdl-ui.js`.
2. **Worktree 2 (Deployment Automation):** Task 5 (WP-A `deploy.sh` and mock harness) operates in a separate isolated worktree modifying only shell scripts and configuration templates.
3. **Worktree 3 (Isolated IA PoC):** Task 6 operates on branch `poc/ia-audio-discovery` in its own isolated worktree, creating `gmdl-ia.js` and `gmdl-ia.test.js`.

*Serial Integration Invariant:* The coordinator integrates branches serially and re-runs the full verification suite (`node --test`, `node --check`, `scripts/smoke.sh`, `git diff --check`) on the integrated tree. Tasks that touch the same file are never dispatched concurrently.

### 5.3 Antigravity Subagent Delegation Run Log
Antigravity subagents dispatched during the governance and review phase are logged below:

| Delegation ID | Agent Type | Assigned Role Hat | Assigned Task & Scope | Workspace Mode | Runtime Status & Exposure | Findings & Outcome |
|---|---|---|---|---|---|---|
| `2b7a5ad6-59ed-40b9-ab82-b9cab6402a2c` | `research` | PM Gate Compliance Auditor | Read-only audit of PM gate compliance across Stages 01–06, SPEC, and contracts | `inherit` (read-only) | Completed; Runtime ID exposed in transcript | 7/7 PM gates passed (SMART goals, milestones, Mendelow, 5×5 heatmap, dependencies, deploy contract, schema) |
| `02fee6d4-38b3-4669-b757-0b4703e9780d` | `research` | IA Scope Isolation Auditor | Read-only audit of IA scope commissioning, branch isolation, and absent Stage 7/smoke | `inherit` (read-only) | Completed; Runtime ID exposed in transcript | 7/7 Isolation checks passed (IA on `poc/ia...`, zero IA code on `main`, absent Stage 7/smoke, clean `126853a`) |
| `e85fc2f1-f688-4ca5-81de-867ab5adb1b4` | `research` | Governance & Deploy Auditor | Read-only audit of 5-step deploy consistency, risk heatmap, RACI 15/15, Mendelow, change log | `inherit` (read-only) | Completed; Runtime ID exposed in transcript | Initial run: 5/6 pass (Check 1 FAIL due to missing deploy steps in `HANDOFF.md`, Checks 2–6 PASS). Defect subsequently remediated directly; no subagent re-dispatch was launched. |
| `6d91e5c7-b644-4c04-9a1c-28c64b7afa21` | `research` | IA Scope & Gate Auditor | Read-only audit of IA isolation, gate status integrity, and absent files | `inherit` (read-only) | Completed; Runtime ID exposed in transcript | 7/7 Checks passed (IA on `poc/ia...`, status integrity, Stage 7/smoke/IA code absent, zero broken links/whitespace) |
| `462ddff6-060e-41ef-81e3-5b62cb61289b` | `research` | Spec Edge-Case & Contract Auditor | Read-only audit of deployment edge cases, duplicate-key preference contract, test suite separation, and invariants | `inherit` (read-only) | Pending / timed out in wait loop; no pass claimed | Running / unreturned during coordinator review window; no pass claim recorded. Direct file-level coordinator checks verified independently instead. |

*Note on Subagent Operational Scope:* Only read-only research subagents have been dispatched to date. No implementation subagents or multi-worktree execution tasks have been launched.

---

## 6. Actionable Escalation Path

If an unexpected obstacle or blocker arises during execution, the following actionable escalation path is followed:

```
[Issue Encountered]
       │
       ▼
[Is resolution within approved plan & specs?] ──YES──► [Apply documented mitigation autonomously & log]
       │
       NO (Scope change / Human-only credential / Paid action / Protected workflow / Material trade-off)
       ▼
[Capture state & halt mutation]
       │
       ▼
[Prepare concise escalation ticket in Chat UI]
- Exact nature of blocker & reproduction command
- Potential options with pros, cons, and risks
- Recommended course of action
- Specific input or decision requested from Owner (OWN)
```

---

## 7. Reusable Project Change-Log Template

The following change-log format is maintained for all subsequent substantive alterations:

```markdown
### Change Log Entry: [CR-YYYYMMDD-XX]
- **Date & Timestamp (+08):** YYYY-MM-DD HH:MM:SS +0800
- **Author Hat / Role:** [PM | IMP | QA | OWN]
- **Decision:** [Approved / Rejected / Pending Coordinator Review]
- **Status:** [Drafted | Verified | Integrated]
- **Affected Artifacts:** [File paths]
- **Nature of Change:** [Scope Clarification | Architecture Refinement | Safety Fix | Test Gate]
- **Rationale & Trigger:** [Explain why change was introduced]
- **Impact on Scope:** [Explicit impact on product scope, boundaries, or exclusions]
- **Impact on Schedule:** [Explicit impact on milestone timelines or critical path]
- **Impact on Risks:** [Explicit impact on risk scores, triggers, or mitigations]
- **Impact on Quality:** [Explicit impact on test criteria, verification metrics, or standards]
- **Verification Performed:** [Commands run and results]
```
