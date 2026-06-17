# Task 001: Install Mailpit binary, supervisord program, expose ports

**Status**: completed
**Depends on**: none
**Retry count**: 0

## Description
Install a pinned Mailpit static binary in the Dockerfile, add a supervisord program block
that runs it on demand (not at startup), and expose the SMTP and web/API ports. This is
the foundational install that later tasks build on. All Dockerfile edits for this feature
live here so no other task touches the Dockerfile.

## Context
- Related files:
  - `Dockerfile` (add a `MAILPIT_VERSION` build arg, a `RUN` that downloads/installs the
    binary, a `COPY` for the new supervisord conf, and the new `EXPOSE` ports)
  - `templates/supervisord/mailpit.conf` (new file)
- Patterns to follow:
  - Varnish supervisord block `templates/supervisord/varnish.conf` (`autostart=false`,
    `autorestart=true`, stdout/stderr to `/dev/stdout`/`/dev/stderr`, maxbytes 0).
  - The Dockerfile uses ONE explicit `COPY` per supervisord conf (lines 48-53), NOT a
    glob. Add a matching explicit `COPY templates/supervisord/mailpit.conf
    /etc/supervisor/conf.d/mailpit.conf` line alongside them.
  - The single `EXPOSE 9000 3306 9200 6379 80` line is at line 190. Extend it in place to
    `EXPOSE 9000 3306 9200 6379 80 1025 8025` (one EXPOSE instruction, matching the
    existing style; do not add a second EXPOSE line).
  - Third-party install convention: pin a version, download, verify, clean in the same
    `RUN` layer. Use the GitHub release asset
    `https://github.com/axllent/mailpit/releases/download/v${MAILPIT_VERSION}/mailpit-linux-amd64.tar.gz`,
    extract `mailpit` to `/usr/local/bin/mailpit`, `chmod +x`.
  - Bind both listeners to all interfaces in the program command:
    `--smtp 0.0.0.0:1025 --listen 0.0.0.0:8025`.
  - Place the `MAILPIT_VERSION` build arg with the other build args near the top of the
    Dockerfile (next to `PHP_VERSION`/`NODE_VERSION`). Pin the default to `1.30.2`
    (i.e. `ARG MAILPIT_VERSION=1.30.2`; the release tag is `v${MAILPIT_VERSION}` =
    `v1.30.2`). Do not let workers pick their own version.
  - The download is from GitHub releases (not an apt repo), so verify integrity: download
    the matching `checksums.txt` from the same release and run a `sha256sum -c` filtered to
    the amd64 asset, all inside the one `RUN`. Remove the tarball and checksums file in the
    same layer. Do NOT use an unpinned "latest" URL.
  - Add the install as its own `RUN` near the other binary installs (Composer/Magerun),
    not folded into the apt `RUN`, so hadolint stays clean and the layer is self-contained.

## Requirements (Test Descriptions)
- [ ] `it installs the mailpit binary at /usr/local/bin/mailpit`
- [ ] `it makes the mailpit binary executable and reports a version`
- [ ] `it parameterizes the mailpit version via a MAILPIT_VERSION build arg`
- [ ] `it ships a mailpit supervisord program with autostart disabled`
- [ ] `it binds mailpit smtp to 0.0.0.0:1025 and the web ui to 0.0.0.0:8025 in the program command`
- [ ] `it exposes ports 1025 and 8025`

## Acceptance Criteria
- All requirements have passing tests (assertions land in Task 003; this task makes the
  artifacts they check exist).
- The image builds with the default `MAILPIT_VERSION` and with an overridden value.
- `hadolint Dockerfile` passes; the install `RUN` cleans up any downloaded tarball.
- No change to default startup behavior (Mailpit stays off until enabled).

## Implementation Notes
(Left blank - filled in by programmer during implementation)
