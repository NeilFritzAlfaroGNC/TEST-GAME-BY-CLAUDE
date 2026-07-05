# Food Heroes — one-command validation (Windows PowerShell 5.1 compatible).
#   powershell -ExecutionPolicy Bypass -File tools\test.ps1
# Runs: import -> logic smoke test -> headless Main.tscn -> headless MainMenu.tscn.
# Exits 0 on PASS, 1 on FAIL.

$godot = "C:\SHIZ\Godot_v4.6.3-stable_win64.exe"
$proj  = Split-Path $PSScriptRoot -Parent
$failPattern = "SCRIPT ERROR|Parse Error|Invalid access|Invalid call|null instance|Cannot find"
$failed = $false

if (-not (Test-Path $godot)) {
    Write-Host "Godot not found at $godot" -ForegroundColor Red
    exit 1
}

Write-Host "== 1/4 Import =="
& $godot --headless --path $proj --import *> $null

Write-Host "== 2/4 Logic smoke test =="
$out = (& $godot --headless --path $proj -s res://tools/smoke_test.gd 2>&1 | Out-String)
Write-Host $out
if ($LASTEXITCODE -ne 0 -or $out -notmatch "ALL PASS") { $failed = $true }

Write-Host "== 3/4 Headless run: Main.tscn =="
$out = (& $godot --headless --path $proj res://scenes/Main.tscn --quit-after 150 2>&1 | Out-String)
if ($out -match $failPattern) { Write-Host $out; $failed = $true } else { Write-Host "   clean" }

Write-Host "== 4/4 Headless run: MainMenu.tscn =="
$out = (& $godot --headless --path $proj res://scenes/MainMenu.tscn --quit-after 60 2>&1 | Out-String)
if ($out -match $failPattern) { Write-Host $out; $failed = $true } else { Write-Host "   clean" }

if ($failed) {
    Write-Host "RESULT: FAIL" -ForegroundColor Red
    exit 1
}
Write-Host "RESULT: PASS" -ForegroundColor Green
exit 0
