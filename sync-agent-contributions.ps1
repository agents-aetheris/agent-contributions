# PowerShell script for syncing agent activity to mirror repository
[CmdletBinding()]
param (
    [Parameter(Mandatory=$false)]
    [string]$WorkRepoPath = ".",

    [Parameter(Mandatory=$false)]
    [string]$AgentEmail = "",

    [Parameter(Mandatory=$false)]
    [string]$MirrorRepoPath = "C:\Users\muhan\.gemini\antigravity\scratch\agent-contributions"
)

# Set default Agent Email if not provided
if ([string]::IsNullOrWhiteSpace($AgentEmail)) {
    $AgentEmail = "agents.aetheris@gmail.com"
}

# Resolve absolute path of work repo
$WorkRepoAbsPath = Resolve-Path $WorkRepoPath -ErrorAction SilentlyContinue
if (-not $WorkRepoAbsPath) {
    Write-Host "[Agent Sync] Work repository path not found: $WorkRepoPath" -ForegroundColor Red
    exit 1
}

# Check if work repo is a git repository
if (-not (Test-Path "$WorkRepoAbsPath\.git")) {
    Write-Host "[Agent Sync] Directory is not a Git repository: $WorkRepoAbsPath" -ForegroundColor Yellow
    exit 0
}

# Check if mirror repository exists
if (-not (Test-Path "$MirrorRepoPath\.git")) {
    Write-Host "[Agent Sync] Mirror repository not initialized at: $MirrorRepoPath" -ForegroundColor Yellow
    Write-Host "[Agent Sync] Please initialize git repository in $MirrorRepoPath first." -ForegroundColor Yellow
    exit 0
}

# Retrieve last commit details from work repository
Push-Location $WorkRepoAbsPath
try {
    $authorEmail    = (git log -1 --format="%ae").Trim()
    $committerEmail = (git log -1 --format="%ce").Trim()
    $commitBody     = (git log -1 --format="%b")
    $commitHash     = (git log -1 --format="%h").Trim()
} catch {
    Write-Host "[Agent Sync] Failed to retrieve git log from work repo." -ForegroundColor Red
    Pop-Location
    exit 1
} finally {
    Pop-Location
}

# Determine Agent Role in the commit
$role = $null

if ($authorEmail -ieq $AgentEmail) {
    $role = "Authored"
} elseif ($committerEmail -ieq $AgentEmail) {
    $role = "Committed"
} elseif ($commitBody -match [regex]::Escape($AgentEmail)) {
    $role = "Co-Authored"
}

# Execute sync if agent was involved
if ($role) {
    Write-Host "[Agent Sync] Agent contribution detected ($role). Mirroring to profile..." -ForegroundColor Green

    Push-Location $MirrorRepoPath
    try {
        $env:GIT_AUTHOR_NAME     = "Agent Bot"
        $env:GIT_AUTHOR_EMAIL    = $AgentEmail
        $env:GIT_COMMITTER_NAME  = "Agent Bot"
        $env:GIT_COMMITTER_EMAIL = $AgentEmail

        $commitMsg = "activity($role): sync contribution from work repo [$commitHash]"
        git commit --allow-empty -m "$commitMsg"
        
        if ($LASTEXITCODE -eq 0) {
            git push origin main --quiet
            if ($LASTEXITCODE -eq 0) {
                Write-Host "[Agent Sync] Successfully pushed contribution graph update ($role)!" -ForegroundColor Green
            } else {
                Write-Host "[Agent Sync] Pushed failed. Ensure remote repository is configured." -ForegroundColor Yellow
            }
        }
    } catch {
        Write-Host "[Agent Sync] Error during mirror commit: $_" -ForegroundColor Red
    } finally {
        Pop-Location
        Remove-Item Env:\GIT_AUTHOR_NAME -ErrorAction SilentlyContinue
        Remove-Item Env:\GIT_AUTHOR_EMAIL -ErrorAction SilentlyContinue
        Remove-Item Env:\GIT_COMMITTER_NAME -ErrorAction SilentlyContinue
        Remove-Item Env:\GIT_COMMITTER_EMAIL -ErrorAction SilentlyContinue
    }
} else {
    Write-Host "[Agent Sync] No agent activity in last commit. Skipping sync." -ForegroundColor Gray
}
