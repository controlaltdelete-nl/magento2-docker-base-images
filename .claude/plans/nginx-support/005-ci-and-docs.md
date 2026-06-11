# Task 005: CI override step, README and docs

**Status**: completed
**Depends on**: 003, 004
**Retry count**: 0

## Description
Exercise the new env overrides in CI and document the nginx feature, including the
downstream migration recipe for `magento2-in-a-box`. Add a CI step that runs the suite
with `NGINX_DOCROOT` and `PHP_FPM_MAX_CHILDREN` set so the env-guarded override assertions
from task 003 actually execute, and update the README to cover nginx, the default docroot,
the env knobs, the port behavior under Varnish, and how a Magento downstream image swaps
its `php -S` dev server for the base nginx.

## Context
- Related files:
  - `.github/workflows/build-php-images.yml` (add a step that runs `run-tests.sh` with `NGINX_DOCROOT` and `PHP_FPM_MAX_CHILDREN` set, mirroring the existing default and Varnish steps)
  - `README.md` ("What's Included", ports table, usage, and a new section for nginx + env knobs)
- Patterns to follow:
  - The two existing CI test steps (`docker run ... bash -c './start-services && /tests/run-tests.sh'`), one plain and one with `ENABLE_VARNISH=true`.
- Notes:
  - Add ONE new CI step that runs `./start-services && /tests/run-tests.sh` with both
    `-e NGINX_DOCROOT=/custom-docroot` and `-e PHP_FPM_MAX_CHILDREN=2` (any value that
    differs from the default `4` so the assertion is meaningful). Do NOT pick a docroot the
    container cannot create or write to; `/custom-docroot` under root is fine.
    `run-tests.sh` (task 003) is responsible for `mkdir -p "$NGINX_DOCROOT"` and writing the
    throwaway `index.php` there, so the CI step does NOT need a volume mount for the docroot.
  - The override step must export `PHP_VERSION` like the other steps (so `php-fpm${PHP_VERSION} -t`
    and any version-guarded assertions resolve).
  - Keep this as a separate step (not folded into the Varnish step) so a failure clearly
    attributes to the override path. Decide whether it also sets `ENABLE_VARNISH`; default
    to NOT setting it so the docroot/pool override is tested against the simple `:80` path.
  - README updates: nginx now replaces the need for the PHP dev server in downstream
    images; document default docroot `/data`, `NGINX_DOCROOT`, `PHP_FPM_MAX_CHILDREN`,
    and that nginx moves to `:8080` when `ENABLE_VARNISH=true`. Update the "Exposed Ports"
    table (the duplicate `80` rows for Varnish/HTTP should be reconciled: `:80` is nginx by
    default, Varnish when `ENABLE_VARNISH=true`). Update the `start-services` description
    that currently says it starts "MySQL, Elasticsearch, Redis, and PHP-FPM" to include nginx.
  - Downstream migration recipe (document in README; this repo does NOT change the downstream,
    that work happens in `magento2-in-a-box`). Describe how a Magento downstream replaces its
    `php -S` dev server with the base nginx, using the hooks from task 004:
    1. Remove the `php -S` webserver supervisord program (the downstream's
       `templates/supervisord-webserver.conf` / `conf.d/webserver.conf`). nginx is inherited
       from the base and autostarts.
    2. Remove the downstream entrypoint's `sed 's/0.0.0.0:80/0.0.0.0:8080/'` port-switch; the
       base `start-services` now does the nginx port-switch when `ENABLE_VARNISH=true`.
    3. Activate the Magento config with one copy:
       `cp /etc/nginx/available/magento.conf /etc/nginx/conf.d/default.conf` (serves
       `/data/pub` via Magento's `nginx.conf.sample`, fastcgi to the `fastcgi_backend`
       upstream). Adjust `$MAGE_MODE` in the wrapper if production is wanted.
    Note that the base default docroot is `/data`, but the Magento wrapper serves `/data/pub`
    through the sample's `root $MAGE_ROOT/pub;`.

## Requirements (Test Descriptions)
- [x] `it runs the test suite in CI with NGINX_DOCROOT and PHP_FPM_MAX_CHILDREN set`
- [x] `it documents nginx, the default docroot, and the NGINX_DOCROOT override in the README`
- [x] `it documents the PHP_FPM_MAX_CHILDREN knob in the README`
- [x] `it documents that nginx listens on 8080 when varnish is enabled`
- [x] `it documents the magento2-in-a-box migration recipe (remove php -S, cp the magento wrapper)`

## Acceptance Criteria
- New CI step runs green across the PHP matrix and triggers the env-guarded assertions from task 003
- README accurately reflects nginx behavior, docroot, ports, and env knobs
- No em dashes; current-year copyright if any added

## Implementation Notes
(Left blank - filled in by programmer during implementation)
