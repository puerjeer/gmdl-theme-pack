# Module Contracts Index
<!-- Project: gmdl-theme-pack-agent · Branch: project/antigravity-overhaul -->
<!-- Stage: Task 2 — Module Index (Canonical) -->
<!-- Date: 2026-10-13 -->

This document serves as the canonical index for the per-module interface contracts defined under `docs/spec/modules/`.
Each specification details public interfaces, DOM mutations, configuration directives, and observable acceptance criteria.

---

## 1. Module Contracts Index

| Module Target | Specification Path | Role / Purpose | Status / Behavior |
|---|---|---|---|
| `gmdl-dark.css` | [`modules/gmdl-dark.css.md`](modules/gmdl-dark.css.md) | Dual-mode glass styling stylesheet, dark theme variables, responsive layout rules, touch ergonomics | Enhancements in Work Packages B & C |
| `gmdl-ui.js` | [`modules/gmdl-ui.js.md`](modules/gmdl-ui.js.md) | Core UI manager: floating personalization region, keyboard accessibility, preference export/import schema | Enhancements in Work Packages B, C, D |
| `gmdl-feat.js` | [`modules/gmdl-feat.js.md`](modules/gmdl-feat.js.md) | Feature pack: daily recommended songs button, blank-query search pagination | **Unchanged Behavior** |
| `openresty-vhost-example.conf` | [`modules/openresty-vhost-example.conf.md`](modules/openresty-vhost-example.conf.md) | Reference OpenResty vhost configuration: reverse proxy pass, caching directives, `sub_filter` asset injection | Deployment integration in Work Package A |
| `deploy.sh` | [`modules/deploy.sh.md`](modules/deploy.sh.md) | Reversible automated deployment script: preflight, pull, asset hashing, atomic config updates, syntax validation, reload, safe rollback | New script in Work Package A |

---

## 2. Decoupled Subsystems (Not in Mainline Modules)

| Candidate / Plan | Specification Path | Policy |
|---|---|---|
| `poc/ia-audio-discovery` | [`IA-POC-BRANCH-PLAN.md`](IA-POC-BRANCH-PLAN.md) | Decoupled; commissioned for this current run; implementation after Task 3 gate on isolated branch only; zero mainline code |
| Wikimedia Commons | [`../project/02-scope.md`](../project/02-scope.md) | Deferred; gated on format, size, and licensing |
