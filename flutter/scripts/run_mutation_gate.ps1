param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ScriptArgs
)

. (Join-Path $PSScriptRoot "_bash_wrapper_common.ps1")
Invoke-BashFromRepo -ScriptPath "./scripts/run_mutation_gate.sh" -ScriptArgs $ScriptArgs

