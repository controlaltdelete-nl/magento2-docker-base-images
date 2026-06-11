# Code Standards

## Style

- Shell: POSIX-friendly Bash. `#!/bin/bash` shebang, `set -e` where a failure should
  abort. Quote variable expansions (`"$VAR"`). No em dashes anywhere.
- Dockerfile: group related `apt-get`/setup work into single `RUN` layers, clean apt
  caches in the same layer (`apt-get clean && rm -rf /var/lib/apt/lists/*`), pin
  third-party repos by signed keyring.

## Linting

```bash
# Lint the Dockerfile
hadolint Dockerfile

# Lint shell scripts
shellcheck scripts/* tests/run-tests.sh build test.sh
```

## Pre-commit Checks

- `hadolint Dockerfile` is clean (or findings are deliberate and justified)
- `shellcheck` is clean on changed scripts
- The image builds for the affected PHP version(s)
- `tests/run-tests.sh` passes inside the built container

## Conventions

- Keep service config in `templates/`, not inlined in the `Dockerfile`.
- Helper scripts live in `scripts/` and are copied to the image WORKDIR (`/data`).
- Version-conditional logic in the `Dockerfile` uses explicit `if`/`sort -V` checks;
  document the reason inline only when the branch is non-obvious.
- No comments in shell logic that a descriptive function or variable name can replace.
- Copyright years, when added, use the current year (2026).
