# Module Contract: `gmdl-dark.css`
<!-- Project: gmdl-theme-pack-agent · Branch: project/antigravity-overhaul -->
<!-- Stage: Task 2 — Module Contract (Canonical) -->
<!-- Date: 2026-10-13 -->

## 1. Overview & Architectural Role

`gmdl-dark.css` is the core stylesheet for the theme pack, loaded via OpenResty injection in `<head>`.
It defines:
1. CSS custom property tokens for color themes and glass intensity.
2. Complete dark mode styling overrides for upstream `go-music-dl` components when `<html class="dark">`.
3. Shared glassmorphism styling for both dark mode (`html.dark.glass`) and light mode (`html.glass:not(.dark)`).
4. Responsive layout constraints, touch target dimensions, and accessible focus states for the personalization region (`#gmdl-ui-panel`).

---

## 2. Token & Custom Property Specifications

### 2.1 CSS Custom Properties
```css
:root {
  --primary-color: #34d399; /* Overridden dynamically by gmdl-ui.js accent */
  --primary-gradient: linear-gradient(135deg, #34d399 0%, #059669 100%);
  --glass-a: 0.09;          /* Computed surface opacity from S.glass */
  --glass-b: 18px;          /* Computed backdrop blur radius from S.glass */
}

html.dark {
  --bg-color: #0d1117;
  --card-bg: #161d27;
  --text-main: #e6edf3;
  --text-sub: #9aa7b8;
  --shadow: 0 4px 6px rgba(0, 0, 0, 0.35);
  --shadow-active: 0 10px 15px -3px rgba(52, 211, 153, 0.25);
  color-scheme: dark;
}
```

---

## 3. Dual-Mode Shared Glass Styling Rules

### 3.1 Dark Mode Glass (`html.dark.glass`)
Preserves existing baseline visuals exactly:
```css
html.dark.glass .search-box,
html.dark.glass .song-card,
html.dark.glass .playlist-card,
html.dark.glass .source-card,
html.dark.glass .list-header,
html.dark.glass .batch-toolbar,
html.dark.glass .settings-modal,
html.dark.glass .app-update-modal,
html.dark.glass .song-list-tools-popover,
html.dark.glass .source-selector,
html.dark.glass .download-records-table {
  background: linear-gradient(135deg, rgba(255, 255, 255, var(--glass-a, 0.09)), rgba(255, 255, 255, calc(var(--glass-a, 0.09) * 0.35)));
  backdrop-filter: blur(var(--glass-b, 18px)) saturate(160%);
  -webkit-backdrop-filter: blur(var(--glass-b, 18px)) saturate(160%);
}
```

### 3.2 Light Mode Glass (`html.glass:not(.dark)`)
Adapts glassmorphism for light environments:
```css
html.glass:not(.dark) .search-box,
html.glass:not(.dark) .song-card,
html.glass:not(.dark) .playlist-card,
html.glass:not(.dark) .source-card,
html.glass:not(.dark) .list-header,
html.glass:not(.dark) .batch-toolbar,
html.glass:not(.dark) .settings-modal,
html.glass:not(.dark) .app-update-modal,
html.glass:not(.dark) .song-list-tools-popover,
html.glass:not(.dark) .source-selector,
html.glass:not(.dark) .download-records-table {
  background: linear-gradient(135deg, rgba(255, 255, 255, calc(var(--glass-a, 0.55) * 0.65 + 0.30)), rgba(255, 255, 255, calc(var(--glass-a, 0.55) * 0.40 + 0.20)));
  backdrop-filter: blur(var(--glass-b, 18px)) saturate(140%);
  -webkit-backdrop-filter: blur(var(--glass-b, 18px)) saturate(140%);
  border: 1px solid rgba(0, 0, 0, 0.08);
  box-shadow: 0 8px 32px 0 rgba(31, 38, 135, 0.08);
}
```

---

## 4. Mobile & Personalization Region Responsive Rules

```css
/* Responsive floating region sizing & layout containment */
#gmdl-ui-panel {
  position: fixed;
  right: 12px;
  bottom: 64px;
  width: calc(100vw - 24px);
  max-width: 400px;
  max-height: min(75vh, 580px);
  overflow-y: auto;
  box-sizing: border-box;
  z-index: 10000;
  -webkit-overflow-scrolling: touch;
}

/* Touch-friendly interactive targets (min 44x44px bounding area) */
#gmdl-ui-btn {
  width: 44px;
  height: 44px;
  min-width: 44px;
  min-height: 44px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.gmdl-ui-segbtn {
  min-height: 44px;
  padding: 8px 14px;
  font-size: 14px;
  box-sizing: border-box;
}

.gmdl-ui-sw {
  width: 36px;
  height: 36px;
  min-width: 36px;
  min-height: 36px;
  margin: 4px;
  border-radius: 50%;
  cursor: pointer;
  position: relative;
}
/* Touch expander for swatches to satisfy 44px touch ergonomics */
.gmdl-ui-sw::after {
  content: "";
  position: absolute;
  top: -4px; left: -4px; right: -4px; bottom: -4px;
}

/* Keyboard focus rings */
#gmdl-ui-btn:focus-visible,
.gmdl-ui-segbtn:focus-visible,
.gmdl-ui-sw:focus-visible,
#gmdl-ui-panel input[type="range"]:focus-visible {
  outline: 2px solid var(--primary-color);
  outline-offset: 2px;
}
```

---

## 5. Observable Acceptance Criteria

- **AC-CSS-01:** When `<html>` has class `glass` without `dark`, cards render translucent light glass styling with clear contrast and borders.
- **AC-CSS-02:** When `<html>` has class `dark` and `glass`, dark mode glass visuals are identical to existing baseline.
- **AC-CSS-03:** On narrow viewports (320px–390px), `#gmdl-ui-panel` does not cause horizontal page overflow (`scrollWidth <= clientWidth`).
- **AC-CSS-04:** All interactive buttons and controls have accessible touch areas ≥44×44px.
- **AC-CSS-05:** Keyboard focus outlines (`:focus-visible`) are clearly distinguishable on all panel controls without modal focus trapping.
