# IA Audio Discovery PoC — Current-Run Isolated Branch Plan
<!-- Project: gmdl-theme-pack-agent -->
<!-- Target Branch: poc/ia-audio-discovery (Current Run, Isolated) -->
<!-- Date: 2026-10-13 -->

> [!IMPORTANT]
> **Authoritative Commissioning Notice (Current Run):**
> Internet Archive (IA) audio discovery is **commissioned for THIS active project run** on its own dedicated,
> isolated branch: `poc/ia-audio-discovery`. This instruction supersedes all prior notes describing it as merely future or deferred.
> **Strict Mainline Isolation Invariant:**
> - IA code, tests, and DOM assets shall remain **completely isolated from `main`**.
> - **NEVER merge or push IA code to `main`**.
> - Work is planned as a fresh isolated branch/worktree branched from baseline `126853a`.
> - Do **NOT** inspect, read, copy, or modify the exploratory `/workspace/gmdl-theme-pack-poc` worktree.
> - Implementation executes strictly **after** Task 2 coordinator review, Stage 7 test-plan, and smoke gates pass.
> - Independent PoC acceptance tests (`gmdl-ia.test.js`) are required. After coordinator acceptance and owner review/approval of the exact final payload, the coordinator will report whether the isolated branch push to `poc/ia-audio-discovery` succeeds.
> - Wikimedia Commons integration remains **strictly deferred**.

---

## 1. Context & Research Foundation

This PoC branch plan builds upon documented public API facts and empirical research recorded in [`docs/research/IA-POC-EVIDENCE.md`](../research/IA-POC-EVIDENCE.md):
- **API Endpoints:**
  - Advanced Search: `https://archive.org/advancedsearch.php` (anonymous, CORS-enabled, JSON output).
  - Metadata Read: `https://archive.org/metadata/{identifier}` (anonymous, CORS-enabled).
  - Audio Streaming: `https://archive.org/download/{identifier}/{filename}` (supports HTTP 206 `Range` requests, native HTML5 `<audio>` playback).
- **Conservative Guardrails:**
  - Maximum audio file size: 50 MiB (52,428,800 bytes) threshold to prevent client memory stalls.
  - Formats: Validated MP3 (`audio/mpeg`, `VBR MP3`, `128Kbps MP3`).
  - Licensing allow-list: Public Domain Mark 1.0 and Creative Commons Zero (CC0) only; fails closed (rejects) for any unknown or missing licenses.

---

## 2. Target Branch Isolation & Execution Boundaries

- **Target Branch Name:** `poc/ia-audio-discovery`
- **Base Commit:** Branched freshly from authorized baseline `126853a`.
- **Workspace Mode:** Isolated Git worktree / branch mode (never touching `/workspace/gmdl-theme-pack-poc`).
- **Push Destination:** Remote branch `poc/ia-audio-discovery` only; push remains pending coordinator acceptance and owner review/approval of the exact final payload.
- **Zero Contamination of `main`:**
  - Mainline reverse proxy configurations (`openresty-vhost-example.conf`) must not reference `gmdl-ia.js`.
  - Mainline test suites (`gmdl-ui.test.js`) and smoke scripts remain 100% free of IA dependencies.
  - Zero IA code shall ever be merged into `main`.

---

## 3. Current-Run Implementation Work Package (Sequenced Post-Gate)

Execution commences strictly after Task 2 review approval and Stage 7 (`07-quality-test-plan.md`) + smoke script verification:

### Phase A: Isolated Unit Test Suite (`gmdl-ia.test.js`)
Deterministic unit tests covering client-side logic without network requests:
1. `IA-01`: Query builder constructs valid IA search URLs with encoded parameters (`mediatype:audio`).
2. `IA-02`: Search parameters handle special characters and boolean syntax safely.
3. `IA-03`: Format filter accepts standard MP3 MIME types and IA format descriptors.
4. `IA-04`: Format filter rejects non-streamable or exotic formats (MIDI, WAV stems, FLAC).
5. `IA-05`: File size gate accepts files ≤ 50 MiB and rejects files > 50 MiB.
6. `IA-06`: License validator accepts CC0 and Public Domain Mark 1.0 URLs.
7. `IA-07`: License validator fails closed (rejects) on missing, proprietary, or unrecognized licenses.
8. `IA-08`: Audio stream URL constructor preserves and percent-encodes meaningful leading, trailing, and internal spaces in safe filenames/identifiers; traversal and separator segments are rejected. Metadata/search tests cover HTTP and JSON parse failures.
9. `IA-09`: Client player accepts only an unmodified playable-file candidate returned by `listPlayableFiles` (never an arbitrary URL); state transitions `idle → loading → playing`, native `pause`/`ended` events return the current track to idle, and stale play-promise resolution **or rejection after the newer track reaches `playing`** cannot overwrite that current state.
10. `IA-10`: Client player fails closed on direct, forged, or credentialed URLs and malformed media inputs; synchronous `play()` throws, rejected playback promises, and media errors transition `loading → error` with a user-safe notice. Search and metadata HTTP/JSON failures must also be handled explicitly by offline tests.

### Phase B: Standalone Adapter Module (`gmdl-ia.js`)
- Client-side JavaScript module with zero npm dependencies and zero modifications to upstream Go source.
- Uses native browser `fetch()` and HTML5 `<audio>` elements.
- Encapsulated namespace or ES module avoiding pollution of existing `gmdl-ui.js` / `gmdl-feat.js` globals.
- The player must require the exact candidate object issued by the allow-list validator; playback URLs cannot bypass license, MIME, size, or path-segment filtering through the public player API.

### Phase C: Acceptance Verification & Branch Push
- Execute `node --test gmdl-ia.test.js` (must pass 10/10).
- Verify `node --check gmdl-ia.js` (clean exit 0).
- After coordinator acceptance and owner review/approval of the exact final payload, perform the host-side push to origin `poc/ia-audio-discovery`.
- Formally report whether the separate branch push succeeds.

---

## 4. Wikimedia Commons Gate Status

Wikimedia Commons remains **strictly deferred** across all branches.
Re-evaluation requires verified format filters excluding MIDI, verified size caps excluding large uncompressed files, and machine-verifiable licensing.
