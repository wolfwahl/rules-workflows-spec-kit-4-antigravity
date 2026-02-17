# Contributor Hardening Guide

## Purpose

This guide defines the minimum safety and reliability expectations for code changes in this repository.

## Non-Negotiable Principles

1. Supabase remains the only backend source of truth for product data and business logic.
2. Data safety takes precedence over implementation speed.
3. Changes must be incremental, reviewable, and reversible where possible.
4. Security and reliability checks are part of correctness, not optional polish.

## Required Local Checks Before PR

Run:

```bash
./scripts/architecture_boundary_audit.sh --fail-on-violations
./scripts/check_schema_drift.sh
./scripts/verify_migrations.sh
./scripts/run_flutter_checks.sh
```

If a check fails, fix the root cause or document explicit risk acceptance.

## Migration Safety Rules

1. Use additive migrations by default.
2. Follow expand-migrate-contract for schema evolution.
3. Avoid destructive operations in standard forward migrations.
4. Keep migration history immutable (no rename/delete of applied migration files).
5. Treat privilege and RLS changes as security-sensitive code.

## Observability Rules

1. Firebase is allowed for testing/observability only:
   - App Distribution
   - Crashlytics
   - Analytics
   - Performance Monitoring
2. Firebase must not host product data/auth/business logic.
3. Application behavior must remain correct if Firebase observability is unavailable.

## Test Quality Rules

1. Keep tests aligned with runtime behavior.
2. Flaky tests require formal quarantine workflow with owner and deadline.
3. Quarantine is temporary and tracked; it is not a permanent bypass.

## Release Readiness

Use the release hardening checklist before shipping:

- analyze/tests green
- architecture and migration checks green
- security-sensitive changes reviewed
- observability and incident readiness confirmed

## Logging Guidance

Prefer consistent operational log fields:

- timestamp_utc, level, service, feature, event, message
- include correlation IDs and stable entity IDs when relevant
- never log secrets or raw sensitive data

## Incident Readiness

Use the incident triage runbook process:

1. detect
2. classify
3. mitigate
4. verify
5. postmortem

Every incident should produce actionable follow-up items with owners and due dates.

## Definition of Done (Hardening Perspective)

A change is hardening-complete when:

1. required checks pass,
2. security/data-integrity implications are reviewed,
3. documentation is updated where behavior/process changed,
4. residual risks are explicitly tracked.
