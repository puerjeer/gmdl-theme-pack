# Internet Archive Discovery & Playback PoC Evidence
<!-- Project: gmdl-theme-pack-agent · Branch: project/antigravity-overhaul -->
<!-- Last updated: 2026-10-13 (Documentation Scope Rebaseline) -->

> [!NOTE]
> **PoC Research Notice:**
> This document records empirical and official API research supporting the future isolated
> proof-of-concept branch plan ([`docs/spec/IA-POC-BRANCH-PLAN.md`](../spec/IA-POC-BRANCH-PLAN.md)) ONLY.
> Internet Archive discovery and audio playback is **NOT part of the mainline product implementation**
> on `project/antigravity-overhaul` or `main`. It will never be merged into mainline production assets.

---

## 1. Overview & Purpose

This document compiles the evidence base for browser-side Internet Archive (IA)
discovery and audio playback, serving as background research for a commissioned current-run isolated
PoC branch (`poc/ia-audio-discovery`).

It strictly separates **official documentation facts** from **owner-provided empirical test evidence**.
It does not invent any unverified sample identifiers, direct download URLs, or assumed endpoint properties.

---

## 2. Official Internet Archive Documentation Facts

The following references define the documented public APIs of the Internet Archive:

1. **Advanced Search Documentation:**
   [https://archive.org/help/aboutsearch.htm](https://archive.org/help/aboutsearch.htm)
   - Documents search query syntax, field-specific queries (e.g. `mediatype:audio`, `collection:`, `title:`), boolean operators, and sorting.
   - Endpoint: `https://archive.org/advancedsearch.php`
   - Supports query parameters such as `q` (Lucene-style query string), `fl[]` (fields to return), `rows` (number of results), `page`, and `output=json`.

2. **Metadata API Overview:**
   [https://archive.org/developers/metadata.html](https://archive.org/developers/metadata.html)
   - Overview of the Internet Archive read/write metadata services.

3. **Metadata Read API:**
   [https://archive.org/developers/md-read.html](https://archive.org/developers/md-read.html)
   - Read endpoint format: `https://archive.org/metadata/{identifier}`
   - Official documented response JSON structure includes top-level keys:
     - `metadata`: object containing item attributes such as `title`, `creator`, `licenseurl`, `mediatype`, etc.
     - `files`: array of file descriptor objects, each including fields such as `name`, `format`, `size`, `source`, `md5`, `crc32`, `sha1`.
     - `server`, `dir`, `workable_servers`: download location routing data.
   - Read access is public and anonymous; no API keys, tokens, or credentials are required for metadata reading.

---

## 3. Owner-Provided Feasibility Evidence

Empirical testing conducted by the project owner established the following practical facts:

- **Anonymous Public Access:** Both Advanced Search (`advancedsearch.php?output=json`) and Metadata Read (`/metadata/{id}`) operate without authentication headers or API keys.
- **CORS Support:** Direct browser `fetch()` requests to `archive.org/advancedsearch.php` and `archive.org/metadata/{id}` succeed with appropriate CORS response headers, allowing client-side execution from arbitrary origins without server-side reverse-proxy forwarding.
- **Audio Stream Delivery:**
  - Direct audio file retrieval from IA storage nodes returns `HTTP 206 Partial Content` when requested with HTTP `Range` headers.
  - MIME type returned for MP3 assets was verified as `audio/mpeg`.
  - HTML5 `<audio>` playback operates natively over these standard HTTP Range/CORS streams.
- **Licensing Verification:**
  - Evaluated candidate metadata items returned explicit `licenseurl` metadata pointing to Public Domain Mark 1.0 (`http://creativecommons.org/publicdomain/mark/1.0/` or `https://...`).
  - No specific identifier or file download URL is permanently assumed; identifiers and file names are resolved dynamically via the Metadata Read API.

---

## 4. Design Assumptions (Adjustable v1 Model for Future PoC)

The following parameters are conservative v1 engineering assumptions established for safety in the isolated branch plan:

| Parameter | Value | Rationale |
|---|---|---|
| **Max file size threshold** | 50 MiB (52,428,800 bytes) | Prevents browser memory exhaustion, excessive mobile data usage, and prolonged buffering during interactive playback. Adjustable in future iterations. |
| **Playable audio format filter** | Validated MP3 (`format` in `["VBR MP3", "128Kbps MP3"]` or `audio/mpeg`) | MP3 playback is universal across modern browsers without transcoding; excludes exotic codecs, multichannel files, or multi-gigabyte lossless stems. |
| **License allow-list** | Public Domain Mark 1.0 (`publicdomain/mark/1.0`), CC0 (`publicdomain/zero/1.0`) | Guarantees clear legal basis for public listening without copyright ambiguity; fails closed (rejects) any item with missing or unrecognized license metadata. |

---

## 5. Wikimedia Commons Comparison & Deferral Rationale

Feasibility tests were also conducted by the project owner for Wikimedia Commons audio content.
The empirical findings were:

- **CORS / Range:** Browser-like `User-Agent` headers and CORS/Range requests succeeded against Wikimedia endpoints.
- **Format Inconsistency:** Wikimedia API search results returned non-playable MIDI assets and other non-standard formats alongside audio.
- **File Size Extremes:** A representative audio candidate tested was an uncompressed WAV file measuring ~154.7 MB, which is unsuitable for lightweight frontend streaming.
- **Decision:** Wikimedia Commons integration is **deferred**. It remains strictly gated and will not be considered or implemented until explicit filters for playable format, file size limits, and machine-verifiable licensing are fully specified and tested.
