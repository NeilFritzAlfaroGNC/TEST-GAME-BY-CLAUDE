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

- Each level asks you to feed the Hero one food group (e.g. *"Feed the Hero **Go** foods!"*).
- **Hunger Monsters** walk in from the left toward the Hero.
- **Drag** the correct-group food box onto the Hero:
  - **Correct** → the closest monster is defeated, +10 points.
  - **Wrong** → a hint appears, try again.
- A monster reaching the Hero costs a **life** (you have 3).
- Clear all monsters in a level → a **lesson popup** appears → continue.
- Beat all 3 levels = **You Win**. Lose all lives = **Game Over**.
- High score is saved offline between runs.

## Project structure

```
project.godot            Project settings + GameData autoload
icon.svg                 App icon
scenes/
  MainMenu.tscn          Title screen (main scene)
  Main.tscn              The game: Hero, 3 Foods, HUD, Timer, lesson popup
  Enemy.tscn             Reusable Hunger Monster (spawned by Main)
  ResultScreen.tscn      Win / Game Over / final score
scripts/
  GameData.gd            Autoload: food database, levels, save/load (offline)
  Main.gd                Level loop, spawning, scoring, win/lose
  Food.gd                Drag-and-drop food box
  Enemy.gd               Walks toward the Hero
  MainMenu.gd            Menu buttons
  ResultScreen.gd        Result screen buttons
```

## How this maps to the development reference

| Reference phase | Status here |
|---|---|
| 2. Core gameplay (gray-box) | ✅ Hero, foods, drag-and-drop, correct/wrong |
| 3. Go-Glow-Grow data & logic | ✅ `GameData.FOODS` with real Filipino foods; level sets correct group |
| 4. Levels & lesson popups | ✅ 3 levels, lives/lose, multiple enemies, lesson popup per level |
| 6. Menus & UI | ✅ Main Menu, Win/Lose, score, lives, hint |
| 7. SQLite save | ✅ Implemented offline with FileAccess + JSON (high score). Swap in the `godot-sqlite` plugin later if the study requires SQLite specifically. |
| 5. Art & sound, 8. Effects, 9. Build | ⬜ Next steps — colored boxes are deliberately still in place |

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
