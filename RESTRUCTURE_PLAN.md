# Food Heroes — Restructure Plan

Produced from a full trace of the codebase (all 8 game scripts, all 6 scenes,
`project.godot`, the sqlite addon, audio assets) cross-referenced against
`CLAUDE.md` and `README.md`. **No code has been changed yet** — this document is
findings + plan only.

---

## SECTION 1 — FINDINGS

### 1.1 Architecture as actually implemented (verified)

The big picture in CLAUDE.md is accurate. Verified end-to-end:

- **Autoloads** in `project.godot` in the documented order: `DB`
  (`scripts/Database.gd`) → `GameData` (`scripts/GameData.gd`) → `Audio`
  (`scripts/Audio.gd`). `GameData._ready()` reads `DB.get_high_score()`, so the
  ordering is load-bearing and correct.
- **Scene flow**: `MainMenu.tscn` → `LevelSelect.tscn` → `Main.tscn` →
  `ResultScreen.tscn` → (Next / Retry / Level Select / Menu). All button
  connections and node paths referenced from scripts exist in the `.tscn` files.
- **Persistence**: SQLite-only via `godot-sqlite` GDExtension; binaries for
  Windows, Android, Linux, macOS, iOS, and web are committed in
  `addons/godot-sqlite/bin/`. Tables `meta` + `progress`; legacy `runs` table
  dropped on open. `record_level_result`, `get_level_progress`,
  `is_level_unlocked`, `get_high_score` all present and used.
- **Cross-script contract** holds: `Food.gd` and `Enemy.gd` reach the controller
  via `get_tree().current_scene`, call `food_dropped_on_hero(self)` /
  `enemy_reached_hero(self)` with untyped params, and locate the hero via
  `get_node("Hero")` (Food uses `get_node_or_null` + `overlaps_area`). `Hero` is
  a direct child of `Main` with a `CollisionShape2D`; all overlay
  `ColorRect`/`Label` nodes set `mouse_filter = 2`.
- **Enemy lifecycle**: `_despawn_enemy` removes from the `"enemies"` group
  before `queue_free`, then `_check_level_complete.call_deferred()` drives the
  state machine (next wave → boss → level complete) exactly as documented.
- **Boss levels**: `GameData.is_boss_level` (every 5th → only level 5 of the
  current 6), 3 waves of `BOSS_WAVE_SIZE + enemy_bonus` enemies, then a 2.2×
  scaled Enemy in the `"boss"` group beaten by feeding one food from each of
  Go/Grow/Glow (`_meal_needed`). Boss reaching the hero costs a life + knockback
  (`reached` reset). All as documented.
- **Conveyor belt**: spawn 1–2 foods per 1s tick into `$Foods`, right-anchored
  stacking via per-frame `_layout_belt()`, 5s lifetime with blink from 3.5s,
  drag pauses age, `food_dropped_on_hero` returns `bool`. The solvability guard
  (`_needed_groups` / `_missing_needed_group`) always spawns a missing needed
  group, even when the belt is at `MAX_FOODS`. All as documented.
- **Effects**: procedural zap / heal / slam + ring, camera shake via `_process`,
  `+nutrient` popup from `GameData.FOOD_NUTRIENTS`. Every food name in `FOODS`
  has a matching key in `FOOD_NUTRIENTS` (verified all 28).
- **Audio**: all 9 referenced streams (`click, correct, wrong, zap, heal, slam,
  win, lose, music`) exist as generated `.wav` + committed `.import` files.

### 1.2 Documented but diverging / not found

1. **"Fails loudly" DB guarantee is debug-only — the most important finding.**
   CLAUDE.md and README say that if the SQLite extension is missing,
   `DB._open()` "asserts and the game will not start… fails loudly instead of
   silently degrading." But `assert()` statements are **compiled out of release
   export builds** in Godot. In an exported game with a broken/missing
   extension, `ClassDB.instantiate("SQLite")` returns `null` and the very next
   line (`inst.path = …`) is a null-instance crash — and `open_db()` failure
   would be silently ignored (`ok` unused in release), leaving `_db` set to a
   half-open instance whose queries fail quietly. The documented intent
   (controlled loud failure in *all* builds) is not what the code does.
2. **README.md is significantly stale.** It documents no part of the boss
   system (waves, the balanced-meal boss, `BOSS_LESSON`), no nutrient popups,
   and no "Coming Soon" level tile. Its "Next steps" list still says to *add*
   sound and the zap/heal/slam effects, while its own phase table marks both ✅
   done. It also says `project.godot` holds "the GameData autoload" (there are
   three autoloads).
3. **README overstates the solvability invariant**: "the game guarantees at
   least one correct food is always on screen." The real guarantee is eventual:
   after the last needed-group food is consumed or expires, the belt can lack
   that group for up to one spawn tick (`FOOD_SPAWN_INTERVAL` = 1s). Never
   unwinnable, but not "always on screen."
4. **CLAUDE.md wave description is slightly imprecise**: "wave 1 = Go, then
   random." Actually wave 2 is constrained to a coin-flip of Glow/Grow
   (guaranteeing wave 2 differs from wave 1), and only wave 3+ is fully random
   (`Main._build_wave_groups`).
5. **Level 5's static data is silently dead.** `LEVELS[4]` ("Fruit Shield",
   Glow, 6 enemies, a fruit lesson) is a boss level, so its `correct_group`,
   `enemies`, and `lesson` are all ignored — but its *name* still shows in the
   HUD ("Level 5: Fruit Shield") while the gameplay is 3 mixed waves + a boss.
   Nothing in LevelSelect marks level 5 as a boss level either.

### 1.3 Implemented but not documented

6. **LevelSelect "Coming Soon" tile** (`LevelSelect.gd:71-77`): a permanently
   disabled 7th slot shown on every difficulty. In neither CLAUDE.md nor
   README.
7. **`TEST GAME BY CLAUDE.approj`** at the repo root is an Anchorpoint
   (cloud.anchorpoint.app) project config — legitimate, but unexplained in any
   doc.
8. **Scene-file inconsistency**: only `MainMenu.tscn` has been re-saved by the
   editor with `uid` / `unique_id` fields; the other five scenes still use the
   pre-editor format. CLAUDE.md says the re-saved form is the expected end
   state.
9. **Leftover temp files**: two `~libgdsqlite.windows…~RF….TMP` files sit in
   `addons/godot-sqlite/bin/` (Windows rename leftovers, dead weight).

### 1.4 Fragile or edge-broken flows

10. **No null/failure guards anywhere in `Database.gd`'s public API.** If
    `_open()` ever fails in release (see #1), every later call
    (`get_high_score` from `GameData._ready`, `get_level_progress` from
    LevelSelect…) is a null-instance crash. Query success is never checked
    either (`query_with_bindings` return values ignored).
11. **Boss-invalid fallthrough** (`Main.food_dropped_on_hero:170`): the boss
    branch requires `_boss_active and is_instance_valid(boss)`. If the boss
    instance were ever invalid while `_boss_active` is still true, feeding
    falls through to the *normal* check against `correct_group` — which is the
    already-finished last wave's group. Currently unreachable through normal
    play (boss is only freed via `_clear_boss`, which flips the flag), but the
    state pair is unguarded and one future edit away from a confusing bug.
12. **Tween stacking can permanently drift the Hero.** `_effect_slam` captures
    `var orig := hero.position` and tweens out-and-back; a second slam (or a
    lunge overlapping anything that moves the hero) fired mid-lunge captures a
    displaced `orig`, and the hero never returns to (920, 320). Two correct
    Grow feeds in quick succession is achievable. Same pattern, lower stakes,
    in `_effect_heal`'s modulate tween.
13. **Same-SFX retrigger cuts audio.** `Audio.play` keeps exactly one
    `AudioStreamPlayer` per sound name, so a rapid second "correct"/"zap" cuts
    off the first. Polish-level, but it is audible during fast play.
14. **Asymmetric cleanup on game over**: `_level_complete()` stops both timers
    and `_clear_foods()`; `_game_over()` stops the timers but leaves foods (the
    scene change frees them, so it's benign today — but the asymmetry invites a
    future bug, e.g. if game over ever shows an in-scene popup like the lesson
    does).
15. **`_needed_groups()` returns `_meal_needed` by reference**, not a copy. All
    current callers only read it, but any future caller that mutates the
    returned array would corrupt the boss meal state.
16. **Per-frame duck-typed lookups**: every `Enemy` and dragged `Food` calls
    `get_tree().current_scene` + `get_node("Hero")` every `_process` frame.
    Correct today (documented contract) but repeated in two scripts, and
    silently does nothing if the contract is broken (enemy just never moves —
    no error, hard to diagnose).
17. **Screen geometry is hardcoded** to the default 1152×648 window across
    `Main.gd` (belt width 1152, stripe wrap 1160/−1300, `STACK_FRONT_X` 1040,
    spawn y-range 180–470) and `Food.gd` (`BELT_Y` 600). Consistent with the
    current stretch settings, but scattered — a resolution change would require
    hunting numbers in two files.
18. **Duplicated logic**: `_stars()` exists in both `LevelSelect.gd` and
    `ResultScreen.gd` (near-identical); `_spawn_food` re-implements
    `_choose_spawn_group`'s missing-group-else-random choice inline.

### 1.5 Gaps

19. **No way to leave a level.** Once in `Main.tscn` there is no pause menu,
    no quit-to-menu, and Esc does nothing — the only exits are winning, dying,
    or killing the window. Notable for an app aimed at kids/classrooms.
20. **No automated tests at all.** The de-facto test is the manual headless
    run in CLAUDE.md. Pure-logic pieces (star math, unlock chain, boss meal
    bookkeeping, needed-group solvability, DB upsert semantics) are all
    headless-testable today with a script, but no such script exists, and the
    two headless commands aren't wrapped in a runnable one-liner.
21. **No audio settings** (mute / volume) — relevant for classroom use.
22. **`is_level_unlocked` does two DB queries per tile per refresh** (12
    queries per difficulty tab click). Harmless at 6 levels; worth batching
    only if the level count grows.

---

## SECTION 2 — RESTRUCTURING PLAN

Guiding rule: **every phase preserves all current features and the documented
cross-script contracts** — `Main` stays the active scene exposing
`food_dropped_on_hero` / `enemy_reached_hero` (untyped params), `Hero` stays a
direct child of `Main` named `Hero`, group strings stay `"Go"/"Glow"/"Grow"`,
`"enemies"`/`"boss"` group semantics stay, and the needed-group belt guarantee
is never weakened. Each phase ends with the standard headless validation
(import + `Main.tscn` and `MainMenu.tscn` runs, filtered for real errors) and
is a separate commit, so any regression bisects to one phase.

### Phase 0 — Documentation sync (no code)

- Rewrite README's gameplay + structure sections to cover boss levels (waves,
  balanced meal, `BOSS_LESSON`), nutrient popups, and the Coming Soon tile;
  fix the self-contradicting "Next steps"; correct the autoload description;
  soften "always on screen" to the real ≤1s-gap guarantee (or tighten the code
  in Phase 2 and keep the strong wording — see below).
- CLAUDE.md touch-ups: precise wave-group rule (wave 2 ∈ {Glow, Grow}), note
  the Coming Soon tile, note the `.approj` (Anchorpoint) file, and — after
  Phase 1 — replace the "asserts" description with the new release-safe
  failure behavior.

### Phase 1 — Robustness hardening (small, surgical edits)

1. **Make DB failure loud in *all* builds** (`Database.gd`): replace the two
   `assert`s with explicit runtime checks that run in release too — on
   missing class / failed open: `push_error(...)`, `OS.alert(...)` with a
   human-readable message, and `get_tree().quit(1)`. Guard every public method
   with an early `if _db == null: return <safe default>` so a partially
   initialized frame can't null-crash before quit lands. Check
   `query`/`query_with_bindings` return values and `push_error` on failure.
   This *implements* the documented intent rather than changing it.
2. **Close the boss-invalid fallthrough** (`Main.food_dropped_on_hero`): when
   `_boss_active` but the boss instance is gone, treat it as a
   consumed-without-effect no-op (return false with a neutral hint) instead of
   falling into the stale wave check; add the invariant as a comment.
3. **Tween ownership for hero movement/tint**: keep a single reusable tween
   reference for the slam lunge (kill the previous before starting a new one,
   and anchor `orig` to the hero's *home* position constant, not its current
   position) and likewise for the heal tint. Kills the drift bug in #12.
4. **Symmetric end-of-level cleanup**: extract a `_stop_level()` helper (stop
   both timers + `_clear_foods()`) called from both `_level_complete` and
   `_game_over`.
5. **Return a duplicate from `_needed_groups()`** (or document the read-only
   aliasing at the call sites) to remove the mutation hazard in #15.

### Phase 2 — Structural refactor of `Main.gd` (~600 lines → focused units)

`Main.gd` currently owns five jobs: level/wave/boss state machine, belt
economy, procedural FX, HUD, and the two contract entry points. Split it while
keeping `Main` as the façade so nothing outside the scene changes:

1. **`scripts/BeltManager.gd`** (child `Node2D` of `Main`, absorbing the
   current `$Foods` container): food spawning, seeding, per-frame stacking
   layout, stripe animation, `_belt_has_group` / missing-group logic. `Main`
   supplies it a `needed_groups_provider` callable so the solvability
   invariant stays driven by level/boss state. **Optional tightening:** spawn
   the replacement needed-group food immediately on consumption/expiry
   (instead of waiting for the next tick), which makes README's "always on
   screen" wording true.
2. **`scripts/FxManager.gd`** (child node): zap / heal / slam / ring / shake /
   nutrient popup. Takes the hero + camera as init refs. Pure output — no game
   state, trivially reusable when the art phase replaces gray boxes.
3. **Boss/wave logic stays in `Main.gd`** but grouped behind a clear section
   as the level state machine (`_start_level → waves → boss → complete`),
   since it *is* the controller's core job. (Extracting it to a fourth file
   adds indirection without reducing coupling — the state machine touches
   score, lives, HUD, and belt anyway.)
4. **`Main` keeps** `food_dropped_on_hero` / `enemy_reached_hero` (delegating
   internally), `Hero`, groups, and all constants that other nodes read.
   Node names inside `Main.tscn` that scripts reference (`Hero`, `Foods`,
   HUD labels) are unchanged.
5. **Geometry constants**: gather the screen-coupled numbers (design size,
   belt line, stack anchor, spawn band) into one `const` block (either in
   `GameData` or a small `Screen` section at the top of `Main.gd`) and have
   `Food.gd` read `BELT_Y` from the belt manager instead of duplicating it.

### Phase 3 — Deduplication & small quality fixes

1. Move `_stars()` into one shared helper (`GameData.stars_text(n)`), used by
   LevelSelect and ResultScreen (keeping ResultScreen's bracket wrapper local).
2. Fold `_spawn_food`'s inline group choice into `_choose_spawn_group`.
3. `Audio.play`: allow overlapping one-shots (small round-robin pool per SFX,
   or `AudioStreamPolyphonic`) so rapid correct/zap sounds don't cut off.
4. Give the boss its own HUD flavor: `target_label` currently keeps the last
   wave's group color during the boss — use a neutral/boss color.
5. Mark level 5 as a boss level in UI data: add an optional `"boss_name"`
   (e.g. "Boss: Balanced Meal") used by the HUD and a "BOSS" badge on the
   LevelSelect tile, so the dead "Fruit Shield" data stops being misleading.
   (Keep `LEVELS[4]`'s entry — `level_data()` still needs a row — but repoint
   its name; alternatively keep the name and only badge it. Either preserves
   all behavior.)

### Phase 4 — Test & validation harness

1. **`tools/smoke_test.gd`** — a `SceneTree` script run headlessly
   (`--headless -s tools/smoke_test.gd`) asserting the pure logic:
   star math (`_compute_stars` across all difficulties), `is_boss_level`,
   unlock chain semantics against a throwaway DB file (create → record win →
   assert next level unlocked → delete), `record_level_result` upsert
   (best-score keeps max), `FOOD_NUTRIENTS` covers every food in `FOODS`,
   and wave-group construction rules. Exit code 1 on any failure.
2. **`tools/test.ps1`** — one command wrapping: import → smoke test →
   `Main.tscn` 150-frame run → `MainMenu.tscn` run, with the CLAUDE.md error
   filter applied and a clear PASS/FAIL summary. Becomes the documented
   pre-commit check in CLAUDE.md.
3. Manual F5 checklist appended to CLAUDE.md for the things headless can't do
   (drag feel, boss knockback, blink timing, sounds).

### Phase 5 — Repo hygiene

- Delete the two `~libgdsqlite…TMP` files from `addons/godot-sqlite/bin/`.
- Open the project once in the editor and commit the re-saved scenes so all
  six `.tscn` files carry `uid`/`unique_id` consistently (CLAUDE.md already
  declares this expected).
- One line in README explaining the `.approj` Anchorpoint file.

### Suggested order & risk

Phases 0–1 are low-risk and highest value (docs truth + release-crash
prevention) — do them first. Phase 2 is the only structurally risky step;
its blast radius is contained by the façade rule and the Phase 4 harness can
even be built *before* it (swap Phases 2 and 4 if preferred — building the
smoke test first gives the refactor a safety net). Phases 3 and 5 are
independent and can ride along with any commit.
