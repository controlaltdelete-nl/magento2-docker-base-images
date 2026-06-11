# Task 001: Install nginx and ship minimal front-controller config

**Status**: completed
**Depends on**: none
**Retry count**: 0

## Description
Install `nginx-light` in the image and ship a minimal, valid generic PHP
front-controller configuration. The config must work out of the box (`listen 80`,
`root /data`, fastcgi to php-fpm on `127.0.0.1:9000`) so the image serves PHP without
any runtime rendering, and so `nginx -t` passes at build time. Keep the footprint low:
`worker_processes 1` and conservative buffers.

## Context
- Related files:
  - `Dockerfile` (add `nginx-light` to the existing stack `apt-get install` RUN layer; clean apt cache in the same layer; remove the distro default site; `COPY` both config files to explicit paths)
  - `templates/nginx/nginx.conf` (new: main config; COPY to `/etc/nginx/nginx.conf`)
  - `templates/nginx/default.conf` (new: server block; COPY to `/etc/nginx/conf.d/default.conf`)
- Patterns to follow:
  - Service config lives under `templates/` and is `COPY`-ed in (see `templates/varnish/`, `templates/elasticsearch/`).
  - Layer hygiene: install + `apt-get clean && rm -rf /var/lib/apt/lists/*` in one RUN.
- Notes:
  - php-fpm listens on TCP `127.0.0.1:9000` (keep TCP; do not switch to a socket).
  - The `nginx.conf` we ship REPLACES the distro `/etc/nginx/nginx.conf`. It must remain
    a complete, valid main config: keep `events {}`, an `http {}` block with
    `include /etc/nginx/mime.types;`, `default_type application/octet-stream;`, `sendfile on;`,
    `gzip on;`, and crucially `include /etc/nginx/conf.d/*.conf;`. Set `worker_processes 1`,
    `daemon off;`, and log `access_log /dev/stdout;` / `error_log /dev/stderr;`. Do NOT
    re-add `include /etc/nginx/sites-enabled/*;` (that is how the distro default `:80`
    server block sneaks back in).
  - Remove `/etc/nginx/sites-enabled/default` (and the symlink target if present) so no
    second `:80` server block exists. Because our shipped `nginx.conf` does not include
    `sites-enabled`, this is belt-and-suspenders, but do it anyway for clarity.
  - Front-controller routing in `default.conf`: `listen 80;`, `root /data;`,
    `index index.php index.html;`, `try_files $uri $uri/ /index.php$is_args$args;`, then a
    `location ~ \.php$` block passing to `fastcgi_pass 127.0.0.1:9000;`. Set
    `fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;` (use
    `$document_root`, NOT a hardcoded path, so the task 003 docroot override only needs to
    rewrite the single `root` directive). Include `/etc/nginx/fastcgi_params`.

## Requirements (Test Descriptions)
These become assertions in `tests/run-tests.sh` (in-container) plus a build-time check.

- [x] `it has the nginx binary installed and on the path`
- [x] `it ships an nginx config that passes nginx -t syntax validation`
- [x] `it sets nginx worker_processes to 1`
- [x] `it removes the distro default nginx site so only the front-controller server block is active` (assert `/etc/nginx/sites-enabled/default` is absent)
- [x] `it includes only conf.d in the main nginx.conf so no other directory is auto-loaded` (assert `nginx.conf` has `include /etc/nginx/conf.d/*.conf;` and has NO `include` of `sites-enabled` or `available`; this is what keeps task 004's `/etc/nginx/available/magento.conf` wrapper inert)
- [x] `it configures fastcgi_pass to 127.0.0.1:9000`
- [x] `it sets SCRIPT_FILENAME from $document_root so a docroot override needs only the root directive`

## Acceptance Criteria
- All requirements have passing assertions in `tests/run-tests.sh`
- `nginx -t` succeeds inside the built image
- nginx-light is installed in the same RUN layer as the rest of the stack with apt cache cleaned
- Code follows project standards (quoted shell, layer hygiene, no em dashes)

## Implementation Notes
(Left blank - filled in by programmer during implementation)
