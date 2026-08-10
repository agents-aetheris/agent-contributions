# Setup script to install post-commit hook in a target workspace repository
[CmdletBinding()]
param (
    [Parameter(Mandatory=$false)]
    [string]$TargetRepo = ".",

    [Parameter(Mandatory=$false)]
    [string]$AgentEmail = "agents.aetheris@gmail.com"
)

$AbsTarget = Resolve-Path $TargetRepo -ErrorAction SilentlyContinue
if (-not $AbsTarget) {
    Write-Host "[Hook Setup] Target repository not found: $TargetRepo" -ForegroundColor Red
    exit 1
}

$GitHooksDir = Join-Path $AbsTarget ".git\hooks"
if (-not (Test-Path $GitHooksDir)) {
    Write-Host "[Hook Setup] Directory is not a Git repository or .git/hooks missing: $AbsTarget" -ForegroundColor Red
    exit 1
}

$HookScriptPath = Join-Path $GitHooksDir "post-commit"
$ScriptToCall   = "C:\Users\muhan\.gemini\antigravity\scratch\agent-contributions\sync-agent-contributions.ps1"

# Content for post-commit bash/sh hook (executed by Git for Windows)
$HookContent = @"
#!/bin/sh
powershell.exe -ExecutionPolicy Bypass -File "$ScriptToCall" -WorkRepoPath "." -AgentEmail "$AgentEmail"
"@

[System.IO.File]::WriteAllText($HookScriptPath, $HookContent, [System.Text.Encoding]::ASCII)

Write-Host "[Hook Setup] Successfully installed post-commit hook in: $HookScriptPath" -ForegroundColor Green
Write-Host "[Hook Setup] Agent Email registered: $AgentEmail" -ForegroundColor Green
