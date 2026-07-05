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
- [ ] Re-save all scenes in the editor once so every `.tscn` gets its
      `uid`/`unique_id` fields (only `MainMenu.tscn` has them now).
      **Needs a manual pass in the editor UI** — a headless `--editor` launch
      doesn't do it AND leaves a zombie process that locks the sqlite DLL
      (documented in CLAUDE.md; don't retry that route).

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
- [ ] **Smoke-test script** (`tools/smoke_test.gd` + `tools/test.ps1`): headless
      asserts for star math, unlock chain, DB upsert, nutrient coverage,
      wave-group rules. One command = PASS/FAIL.
- [ ] **Split `Main.gd` (~600 lines)** into BeltManager + FxManager child nodes
      with `Main` as façade (details in RESTRUCTURE_PLAN.md Phase 2).
- [ ] **Instant needed-food respawn**: when the last food of a needed group is
      consumed or expires, spawn its replacement immediately instead of waiting
      up to 1s for the next tick — makes the "always one correct food on
      screen" claim literally true.
- [ ] **Audio polish**: let the same SFX overlap (small player pool) instead of
      cutting itself off on rapid correct/zap; add a **mute / volume toggle**
      (persist it in the existing `meta` table).
- [ ] **Boss visibility in UI**: "BOSS" badge on the level-5 tile in
      LevelSelect and a boss-flavored HUD title, so "Fruit Shield" isn't shown
      for a level that is actually 3 mixed waves + a boss.
- [ ] Deduplicate `_stars()` (LevelSelect vs ResultScreen) into one shared
      helper; fold `_spawn_food`'s inline group choice into
      `_choose_spawn_group`.
- [ ] Centralize screen-geometry constants (1152×648-coupled numbers scattered
      across `Main.gd` and `Food.gd`).
- [ ] **Android back button** should open/close the pause menu: handle
      `NOTIFICATION_WM_GO_BACK_REQUEST` in `PauseMenu.gd` (Esc/`ui_cancel`
      already works on desktop).
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
- [ ] **Tutorial level 0**: guided first drag with arrows and slowed enemies,
      teaching the three groups before level 1.
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
