# PowerShell script to scan drive for Git repos, backfill historical commits, and setup auto-sync hooks
[CmdletBinding()]
param (
    [Parameter(Mandatory=$false)]
    [string]$SearchRoot = "C:\Users\muhan",

    [Parameter(Mandatory=$false)]
    [string]$AgentEmail = "agents.aetheris@gmail.com",

    [Parameter(Mandatory=$false)]
    [string]$MirrorRepoPath = "C:\Users\muhan\.gemini\antigravity\scratch\agents-contributions"
)

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "[Scanner] Starting Git Repository Scanner across drive..." -ForegroundColor Cyan
Write-Host "[Scanner] Target Root: $SearchRoot" -ForegroundColor Cyan
Write-Host "[Scanner] Agent Email: $AgentEmail" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# Directories to ignore for fast scanning
$ExcludePatterns = @(
    "\AppData\",
    "\node_modules\",
    "\vendor\",
    "\.gemini\",
    "\.vscode\",
    "\.idea\",
    "\Temp\",
    "\Application Data\"
)

# Function to check if path should be skipped
function Test-ShouldSkipPath([string]$path) {
    foreach ($pattern in $ExcludePatterns) {
        if ($path -like "*$pattern*") {
            return $true
        }
    }
    return $false
}

# Collect all .git directories
$foundRepos = [System.Collections.Generic.List[string]]::new()

try {
    $dirs = Get-ChildItem -Path $SearchRoot -Directory -Recurse -ErrorAction SilentlyContinue
    foreach ($dir in $dirs) {
        $fullPath = $dir.FullName
        if (Test-ShouldSkipPath $fullPath) { continue }

        # Don't scan the mirror repo itself
        if ($fullPath -ieq $MirrorRepoPath) { continue }

        $gitFolder = Join-Path $fullPath ".git"
        if (Test-Path $gitFolder) {
            $foundRepos.Add($fullPath)
        }
    }
} catch {
    Write-Host "[Scanner] Warning during directory scan: $_" -ForegroundColor Yellow
}

Write-Host "[Scanner] Scan complete. Found $($foundRepos.Count) Git repositories." -ForegroundColor Green

if ($foundRepos.Count -eq 0) {
    Write-Host "[Scanner] No Git repositories found in $SearchRoot." -ForegroundColor Yellow
    exit 0
}

$ScriptBackfill = Join-Path $MirrorRepoPath "backfill-agents-contributions.ps1"
$ScriptSetup    = Join-Path $MirrorRepoPath "setup-hook.ps1"

$processedCount = 0
foreach ($repoPath in $foundRepos) {
    $processedCount++
    Write-Host "`n----------------------------------------------------------" -ForegroundColor Gray
    Write-Host "[$processedCount/$($foundRepos.Count)] Inspecting: $repoPath" -ForegroundColor Yellow
    Write-Host "----------------------------------------------------------" -ForegroundColor Gray

    # 1. Run backfill for historical commits
    & powershell.exe -ExecutionPolicy Bypass -File $ScriptBackfill -WorkRepoPath "$repoPath" -AgentEmail "$AgentEmail" -MirrorRepoPath "$MirrorRepoPath"

    # 2. Install auto-sync hook for future commits
    & powershell.exe -ExecutionPolicy Bypass -File $ScriptSetup -TargetRepo "$repoPath" -AgentEmail "$AgentEmail"
}

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "[Scanner] Finished processing all $($foundRepos.Count) repositories!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan
