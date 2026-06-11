# Testing Configuration

## Test Framework

Custom Bash assertion runner at `tests/run-tests.sh`. Tests execute INSIDE a built
container against the running services. There is no host-side unit framework; the
container is the system under test.

Helpers in `tests/run-tests.sh`:
- `assert "<desc>" <cmd...>` — passes if the command exits 0
- `assert_contains "<desc>" "<expected>" <cmd...>` — passes if stdout/stderr matches `<expected>`
- Tracks `FAILURES`; exits non-zero if any assertion fails

## Methodology

This project tests behavior of a built image, not source units. The loop is:

1. Change the `Dockerfile`, a `scripts/` helper, or a `templates/` config
2. Build the image for the relevant PHP version
3. Start services and run the test suite inside the container
4. Add or adjust an assertion in `tests/run-tests.sh` for any new guarantee
5. Commit when the image builds clean and all assertions pass

New capabilities added to the image (extensions, services, tools) MUST get a matching
assertion in `tests/run-tests.sh`.

## Commands

```bash
# Build an image for one PHP version
docker build --build-arg PHP_VERSION=8.4 -t magento2-base-image:8.4 .

# Build + run the full suite for one PHP version (mirrors CI)
docker run --rm -v "$(pwd)/tests:/tests" \
  -e PHP_VERSION=8.4 \
  magento2-base-image:8.4 \
  bash -c './start-services && /tests/run-tests.sh'

# Same, with Varnish enabled
docker run --rm -v "$(pwd)/tests:/tests" \
  -e ENABLE_VARNISH=true -e PHP_VERSION=8.4 \
  magento2-base-image:8.4 \
  bash -c './start-services && /tests/run-tests.sh'

# Interactive debugging shell inside the image
docker run -it --rm magento2-base-image:8.4 bash -c './start-services && bash'
```

## Parallel Execution

CI builds all PHP versions as a matrix (fail-fast off), so each version's image
builds and tests in parallel on separate runners. Locally, build/test one PHP
version at a time for a fast feedback loop; only sweep the full matrix
(7.1–8.5) before a release or when a change touches version-conditional logic
in the `Dockerfile`.

## Coverage Expectations

Every service and tool the image promises (see README "What's Included") must have
an assertion: PHP + extensions, MySQL databases/users, Redis, Elasticsearch +
plugins, Composer, Node/nvm, Magerun, and Varnish when enabled.

## PHP Version Matrix

`7.1`, `7.2`, `7.3`, `7.4`, `8.1`, `8.2`, `8.3`, `8.4`, `8.5`. Several parts of the
`Dockerfile` branch on version (opcache packaging, Magerun phar URL) — test the
edge versions (7.1, 7.4, 8.5) when touching that logic.
