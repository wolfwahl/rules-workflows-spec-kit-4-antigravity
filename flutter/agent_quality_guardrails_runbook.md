# Agent Quality Guardrails Runbook

## 1) Purpose

This runbook is for an **agent that must follow project rules** and keep quality stable under change.

Operational guarantee model:
- Primary enforcement is automatic via Git hooks and GitHub Actions gates.
- The agent must treat automatic gate outcomes as authoritative.
- The agent must block completion if required gates fail or are skipped.
- The agent must prevent silent quality-scope weakening.

### 1.1 Execution model: one-time activation, continuous enforcement

- The bring-up sequence in this runbook is intended to be executed once per project clone/environment.
- After that one-time activation, enforcement is automatic via hooks (`pre-commit`, `pre-push`) and CI.
- Agents should not re-run the full bring-up sequence for every task.
- Re-run setup only when environment/tooling changes break guardrails (for example: hooks missing, CI config changes, or quality gate script/policy changes).

## 2) Non-negotiable enforcement rules

1. Always load and follow active `always_on` rules.
2. Never mark work complete with failing required checks.
3. Never replace automated validation with manual QA only.
4. Never silently shrink quality scope.
5. Never add/expand `TEST_EXCEPTION` entries without explicit user approval.
6. Keep local and remote quality gates aligned.
7. Never bypass hook/CI gates as a normal workflow.

## 3) Files that define the guardrail system

### 3.1 Gate entry points
- `.githooks/pre-commit`
- `.githooks/pre-push`
- `.github/workflows/flutter-ci.yml`
- `scripts/install_git_hooks.sh`

### 3.2 Core orchestration
- `scripts/verify_dod.sh`
- `scripts/run_local_ci.sh`
- `scripts/run_flutter_checks.sh`
- `scripts/flutterw.sh`
- `scripts/verify_flutter_env.sh`

### 3.3 Gate and verification scripts
- `scripts/architecture_boundary_audit.sh`
- `scripts/check_schema_drift.sh`
- `scripts/verify_migrations.sh`
- `scripts/verify_feature_test_parity.sh`
- `scripts/verify_coverage_baseline.sh`
- `scripts/generate_quality_baseline_report.sh`
- `scripts/verify_test_quality_guards.sh`
- `scripts/run_mutation_gate.sh`
- `scripts/run_test_stability_matrix.sh`
- `scripts/verify_test_output_clean.sh`
- `scripts/collect_reliability_metrics.sh`
- `scripts/generate_reliability_report.sh`
- `scripts/verify_reliability_report.sh`
- `tool/mutation/ast_mutation_gate.dart`

### 3.4 Policy and threshold inputs
- `ops/testing/coverage_baseline.env`
- `ops/testing/quality_gates.env`
- `ops/testing/coverage_include_patterns.txt`
- `ops/testing/coverage_exclude_patterns.txt`
- `ops/testing/feature_test_parity_baseline.txt`
- `ops/testing/mutation_targets.txt`
- `ops/testing/mutation_exclude_mutants.txt`
- `ops/testing/test_exceptions.txt`
- `ops/testing/test_suite_10of10.md`
- `ops/reliability/README.md`

### 3.5 Test scope setup references
- Scope pattern: `test/**/*_test.dart`
- Helper support: `test/test_helpers/**`
- Flutter test bootstrap: `test/flutter_test_config.dart`

### 3.6 Optional DB drift/migration gates
- `scripts/check_schema_drift.sh`
- `scripts/verify_migrations.sh`
- `supabase/dump/schema.sql`
- `supabase/migrations/*.sql`

### 3.7 Optional rule layer (if this agent workflow is active)
- `.agent/rules/git_workflow.md`
- `.agent/rules/flutter_dart.md`
- `.agent/rules/flutter_ui.md`
- `.agent/rules/definition_of_done.md`
- `.agent/rules/agent_gap_prevention.md`
- `.agent/rules/architecture.md`
- `.agent/rules/artifact_persistence.md`
- `.agent/rules/knowledge_continuity.md`
- `.agent/rules/permanent_data_integrity.md`
- `.agent/rules/supabase_only.md`
- `.agent/rules/supabase_performance.md`

### 3.8 Platform validation reference
- `docs/windows-script-validation.md`

## 4) Automatic gate enforcement (primary)

### 4.1 Commit context
- Trigger: Git `pre-commit` hook.
- Entry point: `.githooks/pre-commit`.
- Effective gate: `bash ./scripts/verify_dod.sh`.
- Purpose: fast scoped DoD checks for changed/new files.

### 4.2 Local push context
- Trigger: Git `pre-push` hook.
- Entry point: `.githooks/pre-push`.
- Effective gate: `bash ./scripts/run_local_ci.sh --skip-mutation`.
- Purpose: full pre-push validation.

### 4.3 Remote push to `main` context
- Trigger: GitHub Actions on push to `main`.
- Entry: `.github/workflows/flutter-ci.yml`
- Includes analyze, tests+coverage, coverage gate, quality artifacts, mutation gates, reliability artifacts.
- This is the primary remote quality authority.

### 4.4 Explicit "10/10" quality request
- Commands:
  - `bash ./scripts/run_local_ci.sh --ten-of-ten --skip-mutation`
  - `bash ./scripts/run_test_stability_matrix.sh`

## 5) Agent-driven pre-checks (secondary, on-demand only)

Use these only when needed (for example: risky refactors, repeated local failures,
or before a large commit). They do not replace automatic gates.

1. Fast scoped sanity check:
   - `bash ./scripts/verify_dod.sh`
2. Full local validation before push:
   - `bash ./scripts/run_local_ci.sh --skip-mutation`
3. Mutation-focused check for risky logic:
   - `bash ./scripts/run_mutation_gate.sh`

## 6) Anti-regression protocol for quality changes

If any of these change:
- `ops/testing/*`
- `scripts/verify_coverage_baseline.sh`
- `scripts/generate_quality_baseline_report.sh`
- `scripts/verify_test_quality_guards.sh`
- `scripts/verify_dod.sh`
- `scripts/run_local_ci.sh`
- `.github/workflows/flutter-ci.yml`

The agent must:
1. Run commit-level and push-level required gates.
2. Verify no quality-scope shrink was introduced.
3. Verify local and remote gate definitions remain aligned.
4. Provide explicit evidence in `.ciReport/` artifacts.

## 7) Forbidden quality-scope weakening (without explicit approval)

1. Broadening `coverage_exclude_patterns.txt` beyond technical generated-file exclusions.
2. Removing or narrowing required include patterns in `coverage_include_patterns.txt`.
3. Removing mutation targets from `mutation_targets.txt`.
4. Adding broad mutation exclusions in `mutation_exclude_mutants.txt`.
5. Adding exception entries in `test_exceptions.txt` without explicit approval.

### 7.1 Coverage include/exclude configuration guidance

1. Keep include scope broad for production code (default pattern: `^lib/.*\.dart$`).
2. Use exclude scope only for technical artifacts (generated code and l10n outputs).
3. Do not exclude feature paths, domains, or modules to satisfy gates.
4. Any new exclude must be minimal, explicit, and justified in code review.
5. After include/exclude edits, run:
   - `bash ./scripts/verify_coverage_baseline.sh`
   - `bash ./scripts/run_local_ci.sh --skip-mutation`

## 8) Evidence package required before completion

The agent should attach/provide:
1. Commands executed.
2. Pass/fail status per required gate.
3. Relevant `.ciReport/*` artifacts, at least:
   - `quality_baseline_*.md`
   - `quality_baseline_snapshot_*.env`
   - `mutation_gate_*.md` (when mutation is in scope)
   - `reliability_operational_report_*.md`
4. Residual risks (if any) and why they are acceptable.

## 9) First-time local bring-up (run once per clone/environment)

1. `./scripts/flutterw.sh pub get`
2. `bash ./scripts/install_git_hooks.sh`
3. `bash ./scripts/verify_flutter_env.sh`
4. `bash ./scripts/verify_dod.sh`
5. `bash ./scripts/run_local_ci.sh --skip-mutation`

## 10) Port this guardrail system to another project (same stack)

### 10.1 Copy setup assets
1. `.githooks/`
2. `.github/workflows/`
3. `scripts/`
4. `ops/testing/`
5. `tool/mutation/`
6. `ops/reliability/README.md`
7. `test/flutter_test_config.dart` (or equivalent)

Optional for Supabase migration guardrails:
1. `supabase/dump/schema.sql`
2. `supabase/migrations/`

### 10.2 Mandatory project-specific adjustments
1. Update package prefix assumptions in `scripts/architecture_boundary_audit.sh`.
2. Re-map `ops/testing/mutation_targets.txt` to project paths.
3. Initialize `ops/testing/coverage_baseline.env` with a realistic baseline.
4. Adjust thresholds in `ops/testing/quality_gates.env`.
5. Keep include scope broad in `ops/testing/coverage_include_patterns.txt` (default: `^lib/.*\.dart$`).
6. Keep excludes technical-only in `ops/testing/coverage_exclude_patterns.txt` (generated/l10n artifacts).
7. Review `ops/testing/feature_test_parity_baseline.txt`.
8. Keep `ops/testing/test_exceptions.txt` empty unless explicitly approved.
9. Verify branch triggers in `.github/workflows/flutter-ci.yml`.

### 10.3 Bring-up sequence in target project
1. `./scripts/flutterw.sh pub get`
2. `bash ./scripts/install_git_hooks.sh`
3. `bash ./scripts/verify_flutter_env.sh`
4. `bash ./scripts/verify_dod.sh`
5. `bash ./scripts/run_local_ci.sh --skip-mutation`
6. `bash ./scripts/run_local_ci.sh` or `bash ./scripts/run_mutation_gate.sh`

## 11) Completion criteria for the agent

Only declare completion when all are true:
1. Automatic required context gates passed.
2. No unresolved rule violations.
3. No unauthorized quality-scope weakening.
4. Evidence package is present and current.
5. Remote CI definition remains consistent with local guardrails.
