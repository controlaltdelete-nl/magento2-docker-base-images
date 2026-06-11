# Magento 2 Docker Base Images

All-in-one Docker images for Magento 2 CI/CD pipelines. Each image bundles PHP-FPM,
MySQL, Elasticsearch, Redis, and Varnish so a pipeline needs only a single container.

## Tech Stack

- **Base**: Ubuntu 22.04, Supervisord as process manager
- **Languages**: Bash (scripts), Dockerfile
- **PHP**: 7.1–8.5, parameterized via `PHP_VERSION` build arg (Ondřej Surý PPA)
- **Bundled**: MySQL, Elasticsearch 7.x (+icu/+phonetic), Redis, Varnish, Composer, Node (nvm), n98-magerun2
- **Testing**: custom Bash assertion runner (`tests/run-tests.sh`), run inside the container
- **Linting**: hadolint (Dockerfile), shellcheck (shell scripts)
- **CI**: GitHub Actions matrix → build, test, push to Docker Hub + ghcr.io

## Core Principles

- The container is the system under test. Validate changes by building the image and
  running `tests/run-tests.sh` inside it, not via host-side units.
- Every capability the image promises gets a matching assertion in the test runner.
- Keep service config in `templates/`; keep the `Dockerfile` lean and layer-efficient.
- Version-conditional logic branches explicitly and is tested at the edge versions.

## Project Structure

- `Dockerfile` — the image build, parameterized by `PHP_VERSION` / `NODE_VERSION`
- `scripts/` — `start-services`, `stop-services`, `retry` (copied to `/data`)
- `templates/` — Supervisord, Elasticsearch, Varnish, PHP config baked into the image
- `tests/run-tests.sh` — in-container assertion suite
- `.github/workflows/build-php-images.yml` — matrix build/test/push

## Commands

```bash
# Build one image
docker build --build-arg PHP_VERSION=8.4 -t magento2-base-image:8.4 .

# Build + test one PHP version (mirrors CI)
docker run --rm -v "$(pwd)/tests:/tests" -e PHP_VERSION=8.4 \
  magento2-base-image:8.4 bash -c './start-services && /tests/run-tests.sh'

# Lint
hadolint Dockerfile
shellcheck scripts/* tests/run-tests.sh
```

## Key Rules

- Quote shell variable expansions; use `set -e` where a failure must abort.
- Clean apt caches in the same `RUN` layer that installs; pin third-party repos by keyring.
- No em dashes in any text, code, comments, or commit messages.
- Add a `tests/run-tests.sh` assertion for any new extension, service, or tool.
- Build/test the affected PHP version(s) before declaring work done; sweep the full
  matrix before release or when touching version-conditional logic.
- Pre-configured DBs (`magento`, `magento-test`) and ports (9000/3306/9200/6379/80) are
  a public contract — don't change them without updating README and tests.

## Detailed Configuration

Project configuration files are in `.claude/`:
- `architecture.md` - Technical patterns and structure
- `testing.md` - Test configuration and commands
- `code-standards.md` - Coding conventions
- `pipeline.md` - Workflow agents per phase
