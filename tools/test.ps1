# Food Heroes — one-command validation (Windows PowerShell 5.1 compatible).
#   powershell -ExecutionPolicy Bypass -File tools\test.ps1
# Runs: import -> logic smoke test -> solvability invariant -> headless scene runs.
# Exits 0 on PASS, 1 on FAIL.

$godot = "C:\SHIZ\Godot_v4.6.3-stable_win64.exe"
$proj  = Split-Path $PSScriptRoot -Parent

# What counts as a real failure. The last alternative is deliberately TARGETED,
# not a bare "ERROR:" match: a native CHECK/ERR_FAIL_COND is how the Layout NaN
# bug showed itself, and it was reported "clean" for several tasks because the
# pattern did not cover that class. A blanket ERROR match is NOT the fix — the
# documented-benign `ObjectDB instances leaked at exit` and
# `resource still in use: music.wav` from a --quit-after run are themselves
# ERROR-level, so matching them would fail every run and train everyone to
# ignore red, which is worse than the bug.
$failPattern = 'SCRIPT ERROR|Parse Error|Invalid access|Invalid call|null instance|Cannot find|Condition ".*" is true'
$failed = $false

if (-not (Test-Path $godot)) {
    Write-Host "Godot not found at $godot" -ForegroundColor Red
    exit 1
}

Write-Host "== 1/6 Import =="
& $godot --headless --path $proj --import *> $null

Write-Host "== 2/6 Logic smoke test =="
$out = (& $godot --headless --path $proj -s res://tools/smoke_test.gd 2>&1 | Out-String)
Write-Host $out
if ($LASTEXITCODE -ne 0 -or $out -notmatch "ALL PASS" -or $out -match $failPattern) { $failed = $true }

# The solvability invariant has two halves. smoke_test covers WaveDirector's
# track/untrack/needed_groups; this drives the real Game.tscn and proves Game.gd
# actually CALLS them in pairs. Dropping either call makes levels unwinnable
# while every other step here stays green, so it gets its own gate.
Write-Host "== 3/6 Solvability invariant: Game track/untrack pairing =="
$out = (& $godot --headless --path $proj res://tools/invariant_test.tscn --quit-after 900 2>&1 | Out-String)
Write-Host $out
if ($LASTEXITCODE -ne 0 -or $out -notmatch "INVARIANT: ALL PASS" -or $out -match $failPattern) { $failed = $true }

Write-Host "== 4/6 Headless run: Game.tscn =="
$out = (& $godot --headless --path $proj res://scenes/Game.tscn --quit-after 150 2>&1 | Out-String)
if ($out -match $failPattern) { Write-Host $out; $failed = $true } else { Write-Host "   clean" }

Write-Host "== 5/6 Headless run: MainMenu.tscn =="
$out = (& $godot --headless --path $proj res://scenes/MainMenu.tscn --quit-after 60 2>&1 | Out-String)
if ($out -match $failPattern) { Write-Host $out; $failed = $true } else { Write-Host "   clean" }

Write-Host "== 6/6 Headless run: HowToPlay.tscn =="
$out = (& $godot --headless --path $proj res://scenes/HowToPlay.tscn --quit-after 60 2>&1 | Out-String)
if ($out -match $failPattern) { Write-Host $out; $failed = $true } else { Write-Host "   clean" }

if ($failed) {
    Write-Host "RESULT: FAIL" -ForegroundColor Red
    exit 1
}
Write-Host "RESULT: PASS" -ForegroundColor Green
exit 0
