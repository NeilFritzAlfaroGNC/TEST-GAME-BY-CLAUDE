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

Headless cannot simulate mouse drag — to verify gameplay feel (drag, zap/heal/slam, sound) open the project and press **F5**.

## Regenerating audio

All sound is synthesized locally — there are **no downloaded assets**. To change a sound, edit and re-run the generator (pure Python stdlib), then re-import:
```powershell
python tools/generate_audio.py     # writes audio/*.wav
```

## Architecture (the big picture)

**Three autoloads hold everything that must outlive a scene change** (registered in `project.godot`, in this init order):
- `DB` (`scripts/Database.gd`) — persistence layer. Primary backend is **SQLite** via the `godot-sqlite` GDExtension; if that native plugin isn't installed it **transparently falls back to JSON** (`user://foodheroes_save.json`). The `SQLite` class is reached by string (`ClassDB.instantiate("SQLite")`) on purpose, so the script parses/runs with or without the plugin. Exposes `record_run`, `get_high_score`, `get_recent_runs`. Must load **before** `GameData` (which calls it on `_ready`).
- `GameData` (`scripts/GameData.gd`) — the food database (`FOODS` by group), `LEVELS` definitions, and the **live run state** (`current_level`, `score`, `lives`, `last_result`). Run state lives here, *not* in the game scene, precisely so it survives `change_scene_to_file`. `save_game`/`load_game` are thin delegates to `DB`.
- `Audio` (`scripts/Audio.gd`) — one-shot SFX pool + looping music, all null-guarded so missing files never crash the game.

**Enabling real SQLite:** drop the `godot-sqlite` addon into `addons/godot-sqlite/` (the `.gdextension` + the platform binary), re-open the project, and `DB.backend` becomes `"sqlite"` automatically — no code change. Until then it logs to JSON. The native binary is intentionally **not** committed.

**Scene flow:** `MainMenu.tscn` → `Main.tscn` (gameplay) → `ResultScreen.tscn` → back. `ResultScreen` decides win vs. lose by reading `GameData.last_result`.

**`Main.gd` is the orchestrator** and implements the dev-reference loop: a FOR over `GameData.LEVELS` (advanced via `current_level`) and a WHILE over enemies within a level. The teaching moment is the right-vs-wrong food check in `food_dropped_on_hero`.

**Cross-script contract (important when renaming or restructuring):**
- `Food.gd` and `Enemy.gd` reach the controller via `get_tree().current_scene` and call `food_dropped_on_hero(self)` / `enemy_reached_hero(self)`. This only works because **`Main` is the active scene** and exposes those methods.
- Both also locate the hero with `current_scene.get_node("Hero")`, so the hero **must remain a direct child of `Main` named exactly `Hero`**.
- These cross-node calls pass **untyped** params on purpose — typing them (e.g. `food: Node`) would make GDScript's static checker reject `food.food_group` / `food.label`.

**Enemy lifecycle:** spawned enemies are added to the `"enemies"` group. `Main` finds/defeats the closest one and detects level completion by checking `enemies_to_spawn <= 0 and group "enemies" is empty`. `_despawn_enemy` removes from the group *before* `queue_free` so the count is accurate the same frame.

**Solvability invariant:** the three food boxes are assigned groups by `Main` (`_refresh_all_foods` / `_refresh_one_food`), which always guarantees **at least one food matches the level's `correct_group`** — never edit food assignment without preserving this, or a level can become unwinnable.

**Special attack effects (`Main.gd`)** are fully procedural (no assets): Go = `Line2D` lightning (`_effect_zap`), Glow = green pulse + expanding ring (`_effect_heal`), Grow = shockwave + camera shake + hero lunge (`_effect_slam`). The shake is driven by the `Camera2D` in `Main.tscn` via `_process`.

## Godot conventions & gotchas specific to this project

- **The food group is a bare string** `"Go"` / `"Glow"` / `"Grow"`, used three ways: dict key into `GameData.FOODS`, key into `GameData.group_color()`, and compared against a level's `correct_group`. Spelling must match exactly across `GameData`, scenes, and code.
- **Clicks/drag require care:** every interactive `Area2D` needs a `CollisionShape2D`, and any `ColorRect`/`Label` drawn over it (including the full-screen `Background`) must set `mouse_filter = 2` (Ignore) or it swallows the click before physics picking sees it. `Main._ready` also sets `get_viewport().physics_object_picking = true`.
- **Gray-box is intentional.** When the art phase comes, replace each `ColorRect` with a `Sprite2D` but keep node names and attached scripts identical so the contracts above keep working.
- **Commit Godot metadata:** `*.import` (e.g. `audio/*.wav.import`) and `*.uid` files must be committed alongside their source; `.godot/` is the cache and is gitignored. Opening the project in the editor re-saves `.tscn` files with added `uid`/`unique_id` fields — that's expected, don't revert it.
- GDScript is **tab-indented**. Keep the `config/features` version in `project.godot` aligned with the editor version (4.6).
