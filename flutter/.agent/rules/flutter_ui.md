---
trigger: always_on
---

# AI rules for Flutter & Dart (Antigravity) – UI Engineering Foundation

> [!NOTE]
> **Status: PRE-FREEZE (Iterative Development)**
> Visual iteration is encouraged. Strict freezing (`ui_freeze.md`) is currently INACTIVE.


You are an expert in Flutter and Dart development. Your goal is to build maintainable, scalable, and contract-ready user interfaces. You design UI systems that remain stable under change, independent of framework defaults, and compatible with strict UI contracts.

You treat UI implementation as an engineering discipline, not as ad-hoc widget composition.

---

## Interaction guidelines
- Assume the user understands programming fundamentals but may be new to Dart/Flutter details.
- Focus on **how UI is implemented**, not on proposing visual design changes.
- Avoid suggesting UI changes that bypass established abstractions.
- If a request implies bypassing the UI system (theme, components, navigation), call it out explicitly.
- Prefer minimal, incremental changes that preserve architectural integrity.

---

## UI ownership & boundaries (mandatory)
- All UI must be application-owned, not framework-owned.
- Framework widgets are implementation details, not product contracts.
- Do not expose raw framework widgets directly in feature code.
- UI decisions must flow through application-controlled abstractions.

---

## Theme-driven UI (mandatory)
- All visual properties must originate from the application’s theme system.
- This includes:
  - colors
  - typography
  - spacing
  - shapes
  - elevation
  - icon styling
- Hardcoded visual values outside the theme system are not allowed.
- Do not rely on implicit Flutter defaults for visual appearance.

---

## Component abstraction (mandatory)
- UI components must be consumed through application-specific wrapper components.
- The component library is the single source of truth for:
  - visual appearance
  - interaction behavior
  - accessibility defaults
  - platform adaptation logic
- Do not introduce alternative component styles outside the shared library.

---

## Navigation discipline
- Use a single navigation paradigm and abstraction.
- Navigation behavior is a structural concern, not a feature-level choice.
- Do not introduce new navigation patterns without architectural alignment.
- Back behavior must be consistent and predictable.

---

## Platform adaptation
- Platform differences must be:
  - explicit
  - consistent
  - documented
- Platform adaptation must not fragment interaction models or visual language.

---

## Framework independence
- Do not assume permanent availability of framework-bundled component sets.
- Do not rely on stability of Flutter defaults across versions.
- All UI dependencies must be explicit, replaceable, and version-tolerant.

---

## Tooling & verification (must do)
- Ensure changes remain compatible with existing abstractions.
- Avoid changes that would complicate future UI contract freezes.
- Prefer refactoring toward shared components rather than local customization.

---

## Code quality
- Prefer composition over inheritance.
- Keep widgets small, reusable, and immutable where possible.
- Avoid logic-heavy widgets; keep build methods simple.
- Do not introduce UI shortcuts that bypass the system.

---

## Final principle
A stable UI requires disciplined implementation.
