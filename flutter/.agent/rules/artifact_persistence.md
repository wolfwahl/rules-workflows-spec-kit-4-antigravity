---
trigger: always_on
---

---
description: Mandatory rules for persisting artifacts and documentation (.specification directory)
globs: "**/*"
---
# Artifact Persistence Rules
This rule defines the structure for the .specification directory. The goal is a clean, chronological, and navigable documentation of all features and technical plans.
## Base Directory
The root directory is .specification.
## 1. Master Index (IMPORTANT)
File: .specification/README.md
This file serves as the table of contents for the entire project.
**Rule:** Every time a new "Implementation Plan" (see Point 3) is created, it MUST be added as a new entry in this file.
**List Format:**
The format is a Markdown table:
`markdown
| Date | Feature / Plan | Status | Link |
| :--- | :--- | :--- | :--- |
| 2025-12-27 | User Authentication | In Progress | [Go to Plan](./2025-12-27-14-30_User-Auth/README.md) |
`
## 2. Global Documentation
Project-wide documents (Architecture, API Standards, DB Schema) that do not become obsolete belong in:
- .specification/_General/
## 3. Implementation Plans (Feature Work)
A new directory is created for each work assignment.
**Naming Convention:** MUST begin with ISO Date and Time.
Format: .specification/YYYY-MM-DD-HH-mm_[Feature-Name]/
*(Example: .specification/2025-12-27-14-30_Login-System/)*
### File Structure within the Plan Directory
To ensure readability, we use numbered prefixes:
1.  **README.md**:
    - Contains title, brief summary, and current status.
    - Serves as the entry point for links.
2.  **01_Implementation_Plan.md**:
    - The detailed technical plan / specification.
3.  **02_Walkthrough.md**:
    - Step-by-step guide for implementation.
4.  **03_Task_List.md**:
    - Checklist of tasks.
5.  **04_Architecture_Decisions.md** (see ADR Template):
    - Architecture Decision Records documenting key design decisions, reasoning, and trade-offs.
    - Use ADR format (see ADR Template below).
    - Record decisions that have significant architectural impact or involve trade-offs.
    - Each decision gets numbered sequentially (ADR-001, ADR-002, etc.)
6.  **Uploaded images**:
    - Each uploaded image related to this implementation plan should be stored as well.

### ADR Template
Each decision should follow this structure:

```markdown
# ADR-[Number]: [Short Title]

**Status:** [Proposed | Accepted | Deprecated | Superseded by ADR-X]
**Date:** YYYY-MM-DD
**Deciders:** [AI Agent / User / Both]

## Context
What is the issue we're facing? What factors are driving this decision?

## Decision
What is the change we're proposing/accepting?

## Consequences
### Positive
- What becomes easier or better?

### Negative
- What becomes harder or worse?
- What are we giving up?

### Neutral
- What changes that is neither good nor bad?

## Alternatives Considered
### Option A: [Name]
- Description
- Pros/Cons
- Why rejected

### Option B: [Name]
- Description
- Pros/Cons
- Why rejected