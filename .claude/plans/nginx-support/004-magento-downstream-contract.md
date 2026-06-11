# Task 004: Magento downstream nginx contract (fastcgi_backend upstream + ready-made wrapper)

**Status**: completed
**Depends on**: 001, 003
**Retry count**: 0

> Dependency note: 004 is logically independent of 003 (it only adds an upstream conf,
> a wrapper template, and two Dockerfile COPYs). It depends on 003 SOLELY to serialize
> the shared-file edits: both 003 and 004 append assertions to `tests/run-tests.sh` and
> both add `COPY` lines to the `Dockerfile`. Running them as parallel workers would cause
> conflicting concurrent edits to those two files. Building 004 after 003 lets it append
> cleanly. Do not reorder back to a parallel batch unless the shared-file edits are
> split out.

## Description
Make the base image's nginx trivially reusable by the only known downstream image,
`controlaltdelete-nl/magento2-in-a-box`, which currently runs
`php -S 0.0.0.0:80 -t /data/pub/ /data/phpserver/router.php`. Ship a `fastcgi_backend`
upstream (so Magento's `nginx.conf.sample` resolves) and a ready-made Magento server-block
wrapper that `include`s the app's `nginx.conf.sample`, so the downstream's migration is a
single `cp` of the wrapper over `/etc/nginx/conf.d/default.conf`. The base's own active
default stays the generic front-controller from task 001; the wrapper ships INACTIVE.

## Context
- Why this exists (verified against the downstream repo):
  - `magento2-in-a-box` runs the dev server via `templates/supervisord-webserver.conf`:
    `php -S 0.0.0.0:80 -t /data/pub/ /data/phpserver/router.php`. Docroot is `/data/pub`
    (Magento's `pub/`), and it relies on Magento's `phpserver/router.php`.
  - Its `entrypoint.sh` already does the same Varnish port-switch
    (`sed 's/0.0.0.0:80/0.0.0.0:8080/'`) BEFORE calling `./start-services` (which is
    inherited from THIS base image). Once nginx's port-switch lives in this base's
    `start-services` (task 003), the downstream drops its own webserver sed.
- Key facts about Magento's `nginx.conf.sample`:
  - It is NOT standalone. It is a server-block FRAGMENT: no `listen`, no `server_name`, no
    `server {}`. It does `root $MAGE_ROOT/pub;` and `fastcgi_pass fastcgi_backend;`, and it
    references `$MAGE_ROOT`, `$MAGE_MODE` (and the multi-store `$MAGE_RUN_CODE` /
    `$MAGE_RUN_TYPE`). So it must be `include`d inside a wrapper `server {}` that sets those
    variables, and an `upstream fastcgi_backend {}` must exist in `http` context.
  - nginx `include` does NOT accept variables, so the wrapper `include`s a LITERAL path
    (`/data/nginx.conf.sample`). That file only exists once a Magento app is present at
    `/data`, which is true at the downstream's runtime, NOT at this base's build time, which
    is exactly why the wrapper ships inactive.
- Related files:
  - `templates/nginx/fastcgi_backend.conf` (new: `upstream fastcgi_backend { server 127.0.0.1:9000; }`; COPY to `/etc/nginx/conf.d/fastcgi_backend.conf`)
  - `templates/nginx/magento.conf` (new: the inactive wrapper; COPY to `/etc/nginx/available/magento.conf`, a path nginx does NOT include)
  - `Dockerfile` (two more COPYs)
- Patterns to follow:
  - Service config under `templates/`, COPY-ed in (task 001 established `templates/nginx/`).
- Notes:
  - `fastcgi_backend.conf` is a SEPARATE conf.d file from `default.conf` so that when the
    downstream overwrites `default.conf` with the Magento wrapper, the upstream survives.
  - The generic `default.conf` from task 001 is left unchanged (it keeps its literal
    `fastcgi_pass 127.0.0.1:9000;`). The `fastcgi_backend` upstream exists ONLY to satisfy
    Magento's sample; the generic base config does not use it. So this task does not depend
    on or modify task 001's server block.
  - The wrapper (`/etc/nginx/available/magento.conf`) MUST `set` EVERY nginx variable that
    Magento's `nginx.conf.sample` dereferences, or the activated config fails to load with
    `nginx: [emerg] unknown "MAGE_RUN_CODE" variable` (config load aborts on the first
    unknown variable, regardless of whether that request path is ever hit). At minimum the
    wrapper must contain, in this order inside the `server {}`:
    - `listen 80;`
    - `server_name _;`
    - `set $MAGE_ROOT /data;`
    - `set $MAGE_MODE developer;`
    - `set $MAGE_RUN_CODE '';`
    - `set $MAGE_RUN_TYPE '';`
    - `set $upstream fastcgi_backend;` is NOT needed (the sample uses the literal
      `fastcgi_pass fastcgi_backend;`), but DOUBLE-CHECK the installed sample: if it
      references any further `$MAGE_*`/`$MAGE_RUN_*` (or `$my_` style) variables, add a
      matching `set` for each. Treat "every `$var` the sample reads is `set` in the wrapper"
      as an acceptance gate, not an optional nicety.
    Then `include /data/nginx.conf.sample;`. Keep the literal `listen 80;` so the base
    `start-services` Varnish port-switch (task 003) rewrites it.
    Because the base test container has no `/data/nginx.conf.sample`, you cannot prove the
    activated config loads here; the variable-completeness check is a careful read of the
    sample, and the real `nginx -t` of the activated wrapper happens in the downstream repo.
  - The base's docroot default stays `/data` (generic). Magento's docroot (`/data/pub`) comes
    from the sample's `root $MAGE_ROOT/pub;`, not from `NGINX_DOCROOT`.
  - Do NOT activate the wrapper in the base (it would fail `nginx -t` at build because
    `/data/nginx.conf.sample` is absent). It is shipped purely as a one-cp convenience.

## Requirements (Test Descriptions)
These become assertions in `tests/run-tests.sh` (in-container). All assertions check the
SHIPPED / INERT state only. Do NOT activate the wrapper in any assertion: copying it over
`default.conf` and running `nginx -t` would FAIL in the base because `/data/nginx.conf.sample`
does not exist at base test time. The wrapper assertions are file-content greps, not config
validation.

- [x] `it defines an nginx upstream named fastcgi_backend targeting 127.0.0.1:9000`
- [x] `it keeps the fastcgi_backend upstream in a separate conf file from default.conf`
- [x] `it ships an inactive magento wrapper at /etc/nginx/available/magento.conf`
- [x] `it sets a literal listen 80 directive in the magento wrapper for the varnish port-switch`
- [x] `it sets the MAGE_RUN_CODE and MAGE_RUN_TYPE variables in the magento wrapper`
- [x] `it includes the app nginx.conf.sample from the magento wrapper`
- [x] `it still passes nginx -t with the generic default active and the wrapper inactive` (the wrapper lives under /etc/nginx/available which the shipped nginx.conf does not include, so nginx -t never parses it)

## Acceptance Criteria
- All requirements have passing assertions in `tests/run-tests.sh`
- The base still serves the generic front-controller on `:80` (the wrapper is inactive)
- The wrapper, when copied over `default.conf` with a Magento app present at `/data`, is a
  valid config (verified conceptually; full validation happens in the downstream repo)
- Code follows project standards (no em dashes)

## Implementation Notes
(Left blank - filled in by programmer during implementation)
