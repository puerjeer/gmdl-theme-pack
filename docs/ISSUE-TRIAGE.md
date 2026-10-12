# Issue Triage — go-music-dl Upstream Issues
<!-- Project: gmdl-theme-pack-agent · Branch: project/antigravity-overhaul -->
<!-- Last updated: 2026-10-13 (Documentation Scope Rebaseline) -->

## Purpose

This document records the triage disposition for five upstream
[go-music-dl](https://github.com/guohuiyuan/go-music-dl) issues reviewed by
the project owner before implementation began.

**None of these issues become implementation tasks in this project.**

---

## Issue Dispositions

### [#242](https://github.com/guohuiyuan/go-music-dl/issues/242) — Upstream bug

- **Disposition:** ✅ Resolved upstream — no UI action needed
- **Detail:** Fixed in go-music-dl v1.1.1. The upstream release resolves the
reported behaviour. No change to theme pack code is required or appropriate.

---

### [#243](https://github.com/guohuiyuan/go-music-dl/issues/243) — API support question

- **Disposition:** ⏸ Not ready — deferred
- **Detail:** No reproducible UI requirement has been identified. The issue likely
relates to source-level or API-level support rather than frontend behaviour.
Deferred pending upstream clarification or a concrete, reproducible UI spec.

---

### [#205](https://github.com/guohuiyuan/go-music-dl/issues/205) — Per-source quality

- **Disposition:** 🚫 Out of scope — backend/source concern
- **Detail:** Per-source quality and codec behaviour is determined server-side and
by the upstream source APIs. This is not addressable from the browser-injected
theme pack layer. No frontend action.

---

### [#220](https://github.com/guohuiyuan/go-music-dl/issues/220) — Authoritative server-side download state

- **Disposition:** 🚫 Out of scope — server-side concern
- **Detail:** Authoritative download queue and file download state is managed server-side by
go-music-dl (not general frontend playback state). The theme pack has no authority over or
visibility into that backend download process from the browser layer. No frontend action.

---

### [#233](https://github.com/guohuiyuan/go-music-dl/issues/233) — Source-match behaviour

- **Disposition:** ⏸ Not ready — deferred
- **Detail:** Reproducible steps and a defined source-match contract are not
available. Without these, no UI behaviour can be specified or tested. Deferred
pending upstream clarification or owner-provided repro.

---

## Summary Table

| Issue | Title / Topic | Disposition | Action |
|---|---|---|---|
| [#242](https://github.com/guohuiyuan/go-music-dl/issues/242) | Upstream bug | Resolved in v1.1.1 | None |
| [#243](https://github.com/guohuiyuan/go-music-dl/issues/243) | API support | Not ready | Defer |
| [#205](https://github.com/guohuiyuan/go-music-dl/issues/205) | Per-source quality | Out of scope (backend) | None |
| [#220](https://github.com/guohuiyuan/go-music-dl/issues/220) | Server-side download state | Out of scope (backend download state) | None |
| [#233](https://github.com/guohuiyuan/go-music-dl/issues/233) | Source-match behaviour | Not ready | Defer |

---

## Re-evaluation Criteria

An issue may be re-opened as an implementation task only if the owner provides
explicit written direction, a reproducible scenario, and a defined UI acceptance
criterion. None currently meet this bar.
