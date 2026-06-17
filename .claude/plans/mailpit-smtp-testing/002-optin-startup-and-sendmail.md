# Task 002: Opt-in startup and sendmail_path wiring in service scripts

**Status**: completed
**Depends on**: 001
**Retry count**: 0

## Description
Wire Mailpit into the runtime scripts following the Varnish opt-in pattern. When
`ENABLE_MAILPIT=true`, `start-services` starts the Mailpit supervisord program, waits for
its API to be ready, and renders `sendmail_path` so PHP `mail()` is captured. When the
flag is unset, nothing changes. All service-script edits for this feature live here so no
other task touches the scripts.

## Context
- Related files:
  - `scripts/start-services` (gate on `ENABLE_MAILPIT`, render `sendmail_path` before the
    `supervisord -n` launch on line 34, then `supervisorctl start mailpit` + readiness
    wait after the Elasticsearch block, near the Varnish block lines 88-93)
  - `scripts/stop-services` (stop mailpit when enabled, before the supervisord shutdown,
    mirroring the Varnish stop at lines 6-8)
- CRITICAL conf.d path gotcha:
  - The PPA PHP (Ondřej Surý) scans `/etc/php/${PHP_VERSION}/fpm/conf.d/` and
    `/etc/php/${PHP_VERSION}/cli/conf.d/`. It does NOT scan `/usr/local/etc/php/conf.d/`.
    Do NOT imitate the existing `memory-limit-php.ini` COPY target (line 188), which uses
    `/usr/local/etc/php/conf.d/` and is effectively dead config for PPA PHP. Writing the
    sendmail ini there would silently fail the wiring and the Task 003 `php -i` assertion.
  - Render the ini into BOTH SAPI conf.d dirs at runtime using the same glob style the
    pool sed uses (`/etc/php/*/fpm/pool.d/` on line 31). Write to
    `/etc/php/*/fpm/conf.d/` AND `/etc/php/*/cli/conf.d/` (e.g. a
    `zz-mailpit-sendmail.ini` with `sendmail_path = "..."`). FPM must be written before
    line 34 so php-fpm picks it up at boot; CLI matters because Task 003 verifies via
    `php -i` (the CLI SAPI) and because Magento cron/CLI mailers use it.
  - `sendmail_path` is `PHP_INI_SYSTEM`, so a conf.d ini is the correct mechanism; do not
    try to set it via an FPM pool `php_admin_value`.
- Patterns to follow:
  - Varnish startup in `start-services` (lines 88-93): `if [ "$ENABLE_VARNISH" = "true" ]`
    then `supervisorctl start varnish`.
  - The runtime sed/`mkdir` rendering done before `supervisord -n` (lines 19-32) for
    nginx/php-fpm config — the sendmail ini render belongs in this pre-boot section.
  - `sendmail_path` value: confirm the exact Mailpit sendmail subcommand flag against the
    installed binary before wiring (recent Mailpit uses `mailpit sendmail -S host:port`;
    older docs show `--smtp-addr`). Run `mailpit sendmail --help` in the built image to
    pin the correct flag, then use e.g. `/usr/local/bin/mailpit sendmail -S 127.0.0.1:1025`.
  - Readiness wait: poll `http://localhost:8025/readyz` with a bounded retry loop. CRITICAL:
    the script runs under `set -e`, so a failing poll command must NOT abort the script.
    Mirror the Elasticsearch loop (lines 69-86): put the probe inside an `if curl -s -f
    ...; then break; else count++; sleep 1; fi` so a non-zero curl exit is swallowed by the
    `if`. Do not use a bare `curl -f` statement under `set -e`.
- Quote all variable expansions; keep `set -e` semantics intact.

## Requirements (Test Descriptions)
- [ ] `it starts mailpit only when ENABLE_MAILPIT is true`
- [ ] `it leaves mailpit stopped when ENABLE_MAILPIT is unset`
- [ ] `it waits for the mailpit api to become ready before continuing`
- [ ] `it renders sendmail_path into the fpm and cli conf.d dirs before php-fpm starts when enabled`
- [ ] `it does not render sendmail_path when ENABLE_MAILPIT is unset`
- [ ] `it stops mailpit on shutdown when ENABLE_MAILPIT is true`
- [ ] `it does not abort start-services if the mailpit readiness probe fails a poll (set -e safe)`

## Acceptance Criteria
- All requirements have passing tests (assertions land in Task 003).
- `shellcheck scripts/start-services scripts/stop-services` passes.
- Default run (flag unset) behaves identically to today: no Mailpit, no sendmail change.
- With the flag set, `php -i` (CLI SAPI) reports the Mailpit `sendmail_path`, and the ini
  exists under `/etc/php/*/fpm/conf.d/` and `/etc/php/*/cli/conf.d/`.

## Implementation Notes
(Left blank - filled in by programmer during implementation)
