# Windows Script Validation Playbook

Use this playbook to validate script compatibility for a Windows-based agent and produce a consistent report.

## Scope

This validation covers:
- Windows-native availability (PowerShell, `flutter`, `git`)
- WSL/Linux execution path (Bash scripts and quality gate entry points)
- Line ending risks (CRLF vs LF) for script files
- A final compatibility verdict and prioritized findings

## Recommended Execution Model

1. Run Windows-native checks in PowerShell.
2. Run Linux/WSL checks in a WSL shell.
3. Save all outputs and summarize in the report template below.

## 1) Environment Inventory

Run in PowerShell:

```powershell
$PSVersionTable.PSVersion
[System.Environment]::OSVersion.VersionString
git --version
where flutter
where pwsh
wsl -l -v
```

Capture:
- Windows version
- PowerShell version
- Git version
- Whether Flutter is in Windows PATH
- Whether WSL is installed and usable

## 2) Script Line Ending Check (CRLF/LF)

Run in PowerShell from `...\flutter`:

```powershell
$targets = @(
  "scripts",
  ".githooks",
  ".specify/scripts/bash",
  ".specify/scripts/powershell"
)

$files = foreach ($t in $targets) {
  if (Test-Path $t) { Get-ChildItem -Path $t -Recurse -File }
}

$crlf = @()
foreach ($f in $files) {
  $raw = Get-Content -Raw -LiteralPath $f.FullName
  if ($raw -match "`r`n") { $crlf += $f.FullName }
}

"CRLF files: $($crlf.Count)"
$crlf
```

Interpretation:
- Any Bash script with CRLF can fail under Linux/WSL shells.
- Document each affected file as a finding.

## 3) PowerShell Parse Check

Run in PowerShell from `...\flutter`:

```powershell
$files = @()
$files += Get-ChildItem .specify/scripts/powershell -File -Filter *.ps1
if (Test-Path .emulator/logcat.ps1) { $files += Get-Item .emulator/logcat.ps1 }

$parseErrors = @()
foreach ($f in $files) {
  $tokens = $null
  $errors = $null
  [System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$tokens, [ref]$errors) | Out-Null
  if ($errors.Count -gt 0) {
    $parseErrors += [PSCustomObject]@{
      File = $f.FullName
      Errors = ($errors | ForEach-Object { $_.Message }) -join " | "
    }
  }
}

"PS parse errors: $($parseErrors.Count)"
$parseErrors
```

## 4) WSL Bash Syntax Check

Run in WSL from `.../flutter`:

```bash
find scripts .githooks .specify/scripts/bash -type f \( -name "*.sh" -o -path ".githooks/*" \) -print0 \
  | while IFS= read -r -d '' f; do
      bash -n "$f" || echo "FAIL $f"
    done
```

Interpretation:
- No output means all checked scripts parsed successfully.
- Any `FAIL` line is a blocking compatibility issue for Linux/WSL execution.

## 5) WSL Smoke Checks (Core Entry Points)

Run in WSL from `.../flutter`:

```bash
./scripts/flutterw.sh --version
bash ./scripts/verify_flutter_env.sh
bash ./scripts/check_schema_drift.sh --help
bash ./scripts/verify_migrations.sh --help
bash ./scripts/run_mutation_gate.sh --help
```

Optional deeper run:

```bash
bash ./scripts/run_local_ci.sh --skip-mutation
```

## 6) Windows-Native Smoke Checks

Run in PowerShell:

```powershell
flutter --version
git --version
```

If `flutter` is not available in native Windows PATH, mark as partial support and rely on WSL path.

## 7) Severity Model

- `Critical`: Script cannot run due to syntax/line-ending/parser failures in required path.
- `Major`: Windows-native or WSL path works only partially with known blockers.
- `Minor`: Non-blocking docs/usability issue.

## 8) Report Template

Save as `windows-script-compat-report.md`:

```md
# Windows Script Compatibility Report

## 1. Scope
- Repo:
- Date:
- Tester:

## 2. Environment
- Windows:
- PowerShell:
- WSL:
- Flutter (Windows PATH):
- Flutter (WSL PATH):
- Git:

## 3. Results Matrix
| Check | Command/Method | Result | Evidence |
|---|---|---|---|

## 4. Findings
| Severity | File/Area | Problem | Impact | Recommended Fix |
|---|---|---|---|---|

## 5. Platform Verdict
- Windows native: PASS/FAIL
- WSL/Linux path: PASS/FAIL

## 6. Priority Fix Plan
1.
2.
3.
```

