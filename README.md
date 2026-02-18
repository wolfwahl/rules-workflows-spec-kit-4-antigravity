# Multi-Agent Rules & Workflows for Flutter + Supabase

> [!CAUTION]
> **LAB-EXPERIMENT / NOT PRODUCTION-READY**
> This repository is a personal experimental setup. It serves exclusively for researching how high-quality code *could* be generated using current AI agents. Nothing herein should be misunderstood as "best practice" for live production systems.

## 🧪 The Experiment: A "Shoulder-View"

This is not a finished framework or product. It is a **pure greenfield experiment** to find out how far one can actually go today with AI agents (Antigravity, Codex, etc.) when given strict rules for architecture and data integrity.

**IMPORTANT:**

- **For new project setups only (Greenfield):** Never use this setup to "inoculate" or modify an already running project.
- **Use at your own risk:** Everything here is in flux and can (and will) break.

## What is this?

This repository documents my **continuous learning journey** in AI-assisted Flutter development. It is a "Living Laboratory" where rules and workflows are constantly refined based on experimental experiences.

The goal: Understand how agents can build robust, maintainable apps while respecting architectural boundaries and data integrity.

## What's inside?

All project assets in this repository are currently organized under `flutter/`.

### 📋 AI Rules (`flutter/.agent/rules/`)

A curated set of rules that guide Antigravity and other AI agents when working with Flutter and Supabase:

- **`architecture.md`** – Feature-first modularization, deletability, and architectural contracts
- **`flutter_dart.md`** – Flutter & Dart best practices (based on [Flutter's official AI rules template](https://gist.github.com/reiott/f01ab63317f8d3b3b40ba5c920029911))
- **`flutter_ui.md`** – UI engineering discipline and theme-driven design
- **`ui_freeze.md`** – UI stability controls for implementation phases
- **`supabase_only.md`** – Supabase-exclusive architecture constraints
- **`supabase_performance.md`** – PostgreSQL indexing and RLS optimization
- **`permanent_data_integrity.md`** – Expand-Migrate-Contract pattern for safe schema evolution
- **`artifact_persistence.md`** – Documentation structure and ADR templates
- **`git_workflow.md`** – Version control discipline
- **`definition_of_done.md`** – Delivery acceptance and completion rules
- **`agent_gap_prevention.md`** – Anti-gap protocol to prevent skipped scope/quality
- **`knowledge_continuity.md`** – Continuity rules for stable project context handover

### 🔧 Workflows (`flutter/.agent/workflows/`)

Specification workflows from the [spec-kit Gemini PS1 package](https://github.com/github/spec-kit), adapted for this repository:

- `/speckit.specify` – Create feature specifications
- `/speckit.plan` – Generate implementation plans
- `/speckit.tasks` – Break down work into actionable tasks
- `/speckit.implement` – Execute implementation plans
- `/speckit.clarify` – Identify underspecified areas
- `/speckit.analyze` – Cross-artifact consistency checks
- `/speckit.checklist` – Generate/validate implementation checklists
- `/speckit.constitution` – Manage project constitution constraints
- `/speckit.taskstoissues` – Convert task outputs into issue-ready artifacts

### 📝 Specification Assets (`flutter/.specify/`)

Feature documentation templates from the [spec-kit Gemini PS1 package](https://github.com/github/spec-kit), adapted for this repository:

- `flutter/.specify/templates/` – Spec, plan, tasks, checklist, and agent templates
- `flutter/.specify/memory/constitution.md` – Constitution memory source
- `flutter/.specify/scripts/bash/` – Bash workflow helpers
- `flutter/.specify/scripts/powershell/` – PowerShell workflow helpers

Note: spec-kit is now available for Antigravity. I originally used the spec-kit Gemini PS1 package as a reference to create an Antigravity-compatible variant before official support was available.

### 🧪 Quality & Automation Assets (`flutter/`)

- `flutter/agent_quality_guardrails_runbook.md` – Operational guardrail runbook for agents
- `flutter/scripts/` – Verification, CI, coverage, mutation, reliability, and helper scripts
- `flutter/ops/testing/` – Coverage baselines, thresholds, mutation/test scope policies
- `flutter/.githooks/` – Local pre-commit and pre-push enforcement
- `flutter/.github/workflows/flutter-ci.yml` – Remote CI quality gates
- `flutter/tool/mutation/ast_mutation_gate.dart` – Mutation analysis tooling
- `flutter/docs/` – Architecture boundaries and contributor hardening guidance

## Philosophy

This isn't about creating the "perfect" AI rules. It's about:

- **Learning through failure** – Rules evolve through real stumbling blocks.
- **Leading agents, not just using them** – Taming the agent through strict architectural guardrails.
- **Exploration over stability** – In the lab, everything is allowed to burn as long as the realization is correct.

## Status: Experimental & Evolving

⚠️ **This is far from anything I would consider good – this is an ongoing experiment.**

Rules change, workflows get refactored agents come and go, and patterns are continuously refined. If you use this, expect breaking changes and ongoing evolution. This is not a stable framework, and it's not meant to be.

This is my attempt to understand what actually works in real AI-assisted development. Let's see what the future brings. I'm wrong every day.

## Acknowledgments

This work builds on:

- **[spec-kit Gemini PS1 package](https://github.com/github/spec-kit)** – Source of the specification workflows and templates (`flutter/.agent/workflows/` and `flutter/.specify/`)
- **[Flutter's official AI rules template](https://gist.github.com/reiott/f01ab63317f8d3b3b40ba5c920029911)** – Foundation for Flutter/Dart best practices in `flutter_dart.md`
- **Google DeepMind's Antigravity** – The original inspiration for this repository

The AI rules in `flutter/.agent/rules/` (architecture, Supabase patterns, data integrity, etc.) and all scripts are original work developed through real-world Flutter + Supabase development.

## Using these rules

### With Antigravity

These rules are designed for Google's Antigravity AI agent. In this repository they live in `flutter/.agent/rules/`. For your own project, place them in your project's `.agent/rules/` directory, and Antigravity will automatically apply them.

### With other AI assistants

The rules are written in Markdown and can be adapted for other AI-powered IDEs (Cursor, Windsurf, etc.) with minimal modifications.

### With Codex (WSL on Windows)

- `flutter/AGENTS.md` defines the agent behavior contract in this blueprint (copy it as `AGENTS.md` to your target repository root).
- Codex can follow this stack reliably when `AGENTS.md` and `.agent/` rules are present.
- On Windows, Codex is currently reliable only when run through WSL.
- Most automation scripts were originally written for Codex first, then adapted to be usable with Antigravity as well.
- Practical context: I had to use Codex as an extension/fallback to Antigravity because of Antigravity instability and quota friction, while still being constrained to develop on Windows. I use both side by side and plan to transition to Linux (or full WSL on Windows) over time.

#### 🛠️ MCP Server Configuration (Codex/RMCP)

If Codex is used with the RMCP client, the file `flutter/.codex/config.toml` must be adapted to the local environment:

1. **Supabase MCP**: Replace `<supbase_project_id>` in the `url` with your actual Supabase Project Ref.
2. **Dart MCP**: Replace `<project_ref>` in the `args` with the **absolute path** to your project root (Windows notation, e.g., `D:/path/to/project`).

```toml
[mcp_servers.supabase]
url = "https://mcp.supabase.com/mcp?project_ref=YOUR_REF&features=..."

[mcp_servers.dart]
args = ["/d", "/c", "cd /d D:/YOUR/PATH && dart mcp-server ..."]
```

## Quickstart (10 Minutes)

Use this to activate the blueprint in a **new target** Flutter repository after copying the assets listed in "Lab-Setup" (run from the target repository root):

```bash
bash ./scripts/install_git_hooks.sh
bash ./scripts/verify_flutter_env.sh
bash ./scripts/verify_dod.sh
bash ./scripts/run_local_ci.sh --skip-mutation
```

Optional (only when dependencies are missing/outdated in the target repo):

```bash
./scripts/flutterw.sh pub get
```

Expected outcome:

- Local hooks are installed.
- Baseline quality gates run successfully.
- Mutation testing gates are configured and can be run explicitly when needed (they are intentionally skipped in fast bring-up).

## Prerequisites & Platform Matrix

| Tool | Required | Notes |
|---|---|---|
| Git | Yes | Needed for hook setup and diff-based gates. |
| Bash | Yes | All core scripts are Bash-based. |
| Flutter SDK (stable channel) | Yes | `./scripts/flutterw.sh --version` must work. |
| Dart CLI | Optional | `run_mutation_gate.sh` uses `dart run` when available, otherwise falls back to `flutter pub run`. |
| Supabase CLI | Optional | Not required for baseline gates in this blueprint. |

| Environment | Status | Notes |
|---|---|---|
| Linux/macOS shell | Supported | Native path for scripts. |
| WSL | Supported | `scripts/flutterw.sh` includes Windows Flutter fallback behavior under WSL. |
| Windows PowerShell-only setup | Partial | Prefer WSL/Git Bash for full script compatibility. |

Version policy note:

- This repository does not hard-pin minimum Flutter/Dart versions in scripts.
- For production adoption, pin exact toolchain versions in your target project and enforce them in CI.

## Windows Script Validation Guide

If you want a reproducible validation workflow for Windows agents, use:

- `flutter/docs/windows-script-validation.md`

Windows execution note:

- Core automation scripts are Bash-first and run in Linux/WSL shells (including Codex in WSL).
- Windows-native wrapper entry points are available:
  - `flutter/scripts/install_git_hooks.ps1`
  - `flutter/scripts/verify_dod.ps1`
  - `flutter/scripts/run_local_ci.ps1`
  - `flutter/scripts/run_mutation_gate.ps1`
- These wrappers call the same underlying Bash scripts to keep quality gate semantics aligned.
- Untested note: wrappers are currently untested across all native Windows agent runtimes.

## Quality Guardrails Runbook

For operational quality enforcement, use:

- `flutter/agent_quality_guardrails_runbook.md`

This runbook defines the guardrail system (hooks, CI gates, verification scripts, and evidence artifacts) that an agent must follow before declaring work complete.
Recommended usage model: run the setup sequence once during initial project onboarding, then rely on automated hook/CI enforcement for day-to-day work.

### Lab-Setup (Starting a new Greenfield trial)

If you want to start a **new** greenfield trial with these guardrails:

1. Place copied assets at the target repository root (for example: `.githooks/`, `scripts/`, `.github/workflows/`, `ops/testing/`).
2. Copy the core guardrail assets from `flutter/`:
   - `AGENTS.md`
   - `.agent/`
   - `.specify/`
   - `.githooks/`
   - `.github/workflows/`
   - `scripts/`
   - `ops/testing/`
   - `ops/reliability/README.md`
   - `tool/mutation/`
   - `agent_quality_guardrails_runbook.md`
3. Optional Codex-specific project config:
   - `.codex/config.toml`
4. Apply mandatory project-specific adjustments:
   - **Architecture**: In `scripts/architecture_boundary_audit.sh`, adapt the package naming (`package:your_project/...` in lines 32, 52, 57) to your `pubspec.yaml`.
   - **Mutation Testing**: In `ops/testing/mutation_targets.txt`, enter the paths to your most relevant logic files.
   - **Quality Gates**: In `ops/testing/quality_gates.env`, set realistic thresholds for the start (e.g., `MIN_BRANCH_COVERAGE_PCT`).
   - **Coverage Baseline**: In `ops/testing/coverage_baseline.env`, define the current state as the baseline.
   - **Codex MCP**: (If used) adapt `flutter/.codex/config.toml` as described above.
5. Run bring-up in order:
   - `./scripts/flutterw.sh pub get`
   - `bash ./scripts/install_git_hooks.sh`
   - `bash ./scripts/verify_flutter_env.sh`
   - `bash ./scripts/verify_dod.sh`
   - `bash ./scripts/run_local_ci.sh --skip-mutation`
6. Treat this as one-time project/clone activation:
   - Run once at onboarding to activate local guardrails.
   - After activation, required checks run automatically on commit/push via hooks and CI.

### Required vs Optional Components

| Component | Baseline | Why |
|---|---|---|
| `AGENTS.md` | Required | Agent behavior contract entry point (especially for Codex). |
| `.agent/rules/` and `.agent/workflows/` | Required | Agent behavior and workflow contract. |
| `.specify/` | Required | Specification templates and workflow scripts expected by the process. |
| `.githooks/` + `scripts/install_git_hooks.sh` | Required | Local enforcement for commit/push quality gates. |
| `ops/testing/*` (coverage/mutation policy files) | Required | Source of threshold and scope definitions. |
| `.github/workflows/flutter-ci.yml` | Required | Remote quality authority and artifact generation. |
| `tool/mutation/ast_mutation_gate.dart` | Required | Mutation gate engine used by scripts/CI. |
| `.codex/config.toml` | Optional | Codex-specific local behavior/configuration file. |
| `scripts/run_mutation_gate.sh --operator-profile strict` | Optional | Deeper but more expensive analysis path. |
| `supabase/dump/schema.sql` + `supabase/migrations/*.sql` | Optional | Required only when Supabase migration guardrails are in scope. |

### Coverage Minimums: Set Realistic Baselines, Then Raise

- Do not start with aspirational coverage numbers that your codebase cannot meet yet.
- Set minimum coverage values from measured reality (`ops/testing/coverage_baseline.env` and `ops/testing/quality_gates.env`).
- Treat thresholds as a ratchet: increase them gradually over time as test quality improves.
- Re-baseline only with explicit justification; never lower standards silently.

### Coverage Scope Rules (Includes/Excludes)

- Start with broad production coverage include scope (default: `^lib/.*\\.dart$` in `ops/testing/coverage_include_patterns.txt`).
- Keep excludes technical-only in `ops/testing/coverage_exclude_patterns.txt` (generated files, l10n outputs).
- Never exclude business features or modules to make gates pass.
- Any new exclude pattern must be explicit, minimal, and justified in review.
- Validate scope changes with `bash ./scripts/verify_coverage_baseline.sh` and `bash ./scripts/run_local_ci.sh --skip-mutation`.

### Policy File Examples

Coverage include allow-list (`ops/testing/coverage_include_patterns.txt`):

```txt
^lib/.*\.dart$
```

Coverage exclude deny-list (`ops/testing/coverage_exclude_patterns.txt`):

```txt
\.g\.dart$
\.freezed\.dart$
\.mocks\.dart$
^lib/l10n/.*\.dart$
```

Mutation targets (`ops/testing/mutation_targets.txt`):

```txt
# source_file|test_command
lib/features/auth/domain/session_policy.dart|./scripts/flutterw.sh test test/features/auth/domain/session_policy_test.dart
```

Mutation excludes (`ops/testing/mutation_exclude_mutants.txt`):

```txt
# source_file|line|reason
lib/features/auth/domain/session_policy.dart|87|platform-specific nondeterministic branch
```

### Custom AST Mutation Tester

- Engine: `flutter/tool/mutation/ast_mutation_gate.dart`
- Wrapper: `flutter/scripts/run_mutation_gate.sh`
- Targets mapping: `flutter/ops/testing/mutation_targets.txt` with `source_file|test_command`
- Optional excludes: `flutter/ops/testing/mutation_exclude_mutants.txt` with `source_file|line|reason`
- Quality gates source: `flutter/ops/testing/quality_gates.env`

What it does:

- Parses Dart source with AST analysis and mutates selected logical constructs.
- `stable` profile focuses on safer operators (`==`/`!=`) plus boolean literal flips.
- `strict` profile extends mutation operators (for example logical/comparison operator mutations) for deeper, more expensive analysis.

How it is used in this blueprint:

- CI runs blocking mutation checks with the default profile.
- CI also runs a strict profile in non-blocking mode for deeper signal without making every strict failure release-blocking.
- Local fast path remains `--skip-mutation`; run mutation explicitly for risky changes or before release candidates.

Useful commands:

- `bash ./scripts/run_mutation_gate.sh`
- `bash ./scripts/run_mutation_gate.sh --operator-profile strict --no-threshold-fail`

### Mutation Gate Decision Guide

| Change type | Recommended action |
|---|---|
| UI-only text/layout/theme changes | `bash ./scripts/run_local_ci.sh --skip-mutation` is usually sufficient. |
| Feature/domain logic changes | Run `bash ./scripts/run_mutation_gate.sh` before merge. |
| Security/auth/payment/session logic | Run blocking mutation gate and review survivors explicitly. |
| Release candidate / high-risk refactor | Run stable gate plus strict non-blocking profile. |

## Operational Disclaimers

- This repository is a blueprint and an evolving experiment, not a guaranteed production framework.
- GitHub Actions can generate costs (runner minutes, storage, artifact retention), especially with quality reports and mutation artifacts.
- Mutation testing is intentionally expensive (many test re-runs by design); it may not be practical on every local run or every branch in all teams.
- The default fast local path uses `bash ./scripts/run_local_ci.sh --skip-mutation`; mutation gates can be executed separately when risk or release scope justifies it.
- Mutation runtime is bounded by configurable limits (for example `MAX_MUTATION_RUNTIME_SECONDS` in `ops/testing/quality_gates.env`) to manage CI time/performance budgets.
- Coverage and mutation thresholds must be calibrated per project baseline; copying thresholds blindly can create unstable or misleading gates.
- CI behavior can vary by runner performance, cache state, and network conditions; occasional timing variance does not automatically indicate a quality regression.
- These assets do not replace security/compliance work: manual threat modeling, secret management, Supabase RLS review, and legal/regulatory checks are still required.

### GitHub Actions Cost Control Tips

- Keep strict mutation in non-blocking mode unless your budget supports always-on strict runs.
- Tune mutation budgets in `ops/testing/quality_gates.env` (`MAX_MUTATION_RUNTIME_SECONDS`, thresholds) to match team capacity.
- Use branch strategy intentionally: run full heavy gates on `main`/release branches, keep local feedback loops fast.
- Set artifact `retention-days` in workflow upload steps if long retention is not needed.
- Consider enabling workflow concurrency cancellation in your target project to reduce duplicate in-flight CI runs.

## Contributing

This is a personal experiment, but if you find value in these rules or have suggestions, feel free to open an issue or discussion. Just remember: this is a work-in-progress by design.

## License

MIT License – Use freely, adapt as needed, no warranties provided.

---

**Built with curiosity, refined through iteration.**
