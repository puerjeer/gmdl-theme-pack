# 07 — Quality & Test Plan
<!-- Stage 7 of 8 governance documents -->
<!-- Project: gmdl-theme-pack-agent · Branch: project/antigravity-overhaul -->
<!-- Stage: Task 3B accepted; Task 3C Smoke Script verified; Task 5 deployment addendum accepted by coordinator -->
<!-- Date: 2026-10-13 -->

> [!NOTE]
> **Governance Stage 7 Review Gate:**
> This document is drafted under Sub-task 3A following coordinator acceptance of Task 2 specifications on 2026-10-13 03:51 UTC+08.
> In accordance with the preserved ordering invariant (`SPEC → Coordinator Review → Stage 7 Quality Test Plan → Coordinator Review → Smoke Automation → Code`),
> the coordinator completed the Sub-task 3B review and **accepted this plan on 2026-10-13 04:20 UTC+08**.
> Sub-task 3C (`scripts/smoke.sh`) was authored and verified against this contract on 2026-10-13; the Stage 7 → Smoke → Code ordering gate is now satisfied for implementation.

---

## 1. Document Control, Scope & Quality Objectives

### 1.1 Version & Status

| Attribute | Value |
|---|---|
| Document ID | `docs/project/07-quality-test-plan.md` |
| Version | v2.1 |
| Phase / Task | Phase 2 / Task 3 complete; Task 4/5/6 execution results appended; v2.1 audit-driven regression addenda accepted before code |
| Current Status | ✅ Stage 7 accepted; v2.1 addenda accepted before test/code changes; deployment 12/12, IA 10/10, independent final reviews passed; latest full smoke 10/0 at 06:38:05 |
| Author Hat | QA / IMP |
| Review Authority | Coordinator |
| Baseline Commit | `126853a` |

### 1.2 Testing Scope & Work Packages

Testing activities are partitioned into four mainline work packages and one isolated proof-of-concept branch:
- **WP-A (Deployment Automation):** Verification of `deploy.sh` read-only Git-metadata-directory lock preflight, lock-before-dirty ordering, dry-run without filesystem writes, syntactically complete vhost include checks, fast-forward pull, all-asset hashing before config replacement, fail-closed atomic vhost update with exact token cardinality, assembled configuration syntax verification, safe reload argv, and deterministic rollback across 12 offline mock conditions (`MOCK-01` through `MOCK-12`).
- **WP-B (Shared Glass Styling):** Dual-mode styling in `gmdl-dark.css` and `gmdl-ui.js`, preserving verified dark mode aesthetics while extending translucent glass surfaces into light mode (`html.glass:not(.dark)`), slider responsiveness, accent swatches across both modes, and reproducible WCAG AA contrast evaluated at both CSS gradient stops using the exact runtime `--glass-a` mapping over fixed light-mode background fixtures.
- **WP-C (Mobile & Keyboard Usability):** Non-modal personalization region (`role="region"`, `aria-controls`, `aria-expanded`), Tab navigation without modal trapping, Escape key dismissal with focus restoration to `#gmdl-ui-btn`, visible focus rings (`:focus-visible`) and touch targets ≥44×44px across all visible interactive controls (explicitly excluding the hidden `<input type="file">`), and zero horizontal overflow (`scrollWidth <= clientWidth`) across 5 viewports (320px to 1280px).
- **WP-D (Preference Export / Import):** Strict `GMDL1:` JSON format, deterministic key serialization order (`v`, `settings`; 9 settings keys), full schema validation (all 6 enum domains, strict boolean, integer bounds and inclusive/just-outside/fractional checks for `blur` 0..24 and `glass` 0..100), token-aware duplicate member name rejection comparing decoded JSON member names at both envelope (`"v"` vs `"\u0076"`) and settings (`"theme"` vs `"\u0074heme"`) levels without third-party dependencies or `eval()`, static prohibition of `eval(` / `Function(`, device-local background image exclusion with explicit notice, accessible status reporting via dedicated `#gmdl-import-status` node, and side-effect-free snapshot invariance.
- **WP-IA (Commissioned Isolated PoC):** Verification of 10 deterministic unit tests (`IA-01` through `IA-10`) in `gmdl-ia.test.js` executed strictly on isolated branch `poc/ia-audio-discovery` branched from `126853a` with zero mainline contamination.
- **Upstream UI Loopback Verification & Visual Regression Gate:** Defined procedure for authentic upstream binary verification on an isolated loopback port using verified GitHub API release digests, accompanied by mandatory real-page before/after screenshot captures across three reference viewports.

### 1.3 Quality Objectives & Principles
1. **Contract Traceability:** 100% of functional requirements and module contract clauses map directly to verifiable test cases.
2. **Deterministic Offline Execution:** All planned automated test suites execute offline without external network dependencies, third-party runtime frameworks, or active server access.
3. **Strict Suite Separation:** Executed baseline tests (`gmdl-ui.test.js`) remain untouched; new mainline features are tested in a dedicated suite (`gmdl-ui-enhancements.test.js`); deployment logic is verified via `scripts/deploy-mock.sh`; IA discovery is tested in `gmdl-ia.test.js` on an isolated branch.
4. **Honest Evidence Boundaries:** Only executed tests are marked as passed; planned or unexecuted tests remain explicitly labeled as planned; external dependencies lacking local tooling remain `currently BLOCKED/UNVERIFIED`.

### 1.4 Defect Severity Classification

| Severity Level | Definition | Project Policy & Impact |
|---|---|---|
| **Critical (Blocker)** | Security vulnerability (`eval()`, prototype pollution), destructive deployment failure, corrupted `localStorage`, unverified binary execution, mainline contamination by IA code, or broken baseline regression. | Immediate halt; blocks phase transition and release. |
| **Major** | Preference schema duplicate key bypass, failed atomic rollback, broken touch target (<44px), viewport horizontal overflow, failure to return focus on Escape, or real-page visual regression. | Must be resolved before milestone completion. |
| **Minor** | Inconsistent error string formatting, minor CSS visual alignment flaw with adequate contrast, or non-breaking doc typo. | Corrected prior to final release-readiness review. |

### 1.5 Environment & Evidence-Recording Rules
- **Execution Environment:** Standard Linux CLI inside `/workspace/gmdl-theme-pack-agent` using Node.js v24.19.0.
- **Sandboxing:** Commands run within standard sandbox; unsandboxed network commands are forbidden for test execution.
- **Evidence Recording:** Every test execution must record exact terminal command, exit status, duration, pass/fail/skip counts, and timestamp in test logs and handoff records.

---

## 2. Comprehensive Requirements Traceability Matrix (RTM) & Crosswalk

The crosswalk below maps every requirement and acceptance criterion from accepted project specifications (`SPEC.md`), module contracts (`deploy.sh.md`, `gmdl-dark.css.md`, `gmdl-ui.js.md`, `gmdl-feat.js.md`, `openresty-vhost-example.conf.md`), governance requirements (`01-requirements.md`), and the IA branch plan (`IA-POC-BRANCH-PLAN.md`) to specific tests, verification methods, evidence artifacts, and current execution statuses.

### 2.1 Traceability Crosswalk

| Source Standard | Criterion ID | Requirement Summary | Planned Test / Verification Method | Expected Result & Verification Gate | Current Status |
|---|---|---|---|---|---|
| **SPEC WP-A** | `AC-A01` | Preflight lock, checks, backup & exact 5-step order | `MOCK-01`, `MOCK-03`, `MOCK-04`, `MOCK-09` | Read-only metadata-dir lock before dirty check; `GIT_OPTIONAL_LOCKS=0` status must exit 0 and be empty or fail closed without index refresh; valid complete include; required commands before backup/pull; all hashes precede replacement | ✅ **EXECUTED / PASS (Task 5 v2.1)** |
| **SPEC WP-A** | `AC-A02` | Pull failure or unverifiable pulled HEAD leaves active config untouched; no unsafe reset | `MOCK-05` | Non-zero pull exits; successful pull with failed `PULLED_HEAD` capture halts before hashing/config changes with manual-recovery diagnostic; neither path performs `git reset` | ✅ **EXECUTED / PASS (Task 5 v2.1)** |
| **SPEC WP-A** | `AC-A03` | Post-pull failure (steps 2–5) triggers safe rollback | `MOCK-06`, `MOCK-10` | Restores backup via staging file (`.rollback.tmp.$$`) with `cmp -s` check | ✅ **EXECUTED / PASS (Task 5 final)** |
| **SPEC WP-A** | `AC-A04` | Atomic vhost update with metadata and 1-token cardinality | `MOCK-07`, `MOCK-08` | Exactly 1 token per shipped asset verified; mode/owner preserved; same-directory rename verified | ✅ **EXECUTED / PASS (Task 5 final)** |
| **SPEC WP-A** | `AC-A05` | Real assembled syntax test via safe argv array (`-c` / `-p`) | `MOCK-09` | Safe array passes `-t -c "$CONF"` and optional `-p "$PREFIX"`; handles whitespace and rejects malformed include syntax | ✅ **EXECUTED / PASS (Task 5 final)** |
| **SPEC WP-A** | `AC-A06` | Safe reset predicated on clean tree AND `HEAD == $PULLED_HEAD` | `MOCK-11`, `MOCK-12` | Reset succeeds on clean matching HEAD; safely refused on dirty or revision drift | ✅ **EXECUTED / PASS (Task 5 final)** |
| **SPEC WP-A** | `AC-A07` | Lock in Git metadata; released on all exits via EXIT trap | `MOCK-02`, `MOCK-03`, `MOCK-04` | Read-only metadata-directory FD; porcelain clean; contention/reacquisition verified; lock precedes dirty check; no lock file | ✅ **EXECUTED / PASS (Task 5 final)** |
| **SPEC WP-A** | `AC-A08` | Offline mock test suite covers 12 conditions deterministically | `bash scripts/deploy-mock.sh` | 12/12 mock conditions pass cleanly without external network | ✅ **EXECUTED / PASS (Task 5 final)** |
| **SPEC WP-B** | `AC-B01` | Light theme with Style=Glass renders translucent surfaces | `gmdl-ui-enhancements.test.js` (`GLASS-01`) | `.glass` on `<html>` without `.dark` activates light glass surface rules | ✅ **EXECUTED / PASS (Task 4 final)** |
| **SPEC WP-B** | `AC-B02` | Dark mode glass visuals identical to verified baseline | Visual / DOM CSS token check (`GLASS-02`) | Surface gradient, border, backdrop blur match baseline contract | ✅ **EXECUTED / PASS (Task 4 final)** |
| **SPEC WP-B** | `AC-B03` | Slider adjustments dynamically update CSS variables | `gmdl-ui-enhancements.test.js` (`GLASS-03`) | Sliders update `--glass-b` and `--glass-a` custom properties in real time | ✅ **EXECUTED / PASS (Task 4 final)** |
| **SPEC WP-B** | `AC-B04` | Accent color swatches apply correctly in both glass modes | `gmdl-ui-enhancements.test.js` (`GLASS-04`) | Accent swatches update active borders, progress bars, and hover rules | ✅ **EXECUTED / PASS (Task 4 final)** |
| **SPEC WP-C** | `AC-C01` | Non-modal region opens/closes via `#gmdl-ui-btn` with ARIA | `gmdl-ui-enhancements.test.js` (`ACC-01`) | `aria-expanded="true"` / `"false"` toggled; references `aria-controls` | ✅ **EXECUTED / PASS (Task 4 final)** |
| **SPEC WP-C** | `AC-C02` | Escape key dismisses panel and returns focus to trigger | `gmdl-ui-enhancements.test.js` (`ACC-02`) | Keydown `Escape` closes panel; focus returns to `#gmdl-ui-btn` | ✅ **EXECUTED / PASS (Task 4 final)** |
| **SPEC WP-C** | `AC-C03` | Zero horizontal overflow across viewports 320px–1280px | Headless DOM viewport audit (`VIEW-01..05`) | `scrollWidth <= clientWidth` across all 5 specified viewports | ✅ **EXECUTED / PASS (Task 4 final)** |
| **SPEC WP-C** | `AC-C04` | Visible interactive controls have ≥44×44px touch area | Viewport bounding client check (`ACC-03`) | All visible interactive controls (incl. upload/clear/export/import; excluding hidden `<input type="file">`) meet ≥44×44px | ✅ **EXECUTED / PASS (Task 4 final)** |
| **SPEC WP-C** | `AC-C05` | Tab navigation operates naturally without focus traps | Keyboard traversal test (`ACC-04`) | Tab moves sequentially through all visible interactive controls and returns to document | ✅ **EXECUTED / PASS (Task 4 final)** |
| **SPEC WP-D** | `AC-D01` | Export produces `GMDL1:` prefix, compact JSON, 9-key order | `gmdl-ui-enhancements.test.js` (`PREF-01`) | `GMDL1:` prefix; exact envelope & settings key sequence | ✅ **EXECUTED / PASS (Task 4 final)** |
| **SPEC WP-D** | `AC-D02` | Background image data (`gmdl-bgimg`) excluded with notice | `gmdl-ui-enhancements.test.js` (`PREF-02`) | `bgimg` absent from exported string; disclaimer notice present in DOM | ✅ **EXECUTED / PASS (Task 4 final)** |
| **SPEC WP-D** | `AC-D03` | Valid preference code restores all 9 settings immediately | `gmdl-ui-enhancements.test.js` (`PREF-03`) | Settings apply to `localStorage` and DOM classes/variables without reload | ✅ **EXECUTED / PASS (Task 4 final)** |
| **SPEC WP-D** | `AC-D04` | Duplicate key rejection at envelope & settings level | `gmdl-ui-enhancements.test.js` (`PREF-04..06`) | Rejects literal & escape-decoded duplicates (`"v"` vs `"\u0076"`, `"theme"` vs `"\u0074heme"`) at both levels; safe fail | ✅ **EXECUTED / PASS (Task 4 final)** |
| **SPEC WP-D** | `AC-D05` | Round-trip export and import preserves 100% fidelity | `gmdl-ui-enhancements.test.js` (`PREF-13`) | `importCode(exportCode())` produces 100% identical configuration | ✅ **EXECUTED / PASS (Task 4 final)** |
| **SPEC WP-D** | `AC-D06` | Zero `eval()`, `new Function()`, or dangerous deserialization | `gmdl-ui-enhancements.test.js` & static audit (`SEC-EVAL-01`) | 0 matches for `eval(`, `new Function(`, `Function(`, or unsafe string execution in production JS | ✅ **EXECUTED / PASS (Task 4 final)** |
| **SPEC WP-D** | `AC-D07` | Side-effect-free snapshot invariance on rejected import | `gmdl-ui-enhancements.test.js` (`PREF-12`) | Excluding only `#gmdl-import-status`, all storage & DOM match 100% across all invalid payloads | ✅ **EXECUTED / PASS (Task 4 final)** |
| **Module DEP** | `AC-DEP-01` | Lock-first preflight, tree check, backup & path checks | `MOCK-01..04`, `MOCK-09` | Lock precedes `GIT_OPTIONAL_LOCKS=0` status; status failure/dirty output fail closed; dry-run leaves Git index bytes/metadata unchanged; valid include/command preflight precedes backup/pull | ✅ **EXECUTED / PASS (Task 5 v2.1)** |
| **Module DEP** | `AC-DEP-02` | Pull or pulled-HEAD capture failure exits with active config safe | `MOCK-05` | Pull failure or successful pull with failed HEAD capture halts before hash/config; no reset for unknown pulled revision | ✅ **EXECUTED / PASS (Task 5 v2.1)** |
| **Module DEP** | `AC-DEP-03` | Exact 5-step linear core execution sequence | `MOCK-01` | Pull+record HEAD → all hashes → Update conf → nginx -t → Reload | ✅ **EXECUTED / PASS (Task 5 final)** |
| **Module DEP** | `AC-DEP-04` | Post-pull failure safe rollback with atomic staging & `cmp -s` | `MOCK-06`, `MOCK-10` | Restores backup via staging file with byte-exact `cmp -s` verification | ✅ **EXECUTED / PASS (Task 5 final)** |
| **Module DEP** | `AC-DEP-05` | Staging file creation, permissions & exact token cardinality | `MOCK-07`, `MOCK-08` | Verifies exactly one token per asset for all 3 shipped files; fails closed | ✅ **EXECUTED / PASS (Task 5 final)** |
| **Module DEP** | `AC-DEP-06` | Syntax test verifies real assembled configuration context | `MOCK-09` | Safe argv array tests `-c "$NGINX_MAIN_CONF"` and optional `-p "$PREFIX"` | ✅ **EXECUTED / PASS (Task 5 final)** |
| **Module DEP** | `AC-DEP-07` | Safe reset conditional on clean tree AND `HEAD == $PULLED_HEAD` | `MOCK-11`, `MOCK-12` | Resets on clean matching HEAD; safely refuses on dirty or revision drift | ✅ **EXECUTED / PASS (Task 5 final)** |
| **Module DEP** | `AC-DEP-08` | Read-only metadata lock released on every exit via EXIT trap | `MOCK-02..04` | Contention, re-acquisition after success/failure, and lock-before-dirty observed | ✅ **EXECUTED / PASS (Task 5 final)** |
| **Module DEP** | `AC-DEP-09` | Offline mock test harness passes 12 conditions deterministically | `bash scripts/deploy-mock.sh` | 12/12 cases including zero-index-write dry-run, post-pull HEAD-capture failure, no-PRE_HEAD missing-sha preflight, and lock evidence | ✅ **EXECUTED / PASS (Task 5 v2.1)** |
| **Module DEP** | `AC-DEP-10` | Deploy and mock scripts pass Bash syntax validation | `bash -n deploy.sh`; `bash -n scripts/deploy-mock.sh` | Both clean exit 0 with zero syntax errors | ✅ **EXECUTED / PASS (Task 5 final)** |
| **Module CSS** | `AC-CSS-01` | Translucent light glass surface styling with borders | `gmdl-ui-enhancements.test.js` (`GLASS-01`, `GLASS-CONTRAST`) | `html.glass:not(.dark)` applies light glass rules; both gradient stops pass WCAG AA ≥4.5:1 | ✅ **EXECUTED / PASS (Task 4 final)** |
| **Module CSS** | `AC-CSS-02` | Dark mode glass visuals identical to verified baseline | Visual / DOM CSS token check (`GLASS-02`) | Surfaces, borders, and backdrop-filter match baseline dark glass | ✅ **EXECUTED / PASS (Task 4 final)** |
| **Module CSS** | `AC-CSS-03` | Narrow viewports (320px–390px) cause zero overflow | Headless DOM viewport audit (`VIEW-01..03`) | Measured `scrollWidth <= clientWidth` across small viewports | ✅ **EXECUTED / PASS (Task 4 final)** |
| **Module CSS** | `AC-CSS-04` | Visible interactive controls meet touch ergonomics ≥44×44px | Viewport bounding client check (`ACC-03`) | Visible buttons, swatches, sliders, upload/clear/export/import controls satisfy ≥44×44px (hidden file input excluded) | ✅ **EXECUTED / PASS (Task 4 final)** |
| **Module CSS** | `AC-CSS-05` | Distinguishable `:focus-visible` outline on visible controls | Visual focus outline test (`ACC-05`) | 2px solid focus ring on all visible interactive controls (excluding hidden `<input type="file">`) | ✅ **EXECUTED / PASS (Task 4 final)** |
| **Module UI** | `AC-UI-01` | Deterministic `exportCode()` with 9 keys in strict sequence | `gmdl-ui-enhancements.test.js` (`PREF-01`) | Valid `GMDL1:` string with exact key sequence | ✅ **EXECUTED / PASS (Task 4 final)** |
| **Module UI** | `AC-UI-02` | Background image data absent from exported code; UI notice | `gmdl-ui-enhancements.test.js` (`PREF-02`) | `gmdl-bgimg` excluded; notice visible in settings DOM | ✅ **EXECUTED / PASS (Task 4 final)** |
| **Module UI** | `AC-UI-03` | Safe fail-closed rejection on invalid preference import | `gmdl-ui-enhancements.test.js` (`PREF-04..11`) | Rejects invalid schema, all enum domains, strict boolean, integer ranges/fractions, and literal/escaped duplicates; error only in `#gmdl-import-status` | ✅ **EXECUTED / PASS (Task 4 final)** |
| **Module UI** | `AC-UI-04` | Valid imported code immediately updates active styling | `gmdl-ui-enhancements.test.js` (`PREF-03`) | Classes (`.dark`, `.glass`) and variables update without reload | ✅ **EXECUTED / PASS (Task 4 final)** |
| **Module UI** | `AC-UI-05` | Escape key dismisses panel and restores focus to trigger | `gmdl-ui-enhancements.test.js` (`ACC-02`) | Panel hidden; activeElement returns to `#gmdl-ui-btn` | ✅ **EXECUTED / PASS (Task 4 final)** |
| **Module UI** | `AC-UI-06` | `#gmdl-ui-btn` updates `aria-expanded` referencing panel | `gmdl-ui-enhancements.test.js` (`ACC-01`) | Dynamic `aria-expanded="true"` / `"false"` referencing `aria-controls` | ✅ **EXECUTED / PASS (Task 4 final)** |
| **Module UI** | `AC-UI-07` | Zero horizontal overflow across all viewports | Headless DOM viewport audit (`VIEW-01..05`) | Measured `scrollWidth <= clientWidth` across 320px–1280px | ✅ **EXECUTED / PASS (Task 4 final)** |
| **Module UI** | `AC-UI-08` | Baseline unit tests continue to pass 8/0/0 | `node --test gmdl-ui.test.js` | 8 pass, 0 fail, 0 skipped | ✅ **EXECUTED / PASSING** |
| **Module UI** | `AC-UI-09` | Side-effect-free snapshot invariance on rejected import | `gmdl-ui-enhancements.test.js` (`PREF-12`) | Excluding `#gmdl-import-status`, all state matches 100% identically across all negative test cases | ✅ **EXECUTED / PASS (Task 4 final)** |
| **Module UI** | `AC-UI-10` | Strict suite separation: baseline intact, new in enhancement | Suite file inventory & test runners | `gmdl-ui.test.js` intact; new tests in `gmdl-ui-enhancements.test.js` | ✅ **EXECUTED / PASS (Task 4 final)** |
| **Module FEAT** | `AC-FEAT-01` | `node --check gmdl-feat.js` exits 0 | `node --check gmdl-feat.js` | Clean exit code 0 | ✅ **EXECUTED / PASSING** |
| **Module FEAT** | `AC-FEAT-02` | Exact blob/hash identity of `gmdl-feat.js` to baseline `126853a` | `git diff --exit-code 126853a -- gmdl-feat.js` | Clean exit code 0; zero diff lines; byte-for-byte identical to baseline | ✅ **EXECUTED / PASSING** |
| **Module FEAT** | `AC-FEAT-03` | Daily recommended songs button navigation query | Static code inspection & planned DOM check | Verified link target `/music/search?q=%20%20&page=1&page_size=10` | ⏳ Planned / Unexecuted |
| **Module FEAT** | `AC-FEAT-04` | De-duplication logic in `moreBtn` filters duplicate cards | Static code inspection & planned DOM check | Verified deduplication key: `dataset.id + '\|' + dataset.source` | ⏳ Planned / Unexecuted |
| **Module CONF** | `AC-CONF-01` | Static theme asset locations include `expires 1h` | Static config inspection | Location blocks for `.css` and `.js` contain `expires 1h;` | ⏳ Planned / Unexecuted |
| **Module CONF** | `AC-CONF-02` | Location `/` sets `expires -1` and disables gzip on proxy | Static config inspection | Location `/` contains `expires -1;` and `proxy_set_header Accept-Encoding "";` | ⏳ Planned / Unexecuted |
| **Module CONF** | `AC-CONF-03` | Pre-hydration script safely handles uninitialized storage | Static config inspection & JS evaluation | Fallback `try { ... } catch(e) {}` with null-safe access | ⏳ Planned / Unexecuted |
| **Module CONF** | `AC-CONF-04` | Asset query string matches `?v=<hash>` format | Static config inspection | `sub_filter` uses `?v=` query parameter format | ⏳ Planned / Unexecuted |
| **Module CONF** | `AC-CONF-05` | Reference vhost passes real `nginx -t` validation | Nginx syntax check binary in runtime environment | Passes syntax check; **currently BLOCKED/UNVERIFIED** in sandbox | ⚠️ Blocked / Unverified |
| **Req Gate** | `AC-01` | Baseline unit tests pass cleanly (8 pass, 0 fail, 0 skip) | `node --test gmdl-ui.test.js` | Verified test output: 8 pass / 0 fail / 0 skip (~103ms) | ✅ **EXECUTED / PASSING** |
| **Req Gate** | `AC-02` | Production JS files pass syntax compilation | `node --check gmdl-ui.js && node --check gmdl-feat.js` | Both individual syntax checks exit 0 | ✅ **EXECUTED / PASSING** |
| **Req Gate** | `AC-03` | Repository formatting and whitespace pass | Python all-text-file scan & `git diff --check` | 0 trailing whitespace errors across all tracked and untracked text files | ✅ **EXECUTED / PASSING** |
| **Req Gate** | `AC-04` | Reversible `deploy.sh` specification complete | Document audit of `docs/spec/modules/deploy.sh.md` | Verified complete specification; accepted by coordinator | ✅ **AUDITED & ACCEPTED** |
| **Req Gate** | `AC-05` | Shared glass styling specified for dark and light modes | Document audit of `SPEC.md` & `gmdl-dark.css.md` | Verified complete specification; accepted by coordinator | ✅ **AUDITED & ACCEPTED** |
| **Req Gate** | `AC-06` | Mobile accessibility specified with 5 viewports | Document audit of `SPEC.md` & `gmdl-ui.js.md` | Verified complete specification; accepted by coordinator | ✅ **AUDITED & ACCEPTED** |
| **Req Gate** | `AC-07` | Preference export/import defined with strict GMDL1 schema | Document audit of `SPEC.md` & `gmdl-ui.js.md` | Verified complete specification; accepted by coordinator | ✅ **AUDITED & ACCEPTED** |
| **Req Gate** | `AC-08` | IA PoC commissioned for current run on isolated branch | Document audit of `docs/spec/IA-POC-BRANCH-PLAN.md` | Verified complete specification; accepted by coordinator | ✅ **AUDITED & ACCEPTED** |
| **Req Gate** | `AC-09` | Documentation reflects canonical `docs/spec/` paths | Document audit across Stages 01–06, 08, TASKS, HANDOFF | All paths updated and verified; accepted by coordinator | ✅ **AUDITED & ACCEPTED** |
| **Req Gate** | `AC-10` | Specification package completed and reviewed | Phase transition gate | Completed and accepted following coordinator review 2026-10-13 | ✅ **AUDITED & ACCEPTED** |
| **IA Suite** | `IA-01..10` | 10 unit tests for IA query, filters, size, license, allow-listed playback/state, and error inputs | `node --test gmdl-ia.test.js` on `poc/ia...` | 10/10 tests pass on isolated branch; playback requires validator-issued candidates; native pause/end and stale resolve/reject after newer `playing` plus malformed/error inputs are verified | ✅ **EXECUTED / PASS (v2.1 offline; final independent review passed)** |
| **Loopback** | `LOOP-01` | Authentic upstream UI loopback verification procedure | Loopback test procedure (§6) | Binary verified against official API digest; executes loopback only | ✅ **EXECUTED / PASS** — local authentic upstream v1.1.1 loopback |
| **Visual Reg** | `VIS-01..04` | Real-page visual regression gate across 3 viewports | Real-page screenshot suite (§6.3) | Side-by-side screenshots verify zero regressions across 3 viewports | ✅ **EXECUTED / PASS** — 11 paired authentic captures |

---

## 3. Work Package A: Reversible Deployment Automation Mock Test Matrix

A standalone `scripts/deploy-mock.sh` harness validates the 12 specified conditions without root permissions, active OpenResty installations, or remote servers. This coordinator-accepted addendum strengthens ordering and dry-run/preflight boundaries before the final Task 5 behavioral run.

### 3.1 12-Case Mock Testing Matrix (`MOCK-01` through `MOCK-12`)

| Mock Case ID | Targeted Condition & Safety Boundary | Injected Mock Scenario | Verification Command / Assertion | Expected Result | Current Status |
|---|---|---|---|---|---|
| **MOCK-01** | Full Success Path in Exact 5-Step Order | Mock git repo, mock vhost config with single asset tokens, mock nginx binary returning 0 | Run `deploy.sh --config ... --nginx-main-conf ...` | Order strictly verified: Step 1 (pull + capture `PULLED_HEAD`) → all three Step 2 asset hashes → Step 3 atomic config update → Step 4 (`nginx -t`) → Step 5 (reload). Every hash event must precede the config rename. Exit code 0. | ✅ **EXECUTED / PASS (Task 5 final)** |
| **MOCK-02** | Single-Instance Lock Contention | Pre-acquired `flock` on the read-only Git metadata directory descriptor via background subshell | Launch second `deploy.sh` instance | Second instance halts immediately with concurrency lock error before dirty check or deployment actions. Active config and Git state untouched. Exit non-zero. | ✅ **EXECUTED / PASS (Task 5 final)** |
| **MOCK-03** | Git Metadata Lock, Re-acquisition & Index-Immutable Dry-Run | Read-only lock across success/failure/dry-run; touch tracked asset mtime before dry-run; snapshot `.git/index` bytes and stat metadata | Verify `GIT_OPTIONAL_LOCKS=0`, actual `FLOCK_PATH`, clean porcelain, lock reacquisition, no backup/config/reload/pull, and exact index bytes/metadata unchanged | Lock is metadata-scoped and released; dry-run creates no file/index side effect. | ✅ **EXECUTED / PASS (Task 5 v2.1)** |
| **MOCK-04** | Dirty Tree & Status-Command Failure Preflight | Dirty file plus clean tree with injected `git status --porcelain` failure (non-zero with empty stdout) | Compare lock/status events; run injected failure subcase and inspect diagnostic, backup, pull, hash, config, reload, reset events | Lock precedes status; dirty output and inability to establish status each fail closed. Failure case exits non-zero with a specific status diagnostic and zero deployment effects; config/worktree unchanged. | ✅ **EXECUTED / PASS (Task 5 v2.1)** |
| **MOCK-05** | Pull and Pulled-HEAD Capture Failure Safety | Subcase A: `git pull --ff-only` exits nonzero. Subcase B: pull succeeds, but its immediate `git rev-parse HEAD` capture fails. | Check explicit diagnostics, event order, hashes/config/reload/reset, active config bytes; allow preflight backup; verify captured-HEAD failure does not destructively reset | Both fail before hashing/config replacement and never reset. Subcase B emits a manual-recovery diagnostic because the pulled revision is unknown. | ✅ **EXECUTED / PASS (Task 5 v2.1)** |
| **MOCK-06** | Post-Pull Asset Hashing Failure Rollback | Step 1 pull succeeds; asset hashing utility fails or shipped asset missing in Step 2 | Run `deploy.sh` with missing `gmdl-dark.css` | Failure triggers safe rollback routine. Config restored via atomic restore staging (`.rollback.tmp.$$`) with `cmp -s` check; code safely reset to `$PRE_HEAD`. Exit non-zero. | ✅ **EXECUTED / PASS (Task 5 final)** |
| **MOCK-07** | Atomic Staging & Metadata Equality | Forward config update and rollback restore staging files created in target vhost dir | Inspect staging file paths and permissions | Temp staging files created in `${CONFIG_DIR}/` (same filesystem atomic `mv`), verifying ownership and mode preservation (`stat`). Rollback verifies byte-for-byte identity (`cmp -s "$RESTORE_TMP" "$BACKUP_PATH"`) before atomic rename. | ✅ **EXECUTED / PASS (Task 5 final)** |
| **MOCK-08** | Asset Token Cardinality Violation (All Shipped Assets) | Target vhost config contains zero, multiple, or unexpected token occurrences parameterized across all three shipped assets: `gmdl-dark.css?v=`, `gmdl-ui.js?v=`, and `gmdl-feat.js?v=` | Run `deploy.sh` parameterized for each asset: (a) zero tokens, (b) 2 tokens, (c) unexpected token count | Cardinality violation detected fail-closed for any asset with token count $\ne 1$; staging file discarded; active configuration remains untouched; safe rollback executed. Exit non-zero. | ✅ **EXECUTED / PASS (Task 5 final)** |
| **MOCK-09** | Assembled Configuration Syntax & Preflight Verification | Mock nginx verifies safe argv; malformed include, non-executable `--nginx-bin`/`--reload-cmd`, and missing `sha256sum` cases | Run valid prefix variants and invalid-path/command cases; assert `FLOCK_PATH` before status and no `REV_PARSE_HEAD` before missing-sha failure | Valid argv is exact; missing `sha256sum` fails after lock/status but before HEAD capture, pull/backup/config mutation; syntax failure triggers safe rollback. | ✅ **EXECUTED / PASS (Task 5 v2.1)** |
| **MOCK-10** | Simulated Reload Failure & Recovery Reload Assertions | Steps 1–4 succeed; first reload command (`$RELOAD_CMD`) exits non-zero | Mock reload script exits 1 on initial reload; mock recovery reload configured | First reload failure triggers atomic config restoration (staged, `cmp -s` verified, atomic rename). Script asserts recovery reload invocation via safe argv array `"$RELOAD_CMD" "${RELOAD_ARGS[@]}"`. If recovery reload also fails, emergency alert is reported. Code safely reset to `$PRE_HEAD`. Exit non-zero. | ✅ **EXECUTED / PASS (Task 5 final)** |
| **MOCK-11** | Conditional Safe Reset on Clean Head | Post-pull failure occurs while worktree is clean and HEAD equals `$PULLED_HEAD` | Post-pull failure injected | Reset predicate validates: (1) `git status --porcelain` is empty, AND (2) `HEAD == $PULLED_HEAD`. Safe reset to `$PRE_HEAD` is executed cleanly. | ✅ **EXECUTED / PASS (Task 5 final)** |
| **MOCK-12** | Refusal of Destructive Reset (Distinct Dirty & Drift Subcases) | Post-pull failure occurs under two distinct unverified worktree states: (a) worktree has uncommitted modifications, (b) HEAD revision has shifted away from `$PULLED_HEAD` | Run `deploy.sh` with: (Subcase 12a) uncommitted file created post-pull; (Subcase 12b) commit added post-pull so `HEAD != $PULLED_HEAD` | In Subcase 12a, safe rollback detects dirty tree and safely refuses `git reset`. In Subcase 12b, safe rollback detects HEAD drift and safely refuses `git reset`. Both subcases restore active config and log emergency alert without mutating worktree state. Exit non-zero. | ✅ **EXECUTED / PASS (Task 5 final)** |

---

## 4. Work Package B, C, D: Frontend Quality & Invariance Test Plan

All mainline frontend enhancements were tested using the dedicated Node.js test suite: `gmdl-ui-enhancements.test.js`, keeping the baseline `gmdl-ui.test.js` intact.

### 4.1 Strict Preference Export / Import Test Matrix (WP-D)

| Test ID | Test Scenario | Input Payload / Action | Expected Result & Verification Method | Current Status |
|---|---|---|---|---|
| **PREF-01** | Deterministic Export Serialization Order | Call `exportCode()` with active theme preferences | Returns `GMDL1:{"v":1,"settings":...}`. Envelope keys strictly `["v", "settings"]`. Settings keys strictly: `theme`, `accent`, `bg`, `style`, `text`, `lyric`, `glow`, `blur`, `glass`. | ✅ **EXECUTED / PASS (Task 4 final)** |
| **PREF-02** | Background Image Exclusion Notice | Call `exportCode()` when `localStorage['gmdl-bgimg']` is populated | `gmdl-bgimg` is NOT present in exported code string. DOM contains visible disclaimer notice: *"注：仅导出主题与外观偏好，自定义背景图保存在当前设备，不随代码导出。"*. | ✅ **EXECUTED / PASS (Task 4 final)** |
| **PREF-03** | Valid Code Import & Instant Application | Call `importCode()` with valid canonical string | Returns `true`; settings applied to `localStorage['gmdl-ui']`, document classes (`.dark`, `.glass`), CSS custom properties (`--primary-color`); `#gmdl-import-status` reports success. | ✅ **EXECUTED / PASS (Task 4 final)** |
| **PREF-04** | Duplicate Key Rejection — Settings Level | Import payload with duplicate key: `GMDL1:{"v":1,"settings":{"theme":"dark","theme":"light",...}}` | Rejection fail-closed before JSON decoding. Error text written to `#gmdl-import-status`. | ✅ **EXECUTED / PASS (Task 4 final)** |
| **PREF-05** | Duplicate Key Rejection — Envelope Level | Import payload with duplicate envelope key: `GMDL1:{"v":1,"v":2,"settings":{...}}` or repeated `settings` | Rejection fail-closed. Error text written to `#gmdl-import-status`. | ✅ **EXECUTED / PASS (Task 4 final)** |
| **PREF-06** | Decoded JSON Escape Duplicate Rejection at Both Levels | Subcases: settings keys `"theme"` and `"\u0074heme"`; envelope keys `"v"` and `"\u0076"` (also escaped `settings`) | Token-aware scanner compares decoded member names independently at envelope and `settings` levels; every duplicate rejects fail-closed. | ✅ **EXECUTED / PASS (Task 4 final)** |
| **PREF-07** | Missing Required Keys Rejection | Data-driven subcases remove each of the nine settings keys in turn, then omit envelope `v` and `settings` | Every missing-key subcase rejects fail-closed; error text is written to `#gmdl-import-status`. | ✅ **EXECUTED / PASS (Task 4 final)** |
| **PREF-08** | Unknown / Prototype Keys & Invalid Envelope Rejection | Extra, `__proto__`, `constructor`, or `prototype` keys at envelope or settings level; non-object/array `settings`; `v` values other than numeric `1` | Rejects fail-closed at both schema levels; no prototype mutation. | ✅ **EXECUTED / PASS (Task 4 final)** |
| **PREF-09** | Complete Data-Driven Schema / Type / Range Matrix | Per-key enum allow/deny cases; `glow` booleans vs wrong JSON types; `blur` and `glass` endpoints, just-outside values, fractions, and wrong JSON types (details in §4.1.1) | Every enumerated valid value is accepted; every invalid enum, non-boolean `glow`, missing/extra key, non-integer or out-of-range number rejects; status and state invariance are asserted. | ✅ **EXECUTED / PASS (Task 4 final)** |
| **PREF-10** | Malformed Prefix & Non-JSON Rejection | Import payload: `raw JSON`, `Base64:...`, or corrupted string | Prefix validation or syntax validation rejects fail-closed. | ✅ **EXECUTED / PASS (Task 4 final)** |
| **PREF-11** | Input Length Boundary | Valid canonical payload under 1024 characters (covered by `PREF-03`) and an ASCII payload of 1025 characters with parser invocation instrumented | The valid short payload is accepted; 1025-character input rejects at the size guard with zero `JSON.parse` calls. | ✅ **EXECUTED / PASS (Task 4 final)** |
| **PREF-12** | Side-Effect-Free Snapshot Invariance | Inject malformed/duplicate code string | Snapshot `localStorage` and all settings DOM controls before and after call. Excluding only `#gmdl-import-status`, all state matches 100% identically with zero mutation. `#gmdl-import-status` contains error message. | ✅ **EXECUTED / PASS (Task 4 final)** |
| **PREF-13** | Round-Trip Configuration Fidelity | `importCode(exportCode())` | State before export and state after import are 100% identical across all 9 settings. | ✅ **EXECUTED / PASS (Task 4 final)** |

#### 4.1.1 Schema Boundary Case Enumeration

`PREF-09` is data-driven and tests every allowed value for each enum field, plus at least one disallowed value per field: `theme` (`dark`, `light`, `auto`); `accent` (`green`, `blue`, `purple`, `orange`, `pink`, `cyan`); `bg` (`obsidian`, `midnight`, `grape`, `amoled`); `style` (`solid`, `glass`); `text` (`bright`, `soft`, `warm`); and `lyric` (`s`, `m`, `big`). `glow` accepts only JSON `true` or `false`; reject strings, numbers, `null`, arrays, and objects. For `blur`, accept integer endpoints `0` and `24` and reject `-1`, `25`, fractional values, and non-number types. For `glass`, accept integer endpoints `0` and `100` and reject `-1`, `101`, fractional values, and non-number types. Include the valid envelope (`v === 1`, exactly `v` and `settings`) and exact nine-key requirement in the same matrix; apply `PREF-12` invariance assertions to every rejected payload.

`SEC-EVAL-01` (traceable to `AC-D06`) is a static security check of production JavaScript that rejects executable uses of `eval(`, `new Function(` / `Function(`, and unsafe dynamic string execution or deserialization. It was executed in the 29/29 Task 4 enhancement suite; the production UI contains no prohibited dynamic evaluation.

### 4.2 Shared Glass Styling Test Matrix (WP-B)

| Test ID | Criterion ID | Test Scenario | Action | Expected Result | Current Status |
|---|---|---|---|---|---|
| **GLASS-01** | `AC-B01`, `AC-CSS-01` | Dual-Mode Glass Activation | Toggle style to `"glass"` in dark mode and light mode | `.glass` class present on `<html>`. In dark mode: `html.dark.glass` surface styling active. In light mode: `html.glass:not(.dark)` translucent styling active. | ✅ **EXECUTED / PASS (Task 4 final)** |
| **GLASS-02** | `AC-B02`, `AC-CSS-02` | Dark Mode Visual Preservation | Inspect computed style tokens in `html.dark.glass` | High-contrast text tokens (`var(--text-main)`, `var(--text-sub)`) and dark gradients match baseline aesthetic. | ✅ **EXECUTED / PASS (Task 4 final)** |
| **GLASS-03** | `AC-B03` | Slider Real-Time Responsiveness | Modify blur slider (0–24px) and opacity slider (0–100%) | Inline styles `--glass-b` and `--glass-a` update dynamically on root `:root` in both modes. | ✅ **EXECUTED / PASS (Task 4 final)** |
| **GLASS-04** | `AC-B04` | Accent Color Swatches in Both Modes | Select each of 6 accent swatches in dark glass and light glass | Swatch click updates `--primary-color`, active border styles, hover rules, and focus indicators in both modes. | ✅ **EXECUTED / PASS (Task 4 final)** |
| **GLASS-CONTRAST** | `AC-CSS-01`, Risk R-05 | Reproducible Light-Mode Glass Contrast Verification | Test both gradient stops over fixed light-mode background fixtures at `S.glass` 0, 55, and 100 | Derive runtime `--glass-a` from the mapping in §4.2.1, composite both CSS gradient-stop colors over each canvas, and compute WCAG 2.1 contrast for both text colors; fail if any evaluated stop is below 4.5:1. | ✅ **EXECUTED / PASS (Task 4 final)** |

#### 4.2.1 Reproducible Light-Mode Background Fixtures Specification
*Note on Spec Gap & Concrete Fixtures:* Upstream `gmdl-dark.css.md` defines light glass card surface opacities but does not enumerate base light-theme page canvas colors. To eliminate ambiguity, Stage 7 defines the following three concrete reference background canvas fixtures for contrast evaluation (without claiming these are product runtime modifications):
1. **Fixture L-BG-1 (Pure Clean White):** Canvas `#ffffff` (Standard browser light default).
2. **Fixture L-BG-2 (Pale Cool Slate):** Canvas `#f8fafc` (Slate-50 light card canvas).
3. **Fixture L-BG-3 (Subtle Gray Tint):** Canvas `#f1f5f9` (Slate-100 neutral background).

The runtime mapping in `gmdl-ui.js` is `--glass-a = (0.015 + (S.glass / 100) * 0.145).toFixed(3)`. Therefore, the reference slider settings produce the following CSS variable and light-mode gradient-stop alphas, using the accepted module formulas `stop-1 = 0.30 + 0.65 * --glass-a` and `stop-2 = 0.20 + 0.40 * --glass-a`:

| `S.glass` | Runtime `--glass-a` | Stop 1 alpha | Stop 2 alpha |
|---:|---:|---:|---:|
| 0 (minimum) | 0.015 | 0.309750 | 0.206000 |
| 55 (default) | 0.095 | 0.361750 | 0.238000 |
| 100 (maximum) | 0.160 | 0.404000 | 0.264000 |

For each slider setting, composite each white gradient stop separately over each listed canvas using the CSS alpha-compositing model, then calculate WCAG 2.1 contrast for primary text `#1f2937` (relative luminance approximately 0.021530) and secondary text `#4b5563` (approximately 0.088937). Test all `3 canvases × 3 slider settings × 2 stops × 2 text colors`; each ratio must be at least 4.5:1. These are reproducible test inputs and calculations, not an assertion that the contrasts have been executed or that the canvases describe upstream runtime colors.

### 4.3 Mobile Ergonomics & Keyboard Interaction Test Matrix (WP-C)

| Test ID | Criterion ID | Test Scenario | Action | Expected Result | Current Status |
|---|---|---|---|---|---|
| **ACC-01** | `AC-C01`, `AC-UI-06` | Non-Modal Panel Open / Close | Click launcher `#gmdl-ui-btn` | Panel displays with `role="region"`; `#gmdl-ui-btn` toggles `aria-expanded="true"` and `"false"`. | ✅ **EXECUTED / PASS (Task 4 final)** |
| **ACC-02** | `AC-C02`, `AC-UI-05` | Escape Key Dismissal & Focus Return | Press `Escape` while panel is open | Panel closes; focus restores immediately to trigger button `#gmdl-ui-btn`. | ✅ **EXECUTED / PASS (Task 4 final)** |
| **ACC-03** | `AC-C04`, `AC-CSS-04` | Touch Target Ergonomics | Measure bounding boxes / hit areas for every visible interactive control, including launcher, buttons, swatches, sliders, upload/clear, and export/import controls when implemented | All visible interactive controls measure $\ge 44 \times 44\text{px}$ interactive area (swatches use `::after` expander); hidden `<input type="file">` is excluded because its visible upload button is the target. | ✅ **EXECUTED / PASS (Task 4 final)** |
| **ACC-04** | `AC-C05` | Keyboard Tab Traversal Without Trapping | Tab through every visible, focusable open-panel control, including future export/import controls | Focus moves sequentially through panel controls and returns to underlying page without modal focus trapping. | ✅ **EXECUTED / PASS (Task 4 final)** |
| **ACC-05** | `AC-CSS-05` | Visible Focus Outlines (`:focus-visible`) | Inspect keyboard focus outline on the trigger and every visible focusable panel control, including upload/clear/export/import controls when implemented | Distinct 2px solid `var(--primary-color)` outline with 2px offset appears on each visible interactive control; hidden `<input type="file">` is excluded. | ✅ **EXECUTED / PASS (Task 4 final)** |

---

## 5. Measured Viewport Test Matrix (WP-C)

The final responsive audit verified layout ergonomics across five reference viewports without physical hardware.

| Viewport Test ID | Dimensions | Device Archetype | Evaluated Layout Criteria | Acceptance Threshold | Current Status |
|---|---|---|---|---|---|
| **VIEW-01** | **320 × 568** | iPhone SE / Compact | Panel width, horizontal scrolling, button grid wrap | `document.documentElement.scrollWidth <= clientWidth`; no horizontal scrollbar; buttons wrap cleanly. | ✅ **EXECUTED / PASS (Task 4 final)** |
| **VIEW-02** | **375 × 812** | iPhone X / 11 / Mini | Touch targets, swatch alignments, header spacing | `scrollWidth <= clientWidth`; touch targets ≥ 44px; swatches fit screen width. | ✅ **EXECUTED / PASS (Task 4 final)** |
| **VIEW-03** | **390 × 844** | iPhone 12 / 13 / 14 | Slider track usability, text legibility | `scrollWidth <= clientWidth`; slider thumbs draggable without page panning. | ✅ **EXECUTED / PASS (Task 4 final)** |
| **VIEW-04** | **768 × 1024** | iPad / Tablet Portrait | Panel dock alignment, translucent surface layout | `scrollWidth <= clientWidth`; panel docks at bottom-right cleanly. | ✅ **EXECUTED / PASS (Task 4 final)** |
| **VIEW-05** | **1280 × 800** | Desktop / Laptop | Full desktop interface, keyboard dismissal | `scrollWidth <= clientWidth`; panel opens as floating non-modal region. | ✅ **EXECUTED / PASS (Task 4 final)** |

*Execution Policy:* Tests are executed in headless browser / simulated viewport DOM fixtures. Physical mobile hardware verification remains **currently BLOCKED/UNVERIFIED** (planned; not run in this phase).

---

## 6. Authentic Upstream UI Loopback Testing & Real-Page Visual Regression Gate

To verify that reverse proxy theme injection operates cleanly against the authentic upstream Go application without modifying upstream source code, the following strict procedure is defined:

### 6.1 Upstream Release Verification & Provenance Rules
1. **Official Release Source:** Official upstream releases originate from [https://github.com/guohuiyuan/go-music-dl/releases](https://github.com/guohuiyuan/go-music-dl/releases).
2. **Mandatory Digest Verification:**
   - The official GitHub v1.1.1 API digest for `go-music-dl_linux_amd64.tar.gz` is:
     `sha256:be7b828096a23b7401d69649484ece667ed588116a6039bb8f55e0f4df7c5949`
   - The legacy digest found in prior task context (`1a4fc4d0fa67c0e0d73fb6cebd8918c1e6998f2f23c7ee19ebacbb27f5f07d0a`; provenance unverified) does **NOT** match and must **NEVER** be used to validate or run assets.
   - Before downloading or extracting any upstream binary, download-time local `sha256sum` verification against the official GitHub digest (`be7b...`) is strictly required. If the digest mismatches, abort immediately.
3. **Execution Status at Stage 7 Acceptance:** No binary had been downloaded or executed when this plan was accepted. The local loopback was pre-authorized under §6.2.8 and was subsequently completed in Task 4; final evidence is recorded below and in `docs/research/UPSTREAM-VISUAL-TEST-PROVENANCE.md`.

### 6.2 Isolated Loopback Execution Procedure
When performed in the Task 7 verification phase (pre-authorized locally by §6.2.8):
1. **Port Selection & Conflict Check:** Upstream documentation confirms `./music-dl web` and default path `/music`, but does not prove the default port. Select explicit, free upstream and proxy ports (using `ss -tlpn` or an ephemeral bind check); record both values. Do not assume port 8080.
2. **Temporary Test Root & Proxy:** Create a temporary test root outside the repository. Build a test-only main configuration and vhost from the accepted OpenResty reference contract, setting static asset roots to the temporary test root, disabling caching for HTML/assets, and binding the proxy server strictly to `127.0.0.1:<proxy-port>`. Preserve the reference injection template and route to the explicitly configured upstream port. Run the verified `nginx -t`/OpenResty syntax check with the temporary prefix and config before startup. If a suitable proxy binary or required `sub_filter` support is unavailable, stop and classify the loopback/visual gate as **currently BLOCKED/UNVERIFIED**; do not substitute fixtures.
3. **Baseline Asset Set:** Before Task 4 UI changes, materialize the three frontend asset files (`gmdl-dark.css`, `gmdl-ui.js`, `gmdl-feat.js`) from baseline commit `126853a` into the temporary static root. Do not modify the repository or upstream Go source. Record the baseline asset hashes.
4. **Loopback Binding:** Launch only the archive-digest-verified authentic upstream binary with documented CLI options that bind it strictly to `127.0.0.1:<upstream-port>` (never `0.0.0.0`). Keep the same binary process and test proxy configuration for before/after captures; verify the supported port option before launch rather than guessing a flag.
5. **HTTP Injection Verification:** Request the upstream `/music` page directly and through `http://127.0.0.1:<proxy-port>/music`. Verify the proxied HTML includes the expected CSS/JS injection before `</head>`, all three injected assets return successfully from the temporary root, and responses are not served from cache.
6. **Before/After Asset Swap:** Capture the baseline screenshots using assets from `126853a`; after Task 4, replace only the temporary static-root assets with the enhanced working-tree assets, disable/clear browser cache, and capture the same URL, browser profile/runtime, viewport, local-storage setup, query and page state. Record enhanced asset hashes and repository revision. Do not replace the upstream binary or synthetic-render the page between captures.
7. **Process Teardown & Trap:** Ensure the test proxy and upstream process are terminated immediately upon test completion via EXIT traps; remove the temporary tree after evidence has been copied to the approved ignored artifact directory.
8. **Execution Authority Boundary:** Once Stage 7 is formally reviewed and accepted by the coordinator, the coordinator holds pre-authorized permission to execute this verified local loopback procedure and visual capture without requesting another owner sign-off. This local test authorization does **NOT** authorize production deployment.
9. **Classification:** The authentic upstream loopback, proxy injection, 11-condition baseline capture, matching enhanced captures, and paired review were completed in Task 4 on 2026-10-13. The local visual-regression gate passes; physical-device and production-vhost validation remain blocked/unverified.

### 6.3 Mandatory Real-Page Visual Regression Gate (`VIS-01` through `VIS-04`)

To guarantee aesthetic and layout integrity without relying solely on headless DOM assertions or isolated mock fixtures, the project establishes a **mandatory real-page visual regression gate**:
1. **Authentic Environment Consistency:** Screenshots must be captured directly from the authentic upstream `go-music-dl` web page served via the local reverse proxy from the same verified official release binary before and after mainline UI modifications.
2. **Identical Capture Conditions:** Before-change (baseline) and after-change (enhanced) captures must share:
   - Same browser runtime and rendering engine.
   - Same local URL (`http://127.0.0.1:<port>/music`).
   - Same fixture data and search query state.
   - Identical viewport dimensions.
3. **Three Mandatory Viewport Dimensions:**
   - **Compact Mobile:** `320 × 568` (iPhone SE).
   - **Standard Mobile:** `390 × 844` (iPhone 12/13/14).
   - **Desktop:** `1280 × 800` (Laptop / Desktop).
4. **Mandatory Capture Matrix (before/after screenshot pair for every row):**

   | Visual ID / State | Required viewport pairs |
   |---|---|
   | `VIS-01` Dark Glass (`theme="dark"`, `style="glass"`) | `320×568`, `390×844`, `1280×800` |
   | `VIS-02` Light Glass (`theme="light"`, `style="glass"`) | `320×568`, `390×844`, `1280×800` |
   | `VIS-03` Open Personalization Region (`#gmdl-ui-panel` open; non-modal and no clipping) | `320×568`, `390×844` |
   | `VIS-04` Export / Import controls, status feedback and layout | `320×568`, `390×844`, `1280×800`; baseline pair records the unenhanced panel and after pair records the planned controls |

   This yields 11 paired conditions (22 PNG captures). Use deterministic names such as `before_VIS-01_dark-glass_320x568.png` and `after_VIS-01_dark-glass_320x568.png`; record the matching baseline/enhanced asset hashes, source revision, binary release/digest, browser version, proxy/upstream ports, theme/storage setup, query, and viewport in a manifest. `VIS-04` is an intentional feature delta: compare unaffected page/panel layout and verify the new controls are visible, usable, and not clipped; do not mislabel expected new controls as pixel-identical.
5. **Storage, Review & Reporting Invariant:**
   - Visual artifacts must be stored in a dedicated non-committed artifact directory (e.g. `.system_generated/visual/` or task scratch directory; verified ignored by Git; never committed to repo).
   - Headless DOM fixtures or synthetic HTML snippets must **never** be silently substituted for authentic upstream captures.
   - Side-by-side visual comparisons, artifact manifest, and Markdown image links must be compiled into the final release-readiness QA report.
   - If local reverse proxy or upstream binary execution cannot run safely, the real-page visual regression gate must be honestly classified as **currently BLOCKED/UNVERIFIED**. Synthetic fixture snapshots must never claim to satisfy this gate.

---

## 7. Commissioned IA PoC Branch Quality Plan (`poc/ia-audio-discovery`)

In accordance with [`docs/spec/IA-POC-BRANCH-PLAN.md`](../spec/IA-POC-BRANCH-PLAN.md), Internet Archive audio discovery is tested on its own isolated branch.

### 7.1 Isolation Guardrails
- **Branch & Worktree:** Branched freshly from `126853a` to `poc/ia-audio-discovery`. Never access `/workspace/gmdl-theme-pack-poc`.
- **Mainline Purity:** Zero IA implementation code or executable IA tests in `project/antigravity-overhaul` or target `main`; governance documents may reference the isolated PoC plan. IA implementation must never be merged into mainline or `main`.
- **Deterministic Offline Fixtures:** Unit tests inject local `fetch` stubs returning deterministic JSON response objects for `archive.org/advancedsearch.php` and `archive.org/metadata/`. Zero live network calls during testing.

### 7.2 10 Unit Tests Specification (`gmdl-ia.test.js`)

| Test ID | Function / Logic Tested | Fixture / Input | Expected Assertion | Current Status |
|---|---|---|---|---|
| `IA-01` | Query Builder & Search Fetch | Standard keyword query; injected `fetch` stubs for success, HTTP failure, invalid response shape, and rejected `response.json()` | Builds audio-scoped Advanced Search URL and sends anonymous CORS GET; success parses; non-OK, malformed envelope, and JSON parse rejection propagate safely | ✅ PASS (offline; v1.9) |
| `IA-02` | Search Param Safety | Special chars, quotes, boolean-looking title | Keeps user title inside one escaped title phrase and URL-encodes it without adding query parameters | ✅ Passed (offline; suite 10/10) |
| `IA-03` | Format Filter (Positive) | Metadata files with `audio/mpeg`, `VBR MP3`, `128Kbps MP3` | Accepted by format filter as streamable | ✅ Passed (offline; suite 10/10) |
| `IA-04` | Format Filter (Negative) | Metadata with MIDI, FLAC, WAV stems, unrelated formats | Rejected by format filter | ✅ Passed (offline; suite 10/10) |
| `IA-05` | File Size Gate | 45 MiB, exactly 50 MiB, 55 MiB, numeric-string metadata sizes | Accepts positive sizes ≤50 MiB; rejects larger, malformed, fractional, or negative sizes | ✅ Passed (offline; suite 10/10) |
| `IA-06` | License & Playable-File Allow-List (Positive) | CC0 and Public Domain Mark 1.0; MP3 metadata files, invalid path-segment filename, malformed metadata shapes | Allowed license plus MP3/size/path filters yields only valid, immutable playable candidates; malformed payloads and unsafe metadata fail closed | ✅ PASS (offline; v1.9) |
| `IA-07` | License Allow-List (Negative) | All Rights Reserved, missing, unknown, spoofed license | Fails closed; item rejected | ✅ Passed (offline; suite 10/10) |
| `IA-08` | Metadata Read & Audio URL Constructor | Identifier and filename with leading/trailing/interior spaces and punctuation, dot segments, separators; injected fetch stubs including rejected `response.json()` | Encodes original safe single path segments without trimming meaningful filename spaces; rejects traversal; handles HTTP and JSON parse failures | ✅ PASS (offline; v1.9) |
| `IA-09` | Allow-Listed Player State & Native Media Events | Only exact candidate object returned by `listPlayableFiles`; separate stale resolve/reject promises; native `pause`/`ended` | Arbitrary URL/forged candidate is refused; both old resolve and old reject **after** newer track reaches `playing` leave newer state unchanged | ✅ PASS (offline; v2.1) |
| `IA-10` | Player Error & Malformed Input Handling | Direct/credentialed URL, forged object, missing audio implementation, media error event, synchronous throw and rejected play promise | Invalid inputs fail before playback; synchronous/asynchronous play errors move to `error` with user-safe notice; errors do not leak stale state | ✅ PASS (offline; v1.9) |

---

## 8. Smoke Automation Design Contract (`scripts/smoke.sh`)

> [!IMPORTANT]
> **Authoring Invariant:**
> File `scripts/smoke.sh` was not created during Sub-tasks 3A/3B.
> This section defines the design contract and behavioral requirements for `scripts/smoke.sh`, authorized for Sub-task 3C by the coordinator's acceptance recorded below.

### 8.1 Phased Execution Architecture (Runnable at Task 3)

Because `scripts/smoke.sh` is authored at Task 3C prior to the creation of Task 4/5 test suites, it must implement **phase-aware execution**:
- **Phase 1 Checks (Mandatory at Task 3 Creation):**
  1. Offline all-file whitespace audit scanning all tracked and untracked UTF-8 text files (`.md`, `.js`, `.sh`, `.json`, `.css`, `.conf`, `.log`, and extensionless text files such as `LICENSE`) via Python script to detect trailing whitespace or CRLF, plus `git diff --check`.
  2. Relative markdown link integrity validation across all repository documentation.
  3. JavaScript syntax validation: `node --check gmdl-ui.js` and `node --check gmdl-feat.js`.
  4. Baseline unit test suite: `node --test gmdl-ui.test.js` (must pass 8/0/0).
  5. Baseline feature file identity: `git diff --exit-code 126853a -- gmdl-feat.js` (must exit 0 with 0 diff lines).
- **Phase 2 Checks (Conditioned on Subsequent Deliverables):**
  - If `gmdl-ui-enhancements.test.js` exists: execute `node --test gmdl-ui-enhancements.test.js`. If absent during Task 3, output `[INFO] UI enhancement suite: NOT YET IMPLEMENTED (deferred to Task 4)`.
  - If `deploy.sh` exists: execute `bash -n deploy.sh`; require `scripts/deploy-mock.sh` to exist and execute `bash scripts/deploy-mock.sh` (a missing harness is a failure once deployment implementation exists). If `deploy.sh` is absent during Task 3, output `[INFO] deploy.sh & mock harness: NOT YET IMPLEMENTED (deferred to Task 5)`.
  - The absence of uncreated future suites must **never** be treated as a test pass and must **never** cause premature script failure during Task 3 verification.

### 8.2 Execution Constraints
- Strictly deterministic; 100% offline.
- Zero live calls to external endpoints (`archive.org`, `music.archfox.eu.cc`).
- Zero calls to live production servers or SSH commands.
- Exit code 0 if and only if all active phase checks pass. Non-zero exit code on any active failure.

### 8.3 Coordinator Review Result (Sub-task 3B)
- **Decision:** Stage 7 Quality & Test Plan **ACCEPTED** on 2026-10-13 04:20 UTC+08. This is an internal quality/governance gate, not a production-deployment authorization.
- **Traceability:** Coordinator's automated identifier-set audit found all 68/68 acceptance-criterion IDs from the canonical product specification, module contracts, requirements, and IA branch plan represented in the RTM; no missing or extra IDs.
- **Protocol review:** Confirmed exact deployment lock/rollback/token cardinality cases (12 deterministic mocks); all 13 preference test IDs and explicit schema boundaries; runtime glass-alpha mapping and both gradient-stop formulas; three-viewport real-upstream before/after matrix (11 paired conditions / 22 PNG captures); mobile/focus coverage; IA branch isolation; and honest blocked/unverified boundaries.
- **Verification:** Baseline suite 8/0/0, both production JS syntax checks, feature-file identity, Markdown links, whitespace/line endings, and `git diff --check` pass. New implementation/test artifacts remain absent at the review gate.
- **Sub-task 3C result:** `bash -n scripts/smoke.sh` passed. `bash scripts/smoke.sh` reported 7 passed checks, 0 failures, and truthful Task 4/5 `[INFO]` deferrals. A temporary wiring probe verified that a present `deploy.sh` without `scripts/deploy-mock.sh` fails closed, and that the future-suite branches execute when present (10 passed, 0 failed with no-op test stubs). All temporary stubs were removed. This probe does **not** claim the future feature suite or any of the 12 deployment cases have been implemented or passed.
- **Additional coordinator-executed evidence:** A separate smoke run at 2026-10-13 04:26:14 UTC+08 was reported by the coordinator: 7 checks passed / 0 failed; baseline tests 8/0/0; 31 UTF-8 text files scanned; 55 relative Markdown links across 23 files with 0 broken; `gmdl-feat.js` unchanged from `126853a`; UI enhancement suite and deployment script/mock harness accurately reported `NOT YET IMPLEMENTED` and not as passes. Provenance is coordinator-executed/reported; **no agent execution is claimed**.
- **Gate transition:** Stage 7 was accepted at 04:20; the smoke script passed at 04:23. Task 4 implementation may now begin, while Task 5 deployment and Task 6 IA work remain subject to their own branch/task sequencing and acceptance gates.

---

## 9. Current Verification Baseline & Evidence Log

### 9.1 Executed Checks & Truthful Baseline Evidence

| Check / Verification Item | Command Executed | Result & Status | Timestamp (+08) |
|---|---|---|---|
| Existing Baseline Tests | `node --test gmdl-ui.test.js` | 8 pass / 0 fail / 0 skipped (~110ms) ✅ | 2026-10-13 04:19 |
| Core UI Syntax | `node --check gmdl-ui.js` | Exit code 0 ✅ | 2026-10-13 04:19 |
| Feature UI Syntax | `node --check gmdl-feat.js` | Exit code 0 ✅ | 2026-10-13 04:19 |
| Feature File Exact Baseline Blob Identity | `git diff --exit-code 126853a -- gmdl-feat.js` | Exit code 0 (0 diff lines; byte-identical to `126853a`) ✅ | 2026-10-13 04:19 |
| Text Whitespace & Line Endings | UTF-8 text scan (30 files) + `git diff --check` | 0 trailing-whitespace errors; 0 CRLF files; diff check exit 0 ✅ | 2026-10-13 04:19 |
| Markdown Link Integrity | Python link validator (23 docs) | 57 relative links checked; 0 broken ✅ | 2026-10-13 04:19 |
| RTM Criterion Coverage | Automated identifier-set comparison | 68/68 source acceptance-criterion IDs; missing 0; extra 0 ✅ | 2026-10-13 04:19 |
| Test Matrix Inventory | Automated ID inventory | PREF-01..13, MOCK-01..12, VIS-01..04 present ✅ | 2026-10-13 04:19 |
| Git Tree Working State | `git status` | Clean tracked state; only governance/control docs untracked ✅ | 2026-10-13 04:19 |
| Stage 7 Review Gate | Coordinator review and acceptance | Accepted; authorizes Sub-task 3C only ✅ | 2026-10-13 04:20 |
| Deferred Artifacts at Review | File/branch absence check | `scripts/smoke.sh`, feature tests, deploy/mock scripts, IA files, and IA branch absent before 3C ✅ | 2026-10-13 04:19 |
| Smoke Script Syntax | `bash -n scripts/smoke.sh` | Exit code 0 ✅ | 2026-10-13 04:23 |
| Smoke Script — Current Phase | `bash scripts/smoke.sh` | 7 checks passed / 0 failed; future suites explicitly reported NOT YET IMPLEMENTED ✅ | 2026-10-13 04:23 |
| Additional Coordinator Smoke Run | `bash scripts/smoke.sh` | 7/0 checks; baseline 8/0/0; 31 UTF-8 text files; 55 links / 23 Markdown files, 0 broken; feature file unchanged; future suites reported NOT YET IMPLEMENTED. Coordinator-executed/reported; no agent attribution. ✅ | 2026-10-13 04:26:14 |
| Smoke Phase-Condition Wiring | Temporary stubs; missing-harness negative case plus all-present conditional case | Missing harness correctly failed; all present branches ran (10 checks passed); stubs removed; no real deploy/test behavior claimed ✅ | 2026-10-13 04:24 |
| Task 4 Final TDD/Smoke Regression | `node --test gmdl-ui-enhancements.test.js`; `node --test gmdl-ui.test.js`; `bash scripts/smoke.sh`; `node --check` on both assets; `git diff --check` | Enhancement 29/29, baseline 8/8, smoke 10 checks passed / 0 failed; syntax/whitespace checks pass; `gmdl-feat.js` remains byte-identical. The final 2px swatch-border change was made after the initial Task 4 acceptance and revalidated in this run. | 2026-10-13 05:26 |
| Authentic Upstream Before/After Capture | Digest-verified v1.1.1 loopback + Chromium 151; before/after manifests | 11/11 before and 11/11 final after screenshots across VIS-01..04; all 22 PNG SHA-256 values revalidated; 11 paired keys/dimensions match; all capture states have zero horizontal overflow; `gmdl-feat.js` unchanged. Final after capture followed the swatch hitbox remediation. | 2026-10-13 05:26 |
| Real-Page Geometry, Pointer & Touch Gate | Chromium measurements at 320×568, 375×812, 390×844, 768×1024, 1280×800 | At all five sizes panel/launcher rectangles do not intersect; document/body scroll widths equal viewport width; pointer closes panel; all 30 visible controls per viewport are ≥44×44px and all 10 swatches pass four edge hit-tests. Detailed measurements: `/workspace/gmdl-theme-pack-visual-evidence/browser-audit.json`. PASS. | 2026-10-13 05:27 |
| Real-Page Keyboard Gate | Final Chromium Enter/Tab/Escape interaction | Enter opens and sets `aria-expanded=true`; Tab reaches `深色` then `浅色` with visible 2px outline; Escape closes and returns focus to `#gmdl-ui-btn`. PASS. | 2026-10-13 05:28 |
| Coordinator Visual Review | Manual inspection of all 11 latest before/after screenshot pairs | Dark-glass pair is pixel-identical at 390/1280; the 320 pair has only 50 RGB pixels of tiny raster/antialiasing variation (mean absolute channel difference 0.00044), with no visible layout/style regression; light-glass and panel/export changes are intended; controls are reachable by scrolling; import error is visible in all 3 VIS-04 after captures. Local visual gate PASS; no live-site/physical-device claim. | 2026-10-13 05:29 |
| IA PoC TDD & Offline Adapter | `node --check gmdl-ia.js`; `node --check gmdl-ia.test.js`; `node --test gmdl-ia.test.js`; browser-global VM with stub `fetch` | Final suite demonstrated red 0/10 with module absent, then green 10/10 after implementation. Search and metadata API paths exercised only with injected local stubs; browser mode exposes `GmdlIA`; no live Archive.org requests. Isolated worktree `poc/ia-audio-discovery` remains at `126853a`; coordinator audit/publication pending. | 2026-10-13 05:09 |
| Task 5 TDD Expected-Red | Temporarily absent `deploy.sh`; `bash scripts/deploy-mock.sh` | 12/12 reported failures solely because the implementation file was absent; this was not counted as behavioral execution. File was immediately restored. | 2026-10-13 05:51 |
| Task 5 Final Deployment Behavior | `bash -n deploy.sh`; `bash -n scripts/deploy-mock.sh`; `bash scripts/deploy-mock.sh` | 12/12 PASS after two review rounds: read-only directory lock, artifact-free dry-run, strict include, invalid Nginx/reload executable and missing-`sha256sum` preflight (MOCK-09i), exact hash/update order, token cardinality, rollback and reset guards. No production or external network calls. | 2026-10-13 06:01 |
| Task 5 Post-Remediation Smoke | `bash scripts/smoke.sh` | 10/0 after `sha256sum` preflight and MOCK-09i; baseline/enhancement/deployment gates passed. | 2026-10-13 06:05:55 |
| IA Audit-Driven TDD & Final Offline Suite | `node --test gmdl-ia.test.js`; `node --check` both IA files | Red phases reproduced arbitrary-URL playback (2 failing tests) and whitespace trimming (1 failing test). After remediation the v1.9 suite passes 10/10; tests use local fetch stubs only. | 2026-10-13 06:06:19 |
| Stage 7 v2.0 Addendum Acceptance | Coordinator plan review | Fail-closed status-command, lock-evidence, and stale rejected-promise assertions approved before implementation. | 2026-10-13 06:14 |
| Task 5 v2.0 Red/Green Regression | `bash scripts/deploy-mock.sh` | Red: 10 pass / 2 fail (only new MOCK-04 status-command and MOCK-09i lock evidence); after fail-closed and lock-path fixes: 12/12 pass. | 2026-10-13 06:16:19 |
| IA-09 Stale Rejection Regression | `node --check` both IA files; `node --test gmdl-ia.test.js` | The former track's rejected `play()` promise after a newer track reaches `playing` is ignored; suite 10/10, 0 fail. | 2026-10-13 06:15:53 |
| Final Stage 7 v2.0 Smoke | `bash scripts/smoke.sh` | 10 passed / 0 failed; baseline 8/8, enhancement 29/29, deployment mocks 12/12; all active mainline checks pass. | 2026-10-13 06:18:15 |
| IA v2.0 Final Offline Suite | `node --check` both IA files; `node --test gmdl-ia.test.js`; untracked-file whitespace check | Syntax passes; 10/10 tests; stale success/rejection guarded; both untracked source/test files pass explicit whitespace check. | 2026-10-13 06:18:16 |
| Stage 7 v2.1 Addendum Acceptance | Coordinator plan review | Git-index-invariant dry-run, pull-success/HEAD-capture-failure recovery boundary, missing-sha no-state-capture, and stale resolve/reject-after-playing assertions accepted before test/code edits. | 2026-10-13 06:23 |
| Task 5 v2.1 Red/Green Regression | `bash scripts/deploy-mock.sh` | Red: 10 pass / 2 fail (MOCK-03 optional-lock/index invariant; MOCK-05 pulled-HEAD failure diagnostic); green: 12/12 after fixes. | 2026-10-13 06:25:40 |
| IA-09 v2.1 Timing Regression | `node --check` both IA files; `node --test gmdl-ia.test.js` | Old play Promise resolve and reject each settle only after a replacement track reaches `playing`; both are ignored; suite 10/10. | 2026-10-13 06:25:13 |
| Final Stage 7 v2.1 Smoke | `bash scripts/smoke.sh` | 10 passed / 0 failed; baseline 8/8, enhancement 29/29, deployment mocks 12/12; all active mainline checks pass after final whitespace cleanup. | 2026-10-13 06:28:36 |
| Deployment v2.1 Independent Final Review | Read-only audit; `bash -n`, harness, full smoke, `git diff --check` | No medium/high issue; index-invariant dry-run, status/capture fail-closed, metadata locking, atomic restore and reset guards verified. One low harness hygiene item (test-only `git status` helpers) was fixed afterward; final gates will rerun. | 2026-10-13 06:30:57 |
| IA v2.1 Independent Final Review | Read-only audit; `node --check`, `node --test`, whitespace, branch/base check | No code/test issue; stale resolve and reject each occur after newer `playing` and are ignored; branch remains isolated on baseline `126853a`. | 2026-10-13 06:30:04 |
| Final Post-Review-Hygiene Smoke | `bash scripts/smoke.sh` | 10/0 after disabling optional Git index locks in all temporary-repo status helpers, correcting the v2.1 MOCK-04 record, and syncing final review/schedule status; baseline 8/8, enhancement 29/29, deployment 12/12. | 2026-10-13 06:38:05 |

### 9.2 Blocked / Unverified Status Summary

| Item | Classification | Reason / Status | Workaround / Fallback |
|---|---|---|---|
| Local Upstream UI Loopback | **PASS — before/after complete** | Official API digest-verified v1.1.1 binary and localhost-only proxy; 11 before and 11 after screenshots, 22 file hashes verified. | Keep evidence manifests under `/workspace/gmdl-theme-pack-visual-evidence/`; host validation remains separate. |
| Real-Page Visual Regression Gate (`VIS-01..04`) | **PASS — local authentic page** | Paired review passed; all capture states have zero horizontal overflow; five viewport pointer checks and real Chromium keyboard checks passed. | Does not substitute for live production or physical hardware checks. |
| Production/reference `nginx -t` | **currently BLOCKED/UNVERIFIED** | Local nginx-extras is installed and the isolated visual proxy config passed syntax validation; production host/include context remains unavailable. | The 12-case offline harness passed, but mock argv checks do not substitute for the real host config. |
| Live-site visual testing | **currently BLOCKED/UNVERIFIED** | `https://music.archfox.eu.cc/music` returns 404. | Simulated viewport fixtures planned for Task 4/7. |
| Physical mobile testing | **currently BLOCKED/UNVERIFIED** | No physical device connected; the complete five-viewport headless geometry/pointer audit is done, but it is not hardware testing. | Use a physical mobile device when available; keep the headless five-size evidence separately. |
| Remote production execution | **currently BLOCKED/UNVERIFIED** | Server credentials and SSH keys pending. | Consolidated input checklist in `HANDOFF.md`. |
| Reference vhost real `nginx -t` (`AC-CONF-05`) | **currently BLOCKED/UNVERIFIED** | Nginx binary is installed; only the isolated visual proxy config was tested. The reference vhost's real assembled include context is not available, and mock argv assertions do not prove syntax. | Planned host verification upon deployment authorization. |
| Wikimedia Commons feature | **DEFERRED** | Awaiting format, size, and licensing proof. | Gated across all branches. |
