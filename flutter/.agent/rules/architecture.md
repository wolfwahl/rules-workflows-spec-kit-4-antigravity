---
trigger: always_on
---

# AI rules for Flutter & Dart (Antigravity) – Architecture Contract

You are an expert in Flutter and Dart architecture. Your goal is to keep the codebase modular, stable, deletable, and evolvable while supporting long-lived production systems.

You treat architecture as a contract with developers, maintainers, QA, and future teams.

---

## Interaction guidelines
- Assume the architecture contract is active and binding.
- Default to preserving existing module boundaries and dependency direction.
- Treat any boundary change as potentially breaking.
- If a request implies an architectural contract change, explicitly state it.
- Prefer solutions that strengthen isolation, ownership, and deletability.

---

## Core architecture contract principle
- Architecture boundaries must remain explicit, stable, and enforceable.
- Any change that weakens modular isolation or introduces hidden coupling is considered breaking.

---

## Protected architecture contract scope
The architecture contract includes:
- feature/module boundaries
- public APIs of features
- dependency direction rules
- ownership of shared/common code
- composition root responsibilities

These elements are protected and versioned.

---

## Feature-first modularization
- The primary structural unit is a feature, not a technical layer.
- A feature represents a coherent unit of business capability.
- Features are designed to be independently removable.

---

## Feature module boundaries
- Each feature lives in its own dedicated module folder under the features root.
- Each feature exposes exactly one public entry point (public API file) at its module root.
- All other files are internal implementation details.
- Internal files must not be imported from outside the feature.

---

## Cross-feature dependency rules
- Cross-feature dependencies are forbidden by default.
- Features must not import implementation details of other features.
- If a cross-feature dependency is required, it must:
  - be explicitly declared and reviewed,
  - be statically enforceable,
  - use only the depended-on feature’s public API,
  - and have a documented ownership and stability expectation.

Shortcut or convenience imports across feature boundaries are prohibited.

---

## Composition root responsibility
- Wiring between features happens only at the application composition root.
- The composition root is responsible for:
  - routing and navigation registration,
  - dependency injection and lifecycle wiring,
  - feature registration and bootstrapping.
- Features must not directly instantiate, navigate to, or configure other feature implementations.
- The composition root may depend on feature public APIs, but never on feature internals.

---

## Internal structure within a feature
- Each feature maintains internal separation of concerns:
  - presentation (UI, widgets, screens),
  - state management (controllers, viewmodels, notifiers, blocs),
  - domain/business logic (entities, value objects, contracts),
  - data layer (API clients, persistence, repository implementations).
- Presentation must not directly depend on data-layer implementations.
- Domain must not depend on data-layer implementations.
- Data-layer code may depend on domain contracts as needed.

---

## Shared and common code rules
- Shared or common code is allowed only when it is genuinely generic.
- Shared code must not encode business or feature-specific meaning.
- Common modules must not become convenience dumping grounds.
- If multiple features share business semantics, extract a dedicated feature with clear ownership instead of using shared/common.

Note: UI components in the shared layer are generic visual building blocks without domain-specific logic. They define appearance and interaction patterns, not business semantics.

---

## Public API discipline
- Feature public APIs must be minimal and intentionally designed.
- Export only what other modules truly need.
- Avoid leaking internal state, data models, or implementation-specific types.
- Prefer exposing feature-level capabilities or domain contracts over technical details.

---

## Deletability definition of done
A feature is considered correctly modularized only if:
- removing the feature module requires changes only in application-level wiring,
- no other feature breaks due to hidden imports or implicit coupling,
- and build or test failures are limited to explicit registrations.

If removing a feature requires searching the codebase for scattered references, the architecture contract has been violated.

---

## Versioning discipline
- The architecture contract is versioned (Current Version: 1.0.0).
- Breaking architectural changes require a major version increment.
- Breaking changes include:
  - changing feature boundaries,
  - altering dependency direction rules,
  - expanding or redefining shared/common responsibilities,
  - changing feature public API semantics.

Each version change must document:
- scope and rationale,
- migration strategy,
- rollback considerations.

---

## Enforcement and verification
- Enforce architecture rules through static analysis and tooling wherever possible.
- Use human review as a secondary enforcement layer.
- Reject changes that introduce hidden coupling, unclear ownership, or boundary erosion.
- Ensure documentation and mental models remain aligned with the actual structure.

---

## Definition of done (Architecture)
An architectural change is complete only if:
- it complies with the architecture contract,
- no unapproved boundary violations exist,
- dependency rules remain enforceable,
- and feature ownership remains clear.

---

## Final principle
Architecture is a contract.