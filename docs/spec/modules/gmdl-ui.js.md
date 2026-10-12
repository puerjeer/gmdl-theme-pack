# Module Contract: `gmdl-ui.js`
<!-- Project: gmdl-theme-pack-agent · Branch: project/antigravity-overhaul -->
<!-- Stage: Task 2 — Module Contract (Canonical) -->
<!-- Date: 2026-10-13 -->

## 1. Overview & Architectural Role

`gmdl-ui.js` is the primary frontend controller module, injected with `defer` into the application DOM.
It manages:
1. User appearance settings persistence in `localStorage['gmdl-ui']`.
2. Application of theme classes (`dark`, `glass`, `lyr-*`) and dynamic accent CSS variables to `:root`.
3. Construction and rendering of the personalization trigger button (`#gmdl-ui-btn`) and floating region (`#gmdl-ui-panel`).
4. Non-modal accessibility semantics (`role="region"`), keyboard operability, and Escape key dismissal with focus restoration.
5. Exporting and importing versioned, schema-validated configuration text codes (`GMDL1:{"v":1,"settings":...}`) requiring all nine keys exactly once.

---

## 2. State Model & Schema Definition

### 2.1 State Structure (`S`)
```javascript
{
  theme: 'auto',     // 'dark' | 'light' | 'auto'
  accent: 'green',   // 'green' | 'blue' | 'purple' | 'orange' | 'pink' | 'cyan'
  bg: 'obsidian',    // 'obsidian' | 'midnight' | 'grape' | 'amoled'
  style: 'glass',    // 'solid' | 'glass'
  text: 'soft',      // 'bright' | 'soft' | 'warm'
  lyric: 'm',        // 's' | 'm' | 'big'
  glow: true,        // boolean
  blur: 10,          // integer, 0..24
  glass: 55          // integer, 0..100
}
```

### 2.2 Storage Isolation Invariant
- **`localStorage['gmdl-ui']`**: Stores JSON serialized state object `S`.
- **`localStorage['gmdl-bgimg']`**: Stores device-local Base64 data URL string. **Never included in export/import payload.**

---

## 3. Work Package Enhancements Interface

### 3.1 WP-B: Dual-Mode Glass Activation
In `apply()`:
```javascript
// Glass styling applies to both dark and light mode
var glass = S.style === 'glass';
document.documentElement.classList.toggle('glass', glass);
```
Dark appearance, contrast, and custom properties (`--primary-color`, `--glass-a`, `--glass-b`) are maintained in both modes.

### 3.2 WP-C: Non-Modal Accessibility & Keyboard Interactions
- **Button Construction:**
  ```javascript
  btn.setAttribute('aria-label', '个性化设置');
  btn.setAttribute('aria-controls', 'gmdl-ui-panel');
  btn.setAttribute('aria-expanded', 'false');
  ```
  *(Note: `aria-haspopup="dialog"` is omitted).*
- **Panel Construction:**
  ```javascript
  panel.setAttribute('role', 'region');
  panel.setAttribute('aria-label', '个性化外观设置');
  ```
  *(Note: `aria-modal="true"` is omitted; focus is not trapped).*
- **Keyboard Navigation:**
  - Tab and Shift+Tab navigate through all interactive controls; focus may leave the region naturally.
- **Escape Key & Focus Restoration:**
  ```javascript
  document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape' && panel && !panel.hidden) {
      panel.hidden = true;
      btn.setAttribute('aria-expanded', 'false');
      btn.focus();
    }
  });
  ```
- **Open / Close Toggle:**
  ```javascript
  btn.onclick = function () {
    panel.hidden = !panel.hidden;
    btn.setAttribute('aria-expanded', String(!panel.hidden));
  };
  ```

### 3.3 WP-D: Single Strict Preference-Code Contract

#### Canonical Format
The preference code uses one human-readable, copyable, non-executable format:
`GMDL1:{"v":1,"settings":{"theme":"auto","accent":"green","bg":"obsidian","style":"glass","text":"soft","lyric":"m","glow":true,"blur":10,"glass":55}}`
- Literal prefix: `GMDL1:`
- Envelope: Canonical compact JSON string containing version `v === 1` and `settings` object.
- **Deterministic Key Serialization Order:**
  - Envelope level: keys serialized strictly in order: `"v"`, `"settings"`.
  - Nested `settings` level: keys serialized strictly in order: `"theme"`, `"accent"`, `"bg"`, `"style"`, `"text"`, `"lyric"`, `"glow"`, `"blur"`, `"glass"`.
- **No Base64 alternatives and no raw-JSON fallback.**

#### Concrete User Journey (Planned Interface Contract)

> [!NOTE]
> **Planned Interface Contract Notice:**
> Existing baseline source code in `gmdl-ui.js` provides only the launcher button (`#gmdl-ui-btn`) and the base settings panel (`#gmdl-ui-panel`). Controls referenced below (`#gmdl-export-code`, `#gmdl-import-code`, `#gmdl-import-btn`, `#gmdl-import-status`, and export buttons) are **planned to-be-implemented controls** for Task 4 (Work Package D), not existing elements in the baseline codebase.

1. **Source Client (Export Journey):**
   - User clicks `#gmdl-ui-btn` to toggle open the personalization floating region.
   - User clicks planned "导出配置" (or copies from planned dedicated read-only input `#gmdl-export-code`).
   - The serialized code string `GMDL1:{"v":1,"settings":...}` is generated with deterministic key order and copied.
   - An explicit notice is visible: *"注：仅导出主题与外观偏好，自定义背景图保存在当前设备，不随代码导出。"*.
2. **Target Client (Import Journey):**
   - User clicks `#gmdl-ui-btn` on target device/browser to open personalization panel.
   - User pastes preference code into planned input `#gmdl-import-code`.
   - User clicks planned "应用" button (`#gmdl-import-btn`).
   - On valid payload: settings apply immediately without full reload; planned status node `#gmdl-import-status` confirms success.
   - On invalid payload: dedicated status node `#gmdl-import-status` (`role="status"`, `aria-live="polite"`) displays error notification (*"导入失败：配置代码格式不正确或已损坏"*). All stored appearance/background preferences and all other settings DOM controls remain 100% untouched.

#### Strict Schema Validation & Import Logic (`importCode(input)`)
1. **Length & Prefix Check:** Input must be a string ≤ 1024 characters starting with literal `GMDL1:`.
2. **Token-Aware Duplicate Key Rejection with Decoded Escapes:**
   Because standard `JSON.parse` silently overwrites duplicate object keys, duplicate member names must be rejected fail-closed on the original payload before/while decoding:
   - Duplicate member names at the envelope level (e.g., duplicate `"v"`, duplicate `"settings"`) must be rejected.
   - Duplicate member names at the `settings` object level (e.g., duplicate `"theme"`, duplicate `"accent"`) must be rejected.
   - The detector must compare **decoded JSON member names**, so that escape-encoded duplicates (such as `"theme"` and `"\u0074heme"`, or `"v"` and `"\u0076"`) are detected and rejected fail-closed.
   - Must be implemented via a lightweight, token-aware scanner or duplicate-detecting parser without third-party runtime dependencies and zero `eval()` / `Function()`.
3. **JSON Parsing:** Parse JSON payload after prefix; reject malformed JSON.
4. **Envelope Check:** Object must contain exactly `v === 1` and a `settings` object.
5. **All Nine Settings Keys Required Exactly Once:**
   - The `settings` object must contain all nine expected keys: `theme`, `accent`, `bg`, `style`, `text`, `lyric`, `glow`, `blur`, `glass`.
   - **Missing keys are rejected fail-closed.**
   - **Duplicate keys are rejected fail-closed.**
   - **Extra or unknown keys (including `__proto__`, `constructor`, `prototype`) are rejected fail-closed.**
6. **Type & Enum Validations:**
   - `theme` in `['dark', 'light', 'auto']`
   - `accent` in `['green', 'blue', 'purple', 'orange', 'pink', 'cyan']`
   - `bg` in `['obsidian', 'midnight', 'grape', 'amoled']`
   - `style` in `['solid', 'glass']`
   - `text` in `['bright', 'soft', 'warm']`
   - `lyric` in `['s', 'm', 'big']`
   - `glow`: strict boolean (`typeof === 'boolean'`)
   - `blur`: integer where `0 <= blur <= 24`
   - `glass`: integer where `0 <= glass <= 100`
7. **Safe Failure Behavior & Dedicated Status Node:**
   - Accessible feedback is provided strictly via one dedicated status element `#gmdl-import-status` with `role="status"` and `aria-live="polite"`.
   - On rejection: only the error text (*"导入失败：配置代码格式不正确或已损坏"*) is written to `#gmdl-import-status`.
   - Stored appearance and background preferences, document styling, and all other settings DOM controls must remain completely unchanged:
     - Zero `localStorage` mutations (`gmdl-ui`, `gmdl-bgimg`, `gmdl-theme` untouched).
     - Zero `<html>` class changes (`.dark`, `.glass` unchanged).
     - Zero inline CSS variable mutations (`--primary-color`, `--glass-a`, `--glass-b`, etc. unchanged).
     - Zero input/slider/toggle state changes in the settings panel.
     - Zero focus or selection side effects.
   - **Snapshot Testing Policy:** Automated tests explicitly exclude only the dedicated `#gmdl-import-status` element from DOM comparison (asserting it receives the error text) and assert that all `localStorage` state and all remaining settings DOM (classes, CSS variables, input elements, controls) match the pre-import snapshot with 100% identity. Do not describe the entire DOM as byte-for-byte unchanged when the dedicated status node's text changes.
8. **Safe Success Behavior:**
   - On success: validated keys are copied to `S`, saved to `localStorage`, and `apply()` + `refreshPanel()` are invoked; `#gmdl-import-status` reports success.
9. **User Notice:**
   - An explicit notice is visible in the UI: *"注：仅导出主题与外观偏好，自定义背景图保存在当前设备，不随代码导出。"*

---

## 4. Observable Acceptance Criteria

- **AC-UI-01:** `exportCode()` generates string starting with `GMDL1:{"v":1,"settings":` containing all nine required keys in strict deterministic key order without extra spaces.
- **AC-UI-02:** Background image data (`gmdl-bgimg`) is confirmed absent from exported code; warning notice is visible.
- **AC-UI-03:** `importCode()` with malformed input, duplicate keys (at envelope or settings level, including repeated `theme`, repeated `v`, or escape-encoded duplicates such as `"theme"` and `"\u0074heme"`), missing keys, raw JSON without `GMDL1:`, Base64 strings, unknown keys, or invalid ranges safely rejects, writing error feedback exclusively to `#gmdl-import-status` (`role="status"`, `aria-live="polite"`) without mutating `localStorage`, document classes, CSS variables, or other panel inputs.
- **AC-UI-04:** Valid imported code immediately updates active classes and CSS variables without page reload.
- **AC-UI-05:** Pressing Escape while panel is open dismisses panel and restores focus to `#gmdl-ui-btn`.
- **AC-UI-06:** `#gmdl-ui-btn` updates `aria-expanded` dynamically upon opening/closing, referencing `aria-controls="gmdl-ui-panel"`.
- **AC-UI-07:** Measured `document.documentElement.scrollWidth <= document.documentElement.clientWidth` across all viewports.
- **AC-UI-08:** Existing unit tests in `gmdl-ui.test.js` continue to pass 8/0/0.
- **AC-UI-09:** Side-effect-free snapshot verification confirms that, excluding only `#gmdl-import-status`, `localStorage` and all settings DOM state remain 100% identical before and after any rejected import, with error text confirmed present in `#gmdl-import-status`.
- **AC-UI-10:** Test suite separation policy: baseline 8 tests remain intact in `gmdl-ui.test.js`; new feature regressions are isolated in `gmdl-ui-enhancements.test.js`.
