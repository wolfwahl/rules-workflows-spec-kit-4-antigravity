---
trigger: always_on
---

# Knowledge Continuity Rules

Goal: prevent loss of engineering knowledge and prevent repeated mistakes by future agents.

## 1. Rules are the durable control plane
- Process-critical knowledge must be encoded in `.agent/rules`, not only in implementation specs.
- If important guidance exists only in `.specification`, it must be translated into enforceable rules when it becomes recurring or safety-relevant.

## 2. Incident-to-rule conversion
- Every recurring failure pattern must produce a new or updated rule.
- Examples:
  - CI break due to missing execution permission
  - pipeline dependency on non-portable tooling
  - unsafe migration behavior
  - architecture boundary regression
  - coverage baseline drift caused by unscoped/non-testable code
  - mutation score instability caused by undocumented exclusions
  - platform-conditional branches that are permanently untested
  - UI or behavior regression caused by missing automated tests for changed behavior
  - quality metric inflation caused by shrinking test scope (coverage/mutation include-exclude manipulation)

## 3. Trigger discipline
- Safety and quality rules must be `always_on`.
- Workflow-specific guidance may be `manual`.
- Ambiguous activation is not allowed.

## 4. Rule quality standard
- Each rule must define:
  - intent,
  - mandatory behavior,
  - explicit prohibitions,
  - completion criteria.
- Rules must be testable in practice and phrased as enforceable constraints (`must`, `must not`).
- Rules should remain compact: extend canonical rules before creating new fragmented files.
- Test obligations must define an explicit exception protocol (approval + owner + due date), not implicit waivers.

## 5. Completion guard
- Work is not complete until relevant new learnings are either:
  - mapped to an existing rule, or
  - captured as a new rule.
- For test-quality learnings, this mapping must include both:
  - `.agent/rules` constraints,
  - and enforceable pipeline/config touchpoints in `ops/testing` or `scripts`.
