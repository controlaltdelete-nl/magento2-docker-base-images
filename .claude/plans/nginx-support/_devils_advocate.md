# Devil's Advocate Review: nginx-support

## Critical (Must fix before building)

### C1. `php-fpm -t` binary does not exist (tasks 002, 003)
The Ondřej Surý PPA installs only the versioned FPM binary (`/usr/sbin/php-fpm8.2`,
confirmed by the existing Dockerfile sed `s|__PHP_FPM_COMMAND__|/usr/sbin/php-fpm$PHP_VERSION -F|`).
There is no unversioned `php-fpm`. The task 002 success criterion "`php-fpm -t` passes"
and the test assertion would fail to even find the binary. Fix: use
`php-fpm${PHP_VERSION} -t` at build time (PHP_VERSION build arg) and in `run-tests.sh`
(the `$PHP_VERSION` env var is already passed via `-e` in every CI step). APPLIED.

### C2. Duplicate php-fpm pool / `:9000` collision (task 002)
`zz-magento.conf` sorting after `www.conf` only "wins" if it overrides directives inside
the SAME pool. If it declares a new pool name (e.g. `[magento]`) it creates a SECOND pool
that also tries to `listen = 127.0.0.1:9000`, and php-fpm fails at start / `-t` with an
address-in-use or duplicate-pool error. The override must reuse the `[www]` header. APPLIED.

### C3. Empty `/data` + missing custom docroot make serving tests fail (tasks 003, 004)
The CI `docker run` only mounts `tests:/tests`; `/data` is empty and a custom
`NGINX_DOCROOT` path may not exist at all, so every "serves a php file" assertion 404s.
Tasks now require writing a sentinel `index.php` into the served docroot and
`mkdir -p "$NGINX_DOCROOT"` for the custom-root case before curling. APPLIED.

## Important (Should fix before building)

### I1. Shipped `nginx.conf` must stay a complete main config (task 001)
"new: main config, worker_processes 1" is underspecified. Overwriting
`/etc/nginx/nginx.conf` with a stub breaks the server (no `http{}`, no `mime.types`, no
`include conf.d/*.conf`). The task now enumerates the required blocks and explicitly
excludes `include sites-enabled/*` (which is how the distro default `:80` block returns).
Also pinned explicit COPY targets (`/etc/nginx/nginx.conf`, `/etc/nginx/conf.d/default.conf`).
APPLIED.

### I2. Docroot override should be a single `root` rewrite (tasks 001, 003)
Task 003 originally said to sed "the root directive AND any SCRIPT_FILENAME/fastcgi path".
A double-sed is fragile. Mandated in task 001 that `SCRIPT_FILENAME` is
`$document_root$fastcgi_script_name`, so task 003 only rewrites the single `root` directive.
APPLIED.

### I3. Startup-latency flakiness on serving assertions (task 003)
`start-services` returns after the Elasticsearch loop without waiting for nginx/php-fpm,
and Varnish is started asynchronously via `supervisorctl start varnish`. A single curl can
race the boot. Tasks now require a short bounded retry loop on the HTTP assertions. APPLIED.

### I4. Anchored sed for the port switch (task 003)
`sed s/80/8080/` (or an unanchored `listen 80`) risks rewriting an unintended `:80`.
Required an anchored pattern (`s/listen 80;/listen 8080;/`). APPLIED.

### I5. README "Exposed Ports" and start-services description drift (task 004)
README has two `80` rows (Varnish / HTTP) and says start-services launches
"MySQL, Elasticsearch, Redis, and PHP-FPM". Task 004 now calls out reconciling the port
table and adding nginx to the description. APPLIED.

## Minor (Nice to address)

### M1. Default `CMD` path does not render overrides
`CMD ["/usr/bin/supervisord","-n"]` does not run `start-services`, so under the bare CMD
nginx uses shipped defaults and `ENABLE_VARNISH`/`NGINX_DOCROOT`/`PHP_FPM_MAX_CHILDREN` are
ignored. This matches existing behavior (Varnish is already start-services-only) and the
documented usage always calls `./start-services`, so it is acceptable. Documented as a
caveat in the plan, not changed.

### M2. `pm = ondemand` leaves `www.conf` dynamic-only directives set
`pm.start_servers` / `pm.min_spare_servers` / `pm.max_spare_servers` from `www.conf` remain
but are ignored by php-fpm under `ondemand` (no error). No action needed; noted in task 002.

### M3. nginx-light module sufficiency
The front controller needs only core + fastcgi + gzip, all in `nginx-light`. The build-time
`nginx -t` is the safety net. No change.

## Questions for the Team

### Q1. Should the override CI step also set `ENABLE_VARNISH=true`?
Task 004 currently recommends NOT combining them (test the docroot/pool override against the
plain `:80` path so a failure is unambiguous). Confirm you do not also want a
Varnish+override combined run. Adding it would mean the docroot test curls through Varnish.

### Q2. Is `PHP_FPM_MAX_CHILDREN=2` an acceptable CI override value?
Picked a value different from the default `4` so the assertion is meaningful. Confirm `2`
is fine (it is only exercised by the synthetic suite, not a real Magento boot).

### Q3. nginx on `:8080` is internal-only under Varnish; no new EXPOSE is added.
Confirm you do not want `8080` exposed (it is only reachable in-container by Varnish, which
is the intended topology). No change made.
