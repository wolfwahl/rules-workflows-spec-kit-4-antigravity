# Reliability Ops Inputs

This directory contains docs for reliability reporting automation.

## Model

- No manual snapshot file is required.
- `scripts/generate_reliability_report.sh` reads:
  - app version automatically from `pubspec.yaml`
  - optional runtime env vars (`RELIABILITY_*`) from CI or local shell
- `scripts/collect_reliability_metrics.sh` auto-populates available `RELIABILITY_*` values from GitHub APIs.

## Automated Inputs

```bash
bash ./scripts/collect_reliability_metrics.sh
```

Output:
- Writes a snapshot env file (in CI/local runs now under `.ciReport/` with timestamp)
- Exports the same values into `GITHUB_ENV` when running in GitHub Actions

For local runs, set a token if you want live GitHub metrics:

```bash
export GITHUB_TOKEN=<token-with-actions-and-issues-read>
bash ./scripts/collect_reliability_metrics.sh
```

Without `GITHUB_TOKEN`, the report is still generated but with partial placeholders.

## Required GitHub Labels

The collector derives incident metrics from issue labels. Use these labels consistently:
- `incident`
- `sev1`, `sev2`, `sev3`, `sev4`
- `flaky-test`
- `reopened` (for reopen-rate calculation)

## Generate Report

```bash
./scripts/generate_reliability_report.sh
```

Optional:

```bash
./scripts/generate_reliability_report.sh \
  --output .ciReport/reliability_operational_report_YYYYMMDD-HHMMSS.md
```

## CI/Local Output Convention

- Local `scripts/run_local_ci.sh` stores:
  - `.ciReport/reliability_snapshot_<UTC_TIMESTAMP>.env`
  - `.ciReport/reliability_operational_report_<UTC_TIMESTAMP>.md`
- GitHub Actions uses the same naming pattern and uploads both files as artifacts.

## Verify Report Statuses

```bash
./scripts/verify_reliability_report.sh --fail-on-unknown false
```

Strict mode (for later):

```bash
./scripts/verify_reliability_report.sh --fail-on-unknown true
```

## Example CI Inputs

```bash
RELIABILITY_FLAVOR=prod \
RELIABILITY_TIME_WINDOW=24h \
RELIABILITY_CRASH_FREE_SESSIONS_PCT=99.8 \
RELIABILITY_ERROR_RATE_PER_1K_SESSIONS=2.9 \
RELIABILITY_MTTR_SEV2_PLUS_HOURS_30D=6.0 \
./scripts/generate_reliability_report.sh
```
