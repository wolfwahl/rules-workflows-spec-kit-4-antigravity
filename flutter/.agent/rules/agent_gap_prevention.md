---
trigger: always_on
---

# Agent Gap Prevention Rules

These rules reduce the chance that future agents recreate known gaps.

## 1. Pre-change checklist (mandatory)
Before making substantial changes, the agent must confirm:
- relevant `always_on` rules are loaded,
- target boundaries are identified (feature, data, CI, security),
- required validation steps are known.
- test-scope impact is identified (coverage scope, mutation targets, exclusions, CI gates).
- test-impact mapping is identified (changed behavior -> required test types/files).
- potential quality-scope shrink risk is identified (include/exclude/target/exclusion list deltas).

## 2. Post-change self-audit (mandatory)
Before finalizing, the agent must verify:
- no new boundary violations were introduced,
- no safety rule was weakened,
- changed behavior is covered by existing or updated rules,
- required checks were executed or explicitly justified as skipped.
- scoped quality artifacts are current for the active gate context:
  - commit DoD scope: scoped `quality_baseline_*`
  - push/remote full scope: `quality_baseline_*` and `mutation_gate_*`
- for each changed behavior, automated test deltas exist (or an approved `TEST_EXCEPTION` is documented).
- no silent quality-scope shrink was introduced without explicit user approval.

## 3. No silent regressions
- If tooling assumptions are platform-specific or optional, fallback behavior must be provided.
- Scripts used in CI must avoid non-portable dependencies unless guaranteed by runner setup.
- If platform-specific branches are not executable in CI, this must be encoded as an explicit tested seam or a documented mutation exclusion.
- Required quality gates must stay aligned between `scripts/run_local_ci.sh` and `.github/workflows/flutter-ci.yml`.

## 4. Quality gate for completion claims
- The agent must not state completion while known failing required checks exist.
- The agent must communicate residual risk in plain language.
- The agent must not rely on manual/one-off quality calculations when project scripts and gates exist.
- The agent must not treat manual exploratory testing as a replacement for required automated tests.
- The agent must end each final delivery with a machine-checkable completion state:
  - `Status: Abgeschlossen` or `Status: Nicht abgeschlossen`.
  - Missing status is treated as process failure.

## 5. Rule-set compactness
- Prefer updating existing rules before adding new rule files.
- Add a new rule file only when no existing rule has clear ownership of the constraint.
