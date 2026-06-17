# Task 004: Add ENABLE_MAILPIT CI test run

**Status**: completed
**Depends on**: 003
**Retry count**: 0

## Description
Add a dedicated test invocation to the build workflow that runs the suite with
`ENABLE_MAILPIT=true`, mirroring how the `ENABLE_VARNISH=true` variant is exercised, so the
Mailpit runtime assertions run in CI for every PHP version in the matrix.

## Context
- Related files: `.github/workflows/build-php-images.yml`
- Patterns to follow:
  - The existing test steps (lines ~47-67): a default run, an `ENABLE_VARNISH=true` run,
    and an `NGINX_DOCROOT`/`PHP_FPM_MAX_CHILDREN` run, each
    `docker run -v .../tests:/tests -e PHP_VERSION=... <image> bash -c './start-services && /tests/run-tests.sh'`.
  - Add the new run with `-e ENABLE_MAILPIT=true` and the same image/command shape.
- Keep `fail-fast: false` matrix behavior; do not change build or push steps.

## Requirements (Test Descriptions)
- [ ] `it runs the test suite with ENABLE_MAILPIT true in CI`
- [ ] `it passes PHP_VERSION through to the mailpit test run`
- [ ] `it leaves the existing default and varnish test runs unchanged`
- [ ] `it does not alter the build or push steps`

## Acceptance Criteria
- The workflow YAML is valid and the new step matches the existing run conventions.
- The Mailpit run uses the same image reference and `start-services && run-tests.sh` command.
- No regression to existing test steps.

## Implementation Notes
(Left blank - filled in by programmer during implementation)
