# 05 — Risk Register
<!-- Stage 5 of 8 governance documents -->
<!-- Project: gmdl-theme-pack-agent · Branch: project/antigravity-overhaul -->
<!-- Last updated: 2026-10-13 (Documentation Scope Rebaseline) -->

## 1. Risk Scoring Methodology

- **Likelihood (L):** 1 (Rare) · 2 (Unlikely) · 3 (Moderate) · 4 (Likely) · 5 (Almost Certain)
- **Impact (I):** 1 (Negligible) · 2 (Minor) · 3 (Moderate) · 4 (Major) · 5 (Catastrophic)
- **Risk Score** = Likelihood × Impact (Scale 1–25)
  - `1–5`: **Low** (Routine monitoring)
  - `6–11`: **Medium** (Named role owner required; proactive mitigation)
  - `12–25`: **High** (Named role owner, concrete mitigation actions, explicit trigger, contingency plan, and active status tracking mandatory)

---

## 2. 5×5 Risk Heat Map

```
IMPACT (I)
  5 │               │               │ [R-08] (15)   │ [R-04] (20)   │               │
  4 │ [R-01] (4)    │ [R-06] (8)    │ [R-05] (12)   │               │               │
  3 │ [R-02] (3)    │ [R-03] (6)    │ [R-11] (9)    │ [R-10] (12)   │               │
  2 │               │ [R-12] (4)    │               │               │               │
  1 │               │               │ [R-07] (3)    │ [R-09] (4)    │               │
────┼───────────────┼───────────────┼───────────────┼───────────────┼───────────────┼─► LIKELIHOOD (L)
         1 (Rare)      2 (Unlikely)    3 (Moderate)     4 (Likely)     5 (Almost Certain)
```

| Likelihood \ Impact | 1 (Negligible) | 2 (Minor) | 3 (Moderate) | 4 (Major) | 5 (Catastrophic) |
|---|---|---|---|---|---|
| **5 (Almost Certain)** | — | — | — | — | — |
| **4 (Likely)** | R-09 (4) | — | R-10 (12) | — | R-04 (20) |
| **3 (Moderate)** | R-07 (3) | — | R-11 (9) | R-05 (12) | R-08 (15) |
| **2 (Unlikely)** | — | R-12 (4) | R-03 (6) | R-06 (8) | — |
| **1 (Rare)** | — | — | R-02 (3) | R-01 (4) | — |

---

## 3. Comprehensive Risk Register (Seven Mandatory Categories)

| ID | Category | Risk Description | L | I | Score | Level | Role Owner | Mitigation Actions, Triggers & Contingencies |
|---|---|---|---|---|---|---|---|---|
| **R-01** | **Scope** | IA PoC code or dependencies leak into mainline `project/antigravity-overhaul` assets. | 1 | 4 | 4 | Low | `PM` | Strictly branch IA on fresh worktree `poc/ia-audio-discovery`. Pre-push diff audit against `126853a` on `main`. |
| **R-02** | **Schedule** | Premature test script creation before specification review blocks linear pipeline. | 1 | 3 | 3 | Low | `PM` | Enforce strict ordering rule: Spec → Coordinator Review → Quality Plan (`07-quality-test-plan.md`) → Smoke Script. |
| **R-03** | **Resource / Cost** | Model quota limits interrupt autonomous execution during development phases. | 2 | 3 | 6 | Medium | `PM` | **Mitigation:** Inspect model availability at phase boundaries; maintain log; fallback to Gemini 3.8 Flash; community free models as defined emergency protocol. |
| **R-04** | **Technical** | `deploy.sh` script encounters syntax error, lock contention, or reload failure during execution. | 4 | 5 | 20 | **High** | `IMP` | **Mitigation Actions:** Mandatory preflight lock, clean tree check, path verification, `$PRE_HEAD` capture, and backup. Core five-step order: Step 1 (`git pull --ff-only` immediately followed on success within the same step by recording `PULLED_HEAD=$(git rev-parse HEAD)`) → Step 2 (compute asset hashes) → Step 3 (fail-closed atomic config update enforcing exactly one token per shipped asset) → Step 4 (`nginx -t` via safe argv array) → Step 5 (graceful reload via safe argv array). Deterministic safe rollback covering any post-pull failure during Step 2, 3, 4, or 5: restore config via atomic restore staging with byte-exact `cmp -s` verification; reset code ONLY if clean and HEAD equals `$PULLED_HEAD`; refuse reset if dirty or mismatched.<br>**Trigger:** Non-zero exit code during hashing, config update, syntax test, or reload.<br>**Contingency:** Emergency restoration of timestamped vhost backup, service traffic reload, release lock via EXIT trap.<br>**Status:** Active; contract specified in `docs/spec/modules/deploy.sh.md`. |
| **R-05** | **Technical** | Shared glass styling degrades readability or contrast in light mode. | 3 | 4 | 12 | **High** | `IMP` | **Mitigation Actions:** Implement dedicated light-mode translucent surface styling (`html.glass:not(.dark)`) with high contrast text tokens (`#1f2937`) and subtle box-shadows.<br>**Trigger:** Text contrast ratio < 4.5:1 on light glass cards.<br>**Contingency:** Adjust surface opacity fallback tokens and enforce background alpha boundaries.<br>**Status:** Active; styling rules defined in `docs/spec/modules/gmdl-dark.css.md`. |
| **R-06** | **Technical** | Malformed preference import corrupts client `localStorage` or executes arbitrary code. | 2 | 4 | 8 | Medium | `IMP` | **Mitigation:** Single strict format `GMDL1:{"v":1,"settings":...}`; require all nine keys exactly once; ban unknown keys; reject raw JSON / Base64; absolute ban on `eval()`. Safe error notice on failure without touching storage. |
| **R-07** | **External** | Live site endpoint (`https://music.archfox.eu.cc/music`) returns 404 or remains unreachable. | 3 | 1 | 3 | Low | `QA` | Mark live site checks honestly as **currently BLOCKED/UNVERIFIED**. Planned local viewport and fixture checks after implementation (explicitly unexecuted in this documentation-only phase). |
| **R-08** | **External** | Upstream release binary digest mismatch leads to running untrusted or corrupted binary. | 3 | 5 | 15 | **High** | `QA` | **Mitigation Actions:** Record official GitHub release API digest (`sha256:be7b...`); document mismatch with legacy digest found in prior task context (provenance unverified); require download-time local `sha256sum` verification against the official digest before any future execution; never run unverified binary.<br>**Trigger:** Request to execute binary during test phases.<br>**Contingency:** Gate loopback testing until Stage 7 quality test plan defines and reviews loopback execution procedure.<br>**Status:** Active; logged in `01-requirements.md` and `08-status.md`. |
| **R-09** | **External** | Local sandbox lacks `nginx`/`openresty` binary for runtime testing. | 4 | 1 | 4 | Low | `QA` | Mark `nginx -t` in sandbox as **currently BLOCKED/UNVERIFIED**. Provide 12-case offline mock test harness for `deploy.sh` validation. |
| **R-10** | **Stakeholder** | Unclear handoff credentials or missing deployment inputs halt final rollout. | 4 | 3 | 12 | **High** | `PM` | **Mitigation Actions:** Consolidate deployment inputs into `HANDOFF.md` for future provision. Autonomous execution authorized for all local tasks and commit creation.<br>**Trigger:** Attempt to execute deployment without server credentials.<br>**Contingency:** Halt live deployment cleanly; report completed local mock test verification.<br>**Status:** Active; checklist cataloged in `HANDOFF.md`. |
| **R-11** | **Quality** | Mobile layout overflows horizontally or touch targets fail ergonomic bounds on small viewports. | 3 | 3 | 9 | Medium | `QA` | **Mitigation:** Explicit viewport test matrix covering 320×568, 375×812, 390×844, 768×1024, 1280×800. Enforce minimum 44px touch targets and measured `scrollWidth <= clientWidth`. |
| **R-12** | **Quality** | Regressions in existing `gmdl-ui.test.js` tests during UI refactoring. | 2 | 2 | 4 | Low | `QA` | Strict invariant: `gmdl-ui.test.js` remains untouched at 8 pass / 0 fail / 0 skipped. Run baseline tests after every modification. |

---

## 4. Top-Three Priority Risk Analysis

1. **Priority 1 — R-04: Deployment Failure & Destructive Code Reset (Score 20, High):**
   - *Impact:* An erroneous rollback command could wipe uncommitted code or crash production services.
   - *Active Control:* Lock-first preflight, capture `$PRE_HEAD`, record `$PULLED_HEAD`, atomic config staging, safe conditional reset only when worktree is clean and matches `$PULLED_HEAD`, EXIT trap unlock, and 12 offline mock test cases.
2. **Priority 2 — R-08: Untrusted Upstream Binary Execution (Score 15, High):**
   - *Impact:* Running a binary with an unverified cryptographic checksum could introduce security vulnerabilities or corrupt system state.
   - *Active Control:* Strict verification against official GitHub API v1.1.1 digest (`sha256:be7b...`); download-time local `sha256sum` verification required before any future execution; legacy digest from prior task context discarded as unverified; no binary downloaded or executed before Stage 7 review.
3. **Priority 3 — R-05 & R-10: Light Glass Readability (Score 12) & Missing Deployment Inputs (Score 12):**
   - *Impact:* Poor text contrast harms end-user usability; missing deployment inputs causes deployment confusion.
   - *Active Control:* Formal light-mode CSS tokens maintaining WCAG AA contrast; consolidated deployment parameters tracked in `HANDOFF.md`.

---

## 5. Devil's-Advocate Worst-Case Scenario & Mitigations

### Worst-Case Scenario Description
"A sudden model quota cut blocks active LLM execution during a deployment script run; concurrently, `git pull` fetches an unexpected remote commit while local uncommitted edits exist on the server; the deployment script blindly executes `git reset --hard ORIG_HEAD`, obliterating uncommitted host-side configuration; `nginx -t` fails due to syntax corruption, the server crashes, and production service goes completely dark without a valid backup."

### Multi-Layered Mitigation Strategy Against Worst Case
1. **Concurrency Lock Before Cleanliness Check:** Preflight acquires an exclusive lock first, preventing concurrent or raced deployments.
2. **Preflight Clean Worktree Invariant:** The script immediately inspects `git status --porcelain`. If any uncommitted or untracked changes exist, it halts before taking any action.
3. **Pre-Deploy HEAD & Pulled HEAD Tracking:** The script explicitly captures `PRE_HEAD` prior to pull, and `PULLED_HEAD` immediately post-pull. It never references ambiguous git aliases like `ORIG_HEAD`.
4. **Refusal of Destructive Reset on Dirty Trees:** If post-pull worktree becomes dirty or HEAD does not equal `PULLED_HEAD`, the rollback routine **refuses** destructive code reset, preserves all files intact, restores only the validated configuration backup, and emits an urgent recovery report.
5. **Always-Active EXIT Trap:** An EXIT trap ensures the single-instance lock is cleared on every code path, preventing deadlock.
6. **Local Mock Verification Requirement:** The script shall be verified offline against this exact failure mode (`MOCK-09` and `MOCK-10`) in a planned test harness before any production deployment is ever contemplated. In this phase, the 12 mock cases remain planned specifications only (unexecuted).

---

## 6. Autonomous Escalation Rule

- **Review Cadence:** The Coordinator PM reviews the risk register and records updated mitigations at every task start and phase boundary.
- **Autonomous Resolution:** The coordinator proactively applies documented mitigations without interrupting the owner.
- **Escalation Threshold:** The coordinator pauses autonomous execution and contacts the Owner (`OWN`) **ONLY** under exceptional conditions:
  1. Any proposed modification or expansion of the project scope.
  2. Requirement for human-only inputs (e.g. production SSH keys, private server passwords).
  3. Actions incurring monetary costs or accessing paid third-party APIs.
  4. Workflows requiring protected external account authorization or 2FA.
  5. Material unresolved technical or architectural trade-offs that cannot be deduced from existing project specifications.
