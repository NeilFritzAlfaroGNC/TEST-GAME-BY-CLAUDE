# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

**Food Heroes** — an educational drag-and-drop game (Godot 4.6, GDScript) that teaches the Filipino **Go / Glow / Grow** food groups. Built as a gray-box prototype: gameplay is complete but visuals are still colored `ColorRect` boxes on purpose ("art last"). See `README.md` for player-facing details and the phase-by-phase mapping to the original dev reference.

## Running & validating (no unit-test framework)

Godot is **not on PATH**. The editor/runtime executable is:
```
C:\SHIZ\Godot_v4.6.3-stable_win64.exe
```

There is no test suite. The de-facto "test" is importing and running scenes **headless** and checking for errors. Always re-import after adding/changing resources (scripts, `.wav`, scenes):

```powershell
# Import (regenerates .godot/ cache; run after adding resources)
& "C:\SHIZ\Godot_v4.6.3-stable_win64.exe" --headless --path "D:\TEST" --import

# Run one scene for ~N frames to catch runtime errors (the "single test")
& "C:\SHIZ\Godot_v4.6.3-stable_win64.exe" --headless --path "D:\TEST" "res://scenes/Main.tscn" --quit-after 150
```

When checking a headless run, filter for **real** failures and ignore noise:
`SCRIPT ERROR | Parse Error | Invalid access | Invalid call | null instance | Cannot find`.

Known benign noise: a `--quit-after` run logs `resource still in use: music.wav` / "ObjectDB instances leaked at exit". This is only the audio autoload being force-killed mid-playback; it does **not** happen on a normal window close and is not a real leak.

Do **not** launch `--headless --editor`: `--quit-after` does not quit the *editor*, so the process stays alive in the background holding the `godot-sqlite` DLL — subsequent `--import` runs then fail with `Error copying library` / `GDExtension dynamic library not found`. If imports suddenly fail that way, kill the stray Godot process. A force-killed instance also leaves `~libgdsqlite…TMP` copies in `addons/godot-sqlite/bin/`; they are the extension's copy-on-load leftovers, already gitignored (`*.TMP`), and safe to delete. (Editor-only chores like re-saving scenes for uid headers must be done in the editor UI.)

Headless cannot simulate mouse drag — to verify gameplay feel (drag, zap/heal/slam, sound) open the project and press **F5**.

## Regenerating audio

All sound is synthesized locally — there are **no downloaded assets**. To change a sound, edit and re-run the generator (pure Python stdlib), then re-import:
```powershell
python tools/generate_audio.py     # writes audio/*.wav
```

## Architecture (the big picture)

**Three autoloads hold everything that must outlive a scene change** (registered in `project.godot`, in this init order):
- `DB` (`scripts/Database.gd`) — persistence layer. Backend is **SQLite only**, via the `godot-sqlite` GDExtension committed in `addons/godot-sqlite/` (Windows + Android binaries). The `SQLite` class is still reached by string (`ClassDB.instantiate("SQLite")`); `_open()` verifies the class exists and the DB opens with **runtime checks, not `assert`s** (asserts are stripped from release exports) — on failure it `push_error`s, shows an `OS.alert`, and quits. Because `quit()` only lands at end of frame, the query helpers guard `_db == null` and public methods return safe defaults, and every query's return value is checked (`push_error` on failure). Tables: `meta` (high score) and `progress` (`PRIMARY KEY(difficulty, level)` → best_score, stars, completed). Exposes `record_level_result`, `get_high_score`, `get_level_progress`, `is_level_unlocked`. There is **no run history / recent-scores feature** — the old `runs` table is dropped on open. The high score is shown on the Main Menu, the in-level HUD, and the Result screen. Must load **before** `GameData` (which calls it on `_ready`).
- `GameData` (`scripts/GameData.gd`) — the food database (`FOODS` by group), the numbered `LEVELS` (1-based) and `DIFFICULTIES` (Easy/Medium/Hard modifiers: lives, enemy speed, spawn rate, enemy bonus, score multiplier), and the **live run state** (`current_difficulty`, `current_level`, `score`, `lives`, `starting_lives`, `last_result`, `last_stars`). State lives here, *not* in the game scene, so it survives `change_scene_to_file`. `start_level(difficulty, number)` resets the run; `record_result(won)` computes stars from lives and writes scores+progress through `DB`.
- `Audio` (`scripts/Audio.gd`) — one-shot SFX pool + looping music, all null-guarded so missing files never crash the game. Runs with `PROCESS_MODE_ALWAYS` so music and menu clicks keep working while the tree is paused.

**SQLite is required:** the `godot-sqlite` addon (`.gdextension` + platform binaries for Windows/Android) is committed in `addons/godot-sqlite/`, so no setup step is needed. There is no JSON fallback — if the extension fails to load, `DB._open()` alerts and quits (a runtime check that also works in release builds).

**Scene flow:** `MainMenu.tscn` → `LevelSelect.tscn` → `Main.tscn` (one level) → `ResultScreen.tscn` → (Next / Retry / Level Select / Menu). `ResultScreen` reads `GameData.last_result` (win/lose) and `last_stars`.

**Pause (`scripts/PauseMenu.gd` on `Main.tscn`'s `PausePopup/Root`):** Esc (`ui_cancel`) or the HUD **Pause** button toggles `get_tree().paused`, which freezes enemies, both spawn timers, belt foods, and camera shake. The overlay's `process_mode = 3` (ALWAYS) is what keeps its Esc handling and buttons alive while paused — don't remove it. `_pause()` refuses when `game_active` is false (lesson popup / game over). Its Retry / Level Select / Main Menu buttons **must unpause before `change_scene_to_file`** or the next scene loads frozen (`_leave()` does this). Leaving mid-level records no result — progress only saves through `GameData.record_result`.

**`LevelSelect.gd`** picks a difficulty (Easy/Medium/Hard) and a numbered level, then calls `GameData.start_level(...)`. It builds the level grid **dynamically in code** from `DB.is_level_unlocked` / `DB.get_level_progress`; levels unlock in order **per difficulty** (clear level N to open N+1; each difficulty is an independent track).

**`Main.gd` plays exactly one level** (the one chosen in LevelSelect) and applies the difficulty modifiers: it sets each enemy's `speed`, the spawn `wait_time`, the enemy count, and the score multiplier from `GameData.difficulty_data()`. A WHILE-style loop spawns/defeats enemies; the teaching moment is the right-vs-wrong food check in `food_dropped_on_hero`. On clear → lesson popup → `record_result(true)` → ResultScreen; on death → `record_result(false)` → ResultScreen.

**Cross-script contract (important when renaming or restructuring):**
- `Food.gd` and `Enemy.gd` reach the controller via `get_tree().current_scene` and call `food_dropped_on_hero(self)` / `enemy_reached_hero(self)`. This only works because **`Main` is the active scene** and exposes those methods.
- Both also locate the hero with `current_scene.get_node("Hero")`, so the hero **must remain a direct child of `Main` named exactly `Hero`**.
- These cross-node calls pass **untyped** params on purpose — typing them (e.g. `food: Node`) would make GDScript's static checker reject `food.food_group` / `food.label`.

**Enemy lifecycle & the level state machine:** spawned enemies join the `"enemies"` group (the boss uses a separate `"boss"` group). A correct food defeats the **closest** enemy to the Hero. `_despawn_enemy` removes an enemy from the group *before* `queue_free` (so the count is right that same frame), then calls `_check_level_complete.call_deferred()`. `_check_level_complete` is the driver: once `enemies_to_spawn <= 0` and the `"enemies"` group is empty, it starts the next wave, spawns the boss, or finishes the level — see boss levels below.

**Boss levels & waves (`Main.gd` + `GameData.BOSS_*`):** every `BOSS_EVERY`-th level (`GameData.is_boss_level`, default every 5th) is a boss fight, not a flat batch. It runs `BOSS_WAVES` waves (`_start_wave`), each targeting a different group (`_build_wave_groups`: wave 1 = Go, then random), then unleashes the **boss** (`_spawn_boss`) — a big, slow Enemy in the `"boss"` group. You beat it by **building a balanced meal**: feeding one food from *each* group in `BOSS_MEAL_GROUPS` (Go + Grow + Glow). `_feed_boss` tracks the still-needed groups in `_meal_needed` — a needed group lands a hit, a duplicate is rejected. While `_boss_active`, `food_dropped_on_hero` routes to `_feed_boss` (any group can be correct), bypassing the normal right/wrong check. The boss reaching the Hero → `_boss_reached_hero` (costs a life, then knockback). Clearing all three groups → `_level_complete` with `BOSS_LESSON`.

**Food conveyor belt & solvability invariant:** foods are **spawned onto a left→right conveyor belt** (`scenes/Food.tscn` + `Food.gd`), not fixed boxes. Each food slides in from the left and **stacks** against a stop point (right-anchored) instead of running off-screen — `Main._layout_belt()` runs every frame, sorts the belt foods by x, and assigns each a `target_x` (`STACK_FRONT_X`, `STACK_SPACING`) that the food slides toward. If a food isn't grabbed within `LIFETIME` (5s) it **blinks and despawns** (dragged foods pause their timer). `Main` spawns them via `_food_timer` → `_spawn_food` (a random **1–2 foods per tick**) into the `$Foods` container and keeps the level solvable by always spawning a food of any **needed group** not currently on the belt: `_needed_groups()` returns `[correct_group]` for a normal level/wave, or the still-missing groups of the balanced meal during the boss. `food_dropped_on_hero(food)` now **returns bool** (true = consumed/removed, false = rides back onto the belt). Never remove the needed-group guarantee or a level/boss can become unwinnable.

**Special attack effects (`Main.gd`)** are fully procedural (no assets): Go = `Line2D` lightning (`_effect_zap`), Glow = green pulse + expanding ring (`_effect_heal`), Grow = shockwave + camera shake + hero lunge (`_effect_slam`). The shake is driven by the `Camera2D` in `Main.tscn` via `_process`. The hero's slam-lunge and heal-tint tweens are **single-flight** (`_hero_move_tween` / `_hero_tint_tween`): a new effect kills the previous tween and re-anchors to `_hero_home`, so overlapping effects can never leave the hero drifted off its home position. A correct food also floats a rising `+nutrient` label (`_show_nutrient_popup`) whose text comes from `GameData.food_nutrient()` (the `FOOD_NUTRIENTS` map).

## Godot conventions & gotchas specific to this project

- **The food group is a bare string** `"Go"` / `"Glow"` / `"Grow"`, used three ways: dict key into `GameData.FOODS`, key into `GameData.group_color()`, and compared against a level's `correct_group`. Spelling must match exactly across `GameData`, scenes, and code.
- **Clicks/drag require care:** every interactive `Area2D` needs a `CollisionShape2D`, and any `ColorRect`/`Label` drawn over it (including the full-screen `Background`) must set `mouse_filter = 2` (Ignore) or it swallows the click before physics picking sees it. `Main._ready` also sets `get_viewport().physics_object_picking = true`.
- **Gray-box is intentional.** When the art phase comes, replace each `ColorRect` with a `Sprite2D` but keep node names and attached scripts identical so the contracts above keep working.
- **Commit Godot metadata:** `*.import` (e.g. `audio/*.wav.import`) and `*.uid` files must be committed alongside their source; `.godot/` is the cache and is gitignored. Opening the project in the editor re-saves `.tscn` files with added `uid`/`unique_id` fields — that's expected, don't revert it.
- GDScript is **tab-indented**. Keep the `config/features` version in `project.godot` aligned with the editor version (4.6).
