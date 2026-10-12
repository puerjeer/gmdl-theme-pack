# 03 — Stakeholders
<!-- Stage 3 of 8 governance documents -->
<!-- Project: gmdl-theme-pack-agent · Branch: project/antigravity-overhaul -->
<!-- Last updated: 2026-10-13 (Documentation Scope Rebaseline) -->

> [!NOTE]
> **Governance Notice (2026-10-13):**
> In this single-owner repository, individual operational functions are structured into distinct
> role-hats to ensure rigorous project management, engineering separation, and objective quality verification.
> Autonomous execution and final publication to `puerjeer/gmdl-theme-pack` branch `main` (and `poc/ia-audio-discovery`)
> via host-side transfer have been explicitly authorized by the project owner. No ordinary owner-approval gates are placed between tasks.

---

## 1. Stakeholder Register (Six Role-Hats)

| Role Code | Role Hat | Description & Operational Scope | Involvement & Authority |
|---|---|---|---|
| **OWN** | **Owner / Sponsor** | Project initiator and overall sponsor. Sets authoritative scope, authorizes autonomous execution and host-side publication, resolves material unresolved trade-offs, and holds sole authority over external credentials, scope alterations, and paid actions. | Sets high-level goals; pre-authorizes autonomous execution and final push; consulted only on genuine exceptions. |
| **PM** | **Coordinator PM** | Antigravity AI operating in project coordinator and management capacity. Sequences work packages, tracks risks, enforces governance ordering rules, performs inter-task reviews, and maintains project logs. | Autonomous coordinator; conducts phase boundary reviews; tracks RACI compliance. |
| **IMP** | **Antigravity Implementer** | Antigravity AI operating in engineering capacity. Authors specifications, module contracts, CSS/JS code, shell scripts, and configuration templates. | Autonomous implementation of authorized work packages within approved specifications. |
| **QA** | **Independent Reviewer / QA** | Antigravity AI operating in testing and verification capacity. Executes baseline checks, unit tests, syntax linters, viewport audits (320px to 1280px), and release-readiness checklists. | Objectively verifies acceptance criteria; flags unverified items honestly. |
| **END** | **End Users** | Mobile and desktop music listeners utilizing the frontend theme pack across browsers. Persona represented through usability and accessibility requirements (touch targets, contrast, keyboard navigation, preference export). | Passive / Persona-driven; represented by observable acceptance criteria in specifications. |
| **OPS** | **Upstream Maintainers / Ops** | Maintainers of upstream `go-music-dl` and production server infrastructure administrators. | Passive; no upstream Go source code changes requested; server deployment environment details pending. |

---

## 2. Mendelow Influence-Interest Grid

The six role-hats are mapped across the Mendelow Matrix quadrants, reflecting realistic stakeholder dynamics:

```
HIGH INFLUENCE
   ▲
   │  [KEEP SATISFIED]                    │  [MANAGE CLOSELY]
   │  • OPS (Upstream Maintainers / Ops)  │  • OWN (Owner / Sponsor)
   │                                      │  • PM (Coordinator PM)
   │──────────────────────────────────────┼──────────────────────────────────────
   │  [MONITOR]                           │  [KEEP INFORMED]
   │  (Explicitly empty — no roles        │  • END (End Users)
   │   warrant passive monitoring)        │  • IMP (Antigravity Implementer)
   │                                      │  • QA (Independent Reviewer / QA)
   ▼
LOW INFLUENCE ────────────────────────────────────────────────────────► HIGH INTEREST
```

| Quadrant | Strategy | Mapped Roles | Rationale in Repository Lifecycle |
|---|---|---|---|
| **High Influence, High Interest** | **Manage Closely** | `OWN`, `PM` | `OWN` holds authoritative scope authority and final repository ownership. `PM` orchestrates task sequence, dependency gates, and risk mitigations. |
| **High Influence, Low Interest** | **Keep Satisfied** | `OPS` | Upstream maintainers hold architectural influence over backend APIs; server ops dictate deployment prerequisites. Satisfied by zero Go source modifications and the planned future offline mock verification (not executed in this phase). |
| **Low Influence, High Interest** | **Keep Informed** | `END`, `IMP`, `QA` | `END` users have low direct repo influence but high interest because theme aesthetics, contrast, and mobile usability directly impact their daily experience. `IMP` and `QA` hats execute granular engineering and verification within approved specifications. |
| **Low Influence, Low Interest** | **Monitor** | *(Explicitly empty)* | No project role qualifies as low-interest. End users are directly impacted and are not relegated to passive monitoring. |

---

## 3. Stakeholder Analysis: Concerns, Resistance & Engagement Strategy

| Role Code | Mendelow Quadrant | Anticipated Concerns & Potential Resistance | Observed vs Anticipated | Engagement Method | Communication Frequency |
|---|---|---|---|---|---|
| **OWN** | High Influence, High Interest (Manage Closely) | Scope bloat, unauthorized remote actions, unverified external binaries running in production, loss of dark theme aesthetics. | **Observed:** Owner explicitly mandated strict four-package scope, isolated IA branch, and preflight deploy safety. | Antigravity interactive chat UI; phase status and handoff reports. | Task completions & material escalation triggers only. |
| **PM** | High Influence, High Interest (Manage Closely) | Linear phase gate violations, race conditions in preflight deploy logic, premature test script drafting. | **Observed:** Enforced ordering rules: specs drafted, review required prior to Stage 7 test plan. | Internal coordinator reviews, log audits, RACI validation. | Continuous at every task boundary. |
| **OPS** | High Influence, Low Interest (Keep Satisfied) | Invasive code changes breaking upstream Go releases, server downtime from bad nginx reloads. | **Anticipated:** Concern that deployment automation could disrupt live reverse proxy service. | Standalone injection architecture; planned fail-closed offline mock testing of `deploy.sh` after implementation; no mock test has run yet. | Milestone completion artifacts. |
| **IMP** | Low Influence, High Interest (Keep Informed) | Ambiguous interface contracts, conflicting requirements between light/dark glass modes. | **Anticipated:** Ambiguity in preference export/import schema or viewport requirements. | Canonical specifications in `docs/spec/SPEC.md` and module contracts. | Continuous during authoring phases. |
| **QA** | Low Influence, High Interest (Keep Informed) | Flaky unit tests, unverified external live endpoints blocking test runs. | **Anticipated:** False passes on unverified endpoints or missing local binaries. | Deterministic local test suites (`node --test`), honest `BLOCKED/UNVERIFIED` tags. | At test execution gates and release readiness. |
| **END** | Low Influence, High Interest (Keep Informed) | Illegible text in light mode, broken mobile touch targets, loss of custom settings on browser restart. | **Anticipated:** Usability friction on mobile devices or corrupted localStorage. | Automated viewport checks (320px–1280px), non-modal keyboard navigation, strict JSON schema validation. | At each acceptance gate and release-readiness review, using persona-based accessibility/usability criteria. |

---

## 4. Decision Authority Matrix

| Category | Deciding Role | Operating Mode |
|---|---|---|
| Task execution within approved plan | PM / IMP | Autonomous |
| Architecture & module specification | PM / IMP | Autonomous |
| Quality verification & test evaluation | QA | Autonomous |
| Phase boundary transition sign-off | PM / QA | Autonomous |
| Final publication to `main` and `poc/ia-audio-discovery` | PM / QA | Authorized by OWN (Autonomous execution via host transfer) |
| Project scope alterations | OWN | Explicit direction required |
| Production server credentials / SSH access | OWN | Human-only provision |
| Wikimedia Commons gate re-evaluation | OWN | Explicit direction required |
