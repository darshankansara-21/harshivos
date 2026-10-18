# One-game play check. Not a factory. Run from the harshivos repo.
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
$flutter = 'C:\src\flutter\bin\flutter.bat'
if (Get-Command flutter -ErrorAction SilentlyContinue) { $flutter = 'flutter' }
& $flutter test --no-pub -j 1 test/race_keeper_rules_test.dart test/mini_games_test.dart --name "Racing|gas builds|goalkeeper"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $flutter test --no-pub -j 1 test/arcade_games_test.dart --name "Goal Keeper"
exit $LASTEXITCODE
