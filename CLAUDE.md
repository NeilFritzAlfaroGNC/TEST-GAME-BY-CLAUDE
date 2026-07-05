# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

**Food Heroes** — an educational drag-and-drop game (Godot 4.6, GDScript) that teaches the Filipino **Go / Glow / Grow** food groups. Built as a gray-box prototype: gameplay is complete but visuals are still colored `ColorRect` boxes on purpose ("art last"). See `README.md` for player-facing details and the phase-by-phase mapping to the original dev reference.

## Running & validating (no unit-test framework)

Godot is **not on PATH**. The editor/runtime executable is:
```
C:\SHIZ\Godot_v4.6.3-stable_win64.exe
```

**The standard check is one command** — import + logic smoke test + headless scene runs, PASS/FAIL summary, exit code 0/1:

```powershell
powershell -ExecutionPolicy Bypass -File tools\test.ps1
```

`tools/smoke_test.gd` (run by test.ps1, or standalone via `--headless --path "D:\TEST" -s res://tools/smoke_test.gd`) asserts the pure logic: star math per difficulty, boss cadence, level clamping, nutrient coverage, difficulty tables, and the whole DB layer (unlock chain, best-score upsert, settings) against a **throwaway** `user://smoke_test.db` — never the real save. Note: `-s` script mode still loads the autoloads, but a child added to root during `_initialize` does **not** get `_ready` — the test calls `DB`-instance `_open()` directly for that reason.

The individual steps, when you need just one:

```powershell
# Import (regenerates .godot/ cache; run after adding resources)
& "C:\SHIZ\Godot_v4.6.3-stable_win64.exe" --headless --path "D:\TEST" --import

# Run one scene for ~N frames to catch runtime errors
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
- `Audio` (`scripts/Audio.gd`) — one-shot SFX + looping music, all null-guarded so missing files never crash the game. Each SFX has a small **voice pool** (`MAX_VOICES_PER_SFX`) so rapid repeats overlap instead of cutting off. Runs with `PROCESS_MODE_ALWAYS` so music and menu clicks keep working while the tree is paused. Holds the **mute** state (`muted` / `set_muted` / `toggle_muted` → Master bus mute), persisted through `DB.get_setting_int/set_setting_int` ("muted" in the `meta` table) and toggled by the Main Menu's **Sound** button.

**SQLite is required:** the `godot-sqlite` addon (`.gdextension` + platform binaries for Windows/Android) is committed in `addons/godot-sqlite/`, so no setup step is needed. There is no JSON fallback — if the extension fails to load, `DB._open()` alerts and quits (a runtime check that also works in release builds).

**Scene flow:** `MainMenu.tscn` → `LevelSelect.tscn` → `Main.tscn` (one level) → `ResultScreen.tscn` → (Next / Retry / Level Select / Menu). `ResultScreen` reads `GameData.last_result` (win/lose) and `last_stars`. The menu also links to `HowToPlay.tscn` (static instructions + a "Play Tutorial" button).

**First-run tutorial (`GameData.tutorial_mode` + Main.gd's tutorial branch):** the menu's Play button checks `DB.get_setting_int("tutorial_done", 0)` — if unset it calls `GameData.start_tutorial()` (Easy, 5 lives, `TUTORIAL_*` pacing consts) and loads `Main.tscn` instead of LevelSelect. Main's `_start_level` tutorial branch shows the `TUTORIAL_PAGES` intro one page at a time through the **lesson popup** (`_tutorial_intro_active` reroutes `_on_continue_pressed`), then starts a single slow GO wave; monsters and the belt only start after the last page. Completing it sets `tutorial_done=1`, clears `tutorial_mode`, and goes to LevelSelect **without recording a result** (the tutorial is not level 1). Losing it just restarts it; PauseMenu's Retry re-primes via `start_tutorial()` (not `start_level`, which clears the flag). `HowToPlay.tscn`'s "Play Tutorial" can rerun it any time.

**Pause (`scripts/PauseMenu.gd` on `Main.tscn`'s `PausePopup/Root`):** Esc (`ui_cancel`) or the HUD **Pause** button toggles `get_tree().paused`, which freezes enemies, both spawn timers, belt foods, and camera shake. The overlay's `process_mode = 3` (ALWAYS) is what keeps its Esc handling and buttons alive while paused — don't remove it. `_pause()` refuses when `game_active` is false (lesson popup / game over). Its Retry / Level Select / Main Menu buttons **must unpause before `change_scene_to_file`** or the next scene loads frozen (`_leave()` does this). Leaving mid-level records no result — progress only saves through `GameData.record_result`.

**`LevelSelect.gd`** picks a difficulty (Easy/Medium/Hard) and a numbered level, then calls `GameData.start_level(...)`. It builds the level grid **dynamically in code** from `DB.is_level_unlocked` / `DB.get_level_progress`; levels unlock in order **per difficulty** (clear level N to open N+1; each difficulty is an independent track).

**`Main.gd` plays exactly one level** (the one chosen in LevelSelect) and applies the difficulty modifiers: it sets each enemy's `speed`, the spawn `wait_time`, the enemy count, and the score multiplier from `GameData.difficulty_data()`. A WHILE-style loop spawns/defeats enemies; the teaching moment is the right-vs-wrong food check in `food_dropped_on_hero`. On clear → lesson popup → `record_result(true)` → ResultScreen; on death → `record_result(false)` → ResultScreen. `Main` is a **façade**: in `_ready` it code-creates two child components and delegates to them — **`BeltManager`** (`scripts/BeltManager.gd`, node "Belt": everything conveyor-side) and **`FxManager`** (`scripts/FxManager.gd`, node "Fx": all procedural effects). Both are deliberately scene-less; `Main` keeps the contract methods, the level/wave/boss state machine, scoring, and the HUD. On a boss level the HUD shows "BOSS: Balanced Meal" instead of the (ignored) `LEVELS` row name, and LevelSelect badges every boss tile ("BOSS n", purple tint).

**Cross-script contract (important when renaming or restructuring):**
- `Food.gd` and `Enemy.gd` reach the controller via `get_tree().current_scene` and call `food_dropped_on_hero(self)` / `enemy_reached_hero(self)`. This only works because **`Main` is the active scene** and exposes those methods.
- Both also locate the hero with `current_scene.get_node("Hero")`, so the hero **must remain a direct child of `Main` named exactly `Hero`**.
- These cross-node calls pass **untyped** params on purpose — typing them (e.g. `food: Node`) would make GDScript's static checker reject `food.food_group` / `food.label`.

**Enemy lifecycle & the level state machine:** spawned enemies join the `"enemies"` group (the boss uses a separate `"boss"` group). A correct food defeats the **closest** enemy to the Hero. `_despawn_enemy` removes an enemy from the group *before* `queue_free` (so the count is right that same frame), then calls `_check_level_complete.call_deferred()`. `_check_level_complete` is the driver: once `enemies_to_spawn <= 0` and the `"enemies"` group is empty, it starts the next wave, spawns the boss, or finishes the level — see boss levels below.

**Boss levels & waves (`Main.gd` + `GameData.BOSS_*`):** every `BOSS_EVERY`-th level (`GameData.is_boss_level`, default every 5th) is a boss fight, not a flat batch. It runs `BOSS_WAVES` waves (`_start_wave`), each targeting a different group (`_build_wave_groups`: wave 1 = Go, then random), then unleashes the **boss** (`_spawn_boss`) — a big, slow Enemy in the `"boss"` group. You beat it by **building a balanced meal**: feeding one food from *each* group in `BOSS_MEAL_GROUPS` (Go + Grow + Glow). `_feed_boss` tracks the still-needed groups in `_meal_needed` — a needed group lands a hit, a duplicate is rejected. While `_boss_active`, `food_dropped_on_hero` routes to `_feed_boss` (any group can be correct), bypassing the normal right/wrong check. The boss reaching the Hero → `_boss_reached_hero` (costs a life, then knockback). Clearing all three groups → `_level_complete` with `BOSS_LESSON`.

**Food conveyor belt & solvability invariant (`scripts/BeltManager.gd`):** foods are **spawned onto a left→right conveyor belt** (`scenes/Food.tscn` + `Food.gd`), not fixed boxes. Each food slides in from the left and **stacks** against a stop point (right-anchored) instead of running off-screen — `BeltManager._layout()` runs every frame, sorts the belt foods by x, and assigns each a `target_x` (`STACK_FRONT_X`, `STACK_SPACING`) that the food slides toward. If a food isn't grabbed within `LIFETIME` (5s) it **blinks and despawns** (dragged foods pause their timer). Food nodes live in **Main's `$Foods` container** (PauseMenu iterates `main.foods_container` — don't move ownership). Spawning is two-tier: a 1s timer adds **1–2 random foods per tick** capped at `MAX_FOODS`, while `_ensure_needed()` runs **every frame** and instantly (cap-free) spawns a food of any **needed group** missing from the belt — so at least one usable food is always available, with zero gap. The needed groups come from a Callable to `Main._needed_groups()`: `[correct_group]` for a normal level/wave, or the still-missing groups of the balanced meal during the boss. `food_dropped_on_hero(food)` **returns bool** (true = consumed/removed, false = rides back onto the belt). Never remove `_ensure_needed()` or a level/boss can become unwinnable. Shared layout numbers (`DESIGN_SIZE`, `BELT_TOP`, `BELT_Y`) live in `GameData`.

**Special attack effects (`scripts/FxManager.gd`)** are fully procedural (no assets): Go = `Line2D` lightning (`_zap`), Glow = green pulse + expanding ring (`_heal`), Grow = shockwave + camera shake + hero lunge (`_slam`). `Main` calls `fx.play_attack(group, target)` / `fx.shake(...)` / `fx.nutrient_popup(...)`. The shake is driven by the `Camera2D` handed over in `fx.setup(hero, cam)` via FxManager's `_process`. The hero's slam-lunge and heal-tint tweens are **single-flight** (`_hero_move_tween` / `_hero_tint_tween`): a new effect kills the previous tween and re-anchors to `_hero_home`, so overlapping effects can never leave the hero drifted off its home position. A correct food also floats a rising `+nutrient` label (`fx.nutrient_popup`) whose text comes from `GameData.food_nutrient()` (the `FOOD_NUTRIENTS` map).

## Godot conventions & gotchas specific to this project

- **The food group is a bare string** `"Go"` / `"Glow"` / `"Grow"`, used three ways: dict key into `GameData.FOODS`, key into `GameData.group_color()`, and compared against a level's `correct_group`. Spelling must match exactly across `GameData`, scenes, and code.
- **Clicks/drag require care:** every interactive `Area2D` needs a `CollisionShape2D`, and any `ColorRect`/`Label` drawn over it (including the full-screen `Background`) must set `mouse_filter = 2` (Ignore) or it swallows the click before physics picking sees it. `Main._ready` also sets `get_viewport().physics_object_picking = true`.
- **Gray-box is intentional.** When the art phase comes, replace each `ColorRect` with a `Sprite2D` but keep node names and attached scripts identical so the contracts above keep working.
- **Commit Godot metadata:** `*.import` (e.g. `audio/*.wav.import`) and `*.uid` files must be committed alongside their source; `.godot/` is the cache and is gitignored. Opening the project in the editor re-saves `.tscn` files with added `uid`/`unique_id` fields — that's expected, don't revert it.
- GDScript is **tab-indented**. Keep the `config/features` version in `project.godot` aligned with the editor version (4.6).
