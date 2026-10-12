/**
 * Task 4 Enhancement Test Suite (WP-B, WP-C, WP-D)
 *
 * Canonical contract:
 * - docs/project/07-quality-test-plan.md
 * - docs/spec/SPEC.md
 * - docs/spec/modules/gmdl-ui.js.md
 * - docs/spec/modules/gmdl-dark.css.md
 *
 * Uses Node.js built-ins only (node:test, node:assert/strict, node:vm, node:fs, node:path).
 * Drives the real gmdl-ui.js through a deterministic DOM/localStorage harness without
 * test-only production hooks or mocked features.
 */
'use strict';

const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const UI_JS_PATH = path.join(__dirname, 'gmdl-ui.js');
const FEAT_JS_PATH = path.join(__dirname, 'gmdl-feat.js');
const DARK_CSS_PATH = path.join(__dirname, 'gmdl-dark.css');

const UI_SRC = fs.readFileSync(UI_JS_PATH, 'utf8');
const FEAT_SRC = fs.readFileSync(FEAT_JS_PATH, 'utf8');
const DARK_CSS_SRC = fs.readFileSync(DARK_CSS_PATH, 'utf8');

const EXPECTED_EXPORT_NOTICE = '注：仅导出主题与外观偏好，自定义背景图保存在当前设备，不随代码导出。';
const EXPECTED_IMPORT_ERR = '导入失败：配置代码格式不正确或已损坏';

const CANONICAL_SETTINGS_KEYS = [
  'theme', 'accent', 'bg', 'style', 'text', 'lyric', 'glow', 'blur', 'glass'
];

const DEFAULT_VALID_SETTINGS = {
  theme: 'auto',
  accent: 'green',
  bg: 'obsidian',
  style: 'glass',
  text: 'soft',
  lyric: 'm',
  glow: true,
  blur: 10,
  glass: 55
};

// ---------------------------------------------------------------------------
// Deterministic DOM & localStorage Harness
// ---------------------------------------------------------------------------

function createDOMEnvironment(options = {}) {
  const prefersLight = Boolean(options.prefersLight);
  const initialStorage = Object.assign({}, options.localStorage || {});
  const docListeners = {};

  function makeStyleObject() {
    const props = {};
    return new Proxy(props, {
      get(target, prop) {
        if (prop === 'setProperty') {
          return function (k, v) { target[k] = String(v); };
        }
        if (prop === 'getPropertyValue') {
          return function (k) { return Object.prototype.hasOwnProperty.call(target, k) ? target[k] : ''; };
        }
        if (prop === 'removeProperty') {
          return function (k) { delete target[k]; };
        }
        if (prop === '_ dump' || prop === '_dump') {
          return function () { return Object.assign({}, target); };
        }
        return Object.prototype.hasOwnProperty.call(target, prop) ? target[prop] : '';
      },
      set(target, prop, value) {
        target[prop] = String(value);
        return true;
      }
    });
  }

  function createElement(tagName) {
    const tag = String(tagName || 'div').toUpperCase();
    const attrs = {};
    const listeners = {};
    const classSet = new Set();
    const styleObj = makeStyleObject();
    let idVal = '';
    let classVal = '';
    let textVal = '';
    let valueVal = '';
    let hiddenVal = false;
    let typeVal = '';
    let titleVal = '';

    function syncClassFromString(str) {
      classSet.clear();
      String(str || '')
        .split(/\s+/)
        .filter(Boolean)
        .forEach((c) => classSet.add(c));
      classVal = Array.from(classSet).join(' ');
      if (classVal) attrs['class'] = classVal;
      else delete attrs['class'];
    }

    function syncStringFromSet() {
      classVal = Array.from(classSet).join(' ');
      if (classVal) attrs['class'] = classVal;
      else delete attrs['class'];
    }

    const node = {
      tagName: tag,
      parentNode: null,
      children: [],
      style: styleObj,
      onclick: null,
      oninput: null,
      onchange: null,
      min: '',
      max: '',
      step: '',
      accept: '',
      placeholder: '',
      readOnly: false,
      disabled: false,
      tabIndex: 0,

      get id() { return idVal; },
      set id(v) {
        idVal = String(v || '');
        if (idVal) attrs.id = idVal;
        else delete attrs.id;
      },

      get className() { return classVal; },
      set className(v) { syncClassFromString(v); },

      get title() { return titleVal; },
      set title(v) {
        titleVal = String(v || '');
        attrs.title = titleVal;
      },

      get type() { return typeVal; },
      set type(v) {
        typeVal = String(v || '');
        attrs.type = typeVal;
      },

      get value() { return valueVal; },
      set value(v) { valueVal = String(v === undefined || v === null ? '' : v); },

      get hidden() { return hiddenVal; },
      set hidden(v) {
        hiddenVal = Boolean(v);
        if (hiddenVal) attrs.hidden = '';
        else delete attrs.hidden;
      },

      get textContent() {
        if (this.children.length === 0) return textVal;
        return textVal + this.children.map((c) => c.textContent).join('');
      },
      set textContent(v) {
        this.children.forEach((c) => { c.parentNode = null; });
        this.children = [];
        textVal = String(v === undefined || v === null ? '' : v);
      },

      get firstChild() {
        return this.children.length > 0 ? this.children[0] : null;
      },

      classList: {
        add(...names) {
          names.forEach((n) => { if (n) classSet.add(String(n)); });
          syncStringFromSet();
        },
        remove(...names) {
          names.forEach((n) => classSet.delete(String(n)));
          syncStringFromSet();
        },
        toggle(name, force) {
          const n = String(name);
          const shouldAdd = force === undefined ? !classSet.has(n) : Boolean(force);
          if (shouldAdd) classSet.add(n);
          else classSet.delete(n);
          syncStringFromSet();
          return shouldAdd;
        },
        contains(name) {
          return classSet.has(String(name));
        },
        has(name) {
          return classSet.has(String(name));
        },
        toArray() {
          return Array.from(classSet);
        }
      },

      setAttribute(name, value) {
        const k = String(name);
        const v = String(value);
        attrs[k] = v;
        if (k === 'id') idVal = v;
        else if (k === 'class') syncClassFromString(v);
        else if (k === 'title') titleVal = v;
        else if (k === 'type') typeVal = v;
        else if (k === 'hidden') hiddenVal = true;
      },

      getAttribute(name) {
        const k = String(name);
        return Object.prototype.hasOwnProperty.call(attrs, k) ? attrs[k] : null;
      },

      hasAttribute(name) {
        return Object.prototype.hasOwnProperty.call(attrs, String(name));
      },

      removeAttribute(name) {
        const k = String(name);
        delete attrs[k];
        if (k === 'id') idVal = '';
        else if (k === 'class') syncClassFromString('');
        else if (k === 'hidden') hiddenVal = false;
      },

      _getAttributes() {
        return Object.assign({}, attrs);
      },

      appendChild(child) {
        if (!child) return child;
        if (child.parentNode) {
          child.parentNode.removeChild(child);
        }
        child.parentNode = this;
        this.children.push(child);
        return child;
      },

      removeChild(child) {
        const idx = this.children.indexOf(child);
        if (idx >= 0) {
          this.children.splice(idx, 1);
          child.parentNode = null;
        }
        return child;
      },

      addEventListener(type, fn) {
        if (!listeners[type]) listeners[type] = [];
        listeners[type].push(fn);
      },

      removeEventListener(type, fn) {
        if (!listeners[type]) return;
        listeners[type] = listeners[type].filter((f) => f !== fn);
      },

      dispatchEvent(evt) {
        const e = Object.assign({ target: this, currentTarget: this, preventDefault() {}, stopPropagation() {} }, evt);
        const handlerProp = 'on' + e.type;
        if (typeof this[handlerProp] === 'function') {
          this[handlerProp].call(this, e);
        }
        if (listeners[e.type]) {
          listeners[e.type].slice().forEach((fn) => fn.call(this, e));
        }
        return true;
      },

      click() {
        this.dispatchEvent({ type: 'click' });
      },

      focus() {
        document.activeElement = this;
      },

      select() {},

      querySelectorAll(selector) {
        return queryAllUnder(this, selector);
      },

      querySelector(selector) {
        const all = queryAllUnder(this, selector);
        return all.length > 0 ? all[0] : null;
      }
    };

    return node;
  }

  function matchesSingleSelector(el, sel) {
    const s = sel.trim();
    if (!s) return false;

    if (s === 'link[href*="gmdl-dark.css"]') {
      return el.tagName === 'LINK' && String(el.getAttribute('href') || el.href || '').includes('gmdl-dark.css');
    }

    // Handle tag[attr="val"] or [attr="val"]
    const attrMatch = s.match(/^([a-zA-Z0-9_-]+)?\[([a-zA-Z0-9_-]+)(?:="([^"]*)")?\]$/);
    if (attrMatch) {
      const [, tagPart, attrName, attrVal] = attrMatch;
      if (tagPart && el.tagName !== tagPart.toUpperCase()) return false;
      const actual = attrName === 'type' ? (el.type || el.getAttribute('type')) : el.getAttribute(attrName);
      if (attrVal === undefined) return actual !== null && actual !== undefined && actual !== '';
      return String(actual || '') === attrVal;
    }

    if (s.startsWith('#')) {
      return el.id === s.slice(1);
    }

    if (s.startsWith('.')) {
      const classes = s.slice(1).split('.');
      return classes.every((c) => el.classList.contains(c));
    }

    return el.tagName === s.toUpperCase();
  }

  function matchesSelector(el, selectorGroup) {
    return String(selectorGroup)
      .split(',')
      .some((part) => matchesSingleSelector(el, part));
  }

  function queryAllUnder(root, selector) {
    const results = [];
    function walk(n) {
      for (const child of n.children) {
        if (matchesSelector(child, selector)) {
          results.push(child);
        }
        walk(child);
      }
    }
    walk(root);
    return results;
  }

  const htmlEl = createElement('html');
  const headEl = createElement('head');
  const bodyEl = createElement('body');
  htmlEl.appendChild(headEl);
  htmlEl.appendChild(bodyEl);

  const linkEl = createElement('link');
  linkEl.href = '/gmdl-dark.css?v=20260416d';
  linkEl.setAttribute('href', '/gmdl-dark.css?v=20260416d');
  headEl.appendChild(linkEl);

  const document = {
    readyState: 'complete',
    documentElement: htmlEl,
    head: headEl,
    body: bodyEl,
    activeElement: bodyEl,

    createElement(tag) {
      return createElement(tag);
    },

    getElementById(id) {
      const target = String(id);
      let found = null;
      function search(n) {
        if (n.id === target) {
          found = n;
          return;
        }
        for (const c of n.children) {
          if (found) return;
          search(c);
        }
      }
      search(htmlEl);
      return found;
    },

    querySelectorAll(sel) {
      return queryAllUnder(htmlEl, sel);
    },

    querySelector(sel) {
      const res = queryAllUnder(htmlEl, sel);
      return res.length > 0 ? res[0] : null;
    },

    addEventListener(type, fn) {
      if (!docListeners[type]) docListeners[type] = [];
      docListeners[type].push(fn);
    },

    removeEventListener(type, fn) {
      if (!docListeners[type]) return;
      docListeners[type] = docListeners[type].filter((f) => f !== fn);
    },

    dispatchEvent(evt) {
      const e = Object.assign({ target: document, currentTarget: document, preventDefault() {}, stopPropagation() {} }, evt);
      if (docListeners[e.type]) {
        docListeners[e.type].slice().forEach((fn) => fn.call(document, e));
      }
      return true;
    }
  };

  const localStorage = {
    _store: Object.assign({}, initialStorage),
    getItem(k) {
      return Object.prototype.hasOwnProperty.call(this._store, k) ? this._store[k] : null;
    },
    setItem(k, v) {
      this._store[k] = String(v);
    },
    removeItem(k) {
      delete this._store[k];
    },
    _snapshot() {
      return Object.assign({}, this._store);
    }
  };

  const windowObj = {
    document,
    localStorage,
    matchMedia(q) {
      const matches = q === '(prefers-color-scheme: light)' ? prefersLight : false;
      return { matches, addEventListener() {}, removeEventListener() {} };
    }
  };

  let jsonParseCalls = 0;
  const realJsonParse = JSON.parse;
  const instrumentedJSON = {
    parse(text, reviver) {
      jsonParseCalls += 1;
      return realJsonParse(text, reviver);
    },
    stringify: JSON.stringify
  };

  const sandbox = {
    window: windowObj,
    document,
    localStorage,
    JSON: instrumentedJSON,
    console,
    alert() {},
    Math,
    Object,
    Array,
    String,
    Number,
    Boolean,
    RegExp,
    Error,
    TypeError,
    SyntaxError,
    parseInt,
    parseFloat,
    isNaN,
    isFinite
  };

  const ctx = vm.createContext(sandbox);
  vm.runInContext(UI_SRC, ctx);

  return {
    sandbox,
    document,
    localStorage,
    window: windowObj,
    getJsonParseCalls() { return jsonParseCalls; },
    resetJsonParseCalls() { jsonParseCalls = 0; }
  };
}

function serializeDOMNode(node, excludeId) {
  if (!node || (excludeId && node.id === excludeId)) {
    return null;
  }
  return {
    tag: node.tagName,
    id: node.id,
    className: node.className,
    attrs: node._getAttributes(),
    style: node.style._dump(),
    value: node.value,
    hidden: node.hidden,
    text: node.children.length === 0 ? node.textContent : '',
    children: node.children
      .map((c) => serializeDOMNode(c, excludeId))
      .filter((x) => x !== null)
  };
}

function captureStateSnapshot(env) {
  const panel = env.document.getElementById('gmdl-ui-panel');
  const accentStyle = env.document.getElementById('gmdl-accent');
  return {
    localStorage: env.localStorage._snapshot(),
    htmlClasses: env.document.documentElement.classList.toArray().slice().sort(),
    htmlStyle: env.document.documentElement.style._dump(),
    accentCss: accentStyle ? accentStyle.textContent : '',
    activeElementId: env.document.activeElement ? env.document.activeElement.id : '',
    activeElementTag: env.document.activeElement ? env.document.activeElement.tagName : '',
    panelTreeExcludingStatus: serializeDOMNode(panel, 'gmdl-import-status')
  };
}

function openPanel(env) {
  const btn = env.document.getElementById('gmdl-ui-btn');
  const panel = env.document.getElementById('gmdl-ui-panel');
  assert.ok(btn, 'Launcher #gmdl-ui-btn must exist');
  assert.ok(panel, 'Panel #gmdl-ui-panel must exist');
  if (panel.hidden) {
    btn.click();
  }
  assert.equal(panel.hidden, false, 'Panel should be open after clicking #gmdl-ui-btn');
  return { btn, panel };
}

function getExportCodeFromUI(env) {
  openPanel(env);
  const exportBtn = env.document.getElementById('gmdl-export-btn');
  if (exportBtn) {
    exportBtn.click();
  }
  const exportInput = env.document.getElementById('gmdl-export-code');
  assert.ok(
    exportInput,
    'Expected #gmdl-export-code element to be rendered in #gmdl-ui-panel for preference export'
  );
  const code = exportInput.value || exportInput.textContent || '';
  assert.ok(code.length > 0, 'Expected non-empty preference export string in #gmdl-export-code');
  return code;
}

function triggerImportInUI(env, candidateCode) {
  openPanel(env);
  const importInput = env.document.getElementById('gmdl-import-code');
  const importBtn = env.document.getElementById('gmdl-import-btn');
  const statusNode = env.document.getElementById('gmdl-import-status');

  assert.ok(importInput, 'Expected #gmdl-import-code input in #gmdl-ui-panel');
  assert.ok(importBtn, 'Expected #gmdl-import-btn button in #gmdl-ui-panel');
  assert.ok(statusNode, 'Expected #gmdl-import-status status node in #gmdl-ui-panel');

  importInput.value = candidateCode;
  const beforeSnapshot = captureStateSnapshot(env);

  env.resetJsonParseCalls();
  importBtn.click();

  const afterSnapshot = captureStateSnapshot(env);
  return {
    importInput,
    importBtn,
    statusNode,
    beforeSnapshot,
    afterSnapshot,
    parseCalls: env.getJsonParseCalls()
  };
}

function buildCanonicalPayload(overrides = {}) {
  const s = Object.assign({}, DEFAULT_VALID_SETTINGS, overrides);
  const orderedSettings = {};
  for (const k of CANONICAL_SETTINGS_KEYS) {
    if (Object.prototype.hasOwnProperty.call(s, k) && s[k] !== undefined) {
      orderedSettings[k] = s[k];
    }
  }
  return 'GMDL1:' + JSON.stringify({ v: 1, settings: orderedSettings });
}

// ===========================================================================
// 1. WP-D: Strict Preference Export / Import Tests (PREF-01..13 & SEC-EVAL-01)
// ===========================================================================

test('PREF-01: Deterministic Export Serialization Order (GMDL1: prefix, compact JSON, exact envelope & 9 settings keys)', () => {
  const env = createDOMEnvironment({
    localStorage: {
      'gmdl-ui': JSON.stringify(DEFAULT_VALID_SETTINGS)
    }
  });

  const code = getExportCodeFromUI(env);
  assert.ok(code.startsWith('GMDL1:'), `Export must start with "GMDL1:", got: ${code}`);

  const exportInput = env.document.getElementById('gmdl-export-code');
  assert.equal(exportInput.readOnly, true, '#gmdl-export-code must be read-only while remaining selectable/copyable');

  const jsonPart = code.slice('GMDL1:'.length);
  const expectedCompact = JSON.stringify({
    v: 1,
    settings: {
      theme: 'auto',
      accent: 'green',
      bg: 'obsidian',
      style: 'glass',
      text: 'soft',
      lyric: 'm',
      glow: true,
      blur: 10,
      glass: 55
    }
  });
  assert.equal(jsonPart, expectedCompact, 'Exported JSON must match exact compact key serialization order');

  const parsed = JSON.parse(jsonPart);
  assert.deepEqual(Object.keys(parsed), ['v', 'settings'], 'Envelope keys must be strictly ["v", "settings"]');
  assert.deepEqual(
    Object.keys(parsed.settings),
    CANONICAL_SETTINGS_KEYS,
    'Settings keys must be in exact canonical 9-key order'
  );
});

test('PREF-02: Background Image Exclusion Notice (gmdl-bgimg excluded from code; visible notice in DOM)', () => {
  const fakeDataUrl = 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD/';
  const env = createDOMEnvironment({
    localStorage: {
      'gmdl-ui': JSON.stringify(DEFAULT_VALID_SETTINGS),
      'gmdl-bgimg': fakeDataUrl
    }
  });

  const { panel } = openPanel(env);
  const code = getExportCodeFromUI(env);

  assert.ok(!code.includes('gmdl-bgimg'), 'Exported code must not include gmdl-bgimg key');
  assert.ok(!code.includes(fakeDataUrl), 'Exported code must not include background image data URL');
  assert.ok(
    panel.textContent.includes(EXPECTED_EXPORT_NOTICE),
    `Panel DOM must include visible disclaimer notice: "${EXPECTED_EXPORT_NOTICE}"`
  );
});

test('PREF-03: Valid Code Import & Instant Application without reload', () => {
  const env = createDOMEnvironment({
    localStorage: {
      'gmdl-ui': JSON.stringify(DEFAULT_VALID_SETTINGS)
    }
  });

  const targetSettings = {
    theme: 'dark',
    accent: 'purple',
    bg: 'grape',
    style: 'glass',
    text: 'bright',
    lyric: 'big',
    glow: false,
    blur: 18,
    glass: 80
  };
  const validPayload = buildCanonicalPayload(targetSettings);
  const { statusNode } = triggerImportInUI(env, validPayload);

  const stored = JSON.parse(env.localStorage.getItem('gmdl-ui'));
  assert.deepEqual(stored, targetSettings, 'localStorage["gmdl-ui"] must be updated with all 9 imported settings');
  assert.equal(env.document.documentElement.classList.contains('dark'), true, '<html> must have .dark class');
  assert.equal(env.document.documentElement.classList.contains('glass'), true, '<html> must have .glass class');
  assert.equal(env.document.documentElement.classList.contains('lyr-big'), true, '<html> must have .lyr-big class');
  assert.equal(env.document.documentElement.classList.contains('lyr-glow'), false, '<html> must not have .lyr-glow when glow=false');

  const expectedGlassA = (0.015 + (80 / 100) * 0.145).toFixed(3);
  assert.equal(env.document.documentElement.style.getPropertyValue('--glass-a'), expectedGlassA);
  assert.equal(env.document.documentElement.style.getPropertyValue('--glass-b'), Math.round((80 / 100) * 28) + 'px');

  const accentCss = env.document.getElementById('gmdl-accent').textContent;
  assert.ok(accentCss.includes('#8b5cf6'), 'Generated CSS must reflect purple accent #8b5cf6');
  assert.ok(
    statusNode.textContent && !statusNode.textContent.includes('失败'),
    'Status node should confirm successful import'
  );
});

test('PREF-04: Duplicate Key Rejection — Settings Level', () => {
  const env = createDOMEnvironment({
    localStorage: { 'gmdl-ui': JSON.stringify(DEFAULT_VALID_SETTINGS) }
  });

  const dupSettingsPayload =
    'GMDL1:{"v":1,"settings":{"theme":"dark","theme":"light","accent":"green","bg":"obsidian","style":"glass","text":"soft","lyric":"m","glow":true,"blur":10,"glass":55}}';

  const { statusNode, beforeSnapshot, afterSnapshot } = triggerImportInUI(env, dupSettingsPayload);
  assert.equal(statusNode.textContent, EXPECTED_IMPORT_ERR);
  assert.deepEqual(afterSnapshot, beforeSnapshot, 'Rejected duplicate settings key must leave state 100% unchanged');
});

test('PREF-05: Duplicate Key Rejection — Envelope Level (repeated "v" and repeated "settings")', () => {
  const env = createDOMEnvironment({
    localStorage: { 'gmdl-ui': JSON.stringify(DEFAULT_VALID_SETTINGS) }
  });

  const validSettingsJson = JSON.stringify(DEFAULT_VALID_SETTINGS);
  const dupVPayload = `GMDL1:{"v":1,"v":2,"settings":${validSettingsJson}}`;
  const dupSettingsObjPayload = `GMDL1:{"v":1,"settings":${validSettingsJson},"settings":${validSettingsJson}}`;

  for (const payload of [dupVPayload, dupSettingsObjPayload]) {
    const { statusNode, beforeSnapshot, afterSnapshot } = triggerImportInUI(env, payload);
    assert.equal(statusNode.textContent, EXPECTED_IMPORT_ERR);
    assert.deepEqual(afterSnapshot, beforeSnapshot, 'Rejected duplicate envelope key must leave state 100% unchanged');
  }
});

test('PREF-06: Decoded JSON Escape Duplicate Rejection at Both Envelope and Settings Levels', () => {
  const env = createDOMEnvironment({
    localStorage: { 'gmdl-ui': JSON.stringify(DEFAULT_VALID_SETTINGS) }
  });

  const validSettingsJson = JSON.stringify(DEFAULT_VALID_SETTINGS);
  const escapedPayloads = [
    // Settings level: "theme" and "\u0074heme"
    'GMDL1:{"v":1,"settings":{"theme":"dark","\\u0074heme":"light","accent":"green","bg":"obsidian","style":"glass","text":"soft","lyric":"m","glow":true,"blur":10,"glass":55}}',
    // Envelope level: "v" and "\u0076"
    `GMDL1:{"v":1,"\\u0076":1,"settings":${validSettingsJson}}`,
    // Envelope level: "settings" and "\u0073ettings"
    `GMDL1:{"v":1,"settings":${validSettingsJson},"\\u0073ettings":${validSettingsJson}}`
  ];

  for (const payload of escapedPayloads) {
    const { statusNode, beforeSnapshot, afterSnapshot } = triggerImportInUI(env, payload);
    assert.equal(
      statusNode.textContent,
      EXPECTED_IMPORT_ERR,
      `Escaped duplicate payload must be rejected fail-closed: ${payload}`
    );
    assert.deepEqual(afterSnapshot, beforeSnapshot, 'Escaped duplicate rejection must preserve 100% state invariance');
  }
});

test('PREF-07: Missing Required Keys Rejection (each of the 9 settings keys plus envelope v and settings)', () => {
  const env = createDOMEnvironment({
    localStorage: { 'gmdl-ui': JSON.stringify(DEFAULT_VALID_SETTINGS) }
  });

  for (const keyToOmit of CANONICAL_SETTINGS_KEYS) {
    const partial = Object.assign({}, DEFAULT_VALID_SETTINGS);
    delete partial[keyToOmit];
    const payload = 'GMDL1:' + JSON.stringify({ v: 1, settings: partial });
    const { statusNode, beforeSnapshot, afterSnapshot } = triggerImportInUI(env, payload);
    assert.equal(
      statusNode.textContent,
      EXPECTED_IMPORT_ERR,
      `Missing settings key "${keyToOmit}" must be rejected fail-closed`
    );
    assert.deepEqual(afterSnapshot, beforeSnapshot);
  }

  const missingV = 'GMDL1:' + JSON.stringify({ settings: DEFAULT_VALID_SETTINGS });
  const missingSettings = 'GMDL1:' + JSON.stringify({ v: 1 });
  for (const envPayload of [missingV, missingSettings]) {
    const { statusNode, beforeSnapshot, afterSnapshot } = triggerImportInUI(env, envPayload);
    assert.equal(statusNode.textContent, EXPECTED_IMPORT_ERR);
    assert.deepEqual(afterSnapshot, beforeSnapshot);
  }
});

test('PREF-08: Unknown / Prototype Keys & Invalid Envelope Rejection', () => {
  const env = createDOMEnvironment({
    localStorage: { 'gmdl-ui': JSON.stringify(DEFAULT_VALID_SETTINGS) }
  });

  const validSettingsJson = JSON.stringify(DEFAULT_VALID_SETTINGS);
  const invalidPayloads = [
    // Extra key in settings
    'GMDL1:' + JSON.stringify({ v: 1, settings: Object.assign({}, DEFAULT_VALID_SETTINGS, { extra: 'val' }) }),
    // Extra key in envelope
    `GMDL1:{"v":1,"settings":${validSettingsJson},"extra":true}`,
    // __proto__, constructor, prototype in settings
    `GMDL1:{"v":1,"settings":{"theme":"auto","accent":"green","bg":"obsidian","style":"glass","text":"soft","lyric":"m","glow":true,"blur":10,"glass":55,"__proto__":{"polluted":true}}}`,
    `GMDL1:{"v":1,"settings":{"theme":"auto","accent":"green","bg":"obsidian","style":"glass","text":"soft","lyric":"m","glow":true,"blur":10,"glass":55,"constructor":{}}}`,
    `GMDL1:{"v":1,"settings":{"theme":"auto","accent":"green","bg":"obsidian","style":"glass","text":"soft","lyric":"m","glow":true,"blur":10,"glass":55,"prototype":{}}}`,
    // __proto__ at envelope level
    `GMDL1:{"v":1,"settings":${validSettingsJson},"__proto__":{"polluted":true}}`,
    `GMDL1:{"v":1,"settings":${validSettingsJson},"constructor":{}}`,
    `GMDL1:{"v":1,"settings":${validSettingsJson},"prototype":{}}`,
    // Invalid envelope v
    `GMDL1:{"v":2,"settings":${validSettingsJson}}`,
    `GMDL1:{"v":0,"settings":${validSettingsJson}}`,
    `GMDL1:{"v":"1","settings":${validSettingsJson}}`,
    // Non-object settings
    'GMDL1:{"v":1,"settings":[]}',
    'GMDL1:{"v":1,"settings":null}',
    'GMDL1:{"v":1,"settings":"invalid"}',
    // Non-object envelope
    'GMDL1:[]',
    'GMDL1:null',
    'GMDL1:"invalid"',
    'GMDL1:1'
  ];

  for (const payload of invalidPayloads) {
    const { statusNode, beforeSnapshot, afterSnapshot } = triggerImportInUI(env, payload);
    assert.equal(statusNode.textContent, EXPECTED_IMPORT_ERR, `Must reject invalid/prototype payload: ${payload}`);
    assert.equal(({}).polluted, undefined, 'Object.prototype must never be polluted');
    assert.deepEqual(afterSnapshot, beforeSnapshot);
  }
});

test('PREF-09: Complete Data-Driven Schema / Type / Range Matrix (§4.1.1)', () => {
  const env = createDOMEnvironment({
    localStorage: { 'gmdl-ui': JSON.stringify(DEFAULT_VALID_SETTINGS) }
  });

  // 1. All valid enum values, boolean values, and inclusive numeric endpoints must be accepted
  const validMatrix = [
    { field: 'theme', values: ['dark', 'light', 'auto'] },
    { field: 'accent', values: ['green', 'blue', 'purple', 'orange', 'pink', 'cyan'] },
    { field: 'bg', values: ['obsidian', 'midnight', 'grape', 'amoled'] },
    { field: 'style', values: ['solid', 'glass'] },
    { field: 'text', values: ['bright', 'soft', 'warm'] },
    { field: 'lyric', values: ['s', 'm', 'big'] },
    { field: 'glow', values: [true, false] },
    { field: 'blur', values: [0, 12, 24] },
    { field: 'glass', values: [0, 55, 100] }
  ];

  for (const { field, values } of validMatrix) {
    for (const val of values) {
      const payload = buildCanonicalPayload({ [field]: val });
      triggerImportInUI(env, payload);
      const saved = JSON.parse(env.localStorage.getItem('gmdl-ui'));
      assert.equal(
        saved[field],
        val,
        `Valid schema value ${field}=${JSON.stringify(val)} must be accepted and persisted`
      );
    }
  }

  // 2. Disallowed enum values, non-booleans, out-of-range/fractional numbers, wrong types must be rejected
  const invalidMatrix = [
    { field: 'theme', badValues: ['sepia', 'DARK', '', null, 1, true, [], {}] },
    { field: 'accent', badValues: ['red', 'yellow', '', null, 123, false] },
    { field: 'bg', badValues: ['forest', 'white', '', null, 0] },
    { field: 'style', badValues: ['flat', 'aero', '', null, true] },
    { field: 'text', badValues: ['high', 'dim', '', null, 1] },
    { field: 'lyric', badValues: ['xs', 'l', 'xl', '', null, 2] },
    { field: 'glow', badValues: ['true', 'false', 1, 0, null, [], {}] },
    { field: 'blur', badValues: [-1, 25, 10.5, 0.1, 23.99, '10', null, true, false, [], {}] },
    { field: 'glass', badValues: [-1, 101, 55.5, 0.5, 99.9, '55', null, true, false, [], {}] }
  ];

  for (const { field, badValues } of invalidMatrix) {
    for (const badVal of badValues) {
      const payload = buildCanonicalPayload({ [field]: badVal });
      const { statusNode, beforeSnapshot, afterSnapshot } = triggerImportInUI(env, payload);
      assert.equal(
        statusNode.textContent,
        EXPECTED_IMPORT_ERR,
        `Invalid schema value ${field}=${JSON.stringify(badVal)} must be rejected fail-closed`
      );
      assert.deepEqual(
        afterSnapshot,
        beforeSnapshot,
        `State invariance violated on rejected ${field}=${JSON.stringify(badVal)}`
      );
    }
  }
});

test('PREF-10: Malformed Prefix & Non-JSON Rejection (raw JSON, Base64, wrong prefix, corrupted JSON)', () => {
  const env = createDOMEnvironment({
    localStorage: { 'gmdl-ui': JSON.stringify(DEFAULT_VALID_SETTINGS) }
  });

  const rawJson = JSON.stringify({ v: 1, settings: DEFAULT_VALID_SETTINGS });
  const base64Payload = Buffer.from(rawJson, 'utf8').toString('base64');

  const malformedPayloads = [
    rawJson,
    'Base64:' + base64Payload,
    'GMDL1:' + base64Payload,
    'GMDL2:' + rawJson,
    'gmdl1:' + rawJson,
    'GMDL1:{"v":1,"settings":',
    'GMDL1:not-json-at-all',
    ''
  ];

  for (const payload of malformedPayloads) {
    const { statusNode, beforeSnapshot, afterSnapshot } = triggerImportInUI(env, payload);
    assert.equal(statusNode.textContent, EXPECTED_IMPORT_ERR, `Must reject malformed payload: ${payload.slice(0, 40)}`);
    assert.deepEqual(afterSnapshot, beforeSnapshot);
  }
});

test('PREF-11: Input Length Boundary (1025-character payload rejected at size guard with zero JSON.parse calls)', () => {
  const env = createDOMEnvironment({
    localStorage: { 'gmdl-ui': JSON.stringify(DEFAULT_VALID_SETTINGS) }
  });

  const basePayload = buildCanonicalPayload();
  assert.ok(basePayload.length <= 1024, 'Canonical payload must be <= 1024 chars');

  const padLen = 1025 - basePayload.length;
  const oversizedPayload = basePayload + ' '.repeat(padLen);
  assert.equal(oversizedPayload.length, 1025, 'Constructed test payload must be exactly 1025 characters');

  const { statusNode, beforeSnapshot, afterSnapshot, parseCalls } = triggerImportInUI(env, oversizedPayload);
  assert.equal(statusNode.textContent, EXPECTED_IMPORT_ERR, '1025-char payload must be rejected');
  assert.equal(parseCalls, 0, '1025-char payload must be rejected before JSON.parse is called');
  assert.deepEqual(afterSnapshot, beforeSnapshot);
});

test('PREF-12: Side-Effect-Free Snapshot Invariance on Rejected Import across all invalid payload classes', () => {
  const initialCustomState = {
    theme: 'dark',
    accent: 'cyan',
    bg: 'midnight',
    style: 'glass',
    text: 'warm',
    lyric: 's',
    glow: true,
    blur: 14,
    glass: 70
  };
  const env = createDOMEnvironment({
    localStorage: {
      'gmdl-ui': JSON.stringify(initialCustomState),
      'gmdl-bgimg': 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUg=='
    }
  });

  const validJson = JSON.stringify(DEFAULT_VALID_SETTINGS);
  const baseCanonical = buildCanonicalPayload();
  const representativeInvalidPayloads = [
    // Duplicate settings key
    'GMDL1:{"v":1,"settings":{"theme":"dark","theme":"light","accent":"green","bg":"obsidian","style":"glass","text":"soft","lyric":"m","glow":true,"blur":10,"glass":55}}',
    // Duplicate envelope key
    `GMDL1:{"v":1,"v":1,"settings":${validJson}}`,
    // Escaped duplicate settings key
    'GMDL1:{"v":1,"settings":{"theme":"dark","\\u0074heme":"light","accent":"green","bg":"obsidian","style":"glass","text":"soft","lyric":"m","glow":true,"blur":10,"glass":55}}',
    // Escaped duplicate envelope key
    `GMDL1:{"v":1,"\\u0076":1,"settings":${validJson}}`,
    // Missing key
    'GMDL1:{"v":1,"settings":{"theme":"dark","accent":"green","bg":"obsidian","style":"glass","text":"soft","lyric":"m","glow":true,"blur":10}}',
    // Extra / prototype key
    `GMDL1:{"v":1,"settings":${validJson},"extra":1}`,
    // Invalid enum / boolean / range / fraction
    buildCanonicalPayload({ theme: 'invalid' }),
    buildCanonicalPayload({ glow: 'true' }),
    buildCanonicalPayload({ blur: 25 }),
    buildCanonicalPayload({ blur: 10.5 }),
    buildCanonicalPayload({ glass: 101 }),
    buildCanonicalPayload({ glass: 55.5 }),
    // Malformed prefix / Base64 / broken JSON / 1025-char oversized
    validJson,
    'Base64:' + Buffer.from(validJson).toString('base64'),
    'GMDL1:{broken',
    baseCanonical + ' '.repeat(1025 - baseCanonical.length)
  ];

  for (const badPayload of representativeInvalidPayloads) {
    const { statusNode, beforeSnapshot, afterSnapshot } = triggerImportInUI(env, badPayload);
    assert.equal(statusNode.getAttribute('role'), 'status', '#gmdl-import-status must have role="status"');
    assert.equal(statusNode.getAttribute('aria-live'), 'polite', '#gmdl-import-status must have aria-live="polite"');
    assert.equal(statusNode.textContent, EXPECTED_IMPORT_ERR, '#gmdl-import-status must contain exact error text');
    assert.deepEqual(
      afterSnapshot,
      beforeSnapshot,
      `All localStorage keys, html classes/styles, focus, and settings DOM (excluding #gmdl-import-status) must remain 100% identical for invalid payload: ${badPayload.slice(0, 50)}`
    );
  }
});

test('PREF-13: Round-Trip Configuration Fidelity (importCode(exportCode()) preserves 100% fidelity across all 9 settings)', () => {
  const customSettings = {
    theme: 'light',
    accent: 'orange',
    bg: 'amoled',
    style: 'glass',
    text: 'bright',
    lyric: 'big',
    glow: false,
    blur: 22,
    glass: 35
  };

  const sourceEnv = createDOMEnvironment({
    localStorage: { 'gmdl-ui': JSON.stringify(customSettings) }
  });
  const exportedCode = getExportCodeFromUI(sourceEnv);

  const targetEnv = createDOMEnvironment({
    localStorage: { 'gmdl-ui': JSON.stringify(DEFAULT_VALID_SETTINGS) }
  });
  triggerImportInUI(targetEnv, exportedCode);

  const restoredSettings = JSON.parse(targetEnv.localStorage.getItem('gmdl-ui'));
  assert.deepEqual(
    restoredSettings,
    customSettings,
    'Round-trip export -> import must preserve all 9 settings identically'
  );
  assert.equal(getExportCodeFromUI(targetEnv), exportedCode, 'Re-exporting after import must yield identical GMDL1 string');
});

test('SEC-EVAL-01: Static Security Prohibition of eval(), Function(), and unsafe dynamic execution (AC-D06)', () => {
  function stripCommentsAndStrings(js) {
    return js
      .replace(/\/\*[\s\S]*?\*\//g, ' ')
      .replace(/\/\/.*$/gm, ' ')
      .replace(/'(?:\\.|[^'\\])*'/g, "''")
      .replace(/"(?:\\.|[^"\\])*"/g, '""');
  }

  for (const [name, src] of [['gmdl-ui.js', UI_SRC], ['gmdl-feat.js', FEAT_SRC]]) {
    const cleaned = stripCommentsAndStrings(src);
    assert.equal(/\beval\s*\(/.test(cleaned), false, `${name} must not invoke eval()`);
    assert.equal(/\bnew\s+Function\s*\(/.test(cleaned), false, `${name} must not invoke new Function()`);
    assert.equal(/\bFunction\s*\(/.test(cleaned), false, `${name} must not invoke Function()`);
    assert.equal(/\bsetTimeout\s*\(\s*['"]/.test(src), false, `${name} must not pass strings to setTimeout`);
    assert.equal(/\bsetInterval\s*\(\s*['"]/.test(src), false, `${name} must not pass strings to setInterval`);
  }
});

// ===========================================================================
// 2. WP-B: Shared Glass Styling & Reproducible Contrast Tests (GLASS-01..04, GLASS-CONTRAST)
// ===========================================================================

test('GLASS-01: Dual-Mode Glass Activation in both dark mode (html.dark.glass) and light mode (html.glass:not(.dark))', () => {
  // Dark mode + glass
  const darkEnv = createDOMEnvironment({
    localStorage: {
      'gmdl-ui': JSON.stringify(Object.assign({}, DEFAULT_VALID_SETTINGS, { theme: 'dark', style: 'glass' }))
    }
  });
  assert.equal(darkEnv.document.documentElement.classList.contains('dark'), true);
  assert.equal(darkEnv.document.documentElement.classList.contains('glass'), true);

  // Light mode + glass
  const lightEnv = createDOMEnvironment({
    prefersLight: true,
    localStorage: {
      'gmdl-ui': JSON.stringify(Object.assign({}, DEFAULT_VALID_SETTINGS, { theme: 'light', style: 'glass' }))
    }
  });
  assert.equal(lightEnv.document.documentElement.classList.contains('dark'), false, 'Light mode must not have .dark on <html>');
  assert.equal(
    lightEnv.document.documentElement.classList.contains('glass'),
    true,
    'Light mode with style="glass" must add .glass class to <html>'
  );

  // Verify gmdl-dark.css defines light-mode glass rules under html.glass:not(.dark)
  assert.ok(
    DARK_CSS_SRC.includes('html.glass:not(.dark)'),
    'gmdl-dark.css must contain html.glass:not(.dark) light-mode glass surface selectors'
  );
  assert.ok(
    DARK_CSS_SRC.includes('calc(var(--glass-a, 0.55) * 0.65 + 0.30)') ||
      DARK_CSS_SRC.includes('calc(var(--glass-a,0.55)*0.65 + 0.30)') ||
      DARK_CSS_SRC.includes('calc(var(--glass-a, 0.55)*0.65 + 0.30)'),
    'gmdl-dark.css must define light-mode glass gradient stop 1 formula (0.30 + 0.65 * --glass-a)'
  );
  assert.ok(
    DARK_CSS_SRC.includes('calc(var(--glass-a, 0.55) * 0.40 + 0.20)') ||
      DARK_CSS_SRC.includes('calc(var(--glass-a,0.55)*0.40 + 0.20)') ||
      DARK_CSS_SRC.includes('calc(var(--glass-a, 0.55)*0.40 + 0.20)'),
    'gmdl-dark.css must define light-mode glass gradient stop 2 formula (0.20 + 0.40 * --glass-a)'
  );
});

test('GLASS-02: Dark Mode Visual Preservation (html.dark.glass surface rules and text tokens preserved)', () => {
  const env = createDOMEnvironment({
    localStorage: {
      'gmdl-ui': JSON.stringify(Object.assign({}, DEFAULT_VALID_SETTINGS, { theme: 'dark', style: 'glass', text: 'soft' }))
    }
  });

  const accentCss = env.document.getElementById('gmdl-accent').textContent;
  assert.ok(accentCss.includes('--text-main:#e6edf3;'), 'Dark mode must preserve --text-main token');
  assert.ok(accentCss.includes('--text-sub:#9aa7b8;'), 'Dark mode must preserve --text-sub token');
  assert.ok(
    DARK_CSS_SRC.includes('rgba(255,255,255,var(--glass-a,0.09))') ||
      DARK_CSS_SRC.includes('rgba(255, 255, 255, var(--glass-a, 0.09))'),
    'gmdl-dark.css must preserve dark glass gradient formula'
  );
});

test('GLASS-03: Slider Real-Time Responsiveness updates --glass-a and --glass-b in both modes', () => {
  for (const theme of ['dark', 'light']) {
    const env = createDOMEnvironment({
      prefersLight: theme === 'light',
      localStorage: {
        'gmdl-ui': JSON.stringify(Object.assign({}, DEFAULT_VALID_SETTINGS, { theme, style: 'glass' }))
      }
    });

    const { panel } = openPanel(env);
    const sliders = panel.querySelectorAll('input[type="range"]');
    assert.ok(sliders.length >= 2, 'Expected blur and glass range sliders in #gmdl-ui-panel');

    const blurSlider = sliders.find((s) => s.max === '24');
    const glassSlider = sliders.find((s) => s.max === '100');
    assert.ok(blurSlider, 'Blur slider (max=24) must exist');
    assert.ok(glassSlider, 'Glass slider (max=100) must exist');

    for (const glassVal of [0, 55, 100]) {
      const currentSliders = panel.querySelectorAll('input[type="range"]');
      const activeGlassSlider = currentSliders.find((s) => s.max === '100');
      activeGlassSlider.value = String(glassVal);
      activeGlassSlider.dispatchEvent({ type: 'input' });

      const expectedA = (0.015 + (glassVal / 100) * 0.145).toFixed(3);
      const expectedB = Math.round((glassVal / 100) * 28) + 'px';
      assert.equal(
        env.document.documentElement.style.getPropertyValue('--glass-a'),
        expectedA,
        `--glass-a must update to ${expectedA} for glass=${glassVal} in ${theme} mode`
      );
      assert.equal(
        env.document.documentElement.style.getPropertyValue('--glass-b'),
        expectedB,
        `--glass-b must update to ${expectedB} for glass=${glassVal} in ${theme} mode`
      );
    }

    const activeBlurSlider = panel.querySelectorAll('input[type="range"]').find((s) => s.max === '24');
    activeBlurSlider.value = '20';
    activeBlurSlider.dispatchEvent({ type: 'input' });
    const stored = JSON.parse(env.localStorage.getItem('gmdl-ui'));
    assert.equal(stored.blur, 20, `Blur slider update must persist blur=20 in ${theme} mode`);
  }
});

test('GLASS-04: Accent Color Swatches apply correctly in both dark glass and light glass modes', () => {
  const expectedHex = {
    green: '#10b981',
    blue: '#3b82f6',
    purple: '#8b5cf6',
    orange: '#f97316',
    pink: '#ec4899',
    cyan: '#06b6d4'
  };
  const accentKeys = Object.keys(expectedHex);

  for (const theme of ['dark', 'light']) {
    const env = createDOMEnvironment({
      prefersLight: theme === 'light',
      localStorage: {
        'gmdl-ui': JSON.stringify(Object.assign({}, DEFAULT_VALID_SETTINGS, { theme, style: 'glass' }))
      }
    });

    const { panel } = openPanel(env);

    accentKeys.forEach((key, idx) => {
      const swatchGroups = panel.querySelectorAll('.gmdl-ui-swatches');
      assert.ok(swatchGroups.length >= 1, 'Expected accent swatch container in panel');
      const accentButtons = swatchGroups[0].querySelectorAll('.gmdl-ui-sw');
      assert.equal(accentButtons.length, 6, 'Expected 6 accent swatches');

      accentButtons[idx].click();

      const updatedButtons = panel.querySelectorAll('.gmdl-ui-swatches')[0].querySelectorAll('.gmdl-ui-sw');
      assert.equal(updatedButtons[idx].classList.contains('on'), true, `Clicked swatch ${key} must have .on class`);

      const css = env.document.getElementById('gmdl-accent').textContent;
      assert.ok(
        css.includes(`--primary-color:${expectedHex[key]}`),
        `Expected --primary-color:${expectedHex[key]} for accent="${key}" in ${theme} glass mode`
      );
      assert.equal(
        env.document.documentElement.classList.contains('glass'),
        true,
        `<html> must have .glass class when selecting accent="${key}" in ${theme} glass mode`
      );
    });
  }
});

test('GLASS-CONTRAST: Reproducible Light-Mode Glass Contrast Verification across 3 canvases x 3 sliders x 2 stops x 2 text colors', () => {
  function srgbChannelToLinear(c8) {
    const c = c8 / 255;
    return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
  }
  function relativeLuminance(rgb) {
    return (
      0.2126 * srgbChannelToLinear(rgb[0]) +
      0.7152 * srgbChannelToLinear(rgb[1]) +
      0.0722 * srgbChannelToLinear(rgb[2])
    );
  }
  function wcagContrast(lum1, lum2) {
    const brighter = Math.max(lum1, lum2);
    const darker = Math.min(lum1, lum2);
    return (brighter + 0.05) / (darker + 0.05);
  }
  function hexToRgb(hex) {
    const h = hex.replace(/^#/, '');
    return [
      parseInt(h.slice(0, 2), 16),
      parseInt(h.slice(2, 4), 16),
      parseInt(h.slice(4, 6), 16)
    ];
  }

  const canvases = [
    { id: 'L-BG-1', hex: '#ffffff', rgb: hexToRgb('#ffffff') },
    { id: 'L-BG-2', hex: '#f8fafc', rgb: hexToRgb('#f8fafc') },
    { id: 'L-BG-3', hex: '#f1f5f9', rgb: hexToRgb('#f1f5f9') }
  ];
  const texts = [
    { id: 'primary', hex: '#1f2937', lum: relativeLuminance(hexToRgb('#1f2937')) },
    { id: 'secondary', hex: '#4b5563', lum: relativeLuminance(hexToRgb('#4b5563')) }
  ];
  const sliderCases = [
    { glass: 0, expectedA: '0.015', stop1: 0.30975, stop2: 0.206 },
    { glass: 55, expectedA: '0.095', stop1: 0.36175, stop2: 0.238 },
    { glass: 100, expectedA: '0.160', stop1: 0.404, stop2: 0.264 }
  ];

  let evaluatedCombinations = 0;

  for (const sc of sliderCases) {
    const env = createDOMEnvironment({
      prefersLight: true,
      localStorage: {
        'gmdl-ui': JSON.stringify(
          Object.assign({}, DEFAULT_VALID_SETTINGS, { theme: 'light', style: 'glass', glass: sc.glass })
        )
      }
    });

    const runtimeA = env.document.documentElement.style.getPropertyValue('--glass-a');
    assert.equal(runtimeA, sc.expectedA, `Runtime --glass-a at S.glass=${sc.glass} must equal ${sc.expectedA}`);

    const aNum = parseFloat(runtimeA);
    const alpha1 = Number((0.30 + 0.65 * aNum).toFixed(6));
    const alpha2 = Number((0.20 + 0.40 * aNum).toFixed(6));
    assert.equal(alpha1, sc.stop1, `Stop 1 alpha mismatch at S.glass=${sc.glass}`);
    assert.equal(alpha2, sc.stop2, `Stop 2 alpha mismatch at S.glass=${sc.glass}`);

    for (const canvas of canvases) {
      for (const [stopLabel, alpha] of [['stop1', alpha1], ['stop2', alpha2]]) {
        const compositedRgb = canvas.rgb.map((ch) => 255 * alpha + ch * (1 - alpha));
        const surfaceLum = relativeLuminance(compositedRgb);
        for (const t of texts) {
          const ratio = wcagContrast(surfaceLum, t.lum);
          evaluatedCombinations += 1;
          assert.ok(
            ratio >= 4.5,
            `WCAG AA contrast < 4.5:1 for ${canvas.id}, S.glass=${sc.glass}, ${stopLabel}, text=${t.id}: got ${ratio.toFixed(2)}:1`
          );
        }
      }
    }

    assert.equal(
      env.document.documentElement.classList.contains('glass'),
      true,
      `Light mode at S.glass=${sc.glass} must activate .glass on <html>`
    );
  }

  assert.equal(evaluatedCombinations, 36, 'Must evaluate all 3 canvases x 3 sliders x 2 stops x 2 text colors = 36 combinations');
  assert.ok(
    DARK_CSS_SRC.includes('html.glass:not(.dark)'),
    'Light-mode glass contrast requires html.glass:not(.dark) rule in gmdl-dark.css'
  );
});

// ===========================================================================
// 3. WP-C: Mobile Ergonomics & Keyboard Interaction Tests (ACC-01..05)
// ===========================================================================

test('ACC-01: Non-Modal Panel Open / Close & ARIA Semantics (role="region", aria-controls, aria-expanded)', () => {
  const env = createDOMEnvironment();
  const btn = env.document.getElementById('gmdl-ui-btn');
  const panel = env.document.getElementById('gmdl-ui-panel');

  assert.equal(btn.getAttribute('aria-label'), '个性化设置');
  assert.equal(btn.getAttribute('aria-controls'), 'gmdl-ui-panel');
  assert.equal(btn.getAttribute('aria-expanded'), 'false');
  assert.equal(btn.getAttribute('aria-haspopup'), null, 'Non-modal trigger must omit aria-haspopup="dialog"');

  assert.equal(panel.getAttribute('role'), 'region');
  assert.equal(panel.getAttribute('aria-label'), '个性化外观设置');
  assert.equal(panel.getAttribute('aria-modal'), null, 'Non-modal panel must omit aria-modal="true"');

  btn.click();
  assert.equal(panel.hidden, false);
  assert.equal(btn.getAttribute('aria-expanded'), 'true');

  btn.click();
  assert.equal(panel.hidden, true);
  assert.equal(btn.getAttribute('aria-expanded'), 'false');
});

test('ACC-02: Escape Key Dismissal & Focus Return to #gmdl-ui-btn', () => {
  const env = createDOMEnvironment();
  const { btn, panel } = openPanel(env);

  env.document.dispatchEvent({ type: 'keydown', key: 'Escape' });

  assert.equal(panel.hidden, true, 'Escape key must close open personalization panel');
  assert.equal(btn.getAttribute('aria-expanded'), 'false', 'Escape key must reset aria-expanded="false"');
  assert.equal(env.document.activeElement, btn, 'Escape key must restore focus to #gmdl-ui-btn');
});

test('ACC-03: Touch Target Ergonomics (>= 44x44px across all visible interactive controls; hidden file input excluded)', () => {
  const env = createDOMEnvironment({
    localStorage: {
      'gmdl-ui': JSON.stringify(DEFAULT_VALID_SETTINGS),
      'gmdl-bgimg': 'data:image/jpeg;base64,/9j/4AAQSkZJRg=='
    }
  });
  const { btn, panel } = openPanel(env);

  // Verify hidden file input is present and display:none (excluded from visible target checks)
  const fileInputs = panel.querySelectorAll('input[type="file"]');
  assert.equal(fileInputs.length, 1, 'Expected one file input for background upload');
  assert.equal(fileInputs[0].style.display, 'none', 'File input must remain hidden (display: none)');

  // Verify all visible interactive controls exist in the DOM including export/import controls
  const segBtns = panel.querySelectorAll('.gmdl-ui-segbtn');
  const swatches = panel.querySelectorAll('.gmdl-ui-sw');
  const sliders = panel.querySelectorAll('input[type="range"]');
  const exportCode = env.document.getElementById('gmdl-export-code');
  const importCode = env.document.getElementById('gmdl-import-code');
  const importBtn = env.document.getElementById('gmdl-import-btn');

  assert.ok(btn, 'Launcher #gmdl-ui-btn must exist');
  assert.ok(segBtns.length >= 15, 'All segmented buttons (including upload/clear) must exist');
  assert.equal(swatches.length, 10, 'All 6 accent + 4 bg swatches must exist');
  for (let i = 6; i < swatches.length; i++) {
    assert.equal(
      swatches[i].style.border,
      '2px solid #555',
      'All four background swatches must preserve the same 2px border box as accent swatches'
    );
  }
  assert.equal(sliders.length, 2, 'Both range sliders must exist');
  assert.ok(exportCode, 'Export control #gmdl-export-code must exist');
  assert.ok(importCode, 'Import control #gmdl-import-code must exist');
  assert.ok(importBtn, 'Import apply button #gmdl-import-btn must exist');

  // Verify CSS touch target sizing rules in gmdl-dark.css
  assert.ok(
    /#gmdl-ui-btn\s*\{[^}]*width:\s*44px[^}]*height:\s*44px/s.test(DARK_CSS_SRC),
    '#gmdl-ui-btn must have 44x44px dimensions'
  );
  assert.ok(
    /\.gmdl-ui-segbtn\s*\{[^}]*min-height:\s*44px/s.test(DARK_CSS_SRC),
    '.gmdl-ui-segbtn must specify min-height: 44px for touch ergonomics'
  );
  assert.ok(
    /\.gmdl-ui-sw\s*\{[^}]*width:\s*36px[^}]*height:\s*36px/s.test(DARK_CSS_SRC),
    '.gmdl-ui-sw visual border box must remain 36x36px'
  );
  const swatchBorderBox = 36;
  const swatchBorder = 2;
  const pseudoInset = 6;
  assert.equal(
    swatchBorderBox - 2 * swatchBorder + 2 * pseudoInset,
    44,
    'A 36px border box with 2px borders needs 6px absolute insets to produce a 44px pseudo box'
  );
  assert.ok(
    /\.gmdl-ui-sw::after\s*\{[^}]*top:\s*-6px[^}]*left:\s*-6px[^}]*right:\s*-6px[^}]*bottom:\s*-6px/s.test(DARK_CSS_SRC),
    'The swatch pseudo hitbox must use -6px on every side because its absolute containing box is the inner padding box'
  );
  assert.ok(
    !/\.gmdl-ui-sw\.on\s*\{[^}]*transform:\s*scale\(/s.test(DARK_CSS_SRC),
    'An enlarged active swatch must not overlap its neighboring 44x44px hit target'
  );
  assert.ok(
    /#gmdl-ui-panel\s+input\[type="range"\]\s*\{[^}]*height:\s*44px/s.test(DARK_CSS_SRC),
    'Both visible range sliders must have a minimum 44px interactive height'
  );
  assert.ok(
    /(?:#gmdl-export-code|\.gmdl-ui-transfer)[^{]*\{[^}]*min-height:\s*44px/s.test(DARK_CSS_SRC) &&
      /(?:#gmdl-import-code|\.gmdl-ui-transfer)[^{]*\{[^}]*min-height:\s*44px/s.test(DARK_CSS_SRC) &&
      /(?:#gmdl-import-btn|\.gmdl-ui-transfer)[^{]*\{[^}]*min-height:\s*44px/s.test(DARK_CSS_SRC),
    'Export, import, and apply controls must each have a CSS-backed 44px minimum hit area'
  );
});

test('ACC-04: Keyboard Tab Traversal Without Trapping (natural tab order across visible controls, including export/import)', () => {
  const env = createDOMEnvironment();
  const { panel } = openPanel(env);

  const allInteractive = panel.querySelectorAll('button, input, select, textarea');
  const visibleFocusable = allInteractive.filter(
    (el) => el.style.display !== 'none' && !el.hidden && el.tabIndex >= 0 && !el.disabled
  );

  // Hidden file input must be excluded
  assert.ok(
    visibleFocusable.every((el) => el.type !== 'file'),
    'Hidden file input must not be in the visible focusable control list'
  );

  // Export/import interactive controls must be included in visible focusable controls
  const ids = visibleFocusable.map((el) => el.id).filter(Boolean);
  assert.ok(ids.includes('gmdl-export-code'), 'Tab order must include read-only #gmdl-export-code');
  assert.ok(ids.includes('gmdl-import-code'), 'Tab order must include #gmdl-import-code');
  assert.ok(ids.includes('gmdl-import-btn'), 'Tab order must include #gmdl-import-btn');

  // Dispatching Tab keydown on panel or document must not preventDefault or trap focus
  const lastControl = visibleFocusable[visibleFocusable.length - 1];
  lastControl.focus();
  let defaultPrevented = false;
  env.document.dispatchEvent({
    type: 'keydown',
    key: 'Tab',
    preventDefault() { defaultPrevented = true; }
  });
  assert.equal(defaultPrevented, false, 'Tab keydown must not be trapped or preventDefault() inside non-modal region');
});

test('ACC-05: Visible Focus Outlines (:focus-visible 2px solid var(--primary-color) on all visible interactive controls)', () => {
  const env = createDOMEnvironment({
    localStorage: {
      'gmdl-ui': JSON.stringify(DEFAULT_VALID_SETTINGS),
      'gmdl-bgimg': 'data:image/jpeg;base64,/9j/4AAQSkZJRg=='
    }
  });
  const { panel } = openPanel(env);

  // Hidden file input is excluded from visible focus outline checks
  const fileInputs = panel.querySelectorAll('input[type="file"]');
  assert.equal(fileInputs.length, 1);
  assert.equal(fileInputs[0].style.display, 'none');

  assert.ok(
    DARK_CSS_SRC.includes('#gmdl-ui-btn:focus-visible') &&
      /#gmdl-ui-panel\s+[^,{]*:focus-visible/.test(DARK_CSS_SRC) &&
      DARK_CSS_SRC.includes('#gmdl-export-code') &&
      DARK_CSS_SRC.includes('#gmdl-import-code') &&
      DARK_CSS_SRC.includes('#gmdl-import-btn'),
    'gmdl-dark.css must provide a panel-wide :focus-visible rule covering export/import controls and the launcher'
  );
  assert.ok(
    /outline:\s*2px\s+solid\s+var\(--primary-color\)/.test(DARK_CSS_SRC) &&
      /outline-offset:\s*2px/.test(DARK_CSS_SRC),
    'gmdl-dark.css :focus-visible rule must specify outline: 2px solid var(--primary-color) and outline-offset: 2px'
  );
});

// ===========================================================================
// 4. WP-C: Viewport Responsive Contract Checks (VIEW-01..05)
// Note: This deterministic DOM shim has no layout engine. These tests assert the
// CSS/DOM responsive containment contract without fabricating scrollWidth
// numbers. Real Chromium scrollWidth <= clientWidth measurement is executed
// separately against the authentic upstream page in Task 7.
// ===========================================================================

const VIEWPORT_CASES = [
  { id: 'VIEW-01', width: 320, height: 568, label: 'iPhone SE / Compact (320x568)' },
  { id: 'VIEW-02', width: 375, height: 812, label: 'iPhone X / 11 / Mini (375x812)' },
  { id: 'VIEW-03', width: 390, height: 844, label: 'iPhone 12 / 13 / 14 (390x844)' },
  { id: 'VIEW-04', width: 768, height: 1024, label: 'iPad / Tablet Portrait (768x1024)' },
  { id: 'VIEW-05', width: 1280, height: 800, label: 'Desktop / Laptop (1280x800)' }
];

for (const vp of VIEWPORT_CASES) {
  test(`${vp.id}: Responsive Panel Containment Contract for ${vp.label} (real browser scrollWidth measurement in Task 7)`, () => {
    // Assert CSS containment contract from gmdl-dark.css.md §4 & SPEC.md §4.2:
    // #gmdl-ui-panel must use width: calc(100vw - 24px); max-width: 400px; max-height: min(75vh, 580px); box-sizing: border-box;
    assert.ok(
      DARK_CSS_SRC.includes('width: calc(100vw - 24px)'),
      `${vp.id}: #gmdl-ui-panel must constrain width to calc(100vw - 24px) so ${vp.width}px viewport does not overflow`
    );
    assert.ok(
      DARK_CSS_SRC.includes('max-width: 400px'),
      `${vp.id}: #gmdl-ui-panel must set max-width: 400px`
    );
    assert.ok(
      DARK_CSS_SRC.includes('max-height: min(75vh, 580px)'),
      `${vp.id}: #gmdl-ui-panel must set max-height: min(75vh, 580px)`
    );
    assert.ok(
      DARK_CSS_SRC.includes('box-sizing: border-box'),
      `${vp.id}: #gmdl-ui-panel must set box-sizing: border-box`
    );

    const effectivePanelWidth = Math.min(vp.width - 24, 400);
    assert.ok(
      effectivePanelWidth > 0 && effectivePanelWidth + 24 <= vp.width,
      `${vp.id}: Effective panel width (${effectivePanelWidth}px) + 24px margins must fit inside ${vp.width}px viewport`
    );
  });
}
