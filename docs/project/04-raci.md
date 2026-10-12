# 04 — RACI Matrix
<!-- Stage 4 of 8 governance documents -->
<!-- Project: gmdl-theme-pack-agent · Branch: project/antigravity-overhaul -->
<!-- Last updated: 2026-10-13 (Documentation Scope Rebaseline) -->

> [!NOTE]
> **RACI Governance Principles:**
> - **Roles:** OWN (Owner/Sponsor), PM (Coordinator PM), IMP (Antigravity Implementer), QA (Independent Reviewer/QA), END (End Users), OPS (Upstream Maintainers/Ops).
> - **Rule 1:** Every row contains **exactly one Accountable (`A`)** role.
> - **Rule 2:** Every row contains **at least one Responsible (`R`)** role.
> - **Rule 3:** No composite cells (zero `C/A` or `R/A` entries).
> - **Rule 4:** `A` designates accountability for outcome quality, **not** an operational owner-approval checkpoint. Autonomous execution is pre-authorized.

---

## 1. Key to RACI Definitions

| Symbol | Definition | Operational Meaning |
|---|---|---|
| **R** | **Responsible** | Does the engineering work, creates files, runs commands, or executes steps. |
| **A** | **Accountable** | Owns the ultimate delivery outcome and quality integrity (strictly one per row). |
| **C** | **Consulted** | Provides input, specifications, or constraints during production. |
| **I** | **Informed** | Receives informational status updates upon completion. |
| **—** | **Not Involved** | Role has no active or passive role in this specific deliverable. |

---

## 2. Deliverables & Work Packages RACI Matrix

| # | Deliverable / Work Package Category | Deliverable Item | OWN | PM | IMP | QA | END | OPS | Check (A/R) |
|---|---|---|---|---|---|---|---|---|---|
| 1 | **UI** | Shared Glass Styling (Dark & Light Modes) (`gmdl-dark.css`, `gmdl-ui.js`) | I | A | R | C | I | — | 1A, 1R |
| 2 | **UI** | Mobile Personalization Region & Keyboard Accessibility (`gmdl-ui.js`, `gmdl-dark.css`) | I | A | R | C | I | — | 1A, 1R |
| 3 | **UI** | Preference Export / Import Engine (`gmdl-ui.js`) | I | A | R | C | I | — | 1A, 1R |
| 4 | **Deploy Script** | Reversible Deployment Script (`deploy.sh`, lock-first preflight, safe rollback & mock harness) | I | A | R | C | — | I | 1A, 1R |
| 5 | **Docs / Spec** | Governance & Baseline Documentation (Stages 01–06, 08, `TASKS.md`, `HANDOFF.md`) | I | A | R | C | — | — | 1A, 1R |
| 6 | **Docs / Spec** | Canonical Product Specification & Architecture Package ([`docs/spec/SPEC.md`](../spec/SPEC.md), [`docs/spec/ARCHITECTURE.md`](../spec/ARCHITECTURE.md), [`docs/spec/MODULES.md`](../spec/MODULES.md)) | I | A | R | C | — | — | 1A, 1R |
| 7 | **Docs / Spec** | Per-Module Contracts (`docs/spec/modules/*`) | I | A | R | C | — | — | 1A, 1R |
| 8 | **IA PoC Branch** | Commissioned Isolated IA PoC Branch Deliverable ([`docs/spec/IA-POC-BRANCH-PLAN.md`](../spec/IA-POC-BRANCH-PLAN.md), `poc/ia-audio-discovery`) | I | A | R | C | — | — | 1A, 1R |
| 9 | **Tests** | Quality Test Plan (`docs/project/07-quality-test-plan.md`) | I | C | R | A | — | — | 1A, 1R |
| 10 | **Tests** | Unit Test Suite Maintenance & IA Tests (`gmdl-ui.test.js`, `gmdl-ia.test.js`) | I | C | R | A | — | — | 1A, 1R |
| 11 | **Tests** | Smoke Verification Automation (`scripts/smoke.sh`) | I | C | R | A | — | — | 1A, 1R |
| 12 | **Viewport Verification** | Browser Viewport Acceptance Checks (320px, 375px, 390px, 768px, 1280px) | I | C | R | A | I | — | 1A, 1R |
| 13 | **Release** | Release Readiness Assessment & Verification Checklist | I | R | C | A | — | — | 1A, 1R |
| 14 | **Host-Side Publication** | Host-Side Commit Transfers to `puerjeer/gmdl-theme-pack` (`main` and `poc/ia-audio-discovery`) | A | R | C | C | I | I | 1A, 1R |
| 15 | **Governance Decision** | Authoritative Scope Rebaseline & Out-of-Scope Exceptions | A | R | C | C | — | — | 1A, 1R |

---

## 3. RACI Structural Verification Summary

- **Total Rows Evaluated:** 15
- **Rows with Exactly One `A`:** 15 (100%)
- **Rows with At Least One `R`:** 15 (100%)
- **Composite Cells (`C/A`, `R/A`):** 0 (0%)
- **Role Distribution of `A`:**
  - `PM`: 8 deliverables (Rows 1–8: UI packages, deploy script, governance docs, product spec, module contracts, IA PoC branch deliverable)
  - `QA`: 5 deliverables (Rows 9–13: Quality plan, unit tests, smoke script, viewport checks, release readiness assessment)
  - `OWN`: 2 deliverables (Rows 14–15: Host-side publication transfers to `main` and `poc/ia-audio-discovery`, scope authority decisions)
  - `IMP`, `END`, `OPS`: 0 (Pure engineering execution, end-user persona, and upstream operations)
