# Architecture: Reverse-Proxy Injected Theme & Personalization Pack
<!-- Project: gmdl-theme-pack-agent · Branch: project/antigravity-overhaul -->
<!-- Stage: Task 2 — Canonical Architecture Specification -->
<!-- Date: 2026-10-13 -->

## 1. System Topology & Reverse-Proxy Injection Model

The `gmdl-theme-pack` architecture operates completely external to upstream [go-music-dl](https://github.com/guohuiyuan/go-music-dl) Go binaries.
All styling, personalization controls, and frontend features are delivered through an OpenResty (Nginx) reverse proxy that intercepts HTML responses and injects assets into the DOM.

```
                                  ┌────────────────────────────────────────────────────────┐
                                  │                  OpenResty Reverse Proxy               │
                                  │                                                        │
┌──────────────┐   HTTP/HTTPS     │  /gmdl-dark.css ──► Static CSS (expires 1h)            │
│ Client       │ ───────────────► │  /gmdl-ui.js   ──► Static JS (expires 1h)              │
│ Browser      │                  │  /gmdl-feat.js ──► Static JS (expires 1h)              │
│              │ ◄─────────────── │                                                        │
└──────────────┘   Injected HTML  │  / (HTML App)  ──► Proxy upstream: 127.0.0.1:9981      │
                                  │                    (expires -1, Accept-Encoding: "")   │
                                  │                    Injects via sub_filter before </head>│
                                  └────────────────────────────────────────────────────────┘
                                                              │ proxy_pass
                                                              ▼
                                               ┌─────────────────────────────┐
                                               │ Upstream go-music-dl Server │
                                               │ (Loopback port, unmod Go)   │
                                               └─────────────────────────────┘
```

### 1.1 Upstream Decoupling & Verification Boundaries
- **Upstream Source Code:** Never cloned into build artifacts or modified; no Go changes permitted.
- **Upstream Documentation Facts:** Fetched official documentation confirms `./music-dl web` and default path `/music`. (Official excerpts did not independently prove default port 8080, so port configuration must not be assumed without verified configuration).
- **Binary Digest Invariant:** The GitHub official v1.1.1 release API lists `go-music-dl_linux_amd64.tar.gz` with digest `sha256:be7b828096a23b7401d69649484ece667ed588116a6039bb8f55e0f4df7c5949`. The legacy digest found in prior task context (`1a4fc4d0fa67c0e0d73fb6cebd8918c1e6998f2f23c7ee19ebacbb27f5f07d0a`; provenance unverified) does NOT match and must never be used to validate or run assets. Before any future execution, download-time local `sha256sum` verification of the archive against the official GitHub digest is strictly required. No binary has been downloaded or executed in this environment. Authentic upstream UI loopback testing is planned only after Stage 7 documents and reviews the procedure; live public site and production deployment remain separately **currently BLOCKED/UNVERIFIED**.
- **Compression & Sub-Filter Injection:** Upstream HTML passes through OpenResty with `proxy_set_header Accept-Encoding ""` to disable upstream gzip compression, permitting `sub_filter` string substitution to match `</head>`.

### 1.2 Injection Payload Structure
OpenResty injects three distinct elements immediately prior to `</head>`:
1. **Primary Theme Stylesheet:**
   `<link rel="stylesheet" href="/gmdl-dark.css?v=<css_hash>">`
2. **Pre-Hydration Anti-Flicker Bootstrap Script:**
   Inline script executing synchronously before body render to read `localStorage['gmdl-ui']` (or system `prefers-color-scheme`) and add class `dark` to `<html>` if applicable, eliminating light-flash flicker on initial page load.
3. **Deferred JavaScript Modules:**
   `<script src="/gmdl-ui.js?v=<ui_hash>" defer></script>`
   `<script src="/gmdl-feat.js?v=<feat_hash>" defer></script>`

---

## 2. Component Interactions & Runtime Lifecycle

```
[Page Load]
    │
    ▼
[OpenResty Injection] ──► Synchronous Pre-Hydration Script
                               │ (inspects localStorage['gmdl-ui'])
                               ▼
                          <html> gets class .dark or .glass
                               │
                               ▼
[HTML Body Rendered] ──► DOMContentLoaded Event
                               │
                               ├─────────────────────────────┐
                               ▼                             ▼
                        gmdl-ui.js Bootstraps         gmdl-feat.js Bootstraps
                        - S = load()                  - Mounts daily song pill
                        - apply() styles & variables  - Hooks blank search pagination
                        - build() floating region
```

### 2.1 CSS Variable Pipeline
`gmdl-ui.js` dynamically maintains a `<style id="gmdl-accent">` element in `<head>` that overrides `:root` custom properties based on active state:
- `--primary-color`: Active accent color (e.g. `#10b981`).
- `--primary-gradient`: Linear gradient for buttons, active tabs, and sliders.
- `--glass-a`: Computed surface opacity alpha derived from `S.glass`.
- `--glass-b`: Computed backdrop blur radius in pixels derived from `S.glass`.
- Dynamic background styles: Obsidian, Midnight, Grape, or Amoled radial gradients.

---

## 3. Work Package A: Reversible Deployment & Rollback Architecture

### 3.1 Preflight & Safety Architecture
Before initiating any deployment mutations, `deploy.sh` executes a strict preflight phase:
1. **Single-Instance Concurrency Lock:** Acquire exclusive process lock (`flock` on lockfile or atomic lock directory) **before** checking worktree cleanliness (preventing concurrency races). The lock path must be derived from Git metadata (`git rev-parse --git-path deploy.lock` or verified non-worktree metadata path), ensuring `git status --porcelain` is left completely clean. Ensure lock release on every exit path via an EXIT trap.
2. **Worktree Cleanliness Check:** Verify git working tree is clean (`git status --porcelain` is empty); abort immediately if dirty.
3. **Parameter & Path Verification:** Verify branch, target repository directory, and vhost configuration path (`--config`) exist.
4. **Main Configuration & Inclusion Verification:** Verify `--nginx-main-conf` (or env `NGINX_MAIN_CONF`) exists, is readable, and contains an active `include` directive referencing `--config`. If the main configuration does not include the target vhost, abort immediately fail-closed. Verify optional `--nginx-prefix` (or env `NGINX_PREFIX`) directory if provided.
5. **Command Availability Check:** Verify presence of `git`, `sha256sum`, and target nginx binary.
6. **Pre-Deploy State Capture:** Record exact pre-deploy commit hash (`PRE_HEAD=$(git rev-parse HEAD)`).
7. **Configuration Backup:** Create timestamped backup of the active configuration file (`vhost.conf.bak.<timestamp>`).

### 3.2 Five-Step Core Deployment Sequence
The core deployment steps execute in strict linear sequence:
1. `git pull --ff-only`: Fast-forward pull of authorized target branch, immediately followed within this same step by recording `PULLED_HEAD=$(git rev-parse HEAD)` on success. (If pull fails, halt immediately; the active configuration is left completely untouched, although the timestamped preflight backup file may already exist, and NO git reset is performed).
2. **Asset Hash Computation:** Compute deterministic SHA-256 short hashes for `gmdl-dark.css`, `gmdl-ui.js`, and `gmdl-feat.js`.
3. **Atomic Config Update:** Perform fail-closed atomic replacement of `?v=<hash>` parameters in the configuration file using a temporary staging file created in the target vhost file's own directory (guaranteeing same-filesystem atomic `mv`). The script verifies and preserves the original file owner, group, and permissions mode (failing closed if preservation cannot be guaranteed) and verifies exact asset token cardinality (exactly one current `sub_filter` asset-version token each for `gmdl-dark.css`, `gmdl-ui.js`, and `gmdl-feat.js`; zero, multiple, or unexpected counts fail closed) before atomic replacement.
4. `nginx -t`: Execute syntax validation on the modified configuration in the real assembled configuration context that includes the target vhost (`"$NGINX_BIN"` invoked via safe argv array: `-t -c "$NGINX_MAIN_CONF"` with conditional `${NGINX_PREFIX:-}`), asserted in the mock test harness.
5. **Graceful Service Reload:** Trigger service reload via safe argv array (`"$RELOAD_CMD" "${RELOAD_ARGS[@]}"`).

### 3.3 Safe Rollback & Recovery Architecture
If any post-pull step fails during Step 2 (hashing), Step 3 (config update), Step 4 (syntax testing), or Step 5 (reload):
1. **Atomic Config Restoration:** Do not overwrite the active configuration directly with non-atomic `cp -p`. Execute atomic restoration staging: copy backup snapshot to restore staging file in target vhost directory (`${CONFIG_PATH}.rollback.tmp.$$`), preserve owner/group/mode (`stat` + `chown`/`chmod`), verify byte-for-byte content identity against the backup snapshot (`cmp -s "$RESTORE_TMP" "$BACKUP_PATH"`), verify metadata equality against target configuration, and atomically rename into place (`mv`). Fail closed and log if restore staging, byte-exact check, or rename cannot be verified.
2. **Conditional Safe Code Reset:**
   - Verify post-pull worktree cleanliness (`git status --porcelain` is empty).
   - Check if current HEAD still equals the recorded `$PULLED_HEAD`.
   - **If clean and expected:** Execute `git reset --hard "$PRE_HEAD"`.
   - **If dirty or unexpected:** **Refuse automatic git reset**, log an urgent manual recovery error, and never destroy uncommitted or unexpected changes. Do not rely on `ORIG_HEAD`.
3. **Verify Restored Configuration:** Re-run syntax test on the real assembled configuration context with the restored configuration using the same safe argv array (`"$NGINX_BIN" "${NGINX_ARGS[@]}"`).
4. **Service Traffic Restoration:** Attempt service reload on the restored configuration using the safe reload argv array (`"$RELOAD_CMD" "${RELOAD_ARGS[@]}"`).
5. **Release Concurrency Lock:** Lock is cleared via EXIT trap on all paths.
6. **Audit Logging & Exit:** Record rollback operations and diagnostics to log; exit with non-zero status.

*Scope Note:* Production execution is NOT authorized. The script will be created and tested locally via deterministic mock harnesses covering at least 12 distinct conditions (`MOCK-01` through `MOCK-12`); no live server calls. In this phase, the 12 mock cases remain planned specifications only (unexecuted).

---

## 4. UI Architecture & Accessibility Model

### 4.1 Non-Modal Floating Personalization Region
The personalization panel (`#gmdl-ui-panel`) is architected as an accessible, non-modal floating region:
- **Semantic Roles:** Container uses `role="region"` with accessible label `aria-label="个性化外观设置"`. It is **not** a modal dialog (`aria-modal="true"` and `aria-haspopup="dialog"` are omitted).
- **Trigger Semantics:** Button `#gmdl-ui-btn` exposes `aria-controls="gmdl-ui-panel"` and dynamic `aria-expanded="false"` / `"true"`.
- **Keyboard Navigation:** Standard `Tab` and `Shift+Tab` operate naturally without focus trapping; focus is permitted to leave the region.
- **Escape Key Handling:** Pressing `Escape` when the region is visible dismisses the panel and returns DOM focus to `#gmdl-ui-btn`.

### 4.2 Viewport Responsiveness & True Overflow Measurement
- Layout rules enforce strict containment (`max-width: min(420px, calc(100vw - 24px))`, margin auto / bounded margins).
- Touch target ergonomics require minimum 44×44px interactive bounds across buttons, swatches, and sliders.
- **Overflow Acceptance Criterion:** Horizontal overflow acceptance is defined by programmatic measurement:
  `document.documentElement.scrollWidth <= document.documentElement.clientWidth`
  across all test viewports (320×568, 375×812, 390×844, 768×1024, 1280×800). Applying `overflow-x: hidden` alone is not treated as proof of responsive adaptation; actual layout causes of overflow are eliminated.

---

## 5. Client-Side Storage & Strict Preference-Code Contract

### 5.1 Storage Partitioning
- **`localStorage['gmdl-ui']`**: Stores serialized settings object `S` (< 300 bytes).
- **`localStorage['gmdl-bgimg']`**: Stores device-local custom background image Data URL. Strictly excluded from preference codes to prevent payload explosion; explicit UI notice informs the user.
- **`localStorage['gmdl-theme']`**: Legacy key migrated and removed on first boot.

### 5.2 Canonical Preference-Code Contract
A single, strict, human-readable, non-executable format is specified:
- **Format:** Literal prefix `GMDL1:` followed by a canonical, compact JSON envelope (no extraneous whitespace).
- **Deterministic Key Serialization Order:**
  - Envelope level: keys serialized strictly in order: `"v"`, `"settings"`.
  - Nested `settings` level: keys serialized strictly in order: `"theme"`, `"accent"`, `"bg"`, `"style"`, `"text"`, `"lyric"`, `"glow"`, `"blur"`, `"glass"`.
  - Example: `GMDL1:{"v":1,"settings":{"theme":"auto","accent":"green","bg":"obsidian","style":"glass","text":"soft","lyric":"m","glow":true,"blur":10,"glass":55}}`
- **Validation Rules:**
  - Base64 encoding and raw-JSON fallbacks are rejected.
  - Strict JSON parse; no `eval()`, `new Function()`, or arbitrary object assignment.
  - **Duplicate Key Rejection:** Because native `JSON.parse` silently overwrites duplicate object keys, duplicate member names are rejected fail-closed on the original payload before/while decoding at both envelope (e.g. repeated `v`, repeated `settings`) and `settings` object levels (e.g. repeated `theme`, repeated `accent`). The detector must compare **decoded JSON member names**, so that escape-encoded forms (e.g., `"theme"` and `"\u0074heme"`, or `"v"` and `"\u0076"`) are detected as duplicates. A token-aware duplicate detector or duplicate-detecting parser must be implemented without third-party dependencies and zero `eval()` / `Function()`.
  - Must have `v === 1` and `settings` object.
  - Exactly all nine expected keys (`theme`, `accent`, `bg`, `style`, `text`, `lyric`, `glow`, `blur`, `glass`) required exactly once; missing keys, duplicate keys, unknown keys, prototype properties (`__proto__`, `constructor`), wrong types, out-of-range numbers, malformed syntax, or oversized input (> 1024 chars) are rejected fail-closed.
  - On rejection, existing `localStorage` and all settings DOM controls remain 100% unchanged.

### 5.3 Concrete User Journey (Planned Interface Contract)

> [!NOTE]
> **Planned Interface Contract Notice:**
> Existing baseline source code in `gmdl-ui.js` provides only the launcher button (`#gmdl-ui-btn`) and the base settings panel (`#gmdl-ui-panel`). Controls referenced below (`#gmdl-export-code`, `#gmdl-import-code`, `#gmdl-import-btn`, `#gmdl-import-status`, and export buttons) are **planned to-be-implemented controls** for Task 4 (Work Package D), not existing elements in the baseline codebase.

1. **Source Client (Export Journey):**
   - User clicks `#gmdl-ui-btn` to toggle open the floating personalization region.
   - User clicks the planned export button (or copies from planned dedicated read-only export input `#gmdl-export-code`).
   - The serialized code string `GMDL1:{"v":1,"settings":...}` is generated and copied to clipboard.
   - An explicit notice is displayed: *"注：仅导出主题与外观偏好，自定义背景图保存在当前设备，不随代码导出。"*.
2. **Target Client (Import Journey):**
   - User clicks `#gmdl-ui-btn` on the target device/browser to open the floating personalization region.
   - User pastes the preference code into the planned import input field (`#gmdl-import-code`).
   - User clicks the planned "应用" button (`#gmdl-import-btn`).
   - On successful validation: new settings commit to `localStorage['gmdl-ui']` and apply immediately to DOM classes and CSS variables without page reload; planned status node `#gmdl-import-status` confirms success.
   - On failed validation: dedicated status node `#gmdl-import-status` (`role="status"`, `aria-live="polite"`) displays error notification (*"导入失败：配置代码格式不正确或已损坏"*). All stored appearance/background preferences and all other settings DOM controls remain 100% untouched.

### 5.4 Side-Effect-Free Import Validation Proof
To verify that invalid imports have zero side effects:
- Automated tests capture a full snapshot of `localStorage['gmdl-ui']`, `localStorage['gmdl-bgimg']`, document classes (`.dark`, `.glass`), inline CSS variables, and panel control inputs/values prior to calling `importCode()`.
- After attempting import with malformed syntax, duplicate keys (envelope or settings), missing keys, unknown keys, out-of-range numbers, or prototype pollution payloads, tests explicitly exclude only the dedicated `#gmdl-import-status` node (which receives the error message) and assert that all storage, classes, CSS custom properties, and settings panel DOM properties match the pre-call snapshot with 100% identity. Do not describe the entire DOM as byte-for-byte unchanged when the status node changes.

---

## 6. Commissioned Isolated PoC & Deferred Subsystems

### 6.1 Commissioned Isolated IA PoC Branch
- Internet Archive (IA) audio discovery is **commissioned for this active run** on isolated branch `poc/ia-audio-discovery`.
- Specified in [`docs/spec/IA-POC-BRANCH-PLAN.md`](IA-POC-BRANCH-PLAN.md) branched freshly from baseline `126853a` (never accessing `/workspace/gmdl-theme-pack-poc`).
- Mainline `project/antigravity-overhaul` and eventual publication target `main` remain 100% free of IA code; zero IA code shall ever merge into `main`.

### 6.2 Wikimedia Commons Deferral
- Gated on playable audio format filtering (excluding MIDI), strict file size limits (excluding >150MB WAVs), and machine-verifiable licensing.
- Fully deferred across all branches.

---

## 7. Test Suite Accounting & Separation

The verification architecture separates testing into distinct suites with explicit boundaries:
1. **Mainline Baseline Regression Suite (`gmdl-ui.test.js`):**
   - Retains existing 8 unit tests intact (covering legacy accent logic, color overrides, and baseline DOM structures). Currently executed and passing: 8 pass / 0 fail / 0 skipped.
2. **Mainline Enhancements Suite (`gmdl-ui-enhancements.test.js`):**
   - Planned dedicated suite for new Task 4 feature regressions: dual-mode glass variables, floating region keyboard and ARIA interactions, deterministic export serialization order, token-aware duplicate key rejection with decoded JSON escapes, side-effect-free invalid import snapshot invariance, and round-trip fidelity.
   - Currently planned and unexecuted. The project never claims the entire feature work is covered by the baseline 8 tests.
3. **Deployment Automation Mock Suite:**
   - Planned offline mock harness covering the 12 deterministic mock test conditions (`MOCK-01` through `MOCK-12`) verifying preflight lock, porcelain cleanliness, failure boundaries, rollback config restoration with byte-exact `cmp -s`, conditional code reset, and assembled syntax test arguments. Currently specified only and unexecuted.
4. **Isolated IA PoC Suite (`gmdl-ia.test.js`):**
   - Planned 10 deterministic unit tests on isolated branch `poc/ia-audio-discovery` covering search query construction, format filtering, file size cap, audio URL generation, and player state transitions. Currently planned and unexecuted.
