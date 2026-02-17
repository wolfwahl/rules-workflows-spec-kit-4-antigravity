# Architecture Boundaries

## Goal

Keep features isolated and deletable by enforcing imports through feature public APIs only.

## Rule

- Allowed cross-feature import:
  - `package:hsf/features/<feature>/<feature>.dart`
- Forbidden cross-feature import:
  - Any direct import into `data/`, `domain/`, `presentation/`, `services/`, etc. of another feature.

## Local Check

Run:

```bash
./scripts/architecture_boundary_audit.sh --fail-on-violations
```

## CI Check

The same check is enforced in `.github/workflows/flutter-ci.yml`.

## Migration Guidance

If a symbol is needed across features:

1. Export it from the owning feature API file.
2. Import only the feature API from consuming modules.
3. Re-run the boundary audit and ensure zero violations.

