# Food Heroes — TODO: Recommendations & Possible Features

Companion to [RESTRUCTURE_PLAN.md](RESTRUCTURE_PLAN.md). Items are grouped and
roughly ordered by value-for-effort. Nothing here removes or changes an
existing feature.

## Fixes / hardening (from the findings — highest priority)

- [x] **Release-safe DB failure**: replaced `assert`s in `Database.gd` with
	  runtime checks (`_fail()`: `push_error` + `OS.alert` + quit); all query
	  helpers guard `_db == null`; every query's return value is checked and
      logged via the `_exec` / `_exec_bound` helpers.
- [x] **Fix hero drift from stacked slam tweens** in `Main.gd` — slam/heal
      tweens are now single-flight (`_hero_move_tween` / `_hero_tint_tween`),
      killed and re-anchored to `_hero_home` on each new effect.
- [x] **Guard the boss-invalid state** in `food_dropped_on_hero` — a missing
      boss while `_boss_active` now keeps the food on the belt instead of
      falling through to the stale wave check.
- [x] **Symmetric cleanup**: shared `_stop_level()` now used by both
      `_level_complete` and `_game_over` (timers + `_clear_foods`).
- [x] **Sync README.md**: boss levels/waves/balanced meal, nutrient popups,
      Coming Soon tile, pause menu, fixed "Next steps", corrected the autoload
      description, `.approj` noted. (CLAUDE.md DB/pause sections synced too.)
- [x] Deleted the `~libgdsqlite…TMP` leftovers in `addons/godot-sqlite/bin/`.
      **Learned since**: these regenerate whenever a Godot instance is
	  force-killed — they're godot-sqlite's copy-on-load leftovers, already
      gitignored via `*.TMP`, and always safe to delete (see the new
      headless-editor warning in CLAUDE.md).
- [x] Re-save all scenes in the editor once so every `.tscn` gets its
      `uid`/`unique_id` fields — **done via a manual editor pass** (all six
      scenes now carry uid headers). Reminder: a headless `--editor` launch
	  can't do this AND leaves a zombie process that locks the sqlite DLL
	  (documented in CLAUDE.md).

## Round 2 fixes (post-review re-read — done)

- [x] **Pause-while-dragging exploit/glitch**: pausing mid-drag then releasing
	  the mouse used to complete the drop on resume (could silently feed the
	  Hero). `Food.cancel_drag()` now returns any held food to the belt the
	  moment the game pauses (`PauseMenu._pause`).
- [x] **`_needed_groups()` aliasing hazard**: during a boss it returned the
	  live `_meal_needed` array by reference; now returns a duplicate so no
	  future caller can corrupt the boss meal state.
- [x] **Game icon**: `Icon Game.png` committed and set as the project icon in
	  `project.godot`; README structure list updated (`icon.svg` is now the
	  unused old default).
- [x] **CLAUDE.md**: documented the headless `--editor` zombie-process trap
	  and the regenerating `~*.TMP` files so future sessions don't rediscover
	  them the hard way.

## Recommended improvements (quality / maintainability)

- [x] **Pause / quit-to-menu** during a level — `scripts/PauseMenu.gd` +
	  `PausePopup` overlay in `Main.tscn`: Esc or the HUD Pause button pauses
	  the tree (enemies/timers/belt freeze); Resume, Retry Level, Level Select,
	  and Main Menu buttons. The `Audio` autoload now runs `PROCESS_MODE_ALWAYS`
	  so music keeps playing and clicks stay audible while paused.
- [x] **Smoke-test script** — `tools/smoke_test.gd` (star math per difficulty,
	  boss cadence, level clamping, nutrient coverage, difficulty tables, DB
	  unlock chain + upsert + settings against a throwaway db) and
	  `tools/test.ps1` (import + smoke test + headless scene runs, PASS/FAIL).
- [x] **Split `Main.gd`** — now a ~380-line façade over two code-created child
	  components: `scripts/BeltManager.gd` ("Belt": spawning, stacking layout,
	  visuals, solvability) and `scripts/FxManager.gd` ("Fx": zap/heal/slam,
	  shake, nutrient popups). All external contracts unchanged
	  (`food_dropped_on_hero`, `enemy_reached_hero`, `Hero`, `foods_container`).
- [x] **Instant needed-food respawn** — `BeltManager._ensure_needed()` runs
	  every frame and cap-free spawns any missing needed group, so a usable
	  food is now literally always on screen (was: up to 1s gap).
- [x] **Audio polish** — per-SFX voice pool (`MAX_VOICES_PER_SFX = 4`) so rapid
	  repeats overlap; **Sound ON/OFF toggle** on the Main Menu, persisted via
	  the new `DB.get_setting_int`/`set_setting_int` (meta table).
- [x] **Boss visibility in UI** — LevelSelect badges boss tiles ("BOSS n",
	  purple tint); the in-level HUD shows "BOSS: Balanced Meal" instead of the
	  unused "Fruit Shield" row name, and the target label turns boss-purple
	  during the boss fight.
- [x] Deduplicated stars: shared `GameData.stars_text()` used by LevelSelect
	  and ResultScreen; the belt group choice lives once in
	  `BeltManager._choose_group()`.
- [x] Centralized screen geometry: `GameData.DESIGN_SIZE` / `BELT_TOP` /
	  `BELT_Y` shared by BeltManager and Food.gd.
- [x] **Android back button** opens/closes the pause menu
	  (`NOTIFICATION_WM_GO_BACK_REQUEST` in `PauseMenu.gd`).
- [ ] **Export presets with the new icon**: Windows `.exe` icon needs an `.ico`
	  + rcedit configured in the export preset; Android needs the adaptive
	  icon set. (`Icon Game.png` only covers the editor/project icon today.)
- [ ] Delete `icon.svg` (+ its `.import`/`.uid`) if the old default icon is
	  truly not wanted anywhere anymore — nothing references it now.

## Possible features (future content — none started)

- [ ] **More levels (7–10)** so the every-5th boss rule yields a second boss at
	  level 10; replace the "Coming Soon" tile with the real thing. Ideas:
	  mixed-group levels ("feed Go OR Grow"), a speed round, a "no wrong
	  answers allowed" perfect round.
- [x] **Tutorial level + How to Play screen** — first-ever Play launches a
	  guided tutorial (4 intro pages via the lesson popup, then 3 extra-slow
	  GO monsters, 5 lives; nothing recorded; completion sets the persisted
	  `tutorial_done` flag). New `HowToPlay.tscn` from the menu explains the
	  rules and can replay the tutorial any time.
- [ ] **Language toggle (English ⇄ Filipino)** for food names — the git history
	  shows names were translated *to* English; a toggle keeps both audiences
	  (`FOODS` keyed once, display names per locale).
- [ ] **Colorblind support**: add a shape/icon per group (e.g. bolt / leaf /
	  muscle) alongside the yellow/green/red coding — cheap now while
	  everything is still gray-box.
- [ ] **Streak / combo scoring**: consecutive correct feeds multiply points;
	  a wrong food resets the streak. Pairs naturally with the existing
	  per-difficulty score multiplier.
- [ ] **Time-based star bonus** or "no lives lost" medal per level, stored in
	  the existing `progress` table (add a column, keep the upsert pattern).
- [ ] **Boss variety**: a second boss type at level 10 — e.g. "Junk Food King"
	  that must be countered with specific nutrient popups, or a boss that
	  periodically steals a belt food.
- [ ] **Win/lose flourish**: confetti on 3 stars, hero sad-pose on game over
	  (procedural, consistent with the gray-box "art last" rule).
- [ ] **Android export pass**: export preset, touch-target sizing check
	  (foods are 150×90 — fine), and on-device drag test. Windows `.exe`
	  export preset too (README phase 9 is still open).
- [ ] **Art phase** (per CLAUDE.md: swap `ColorRect` → `Sprite2D`, keep node
	  names/scripts): hero, monsters, boss, per-food sprites, belt texture.
- [ ] **Per-difficulty stats screen**: total stars per track, e.g. "Easy
	  14/18 ★" on LevelSelect — all data already lives in `progress`.
- [ ] **Settings scene**: volume sliders (music/SFX), language, colorblind
	  icons toggle — persisted in `meta`.
