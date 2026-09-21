# Food Heroes — Rebuild Design

**Date:** 2026-09-21
**Status:** Draft, awaiting review
**Supersedes:** the gray-box prototype in `scripts/` (levels, waves, boss, tutorial)

---

## 1. Why

Food Heroes teaches the Filipino Go / Glow / Grow food groups. Two problems make the
current build unfit for that purpose and for phones.

**The game can be won without reading.** `GameData.group_color()` paints every food box by
its group, and `Main._update_hud()` colours the instruction label with that same colour:

```gdscript
target_label.text = "Feed the Hero  %s  foods!" % correct_group
target_label.add_theme_color_override("font_color", GameData.group_color(correct_group))
```

A player matches the yellow label to the yellow box. The question the game exists to ask —
*"is Rice a Go food?"* — never gets asked. Three further faults compound it:

| Fault | Location | Effect |
|---|---|---|
| Wrong answers are free | `Main.food_dropped_on_hero` | Guessing is optimal play |
| One `correct_group` per level | `Main.correct_group` | ~1 classification decision per level, not ~40 |
| 6 levels, one boss | `LEVELS`, `BOSS_EVERY := 5` | ~10 minutes of content |
| `LEVELS[4]` lesson unreachable | boss overrides level 5 | "Fruit Shield" text never shown |

**The layout only works at exactly 16:9.** Positions are hardcoded across four files
(`Hero` at `Vector2(920, 320)` in `Main.tscn`, `STACK_FRONT_X := 1040.0` in `BeltManager`,
spawn `Vector2(120, ...)` in `Main.gd`, `BELT_Y := 600.0` in `GameData`). With
`stretch/aspect="expand"` a 20:9 phone reveals 1440 design units of width while the Hero
stays pinned at 920 and the conveyor stops at 1040.

## 2. Decisions taken

| Question | Decision |
|---|---|
| Audience | School-age 9–12; learning must be real and demonstrable |
| Scope | Full rebuild of scripts and scenes |
| Orientation | **Landscape only.** No portrait mode. |
| Resolution | Single anchored layout spanning 16:9 → 21:9, with safe-area insets |

### Carried over unchanged

- `GameData.FOODS` and `GameData.FOOD_NUTRIENTS` (28 foods, nutrient map)
- The SQLite layer (`scripts/Database.gd`) and the committed `addons/godot-sqlite`
- All synthesized audio and `tools/generate_audio.py`
- The Kenney UI theme (`assets/ui/menu_theme.tres`) and themed menu scenes
- `FxManager` procedural effects, de-hardcoded
- The belt solvability invariant (see 4.4)

### Non-goals

Portrait support. New in-game art (gray-box continues; UI theming stays as-is).
Online or multiplayer. Run history — the `runs` table stays dropped.

## 3. Gameplay model

### 3.1 Per-monster weakness

Each Hunger Monster spawns carrying its own weakness instead of the level carrying one
`correct_group`. The player reads the monster, finds a matching food, drags it to the Hero,
and the Hero strikes **that** monster.

This moves the game from one classification decision per level to one per monster —
roughly 40 per level. It is the central change; everything else supports it.

Targeting changes accordingly: the old `defeat_closest_enemy()` becomes
`defeat_matching_enemy(group)`, which resolves to the **closest monster whose weakness
matches the fed food**. If no on-screen monster matches, the feed is rejected as wrong.

A feed is therefore wrong in exactly two cases — the food's group matches no on-screen
monster, or the player drops it while no monster is present. Both take the identical path:
stun (3.4), streak reset (3.5), and an accuracy record against the fed food's group (3.6).
There is no third, softer outcome.

### 3.2 Difficulty is the teaching ladder

`DIFFICULTIES` gains two keys that make the tiers mechanically different rather than
merely faster:

| Tier | `monster_label` | `show_food_color` | lives | speed | spawn | score |
|---|---|---|---|---|---|---|
| Easy | `"group"` | `true` | 5 | 0.70 | 1.30 | x1 |
| Medium | `"group"` | `false` | 3 | 1.00 | 1.00 | x2 |
| Hard | `"nutrient"` | `false` | 2 | 1.40 | 0.70 | x3 |

Easy keeps the colour crutch for players who need it. Medium removes it and asks which
foods belong to which group. Hard asks for the nutrient, using the existing
`FOOD_NUTRIENTS` data.

### 3.3 The nutrient tier has a data problem

Hard mode requires a nutrient to imply exactly one group. Most do not. Derived from
`FOOD_NUTRIENTS`:

| Nutrient | Groups carrying it | Usable in Hard mode |
|---|---|---|
| Carbs | Go | yes |
| Fiber | Go | yes |
| Energy | Go | yes |
| Vitamin C | Glow | yes |
| Potassium | Glow | yes |
| Protein | Grow | yes |
| **Vitamin A** | Go + Glow | no |
| **Iron** | Glow + Grow | no |
| **Calcium** | Glow + Grow | no |

A new `NUTRIENT_GROUPS` constant holds only the unambiguous six. Grow contributes just
`Protein`, so an all-nutrient Hard mode would repeat it constantly. **Hard therefore mixes
nutrient requests with group requests at roughly 50/50.**

A test asserts every entry in `NUTRIENT_GROUPS` resolves to exactly one group, so adding a
food later cannot silently make a Hard-mode request unanswerable.

### 3.4 Wrong answers cost time

A wrong food stuns the Hero for **1.0s** — no feeding while stunned, monsters keep
advancing. No life is lost. Guessing stops being optimal the moment it is slower than
thinking, without being punitive for a child.

### 3.5 Streak multiplier

`streak_mult = 1 + floor(streak / 5)`, capped at **5**. A correct feed increments the
streak; a wrong feed resets it to 0.

```
points = 10 * difficulty.score_mult * streak_mult
```

Score now reflects accuracy rather than mere survival.

### 3.6 Per-group accuracy

Every feed records correct/wrong against its group. The Result screen reports:

> Go 95%  ·  Glow 78%  ·  Grow 52% — practise your Grow foods!

This closes the teaching loop and produces evidence of learning rather than a score.

### 3.7 Content

15 levels, boss at 5 / 10 / 15. The "Fruit Shield" lesson currently buried under the boss
override gets its own non-boss level. Boss fights keep the balanced-meal mechanic
(one Go + one Grow + one Glow) and `BOSS_LESSON` unchanged.

## 4. Layout architecture

### 4.1 The `Layout` autoload

A new autoload owns every position, derived from the live viewport and safe area. No other
file hardcodes a coordinate.

```
hero_x        = safe.end.x      - 232
stack_front_x = safe.end.x      - 112
spawn_x       = safe.position.x - 80
belt_y        = safe.end.y      - 88
belt_top      = belt_y          - 48
lane_top      = safe.position.y + hud_h + 24
lane_bottom   = belt_top        - 24
```

It emits `changed` on resize so the belt, Hero and lanes re-anchor.

### 4.2 `Layout` is a pure function

`Layout` computes from exactly two inputs — `viewport_size` and `safe_area_rect` — and
reads no engine state. This is the load-bearing decision: it makes the layout testable
headlessly at every shipped aspect, without a device.

```
1152x648 (16:9)   1404x648 (19.5:9)   1440x648 (20:9)   1512x648 (21:9)
```

Assertions: Hero on-screen at every aspect; belt clears the bottom inset; `lane_top <
lane_bottom`; stack front never left of entry.

### 4.3 Safe areas

`DisplayServer.get_display_safe_area()` returns **physical screen pixels**, not design
units, and must be divided by the stretch scale before use. On desktop it returns the full
rect, so it is meaningful only on device.

**This cannot be verified from the development machine.** `tools/test.ps1` runs headless on
Windows and will always see the desktop rect. The conversion math is unit-tested against
synthetic insets; whether the belt actually clears the iOS home indicator and the Android
gesture bar must be confirmed on hardware. The inset is a single tunable constant for that
reason.

The belt currently occupies the bottom 96px (`BELT_TOP 552` + `BELT_H 96` against a 648
design height) — flush with the edge where both platforms put their system gesture strip,
and where every drag in the game begins. Lifting it is the single most important
phone-correctness fix.

### 4.4 Extra width is spacing, not advantage

A 20:9 phone reveals 1440 units against 1152 — room for two more foods. `MAX_FOODS` stays
fixed at **6** regardless of device: a school with mixed phones must not have students
playing measurably different difficulties. The surplus goes to spacing:

```
spacing = clamp((stack_front_x - safe.position.x) / MAX_FOODS, 185, 230)
```

Yielding 185 at 16:9, 221 at 20:9, 230 at 21:9.

**The solvability invariant is preserved.** `BeltManager._ensure_needed()` runs every frame
and spawns, cap-free, a food for any needed group missing from the belt. `_needed_groups()`
becomes "the set of weaknesses currently on screen" (or the still-missing meal groups during
a boss). Removing this makes levels unwinnable.

### 4.5 Touch targets

On a 6.1" phone the screen's long edge is roughly 141mm carrying ~1404 design units, so one
unit is about 0.1mm. A 150-unit food box lands near **15mm**, comfortably above the ~9mm
minimum both platforms recommend. No resizing required.

### 4.6 Project settings

Verified against Godot 4.6.3 by querying `ProjectSettings` in a headless run:

- `display/window/handheld/orientation` — an **integer enum**, not a string. It already
  resolves to `0` (landscape), which is the engine default, so the build is landscape-locked
  on handheld today. Set it explicitly in `project.godot` to document the intent.
- `display/window/size/viewport_width` already reports `1152`; pair it with an explicit
  `viewport_height = 648`.
- `display/window/stretch/aspect` already reports `expand`; `stretch/mode` stays
  `canvas_items`. Both unchanged.

## 5. Scene and script architecture

`Main.gd` is 473 lines running the level machine, wave machine, boss fight, scoring,
tutorial and HUD. The rebuild splits it:

| Script | Owns |
|---|---|
| `Game.gd` | thin orchestrator; the cross-script contract surface |
| `WaveDirector.gd` | level / wave / boss state machine |
| `ScoreKeeper.gd` | score, streak multiplier, per-group accuracy |
| `HudController.gd` | all HUD text and colour |
| `BeltManager.gd` | conveyor (carried over, de-hardcoded) |
| `FxManager.gd` | procedural effects (carried over) |

Scene flow is unchanged: `MainMenu` → `LevelSelect` → `Game` → `Result`, plus `HowToPlay`.

### 5.1 The fragile contract is removed

Today `Food.gd` and `Enemy.gd` reach the controller via `get_tree().current_scene` and find
the hero with `current_scene.get_node("Hero")`. This works only while `Main` is the active
scene and the hero is named exactly `Hero`; renaming either breaks it silently at runtime,
and it forces the untyped-parameter workaround documented in CLAUDE.md.

The spawner now **injects** the references a food or enemy needs at creation. No global
lookups, no name dependency, and parameters can be typed.

### 5.2 Autoload order

`Layout` → `DB` → `GameData` → `Audio`. `Layout` depends on nothing. `GameData` still calls
`DB` in `_ready()`, so that existing constraint holds.

### 5.3 Systems that must be re-implemented, not inherited

A from-scratch rebuild drops working code. These are re-implemented deliberately, and the
plan must carry a task for each:

- First-run tutorial (`tutorial_mode`, `TUTORIAL_PAGES`, the paged lesson popup)
- Pause overlay with `process_mode = ALWAYS` and unpause-before-scene-change
- Boss fight: waves, balanced meal, `_meal_needed` tracking
- Level unlock chain, per difficulty
- Mute toggle persisted through `DB.get_setting_int`

## 6. Data model

`progress` and `meta` are unchanged; levels 1–6 of existing saves stay valid as the table
grows to 15, and the unlock chain is untouched. No migration needed.

One new table, created on open beside the others:

```sql
accuracy(difficulty TEXT, group TEXT, correct INT, wrong INT,
         PRIMARY KEY(difficulty, group))
```

Accessed through `DB.record_answer(difficulty, group, was_correct)` and
`DB.get_accuracy(difficulty)`. Both follow existing practice: guard `_db == null`, check
every query return, `push_error` on failure, return safe defaults.

## 7. Testing

`tools/test.ps1` stays the standard check. `tools/smoke_test.gd` gains:

- `Layout` geometry at all four aspects (4.2)
- Safe-area conversion against synthetic insets
- Streak multiplier math including the cap
- `NUTRIENT_GROUPS` unambiguity (3.3)
- Accuracy table upsert and percentage math, against the throwaway `user://smoke_test.db`

Headless cannot simulate drag, so feel — drag, stun, zap/heal/slam, sound — is verified by
opening the project and pressing F5. Safe areas require a device build (4.3).

## 8. Open dials

Deliberately left tunable; both were flagged during design and neither blocks
implementation:

1. **Stun duration (1.0s).** The only mechanic that punishes a child directly. May be too
   harsh or too slight for 9–12.
2. **Hard-mode nutrient tier.** May work better as an optional challenge or a post-15
   unlock than as the standard Hard difficulty, given the Grow/Protein thinness in 3.3.

## 9. Risks

| Risk | Mitigation |
|---|---|
| Safe-area insets unverifiable on dev machine | Single tunable constant; device build required before release |
| Rebuild silently drops a working system | 5.3 enumerates them; plan carries a task each |
| Per-monster weakness makes levels unwinnable | Solvability invariant preserved (4.4) and tested |
