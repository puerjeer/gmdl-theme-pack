# Deployment Mock Harness — Independent Audit

**Date:** 2026-10-13 (UTC+08)
**Target:** `deploy.sh` and `scripts/deploy-mock.sh` on `project/antigravity-overhaul`
**Contract:** `docs/spec/modules/deploy.sh.md`; `docs/project/07-quality-test-plan.md`
**Scope:** Offline-only code and harness review; no production deployment, SSH, real service, or external network calls.

## TDD Red-State Evidence

- Before `deploy.sh` existed, the harness reported `Total=12 | Passed=0 | Failed=12`; each case stopped at the absent implementation. This was an implementation-absent expected-red state, not 12 executed behavioral failures.
- Stage 7 v2.0 added two assertions; red was `10/12`, isolating MOCK-04 status-command fail-closed and MOCK-09i positive lock-order evidence.
- Stage 7 v2.1 added two further assertions; red was `10/12`, isolating MOCK-03 optional-index-lock/index-invariance and MOCK-05 pulled-HEAD capture failure.

## Independent Findings and Remediation

| Cases | Verified assertions / remediation |
|---|---|
| MOCK-01 | Exact pull/reload argv, backup snapshot, core-step counts/order, and all three asset hashes before config replacement. |
| MOCK-02/03 | Lock contention refuses the second instance; the read-only descriptor targets the Git metadata directory; lock is reacquirable after success/failure/dry-run and no persistent lockfile is created. |
| MOCK-03 | Before dry-run, a tracked asset's mtime is forced stale; `.git/index` content hash and stat metadata are snapshotted. Status must log `GIT_OPTIONAL_LOCKS=0`; after dry-run both index bytes and metadata are unchanged, no index lock remains, and there are no backup/config/reload/pull/reset side effects. |
| MOCK-04 | Dirty working tree is rejected after lock acquisition and its intentional edit is preserved. A separate injected nonzero `git status --porcelain` with empty stdout must emit the specific fail-closed diagnostic and cause zero deployment side effects. |
| MOCK-05 | Pull failure leaves active config unchanged with no reset. A separate successful-pull/failed-`rev-parse HEAD` case must stop before hash/config/reload, emit manual-recovery guidance, and never reset an unknown pulled revision. A preflight backup may exist. |
| MOCK-06/07/10 | Byte-exact backup comparison, same-directory staging/rename calls, owner/group/mode checks, and rollback recovery syntax/reload order. This proves the program's same-directory rename path and content/metadata checks; it does **not** trace the kernel rename syscall or prove crash consistency. |
| MOCK-08 | Each zero/duplicate/empty asset-token fixture is validated before deployment; non-target assets retain expected tokens. |
| MOCK-09 | Assembled nginx argv, prefix variants, invalid/malformed include, non-executable `--nginx-bin`/`--reload-cmd`, missing `sha256sum`, and syntax-failure recovery. The missing-sha case positively verifies metadata lock before status and absence of any `REV_PARSE_HEAD` event; invalid preflight cases fail before pull/backup/config mutation. |
| MOCK-11/12 | Reset is permitted only for a clean tree with `HEAD == PULLED_HEAD`; dirty/drift cases refuse reset. |

### Follow-up Review Findings

An independent review identified that ordinary `git status --porcelain` could refresh Git's optional index stat cache, contradicting a strict no-filesystem-write dry-run. The implementation now invokes every status check with `GIT_OPTIONAL_LOCKS=0`. MOCK-03 forces a stale tracked-file mtime and verifies the index's bytes and metadata are identical before and after dry-run. The same review also found two low-severity assertion gaps: MOCK-09i did not assert absence of `PRE_HEAD` capture, and a failed immediate `PULLED_HEAD` capture lacked a specific recovery boundary. MOCK-09i now asserts no `REV_PARSE_HEAD`; MOCK-05 tests capture failure and the script explicitly stops before hashes/config mutation without attempting an unsafe reset.

Earlier review findings were also remediated: missing `sha256sum` is rejected before state capture/backup/pull; `git status` errors with empty stdout fail closed; lock-before-status is directly asserted.

## Latest Offline Results

- v2.1 TDD red: `10/12` passed; only MOCK-03 and MOCK-05 new assertions failed.
- v2.1 green: `bash -n deploy.sh`, `bash -n scripts/deploy-mock.sh`, and `bash scripts/deploy-mock.sh` passed; `Total=12 | Passed=12 | Failed=0` at 2026-10-13 06:25:40 UTC+08.
- Independent final review at 2026-10-13 06:30:57 UTC+08: no medium/high issue; deployment safety invariants, all 12 mock cases, full smoke, and `git diff --check` were verified. A low test-hygiene observation identified helper `git status` calls in temporary repos; all six are now invoked with `GIT_OPTIONAL_LOCKS=0`, matching the deployed script's read-only status policy.
- Post-review hygiene recheck at 2026-10-13 06:33:09 UTC+08: `bash scripts/smoke.sh` passed 10/0, including baseline 8/8, UI enhancement 29/29, and deployment mocks 12/12; the helper-only change did not alter deployment behavior.
- Final smoke after schedule and review-status documentation sync at 2026-10-13 06:35:54 UTC+08: `bash scripts/smoke.sh` passed 10/0, including baseline 8/8, enhancement 29/29, and deployment 12/12.
- A further full smoke and explicit `git diff --check` passed at 2026-10-13 06:38:05 UTC+08 after all current documentation updates.

The harness uses temporary directories, local bare Git repositories/clones, local vhost/main config fixtures, and PATH-instrumented command wrappers. It does not validate a production host, real OpenResty configuration, actual service reload, remote connectivity, or crash consistency. Production execution remains unauthorized and unperformed.
