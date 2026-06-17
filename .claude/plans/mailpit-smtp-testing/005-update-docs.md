# Task 005: Update README and architecture docs

**Status**: completed
**Depends on**: 002, 003
**Retry count**: 0

## Description
Document the Mailpit capability so the public contract stays accurate: the new env var,
the exposed ports, the services list, and a short usage note covering the SMTP port and
the captured-mail REST API. Update the architecture doc's port/convention notes to match.

## Context
- Related files:
  - `README.md` (the `## Services` note ~62-69, the env-var table ~76-80, the
    `## Exposed Ports` table ~118-126)
  - `.claude/architecture.md` (the "Exposed ports" convention line ~39 and the
    optional-services description)
- Patterns to follow:
  - The existing `ENABLE_VARNISH` row in the env-var table and the port-table format.
  - Keep the documented port contract complete: add `1025` (SMTP) and `8025` (web UI/API).
  - Project rule: no em dashes in docs.

## Requirements (Test Descriptions)
- [ ] `it documents the ENABLE_MAILPIT env var and its effect`
- [ ] `it lists ports 1025 and 8025 in the exposed ports table`
- [ ] `it explains how to capture mail via the smtp port and read it from the rest api`
- [ ] `it notes mailpit is opt-in and off by default`
- [ ] `it documents that PHP mail() is auto-routed to mailpit via sendmail_path when enabled`
- [ ] `it updates the architecture doc exposed-ports line to include 1025 and 8025`

## Acceptance Criteria
- README and architecture doc accurately reflect the shipped behavior from tasks 001-003.
- Port and env-var tables are consistent with the Dockerfile `EXPOSE` and `start-services`.
- No em dashes; matches the surrounding doc style.

## Implementation Notes
(Left blank - filled in by programmer during implementation)
