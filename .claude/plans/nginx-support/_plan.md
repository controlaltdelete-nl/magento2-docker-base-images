# Plan: nginx Support (replace PHP dev server)

## Created
2026-06-11

## Status
completed

## Objective
Add a minimal, memory-bounded nginx web server to the base image to replace the
PHP built-in development server used by downstream images, and cap php-fpm worker
memory to prevent the GitHub Actions OOM events seen previously.

## Related Issues
none

## Discovery Notes
- No web server currently serves PHP. The image runs `php-fpm` on TCP `:9000` and an
  opt-in Varnish on `:80` whose backend is hardcoded to `127.0.0.1:8080`
  (`templates/varnish/default.vcl`), but nothing listens on `8080`. nginx slots into
  that gap.
- `WORKDIR` is `/data` (the consumer's app mount). No docroot is configured anywhere.
- Real OOM lever is php-fpm: `memory_limit = 2048M` (`templates/memory-limit-php.ini`)
  plus Ubuntu's default pool (`pm = dynamic, max_children = 5`) allows ~5 fat Magento
  workers. Bounding the pool is the actual fix.
- Services are wired via Supervisord (`templates/supervisord/*.conf`, COPY-ed one-per-file
  into `/etc/supervisor/conf.d/` by explicit Dockerfile lines, NOT a glob) and tested
  in-container by the `tests/run-tests.sh` Bash assertion suite. `start-services`
  launches supervisord at line 19, so any config rendered before that point is in place
  when daemons boot.
- Stale bug: `start-services` echoes "Varnish is available on port 6081" but Varnish
  binds `:80`. Fixed as part of this work.
- Downstream image (`controlaltdelete-nl/magento2-in-a-box`, the only known consumer)
  runs the dev server via `templates/supervisord-webserver.conf`:
  `php -S 0.0.0.0:80 -t /data/pub/ /data/phpserver/router.php`. Its docroot is `/data/pub`
  and it uses Magento's `phpserver/router.php`. Its `entrypoint.sh` already does the
  `ENABLE_VARNISH` port-switch (`sed 0.0.0.0:80 -> 0.0.0.0:8080`) before calling the
  inherited `./start-services`. Magento's `nginx.conf.sample` is a server-block FRAGMENT
  (no `listen`/`server {}`; needs `$MAGE_ROOT`, `$MAGE_MODE`, and an `upstream
  fastcgi_backend`), so it cannot be dropped straight into `conf.d`. The base therefore
  ships the `fastcgi_backend` upstream plus an inactive wrapper to make the downstream a
  one-`cp` migration (task 004).

### Resolved design decisions
- **Port topology**: nginx listens on `:80` by default; when `ENABLE_VARNISH=true` it
  switches to `:8080` and Varnish fronts `:80`. Implemented by rewriting the `listen`
  directive in `start-services` before supervisord launches.
- **Config flavor**: minimal generic PHP front-controller (`try_files $uri $uri/
  /index.php$is_args$args`, `fastcgi_pass 127.0.0.1:9000`). Not Magento-specific.
- **Document root**: defaults to `/data`, overridable via `NGINX_DOCROOT`.
- **php-fpm bounding**: in scope. `pm = ondemand`, low `pm.max_children` (default 4),
  idle timeout, overridable via `PHP_FPM_MAX_CHILDREN`.
- **Always-on**: nginx runs by default (it replaces a required component); no
  `ENABLE_NGINX` flag. php-fpm stays on TCP `:9000` to preserve the documented contract.
- **Package**: `nginx-light` (smaller footprint than full nginx).

## Scope

### In Scope
- Install `nginx-light` and ship a minimal front-controller config.
- Run nginx under Supervisord; render listen port (80/8080) and docroot at startup.
- Bound the php-fpm pool memory with conservative, env-overridable defaults.
- Ship the `fastcgi_backend` upstream and a ready-made (inactive) Magento wrapper so the
  downstream `magento2-in-a-box` migration is a single `cp`.
- Test assertions in `tests/run-tests.sh` for nginx serving, pool config, and the downstream hooks.
- A CI step exercising the `NGINX_DOCROOT` / `PHP_FPM_MAX_CHILDREN` overrides.
- README and docs updates, including the downstream migration recipe.
- Fix the stale Varnish port echo in `start-services`.

### Out of Scope
- Baking Magento routing rules INTO the base default config (the base default stays a
  generic front-controller; Magento routing comes from the app's own `nginx.conf.sample`,
  which the shipped wrapper `include`s).
- The actual edits to the `magento2-in-a-box` repo (different repo; documented as a recipe only).
- TLS/HTTPS termination.
- An `ENABLE_NGINX` opt-out flag.
- Switching php-fpm from TCP `:9000` to a unix socket.
- Changing the Varnish VCL or its `malloc` budget.

## Success Criteria
- [ ] nginx serves a PHP file from the docroot over HTTP on `:80` (Varnish disabled)
- [ ] With `ENABLE_VARNISH=true`, requests to `:80` reach php through Varnish to nginx on `:8080`
- [ ] php-fpm pool uses `pm = ondemand` with a bounded, overridable `max_children`
- [ ] `nginx -t` and `php-fpm -t` pass at build time
- [ ] Image builds clean for the affected PHP versions and the full suite passes
- [ ] README documents nginx, docroot, and the env knobs
- [ ] Code follows project standards

## Task Overview
| Task | Description | Depends On | Status |
|------|-------------|------------|--------|
| 001 | Install nginx and ship minimal front-controller config | - | completed |
| 002 | Bound php-fpm pool memory | - | completed |
| 003 | Run nginx under Supervisord; wire startup port/docroot/pool overrides + assertions | 001, 002 | completed |
| 004 | Magento downstream contract: fastcgi_backend upstream + ready-made wrapper | 001, 003 | completed |
| 005 | CI override step, README and docs (incl. magento2-in-a-box migration recipe) | 003, 004 | completed |

Dependency graph:
```
001 ─┬─► 003 ─┬─► 004 ─► 005
     │        │
     └────────┘
002 ─────► 003
```
Batch 1: 001, 002 (parallel). Batch 2: 003. Batch 3: 004. Batch 4: 005.
004 is logically independent of 003, but both append assertions to `tests/run-tests.sh`
and both add `COPY` lines to the `Dockerfile`. Serializing 004 after 003 avoids conflicting
concurrent edits to those two shared files by parallel workers.

## Architecture Notes
- nginx ships with a VALID default config (`listen 80`, `root /data`) so `nginx -t`
  passes at build time and the server works without runtime rendering. We ship a complete
  `/etc/nginx/nginx.conf` (with `events`, `http`, `include conf.d/*.conf`, NOT
  `sites-enabled`) plus `/etc/nginx/conf.d/default.conf` (the server block).
  `start-services` only rewrites the `listen` port and `root` when needed, using anchored
  `sed` before supervisord launches (avoids a runtime gettext dependency and any boot-order
  race). `SCRIPT_FILENAME` is built from `$document_root`, so the docroot override is a
  single `root`-directive rewrite.
- Default-`CMD` caveat: the rendering lives in `start-services`. The bare
  `CMD ["/usr/bin/supervisord","-n"]` path does not run it, so under the default CMD nginx
  uses its shipped defaults and `ENABLE_VARNISH`/overrides are honored only when the
  container is launched via `./start-services` (the CI and documented usage).
- The php-fpm pool override is baked at build time into
  `/etc/php/${PHP_VERSION}/fpm/pool.d/zz-magento.conf` (PHP_VERSION is a build arg) and
  reuses the `[www]` pool name to avoid creating a duplicate pool on `:9000`. Runtime
  override of `max_children` is applied by `start-services` via a glob path
  (`/etc/php/*/fpm/pool.d/zz-magento.conf`) so it works without knowing the version at
  runtime. Build-time validation uses the version-specific binary `php-fpm${PHP_VERSION} -t`
  (there is no unversioned `php-fpm`); the test suite uses the `$PHP_VERSION` env var the
  CI already passes in.
- Override assertions in `tests/run-tests.sh` are guarded by their env vars
  (`NGINX_DOCROOT`, `PHP_FPM_MAX_CHILDREN`) so they only run in the dedicated CI step,
  mirroring the existing `ENABLE_VARNISH` guard pattern. HTTP-serving assertions write a
  sentinel `index.php` into the served docroot (`mkdir -p` for custom roots) and retry the
  curl with a short bounded loop to absorb php-fpm/nginx/Varnish startup latency.

## Risks & Mitigations
- **nginx-light missing a needed module**: minimal front-controller needs only core
  fastcgi + gzip, both present in nginx-light. Mitigation: `nginx -t` at build time.
- **Port-switch race with Varnish**: nginx renders to 8080 before supervisord starts;
  Varnish (autostart=false) binds 80 later. No overlap. Mitigation: assertion in the
  ENABLE_VARNISH test run.
- **Pool override path drift across PHP versions**: glob path decouples from the version
  string. Mitigation: build-time `php-fpm -t`.
- **Empty `/data` in CI**: tests write a throwaway `index.php` into the docroot before
  curling (and `mkdir -p` a custom `NGINX_DOCROOT`). Mitigation: cleanup not required
  (ephemeral container).
- **`php-fpm -t` binary does not exist**: the PPA installs only the versioned binary
  `php-fpm${PHP_VERSION}`. Build-time check and test assertion both use that name.
- **Duplicate php-fpm pool**: the override file reuses the `[www]` header instead of a new
  pool name, so it overrides `www.conf` rather than opening a second `:9000` listener.
- **Startup latency flake**: serving assertions retry the curl on a short bounded loop;
  nginx connects to php-fpm per request so nginx itself need not wait for php-fpm to boot.
