# Product Specification: Theme & Personalization Pack
<!-- Project: gmdl-theme-pack-agent · Branch: project/antigravity-overhaul -->
<!-- Stage: Task 2 — Product Specification (Canonical) -->
<!-- Date: 2026-10-13 -->

> [!NOTE]
> **Scope & Governance Status:**
> This document establishes the authoritative product specification for the `gmdl-theme-pack` suite.
> Mainline development on `project/antigravity-overhaul` is strictly scoped to four core work packages:
> - **Work Package A:** Reversible Deployment Automation (`deploy.sh`)
> - **Work Package B:** Shared Glass Styling (Dark & Light Modes)
> - **Work Package C:** Mobile Personalization Panel & Keyboard Interactions
> - **Work Package D:** Copyable Preference Export / Import
> **Internet Archive (IA) audio discovery is commissioned for this active run** on its own dedicated branch:
> `poc/ia-audio-discovery` ([`docs/spec/IA-POC-BRANCH-PLAN.md`](IA-POC-BRANCH-PLAN.md)), strictly isolated from `main`.
> Wikimedia Commons remains **deferred**.

---

## 1. System Overview & Injection Architecture

The `gmdl-theme-pack` enhances the web interface of `go-music-dl` without modifying upstream Go code.
Delivery operates via an OpenResty/nginx reverse proxy configured to:
1. Serve static theme assets (`gmdl-dark.css`, `gmdl-ui.js`, `gmdl-feat.js`) directly with HTTP caching headers (`expires 1h`).
2. Proxy application requests to upstream `go-music-dl` with `expires -1` (no cache).
3. Inject the theme stylesheet, pre-hydration theme bootstrap script, and deferred JS modules into HTML responses using `sub_filter` before `</head>`.
4. Cache-bust injected assets using content-hashed query strings (`?v=<hash>`), maintained reversibly by `deploy.sh`.

### 1.1 Truthful Upstream Verification Status
- Official documentation confirms `./music-dl web` and default path `/music`.
- Fetched README excerpts did not independently prove that this command defaults to port 8080, so port configuration is treated as an explicit parameter rather than an assumed default.
- The official GitHub v1.1.1 release API lists `go-music-dl_linux_amd64.tar.gz` with digest:
  `sha256:be7b828096a23b7401d69649484ece667ed588116a6039bb8f55e0f4df7c5949`
- The legacy digest found in prior task context (`1a4fc4d0fa67c0e0d73fb6cebd8918c1e6998f2f23c7ee19ebacbb27f5f07d0a`; provenance unverified) does **NOT** match; it must never be used to validate or execute binaries. Before any future execution, download-time local `sha256sum` verification of the archive against the official GitHub digest is strictly required.
- At Task 2 specification acceptance, no binary had yet been downloaded or executed. After Stage 7 acceptance, the v1.1.1 archive was downloaded and verified against the official digest; its authentic UI was run loopback-only for before/after visual testing. Exact procedure and evidence are recorded in [`docs/research/UPSTREAM-VISUAL-TEST-PROVENANCE.md`](../research/UPSTREAM-VISUAL-TEST-PROVENANCE.md).
- The live public site (`https://music.archfox.eu.cc/music`) and production deployment remain separately **currently BLOCKED/UNVERIFIED**.

---

## 2. Work Package A: Reversible Deployment Automation (`deploy.sh`)

### 2.1 Functional Objective
Provide an operational shell script (`deploy.sh`) automating asset deployment and reverse proxy configuration on the target server with lock-first preflight checks, strict linear ordering, fail-closed config replacement, automated backups, and deterministic safe rollback.

### 2.2 Mandatory Preflight Verification
Before initiating any deployment mutations, `deploy.sh` executes the following preflight checks:
1. **Concurrency Lock Acquisition in Git Metadata:** Acquire an exclusive single-instance process lock (`flock` on a lockfile path derived from `git rev-parse --git-path deploy.lock` or verified non-worktree metadata directory, never a tracked or worktree-root path) **before** checking worktree cleanliness (preventing concurrency races). Ensure lock release on every exit path via an EXIT trap. Lock acquisition/release must leave `git status --porcelain` completely clean.
2. **Worktree Cleanliness Check:** Require `GIT_OPTIONAL_LOCKS=0 git status --porcelain` to exit successfully and return empty output. Disabling optional Git locks prevents status from refreshing the index; dry-run must leave both the worktree and Git index unchanged. Abort immediately for any uncommitted changes; if the status command fails, fail closed even when stdout is empty.
3. **Parameter & Path Verification:** Verify branch parameter, repository directory, and `--config` file path exist. (Do not guess or assume a production config path as a default).
4. **Main Configuration & Inclusion Verification:** Verify `--nginx-main-conf` (or env `NGINX_MAIN_CONF`) exists, is readable, and contains an active `include` directive referencing the target `--config` vhost file. If the main config does not include the target vhost, abort immediately fail-closed. Verify optional `--nginx-prefix` (or env `NGINX_PREFIX`) directory if provided.
5. **Command Availability Check:** Before state capture, backup, or pull, verify required `sha256sum`, nginx test binary, and reload command are available/executable; failures of the earlier `git`/`flock` commands also fail closed.
6. **Pre-Deploy State Capture:** Record exact pre-deploy commit hash:
   `PRE_HEAD=$(git rev-parse HEAD)`
7. **Configuration Backup:** Create a separate timestamped snapshot backup of the active configuration file:
   `<config>.bak.<timestamp>`
   *Failure boundary:* Failure during preflight or pull exits immediately leaving active configuration untouched (though the timestamped preflight backup file may already exist). If pull succeeds but `PULLED_HEAD` capture fails, halt before hashing/config changes, emit a manual-recovery diagnostic, and do not reset an unverified revision. No git reset is executed when pull or post-pull state capture fails.

### 2.3 Strict Five-Step Linear Workflow
Following successful preflight, `deploy.sh` executes the core sequence in exact linear order:

```
Step 1: git pull --ff-only
  │ (On success, immediately record PULLED_HEAD=$(git rev-parse HEAD) within this step.
  │  If pull or PULLED_HEAD capture fails, halt before hashing/config; no reset because the pulled revision is unverified)
  ▼
Step 2: Compute ?v= Hashes
  │ (SHA-256 short hashes for gmdl-dark.css, gmdl-ui.js, gmdl-feat.js;
  │  Hashing failure is a post-pull failure and invokes safe rollback)
  ▼
Step 3: Fail-Closed Atomic Config Update
  │ (Staging file created in vhost directory; verifies original owner/group/mode;
  │  verifies exactly one sub_filter token per shipped asset; atomically moved)
  ▼
Step 4: nginx -t (Real Assembled Configuration Context)
  │ (Tests NGINX_BIN via safe argv array: -t -c NGINX_MAIN_CONF [-p NGINX_PREFIX];
  │  Syntax test fails? Trigger Automatic Safe Rollback Routine)
  ▼
Step 5: Graceful Reload
  │ (Reload fails? Trigger Automatic Safe Rollback Routine)
  ▼
[Deployment Success: Release lock via EXIT trap & exit 0]
```

### 2.4 Automatic Safe Rollback & Recovery Routine
If any post-pull failure occurs during Step 2 (hashing), Step 3 (config update), Step 4 (syntax testing), or Step 5 (reload):
1. **Atomic Config Restoration:** Do not overwrite the active configuration directly with non-atomic `cp -p`. Execute atomic restoration staging: copy backup snapshot to restore staging file in target vhost directory (`${CONFIG_PATH}.rollback.tmp.$$`), preserve owner/group/mode (`stat` + `chown`/`chmod`), verify byte-for-byte content identity against the backup snapshot (`cmp -s "$RESTORE_TMP" "$BACKUP_PATH"`), verify metadata equality to active config, and atomically rename into place (`mv`). Fail closed and log if restore staging, byte-exact check, or rename cannot be verified.
2. **Conditional Safe Code Reset:**
   - Verify post-pull worktree cleanliness (`GIT_OPTIONAL_LOCKS=0 git status --porcelain` exits successfully and is empty).
   - Check if current HEAD still equals the recorded `$PULLED_HEAD`.
   - **If clean and expected:** Execute `git reset --hard "$PRE_HEAD"`.
   - **If dirty or unexpected:** **Refuse destructive reset**, emit a critical recovery warning, and do NOT destroy uncommitted or unexpected changes. Never rely on `ORIG_HEAD`.
3. **Verify Restored Configuration:** Re-run syntax test on the real assembled configuration context with the restored file using the safe argv array (`"$NGINX_BIN" "${NGINX_ARGS[@]}"`).
4. **Service Traffic Restoration:** Attempt service reload on the restored configuration using the safe reload argv array (`"$RELOAD_CMD" "${RELOAD_ARGS[@]}"`).
5. **Audit Logging & Exit:** Record rollback operations and diagnostics to log; release lock via EXIT trap; exit with non-zero status.

### 2.5 Safety Boundaries & Mock Testing Invariant
- Production execution is **NOT authorized** by the current scope.
- Script creation and isolated local mock testing are in scope; no live deployment without future explicit authorization and working server credentials. `deploy.sh` and the offline harness are implemented; all 12 behavioral cases pass. The implementation holds a read-only lock on the Git metadata directory, uses `GIT_OPTIONAL_LOCKS=0` for status queries so dry-run preserves Git index bytes/metadata, rejects malformed include directives before pull/backup, and stops with manual-recovery guidance if successful pull's `PULLED_HEAD` cannot be verified.
- Required offline mock test matrix covers at least 12 distinct conditions:
  1. `MOCK-01`: Success path in exact five-step order (preflight → pull + record PULLED_HEAD → all three hashes → config → test → reload); every hash precedes config replacement.
  2. `MOCK-02`: Single-instance lock contention halts second instance cleanly.
  3. `MOCK-03`: Read-only lock acquisition/release on `git rev-parse --absolute-git-dir` leaves porcelain clean, creates no lock file, and permits a no-write dry-run.
  4. `MOCK-04`: Dirty working tree halts preflight with zero file mutations and zero reset; lock acquisition is verified before dirty check.
  5. `MOCK-05`: Pull failure halts before config modification; active config unchanged; no git reset performed.
  6. `MOCK-06`: Post-pull asset hashing failure (Step 2) invokes safe rollback routine.
  7. `MOCK-07`: Staging file created in vhost directory with verified same-filesystem atomic rename and owner/group/mode preservation for both forward update (`.tmp.$$`) and rollback restoration (`.rollback.tmp.$$`). Rollback restoration verifies byte-for-byte identity against backup snapshot (`cmp -s`) and metadata equality before atomic rename.
  8. `MOCK-08`: Token cardinality violation (zero, multiple, or unexpected current `sub_filter` asset-version token count for `gmdl-dark.css`, `gmdl-ui.js`, or `gmdl-feat.js`; expected count is exactly 1 per asset) halts config update fail-closed before active file is modified.
  9. `MOCK-09`: Syntax test verifies assembled configuration arguments via safe argv array (`-t -c "$NGINX_MAIN_CONF"` and optional `-p "$NGINX_PREFIX"`); valid prefix variants pass, malformed include text with trailing junk is rejected before pull/backup, and syntax failure restores the backup.
  10. `MOCK-10`: Simulated reload failure triggers atomic config restoration (staged, `cmp -s` verified, atomic rename) and recovery reload using `"$RELOAD_CMD" "${RELOAD_ARGS[@]}"` (asserting exact argv array, including multi-argument systemctl-style reload invocations).
  11. `MOCK-11`: Safe code reset correctly returns to `$PRE_HEAD` on clean tree matching `$PULLED_HEAD`.
  12. `MOCK-12`: Code reset is safely **refused** when tree is dirty or current HEAD differs from `$PULLED_HEAD`.

### 2.6 Observable Acceptance Criteria (WP-A)
- **AC-A01:** `deploy.sh` acquires `flock` on a read-only descriptor for the verified Git metadata directory before dirty status, leaves no lock file, validates paths and complete include syntax, verifies `git`, `flock`, `sha256sum`, and both executable paths before backup/pull, captures `$PRE_HEAD`, and creates backup before deployment mutation; it then executes the exact five-step sequence: (1) `git pull --ff-only` with immediate recording of `$PULLED_HEAD` → (2) all asset hashes → (3) atomic config update in vhost directory with metadata preservation → (4) real assembled config `nginx -t` via safe argv array → (5) graceful reload via safe argv array. A dry-run uses the same lock and creates no backup or configuration file.
- **AC-A02:** Pull failure exits immediately leaving the active configuration untouched (preflight backup may already exist) without running git reset.
- **AC-A03:** Post-pull failure during Step 2 (hashing), Step 3 (atomic update), Step 4 (syntax test), or Step 5 (reload) restores backup config via atomic restore staging in vhost directory with verified byte-exact identity (`cmp -s`), metadata equality, and atomic rename, then attempts recovery reload.
- **AC-A04:** Staging files for both update and rollback restore are created in target vhost directory, preserve file ownership and permissions, verify byte-for-byte content identity (`cmp -s`), and validate exact asset token cardinality (exactly one current `sub_filter` asset-version token per each shipped asset: `gmdl-dark.css`, `gmdl-ui.js`, `gmdl-feat.js`; zero, multiple, or unexpected counts fail closed) before atomic replacement.
- **AC-A05:** Syntax verification tests real assembled configuration context (`-c NGINX_MAIN_CONF [-p NGINX_PREFIX]`), asserting full argument vector in offline mock harness, including unset, empty, and whitespace prefix cases and multi-argument reload arrays.
- **AC-A06:** Rollback verifies clean worktree and exact `$PULLED_HEAD` revision before resetting code; safely refuses reset if dirty or mismatched.
- **AC-A07:** Lock is guaranteed released on every exit path via EXIT trap.
- **AC-A08:** Planned deterministic offline mock test harness verifies all 12 specified test conditions without live network calls (unexecuted in this phase).

---

## 3. Work Package B: Shared Glass Styling (Dark & Light Modes)

### 3.1 Design Decision & Architectural Rationale
The project explicitly selects the **shared glass styling path** over an unrelated full redesign.
Glassmorphism provides an elevated, modern aesthetic across cards, toolbars, search boxes, and player containers while:
1. Fully preserving established dark mode appearance, contrast ratios, and user theme selections.
2. Extending translucent glass styling seamlessly into light mode (`html.glass:not(.dark)`).
3. Utilizing a unified CSS variable architecture.

### 3.2 Dual-Mode Glass Surface Architecture

#### Dark Mode Glass (`html.dark.glass`)
- Surfaces: `linear-gradient(135deg, rgba(255, 255, 255, var(--glass-a, 0.09)), rgba(255, 255, 255, calc(var(--glass-a, 0.09) * 0.35)))`
- Backdrop blur: `backdrop-filter: blur(var(--glass-b, 18px)) saturate(160%)`
- Border: `1px solid rgba(255, 255, 255, 0.12)`
- Preserves high-contrast text (`var(--text-main)`, `var(--text-sub)`) and dark gradients.

#### Light Mode Glass (`html.glass:not(.dark)`)
- Surfaces: `linear-gradient(135deg, rgba(255, 255, 255, calc(var(--glass-a, 0.55) * 0.65 + 0.30)), rgba(255, 255, 255, calc(var(--glass-a, 0.55) * 0.40 + 0.20)))`
- Backdrop blur: `backdrop-filter: blur(var(--glass-b, 18px)) saturate(140%)`
- Border: `1px solid rgba(0, 0, 0, 0.08)`
- Box shadow: `0 8px 32px 0 rgba(31, 38, 135, 0.08)`
- Text contrast: Preserves high-contrast primary text (`#1f2937`) and secondary text (`#4b5563`).

### 3.3 Observable Acceptance Criteria (WP-B)
- **AC-B01:** Switching theme to Light with Style=Glass adds class `glass` to `<html>` and renders translucent light backdrop surfaces without breaking text legibility.
- **AC-B02:** Dark mode glass visuals (`html.dark.glass`) remain visually identical to the verified baseline.
- **AC-B03:** Slider adjustments for glass intensity dynamically update `--glass-a` and `--glass-b` custom properties on `:root` in both modes.
- **AC-B04:** Accent color swatches apply correctly to active borders and progress bars in both dark and light glass modes.

---

## 4. Work Package C: Mobile Personalization Panel & Keyboard Interactions

### 4.1 Non-Modal Floating Region Semantics
- **Container Semantics:** Container `#gmdl-ui-panel` is an accessible floating region with `role="region"` and `aria-label="个性化外观设置"`.
- **Non-Modal Design:** `aria-modal="true"` and `aria-haspopup="dialog"` are omitted. It is not a modal dialog.
- **Trigger Semantics:** Trigger `#gmdl-ui-btn` exposes `aria-controls="gmdl-ui-panel"` and dynamic `aria-expanded="false"` / `"true"`.
- **Keyboard Navigation:** Tab and Shift+Tab operate naturally without focus trapping; focus is permitted to leave the region.
- **Escape Key Handling:** Pressing `Escape` when the region is open dismisses the panel (`panel.hidden = true`), updates `aria-expanded="false"`, and restores focus to `#gmdl-ui-btn`.

### 4.2 Responsive Layout & Measured Overflow Invariant
- **Responsive Width:** Panel `#gmdl-ui-panel` is constrained to `width: calc(100vw - 24px); max-width: 400px; box-sizing: border-box;`.
- **Vertical Scrolling:** `max-height: min(75vh, 580px); overflow-y: auto; -webkit-overflow-scrolling: touch;`.
- **Touch Target Bounds:** All interactive elements (`.gmdl-ui-segbtn`, `.gmdl-ui-sw`, trigger `#gmdl-ui-btn`, upload buttons) provide a minimum interactive bounding box of 44×44px.
- **Horizontal Overflow Acceptance:** Acceptance is defined as measured:
  `document.documentElement.scrollWidth <= document.documentElement.clientWidth`
  across all test viewports. Layout causes of overflow are eliminated; `overflow-x: hidden` alone is not treated as proof.

### 4.3 Viewport Acceptance Matrix

| Viewport Dimensions | Device Archetype | Acceptance Criteria |
|---|---|---|
| **320 × 568** | iPhone 5 / SE (Compact) | Measured `scrollWidth <= clientWidth`; panel fits screen; buttons wrap neatly without clipping. |
| **375 × 812** | iPhone X / 11 / 12 Mini | Measured `scrollWidth <= clientWidth`; touch targets ≥44px; swatches aligned in grid. |
| **390 × 844** | iPhone 12 / 13 / 14 | Measured `scrollWidth <= clientWidth`; sliders operable via touch drag without viewport panning. |
| **768 × 1024** | iPad / Tablet Portrait | Measured `scrollWidth <= clientWidth`; panel renders docked cleanly at bottom-right; typography crisp. |
| **1280 × 800** | Desktop / Laptop | Measured `scrollWidth <= clientWidth`; keyboard navigation and Escape dismissal verified. |

*Note:* In sandbox environments lacking physical mobile hardware, browser viewport simulation is planned after implementation, and physical device checks remain **currently BLOCKED/UNVERIFIED** (unexecuted in this phase).

### 4.4 Observable Acceptance Criteria (WP-C)
- **AC-C01:** Panel opens and closes via `#gmdl-ui-btn` while toggling `aria-expanded="true"` and `aria-expanded="false"`, referencing `aria-controls="gmdl-ui-panel"`.
- **AC-C02:** Pressing `Escape` while panel is open dismisses panel and restores DOM focus to `#gmdl-ui-btn`.
- **AC-C03:** Measured `document.documentElement.scrollWidth <= document.documentElement.clientWidth` across all five viewports (320px to 1280px).
- **AC-C04:** Touch targets for buttons and swatches measure ≥44×44px interactive area.
- **AC-C05:** Keyboard navigation operates naturally with Tab/Shift+Tab without modal focus trapping.

---

## 5. Work Package D: Copyable Preference Export / Import

### 5.1 Storage Boundary & Background Image Exclusion
- **Scope Boundary:** Export and import operations apply strictly to appearance settings in `localStorage['gmdl-ui']`.
- **Exclusion of `gmdl-bgimg`:** Uploaded background image payloads (base64 Data URLs) are excluded to prevent clipboard overflow and memory bloat. Background image storage remains strictly device-local.
- **User Notice:** Explicit UI notice displayed:
  *"注：仅导出主题与外观偏好，自定义背景图保存在当前设备，不随代码导出。"*

### 5.2 Single Strict Preference-Code Contract
A single, human-readable, copyable, non-executable format is specified:
- **Format:** Literal prefix `GMDL1:` followed by a canonical, compact JSON envelope (no extraneous whitespace):
  `GMDL1:{"v":1,"settings":{"theme":"auto","accent":"green","bg":"obsidian","style":"glass","text":"soft","lyric":"m","glow":true,"blur":10,"glass":55}}`
- **Deterministic Key Serialization Order:**
  - Envelope level: keys serialized strictly in order: `"v"`, `"settings"`.
  - Nested `settings` level: keys serialized strictly in order: `"theme"`, `"accent"`, `"bg"`, `"style"`, `"text"`, `"lyric"`, `"glow"`, `"blur"`, `"glass"`.
- **Rejection of Alternatives:** Base64 alternatives and raw-JSON envelopes without prefix are strictly rejected.

### 5.3 Concrete User Journey (Planned Interface Contract)

> [!NOTE]
> **Planned Interface Contract Notice:**
> Existing baseline source code in `gmdl-ui.js` provides only the launcher button (`#gmdl-ui-btn`) and the base settings panel (`#gmdl-ui-panel`). Controls referenced below (`#gmdl-export-code`, `#gmdl-import-code`, `#gmdl-import-btn`, `#gmdl-import-status`, and export triggers) are **planned to-be-implemented controls** for Task 4 (Work Package D), not existing elements in the baseline codebase.

1. **Source Client (Export Journey):**
   - User opens floating panel via `#gmdl-ui-btn`.
   - User clicks planned export button (or copies from planned dedicated read-only input `#gmdl-export-code`).
   - The serialized code string `GMDL1:{"v":1,"settings":...}` is generated with deterministic key ordering and copied.
   - An explicit notice is visible: *"注：仅导出主题与外观偏好，自定义背景图保存在当前设备，不随代码导出。"*.
2. **Target Client (Import Journey):**
   - User opens floating panel via `#gmdl-ui-btn` on target browser/device.
   - User pastes preference code into planned input `#gmdl-import-code`.
   - User clicks planned "应用" button (`#gmdl-import-btn`).
   - On valid payload: settings apply immediately without full reload; planned status node `#gmdl-import-status` confirms success.
   - On invalid payload: dedicated status node `#gmdl-import-status` (`role="status"`, `aria-live="polite"`) displays error notification (*"导入失败：配置代码格式不正确或已损坏"*). All stored appearance/background preferences and all other settings DOM controls remain 100% untouched.

### 5.4 Strict Schema Validation Rules
Upon receiving an imported code string, the deserializer must validate:
1. **Prefix & Format:** Must start with literal `GMDL1:` followed by valid JSON.
2. **Duplicate Key Rejection (Pre-decode / Token-Aware with JSON Escapes):**
   Standard `JSON.parse` silently retains only one value when object member names are duplicated. Therefore, “all nine keys exactly once” must be enforceable on the original raw payload, not merely on the parsed object:
   - Duplicate member names are rejected fail-closed at both the envelope level (e.g., duplicate `v`, duplicate `settings`) and the nested `settings` level (e.g., duplicate `theme`, duplicate `accent`).
   - The detector must compare **decoded JSON member names**, so that escape-encoded forms (e.g., `"theme"` and `"\u0074heme"`, or `"v"` and `"\u0076"`) are correctly detected as duplicates and rejected fail-closed.
   - The implementation must use a lightweight, token-aware duplicate-key detector or duplicate-detecting parser before or during decoding, using no third-party runtime dependencies and zero `eval()` / `Function()`.
3. **Envelope Check:** Parsed object must contain exactly `v === 1` and a `settings` object.
4. **Exact Nine Keys Required Exactly Once:**
   The `settings` object must require all nine keys: `theme`, `accent`, `bg`, `style`, `text`, `lyric`, `glow`, `blur`, `glass`. Missing keys, duplicate keys, or extra/unknown keys (including prototype properties `__proto__`, `constructor`) cause fail-closed rejection.
5. **Enum Boundary Validation:**
   - `theme` in `['dark', 'light', 'auto']`
   - `accent` in `['green', 'blue', 'purple', 'orange', 'pink', 'cyan']`
   - `bg` in `['obsidian', 'midnight', 'grape', 'amoled']`
   - `style` in `['solid', 'glass']`
   - `text` in `['bright', 'soft', 'warm']`
   - `lyric` in `['s', 'm', 'big']`
   - `glow`: typeof boolean
6. **Number Range Boundaries:**
   - `blur`: integer where `0 <= blur <= 24`
   - `glass`: integer where `0 <= glass <= 100`
7. **Input Size Cap:** Strings exceeding 1024 characters are rejected immediately.
8. **Anti-Eval Security:** Zero use of `eval()`, `new Function()`, or arbitrary object assignment.

### 5.5 Safe Failure & Feedback Behavior
- Accessible feedback is provided strictly via one dedicated status node: `#gmdl-import-status` with `role="status"` and `aria-live="polite"`.
- If validation fails: error text (*"导入失败：配置代码格式不正确或已损坏"*) is written exclusively to `#gmdl-import-status`. Stored appearance/background preferences and all other settings DOM remain completely unchanged:
  - Zero `localStorage` mutations (`gmdl-ui`, `gmdl-bgimg`, `gmdl-theme` untouched).
  - Zero `<html>` class list mutations (`.dark`, `.glass` unchanged).
  - Zero inline CSS variable mutations (`--primary-color`, `--glass-a`, `--glass-b`, etc. unchanged).
  - Zero input/slider/toggle state mutations.
  - Zero focus or selection side effects.
- **Side-Effect-Free Snapshot Verification:** Automated tests snapshot `localStorage` and all settings DOM state prior to calling `importCode()`. Tests explicitly exclude only the dedicated `#gmdl-import-status` element from the DOM snapshot comparison, asserting it receives the error string while all storage and settings DOM snapshots match with 100% identity. Do not describe the entire DOM as byte-for-byte unchanged when the dedicated status node's text changes.
- If validation succeeds: validated settings commit to `localStorage['gmdl-ui']`, apply immediately without reload, and `#gmdl-import-status` reports success.

### 5.6 Round-Trip Fidelity
Executing `importCode(exportCode())` produces 100% identical configuration state.

### 5.7 Observable Acceptance Criteria (WP-D)
- **AC-D01:** Clicking export generates string starting with `GMDL1:{"v":1,"settings":...}` containing all nine required keys in strict deterministic key order.
- **AC-D02:** Background image data (`gmdl-bgimg`) is absent from exported code; warning notice is visible.
- **AC-D03:** Importing valid code restores settings immediately.
- **AC-D04:** Importing malformed JSON, duplicate keys (at envelope or settings level, including repeated `theme`, repeated `v`, or escape-encoded duplicates such as `"theme"` and `"\u0074heme"`), missing keys, unknown keys, raw JSON, Base64 strings, or out-of-range numbers safely fails, writing error feedback exclusively to `#gmdl-import-status` (`role="status"`, `aria-live="polite"`) without mutating `localStorage`, document classes, CSS variables, or other panel inputs.
- **AC-D05:** Round-trip export and import preserves 100% configuration fidelity.
- **AC-D06:** Zero `eval()` or dangerous deserialization patterns in code.
- **AC-D07:** Side-effect-free snapshot testing confirms that, excluding only `#gmdl-import-status`, all `localStorage` state and settings DOM remain 100% identical before and after any rejected import, with error text confirmed present in `#gmdl-import-status`.

---

## 6. Specification Traceability & Matrix

| Work Package | Deliverables | Related Specs & Modules | Acceptance Criteria |
|---|---|---|---|
| **WP-A** | `deploy.sh` | [`modules/deploy.sh.md`](modules/deploy.sh.md), [`modules/openresty-vhost-example.conf.md`](modules/openresty-vhost-example.conf.md) | AC-A01 – AC-A08 (12 mock tests) |
| **WP-B** | Shared Glass Styling | [`modules/gmdl-dark.css.md`](modules/gmdl-dark.css.md), [`modules/gmdl-ui.js.md`](modules/gmdl-ui.js.md) | AC-B01 – AC-B04 |
| **WP-C** | Mobile & Keyboard Panel | [`modules/gmdl-ui.js.md`](modules/gmdl-ui.js.md), [`modules/gmdl-dark.css.md`](modules/gmdl-dark.css.md) | AC-C01 – AC-C05 |
| **WP-D** | Preference Export/Import | [`modules/gmdl-ui.js.md`](modules/gmdl-ui.js.md) | AC-D01 – AC-D07 |
| **WP-IA** | Isolated IA PoC Branch | [`IA-POC-BRANCH-PLAN.md`](IA-POC-BRANCH-PLAN.md) | IA-01 – IA-10 |

### 6.1 Test Suite Accounting & Separation Policy
The project mandates clear separation across test suites:
- **Baseline Suite (`gmdl-ui.test.js`):** Preserves original 8 unit tests covering legacy accent behaviors. Currently executed and passing (8 pass / 0 fail / 0 skipped).
- **Enhancement Suite (`gmdl-ui-enhancements.test.js`):** Dedicated regression suite for Work Packages B, C, and D; final run passes 29/29, separate from the unchanged baseline 8 tests.
- **Deployment Suite:** Offline mock deployment harness covering `MOCK-01` through `MOCK-12`; latest v2.1 run passes 12/12 including Git-index-invariant dry-run, nonzero status fail-closed, successful pull/failed `PULLED_HEAD` capture, missing-`sha256sum` before state capture, and rollback guards. No production or external-network execution is claimed.
- **Isolated IA PoC Suite (`gmdl-ia.test.js`):** Ten deterministic offline tests on `poc/ia-audio-discovery`; latest v2.1 run passes 10/10 including stale resolve and reject arriving after the replacement track is already playing. Final independent review passed; owner review of the exact payload before branch-only push remains pending. No live IA calls are made.
