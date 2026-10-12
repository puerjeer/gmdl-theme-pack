# Upstream Provenance for the Real-Page Visual Gate

**Recorded:** 2026-10-13 UTC+08
**Purpose:** Evidence for the accepted authentic-page loopback procedure in [`docs/project/07-quality-test-plan.md`](../project/07-quality-test-plan.md) §6. This is test provenance only; it does not alter or build upstream Go source.

## Official Release and Verified Asset

- Official release page: <https://github.com/guohuiyuan/go-music-dl/releases/tag/v1.1.1>
- Official GitHub release API: <https://api.github.com/repos/guohuiyuan/go-music-dl/releases/tags/v1.1.1>
- Tag: `v1.1.1`, published `2026-09-17T02:35:29Z`.
- Asset: `go-music-dl_linux_amd64.tar.gz`; GitHub API size: `11,730,419` bytes.
- API-published digest: `sha256:be7b828096a23b7401d69649484ece667ed588116a6039bb8f55e0f4df7c5949`.
- Downloaded using the enabled GitHub connector to `/tmp/gmdl-upstream-v1.1.1/go-music-dl_linux_amd64.tar.gz`; local `sha256sum` matched the API digest exactly at 2026-10-13 04:29:44 UTC+08. The archive member list was inspected before extraction; only `LICENSE`, `README.md`, and `music-dl` were present. The verified binary was extracted to `/tmp/gmdl-upstream-v1.1.1/extracted/music-dl`; `file` identified a statically linked x86-64 ELF.

## Documented Route and Loopback Binding

- Version-pinned README: <https://github.com/guohuiyuan/go-music-dl/blob/v1.1.1/README.md>
  - Documents `./music-dl web`, default route `/music`, default port `8080`, and the `--port` option (the Docker example uses `./music-dl web --port 8080 --no-browser`).
- Version-pinned CLI source: <https://github.com/guohuiyuan/go-music-dl/blob/v1.1.1/cmd/music-dl/web.go>
  - Advertises `--port`; source shows the hidden `--desktop` flag routes to `web.StartDesktop(port)`.
- Version-pinned server source: <https://github.com/guohuiyuan/go-music-dl/blob/v1.1.1/internal/web/server.go>
  - `StartDesktop` sets `ListenHost: "127.0.0.1"`; the listener is opened using `net.Listen("tcp", opts.ListenHost + ":" + port)`. Thus the documented/tested loopback-only invocation is `music-dl web --desktop --port <free-port>`; it does not bind to `0.0.0.0`.
- The binary's `./music-dl web --help` was inspected after digest verification; it reported the `--port` flag, default `8080`, and default base path `/music`. The hidden `--desktop` flag was cross-checked against the version-pinned source above.

## Proxy Capability

- Installed Ubuntu `nginx-extras` `1.24.0-2ubuntu7.18` for local-only verification; `nginx -V` reports `--with-http_sub_module`.
- Existing `/usr/sbin/policy-rc.d` returns `101`, preventing package installation from auto-starting a system-wide nginx service. At the check time, no nginx process was running.
- The test proxy uses a temporary config/prefix and binds only to `127.0.0.1`. Any local upstream/proxy execution remains separate from production; do not search, download, or play music during visual capture.

## Baseline Capture Execution

- **Capture time:** 2026-10-13 04:39:20 UTC+08 (manifest UTC timestamp `2026-10-12T20:39:20.958Z`).
- **Upstream process:** `/tmp/gmdl-upstream-v1.1.1/extracted/music-dl web --desktop --port 50765`; source-verified desktop mode binds `127.0.0.1` only.
- **Proxy:** nginx-extras with `sub_filter`, temporary prefix under `/tmp/gmdl-visual-Ed5WCgWtduzIGX0xtlPLoh/nginx`, proxy `127.0.0.1:36935`; the temporary configuration passed `nginx -t` and injection/assets were health-checked.
- **Browser:** `/usr/bin/chromium` 151.0.7922.34, headless, device scale factor 1, persistent test profile `/tmp/gmdl-visual-Ed5WCgWtduzIGX0xtlPLoh/chrome-profile`; non-loopback origins were blocked.
- **Baseline assets:** materialized from repository baseline `126853a`; per-file hashes and state details are recorded in `/workspace/gmdl-theme-pack-visual-evidence/manifest-before.json`.
- **Captures:** all 11 required baseline conditions (VIS-01 3 viewports, VIS-02 3, VIS-03 2, VIS-04 3) were captured as authentic screenshots under `/workspace/gmdl-theme-pack-visual-evidence/`, outside the Git worktree.
- **Gate status:** before-state capture complete; matching after-state captures and review are recorded below. The initial after attempt exposed a panel/launcher pointer overlap at 320×568 and stopped before creating any after image. Antigravity made a CSS-only positioning correction; independent five-viewport Chromium geometry/pointer checks and a real keyboard test then passed before the paired recapture.

## Matched After Capture, Browser Checks & Visual Review

- **Final capture time:** 2026-10-13 05:26:48 UTC+08 (manifest UTC timestamp `2026-10-12T21:26:48.913Z`), recaptured after the final 44×44 swatch-hitbox remediation.
- **Same test surface:** digest-verified upstream v1.1.1 on `127.0.0.1:50765`, the same localhost nginx proxy on `127.0.0.1:36935`, Chromium 151.0.7922.34, device scale factor 1, persistent profile, `/music` route, and blocked non-loopback origins.
- **Enhanced assets:** `gmdl-dark.css` SHA-256 `2c1db2ab043acde6969d1452f03fc9981c8a6dd4347db26cf85939801524f19a`; `gmdl-ui.js` `7049516f514daf17de13347163768d055ccda5ac1544cfed898fd6fc6a06a4f1`; `gmdl-feat.js` `05e5d4ab37a89ef3d0808a00765ef4bec3f7dc42998bc4bd263b7628b12d2857` (byte-identical to baseline).
- **Captures:** 11/11 after-state screenshots at the same VIS-01..04 matrix; `/workspace/gmdl-theme-pack-visual-evidence/manifest-after.json` records exact PNG hashes, dimensions, states, asset hashes, browser, and route. The verifier confirmed all 22 before/after PNG SHA-256 values, all 11 paired keys/dimensions, and zero horizontal overflow in every capture state. `browser-audit.json` stores the final geometry, 44px hitbox, pointer, and keyboard results.
- **Responsive/pointer/touch verification:** at `320×568`, `375×812`, `390×844`, `768×1024`, and `1280×800`, panel and launcher rectangles did not intersect, `documentElement.scrollWidth` and `body.scrollWidth` exactly matched viewport width, and a real Playwright pointer click closed the panel in every viewport. All 30 visible interactive controls measured at least 44×44px in each viewport; all 10 swatches per viewport passed real hit tests at the four outer edge offsets. The earlier 46px overlapping swatch target was removed by using a 2px border with no overlaid expansion.
- **Keyboard verification:** final Chromium rerun: Enter opened the panel and set `aria-expanded=true`; Tab moved to `深色` then `浅色`, with `:focus-visible` and a computed 2px outline; Escape closed the panel, set `aria-expanded=false`, and returned focus to `#gmdl-ui-btn`.
- **Visual review:** all 11 latest before/after pairs were inspected. Dark-glass renders at 390×844 and 1280×800 are pixel-identical; the 320×568 dark pair differs in only 50 RGB pixels (mean absolute channel difference `0.00044`), a minor raster/antialiasing variation with no visible layout or style regression on side-by-side review. Light-glass changes are intentional; compact panels remain within viewport and export/import controls are reachable by panel scrolling. The expected accessible import-error message is present in all 3 VIS-04 after captures. Before and after manifests report the same blocked origin (`https://cdn.jsdelivr.net`); no off-origin resources were allowed.
- **Gate status:** local authentic-page before/after visual regression gate **PASS**. This does not claim physical-device, live-production-site, or production-vhost validation.

The initial provenance note above predates service startup; the execution records supersede only its pre-execution status. No upstream Go source was modified.
