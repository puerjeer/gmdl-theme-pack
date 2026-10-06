/* MusicDL feature pack: daily random songs button + load-more on blank search */
(function () {
  'use strict';
  function spaces(n) { var s = ''; for (var i = 0; i < n; i++) s += '%20'; return s; }

  /* 1. homepage: 每日推荐歌曲 next to 每日推荐歌单 */
  function homeBtn() {
    if (!/^\/music\/?$/.test(location.pathname)) return;
    if (document.getElementById('gmdl-daily-songs')) return;
    var anchor = document.querySelector('button[onclick="goToRecommend()"]');
    if (!anchor || !anchor.parentNode) return;
    var b = document.createElement('button');
    b.type = 'button';
    b.id = 'gmdl-daily-songs';
    b.className = 'btn-pill btn-pill-fav';
    b.innerHTML = '<i class="fa-solid fa-dice"></i> 每日推荐歌曲';
    b.onclick = function () { location.href = '/music/search?q=' + spaces(2) + '&page=1&page_size=10'; };
    anchor.parentNode.insertBefore(b, anchor);
  }

  /* 2. blank-query search page: append more random songs */
  var round = 0;
  function moreBtn() {
    if (!/^\/music\/search/.test(location.pathname)) return;
    var q = '';
    try { q = new URLSearchParams(location.search).get('q') || ''; } catch (e) {}
    if (q.trim() !== '') return;
    var list = document.querySelector('.result-list');
    if (!list || document.getElementById('gmdl-more-songs')) return;
    var b = document.createElement('button');
    b.type = 'button';
    b.id = 'gmdl-more-songs';
    b.className = 'song-list-tool-action';
    b.style.display = 'block';
    b.style.margin = '14px auto';
    b.textContent = '🎲 再来十首';
    b.onclick = function () {
      round = (round % 5) + 1;
      b.disabled = true;
      b.textContent = '加载中…';
      fetch('/music/search?q=' + spaces(round + 1) + '&page=1&page_size=10')
        .then(function (r) { return r.text(); })
        .then(function (html) {
          var d = document.createElement('div');
          d.innerHTML = html;
          var seen = {};
          list.querySelectorAll('.song-card').forEach(function (c) { seen[c.dataset.id + '|' + c.dataset.source] = 1; });
          var added = 0;
          d.querySelectorAll('.song-card').forEach(function (c) {
            var k = c.dataset.id + '|' + c.dataset.source;
            if (seen[k]) return;
            seen[k] = 1;
            list.appendChild(document.importNode(c, true));
            added++;
          });
          try {
            if (typeof refreshDownloadLinks === 'function') refreshDownloadLinks(list);
          } catch (e) {}
          b.disabled = false;
          b.textContent = added > 0 ? '🎲 再来十首（已+ ' + added + '）' : '🎲 再来十首（本轮重复，换一批）';
        })
        .catch(function () { b.disabled = false; b.textContent = '🎲 再来十首（失败点我重试）'; });
    };
    list.parentNode.insertBefore(b, list.nextSibling);
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', function () { homeBtn(); moreBtn(); });
  else { homeBtn(); moreBtn(); }
})();
