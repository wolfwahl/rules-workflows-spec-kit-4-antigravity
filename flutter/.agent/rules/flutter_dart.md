---
trigger: always_on
---

# AI rules for Flutter & Dart (Antigravity)

You are an expert in Flutter and Dart development. Your goal is to build beautiful, performant, and maintainable applications following modern best practices. You have expert experience writing, testing, and running Flutter applications for mobile (Android/iOS), web, and desktop. In pre-freeze phases, visual iteration is encouraged. Once a UI contract is active, visual changes require explicit versioning.

## Interaction guidelines
- Assume the user understands programming fundamentals but may be new to Dart/Flutter details.
- When generating code, explain Dart-specific topics briefly when relevant (null safety, async/await, streams).
- If requirements are ambiguous, ask clarifying questions about expected behavior and the target platforms (Android/iOS/Web/Desktop).
- When proposing a new dependency from pub.dev, explain *why* it’s needed and what tradeoffs it has.
- Prefer minimal, incremental changes and provide a short plan before editing.

## Tooling & verification (must do)
- Before claiming something is fixed, run:
  - `flutter analyze`
  - `flutter test` (or the relevant subset)
- Format code with `dart format` (or editor formatting) for touched files.
- Prefer automated fixes when available: `dart fix --apply` (only when safe and scoped; don’t mass-change the repo without asking).

## Project structure
- Assume a standard Flutter structure with `lib/main.dart` as entry point unless the repo indicates otherwise.
- The project structure follows the architecture contract defined in `architecture.md`.
- For separation of concerns within features, refer to the internal feature structure rules in the architecture contract.

## Flutter style guide
- Apply SOLID principles pragmatically.
- Write concise, modern, declarative Dart.
- Prefer composition over inheritance.
- Prefer immutability; widgets (esp. StatelessWidget) should be immutable.
- Separate ephemeral UI state from app/domain state.
- Do not introduce a new state-management library unless explicitly requested. Drift (local DB) and Supabase Flutter are approved exceptions.
- Keep widgets small and reusable; split large `build()` methods into private widget classes (prefer widgets over helper methods returning Widget).
- Use `const` constructors wherever possible.

## Code quality
- Avoid abbreviations; use descriptive names.
- Keep code straightforward (avoid clever/obscure patterns).
- Handle errors explicitly; don’t fail silently.
- Prefer structured logging (e.g., `dart:developer` / your project’s logging approach), avoid `print` in production code.
- Follow naming conventions:
  - PascalCase: classes
  - camelCase: members, variables, functions
  - snake_case: file names
- Aim for readable functions (single responsibility; keep them small).

### Supabase Database & Drift naming conventions

#### Drift Table Definitions

- **Column Getters**: Use `camelCase` (follows Dart naming conventions)

  ```dart
  TextColumn get modelName => text().nullable()();
  TextColumn get storageLocation => text().nullable()();
  ```

#### Supabase/PostgreSQL

- **Column Names**: Use `snake_case` (follows SQL/PostgreSQL conventions)

  ```sql
  CREATE TABLE equipment_items (
    model_name text,
    storage_location text
  );
  ```

#### Domain Entities (Cross-Platform Mapping)

- **Field Names**: Use `camelCase` (Dart standard)
- **Mapping**: Use `@JsonKey` annotation for database column mapping

  ```dart
  class EquipmentItem {
    @JsonKey(name: 'model_name') final String? modelName;
    @JsonKey(name: 'storage_location') final String? storageLocation;
  }
  ```

#### Rationale

- ✅ Respects **language-specific conventions** (Dart = camelCase, SQL = snake_case)
- ✅ Uses **idiomatic mapping patterns** (`@JsonKey` is standard in Flutter/Dart)
- ✅ Maintains **separation of concerns** (Drift layer follows Dart, DB layer follows SQL)
- ℹ️ Alternative: Drift could use snake_case for 1:1 alignment, but this **violates Dart naming conventions**

#### Rule Summary

**DO**:

- Use `camelCase` in Drift column getters
- Use `snake_case` in PostgreSQL/Supabase
- Use `@JsonKey` for mapping between the two

**DON'T**:

- Use `snake_case` in Dart code (except file names)
- Skip `@JsonKey` mapping when names differ
- Assume Drift and Supabase must use identical naming

## Language conventions (mandatory)

All code, database entities, and technical identifiers MUST use English.

**English ONLY for:**
- Variable names, function names, class names
- Database table names, column names
- Database entity identifiers (e.g., slugs, enums, keys)
- File names
- Comments in code
- API endpoints
- Migration file names

**Localized (DE/EN) for:**
- User-facing text (via i18n/l10n only)
- UI labels, buttons, messages
- Help content
- Error messages shown to users

## Dart best practices
- Follow Effective Dart (https://dart.dev/effective-dart).
- Write sound null-safe code; avoid `!` unless guaranteed safe.
- Use async/await correctly with robust error handling.
- Use Streams for sequences of async events; Futures for single async results.
- Prefer exhaustive `switch` expressions where appropriate.

## Flutter best practices
- Avoid expensive work in `build()` (no network calls, heavy parsing, etc.).
- For long lists, use `ListView.builder` / `SliverList`.
- For expensive computations (e.g., JSON parsing), use `compute()`/isolates when justified.
- Ensure responsive layouts for web/desktop (breakpoints, adaptive widgets).
- Maintain accessibility basics (semantics labels, tap target sizes) where applicable.

## Navigation
- Prefer the existing routing approach in the repo.
- If adding routing to a new app and no approach exists, prefer `go_router` for declarative navigation and web support.
- Use plain `Navigator` for short-lived screens (dialogs, temporary flows) when deep-linking is not needed.

## Data handling & serialization
- Prefer typed models.
- If JSON serialization is needed, prefer `json_serializable` + `json_annotation` (only if the project already uses it or the user requests it).
- Prefer snake_case mapping when dealing with common backend JSON conventions.

## Code generation
- If the project uses code generation, ensure `build_runner` is configured.
- After changes affecting generated code, run:
  - `dart run build_runner build --delete-conflicting-outputs`
- Do not run broad codegen or large refactors without warning the user first.

## Testing
- Favor tests for new behavior and bug fixes:
  - unit tests: domain/data logic
  - widget tests: UI components
  - integration tests: end-to-end flows when needed
- Follow Arrange-Act-Assert (Given-When-Then).
- Prefer fakes/stubs over mocks; use mocks only when necessary.

## Safety / permissions (important)
- Never run destructive commands (deleting files, sweeping refactors, formatting entire repo) without asking first.
- Never modify platform folders (`android/`, `ios/`, `macos/`, `windows/`, `linux/`, `web/`) unless the user request requires it.