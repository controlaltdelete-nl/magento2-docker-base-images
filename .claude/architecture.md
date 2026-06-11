# Architecture

All-in-one Docker base images for Magento 2 CI/CD. One image bundles PHP-FPM, MySQL,
Elasticsearch, Redis, and Varnish so a pipeline needs only a single container.
Supervisord is the process manager (PID 1 via `CMD ["/usr/bin/supervisord", "-n"]`).

## Directory Structure

- `Dockerfile` — single multi-stage-free build, parameterized by `PHP_VERSION` and
  `NODE_VERSION` build args. Installs the full stack, configures MySQL/Elasticsearch,
  installs Composer, Node (via nvm), and n98-magerun2.
- `scripts/` — runtime helpers copied into the image WORKDIR (`/data`):
  - `start-services` — start MySQL, Elasticsearch, Redis, PHP-FPM (and Varnish when `ENABLE_VARNISH=true`)
  - `stop-services` — stop all services
  - `retry` — retry wrapper for flaky startup steps
- `templates/` — service configuration baked into the image:
  - `supervisord.conf` and `supervisord/*.conf` — one program block per service
  - `elasticsearch/` — `elasticsearch.yml` and JVM GC options
  - `varnish/default.vcl`, `memory-limit-php.ini`
- `tests/run-tests.sh` — Bash assertion suite run inside the built container
- `.github/workflows/build-php-images.yml` — matrix build → test → push pipeline
- `build`, `test.sh` — local debugging helpers (NOT used by CI)

## Build and Release Flow

1. CI matrix builds one image per PHP version (7.1–8.5), `fail-fast: false`.
2. Each image is loaded locally and tested twice: default, then `ENABLE_VARNISH=true`.
3. On `main`, images are pushed to Docker Hub (`michielgerritsen/magento2-base-image`)
   and ghcr.io (`ghcr.io/controlaltdelete-nl/magento2-docker-base-images/magento2-base-image`),
   tagged `<php-version>` and `php<NN>-fpm`.

## Conventions

- Service config lives in `templates/`, never inlined in the `Dockerfile`.
- Version-specific behavior (opcache packaging, Magerun phar URL) branches explicitly
  inside the `Dockerfile`.
- Pre-configured databases: `magento` / `magento-test`, user/pass `magento` / `password`
  and `magento-test` / `password`.
- Exposed ports: 9000 (PHP-FPM), 3306 (MySQL), 9200 (Elasticsearch), 6379 (Redis), 80 (Varnish/HTTP).
- Node.js is installed via nvm; runtime version switching is supported.

## Current Focus

Branch `feature/reduce-startup-time` — work aimed at reducing container/service
startup time. Keep `start-services` and Supervisord/service tuning changes measured
against the `tests/run-tests.sh` suite to avoid regressing service readiness.
