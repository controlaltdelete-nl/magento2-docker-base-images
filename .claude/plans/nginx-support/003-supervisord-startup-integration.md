# Task 003: Run nginx under Supervisord; wire startup port/docroot/pool overrides

**Status**: completed
**Depends on**: 001, 002
**Retry count**: 0

## Description
Make nginx a managed Supervisord program and wire the runtime knobs into
`scripts/start-services`: switch the nginx `listen` port to `8080` when Varnish is
enabled, swap the docroot when `NGINX_DOCROOT` is set, and override the php-fpm pool
`max_children` when `PHP_FPM_MAX_CHILDREN` is set. All rendering happens BEFORE
supervisord launches (start-services line ~19) so daemons boot with the final config.
Also fix the stale Varnish port echo.

## Context
- Related files:
  - `templates/supervisord/nginx.conf` (new: `program:nginx`, `command=nginx -g 'daemon off;'`, `autostart=true`, logs to stdout/stderr). The explicit `-g 'daemon off;'` here is the source of truth for foregrounding even if task 001 also set `daemon off;` in nginx.conf; passing it twice is harmless, but keep it on the supervisord command so the program never daemonizes out from under supervisord.
  - `Dockerfile` (add ONE explicit `COPY templates/supervisord/nginx.conf /etc/supervisor/conf.d/nginx.conf` line next to the existing per-file COPYs at lines ~48-52; the Dockerfile uses one explicit COPY per supervisord conf, NOT a glob, so add a matching explicit line)
  - `scripts/start-services` (render port/docroot/pool before launching supervisord; fix port echo)
- Patterns to follow:
  - Existing supervisord program blocks under `templates/supervisord/` (e.g. `varnish.conf`, `php-fpm.conf`).
  - `start-services` already does pre-supervisord setup (MySQL init) before line 19; add the rendering there.
  - Varnish is `autostart=false` and started later; nginx on `8080` and Varnish on `80` do not overlap.
- Notes:
  - All rendering must live in `scripts/start-services` BEFORE line 19 (the
    `supervisord -n` launch). This only takes effect when the container is started via
    `./start-services` (the CI flow and the README usage). The default `CMD
    ["/usr/bin/supervisord","-n"]` path does NOT run start-services, so nginx boots with
    its shipped defaults (`listen 80`, `root /data`) and `ENABLE_VARNISH`/overrides are
    only honored through start-services. This is acceptable: the defaults are the correct
    no-override behavior. Do NOT move rendering into a supervisord pre-hook.
  - Port switch: default config has `listen 80`. When `ENABLE_VARNISH=true`, `sed` it to
    `listen 8080` in `/etc/nginx/conf.d/default.conf` so Varnish (`-a :80`) fronts nginx.
    Anchor the sed (e.g. `s/listen 80;/listen 8080;/`) so it cannot also rewrite a `:80`
    inside a comment or fastcgi value.
  - Docroot override: when `NGINX_DOCROOT` is set, `sed` ONLY the `root` directive in
    `/etc/nginx/conf.d/default.conf` (task 001 sets `SCRIPT_FILENAME` from `$document_root`,
    so the single `root` rewrite is sufficient; do not touch the fastcgi block).
    Also `mkdir -p "$NGINX_DOCROOT"` so nginx does not 404/500 on a missing root.
  - Pool override: when `PHP_FPM_MAX_CHILDREN` is set, `sed` `pm.max_children` in the pool
    file via the glob `/etc/php/*/fpm/pool.d/zz-magento.conf` (avoids needing PHP_VERSION at
    runtime). The glob must run before supervisord starts php-fpm so the new value is read
    at boot (php-fpm reads the pool config once at start, not per request).
  - Fix: `scripts/start-services` currently echoes "Varnish is available on port 6081";
    Varnish binds `:80`. Correct the message to reference port 80.
  - Override assertions are GUARDED by their env vars so they pass/skip in the default run
    and only execute in task 005's dedicated CI override step (mirrors the `ENABLE_VARNISH` guard
    already in `run-tests.sh`).
  - The `/data` mount is empty in CI. The HTTP-serving tests MUST first write a throwaway
    `index.php` (e.g. `<?php echo "nginx-ok";`) into the docroot being served
    (`/data` by default, `$NGINX_DOCROOT` when set) before curling, and assert the response
    body contains the sentinel string. For the custom-docroot test, `mkdir -p "$NGINX_DOCROOT"`
    first (the override CI step in task 005 may point it at a non-existent path).
  - nginx (`fastcgi_pass 127.0.0.1:9000`) connects to php-fpm per request, so nginx can boot
    before php-fpm is ready; but php-fpm itself is started by supervisord and start-services
    returns after the Elasticsearch loop without waiting for php-fpm/nginx. The serving
    assertions MUST retry the curl with a short bounded loop (a few attempts, 1s apart) to
    avoid a flaky failure against a php-fpm/nginx that is still coming up. Same applies to the
    Varnish-fronted curl on `:80` (start-services starts Varnish asynchronously via
    `supervisorctl start varnish`).

## Requirements (Test Descriptions)
These become assertions in `tests/run-tests.sh`.

- [x] `it runs nginx as a supervisord-managed program`
- [x] `it serves a php file from the document root over http on port 80 when varnish is disabled`
- [x] `it serves php through varnish on port 80 with nginx listening on 8080 when varnish is enabled`
- [x] `it serves from a custom document root when NGINX_DOCROOT is set`
- [x] `it overrides php-fpm pm.max_children when PHP_FPM_MAX_CHILDREN is set`
- [x] `it reports the correct varnish port in start-services output`

## Acceptance Criteria
- All requirements have passing assertions in `tests/run-tests.sh`
- Default run (no Varnish): nginx serves php on `:80`
- `ENABLE_VARNISH=true` run: nginx on `:8080`, Varnish serves php on `:80`
- Override assertions are env-guarded and do not break the default and Varnish runs
- Stale 6081 echo corrected
- Code follows project standards (quoted shell, early returns, no em dashes)

## Implementation Notes
(Left blank - filled in by programmer during implementation)
