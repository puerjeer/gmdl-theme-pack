'use strict';

(function install(root, factory) {
  const api = factory(root);
  if (typeof module === 'object' && module && module.exports) {
    module.exports = api;
  } else if (root && !Object.prototype.hasOwnProperty.call(root, 'GmdlIA')) {
    Object.defineProperty(root, 'GmdlIA', {
      value: api,
      configurable: true,
      enumerable: false,
      writable: false,
    });
  }
})(typeof globalThis !== 'undefined' ? globalThis : this, function createApi(root) {
  const SEARCH_ENDPOINT = 'https://archive.org/advancedsearch.php';
  const METADATA_ENDPOINT = 'https://archive.org/metadata';
  const DOWNLOAD_ENDPOINT = 'https://archive.org/download';
  const MAX_FILE_SIZE_BYTES = 50 * 1024 * 1024;
  const ALLOWED_LICENSE_PATHS = new Set([
    '/publicdomain/zero/1.0',
    '/publicdomain/mark/1.0',
  ]);
  const SEARCH_FIELDS = ['identifier', 'title', 'creator', 'year', 'licenseurl'];
  const playableCandidates = new WeakSet();

  function escapeTitlePhrase(value) {
    return value.replace(/\\/g, '\\\\').replace(/"/g, '\\"');
  }

  function encodePathSegment(value, label) {
    const segment = value;
    if (!segment.trim() || segment === '.' || segment === '..' || /[\/\\\u0000-\u001f\u007f]/.test(segment)) {
      throw new TypeError(`The Internet Archive ${label} must be a single safe path segment.`);
    }
    return encodeURIComponent(segment);
  }

  function isSafePathSegment(value) {
    if (typeof value !== 'string') return false;
    try {
      encodePathSegment(value, 'path segment');
      return true;
    } catch (_) {
      return false;
    }
  }

  function buildSearchUrl(title, options = {}) {
    if (typeof title !== 'string') {
      throw new TypeError('Search title must be a string.');
    }
    const normalizedTitle = title.trim();
    if (!normalizedTitle || normalizedTitle.length > 512 || /[\u0000-\u001f\u007f]/.test(normalizedTitle)) {
      throw new TypeError('Search title must be non-empty, at most 512 characters, and contain no control characters.');
    }

    const rows = options.rows === undefined ? 20 : options.rows;
    const page = options.page === undefined ? 1 : options.page;
    if (!Number.isSafeInteger(rows) || rows < 1 || rows > 100) {
      throw new RangeError('Search rows must be an integer from 1 to 100.');
    }
    if (!Number.isSafeInteger(page) || page < 1) {
      throw new RangeError('Search page must be a positive integer.');
    }

    const params = new URLSearchParams();
    params.set('q', `mediatype:audio AND title:"${escapeTitlePhrase(normalizedTitle)}"`);
    for (const field of SEARCH_FIELDS) params.append('fl[]', field);
    params.set('rows', String(rows));
    params.set('page', String(page));
    params.set('output', 'json');
    return `${SEARCH_ENDPOINT}?${params.toString()}`;
  }

  async function searchAudio(title, options = {}) {
    const fetcher = options.fetchImpl || root.fetch;
    if (typeof fetcher !== 'function') throw new TypeError('A fetch implementation is required.');
    const response = await fetcher(buildSearchUrl(title, options), {
      method: 'GET',
      mode: 'cors',
      credentials: 'omit',
      headers: { Accept: 'application/json' },
      signal: options.signal,
    });
    if (!response || response.ok !== true) {
      throw new Error(`Internet Archive search failed${response && response.status ? ` (${response.status})` : ''}.`);
    }
    const payload = await response.json();
    const docs = payload && payload.response && payload.response.docs;
    if (!Array.isArray(docs)) throw new Error('Internet Archive search returned an invalid response.');
    return docs.filter(doc => doc && typeof doc.identifier === 'string' && doc.identifier.length > 0);
  }

  async function fetchMetadata(identifier, options = {}) {
    if (typeof identifier !== 'string' || !identifier.trim()) {
      throw new TypeError('An Internet Archive identifier is required.');
    }
    const fetcher = options.fetchImpl || root.fetch;
    if (typeof fetcher !== 'function') throw new TypeError('A fetch implementation is required.');
    const url = `${METADATA_ENDPOINT}/${encodePathSegment(identifier, 'identifier')}`;
    const response = await fetcher(url, {
      method: 'GET',
      mode: 'cors',
      credentials: 'omit',
      headers: { Accept: 'application/json' },
      signal: options.signal,
    });
    if (!response || response.ok !== true) {
      throw new Error(`Internet Archive metadata lookup failed${response && response.status ? ` (${response.status})` : ''}.`);
    }
    const payload = await response.json();
    if (!payload || typeof payload !== 'object' || Array.isArray(payload)) {
      throw new Error('Internet Archive metadata returned an invalid response.');
    }
    return payload;
  }

  function isPlayableMp3(file) {
    if (!file || typeof file !== 'object' || Array.isArray(file)) return false;
    const format = typeof file.format === 'string' ? file.format.trim().toLowerCase() : '';
    const mime = typeof (file.mimetype || file.mimeType) === 'string'
      ? String(file.mimetype || file.mimeType).trim().toLowerCase()
      : '';
    return format === 'vbr mp3' || format === '128kbps mp3' || format === 'audio/mpeg' || mime === 'audio/mpeg';
  }

  function isWithinSizeLimit(size) {
    let bytes;
    if (typeof size === 'number') {
      bytes = size;
    } else if (typeof size === 'string' && /^\d+$/.test(size.trim())) {
      bytes = Number(size.trim());
    } else {
      return false;
    }
    return Number.isSafeInteger(bytes) && bytes > 0 && bytes <= MAX_FILE_SIZE_BYTES;
  }

  function isAllowedLicense(value) {
    if (typeof value !== 'string' || !value.trim()) return false;
    try {
      const url = new URL(value.trim());
      if (!['http:', 'https:'].includes(url.protocol)) return false;
      if (url.hostname.toLowerCase() !== 'creativecommons.org') return false;
      if (url.username || url.password || url.port || url.search || url.hash) return false;
      const path = url.pathname.replace(/\/+$/, '');
      return ALLOWED_LICENSE_PATHS.has(path);
    } catch (_) {
      return false;
    }
  }

  function buildAudioUrl(identifier, filename) {
    if (typeof identifier !== 'string' || !identifier.trim()) {
      throw new TypeError('An Internet Archive identifier is required.');
    }
    if (typeof filename !== 'string' || !filename.trim()) {
      throw new TypeError('An audio filename is required.');
    }
    return `${DOWNLOAD_ENDPOINT}/${encodePathSegment(identifier, 'identifier')}/${encodePathSegment(filename, 'filename')}`;
  }

  function listPlayableFiles(metadataResponse, identifier) {
    if (!metadataResponse || typeof metadataResponse !== 'object' || Array.isArray(metadataResponse)) return [];
    const metadata = metadataResponse.metadata;
    const files = metadataResponse.files;
    if (!isSafePathSegment(identifier)) return [];
    if (!metadata || typeof metadata !== 'object' || metadata.mediatype !== 'audio') return [];
    if (!isAllowedLicense(metadata.licenseurl) || !Array.isArray(files)) return [];

    return files
      .filter(file => file && isSafePathSegment(file.name) && isPlayableMp3(file) && isWithinSizeLimit(file.size))
      .map(file => {
        const candidate = Object.freeze({ ...file, url: buildAudioUrl(identifier, file.name) });
        playableCandidates.add(candidate);
        return candidate;
      });
  }

  function createPlayer(options = {}) {
    const audioFactory = typeof options.audioFactory === 'function'
      ? options.audioFactory
      : () => new root.Audio();
    const onStateChange = typeof options.onStateChange === 'function' ? options.onStateChange : () => {};
    let state = 'idle';
    let errorMessage = '';
    let audio = null;
    let activeHandlers = null;
    let generation = 0;

    function setState(next) {
      if (state === next) return;
      state = next;
      try { onStateChange(next); } catch (_) { /* Consumer callbacks cannot break playback. */ }
    }

    function detachHandlers() {
      if (!audio || !activeHandlers || typeof audio.removeEventListener !== 'function') return;
      audio.removeEventListener('canplay', activeHandlers.onCanPlay);
      audio.removeEventListener('error', activeHandlers.onError);
      audio.removeEventListener('pause', activeHandlers.onPause);
      audio.removeEventListener('ended', activeHandlers.onEnded);
      activeHandlers = null;
    }

    function fail(message = '音频加载或播放失败，请稍后重试。', expectedGeneration = generation, expectedAudio = audio) {
      if (expectedGeneration !== generation || expectedAudio !== audio) return false;
      generation += 1;
      errorMessage = message;
      setState('error');
      return true;
    }

    function load(candidate) {
      const requestGeneration = ++generation;
      detachHandlers();
      if (audio && typeof audio.pause === 'function') {
        try { audio.pause(); } catch (_) { /* Continue fail-closed if a media implementation throws. */ }
      }
      errorMessage = '';

      if (!candidate || typeof candidate !== 'object' || !playableCandidates.has(candidate)) {
        fail('只允许播放经过格式、大小与授权过滤的音频文件。', requestGeneration, audio);
        return false;
      }

      let parsed;
      try { parsed = new URL(candidate.url); } catch (_) { fail('音频链接无效。', requestGeneration, audio); return false; }
      if (parsed.origin !== 'https://archive.org' || parsed.username || parsed.password || !parsed.pathname.startsWith('/download/')) {
        fail('只允许播放 Internet Archive 音频链接。', requestGeneration, audio);
        return false;
      }

      try {
        audio = audioFactory();
        if (!audio || typeof audio.addEventListener !== 'function' || typeof audio.removeEventListener !== 'function') {
          throw new TypeError('Audio element unavailable.');
        }
        const currentAudio = audio;
        audio.preload = 'none';
        const onCanPlay = () => {
          if (requestGeneration !== generation || audio !== currentAudio) return;
          try {
            const result = currentAudio.play();
            if (result && typeof result.then === 'function') {
              result.then(
                () => {
                  if (requestGeneration === generation && audio === currentAudio) setState('playing');
                },
                () => fail('音频加载或播放失败，请稍后重试。', requestGeneration, currentAudio),
              );
            } else {
              if (requestGeneration === generation && audio === currentAudio) setState('playing');
            }
          } catch (_) {
            fail('音频加载或播放失败，请稍后重试。', requestGeneration, currentAudio);
          }
        };
        const onError = () => fail('音频加载或播放失败，请稍后重试。', requestGeneration, currentAudio);
        const onPause = () => {
          if (requestGeneration !== generation || audio !== currentAudio) return;
          generation += 1;
          errorMessage = '';
          setState('idle');
        };
        const onEnded = () => {
          if (requestGeneration !== generation || audio !== currentAudio) return;
          generation += 1;
          errorMessage = '';
          setState('idle');
        };
        activeHandlers = { onCanPlay, onError, onPause, onEnded };
        currentAudio.addEventListener('canplay', onCanPlay);
        currentAudio.addEventListener('error', onError);
        currentAudio.addEventListener('pause', onPause);
        currentAudio.addEventListener('ended', onEnded);
        currentAudio.src = parsed.href;
        setState('loading');
        if (typeof currentAudio.load === 'function') currentAudio.load();
        return true;
      } catch (_) {
        fail('音频加载或播放失败，请稍后重试。', requestGeneration, audio);
        return false;
      }
    }

    function pause() {
      generation += 1;
      detachHandlers();
      if (audio && typeof audio.pause === 'function') {
        try { audio.pause(); } catch (_) { /* Preserve the local state even if media pause throws. */ }
      }
      errorMessage = '';
      setState('idle');
    }

    function destroy() {
      generation += 1;
      detachHandlers();
      if (audio && typeof audio.pause === 'function') {
        try { audio.pause(); } catch (_) { /* Teardown must not throw. */ }
      }
      audio = null;
      errorMessage = '';
      setState('idle');
    }

    return Object.freeze({
      load,
      pause,
      destroy,
      getState: () => state,
      getErrorMessage: () => errorMessage,
    });
  }

  return Object.freeze({
    SEARCH_ENDPOINT,
    METADATA_ENDPOINT,
    DOWNLOAD_ENDPOINT,
    MAX_FILE_SIZE_BYTES,
    buildSearchUrl,
    searchAudio,
    fetchMetadata,
    isPlayableMp3,
    isWithinSizeLimit,
    isAllowedLicense,
    buildAudioUrl,
    listPlayableFiles,
    createPlayer,
  });
});
