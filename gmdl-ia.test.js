'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

// Keep the red phase as ten independent failures rather than a module-load crash.
let IA = null;
let moduleLoadError = null;
try {
  IA = require('./gmdl-ia.js');
} catch (error) {
  moduleLoadError = error;
}

function requireFunction(name) {
  assert.ok(IA, `gmdl-ia.js is not implemented yet: ${moduleLoadError?.message || 'module missing'}`);
  assert.equal(typeof IA[name], 'function', `gmdl-ia.js must export ${name}()`);
  return IA[name];
}

function fakeAudio() {
  const listeners = new Map();
  return {
    listeners,
    src: '',
    preload: '',
    load() {},
    pause() {},
    play() { return Promise.resolve(); },
    addEventListener(name, callback) { listeners.set(name, callback); },
    removeEventListener(name) { listeners.delete(name); },
    emit(name) { const listener = listeners.get(name); if (listener) listener(); },
  };
}

function playableFile(name = 'track.mp3', identifier = 'item') {
  const files = requireFunction('listPlayableFiles')({
    metadata: {
      mediatype: 'audio',
      licenseurl: 'https://creativecommons.org/publicdomain/zero/1.0/',
    },
    files: [{ name, format: 'VBR MP3', size: '1024' }],
  }, identifier);
  assert.equal(files.length, 1, 'fixture must produce one allow-listed candidate');
  return files[0];
}

test('IA-01: query builder and offline fetch create Advanced Search request scoped to audio', async () => {
  const buildSearchUrl = requireFunction('buildSearchUrl');
  const url = new URL(buildSearchUrl('ambient music'));
  assert.equal(url.origin, 'https://archive.org');
  assert.equal(url.pathname, '/advancedsearch.php');
  assert.equal(url.searchParams.get('q'), 'mediatype:audio AND title:"ambient music"');
  assert.equal(url.searchParams.get('output'), 'json');
  assert.equal(url.searchParams.get('rows'), '20');
  assert.equal(url.searchParams.getAll('q').length, 1);

  const searchAudio = requireFunction('searchAudio');
  const docs = [{ identifier: 'sample-audio', title: 'Ambient Music' }];
  let requestUrl;
  let requestOptions;
  const results = await searchAudio('ambient music', {
    fetchImpl: async (input, init) => {
      requestUrl = input;
      requestOptions = init;
      return { ok: true, json: async () => ({ response: { docs } }) };
    },
  });
  assert.equal(requestUrl, buildSearchUrl('ambient music'));
  assert.equal(requestOptions.method, 'GET');
  assert.equal(requestOptions.mode, 'cors');
  assert.equal(requestOptions.credentials, 'omit');
  assert.deepEqual(results, docs);
  await assert.rejects(searchAudio('ambient music', {
    fetchImpl: async () => ({ ok: false, status: 503 }),
  }), /search failed \(503\)/i);
  await assert.rejects(searchAudio('ambient music', {
    fetchImpl: async () => ({ ok: true, json: async () => ({ response: { docs: {} } }) }),
  }), /invalid response/i);
  await assert.rejects(searchAudio('ambient music', {
    fetchImpl: async () => ({ ok: true, json: async () => { throw new Error('offline search JSON failure'); } }),
  }), /offline search JSON failure/);
});

test('IA-02: quoted title, boolean-looking text, and URL metacharacters remain one safe query value', () => {
  const buildSearchUrl = requireFunction('buildSearchUrl');
  const title = 'symphony " OR mediatype:movies & page=99';
  const url = new URL(buildSearchUrl(title));
  const q = url.searchParams.get('q');
  assert.match(q, /^mediatype:audio AND title:"/);
  assert.match(q, /\\"/);
  assert.match(q, /OR mediatype:movies & page=99/);
  assert.equal(url.searchParams.getAll('q').length, 1);
  assert.equal(url.searchParams.get('output'), 'json');
  assert.equal(url.searchParams.get('page'), '1');
  assert.equal(url.searchParams.get('rows'), '20');
});

test('IA-03: validated MP3 MIME type and IA MP3 descriptors are playable', () => {
  const isPlayableMp3 = requireFunction('isPlayableMp3');
  assert.equal(isPlayableMp3({ format: 'VBR MP3' }), true);
  assert.equal(isPlayableMp3({ format: '128Kbps MP3' }), true);
  assert.equal(isPlayableMp3({ format: 'MP3', mimetype: 'audio/mpeg' }), true);
  assert.equal(isPlayableMp3({ format: 'mp3', mimetype: ' AUDIO/MPEG ' }), true);
});

test('IA-04: MIDI, FLAC, WAV stems, and unrelated formats are rejected', () => {
  const isPlayableMp3 = requireFunction('isPlayableMp3');
  assert.equal(isPlayableMp3({ format: 'audio/midi', mimetype: 'audio/midi' }), false);
  assert.equal(isPlayableMp3({ format: 'FLAC', mimetype: 'audio/flac' }), false);
  assert.equal(isPlayableMp3({ format: '24bit WAV stem', mimetype: 'audio/wav' }), false);
  assert.equal(isPlayableMp3({ format: 'Ogg Vorbis', mimetype: 'audio/ogg' }), false);
  assert.equal(isPlayableMp3(null), false);
});

test('IA-05: file-size gate accepts up to 50 MiB and rejects anything larger', () => {
  const isWithinSizeLimit = requireFunction('isWithinSizeLimit');
  const limit = 50 * 1024 * 1024;
  assert.equal(isWithinSizeLimit(45 * 1024 * 1024), true);
  assert.equal(isWithinSizeLimit(limit), true);
  assert.equal(isWithinSizeLimit(limit + 1), false);
  assert.equal(isWithinSizeLimit(55 * 1024 * 1024), false);
  assert.equal(isWithinSizeLimit('1024'), true);
  assert.equal(isWithinSizeLimit(String(limit)), true);
  assert.equal(isWithinSizeLimit(String(limit + 1)), false);
  assert.equal(isWithinSizeLimit('unknown'), false);
  assert.equal(isWithinSizeLimit('1.5'), false);
  assert.equal(isWithinSizeLimit(-1), false);
});

test('IA-06: CC0 and Public Domain Mark 1.0 URLs are allowed', () => {
  const isAllowedLicense = requireFunction('isAllowedLicense');
  const listPlayableFiles = requireFunction('listPlayableFiles');
  assert.equal(isAllowedLicense('https://creativecommons.org/publicdomain/zero/1.0/'), true);
  assert.equal(isAllowedLicense('http://creativecommons.org/publicdomain/zero/1.0'), true);
  assert.equal(isAllowedLicense('https://creativecommons.org/publicdomain/mark/1.0/'), true);
  assert.equal(isAllowedLicense('http://creativecommons.org/publicdomain/mark/1.0'), true);

  const playable = listPlayableFiles({
    metadata: { mediatype: 'audio', licenseurl: 'https://creativecommons.org/publicdomain/zero/1.0/' },
    files: [
      { name: 'song.mp3', format: 'VBR MP3', size: '1024' },
      { name: 'too-large.mp3', format: 'VBR MP3', size: String(50 * 1024 * 1024 + 1) },
      { name: 'stems.flac', format: 'FLAC', size: '1024' },
      { name: '../unexpected.mp3', format: 'VBR MP3', size: '1024' },
    ],
  }, 'sample item');
  assert.deepEqual(playable.map(file => file.name), ['song.mp3']);
  assert.equal(Object.isFrozen(playable[0]), true, 'allow-list candidates are immutable capabilities');
  assert.equal(playable[0].url, 'https://archive.org/download/sample%20item/song.mp3');
  assert.deepEqual(listPlayableFiles({
    metadata: { mediatype: 'audio', licenseurl: 'https://creativecommons.org/publicdomain/zero/1.0/' },
    files: [{ name: 'song.mp3', format: 'VBR MP3', size: '1024' }],
  }, '..'), []);
  const malformedResponses = [
    null,
    [],
    { metadata: null, files: [] },
    { metadata: { mediatype: 'audio', licenseurl: 'https://creativecommons.org/publicdomain/zero/1.0/' }, files: null },
    { metadata: { mediatype: 'video', licenseurl: 'https://creativecommons.org/publicdomain/zero/1.0/' }, files: [{ name: 'song.mp3', format: 'VBR MP3', size: '1024' }] },
  ];
  for (const malformed of malformedResponses) assert.deepEqual(listPlayableFiles(malformed, 'sample'), []);
});

test('IA-07: missing, proprietary, unknown, and spoofed license URLs fail closed', () => {
  const isAllowedLicense = requireFunction('isAllowedLicense');
  const listPlayableFiles = requireFunction('listPlayableFiles');
  assert.equal(isAllowedLicense(''), false);
  assert.equal(isAllowedLicense(null), false);
  assert.equal(isAllowedLicense('https://creativecommons.org/licenses/by/4.0/'), false);
  assert.equal(isAllowedLicense('https://example.org/publicdomain/zero/1.0/'), false);
  assert.equal(isAllowedLicense('https://creativecommons.org.evil.invalid/publicdomain/zero/1.0/'), false);
  const file = { name: 'song.mp3', format: 'VBR MP3', size: '1024' };
  for (const licenseurl of ['', undefined, 'https://creativecommons.org/licenses/by/4.0/']) {
    assert.deepEqual(listPlayableFiles({ metadata: { mediatype: 'audio', licenseurl }, files: [file] }, 'sample'), []);
  }
  assert.deepEqual(listPlayableFiles({ metadata: { mediatype: 'audio' }, files: [file] }, 'sample'), []);
});

test('IA-08: metadata lookup and stream URL safely encode path segments', async () => {
  const buildAudioUrl = requireFunction('buildAudioUrl');
  const url = new URL(buildAudioUrl('item with spaces', 'live & rare?.mp3'));
  assert.equal(url.origin, 'https://archive.org');
  assert.equal(url.pathname, '/download/item%20with%20spaces/live%20%26%20rare%3F.mp3');
  assert.equal(url.search, '');
  assert.equal(url.hash, '');
  assert.equal(buildAudioUrl(' item ', ' track name.mp3 '), 'https://archive.org/download/%20item%20/%20track%20name.mp3%20');
  assert.throws(() => buildAudioUrl('..', 'song.mp3'), TypeError);
  assert.throws(() => buildAudioUrl('item', '..'), TypeError);
  assert.throws(() => buildAudioUrl('../other', 'song.mp3'), TypeError);

  const fetchMetadata = requireFunction('fetchMetadata');
  const payload = { metadata: { identifier: 'item with spaces', mediatype: 'audio' }, files: [] };
  let requestUrl;
  let requestOptions;
  const result = await fetchMetadata('item with spaces', {
    fetchImpl: async (input, init) => {
      requestUrl = input;
      requestOptions = init;
      return { ok: true, json: async () => payload };
    },
  });
  assert.equal(requestUrl, 'https://archive.org/metadata/item%20with%20spaces');
  assert.equal(requestOptions.credentials, 'omit');
  assert.deepEqual(result, payload);
  await assert.rejects(fetchMetadata('..', {
    fetchImpl: async () => { throw new Error('invalid identifier reached fetch'); },
  }), TypeError);
  await assert.rejects(fetchMetadata('missing-item', {
    fetchImpl: async () => ({ ok: false, status: 404 }),
  }), /metadata lookup failed \(404\)/i);
  await assert.rejects(fetchMetadata('malformed-item', {
    fetchImpl: async () => ({ ok: true, json: async () => [] }),
  }), /invalid response/i);
  await assert.rejects(fetchMetadata('broken-json-item', {
    fetchImpl: async () => ({ ok: true, json: async () => { throw new Error('offline metadata JSON failure'); } }),
  }), /offline metadata JSON failure/);
});

test('IA-09: player transitions correctly and ignores stale play completions', async () => {
  const createPlayer = requireFunction('createPlayer');
  const firstAudio = fakeAudio();
  const secondAudio = fakeAudio();
  const thirdAudio = fakeAudio();
  const fourthAudio = fakeAudio();
  let resolveFirst;
  let resolveSecond;
  let resolveFourth;
  firstAudio.play = () => new Promise(resolve => { resolveFirst = resolve; });
  secondAudio.play = () => new Promise(resolve => { resolveSecond = resolve; });
  fourthAudio.play = () => new Promise(resolve => { resolveFourth = resolve; });
  const audioElements = [firstAudio, secondAudio, thirdAudio, fourthAudio];
  const transitions = [];
  const player = createPlayer({ audioFactory: () => audioElements.shift(), onStateChange: state => transitions.push(state) });
  assert.equal(player.getState(), 'idle');
  player.load(playableFile('first.mp3'));
  assert.equal(player.getState(), 'loading');
  assert.equal(firstAudio.src, 'https://archive.org/download/item/first.mp3');
  firstAudio.listeners.get('canplay')();

  player.load(playableFile('second.mp3'));
  secondAudio.listeners.get('canplay')();
  resolveFirst();
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(player.getState(), 'loading', 'a stale first play promise cannot complete the second load');
  resolveSecond();
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(player.getState(), 'playing');
  secondAudio.emit('pause');
  assert.equal(player.getState(), 'idle', 'native pause event synchronizes the player state');

  player.load(playableFile('third.mp3'));
  thirdAudio.listeners.get('canplay')();
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(player.getState(), 'playing');
  thirdAudio.emit('ended');
  assert.equal(player.getState(), 'idle', 'native ended event returns the player to idle');

  player.load(playableFile('fourth.mp3'));
  fourthAudio.listeners.get('canplay')();
  player.pause();
  assert.equal(player.getState(), 'idle');
  resolveFourth();
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(player.getState(), 'idle', 'pause invalidates an outstanding play promise');
  assert.deepEqual(transitions, ['loading', 'playing', 'idle', 'loading', 'playing', 'idle', 'loading', 'idle']);

  const staleAudio = fakeAudio();
  const currentAudio = fakeAudio();
  let rejectStalePlay;
  staleAudio.play = () => new Promise((_, reject) => { rejectStalePlay = reject; });
  const staleElements = [staleAudio, currentAudio];
  const stalePlayer = createPlayer({ audioFactory: () => staleElements.shift() });
  assert.equal(stalePlayer.load(playableFile('stale-reject.mp3')), true);
  staleAudio.emit('canplay');
  assert.equal(stalePlayer.load(playableFile('current-after-reject.mp3')), true);
  currentAudio.emit('canplay');
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(stalePlayer.getState(), 'playing');
  rejectStalePlay(new Error('stale track rejected after replacement'));
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(stalePlayer.getState(), 'playing', 'a stale play rejection cannot overwrite the newer track state');

  const staleResolveAudio = fakeAudio();
  const currentAfterResolveAudio = fakeAudio();
  let resolveStalePlay;
  staleResolveAudio.play = () => new Promise(resolve => { resolveStalePlay = resolve; });
  const resolveElements = [staleResolveAudio, currentAfterResolveAudio];
  const resolvePlayer = createPlayer({ audioFactory: () => resolveElements.shift() });
  assert.equal(resolvePlayer.load(playableFile('stale-resolve.mp3')), true);
  staleResolveAudio.emit('canplay');
  assert.equal(resolvePlayer.load(playableFile('current-before-stale-resolve.mp3')), true);
  currentAfterResolveAudio.emit('canplay');
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(resolvePlayer.getState(), 'playing');
  resolveStalePlay();
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(resolvePlayer.getState(), 'playing', 'a stale play resolution after replacement cannot overwrite the newer playing state');
});

test('IA-10: player requires allow-listed candidates and handles malformed/error inputs safely', async () => {
  const createPlayer = requireFunction('createPlayer');
  let factoryCalls = 0;
  const guardedPlayer = createPlayer({ audioFactory: () => { factoryCalls += 1; return fakeAudio(); } });
  assert.equal(guardedPlayer.load('https://credentials@archive.org/download/item/audio.mp3'), false);
  assert.equal(guardedPlayer.load('https://archive.org/download/item/unlisted.mp3'), false, 'direct URL cannot bypass the allow-list');
  assert.equal(guardedPlayer.load({ url: 'https://archive.org/download/item/forged.mp3' }), false, 'forged candidate object cannot bypass the allow-list');
  assert.equal(factoryCalls, 0, 'credentialed URLs are rejected before constructing audio');
  assert.equal(guardedPlayer.getState(), 'error');
  assert.match(guardedPlayer.getErrorMessage(), /允许|验证|音频|链接/i);

  const unavailablePlayer = createPlayer({ audioFactory: () => null });
  assert.equal(unavailablePlayer.load(playableFile()), false);
  assert.equal(unavailablePlayer.getState(), 'error', 'missing audio implementation becomes a safe error state');

  const audio = fakeAudio();
  const transitions = [];
  const player = createPlayer({ audioFactory: () => audio, onStateChange: state => transitions.push(state) });
  assert.equal(player.load(playableFile('audio.mp3')), true);
  audio.emit('error');
  assert.equal(player.getState(), 'error');
  assert.equal(transitions.at(-1), 'error');
  assert.match(player.getErrorMessage(), /加载|播放|失败|无法/i);

  const rejectedAudio = fakeAudio();
  rejectedAudio.play = () => Promise.reject(new Error('private platform detail'));
  const rejectedPlayer = createPlayer({ audioFactory: () => rejectedAudio });
  assert.equal(rejectedPlayer.load(playableFile('rejected.mp3')), true);
  rejectedAudio.emit('canplay');
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(rejectedPlayer.getState(), 'error');
  assert.doesNotMatch(rejectedPlayer.getErrorMessage(), /private platform detail/);

  const throwingAudio = fakeAudio();
  throwingAudio.play = () => { throw new Error('private synchronous platform detail'); };
  const throwingPlayer = createPlayer({ audioFactory: () => throwingAudio });
  assert.equal(throwingPlayer.load(playableFile('throws.mp3')), true);
  throwingAudio.emit('canplay');
  assert.equal(throwingPlayer.getState(), 'error');
  assert.doesNotMatch(throwingPlayer.getErrorMessage(), /private synchronous platform detail/);
});
