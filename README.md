# Food Heroes (Godot 4)

An educational drag-and-drop game teaching the Filipino **Go · Glow · Grow**
food groups. Built as a gray-box prototype (colored boxes first, art last) per
the development reference.

## How to run

1. Open **Godot 4.6** (`C:\SHIZ\Godot_v4.6.3-stable_win64.exe`).
2. **Import** → select `D:\TEST\project.godot` → **Edit**.
3. Press **F5** (Play). The main scene is the Main Menu.

> Already validated headlessly on Godot 4.6.3 — all scenes load and run with no errors.

## How to play

- From the menu, **Play** opens the **Level Select**: pick a **difficulty** (Easy / Medium / Hard) and a numbered **level**.
- Each level asks you to feed the Hero one food group (e.g. *"Feed the Hero **Go** foods!"*).
- **Hunger Monsters** walk in from the left toward the Hero.
- **Drag** the correct-group food box onto the Hero:
  - **Correct** → the closest monster is defeated, points scored (×1 Easy / ×2 Medium / ×3 Hard).
  - **Wrong** → a hint appears, try again.
- A monster reaching the Hero costs a **life** (Easy 5 / Medium 3 / Hard 2).
- Clear all monsters → a **lesson popup**, then a results screen with **1–3 stars** (based on lives kept).
- Clearing a level **unlocks the next one** for that difficulty. Each difficulty is its own track.
- **All progress, stars, best scores, and the high score are saved in SQLite** (per difficulty + level) and persist between runs.

### Difficulty modifiers
| Difficulty | Lives | Monster speed | Spawn rate | Points |
|---|---|---|---|---|
| Easy | 5 | slow | slower | ×1 |
| Medium | 3 | normal | normal | ×2 |
| Hard | 2 | fast | faster | ×3 |

## Project structure

```
project.godot            Project settings + GameData autoload
icon.svg                 App icon
scenes/
  MainMenu.tscn          Title screen (main scene)
  LevelSelect.tscn       Difficulty selector + numbered level grid
  Main.tscn              The game: Hero, 3 Foods, HUD, Timer, lesson popup
  Enemy.tscn             Reusable Hunger Monster (spawned by Main)
  ResultScreen.tscn      Stars + score, Next / Retry / Level Select / Menu
scripts/
  Database.gd            Autoload (DB): SQLite (+ JSON fallback) — scores & progress
  GameData.gd            Autoload: food database, levels, difficulties, run state
  Audio.gd               Autoload: SFX pool + looping music
  LevelSelect.gd         Builds the difficulty/level grid from DB progress
  Main.gd                One-level loop, spawning, scoring, win/lose
  Food.gd                Drag-and-drop food box
  Enemy.gd               Walks toward the Hero
  MainMenu.gd            Menu buttons
  ResultScreen.gd        Stars, best score, navigation buttons
```

## How this maps to the development reference

| Reference phase | Status here |
|---|---|
| 2. Core gameplay (gray-box) | ✅ Hero, foods, drag-and-drop, correct/wrong |
| 3. Go-Glow-Grow data & logic | ✅ `GameData.FOODS` with real Filipino foods; level sets correct group |
| 4. Levels & lesson popups | ✅ 6 numbered levels, lives/lose, lesson popup per level |
| 6. Menus & UI | ✅ Main Menu, **Level Select (numbered + Easy/Medium/Hard)**, results with stars, score, lives, hint |
| 7. SQLite save | ✅ `DB` autoload ([scripts/Database.gd](scripts/Database.gd)) stores **all scores AND progress** in **SQLite** — high score, every run, and per-(difficulty, level) best score / stars / unlock state. Automatic **JSON fallback** if the native plugin is absent. See "Enabling SQLite" below. |
| 8. Special attack effects | ✅ Go = **zap** (lightning bolt), Glow = **heal** (green pulse + ring), Grow = **slam** (shockwave + screen shake + hero lunge) |
| 5. Sound | ✅ Procedural SFX + looping music (correct / wrong / zap / heal / slam / click / win / lose / music) — generated, no downloads |
| 5. Art (sprites) | ⬜ Next step — colored boxes still in place on purpose (art last) |
| 9. Build & device testing | ⬜ Export Android `.apk` + Windows `.exe` |

## Data — SQLite & offline save

The `DB` autoload ([scripts/Database.gd](scripts/Database.gd)) is the persistence layer.
It logs every finished run (`score`, `result`, `level_reached`, `played_at`) and the
high score, and the Result screen shows your recent scores.

- **With the SQLite plugin installed** → writes to `user://foodheroes.db` (tables `runs`, `meta`).
- **Without it** → automatically falls back to `user://foodheroes_save.json`. Same API, no code change. `DB.backend` reports which is active.

### Enabling real SQLite (optional)
Godot 4 has no built-in SQLite — it needs the **godot-sqlite** GDExtension (a native plugin):

1. Download `bin.zip` from https://github.com/2shady4u/godot-sqlite/releases (latest, e.g. `v4.7`).
2. Copy the `addons/godot-sqlite/` folder from the zip into this project's root (so you have `D:\TEST\addons\godot-sqlite\`). At minimum keep `godot-sqlite.gdextension` and the binaries for your platform (e.g. `bin/libgdsqlite.windows.*.x86_64.dll`).
3. Re-open the project in Godot. On the next run `DB.backend` becomes `"sqlite"` and it writes `foodheroes.db`.

> The native binary is **not** committed to this repo on purpose (platform-specific, large). It's a drop-in — no code changes needed.

## Sound

All sounds are generated locally by [`tools/generate_audio.py`](tools/generate_audio.py)
(pure Python standard library — no assets to download) into `audio/*.wav`, and
played through the `Audio` autoload ([scripts/Audio.gd](scripts/Audio.gd)).
Re-run `python tools/generate_audio.py` any time to tweak/regenerate them.

## Special attack effects

When the correct food defeats a monster, the Hero plays the attack that matches
the level's group (built procedurally in [scripts/Main.gd](scripts/Main.gd), no art needed):

- **Go = Zap** — a jagged yellow lightning bolt from the Hero to the monster.
- **Glow = Heal** — the Hero flashes green with an expanding healing ring.
- **Grow = Slam** — an orange shockwave, a camera **screen-shake**, and the Hero lunges.

## Design notes / choices made

- **Foods are color-coded** by group (Go = yellow, Glow = green, Grow = red) and
  show a real food **name** (e.g. *Isda*, *Kanin*, *Mangga*). Names are randomized
  each round from `GameData.FOODS`, and the game guarantees at least one correct
  food is always on screen so a level is always solvable.
- **Save** uses Godot's built-in `FileAccess` + `JSON` to `user://foodheroes_save.json`
  — fully offline and needs no extra plugin (the reference's SQLite goal, made portable).
- The `Enemy.tscn` is already wired into `Main`'s **Enemy Scene** slot in the
  inspector, so no manual drag step is needed.

## Next steps (when you move to art & sound)

1. Replace each `ColorRect` with a `Sprite2D` (keep the node names and scripts).
2. Add an `AudioStreamPlayer` for music and SFX (correct / wrong / attack).
3. Add the Go = zap / Glow = heal / Grow = slam attack effects.
4. Export Android `.apk` (touch already works) and Windows `.exe`.
