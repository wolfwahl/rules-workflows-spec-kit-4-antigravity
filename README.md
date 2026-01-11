# Antigravity Rules & Workflows for Flutter + Supabase

An experimental, evolving collection of AI rules and workflows for building production-ready Flutter applications with Supabase using Google's Antigravity AI agent.

## What is this?

This repository is a **continuous experiment** in AI-assisted Flutter development. It's not a finished product—it's a living laboratory where rules, workflows, and patterns are constantly refined based on real-world development experience.

The goal: Help Antigravity understand how to build robust, maintainable Flutter apps backed by Supabase, while respecting architectural boundaries, data integrity, and long-term evolvability.

## What's inside?

### 📋 AI Rules (`.agent/rules/`)

A curated set of rules that guide Antigravity's behavior when working with Flutter and Supabase:

- **`architecture.md`** – Feature-first modularization, deletability, and architectural contracts
- **`flutter_dart.md`** – Flutter & Dart best practices (based on [Flutter's official AI rules template](https://gist.github.com/reiott/f01ab63317f8d3b3b40ba5c920029911))
- **`flutter_ui.md`** – UI engineering discipline and theme-driven design
- **`supabase_only.md`** – Supabase-exclusive architecture constraints
- **`supabase_performance.md`** – PostgreSQL indexing and RLS optimization
- **`permanent_data_integrity.md`** – Expand-Migrate-Contract pattern for safe schema evolution
- **`artifact_persistence.md`** – Documentation structure and ADR templates
- **`git_workflow.md`** – Version control discipline

### 🔧 Workflows (`.agent/workflows/`)

Specification workflows from the [spec-kit Gemini PS1 package](https://github.com/github/spec-kit), adapted for Antigravity:

- `/speckit.specify` – Create feature specifications
- `/speckit.plan` – Generate implementation plans
- `/speckit.tasks` – Break down work into actionable tasks
- `/speckit.implement` – Execute implementation plans
- `/speckit.clarify` – Identify underspecified areas
- `/speckit.analyze` – Cross-artifact consistency checks

### 📝 Specification Templates (`.specify/`)

Feature documentation templates from the [spec-kit Gemini PS1 package](https://github.com/github/spec-kit), adapted for Antigravity.

## Philosophy

This isn't about creating the "perfect" AI rules. It's about:

- **Learning by doing** – Rules evolve as we encounter real problems
- **Balancing control and flexibility** – Strict where it matters (data integrity, architecture), flexible where it helps (UI iteration)
- **Making implicit knowledge explicit** – Codifying patterns that work
- **Staying pragmatic** – Rules serve the project, not the other way around

## Status: Experimental & Evolving

⚠️ **This is far from anything I would consider good – this is an ongoing experiment.**

Rules change, workflows get refactored, and patterns are continuously refined. If you use this, expect breaking changes and ongoing evolution. This is not a stable framework, and it's not meant to be.

This is my attempt to figure out Antigravity. Let's see what the future brings. I'm wrong every day.

## Acknowledgments

This work builds on:

- **[spec-kit Gemini PS1 package](https://github.com/github/spec-kit)** – Source of the specification workflows and templates (`.agent/workflows/` and `.specify/`)
- **[Flutter's official AI rules template](https://gist.github.com/reiott/f01ab63317f8d3b3b40ba5c920029911)** – Foundation for Flutter/Dart best practices in `flutter_dart.md`
- **Google Deepmind's Antigravity** – The AI agent that makes this all possible

The AI rules in `.agent/rules/` (architecture, Supabase patterns, data integrity, etc.) are original work developed through real-world Flutter + Supabase development.

## Using these rules

### With Antigravity

These rules are designed for Google's Antigravity AI agent. Place them in your project's `.agent/rules/` directory, and Antigravity will automatically apply them.

### With other AI assistants

The rules are written in Markdown and can be adapted for other AI-powered IDEs (Cursor, Windsurf, etc.) with minimal modifications.

## Contributing

This is a personal experiment, but if you find value in these rules or have suggestions, feel free to open an issue or discussion. Just remember: this is a work-in-progress by design.

## License

MIT License – Use freely, adapt as needed, no warranties provided.

---

**Built with curiosity, refined through iteration.**
