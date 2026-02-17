---
trigger: always_on
---

# Definition of Done (DoD) Rules

These rules define when work is allowed to be marked as done.
If one DoD item is not satisfied, the work is not done.

## 1. Scope completeness
- The implementation must match the user request and accepted constraints.
- Open assumptions must be explicitly listed.
- No hidden scope cuts are allowed.
- DoD verification scope is limited to semantic deltas of changed/new files and affected features (commit mode: staged delta).

## 2. Rule compliance
- All `always_on` rules must be checked before completion.
- If a conflict between rules is detected, the conflict must be raised explicitly.
- Work must not be closed while a known rule violation remains unresolved.

## 3. Verification evidence
- Modified code must be validated with relevant checks (format, lint/analyze, tests, scripts).
- The final report must contain concrete evidence of what was run and what passed/failed.
- If a check cannot be run, the reason and risk must be documented.
- Any new implementation with user-visible or business-relevant behavior is incomplete without automated test changes in the same delivery.
- Any behavior change is incomplete without automated test changes in the same delivery.
- For new implementation/behavior changes/bug fixes, the final report must list:
  - test files added/updated,
  - scenario mapping (happy/error/edge) covered by those tests.
- For test-relevant changes (production logic, tests, quality-gate config), required minimum evidence is context-bound:
  - local commit (pre-commit DoD): `bash ./scripts/verify_dod.sh` (scoped to changed/new files/features, mutation skipped)
  - local push (pre-push CI): `bash ./scripts/run_local_ci.sh --skip-mutation` (full project scope without mutation)
  - remote push (CI): full gate pipeline from `.github/workflows/flutter-ci.yml` (includes mutation)
- When the user explicitly requests "10/10" test-suite quality, additional evidence is mandatory:
  - `bash ./scripts/run_local_ci.sh --ten-of-ten --skip-mutation`
  - stability matrix log without warnings from `.ciReport/test_stability_matrix_*.log`
  - scoped branch coverage proof at `100.00%` via `scripts/verify_coverage_baseline.sh`
- Coverage and mutation claims must be based on scoped testable code only, as defined in:
  - `ops/testing/coverage_include_patterns.txt`
  - `ops/testing/coverage_exclude_patterns.txt`
  - `ops/testing/mutation_targets.txt`
  - `ops/testing/mutation_exclude_mutants.txt`
- Coverage acceptance is based on scoped branch coverage (`BRDA`), with scoped line coverage only as a fallback when BRDA is unavailable.
- Quality scope must not be silently weakened:
  - expanding exclude patterns,
  - shrinking include patterns,
  - removing mutation targets,
  - or adding broad mutation exclusions
  is prohibited without explicit user approval and documented rationale/risk.
- When quality gates are changed, local and remote CI definitions must be updated together:
  - `scripts/run_local_ci.sh`
  - `.github/workflows/flutter-ci.yml`
- Ad-hoc manual coverage recalculation outside the scoped pipeline is not accepted as completion evidence.
- Test removals or assertion-weakening are prohibited unless replaced with equal-or-stronger automated coverage in the same delivery.
- A behavior change without tests is allowed only with explicit user-approved `TEST_EXCEPTION` containing:
  - reason,
  - risk,
  - owner,
  - due date for test debt closure.
- For UI files outside unified coverage scope, completion requires direct file-level `testWidgets` coverage (`test/.../<same_file>_test.dart`) unless an explicitly approved `TEST_EXCEPTION` exists.
- `TEST_EXCEPTION` entries must not be created or expanded by the agent without explicit user approval in the same thread.
- If an exception is proposed, approval must be requested first; without approval, the only valid path is writing tests and keeping quality gates green.

## 4. Data and migration safety
- Any schema/data change must preserve production data integrity.
- Expand/contract discipline must be respected.
- Destructive SQL is only acceptable within explicitly allowed migration contracts.

## 5. Knowledge persistence
- If the change introduces or updates operational behavior, a durable rule-level guardrail must exist in `.agent/rules`.
- If an incident exposed a process gap, that gap must be closed by creating or updating a rule before marking done.

## 6. Handover quality
- Final output must include:
  - what changed,
  - verification status,
  - remaining risks,
  - immediate next steps (if any).
- Final output must include an explicit completion declaration as the first line:
  - `Status: Abgeschlossen` only if all required DoD items are satisfied.
  - `Status: Nicht abgeschlossen` if any DoD item is open, failed, skipped, or unknown.
- A response without this explicit status declaration is itself a DoD violation.

## 7. Stop condition
- Never claim "done" while critical blockers, failing required checks, or unresolved safety risks are known.
- Never claim "done" while scoped quality gates are missing, stale, or based on unscoped code.
- Never claim "done" when mandatory tests for changed behavior are missing and no approved `TEST_EXCEPTION` exists.
