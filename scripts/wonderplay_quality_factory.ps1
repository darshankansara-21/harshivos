# One-game quality factory. Default is Status: it does not call a model.
# Once invokes exactly one Copilot CLI worker, then stops.
# A game that exits without a commit is quarantined and is not retried.
[CmdletBinding()]
param(
  [ValidateSet('Status', 'Once')]
  [string]$Action = 'Status'
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$backlogPath = Join-Path $repo 'docs\WONDERPLAY_QUALITY_BACKLOG.json'
$logDir = Join-Path $repo '_factory_logs'
$lockPath = Join-Path $logDir 'quality.lock'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
Set-Location -LiteralPath $repo

if (-not (Test-Path (Join-Path $repo 'pubspec.yaml'))) {
  throw "Refusing to run outside the WonderPlay repo: $repo"
}
$branch = (& git rev-parse --abbrev-ref HEAD).Trim()
if ($branch -ne 'main') { throw "Refusing to run on branch $branch" }

$backlog = Get-Content $backlogPath -Raw | ConvertFrom-Json
$next = $backlog.games | Where-Object { $_.status -eq 'pending' } | Select-Object -First 1
Write-Host "HEAD $((& git rev-parse --short HEAD).Trim())"
Write-Host "NEXT $($next.id)"
if ($Action -eq 'Status') { exit 0 }

if (Test-Path $lockPath) {
  $owner = Get-Content $lockPath -Raw
  throw "Factory lock exists ($owner). Remove it only if no worker is running."
}
$dirty = (& git status --porcelain)
if ($dirty) { throw 'Working tree is dirty. Commit or leave it before Once.' }

$copilot = Join-Path $env:APPDATA 'npm\copilot.cmd'
if (-not (Test-Path $copilot)) { throw "Copilot CLI missing: $copilot" }

Set-Content -Path $lockPath -Value "$PID $(Get-Date -Format o)"
$before = (& git rev-parse HEAD).Trim()
$prompt = @"
You are in C:\src\lifelens\harshivos on main. Improve ONLY the existing game id '$($next.id)'.
Make one meaningful gameplay change, add or update a focused test, run that test, and commit if it passes.
Do not add games. Do not edit other games. Do not push. Do not reset. If you cannot improve it, exit without committing.
"@
$env:COPILOT_ALLOW_ALL = 'true'
if (Test-Path 'C:\src\flutter\bin') { $env:Path += ';C:\src\flutter\bin' }
& $copilot -p $prompt --allow-all-tools -C $repo -s --model auto
$code = $LASTEXITCODE
$after = (& git rev-parse HEAD).Trim()
Remove-Item $lockPath -Force
if ($after -eq $before) {
  foreach ($game in $backlog.games) {
    if ($game.id -eq $next.id) {
      $game.status = 'quarantined'
      $game.note = "worker exit $code produced no commit"
    }
  }
  $backlog | ConvertTo-Json -Depth 6 | Set-Content $backlogPath
  Write-Host "QUARANTINED $($next.id)"
  exit 2
}
Write-Host "PROGRESSED $before -> $after"
exit 0
