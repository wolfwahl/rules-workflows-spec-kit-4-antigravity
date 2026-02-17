# Test Suite 10/10 Checklist

This checklist defines the quality bar for a "10/10" test-suite run.

## Scope
- Production scope: all `lib/**/*.dart`
- Exclusions: generated files and `lib/l10n/**` (from `ops/testing/coverage_exclude_patterns.txt`)

## Required outcomes
1. Scoped branch coverage is exactly `100.00%` (`BRDA`).
2. No runtime warning noise in test output (especially Drift multi-database warning).
3. No unapproved `TEST_EXCEPTION` usage.
4. Mutation gates pass in stable profile; strict profile has no unknown regressions.
5. Stability matrix passes across repeated runs with Flutter default concurrency.

## Command sequence
1. Scoped/full local CI baseline:
   - `bash ./scripts/run_local_ci.sh --skip-mutation`
2. Deep 10/10 mode (includes stability matrix):
   - `bash ./scripts/run_local_ci.sh --ten-of-ten --skip-mutation`
3. Mutation stable + strict:
   - `bash ./scripts/run_mutation_gate.sh`
   - `bash ./scripts/run_mutation_gate.sh --operator-profile strict --no-threshold-fail`
4. Explicit coverage proof:
   - `bash ./scripts/verify_coverage_baseline.sh --lcov coverage/lcov.info --quality-gates ops/testing/quality_gates.env --include-patterns ops/testing/coverage_include_patterns.txt --exclude-patterns ops/testing/coverage_exclude_patterns.txt`
5. Optional direct stability run:
   - `bash ./scripts/run_test_stability_matrix.sh --iterations 2 --concurrency-list auto`

## Evidence artifacts
- `.ciReport/quality_baseline_*.md`
- `.ciReport/quality_baseline_snapshot_*.env`
- `.ciReport/mutation_gate_*.md`
- `.ciReport/mutation_gate_strict_*.md`
- `.ciReport/test_stability_matrix_*.log`

## Notes
- Keep `ops/testing/test_exceptions.txt` empty unless explicitly approved by the user in-thread.
- If a warning/noise pattern appears in logs, either fix root cause or add deterministic test bootstrap handling.
