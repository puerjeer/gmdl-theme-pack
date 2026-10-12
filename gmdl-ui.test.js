/**
 * Regression test: apply() must include accent-color CSS rules for
 * hover/focus/search-btn styles in both dark and light mode.
 *
 * Uses Node.js built-ins only (node:test, node:vm, node:fs).
 * Run with: node --test gmdl-ui.test.js
 */
'use strict';

const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

// ---------------------------------------------------------------------------
// Minimal DOM stub – just enough to let gmdl-ui.js initialise and run apply()
// without a real browser.
// ---------------------------------------------------------------------------
function makeSandbox(overrides) {
  const styles = {};           // id -> { textContent }
  const classLists = {};       // element key -> Set<string>

  function makeClassList(key) {
    classLists[key] = classLists[key] || new Set();
    const cl = classLists[key];
    return {
      toggle(name, force) {
        if (force === undefined) { cl.has(name) ? cl.delete(name) : cl.add(name); }
        else { force ? cl.add(name) : cl.delete(name); }
      },
      add(name) { cl.add(name); },
      has(name) { return cl.has(name); }
    };
  }

  const htmlEl = {
    classList: makeClassList('html'),
    style: { setProperty() {} }
  };

  function makeStyleEl(id) {
    if (!styles[id]) styles[id] = { id, textContent: '' };
    return styles[id];
  }

  const headEl = {
    appendChild() {},
    querySelector() { return null; }
  };

  const bodyEl = {
    appendChild() {},
    querySelectorAll(sel) { return []; }
  };

  const panelEl = {
    hidden: true,
    firstChild: null,
    appendChild() {},
    removeChild() {},
    querySelectorAll() { return []; },
    querySelector() { return null; }
  };

  const document = {
    readyState: 'complete',
    documentElement: htmlEl,
    getElementById(id) { return styles[id] || null; },
    createElement(tag) {
      if (tag === 'style') return makeStyleEl('__new__' + Math.random());
      // button / div / span / etc.
      return {
        id: '',
        className: '',
        textContent: '',
        title: '',
        hidden: false,
        style: {},
        type: '',
        onclick: null,
        appendChild() {},
        removeChild() {},
        querySelectorAll() { return []; },
        querySelector() { return null; }
      };
    },
    querySelector(sel) {
      if (sel === 'link[href*="gmdl-dark.css"]') return null;
      return null;
    },
    head: headEl,
    body: bodyEl,
    addEventListener() {}
  };

  const localStorage = {
    _store: Object.assign({}, overrides && overrides.localStorage || {}),
    getItem(k) { return Object.prototype.hasOwnProperty.call(this._store, k) ? this._store[k] : null; },
    setItem(k, v) { this._store[k] = v; },
    removeItem(k) { delete this._store[k]; }
  };

  const window = {
    matchMedia(q) {
      // Always simulate dark (prefers-color-scheme: light → false)
      const matches = q === '(prefers-color-scheme: light)' ? false : false;
      return { matches, addEventListener() {}, removeEventListener() {} };
    }
  };

  return {
    sandbox: { document, localStorage, window, console, alert() {} },
    getStyle: (id) => styles[id]
  };
}

// ---------------------------------------------------------------------------
// Helper: run gmdl-ui.js in a sandboxed VM and return the generated CSS text
// for the given settings.
// ---------------------------------------------------------------------------
function runAndGetAccentCss(lsSettings) {
  const src = fs.readFileSync(
    require('node:path').join(__dirname, 'gmdl-ui.js'),
    'utf8'
  );

  const { sandbox, getStyle } = makeSandbox({
    localStorage: {
      'gmdl-ui': JSON.stringify(lsSettings)
    }
  });

  // Patch getElementById so ensureStyle() finds/creates the right element
  const styles = {};
  sandbox.document.getElementById = function (id) {
    if (!styles[id]) {
      styles[id] = { id, textContent: '' };
    }
    return styles[id];
  };

  const ctx = vm.createContext(sandbox);
  vm.runInContext(src, ctx);

  // The style element with id 'gmdl-accent' holds apply()'s output
  return sandbox.document.getElementById('gmdl-accent').textContent;
}

// ---------------------------------------------------------------------------
// RED: test that accent-color rules appear in generated CSS for every accent.
// These selectors MUST appear because they rely on the accent's mid-tone (a.m)
// or shadow/glow values that are only defined in ACCENTS[].
// ---------------------------------------------------------------------------

const EXPECTED_SELECTORS = [
  '.type-option:hover',
  'input[type="text"]:focus',
  '.search-btn',
  '.search-btn:hover',
  '.aplayer .aplayer-lrc p.aplayer-lrc-current',
];

const ACCENT_NAMES = ['green', 'blue', 'purple', 'orange', 'pink', 'cyan'];

for (const accent of ACCENT_NAMES) {
  test(`apply() includes hover/focus/search-btn accent rules for accent="${accent}" in dark mode`, () => {
    const css = runAndGetAccentCss({ theme: 'dark', accent, bg: 'obsidian', style: 'solid' });

    for (const sel of EXPECTED_SELECTORS) {
      assert.ok(
        css.includes(sel),
        `Expected selector "${sel}" to be present in generated CSS for accent="${accent}".\n` +
        `Generated CSS (first 800 chars):\n${css.slice(0, 800)}`
      );
    }
  });
}

// Light mode: accent rules must also appear even when dark=false
test('apply() includes hover/focus/search-btn accent rules in light mode', () => {
  const css = runAndGetAccentCss({ theme: 'light', accent: 'blue', bg: 'obsidian', style: 'solid' });

  for (const sel of EXPECTED_SELECTORS) {
    assert.ok(
      css.includes(sel),
      `Expected selector "${sel}" in light-mode CSS.\n` +
      `Generated CSS:\n${css.slice(0, 800)}`
    );
  }
});

// Accent mid-tone color value must actually appear in the CSS
test('apply() embeds the correct accent hex color in hover rules', () => {
  // green accent mid-tone is #10b981
  const css = runAndGetAccentCss({ theme: 'dark', accent: 'green', bg: 'obsidian', style: 'solid' });
  assert.ok(
    css.includes('#10b981'),
    `Expected accent mid-tone "#10b981" (green) to appear in generated CSS.\n` +
    `Generated CSS (first 800 chars):\n${css.slice(0, 800)}`
  );
});
