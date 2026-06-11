# Task 002: Bound php-fpm pool memory

**Status**: completed
**Depends on**: none
**Retry count**: 0

## Description
Cap php-fpm worker memory to prevent the GitHub Actions OOM events. Ship a pool
override that switches process management to on-demand with a low, conservative
`max_children` default, an idle timeout, and a request recycle limit. Bake it at build
time into the version-specific pool directory using the `PHP_VERSION` build arg.

## Context
- Related files:
  - `templates/php-fpm/zz-magento.conf` (new: pool override)
  - `Dockerfile` (COPY/render the pool override into `/etc/php/${PHP_VERSION}/fpm/pool.d/zz-magento.conf`)
- Patterns to follow:
  - `PHP_VERSION` is a build arg already used throughout the `Dockerfile`
    (see the `php-fpm.conf` sed and the opcache/Magerun version branches).
  - Config templates live under `templates/`.
- Notes / rationale:
  - Current risk: `memory_limit = 2048M` (`templates/memory-limit-php.ini`) with the
    default pool `pm = dynamic, pm.max_children = 5` allows ~5 fat workers.
  - Target settings: `pm = ondemand`, `pm.max_children = 4` (default),
    `pm.process_idle_timeout = 10s`, `pm.max_requests = 500`, `catch_workers_output = yes`.
  - The pool file must end up in the version-specific path
    `/etc/php/${PHP_VERSION}/fpm/pool.d/zz-magento.conf` (Ondřej Surý PPA layout, confirmed
    by the existing `/usr/sbin/php-fpm$PHP_VERSION` sed in the Dockerfile). The file name
    `zz-magento.conf` sorts after the distro `www.conf` so its directives win.
  - The override must reuse the SAME pool name as the distro pool. The distro pool is named
    `[www]` in `www.conf`. Start `zz-magento.conf` with the `[www]` header and override the
    directives under it; a new pool name would create a SECOND pool listening on the same
    `127.0.0.1:9000` socket and `php-fpm -t` / startup would fail with an "address already
    in use" / duplicate-pool error. (Alternatively, override `pm` etc. inside `[www]`.)
  - `pm = ondemand` ignores the `dynamic`-only directives (`pm.start_servers`,
    `pm.min_spare_servers`, `pm.max_spare_servers`) that `www.conf` still sets; this is
    accepted by php-fpm without error, no need to unset them.
  - The build-time validation binary is version-specific: `php-fpm${PHP_VERSION} -t`
    (there is no unversioned `php-fpm` binary). Use the `PHP_VERSION` build arg.
  - Runtime override of `max_children` (`PHP_FPM_MAX_CHILDREN`) is handled in task 003,
    not here. This task ships the static, bounded defaults.

## Requirements (Test Descriptions)
These become assertions in `tests/run-tests.sh` (reading the effective pool config) plus a build-time check.

- [x] `it configures the php-fpm pool with pm set to ondemand`
- [x] `it caps php-fpm pm.max_children at 4 by default`
- [x] `it sets a php-fpm process idle timeout`
- [x] `it recycles php-fpm workers via pm.max_requests`
- [x] `it passes php-fpm configuration validation` (assertion invokes `php-fpm${PHP_VERSION} -t`; `PHP_VERSION` is exported into the test container via `-e`)

## Acceptance Criteria
- All requirements have passing assertions in `tests/run-tests.sh`
- `php-fpm${PHP_VERSION} -t` succeeds inside the built image
- Pool override lands in the correct version-specific `pool.d` directory and reuses the
  `[www]` pool name (no duplicate pool / duplicate `:9000` listener)
- Code follows project standards (no em dashes)

## Implementation Notes
(Left blank - filled in by programmer during implementation)
