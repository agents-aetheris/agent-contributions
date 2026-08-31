# PowerShell script to backfill historical agent commits into the mirror repository
[CmdletBinding()]
param (
    [Parameter(Mandatory=$false)]
    [string]$WorkRepoPath = ".",

    [Parameter(Mandatory=$false)]
    [string]$AgentEmail = "agents.aetheris@gmail.com",

    [Parameter(Mandatory=$false)]
    [string]$MirrorRepoPath = "C:\Users\muhan\.gemini\antigravity\scratch\agents-contributions"
)

# Resolve absolute path of work repo
$WorkRepoAbsPath = Resolve-Path $WorkRepoPath -ErrorAction SilentlyContinue
if (-not $WorkRepoAbsPath) {
    Write-Host "[Backfill] Work repository path not found: $WorkRepoPath" -ForegroundColor Red
    exit 1
}

# Check git repository validity
if (-not (Test-Path "$WorkRepoAbsPath\.git")) {
    Write-Host "[Backfill] Directory is not a Git repository: $WorkRepoAbsPath" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path "$MirrorRepoPath\.git")) {
    Write-Host "[Backfill] Mirror repository not found: $MirrorRepoPath" -ForegroundColor Red
    exit 1
}

Write-Host "[Backfill] Scanning historical commits in: $WorkRepoAbsPath" -ForegroundColor Cyan
Write-Host "[Backfill] Searching for agent email: $AgentEmail" -ForegroundColor Cyan

# Fetch all commits with format: hash|author_email|committer_email|iso_date|body
Push-Location $WorkRepoAbsPath
try {
    $commitLogs = git log --pretty=format:"%h|%ae|%ce|%ad|%s" --date=iso-strict
} catch {
    Write-Host "[Backfill] Failed to read git history." -ForegroundColor Red
    Pop-Location
    exit 1
} finally {
    Pop-Location
}

if (-not $commitLogs) {
    Write-Host "[Backfill] No git commits found in work repo." -ForegroundColor Yellow
    exit 0
}

# Also retrieve commit bodies for Co-authored-by check
Push-Location $WorkRepoAbsPath
try {
    $rawHistory = git log --pretty=format:"COMMIT_START%n%h|%ae|%ce|%ad%n%b%nCOMMIT_END" --date=iso-strict
} finally {
    Pop-Location
}

$commitBlocks = $rawHistory -split "COMMIT_START"
$syncedCount = 0

Push-Location $MirrorRepoPath
try {
    foreach ($block in $commitBlocks) {
        if ([string]::IsNullOrWhiteSpace($block)) { continue }

        $lines = $block.Trim() -split "`n"
        if ($lines.Count -lt 1) { continue }

        $header = $lines[0]
        $headerParts = $header -split "\|"
        if ($headerParts.Count -lt 4) { continue }

        $hash           = $headerParts[0].Trim()
        $authorEmail    = $headerParts[1].Trim()
        $committerEmail = $headerParts[2].Trim()
        $commitDate     = $headerParts[3].Trim()
        $body           = ($lines[1..($lines.Count - 1)]) -join "`n"

        $role = $null
        if ($authorEmail -ieq $AgentEmail) {
            $role = "Authored"
        } elseif ($committerEmail -ieq $AgentEmail) {
            $role = "Committed"
        } elseif ($body -match [regex]::Escape($AgentEmail)) {
            $role = "Co-Authored"
        }

        if ($role) {
            Write-Host "[Backfill] Found $role commit [$hash] from $commitDate" -ForegroundColor Green

            $env:GIT_AUTHOR_NAME     = "Agent Bot"
            $env:GIT_AUTHOR_EMAIL    = $AgentEmail
            $env:GIT_AUTHOR_DATE     = $commitDate
            $env:GIT_COMMITTER_NAME  = "Agent Bot"
            $env:GIT_COMMITTER_EMAIL = $AgentEmail
            $env:GIT_COMMITTER_DATE  = $commitDate

            $commitMsg = "activity($role): backfill historical contribution [$hash]"
            git commit --allow-empty -m "$commitMsg" --date="$commitDate" > $null 2>&1
            if ($LASTEXITCODE -eq 0) {
                $syncedCount++
            }
        }
    }

    if ($syncedCount -gt 0) {
        Write-Host "[Backfill] Pushing $syncedCount historical commits to GitHub..." -ForegroundColor Cyan
        git push origin main
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[Backfill] Successfully backfilled $syncedCount commits to agent contribution graph!" -ForegroundColor Green
        } else {
            Write-Host "[Backfill] Push failed during backfill." -ForegroundColor Red
        }
    } else {
        Write-Host "[Backfill] No historical agent commits found matching: $AgentEmail" -ForegroundColor Yellow
    }

} finally {
    Pop-Location
    Remove-Item Env:\GIT_AUTHOR_NAME -ErrorAction SilentlyContinue
    Remove-Item Env:\GIT_AUTHOR_EMAIL -ErrorAction SilentlyContinue
    Remove-Item Env:\GIT_AUTHOR_DATE -ErrorAction SilentlyContinue
    Remove-Item Env:\GIT_COMMITTER_NAME -ErrorAction SilentlyContinue
    Remove-Item Env:\GIT_COMMITTER_EMAIL -ErrorAction SilentlyContinue
    Remove-Item Env:\GIT_COMMITTER_DATE -ErrorAction SilentlyContinue
}
