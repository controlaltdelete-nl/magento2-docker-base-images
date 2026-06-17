# Task 003: Guarded Mailpit assertions in the test runner

**Status**: completed
**Depends on**: 001, 002
**Retry count**: 0

## Description
Add a Mailpit assertion block to `tests/run-tests.sh`. Static artifact checks (binary
present, supervisord program shipped + autostart false) run unconditionally; runtime
behavior checks (service running, mail captured via API, sendmail wiring) run only inside
a `[ "$ENABLE_MAILPIT" = "true" ]` guard, mirroring the Varnish block.

CRITICAL: the test runner executes INSIDE the container with only `tests/` mounted. The
`Dockerfile` is NOT present in the image, so you cannot grep it for the `EXPOSE` line.
Every existing assertion checks in-container state (config files, listening ports,
`supervisorctl status`). Verify ports the same way: when enabled, assert the SMTP and API
ports are actually bound/answering, not that they appear in a Dockerfile.

## Context
- Related files: `tests/run-tests.sh`
- Patterns to follow:
  - The Varnish guarded block (lines ~129-135) using
    `if [ "$ENABLE_VARNISH" = "true" ]` and `assert_contains "..." "RUNNING" supervisorctl status varnish`.
  - Helpers already defined: `assert`, `assert_contains`, `curl_retry`.
  - Existing port/config assertions style (grep against config files, curl against a port).
  - The supervisord conf is in the image at `/etc/supervisor/conf.d/mailpit.conf`; assert
    `autostart=false` by grepping that file (like the existing nginx/varnish conf checks),
    NOT the Dockerfile.
- For the "mail captured" check: send a message to `127.0.0.1:1025` then assert it appears
  in `http://localhost:8025/api/v1/messages`. Pick a sender that exists in-container:
  `swaks` is NOT installed, so do not rely on it. Prefer the Mailpit binary's own sendmail
  shim (`echo ... | /usr/local/bin/mailpit sendmail -S 127.0.0.1:1025 someone@example.com`)
  or a `php -r` `mail()` call (which only routes to Mailpit when sendmail_path is wired, so
  use that only inside the enabled guard). Confirm the chosen sender command against the
  installed binary before asserting.
  - The captured-mail assertion must allow for delivery latency: poll the API (reuse
    `curl_retry` against `/api/v1/messages`) and assert on the message count or subject
    rather than reading once immediately after send (avoids a flaky race).

## Requirements (Test Descriptions)
- [ ] `it asserts the mailpit binary is installed and runnable`
- [ ] `it asserts the mailpit supervisord program is shipped with autostart false`
- [ ] `it asserts mailpit is RUNNING under supervisord when ENABLE_MAILPIT is true`
- [ ] `it asserts the mailpit api answers on port 8025 when enabled`
- [ ] `it asserts the mailpit smtp port 1025 is listening when enabled`
- [ ] `it asserts a message sent to the smtp port is retrievable via the rest api when enabled`
- [ ] `it asserts sendmail_path reported by php -i points at the mailpit shim when enabled`
- [ ] `it asserts mailpit is not running and sendmail_path is unchanged when ENABLE_MAILPIT is unset`

## Acceptance Criteria
- All requirements have passing tests.
- The default (flag unset) suite passes unchanged; only the static Mailpit checks run.
- The `ENABLE_MAILPIT=true` suite passes with all runtime checks green.
- `shellcheck tests/run-tests.sh` passes.

## Implementation Notes
(Left blank - filled in by programmer during implementation)
