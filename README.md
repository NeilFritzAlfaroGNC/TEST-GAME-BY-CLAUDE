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

- From the menu, **Play** opens the **Level Select**: pick a **difficulty** (Easy / Medium / Hard) and a numbered **level**. (The grid also shows a locked **"Coming Soon"** slot reserved for future levels.)
- Each level asks you to feed the Hero one food group (e.g. *"Feed the Hero **Go** foods!"*).
- **Hunger Monsters** walk in from the left toward the Hero.
- Foods ride a **conveyor belt** along the bottom, sliding in from the left. Grab one before it **blinks and disappears** (each food lasts ~5s if untouched). New foods keep spawning at random.
- **Drag** a correct-group food off the belt onto the Hero:
  - **Correct** → the closest monster is defeated, points scored (×1 Easy / ×2 Medium / ×3 Hard), and a floating **+nutrient** popup shows what that food gives you (e.g. *+Vitamin C*, *+Protein*).
  - **Wrong** → a hint appears; the food rides back onto the belt to try again.
- A monster reaching the Hero costs a **life** (Easy 5 / Medium 3 / Hard 2).
- Every **5th level is a BOSS level**: fight through **3 waves** (each wave targets a different food group), then the **Boss** appears. Beat it by building a **balanced meal** — feed one **Go**, one **Grow**, and one **Glow** food (duplicates are rejected). The boss reaching the Hero costs a life and knocks it back to try again.
- Press **Esc** or the **Pause** button any time during a level to pause: Resume, Retry Level, Level Select, or Main Menu. Quitting mid-level records nothing — progress only saves on a win/lose result.
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
project.godot            Project settings + the three autoloads (DB, GameData, Audio)
Icon Game.png            App icon (the project icon set in project.godot)
icon.svg                 Old default Godot icon (no longer referenced)
TEST GAME BY CLAUDE.approj   Anchorpoint (asset-management tool) project config
scenes/
  MainMenu.tscn          Title screen (main scene)
  LevelSelect.tscn       Difficulty selector + numbered level grid
  Main.tscn              The game: Hero, food belt, HUD, Timer, lesson popup
  Enemy.tscn             Reusable Hunger Monster (spawned by Main)
  Food.tscn              Reusable conveyor-belt food (spawned by Main)
  ResultScreen.tscn      Stars + score, Next / Retry / Level Select / Menu
scripts/
  Database.gd            Autoload (DB): SQLite — scores & progress
  GameData.gd            Autoload: food database, levels, difficulties, run state
  Audio.gd               Autoload: SFX pool + looping music
  LevelSelect.gd         Builds the difficulty/level grid from DB progress
  Main.gd                One-level loop, waves/boss, food-belt spawning, scoring, win/lose
  PauseMenu.gd           Pause overlay (Esc / Pause button): Resume, Retry, quit out
  Food.gd                Conveyor-belt food: rides left→right, expires after 5s
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
| 7. SQLite save | ✅ `DB` autoload ([scripts/Database.gd](scripts/Database.gd)) stores **all scores AND progress** in **SQLite** — the high score and per-(difficulty, level) best score / stars / unlock state. |
| 8. Special attack effects | ✅ Go = **zap** (lightning bolt), Glow = **heal** (green pulse + ring), Grow = **slam** (shockwave + screen shake + hero lunge) |
| 5. Sound | ✅ Procedural SFX + looping music (correct / wrong / zap / heal / slam / click / win / lose / music) — generated, no downloads |
| 5. Art (sprites) | ⬜ Next step — colored boxes still in place on purpose (art last) |
| 9. Build & device testing | ⬜ Export Android `.apk` + Windows `.exe` |

## Data — SQLite save

The `DB` autoload ([scripts/Database.gd](scripts/Database.gd)) is the persistence layer.
It stores the **high score** and per-(difficulty, level) **best score / stars / unlock**
state. The high score is shown on the Main Menu, on the in-level HUD, and on the Result
screen. (There is no run-history / "recent scores" feature.)

Godot 4 has no built-in SQLite, so persistence uses the **godot-sqlite** GDExtension
(a native plugin, committed in `addons/godot-sqlite/` for Windows + Android). On
`_ready`, `DB` opens `user://foodheroes.db` (tables `meta`, `progress`).
If the extension is ever missing or the database cannot open, `DB` shows an error
alert and closes the game — a **runtime check that also works in release exports**
(an `assert` would be stripped there). The game requires SQLite; there is no fallback.

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
  show a real food **name** (e.g. *Fish*, *Rice*, *Mango*). Names are randomized
  each round from `GameData.FOODS`, and the belt always re-spawns any **needed**
  food group that's missing (on the next spawn tick, within about a second), so a
  level or boss fight can never become unwinnable.
- **Save** uses the `godot-sqlite` GDExtension to write `user://foodheroes.db`
  — fully offline, matching the reference's SQLite goal directly.
- The `Enemy.tscn` is already wired into `Main`'s **Enemy Scene** slot in the
  inspector, so no manual drag step is needed.

## Next steps (when you move to art)

1. Replace each `ColorRect` with a `Sprite2D` (keep the node names and scripts).
2. Export Android `.apk` (touch already works) and Windows `.exe`.

(Sound and the zap / heal / slam attack effects are already done — see the phase
table above.)
