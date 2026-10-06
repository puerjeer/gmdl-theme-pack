/* MusicDL personalization panel: theme / accent / background. Prefs in localStorage. */
(function () {
  'use strict';
  var LS = 'gmdl-ui';
  var PANEL_V = 'v9';
  var ACCENTS = {
    green:  { label: '薄荷绿', m: '#10b981', b: '#34d399', d: '#059669', glow: 'rgba(16,185,129,0.15)',  shadow: 'rgba(16,185,129,0.3)' },
    blue:   { label: '天空蓝', m: '#3b82f6', b: '#60a5fa', d: '#2563eb', glow: 'rgba(59,130,246,0.15)',  shadow: 'rgba(59,130,246,0.3)' },
    purple: { label: '葡萄紫', m: '#8b5cf6', b: '#a78bfa', d: '#7c3aed', glow: 'rgba(139,92,246,0.16)',  shadow: 'rgba(139,92,246,0.3)' },
    orange: { label: '活力橙', m: '#f97316', b: '#fb923c', d: '#ea580c', glow: 'rgba(249,115,22,0.15)',   shadow: 'rgba(249,115,22,0.3)' },
    pink:   { label: '樱花粉', m: '#ec4899', b: '#f472b6', d: '#db2777', glow: 'rgba(236,72,153,0.15)',   shadow: 'rgba(236,72,153,0.3)' },
    cyan:   { label: '青碧色', m: '#06b6d4', b: '#22d3ee', d: '#0891b2', glow: 'rgba(6,182,212,0.15)',     shadow: 'rgba(6,182,212,0.3)' }
  };
  var BGS = {
    obsidian: { label: '曜石黑', base: '#0d1117', g1: 'hsla(160,60%,12%,1)', g2: 'hsla(220,40%,16%,1)',  g3: 'hsla(330,45%,14%,1)' },
    midnight: { label: '深海蓝', base: '#0a1526', g1: 'hsla(210,70%,16%,1)', g2: 'hsla(230,60%,20%,1)',  g3: 'hsla(200,70%,12%,1)' },
    grape:    { label: '暗夜紫', base: '#140f1e', g1: 'hsla(280,50%,16%,1)', g2: 'hsla(320,45%,14%,1)',  g3: 'hsla(250,50%,12%,1)' },
    amoled:   { label: '纯黑',   base: '#000000', g1: 'hsla(160,60%,6%,1)',  g2: 'hsla(220,40%,8%,1)',   g3: 'hsla(330,45%,7%,1)' }
  };

  var TEXTS = {
    bright: { label: '亮白', main: '#f2f6fb', sub: '#a7b4c4' },
    soft:   { label: '柔白', main: '#e6edf3', sub: '#9aa7b8' },
    warm:   { label: '暖白', main: '#f5efe4', sub: '#b3a893' }
  };
  var BGIMG_KEY = 'gmdl-bgimg';

  function load() {
    var s = { theme: 'auto', accent: 'green', bg: 'obsidian', style: 'glass', text: 'soft', lyric: 'm', glow: true, blur: 10, glass: 55 };
    try {
      var raw = localStorage.getItem(LS);
      if (raw) { var p = JSON.parse(raw); for (var k in s) { if (p[k] !== undefined) s[k] = p[k]; } }
      else {
        var old = null;
        try { old = localStorage.getItem('gmdl-theme'); } catch (e) {}
        if (old === 'dark' || old === 'light') s.theme = old;
      }
    } catch (e) {}
    if (!ACCENTS[s.accent]) s.accent = 'green';
    if (!BGS[s.bg]) s.bg = 'obsidian';
    if (['dark', 'light', 'auto'].indexOf(s.theme) < 0) s.theme = 'auto';
    if (['solid', 'glass'].indexOf(s.style) < 0) s.style = 'glass';
    if (!TEXTS[s.text]) s.text = 'soft';
    if (['s', 'm', 'big'].indexOf(s.lyric) < 0) s.lyric = 'm';
    s.glow = s.glow !== false;
    s.blur = Math.max(0, Math.min(24, parseInt(s.blur, 10) || 0));
    s.glass = Math.max(0, Math.min(100, parseInt(s.glass, 10)));
    if (isNaN(s.glass)) s.glass = 55;
    return s;
  }
  function save(s) { try { localStorage.setItem(LS, JSON.stringify(s)); } catch (e) {} }
  var S = load();
  function bgImg() { try { return localStorage.getItem(BGIMG_KEY) || ''; } catch (e) { return ''; } }

  function isDark() {
    if (S.theme === 'dark') return true;
    if (S.theme === 'light') return false;
    return !(window.matchMedia && window.matchMedia('(prefers-color-scheme: light)').matches);
  }
  function ensureStyle(id) {
    var el = document.getElementById(id);
    if (!el) { el = document.createElement('style'); el.id = id; document.head.appendChild(el); }
    return el;
  }
  function apply() {
    var dark = isDark();
    var glass = dark && S.style === 'glass';
    var img = bgImg();
    var hasImg = dark && !!img;
    document.documentElement.classList.toggle('dark', dark);
    document.documentElement.classList.toggle('glass', glass);
    document.documentElement.classList.toggle('gmdl-bgimg', hasImg);
    document.documentElement.classList.toggle('lyr-small', S.lyric === 's');
    document.documentElement.classList.toggle('lyr-big', S.lyric === 'big');
    document.documentElement.classList.toggle('lyr-glow', S.glow !== false);
    try {
      document.documentElement.style.setProperty('--glass-a', (0.015 + (S.glass / 100) * 0.145).toFixed(3));
      document.documentElement.style.setProperty('--glass-b', Math.round((S.glass / 100) * 28) + 'px');
    } catch (e) {}
    var a = ACCENTS[S.accent], bg = BGS[S.bg], tx = TEXTS[S.text];
    var css = ':root{--primary-color:' + a.m + ';--primary-gradient:linear-gradient(135deg,' + a.b + ' 0%,' + a.d + ' 100%);--karaoke-progress:' + a.m + ';}\n' +
      (dark ? ':root{--text-main:' + tx.main + ';--text-sub:' + tx.sub + ';}\n' +
      'html.dark .source-name,html.dark .song-list-tool-field,html.dark .song-list-tools-heading{color:' + tx.sub + ';}\n' +
      'html.dark .cookie-item select,html.dark .song-list-tool-field select,html.dark h2,html.dark h3{color:' + tx.main + ';}\n' : '');
      '.type-option:hover,.type-option input:checked+span,.source-collapse-btn:hover .source-title,.source-collapse-btn:hover .source-collapse-icon,.ctrl-btn:hover,.list-header .result-count .count{color:' + a.m + ';}\n' +
      '.type-option input{accent-color:' + a.m + ';}\n' +
      'input[type="text"]:focus,input[type="password"]:focus{border-color:' + a.m + ';box-shadow:0 0 0 4px ' + a.glow + ';}\n' +
      '.search-btn{box-shadow:0 4px 12px ' + a.shadow + ';}\n' +
      '.search-btn:hover{box-shadow:0 6px 16px ' + a.shadow + ';}\n' +
      '.song-list-tools-trigger:hover,.song-list-tools-trigger[aria-expanded="true"]{border-color:' + a.b + ';}\n' +
      '.song-list-tool-field select:focus{border-color:' + a.b + ';box-shadow:0 0 0 3px ' + a.glow + ';}\n' +
      '.aplayer .aplayer-lrc p.aplayer-lrc-current{color:' + a.m + ';}\n';
    if (img && dark) {
      css += 'html.dark.gmdl-bgimg body{background:transparent;background-image:none;}\n' +
        'html.dark.gmdl-bgimg body::before{content:"";position:fixed;left:-40px;top:-40px;right:-40px;bottom:-40px;background-image:linear-gradient(rgba(10,14,20,0.66),rgba(10,14,20,0.74)),url("' + img + '");background-size:cover;background-position:center;z-index:-1;filter:blur(' + S.blur + 'px) saturate(1.25);}\n';
    } else if (dark && !glass) {
      css += 'html.dark body{background-color:' + bg.base + ';background-image:radial-gradient(at 0% 0%,' + bg.g1 + ' 0,transparent 50%),radial-gradient(at 50% 0%,' + bg.g2 + ' 0,transparent 50%),radial-gradient(at 100% 0%,' + bg.g3 + ' 0,transparent 50%);}\n';
    }
    ensureStyle('gmdl-accent').textContent = css;
    if (panel) {
      var has = !!bgImg();
      if (has !== lastHasImg) renderRows(); else refreshPanel();
      lastHasImg = has;
    } else refreshPanel();
  }

  function el(tag, cls, text) {
    var e = document.createElement(tag);
    if (cls) e.className = cls;
    if (text !== undefined) e.textContent = text;
    return e;
  }
  var panel = null;
  var lastHasImg = null;
  function renderRows() {
    while (panel.firstChild) panel.removeChild(panel.firstChild);
    panel.appendChild(rowTheme());
    panel.appendChild(rowStyle());
    panel.appendChild(rowText());
    panel.appendChild(rowLyric());
    panel.appendChild(rowGlow());
    panel.appendChild(rowPreview());
    panel.appendChild(rowAccent());
    panel.appendChild(rowBg());
    panel.appendChild(rowBlur());
    panel.appendChild(rowGlass());
    panel.appendChild(rowBgImg());
    var cssV = '';
    try {
      var lk = document.querySelector('link[href*="gmdl-dark.css"]');
      var m = lk && lk.href.match(/v=(\d+)/);
      if (m) cssV = m[1];
    } catch (e) {}
    panel.appendChild(el('div', 'gmdl-ui-foot', '偏好只保存在当前浏览器 · 样式v' + (cssV || '?') + '/面板' + PANEL_V));
  }
  function build() {
    var btn = el('button', null, '⚙');
    btn.id = 'gmdl-ui-btn';
    btn.title = '个性化设置';
    btn.onclick = function () { panel.hidden = !panel.hidden; };
    panel = el('div', null, null);
    panel.id = 'gmdl-ui-panel';
    panel.hidden = true;
    renderRows();
    (document.body || document.documentElement).appendChild(btn);
    document.body.appendChild(panel);
    refreshPanel();
  }
  function rowTheme() {
    var row = el('div', 'gmdl-ui-row', null);
    row.appendChild(el('span', 'gmdl-ui-label', '主题'));
    var wrap = el('div', 'gmdl-ui-seg', null);
    [['dark', '深色'], ['light', '浅色'], ['auto', '跟随']].forEach(function (o) {
      var b = el('button', 'gmdl-ui-segbtn' + (S.theme === o[0] ? ' on' : ''), o[1]);
      b.onclick = function () { S.theme = o[0]; save(S); apply(); };
      wrap.appendChild(b);
    });
    row.appendChild(wrap);
    return row;
  }
  function rowStyle() {
    var row = el('div', 'gmdl-ui-row', null);
    row.appendChild(el('span', 'gmdl-ui-label', '风格'));
    var wrap = el('div', 'gmdl-ui-seg', null);
    [['solid', '曜石'], ['glass', '玻璃']].forEach(function (o) {
      var b = el('button', 'gmdl-ui-segbtn gmdl-ui-stylebtn' + (S.style === o[0] ? ' on' : ''), o[1]);
      b.onclick = function () { S.style = o[0]; save(S); apply(); };
      wrap.appendChild(b);
    });
    row.appendChild(wrap);
    return row;
  }
  function rowText() {
    var row = el('div', 'gmdl-ui-row', null);
    row.appendChild(el('span', 'gmdl-ui-label', '文字'));
    var wrap = el('div', 'gmdl-ui-seg', null);
    [['bright', '亮白'], ['soft', '柔白'], ['warm', '暖白']].forEach(function (o) {
      var b = el('button', 'gmdl-ui-segbtn gmdl-ui-textbtn' + (S.text === o[0] ? ' on' : ''), o[1]);
      b.onclick = function () { S.text = o[0]; save(S); apply(); };
      wrap.appendChild(b);
    });
    row.appendChild(wrap);
    return row;
  }
  function rowBgImg() {
    var row = el('div', 'gmdl-ui-row', null);
    row.appendChild(el('span', 'gmdl-ui-label', '背景图'));
    var wrap = el('div', 'gmdl-ui-seg', null);
    var up = el('button', 'gmdl-ui-segbtn', bgImg() ? '已设置·更换' : '上传');
    var file = document.createElement('input');
    file.type = 'file';
    file.accept = 'image/*';
    file.style.display = 'none';
    file.onchange = function () {
      if (!file.files || !file.files[0]) return;
      var rd = new FileReader();
      rd.onload = function () {
        var im = new Image();
        im.onload = function () {
          try {
            var max = 1920, w = im.width, h = im.height;
            if (w > max) { h = Math.round(h * max / w); w = max; }
            var cv = document.createElement('canvas');
            cv.width = w; cv.height = h;
            cv.getContext('2d').drawImage(im, 0, 0, w, h);
            var url = cv.toDataURL('image/jpeg', 0.82);
            try { localStorage.setItem(BGIMG_KEY, url); } catch (e) {
              alert('图片太大，浏览器存不下，换张小一点的试试');
              return;
            }
            apply();
          } catch (e) { alert('读取图片失败'); }
        };
        im.src = rd.result;
      };
      rd.readAsDataURL(file.files[0]);
      file.value = '';
    };
    up.onclick = function () { file.click(); };
    wrap.appendChild(up);
    if (bgImg()) {
      var cl = el('button', 'gmdl-ui-segbtn', '清除');
      cl.onclick = function () { try { localStorage.removeItem(BGIMG_KEY); } catch (e) {} apply(); };
      wrap.appendChild(cl);
    }
    wrap.appendChild(file);
    row.appendChild(wrap);
    return row;
  }
  function rowLyric() {
    var row = el('div', 'gmdl-ui-row', null);
    row.appendChild(el('span', 'gmdl-ui-label', '歌词字号'));
    var wrap = el('div', 'gmdl-ui-seg', null);
    [['s', '小'], ['m', '中'], ['big', '大']].forEach(function (o) {
      var b = el('button', 'gmdl-ui-segbtn' + (S.lyric === o[0] ? ' on' : ''), o[1]);
      b.onclick = function () { S.lyric = o[0]; save(S); apply(); };
      wrap.appendChild(b);
    });
    row.appendChild(wrap);
    return row;
  }
  function rowGlow() {
    var row = el('div', 'gmdl-ui-row', null);
    row.appendChild(el('span', 'gmdl-ui-label', '歌词发光'));
    var wrap = el('div', 'gmdl-ui-seg', null);
    [[true, '开'], [false, '关']].forEach(function (o) {
      var b = el('button', 'gmdl-ui-segbtn' + ((S.glow !== false) === o[0] ? ' on' : ''), o[1]);
      b.onclick = function () { S.glow = o[0]; save(S); apply(); };
      wrap.appendChild(b);
    });
    row.appendChild(wrap);
    return row;
  }
  function rowPreview() {
    var pv = el('div', null, null);
    pv.id = 'gmdl-lyric-preview';
    pv.textContent = '晴天 · 周杰伦';
    var sm = el('small', null, '歌词样式实时预览');
    pv.appendChild(sm);
    return pv;
  }
  function rowBlur() {
    var row = el('div', 'gmdl-ui-row', null);
    row.appendChild(el('span', 'gmdl-ui-label', '背景模糊'));
    var wrap = el('div', 'gmdl-ui-seg', null);
    var rg = document.createElement('input');
    rg.type = 'range'; rg.min = '0'; rg.max = '24'; rg.step = '1';
    rg.value = String(S.blur);
    rg.style.width = '110px';
    rg.title = '背景图模糊程度';
    var val = el('span', 'gmdl-ui-label', S.blur + 'px');
    val.style.minWidth = '36px';
    rg.oninput = function () {
      S.blur = Math.max(0, Math.min(24, parseInt(rg.value, 10) || 0));
      val.textContent = S.blur + 'px';
      save(S); apply();
    };
    wrap.appendChild(rg);
    wrap.appendChild(val);
    row.appendChild(wrap);
    return row;
  }
  function rowGlass() {
    var row = el('div', 'gmdl-ui-row', null);
    row.appendChild(el('span', 'gmdl-ui-label', '玻璃强度'));
    var wrap = el('div', 'gmdl-ui-seg', null);
    var rg = document.createElement('input');
    rg.type = 'range'; rg.min = '0'; rg.max = '100'; rg.step = '1';
    rg.value = String(S.glass);
    rg.style.width = '110px';
    rg.title = '毛玻璃模糊与不透明程度，调低可看清背景图';
    var val = el('span', 'gmdl-ui-label', S.glass + '%');
    val.style.minWidth = '40px';
    rg.oninput = function () {
      S.glass = Math.max(0, Math.min(100, parseInt(rg.value, 10) || 0));
      val.textContent = S.glass + '%';
      save(S); apply();
    };
    wrap.appendChild(rg);
    wrap.appendChild(val);
    row.appendChild(wrap);
    return row;
  }
  function rowAccent() {
    var row = el('div', 'gmdl-ui-row', null);
    row.appendChild(el('span', 'gmdl-ui-label', '强调色'));
    var wrap = el('div', 'gmdl-ui-swatches', null);
    Object.keys(ACCENTS).forEach(function (k) {
      var b = el('button', 'gmdl-ui-sw' + (S.accent === k ? ' on' : ''), null);
      b.title = ACCENTS[k].label;
      b.style.background = ACCENTS[k].m;
      b.onclick = function () { S.accent = k; save(S); apply(); };
      wrap.appendChild(b);
    });
    row.appendChild(wrap);
    return row;
  }
  function rowBg() {
    var row = el('div', 'gmdl-ui-row', null);
    row.appendChild(el('span', 'gmdl-ui-label', '背景'));
    var wrap = el('div', 'gmdl-ui-swatches', null);
    Object.keys(BGS).forEach(function (k) {
      var b = el('button', 'gmdl-ui-sw' + (S.bg === k ? ' on' : ''), null);
      b.title = BGS[k].label;
      b.style.background = BGS[k].base;
      b.style.border = '1px solid #555';
      b.onclick = function () { S.bg = k; save(S); apply(); };
      wrap.appendChild(b);
    });
    row.appendChild(wrap);
    return row;
  }
  function refreshPanel() {
    if (!panel) return;
    var groups = panel.querySelectorAll('.gmdl-ui-seg');
    var keys = [['theme', ['dark', 'light', 'auto']], ['style', ['solid', 'glass']], ['text', ['bright', 'soft', 'warm']], ['lyric', ['s', 'm', 'big']], ['glow', [true, false]]];
    for (var g = 0; g < groups.length && g < keys.length; g++) {
      var sbtns = groups[g].querySelectorAll('.gmdl-ui-segbtn');
      for (var i = 0; i < sbtns.length; i++) sbtns[i].classList.toggle('on', S[keys[g][0]] === keys[g][1][i]);
    }
    var sws = panel.querySelectorAll('.gmdl-ui-swatches');
    if (sws[0]) {
      var ks = Object.keys(ACCENTS);
      var bs = sws[0].querySelectorAll('.gmdl-ui-sw');
      for (var j = 0; j < bs.length; j++) bs[j].classList.toggle('on', S.accent === ks[j]);
    }
    if (sws[1]) {
      var kb = Object.keys(BGS);
      var cs = sws[1].querySelectorAll('.gmdl-ui-sw');
      for (var q = 0; q < cs.length; q++) cs[q].classList.toggle('on', S.bg === kb[q]);
    }
  }

  try { localStorage.removeItem('gmdl-theme'); } catch (e) {}
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', function () { apply(); build(); });
  else { apply(); build(); }
})();
