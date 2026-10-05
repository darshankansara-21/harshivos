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
  [int]$StallLimit = 4,           # consecutive exit-0-but-no-commit iterations before stopping
  [int]$FailLimit = 3,            # consecutive worker FAILURES (exit != 0) before stopping
  [int]$CooldownSeconds = 20,     # pause between workers
  [int]$MaxFilesPerStep = 80,     # per-iteration committed-file budget; above this = investigate, not continue
  [int]$MaxLinesPerStep = 8000,   # per-iteration committed-line budget (insertions+deletions)
  [string]$Model = ''             # optional: force a model; empty = Copilot default (Claude)
)

$ErrorActionPreference = 'Continue'
$repo    = Split-Path $PSScriptRoot -Parent
$copilot = Join-Path $env:APPDATA 'npm\copilot.cmd'
$state   = Join-Path $repo 'docs\WONDERPLAY_GAME_FACTORY_STATE.md'
$claude  = Join-Path $repo 'CLAUDE.md'
$logDir  = Join-Path $repo '_factory_logs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

# CRITICAL: the Copilot CLI's shell SANDBOX is scoped to the launching process's
# working directory (COPILOT_ALLOW_ALL trusts the CWD), NOT the -C flag. If the
# orchestrator is started from a subfolder (e.g. .vscode) the worker is trapped
# there, cannot reach the repo root, and either stalls (+0 -0) or wanders into a
# nested clone. Force CWD to the repo root so the sandbox covers the whole repo.
Set-Location -LiteralPath $repo

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

# origin/main after a fetch. Workers push their work, so the remote is the real
# source of truth for progress even if a worker committed from another checkout.
function Get-OriginHead {
  try {
    & git -C $repo fetch origin -q 2>$null | Out-Null
    (& git -C $repo rev-parse --short origin/main 2>$null)
  } catch { '' }
}

# Keep the real repo current with pushed work so local HEAD advances here too
# (single source of truth). Fast-forward only -- never creates merge noise.
function Sync-MainToOrigin {
  & git -C $repo pull --ff-only origin main -q 2>$null | Out-Null
}

# A leftover uncommitted file (e.g. a worker's post-commit reformat) blocks
# pull --ff-only and leaves the local repo lagging origin. Park any leftovers in
# a stash (NEVER discard -- product work is preserved), fast-forward, then restore
# them for the next worker. Only tracked product files matter; gitignored temp
# files (_factory_logs, build, .vscode, evidence, _lltest) never appear here.
function Reconcile-Tree {
  $porcelain = & git -C $repo status --porcelain
  if (-not $porcelain) { Sync-MainToOrigin; return }
  $n = ($porcelain | Measure-Object).Count
  Write-Log "RECONCILE: $n leftover file(s) before sync -> stashing to fast-forward, then restoring."
  & git -C $repo stash push -u -m 'factory-autoreconcile' -q 2>$null | Out-Null
  Sync-MainToOrigin
  $pop = & git -C $repo stash pop 2>&1
  if ($LASTEXITCODE -ne 0) {
    Write-Log "RECONCILE: stash pop conflicted; leftovers kept in stash for manual review (git stash list). $pop"
  }
}

# Measure the committed diff a single iteration introduced. Returns a hashtable
# @{ Files; Lines }. Used to flag an accidental bulk rewrite for investigation
# instead of blindly continuing.
function Measure-StepDiff {
  param([string]$FromHead, [string]$ToHead)
  if (-not $FromHead -or -not $ToHead -or $FromHead -eq $ToHead) { return @{ Files = 0; Lines = 0 } }
  $stat = & git -C $repo diff --shortstat "$FromHead..$ToHead" 2>$null
  $files = 0; $lines = 0
  if ($stat -match '(\d+)\s+files?\s+changed')      { $files = [int]$Matches[1] }
  if ($stat -match '(\d+)\s+insertion')             { $lines += [int]$Matches[1] }
  if ($stat -match '(\d+)\s+deletion')              { $lines += [int]$Matches[1] }
  return @{ Files = $files; Lines = $lines }
}

# Count the product-code files a step actually changed. ONLY changes under lib/
# count as real improvement; a commit that touches only docs/, the state file,
# CLAUDE.md, scripts, or other non-code is an AUDIT/DOCUMENTATION step and must
# NOT be mistaken for product progress (that was the no-op-but-exit-0 pattern the
# human flagged). Returns the number of changed files whose path starts with lib/.
function Measure-StepProductFiles {
  param([string]$FromHead, [string]$ToHead)
  if (-not $FromHead -or -not $ToHead -or $FromHead -eq $ToHead) { return 0 }
  $names = & git -C $repo diff --name-only "$FromHead..$ToHead" 2>$null
  if (-not $names) { return 0 }
  return (@($names | Where-Object { $_ -match '^lib/' }) | Measure-Object).Count
}

# Workers must operate ONLY in the repo root. A nested clone (observed as
# .vscode/tmprepo) causes split-brain: a worker commits there and the
# orchestrator -- watching the real repo -- never sees progress. Remove any such
# nested clone when it is clean and fully pushed; refuse to delete unsaved work.
function Remove-StrayClone {
  $stray = Join-Path $repo '.vscode\tmprepo'
  if (-not (Test-Path (Join-Path $stray '.git'))) { return }
  $dirty    = (& git -C $stray status --porcelain 2>$null | Measure-Object).Count
  $unpushed = (& git -C $stray log --oneline '@{u}..HEAD' 2>$null | Measure-Object).Count
  if ($dirty -eq 0 -and $unpushed -eq 0) {
    Write-Log "Removing stray nested clone .vscode/tmprepo (clean + fully pushed) to prevent split-brain commits."
    Remove-Item -Recurse -Force $stray -ErrorAction SilentlyContinue
  } else {
    Write-Halt "Nested clone .vscode/tmprepo holds $dirty uncommitted / $unpushed unpushed change(s) -- workers committed OUTSIDE the main repo. Reconcile it (push or discard) then rerun; refusing to proceed with a split-brain working copy."
    exit 4
  }
}

function Ensure-Copilot {
  # CLI-missing is decided ONLY by the real executable on disk -- never by
  # scanning worker output. We do NOT auto-install (an unexpected reinstall can
  # mask the real problem); we report the exact absolute path we checked.
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

# Scan a finished worker's log for a FATAL, non-recoverable condition. Returns a
# human-readable reason string, or $null if nothing fatal was found. These are
# conditions where spawning MORE workers is pointless (they will all fail the
# same way) -- the orchestrator must STOP and tell the human, not keep looping.
function Get-WorkerFatalReason {
  param([string]$LogPath)
  if (-not (Test-Path $LogPath)) { return $null }
  $t = Get-Content $LogPath -Raw -Encoding Unicode
  if (-not $t) { $t = Get-Content $LogPath -Raw }
  # Match ONLY the Copilot CLI's own unrecoverable account/billing/auth errors.
  # NEVER match generic shell phrases (e.g. "is not recognized", "cannot find")
  # -- ordinary worker shell output contains those and must not halt the factory.
  # CLI-missing is handled separately via Test-Path on the real executable.
  if ($t -match 'exceeded your monthly quota') { return 'GitHub Copilot monthly quota exceeded (no AI credits). Add credits or wait for the monthly reset.' }
  if ($t -match 'no credits remaining|insufficient_quota')  { return 'Model provider has no credits remaining (billing). Add credits / configure a funded provider.' }
  if ($t -match '\b429\b[^\r\n]{0,40}(quota|credit|rate limit)') { return 'Model provider returned 429 (quota/rate/credit limit).' }
  if ($t -match 'authentication failed|401 Unauthorized|Please run:?\s*copilot login') { return 'Copilot CLI is not authenticated. Run: copilot login' }
  return $null
}

# Record a hard stop so the human knows EXACTLY why and what to do. Writes a
# marker file and appends to the factory log. Never silently keeps looping.
function Write-Halt {
  param([string]$Reason)
  $msg = "FACTORY HALTED: $Reason"
  Write-Log $msg
  $marker = Join-Path $logDir 'FACTORY_HALTED.txt'
  Set-Content -Path $marker -Value ("[{0}] {1}`r`nCurrent HEAD: {2}`r`nResume after fixing with:`r`n  powershell -NoProfile -ExecutionPolicy Bypass -File scripts/wonderplay_factory.ps1`r`n" -f (Get-Date), $Reason, (Get-RepoHead))
}

Write-Log "=== WonderPlay self-driving factory starting ==="
Write-Log "repo=$repo"
Write-Log "copilot=$copilot"

if (-not (Ensure-Copilot)) {
  Write-Log "FATAL: GitHub Copilot CLI not found at '$copilot'. Install with: npm install -g @github/copilot  then: copilot login. Stopping."
  exit 2
}
Write-Log "preflight OK: copilot executable present at $copilot"

# One source of truth: drop any stray nested clone and sync the repo to origin.
Remove-StrayClone
Reconcile-Tree

$iter = 0
$stall = 0
$fail = 0
$lastHead   = Get-RepoHead
$lastRemote = Get-OriginHead

while ($true) {
  if (Test-FactoryComplete) {
    Write-Log "FACTORY_COMPLETE = TRUE detected in state file. The factory is done. Stopping."
    break
  }
  if ($iter -ge $MaxIterations) {
    Write-Log "Reached MaxIterations $MaxIterations. Stopping; rerun to continue."
    break
  }
  # CLI-missing is checked against the REAL executable right before each launch --
  # never inferred from a previous worker's text output.
  if (-not (Test-Path $copilot)) {
    Write-Halt "Copilot CLI executable vanished from '$copilot'. Reinstall with: npm install -g @github/copilot"
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

  $started = Get-Date
  try {
    & $copilot @cliArgs *> $wlog
    $code = $LASTEXITCODE
  } catch {
    $code = 999
    Add-Content -Path $wlog -Value "ORCHESTRATOR EXCEPTION: $($_.Exception.Message)"
  }
  $elapsed = [int]((Get-Date) - $started).TotalSeconds
  Write-Log "worker #$iter exited code=$code in ${elapsed}s"

  # 1) FATAL check FIRST: if the worker died on a non-recoverable condition
  #    (quota/credits/auth/missing binary), spawning more workers is useless.
  #    STOP immediately with a clear diagnosis instead of burning the budget.
  $fatal = Get-WorkerFatalReason $wlog
  if ($fatal) {
    Write-Halt $fatal
    break
  }

  # 2) Did the repo actually advance? Reconcile any leftover dirty file FIRST so
  #    the fast-forward is not blocked, then count progress if EITHER the local
  #    HEAD or origin/main moved (a worker may push from any checkout).
  $remote = Get-OriginHead
  Reconcile-Tree
  $head = Get-RepoHead
  if (($head -and $head -ne $lastHead) -or ($remote -and $remote -ne $lastRemote)) {
    # Guard against an accidental bulk rewrite: a single step producing a huge
    # diff is suspicious -- investigate instead of auto-continuing.
    $d = Measure-StepDiff $lastHead $head
    if ($d.Files -gt $MaxFilesPerStep -or $d.Lines -gt $MaxLinesPerStep) {
      Write-Halt "Oversized change this step: $($d.Files) files / $($d.Lines) lines (limits $MaxFilesPerStep / $MaxLinesPerStep) between $lastHead..$head. This looks like a bulk/accidental rewrite, not a bounded product change. Review 'git diff $lastHead..$head' before resuming."
      break
    }
    # Only a change under lib/ is real product progress. A commit that touches
    # ONLY docs/state/CLAUDE/scripts is an audit/documentation step -- the human
    # explicitly ruled that does NOT count. Advance the baselines either way (so
    # the same commits are never re-counted), but a docs-only step is a STALL.
    $prod = Measure-StepProductFiles $lastHead $head
    $prevHead   = $lastHead
    $lastHead   = $head
    $lastRemote = $remote
    if ($prod -gt 0) {
      Write-Log "PROGRESS: local $prevHead -> $head ; origin $lastRemote -> $remote ($($d.Files) files / $($d.Lines) lines, $prod under lib/)"
      $stall = 0
      $fail = 0
    }
    else {
      $stall++
      Write-Log "NON-PRODUCT STEP: $prevHead..$head changed only docs/state/non-lib files ($($d.Files) files / $($d.Lines) lines, 0 under lib/). This does NOT count as product progress (consecutive stalls=$stall of $StallLimit)."
      if ($stall -ge $StallLimit) {
        Write-Halt "$StallLimit consecutive workers produced NO product-code change (only docs/state churn or clean no-ops). The mission requires AUDIT -> IMPLEMENT a real lib/ improvement -> TEST -> COMMIT -> PUSH. Review the newest worker_*.log and NEXT_ACTION: workers are auditing/documenting instead of implementing."
        break
      }
    }
  }
  elseif ($code -ne 0) {
    # A real failure (non-zero exit) with no progress.
    $fail++
    Write-Log "FAILURE: worker exited $code with no commit (consecutive failures=$fail of $FailLimit)"
    if ($fail -ge $FailLimit) {
      Write-Halt "$FailLimit consecutive worker FAILURES (exit != 0) with no git progress. Last exit=$code. See the newest worker_*.log in _factory_logs for the error. The loop stopped instead of burning more workers."
      break
    }
  }
  else {
    # Worker exited 0 but produced no commit (soft stall: wandered / no-op).
    $stall++
    Write-Log "STALL: worker exited 0 but made no commit (consecutive stalls=$stall of $StallLimit)"
    if ($stall -ge $StallLimit) {
      Write-Halt "$StallLimit consecutive workers exited cleanly but produced NO commit (no measurable progress). The loop stopped instead of spinning. Inspect the worker logs / NEXT_ACTION in the state file."
      break
    }
  }

  # Safety: warn if the worker left the tree dirty (next worker should reconcile).
  $dirty = (& git -C $repo status --porcelain) | Measure-Object | Select-Object -ExpandProperty Count
  if ($dirty -gt 0) { Write-Log "WARNING: working tree is dirty: $dirty files. Next worker must reconcile." }

  if (Test-FactoryComplete) {
    Write-Log "FACTORY_COMPLETE = TRUE detected after worker #$iter. Stopping."
    break
  }

  Start-Sleep -Seconds $CooldownSeconds
}

Write-Log "=== factory orchestrator exiting after $iter iteration(s) ==="
