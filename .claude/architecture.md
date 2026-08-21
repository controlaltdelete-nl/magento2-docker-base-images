# Architecture

All-in-one Docker base images for Magento 2 CI/CD. One image bundles PHP-FPM, MySQL,
Elasticsearch, Redis, and Varnish so a pipeline needs only a single container.
Supervisord is the process manager (PID 1 via `CMD ["/usr/bin/supervisord", "-n"]`).

## Directory Structure

- `Dockerfile` — single multi-stage-free build, parameterized by `PHP_VERSION` and
  `NODE_VERSION` build args. Installs the full stack, configures MySQL/Elasticsearch,
  installs Composer, Node (via nvm), and n98-magerun2.
- `scripts/` — runtime helpers copied into the image WORKDIR (`/data`):
  - `start-services` — render nginx/php-fpm config from env vars, then start MySQL,
    Elasticsearch, Redis, PHP-FPM, and nginx. Opt-ins: `ENABLE_VARNISH=true` (Varnish
    on :80, nginx to :8080), `ENABLE_MAILPIT=true` (SMTP catcher), `ENABLE_CORS=true`
    (includes the CORS nginx snippet in the active server blocks)
  - `stop-services` — stop all services
  - `retry` — retry wrapper for flaky startup steps
- `templates/` — service configuration baked into the image:
  - `supervisord.conf` and `supervisord/*.conf` — one program block per service
  - `elasticsearch/` — `elasticsearch.yml` and JVM GC options
  - `nginx/` — `nginx.conf`, active `default.conf` front-controller, `fastcgi_backend.conf`
    upstream, plus inactive snippets under `/etc/nginx/available/`: `magento.conf`
    (wrapper around Magento's `nginx.conf.sample`) and `cors.conf` (wide-open CORS
    headers + `OPTIONS` preflight, activated by `ENABLE_CORS=true`)
  - `php-fpm/zz-magento.conf` — the only pool: root workers, `ondemand`, bounded children
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
- Behavior only some consumers want is opt-in via an `ENABLE_*` env var, off by default
  (`ENABLE_VARNISH`, `ENABLE_MAILPIT`, `ENABLE_CORS`); defaults must mirror production
  and never alter observable HTTP behavior for users who did not ask for it.
- Version-specific behavior (opcache packaging, Magerun phar URL) branches explicitly
  inside the `Dockerfile`.
- Pre-configured databases: `magento` / `magento-test`, user/pass `magento` / `password`
  and `magento-test` / `password`.
- Exposed ports: 9000 (PHP-FPM), 3306 (MySQL), 9200 (Elasticsearch), 6379 (Redis), 80 (Varnish/HTTP), 1025 (Mailpit SMTP, opt-in), 8025 (Mailpit web UI/API, opt-in).
- Node.js is installed via nvm; runtime version switching is supported.

## Current Focus

Branch `feature/reduce-startup-time` — work aimed at reducing container/service
startup time. Keep `start-services` and Supervisord/service tuning changes measured
against the `tests/run-tests.sh` suite to avoid regressing service readiness.
