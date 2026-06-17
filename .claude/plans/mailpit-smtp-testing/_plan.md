# Plan: Mailpit SMTP Testing Tool

## Created
2026-06-17

## Status
completed

## Objective
Bundle Mailpit (SMTP catcher with web UI + REST API) into the base image as an opt-in
service so Magento CI pipelines can capture and assert on outgoing email without sending
it externally.

## Related Issues
none

## Discovery Notes
The image has two service tiers. Core services (MySQL, Elasticsearch, Redis, PHP-FPM,
nginx) are `autostart=true` via their own `templates/supervisord/*.conf`. Optional
services follow the Varnish pattern: `autostart=false`, gated behind an env var
(`ENABLE_VARNISH=true`), started explicitly in `scripts/start-services`, asserted in a
guarded block of `tests/run-tests.sh`, and exercised by a dedicated CI run in
`.github/workflows/build-php-images.yml`.

Mailpit was chosen over MailHog (unmaintained) and Mailcatcher/smtp4dev (heavier
runtimes): it is a single static Go binary with no runtime dependencies, a tiny memory
footprint, and an SMTP listener + web UI + REST API. The REST API is what makes it
valuable in CI (`/api/v1/messages` lets a pipeline assert on captured mail).

Resolved during clarification:
- Tool: Mailpit.
- Startup: opt-in via `ENABLE_MAILPIT=true`, mirroring the Varnish pattern.
- PHP integration: also wire `sendmail_path` to Mailpit's sendmail shim so native PHP
  `mail()` is captured, in addition to exposing the SMTP port for Magento SMTP modules.
- Ports: SMTP `1025`, web UI/API `8025`, bound to `0.0.0.0`.
- Install: pinned static binary via a `MAILPIT_VERSION` build arg (default `1.30.2`,
  release tag `v1.30.2`), downloaded from the GitHub release tarball and verified, with
  cleanup in the same `RUN` layer.
- Storage: in-memory ephemeral, no auth (CI-appropriate).
- The `sendmail_path` ini is rendered at runtime in `start-services` only when
  `ENABLE_MAILPIT=true`, before supervisord launches php-fpm, so it never points at a
  Mailpit that is not running.
- The ini must land in the PPA conf.d dirs (`/etc/php/*/fpm/conf.d/` and
  `/etc/php/*/cli/conf.d/`), NOT `/usr/local/etc/php/conf.d/` (which PPA PHP does not scan;
  the existing `memory-limit-php.ini` lives there and is effectively inert).

## Scope

### In Scope
- Install a pinned Mailpit static binary in the Dockerfile, parameterized by a
  `MAILPIT_VERSION` build arg.
- A `templates/supervisord/mailpit.conf` program block (`autostart=false`) binding SMTP
  to `0.0.0.0:1025` and the UI/API to `0.0.0.0:8025`.
- `EXPOSE` ports `1025` and `8025`.
- Opt-in startup wiring in `scripts/start-services` gated by `ENABLE_MAILPIT=true`,
  including a readiness wait on the API and graceful handling in `scripts/stop-services`.
- Render `sendmail_path` (php-fpm + cli) to the Mailpit sendmail shim at runtime when
  `ENABLE_MAILPIT=true`, before supervisord boots php-fpm.
- A guarded Mailpit assertion block in `tests/run-tests.sh`.
- A dedicated `ENABLE_MAILPIT=true` CI run in the build workflow.
- README and architecture documentation updates (ports table, env var, services list).

### Out of Scope
- Persisting captured mail across container restarts (in-memory only).
- Mailpit UI authentication / TLS.
- Auto-configuring Magento's own SMTP transport settings (downstream points its SMTP
  module at `localhost:1025`).
- Multi-architecture (arm64) binary selection beyond what CI builds today.

## Success Criteria
- [ ] With `ENABLE_MAILPIT=true`, Mailpit runs and its API answers on `8025`.
- [ ] With `ENABLE_MAILPIT` unset, Mailpit does not run and no extra ports are bound.
- [ ] A mail sent to `127.0.0.1:1025` is retrievable via the REST API.
- [ ] PHP `mail()` is captured by Mailpit when `ENABLE_MAILPIT=true`.
- [ ] The default (Mailpit-off) test run is unaffected.
- [ ] All tests passing in both default and `ENABLE_MAILPIT=true` CI variants.
- [ ] Code follows project standards.

## Task Overview
| Task | Description | Depends On | Status |
|------|-------------|------------|--------|
| 001 | Install Mailpit binary, supervisord program, expose ports | - | completed |
| 002 | Opt-in startup + sendmail_path wiring in service scripts | 001 | completed |
| 003 | Guarded Mailpit assertions in the test runner | 001, 002 | completed |
| 004 | Add ENABLE_MAILPIT CI test run | 003 | completed |
| 005 | Update README and architecture docs | 002, 003 | completed |

## Architecture Notes
- Follow the Varnish opt-in pattern exactly: `autostart=false` in the supervisord conf,
  `supervisorctl start mailpit` from `start-services` only when the flag is set, and a
  test block guarded by `[ "$ENABLE_MAILPIT" = "true" ]`.
- Keep all Dockerfile-touching changes (binary install, `COPY` of the supervisord conf,
  `EXPOSE`) inside Task 001 so parallel workers never edit the Dockerfile concurrently.
- Keep all service-script changes (`start-services`, `stop-services`, `sendmail_path`
  rendering) inside Task 002 for the same reason.
- Render `sendmail_path` before the `supervisord -n` launch line (start-services line 34)
  so php-fpm picks it up, into both the fpm and cli conf.d dirs.
- Pin the binary by version arg and verify the download with the release `checksums.txt`
  (`sha256sum -c`); clean up tarball and checksums in the same `RUN`. No "latest" URL.
- The test runner runs INSIDE the container with only `tests/` mounted; the Dockerfile is
  not present. Assert ports by checking they are bound/answering, never by grepping EXPOSE.
- Readiness/probe loops in start-services run under `set -e`; wrap the probe in an `if`
  (mirror the Elasticsearch loop) so a failing poll cannot abort the script.

## Risks & Mitigations
- Mailpit release URL/version drift: pinned to `MAILPIT_VERSION=1.30.2` (tag `v1.30.2`);
  no "latest" URL, so the build is reproducible.
- Architecture mismatch (arm64 vs amd64): default to the `linux-amd64` asset to match
  what CI builds; note arm64 as a follow-up if needed.
- `sendmail_path` pointing at a stopped Mailpit: only render it when `ENABLE_MAILPIT=true`
  and before php-fpm starts, so native `mail()` never targets a dead listener.
- Port collision: `1025`/`8025` do not overlap the existing EXPOSE contract
  (9000/3306/9200/6379/80; nginx moves to 8080 at runtime when Varnish is enabled);
  confirmed against the Dockerfile EXPOSE line, README, and tests.
- Mailpit sendmail flag drift: the exact subcommand flag (`-S` vs `--smtp-addr`) varies by
  Mailpit version; the implementer pins it by running `mailpit sendmail --help` in the
  built image before wiring start-services and the test sender.
