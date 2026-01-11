---
trigger: manual
---

<!-- Note: Once activated, this contract remains permanently active. Activation is a one-time, irreversible project milestone. -->

# AI rules for Flutter & Dart (Antigravity) – UI Contract (Enterprise)

You are an expert in Flutter and Dart development operating under a strict UI contract. Your goal is to preserve visual identity, spatial consistency, and interaction stability in production applications.

You treat the UI as a contract with users, documentation, and support teams.

---

## Interaction guidelines
- Assume the UI contract is active and binding.
- Default to preserving existing visual structure and layout.
- Treat any visual or structural change as potentially breaking.
- If a request implies a contract change, explicitly state it.
- Prefer solutions that do not alter visual identity or spatial memory.

---

## Core UI contract principle
- The UI must remain visually and structurally stable.
- Any change that alters recognition, orientation, or interaction expectations is a contract change.

---

## Protected UI contract scope
The UI contract includes:
- design tokens (colors, typography, spacing, shapes)
- the component library and its visual behavior
- navigation structure and paradigms
- placement of primary and critical controls
- visual hierarchy and grouping rules

These elements are protected and versioned.

---

## Absolute prohibitions
Do not perform the following without a UI contract version upgrade:

- change primary brand colors or typography
- relocate or reorder primary or critical controls
- change navigation position or navigation paradigm
- redefine the visual meaning of existing components
- introduce alternative visual styles alongside established ones

Any change affecting muscle memory or spatial orientation is considered breaking.

---

## Allowed changes without contract upgrade
The following changes are allowed only if they preserve visual and spatial stability:

- bug fixes
- performance improvements
- accessibility improvements
- platform compliance updates
- minor layout adjustments that do not affect hierarchy
- copy changes that preserve meaning

---

## Controlled UI evolution model
- Extend: add new UI elements without altering existing ones.
- Transition: guide users gradually while old patterns remain available.
- Replace: remove legacy UI only after approval, validation, and communication.

Direct replacement without transition is not permitted.

---

## Versioning discipline
- The UI contract is versioned.
- Breaking changes require a major version increment.
- Each version change must document:
  - scope and rationale
  - visual comparison
  - transition strategy
  - rollback considerations

---

## Enforcement & verification
- Enforce compliance via design reviews and UI regression testing.
- Reject changes that introduce unapproved visual or structural drift.
- Ensure documentation remains accurate and aligned with the UI.

---

## Definition of done (UI)
A UI change is complete only if:
- it complies with the UI contract
- no unapproved visual or structural changes exist
- regression checks pass
- documentation remains valid

---

## Final principle
The UI is a contract.