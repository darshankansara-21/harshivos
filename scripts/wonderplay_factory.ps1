<#
  WonderPlay Self-Driving Development Factory — autonomous orchestrator.

  WHAT THIS DOES
  --------------
  Starts the GitHub Copilot CLI (the Claude-backed coding agent) in
  non-interactive mode, hands it the permanent WonderPlay mission, lets it do
  ONE safe unit of work, then — when that worker exits (context/tool limit or a
  completed batch) — launches a FRESH worker automatically. Each worker reads
  the repository (CLAUDE.md + docs/WONDERPLAY_GAME_FACTORY_STATE.md + git) as its
  only memory. No human intervention between workers.

  The repository is the memory. Each Copilot context is disposable.

  START ONCE:
      powershell -NoProfile -ExecutionPolicy Bypass -File scripts/wonderplay_factory.ps1

  STOPS ONLY WHEN:
    - docs/WONDERPLAY_GAME_FACTORY_STATE.md contains FACTORY_COMPLETE = TRUE, or
    - a genuinely unrecoverable environment failure occurs (e.g. the Copilot CLI
      cannot be installed/authenticated), or
    - the safety stall-guard trips (many consecutive iterations with no git
      progress AND no clean exit), or
    - -MaxIterations is reached.

  A new Copilot context is NOT a failure. It is expected.
#>
[CmdletBinding()]
param(
  [int]$MaxIterations = 500,
  [int]$MaxAutopilotContinues = 60,
  [int]$StallLimit = 6,           # consecutive no-progress iterations before pausing hard
  [int]$CooldownSeconds = 20,     # pause between workers
  [string]$Model = ''             # optional: force a model; empty = Copilot default (Claude)
)

$ErrorActionPreference = 'Continue'
$repo    = Split-Path $PSScriptRoot -Parent
$copilot = Join-Path $env:APPDATA 'npm\copilot.cmd'
$state   = Join-Path $repo 'docs\WONDERPLAY_GAME_FACTORY_STATE.md'
$claude  = Join-Path $repo 'CLAUDE.md'
$logDir  = Join-Path $repo '_factory_logs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

# Flutter on PATH so the worker's shell can build/test immediately.
if (Test-Path 'C:\src\flutter\bin') { $env:Path += ';C:\src\flutter\bin' }

# CRITICAL: the --allow-all-tools FLAG only auto-approves tools, but headless SHELL
# execution stays blocked until the working directory is TRUSTED. Setting
# COPILOT_ALLOW_ALL to exactly "true" trusts the working dir and lets the worker run
# shell commands (flutter/git) without a human to approve them. Verified 2026-10-04.
$env:COPILOT_ALLOW_ALL = 'true'

function Write-Log($msg) {
  $line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg
  Write-Host $line
  Add-Content -Path (Join-Path $logDir 'factory.log') -Value $line
}

function Test-FactoryComplete {
  if (-not (Test-Path $state)) { return $false }
  $txt = Get-Content $state -Raw
  # Only the real status line counts: a line that begins FACTORY_COMPLETE : TRUE.
  # Prose mentions elsewhere start with a quote or angle bracket, so the
  # start-of-line anchor below does not match them.
  return [bool]($txt -match '(?im)^\s*FACTORY_COMPLETE\s*[:=]\s*\**\s*TRUE\b')
}

function Get-RepoHead {
  try { (& git -C $repo rev-parse --short HEAD 2>$null) } catch { '' }
}

function Ensure-Copilot {
  if (-not (Test-Path $copilot)) {
    Write-Log "Copilot CLI missing. Installing @github/copilot ..."
    & 'npm.cmd' install -g '@github/copilot' 2>&1 | Out-Null
  }
  return (Test-Path $copilot)
}

# The permanent per-worker bootstrap lives in scripts/factory_prompt.txt (kept in a
# separate file to avoid any quoting pitfalls). The full, durable rules live in
# CLAUDE.md and the state file; each worker must re-read them itself.
$promptFile = Join-Path $PSScriptRoot 'factory_prompt.txt'
if (-not (Test-Path $promptFile)) {
  Write-Log "FATAL: missing scripts/factory_prompt.txt"
  exit 3
}
$bootstrap = Get-Content $promptFile -Raw

Write-Log "=== WonderPlay self-driving factory starting ==="
Write-Log "repo=$repo"
Write-Log "copilot=$copilot"

if (-not (Ensure-Copilot)) {
  Write-Log "FATAL: GitHub Copilot CLI is not installed and could not be installed. Run: npm install -g @github/copilot then: copilot login. Stopping."
  exit 2
}

$iter = 0
$stall = 0
$lastHead = Get-RepoHead

while ($true) {
  if (Test-FactoryComplete) {
    Write-Log "FACTORY_COMPLETE = TRUE detected in state file. The factory is done. Stopping."
    break
  }
  if ($iter -ge $MaxIterations) {
    Write-Log "Reached MaxIterations $MaxIterations. Stopping; rerun to continue."
    break
  }
  $iter++
  $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
  $wlog  = Join-Path $logDir "worker_$($iter)_$stamp.log"
  Write-Log "--- worker #$iter starting (fresh context) -> $wlog"

  $cliArgs = @(
    '-p', $bootstrap,
    '--allow-all-tools',
    '--autopilot', '--max-autopilot-continues', "$MaxAutopilotContinues",
    '-C', $repo,
    '--log-dir', $logDir,
    '--log-level', 'error'
  )
  if ($Model) { $cliArgs += @('--model', $Model) }

  try {
    & $copilot @cliArgs *> $wlog
    $code = $LASTEXITCODE
  } catch {
    $code = 999
    Add-Content -Path $wlog -Value "ORCHESTRATOR EXCEPTION: $($_.Exception.Message)"
  }
  Write-Log "worker #$iter exited code=$code"

  # Progress / stall detection — did the repo advance?
  $head = Get-RepoHead
  if ($head -and $head -ne $lastHead) {
    Write-Log "progress: HEAD $lastHead -> $head"
    $lastHead = $head
    $stall = 0
  } else {
    $stall++
    Write-Log "no new commit this iteration (stall=$stall of $StallLimit)"
  }

  # Safety: warn if the worker left the tree dirty (next worker should reconcile).
  $dirty = (& git -C $repo status --porcelain) | Measure-Object | Select-Object -ExpandProperty Count
  if ($dirty -gt 0) { Write-Log "WARNING: working tree is dirty: $dirty files. Next worker must reconcile." }

  if (Test-FactoryComplete) {
    Write-Log "FACTORY_COMPLETE = TRUE detected after worker #$iter. Stopping."
    break
  }

  if ($stall -ge $StallLimit) {
    Write-Log "STALL GUARD: $StallLimit consecutive iterations with no git progress. Pausing 5 min then continuing; machine may be overloaded or blocked."
    Start-Sleep -Seconds 300
    $stall = 0
  } else {
    Start-Sleep -Seconds $CooldownSeconds
  }
}

Write-Log "=== factory orchestrator exiting after $iter iteration(s) ==="
