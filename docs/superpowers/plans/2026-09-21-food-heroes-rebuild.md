# Food Heroes Rebuild Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild Food Heroes so every monster asks its own food-group question, difficulty becomes a teaching ladder, and the landscape layout adapts correctly from 16:9 to 21:9 phones with safe-area insets.

**Architecture:** A new pure-function `Layout` autoload owns every screen coordinate, derived from viewport size and safe area, which makes the multi-resolution work unit-testable headlessly. The 473-line `Main.gd` splits into `Game` (orchestrator), `WaveDirector` (level/wave/boss machine), `ScoreKeeper` (score/streak/accuracy) and `HudController`. Monsters carry a per-instance weakness instead of the level carrying one `correct_group`.

**Tech Stack:** Godot 4.6.3 (GDScript, tab-indented), SQLite via the committed `addons/godot-sqlite` GDExtension, PowerShell test runner.

**Spec:** `docs/superpowers/specs/2026-09-21-food-heroes-rebuild-design.md`

## Global Constraints

- **Engine:** Godot 4.6.3 at `C:\SHIZ\Godot_v4.6.3-stable_win64.exe` — not on PATH.
- **Indentation:** GDScript is tab-indented. Match surrounding style exactly.
- **The standard check is one command:** `powershell -ExecutionPolicy Bypass -File tools\test.ps1` — import, logic smoke test, headless scene runs, PASS/FAIL, exit 0/1.
- **There is no unit-test framework.** All logic tests are `_check(cond, what)` calls inside `tools/smoke_test.gd`, which `extends SceneTree`. In `-s` script mode autoloads are **not** instantiated — load scripts manually with `load("res://scripts/X.gd")`.
- **Never touch the real save.** Logic tests use the throwaway `user://smoke_test.db` only.
- **Orientation is landscape only.** No portrait mode, at any point, in any task.
- **Design box:** 1152x648, `stretch/mode="canvas_items"`, `stretch/aspect="expand"`.
- **Gameplay quantities stay device-independent.** `MAX_FOODS` is 6 on every phone; surplus width becomes spacing, never advantage.
- **Food groups are bare strings** `"Go"` / `"Glow"` / `"Grow"`. Spelling must match across `GameData`, scenes and code.
- **Every interactive `Area2D` needs a `CollisionShape2D`**, and any `ColorRect`/`Label` drawn over it must set `mouse_filter = 2` (Ignore) or it swallows the click.
- **Do not launch `--headless --editor`.** `--quit-after` does not quit the editor; the process survives holding the sqlite DLL and later `--import` runs fail with `Error copying library`.
- **Benign noise to ignore** when reading headless output: `resource still in use: music.wav` and "ObjectDB instances leaked at exit" on `--quit-after` runs.
- **Commits:** approving this plan authorizes the per-task commits specified below. Nothing outside a task's listed files gets committed. The repo currently has unrelated dirty `.import` files and an untracked CCGS framework install — never `git add -A`.

---

## File Structure

| File | Responsibility |
|---|---|
| `scripts/Layout.gd` | **New autoload.** Pure geometry: viewport + safe area → every coordinate. |
| `scripts/GameData.gd` | Food tables (kept), `NUTRIENT_GROUPS` (new), 15 levels, difficulty tiers, run state. |
| `scripts/Database.gd` | Adds the `accuracy` table and its two accessors. |
| `scripts/ScoreKeeper.gd` | **New.** Score, streak multiplier, per-group accuracy for one run. |
| `scripts/WaveDirector.gd` | **New.** Level / wave / boss state machine. |
| `scripts/HudController.gd` | **New.** All HUD text and colour. |
| `scripts/Game.gd` | **New.** Thin orchestrator; the cross-script contract surface. |
| `scripts/Enemy.gd` | Gains a per-instance `weakness`; references injected, no `current_scene` lookups. |
| `scripts/Food.gd` | Neutral-vs-coloured rendering; references injected. |
| `scripts/BeltManager.gd` | Reads all coordinates from `Layout`. |
| `tools/smoke_test.gd` | Gains four test groups. |

---

## Task 1: Layout geometry (pure functions)

**Files:**
- Create: `scripts/Layout.gd`
- Test: `tools/smoke_test.gd`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `Layout.BASE : Vector2` = `Vector2(1152, 648)`
  - `static func design_scale(window_px: Vector2, base: Vector2) -> float`
  - `static func visible_size(window_px: Vector2, base: Vector2) -> Vector2`
  - `static func safe_in_design(safe_px: Rect2, window_px: Vector2, base: Vector2) -> Rect2`
  - `static func compute(view: Vector2, safe: Rect2) -> Dictionary` with keys
    `hero_x`, `stack_front_x`, `spawn_x`, `belt_y`, `belt_top`, `lane_top`,
    `lane_bottom`, `stack_spacing` — all floats.

- [ ] **Step 1: Write the failing test**

Add to `tools/smoke_test.gd`, and add `_test_layout()` to the `_initialize()` body before `_test_database()`:

```gdscript
# === Layout: pure geometry at every shipped aspect ===
func _test_layout() -> void:
	print("[Layout]")
	var L = load("res://scripts/Layout.gd")

	# Scale is the smaller of the two axis ratios; with a fixed 648 design
	# height in landscape that is always the height ratio.
	_check(is_equal_approx(L.design_scale(Vector2(1152, 648), L.BASE), 1.0), "scale is 1.0 at the design size")
	_check(is_equal_approx(L.design_scale(Vector2(2400, 1080), L.BASE), 1080.0 / 648.0), "scale follows the height ratio")

	# Visible width grows with the device; height stays at the design 648.
	var vis := L.visible_size(Vector2(2400, 1080), L.BASE)
	_check(is_equal_approx(vis.y, 648.0), "visible height stays 648")
	_check(int(round(vis.x)) == 1440, "20:9 reveals 1440 design units of width")

	# Every shipped aspect must produce a sane, ordered play field.
	var windows := [Vector2(1152, 648), Vector2(2556, 1179), Vector2(2400, 1080), Vector2(2520, 1080)]
	for w in windows:
		var v: Vector2 = L.visible_size(w, L.BASE)
		var safe := Rect2(Vector2.ZERO, v)          # no insets: the desktop case
		var m: Dictionary = L.compute(v, safe)
		var tag := "%dx%d" % [int(w.x), int(w.y)]
		_check(m["hero_x"] > 0.0 and m["hero_x"] < v.x, "%s: hero is on screen" % tag)
		_check(m["spawn_x"] < 0.0, "%s: monsters spawn off the left edge" % tag)
		_check(m["spawn_x"] < m["hero_x"], "%s: monsters spawn left of the hero" % tag)
		_check(m["belt_top"] < m["belt_y"], "%s: belt top is above the food lane" % tag)
		_check(m["belt_y"] < v.y, "%s: food lane is on screen" % tag)
		_check(m["lane_top"] < m["lane_bottom"], "%s: monster lanes are not inverted" % tag)
		_check(m["lane_bottom"] < m["belt_top"], "%s: monster lanes clear the belt" % tag)
		_check(m["stack_spacing"] >= 185.0 and m["stack_spacing"] <= 230.0, "%s: spacing stays in range" % tag)

	# Wider devices get more breathing room, never more foods.
	var narrow: Dictionary = L.compute(Vector2(1152, 648), Rect2(Vector2.ZERO, Vector2(1152, 648)))
	var wide: Dictionary = L.compute(Vector2(1440, 648), Rect2(Vector2.ZERO, Vector2(1440, 648)))
	_check(wide["stack_spacing"] > narrow["stack_spacing"], "surplus width becomes spacing")
```

- [ ] **Step 2: Run test to verify it fails**

```bash
powershell -ExecutionPolicy Bypass -File tools\test.ps1
```

Expected: FAIL. The smoke test prints a parse/load error because `res://scripts/Layout.gd` does not exist.

- [ ] **Step 3: Write minimal implementation**

Create `scripts/Layout.gd`:

```gdscript
extends Node
## Autoload singleton ("Layout").
## The single authority for every on-screen coordinate. Everything here is a
## pure function of the visible viewport and the safe area, so the whole layout
## is testable headlessly at any aspect without a device — see tools/smoke_test.gd.
##
## Landscape only. The design box is 1152x648 with stretch mode "canvas_items"
## and aspect "expand", so the design HEIGHT is fixed and the WIDTH grows on
## taller phones (16:9 -> 1152 units, 21:9 -> 1512 units).

const BASE := Vector2(1152, 648)

# Distances from a safe-area edge. Tune these, never the call sites.
const HERO_INSET_R := 232.0     # hero sits this far in from the right safe edge
const STACK_INSET_R := 112.0    # front of the food stack, right-anchored
const SPAWN_INSET_L := 80.0     # monsters enter this far off the left edge
const BELT_INSET_B := 88.0      # food lane, up from the bottom safe edge
const BELT_H := 96.0            # drawn height of the conveyor
const HUD_H := 106.0            # reserved strip at the top for the HUD
const LANE_MARGIN := 24.0       # gap between the monster lanes and HUD/belt
const MAX_FOODS := 6            # fixed on every device, on purpose
const SPACING_MIN := 185.0
const SPACING_MAX := 230.0

# The engine scales the design box by the SMALLER axis ratio and reveals the
# surplus on the other axis. In landscape that is always the height ratio.
static func design_scale(window_px: Vector2, base: Vector2) -> float:
	return minf(window_px.x / base.x, window_px.y / base.y)

static func visible_size(window_px: Vector2, base: Vector2) -> Vector2:
	return window_px / design_scale(window_px, base)

# DisplayServer reports the safe area in PHYSICAL pixels; convert to design units.
static func safe_in_design(safe_px: Rect2, window_px: Vector2, base: Vector2) -> Rect2:
	var s := design_scale(window_px, base)
	return Rect2(safe_px.position / s, safe_px.size / s)

static func compute(view: Vector2, safe: Rect2) -> Dictionary:
	var belt_y: float = safe.end.y - BELT_INSET_B
	var belt_top: float = belt_y - BELT_H * 0.5
	var stack_front_x: float = safe.end.x - STACK_INSET_R
	var spacing: float = clampf((stack_front_x - safe.position.x) / float(MAX_FOODS), SPACING_MIN, SPACING_MAX)
	return {
		"view": view,
		"safe": safe,
		"hero_x": safe.end.x - HERO_INSET_R,
		"hero_y": safe.position.y + (belt_top - safe.position.y) * 0.5,
		"stack_front_x": stack_front_x,
		"stack_spacing": spacing,
		"spawn_x": safe.position.x - SPAWN_INSET_L,
		"belt_y": belt_y,
		"belt_top": belt_top,
		"lane_top": safe.position.y + HUD_H + LANE_MARGIN,
		"lane_bottom": belt_top - LANE_MARGIN,
	}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
powershell -ExecutionPolicy Bypass -File tools\test.ps1
```

Expected: PASS, with the `[Layout]` block printing `ok` for every aspect.

- [ ] **Step 5: Commit**

```bash
git add scripts/Layout.gd tools/smoke_test.gd
git commit -m "Layout: pure geometry for 16:9 to 21:9 landscape"
```

---

## Task 2: Safe-area conversion

**Files:**
- Modify: `scripts/Layout.gd`
- Test: `tools/smoke_test.gd`

**Interfaces:**
- Consumes: `Layout.safe_in_design`, `Layout.compute` from Task 1.
- Produces: `func refresh() -> void` and `signal changed` on the autoload instance, plus `var m: Dictionary` holding the current metrics.

- [ ] **Step 1: Write the failing test**

Append inside `_test_layout()` in `tools/smoke_test.gd`:

```gdscript
	# Physical safe-area pixels convert to design units by the same scale.
	# iPhone-shaped case: a notch inset on the left, gesture strip at the bottom.
	var win := Vector2(2556, 1179)
	var safe_px := Rect2(132.0, 0.0, 2292.0, 1077.0)
	var safe_d: Rect2 = L.safe_in_design(safe_px, win, L.BASE)
	var view_d: Vector2 = L.visible_size(win, L.BASE)
	_check(safe_d.position.x > 0.0, "notch inset survives conversion")
	_check(safe_d.end.x < view_d.x, "right safe edge is inside the viewport")
	_check(safe_d.end.y < view_d.y, "bottom safe edge is above the screen bottom")

	# The belt must clear the gesture strip once the inset is applied.
	var inset: Dictionary = L.compute(view_d, safe_d)
	_check(inset["belt_y"] < safe_d.end.y, "food lane sits inside the safe area")
	_check(inset["belt_top"] > safe_d.position.y, "belt does not reach the top safe edge")
	_check(inset["hero_x"] < safe_d.end.x, "hero clears the right safe edge")

	# An inset layout must never be identical to an uninset one, or the
	# conversion is silently doing nothing.
	var none: Dictionary = L.compute(view_d, Rect2(Vector2.ZERO, view_d))
	_check(inset["belt_y"] < none["belt_y"], "insets lift the belt off the bottom edge")
```

- [ ] **Step 2: Run test to verify it fails**

```bash
powershell -ExecutionPolicy Bypass -File tools\test.ps1
```

Expected: FAIL on `insets lift the belt off the bottom edge` only if `compute` ignores the safe rect. If Task 1 was implemented as written these pass immediately — that is the point of the check, it guards the conversion against future regressions.

- [ ] **Step 3: Write minimal implementation**

Append to `scripts/Layout.gd`:

```gdscript
signal changed

var m: Dictionary = {}

func _ready() -> void:
	refresh()
	get_tree().get_root().size_changed.connect(refresh)

# Reads live engine state, converts it, and republishes the metrics.
# Desktop reports the whole screen as safe, which is correct there — the insets
# only ever appear on a device build.
func refresh() -> void:
	var win := Vector2(DisplayServer.window_get_size())
	var view := visible_size(win, BASE)
	var safe_px := Rect2(DisplayServer.get_display_safe_area())
	var safe := safe_in_design(safe_px, win, BASE)
	# Clamp: a driver reporting nonsense must never push geometry off-screen.
	safe = safe.intersection(Rect2(Vector2.ZERO, view))
	if safe.size.x <= 0.0 or safe.size.y <= 0.0:
		safe = Rect2(Vector2.ZERO, view)
	m = compute(view, safe)
	changed.emit()
```

- [ ] **Step 4: Run test to verify it passes**

```bash
powershell -ExecutionPolicy Bypass -File tools\test.ps1
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/Layout.gd tools/smoke_test.gd
git commit -m "Layout: safe-area conversion and live refresh"
```

---

## Task 3: Register the autoload and pin project settings

**Files:**
- Modify: `project.godot`

**Interfaces:**
- Consumes: `scripts/Layout.gd` from Tasks 1–2.
- Produces: a global `Layout` singleton available to every later task.

- [ ] **Step 1: Register the autoload**

In `project.godot`, `Layout` must load **first** — nothing depends on it and everything reads it. In the `[autoload]` section, place it above `DB`:

```ini
Layout="*res://scripts/Layout.gd"
```

`GameData` still calls `DB` in `_ready()`, so `DB` must stay above `GameData`. Final order: `Layout`, `DB`, `GameData`, `Audio`.

- [ ] **Step 2: Pin the display settings**

In the `[display]` section. `handheld/orientation` is an **integer enum**, not a string — `0` is landscape, and it is already the effective default; setting it explicitly documents the intent:

```ini
window/size/viewport_width=1152
window/size/viewport_height=648
window/handheld/orientation=0
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
```

- [ ] **Step 3: Verify the settings resolve**

```bash
powershell -ExecutionPolicy Bypass -File tools\test.ps1
```

Expected: PASS. The headless scene runs load the new autoload; any error in `Layout._ready()` shows as `SCRIPT ERROR` and fails step 3/5.

- [ ] **Step 4: Commit**

```bash
git add project.godot
git commit -m "Project: register Layout autoload, pin landscape display settings"
```

---

## Task 4: NUTRIENT_GROUPS and the unambiguity guard

**Files:**
- Modify: `scripts/GameData.gd`
- Test: `tools/smoke_test.gd`

**Interfaces:**
- Consumes: the existing `GameData.FOODS` and `GameData.FOOD_NUTRIENTS`.
- Produces:
  - `GameData.NUTRIENT_GROUPS : Dictionary` mapping nutrient string → group string.
  - `func nutrient_group(nutrient: String) -> String` returning `""` when unknown.
  - `func random_nutrient_for(group: String) -> String` returning `""` when the group has none.

- [ ] **Step 1: Write the failing test**

Add a `_test_nutrients()` function to `tools/smoke_test.gd` and call it from `_initialize()` after `_test_gamedata()`:

```gdscript
# === Nutrients: Hard mode can only ask questions with one answer ===
func _test_nutrients() -> void:
	print("[Nutrients]")
	var gd = load("res://scripts/GameData.gd").new()

	# Build nutrient -> set of groups straight from the food tables.
	var spread := {}
	for group in gd.FOODS.keys():
		for food in gd.FOODS[group]:
			var n: String = gd.FOOD_NUTRIENTS.get(food, "")
			_check(n != "", "%s has a nutrient" % food)
			if not spread.has(n):
				spread[n] = {}
			spread[n][group] = true

	# Every nutrient offered to Hard mode must resolve to exactly one group.
	for n in gd.NUTRIENT_GROUPS.keys():
		var groups: Dictionary = spread.get(n, {})
		_check(groups.size() == 1, "%s belongs to exactly one group" % n)
		_check(groups.has(gd.NUTRIENT_GROUPS[n]), "%s maps to the group that carries it" % n)

	# The ambiguous three must be absent, or Hard mode asks unanswerable questions.
	for n in ["+Vitamin A", "+Iron", "+Calcium"]:
		_check(not gd.NUTRIENT_GROUPS.has(n), "%s is excluded as ambiguous" % n)

	# Every group must be able to produce at least one Hard-mode request.
	for group in gd.FOODS.keys():
		_check(gd.random_nutrient_for(group) != "", "%s can produce a nutrient request" % group)

	_check(gd.nutrient_group("+Protein") == "Grow", "protein resolves to Grow")
	_check(gd.nutrient_group("+Nonsense") == "", "unknown nutrient resolves to empty")
```

- [ ] **Step 2: Run test to verify it fails**

```bash
powershell -ExecutionPolicy Bypass -File tools\test.ps1
```

Expected: FAIL with `Invalid access` on `NUTRIENT_GROUPS`.

- [ ] **Step 3: Write minimal implementation**

Add to `scripts/GameData.gd`, below `FOOD_NUTRIENTS`:

```gdscript
# Nutrients that belong to EXACTLY ONE group, so a Hard-mode monster asking for
# one has a single correct answer. Vitamin A (Go + Glow), Iron and Calcium
# (Glow + Grow) are deliberately excluded — a monster asking for them would be
# unanswerable. tools/smoke_test.gd asserts this stays true as foods are added.
const NUTRIENT_GROUPS := {
	"+Carbs": "Go", "+Fiber": "Go", "+Energy": "Go",
	"+Vitamin C": "Glow", "+Potassium": "Glow",
	"+Protein": "Grow",
}

func nutrient_group(nutrient: String) -> String:
	return NUTRIENT_GROUPS.get(nutrient, "")

# Grow only contributes "+Protein", which is why Hard mode mixes nutrient and
# group requests rather than asking for nutrients every time (see WaveDirector).
func random_nutrient_for(group: String) -> String:
	var options: Array = []
	for n in NUTRIENT_GROUPS.keys():
		if NUTRIENT_GROUPS[n] == group:
			options.append(n)
	if options.is_empty():
		return ""
	return options[randi() % options.size()]
```

- [ ] **Step 4: Run test to verify it passes**

```bash
powershell -ExecutionPolicy Bypass -File tools\test.ps1
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/GameData.gd tools/smoke_test.gd
git commit -m "GameData: unambiguous nutrient-to-group map for Hard mode"
```

---

## Task 5: Difficulty tiers and 15 levels

**Files:**
- Modify: `scripts/GameData.gd:47-52` (the `DIFFICULTIES` block), `scripts/GameData.gd:29-45` (the `LEVELS` block)
- Test: `tools/smoke_test.gd`

**Interfaces:**
- Consumes: Task 4's `NUTRIENT_GROUPS`.
- Produces: `DIFFICULTIES[tier]["monster_label"]` (`"group"` or `"nutrient"`) and `["show_food_color"]` (bool); `LEVELS` with 15 entries.

- [ ] **Step 1: Write the failing test**

Append to `_test_gamedata()` in `tools/smoke_test.gd`:

```gdscript
	# 15 levels means bosses land on 5, 10 and 15.
	_check(gd.LEVELS.size() == 15, "there are 15 levels")
	_check(gd.num_levels() == 15, "num_levels agrees with the table")
	var bosses := 0
	for n in range(1, gd.num_levels() + 1):
		if gd.is_boss_level(n):
			bosses += 1
	_check(bosses == 3, "three boss levels across the run")

	# Every level is well-formed, or a level silently becomes unplayable.
	for i in range(gd.LEVELS.size()):
		var row: Dictionary = gd.LEVELS[i]
		_check(row.has("name") and String(row["name"]) != "", "level %d has a name" % (i + 1))
		_check(gd.FOODS.has(row["correct_group"]), "level %d targets a real group" % (i + 1))
		_check(int(row["enemies"]) > 0, "level %d spawns monsters" % (i + 1))
		_check(String(row["lesson"]) != "", "level %d has a lesson" % (i + 1))

	# Difficulty is a teaching ladder, not just a speed knob.
	for diff in gd.DIFFICULTY_ORDER:
		var d: Dictionary = gd.DIFFICULTIES[diff]
		_check(d.has("monster_label"), "%s declares a monster label mode" % diff)
		_check(d["monster_label"] in ["group", "nutrient"], "%s label mode is valid" % diff)
		_check(d.has("show_food_color"), "%s declares whether foods are coloured" % diff)
	_check(gd.DIFFICULTIES["Easy"]["show_food_color"] == true, "Easy keeps the colour crutch")
	_check(gd.DIFFICULTIES["Medium"]["show_food_color"] == false, "Medium removes the colour crutch")
	_check(gd.DIFFICULTIES["Hard"]["monster_label"] == "nutrient", "Hard asks for nutrients")
```

- [ ] **Step 2: Run test to verify it fails**

```bash
powershell -ExecutionPolicy Bypass -File tools\test.ps1
```

Expected: FAIL — `there are 15 levels` (the table has 6) and `Easy declares a monster label mode`.

- [ ] **Step 3: Write minimal implementation**

Replace the `DIFFICULTIES` block in `scripts/GameData.gd`:

```gdscript
# === Difficulty modifiers ===
# lives: starting lives. speed_mult: enemy speed. spawn_mult: time between
# spawns (>1 = slower). enemy_bonus: extra enemies. score_mult: points multiplier.
# monster_label: what a monster displays as its weakness -- "group" ("GROW") or
#   "nutrient" ("needs PROTEIN"). show_food_color: whether belt foods are tinted
#   by group. Together these make difficulty a TEACHING ladder: Easy lets the
#   player match colours, Medium demands group knowledge, Hard demands the
#   food -> nutrient -> group chain.
const DIFFICULTIES := {
	"Easy":   {"lives": 5, "speed_mult": 0.70, "spawn_mult": 1.30, "enemy_bonus": 0, "score_mult": 1,
			   "monster_label": "group", "show_food_color": true},
	"Medium": {"lives": 3, "speed_mult": 1.00, "spawn_mult": 1.00, "enemy_bonus": 1, "score_mult": 2,
			   "monster_label": "group", "show_food_color": false},
	"Hard":   {"lives": 2, "speed_mult": 1.40, "spawn_mult": 0.70, "enemy_bonus": 2, "score_mult": 3,
			   "monster_label": "nutrient", "show_food_color": false},
}
```

Extend `LEVELS` from 6 to 15 rows. Keep the existing six in order, then append nine. Level 5 is now a boss so its row is only used by LevelSelect's title; the "Fruit Shield" fruit lesson moves to level 6 where a player will actually read it:

```gdscript
	{"name": "Fruit Shield", "correct_group": "Glow", "enemies": 6,
	 "lesson": "Fruits are Glow foods too! Mango, papaya, and orange give vitamins that keep you healthy."},
	{"name": "Strong Finish", "correct_group": "Grow", "enemies": 6,
	 "lesson": "Grow foods help you grow tall and strong! Chicken, shrimp, tofu, and cheese build your body."},
	{"name": "Market Run", "correct_group": "Go", "enemies": 7,
	 "lesson": "Go foods are grains and starchy roots. Rice, corn, and sweet potato all give lasting energy."},
	{"name": "Garden Guard", "correct_group": "Glow", "enemies": 7,
	 "lesson": "Dark green leaves are the strongest Glow foods. Moringa and bok choy are packed with vitamins."},
	{"name": "Protein Power", "correct_group": "Grow", "enemies": 8,
	 "lesson": "Fish, egg, tofu, and mung beans are all Grow foods. They repair your body every single day."},
	{"name": "Lunchbox Logic", "correct_group": "Go", "enemies": 8,
	 "lesson": "A Go food belongs in every meal. Noodles, bread, and porridge keep your energy steady."},
	{"name": "Vitamin Vault", "correct_group": "Glow", "enemies": 9,
	 "lesson": "Glow foods protect you from sickness. Eat a colourful mix of fruits and vegetables daily."},
	{"name": "Build and Grow", "correct_group": "Grow", "enemies": 9,
	 "lesson": "Milk and cheese give calcium for strong bones, while fish and beef give iron for your blood."},
	{"name": "Healthy Habit", "correct_group": "Glow", "enemies": 10,
	 "lesson": "Eating well is a habit, not a one-time meal. Choose Go, Grow, and Glow foods every day."},
```

Insert these after the existing `"Power Snack"` row so the six originals occupy levels 1–4 plus the boss slot at 5, and the appended rows fill 6–15. The final table must have exactly 15 entries.

- [ ] **Step 4: Run test to verify it passes**

```bash
powershell -ExecutionPolicy Bypass -File tools\test.ps1
```

Expected: PASS. The existing star-math and clamp tests still pass — `level_data` clamps against `LEVELS.size()`, which simply grew.

- [ ] **Step 5: Commit**

```bash
git add scripts/GameData.gd tools/smoke_test.gd
git commit -m "GameData: teaching-ladder difficulties and 15 levels"
```

---

## Task 6: Accuracy table in the DB layer

**Files:**
- Modify: `scripts/Database.gd`
- Test: `tools/smoke_test.gd`

**Interfaces:**
- Consumes: the existing `_db` handle and query helpers in `Database.gd`.
- Produces:
  - `func record_answer(difficulty: String, group: String, was_correct: bool) -> void`
  - `func get_accuracy(difficulty: String) -> Dictionary` → `{group: {"correct": int, "wrong": int}}`

- [ ] **Step 1: Write the failing test**

Append to `_test_database()` in `tools/smoke_test.gd`, before `_remove_test_db()`:

```gdscript
	# Accuracy: the evidence-of-learning record.
	_check(db.get_accuracy("Easy").is_empty(), "fresh accuracy is empty")
	db.record_answer("Easy", "Go", true)
	db.record_answer("Easy", "Go", true)
	db.record_answer("Easy", "Go", false)
	db.record_answer("Easy", "Grow", false)
	var acc: Dictionary = db.get_accuracy("Easy")
	_check(acc.has("Go") and acc.has("Grow"), "both answered groups are recorded")
	_check(int(acc["Go"]["correct"]) == 2, "correct answers accumulate")
	_check(int(acc["Go"]["wrong"]) == 1, "wrong answers accumulate")
	_check(int(acc["Grow"]["correct"]) == 0, "a group with only misses reads zero correct")

	# Accuracy is per difficulty, like the unlock chain.
	_check(db.get_accuracy("Hard").is_empty(), "accuracy does not leak across difficulties")
```

- [ ] **Step 2: Run test to verify it fails**

```bash
powershell -ExecutionPolicy Bypass -File tools\test.ps1
```

Expected: FAIL with `Invalid call ... 'get_accuracy'`.

- [ ] **Step 3: Write minimal implementation**

In `scripts/Database.gd`, create the table alongside `meta` and `progress` in `_open()`. Note `group` is a reserved SQL word — it must be quoted:

```gdscript
	_db.query("""
		CREATE TABLE IF NOT EXISTS accuracy (
			difficulty TEXT NOT NULL,
			"group"    TEXT NOT NULL,
			correct    INTEGER NOT NULL DEFAULT 0,
			wrong      INTEGER NOT NULL DEFAULT 0,
			PRIMARY KEY (difficulty, "group")
		)""")
```

Then add the two accessors. They follow the file's existing practice: guard `_db == null`, check every query return, `push_error` on failure, return safe defaults:

```gdscript
# Records one answer against its food group. Fire-and-forget: a failure here
# must never interrupt play, so it logs and returns.
func record_answer(difficulty: String, group: String, was_correct: bool) -> void:
	if _db == null:
		return
	var col := "correct" if was_correct else "wrong"
	var sql := """
		INSERT INTO accuracy (difficulty, "group", correct, wrong) VALUES (?, ?, ?, ?)
		ON CONFLICT(difficulty, "group") DO UPDATE SET %s = %s + 1""" % [col, col]
	var ok := _db.query_with_bindings(sql, [difficulty, group, 1 if was_correct else 0, 0 if was_correct else 1])
	if not ok:
		push_error("[DB] record_answer failed: %s" % _db.error_message)

func get_accuracy(difficulty: String) -> Dictionary:
	var out := {}
	if _db == null:
		return out
	var ok := _db.query_with_bindings(
		'SELECT "group", correct, wrong FROM accuracy WHERE difficulty = ?', [difficulty])
	if not ok:
		push_error("[DB] get_accuracy failed: %s" % _db.error_message)
		return out
	for row in _db.query_result:
		out[String(row["group"])] = {"correct": int(row["correct"]), "wrong": int(row["wrong"])}
	return out
```

- [ ] **Step 4: Run test to verify it passes**

```bash
powershell -ExecutionPolicy Bypass -File tools\test.ps1
```

Expected: PASS. Confirm the `[Database]` block still ends with `throwaway db removed` — the new table must not break teardown.

- [ ] **Step 5: Commit**

```bash
git add scripts/Database.gd tools/smoke_test.gd
git commit -m "DB: per-group accuracy table and accessors"
```

---

## Task 7: ScoreKeeper

**Files:**
- Create: `scripts/ScoreKeeper.gd`
- Test: `tools/smoke_test.gd`

**Interfaces:**
- Consumes: nothing at runtime; the caller passes the difficulty multiplier in.
- Produces:
  - `func reset() -> void`
  - `func correct(group: String) -> int` — returns the points awarded
  - `func wrong(group: String) -> void`
  - `var score: int`, `var streak: int`, `var score_mult: int`
  - `func streak_mult() -> int`
  - `func tally() -> Dictionary` → `{group: {"correct": int, "wrong": int}}`
  - `func percent(group: String) -> int` — 0–100, and 0 when the group was never seen

- [ ] **Step 1: Write the failing test**

Add `_test_scoring()` to `tools/smoke_test.gd` and call it from `_initialize()` after `_test_nutrients()`:

```gdscript
# === ScoreKeeper: streaks reward knowing, not flailing ===
func _test_scoring() -> void:
	print("[ScoreKeeper]")
	var sk = load("res://scripts/ScoreKeeper.gd").new()
	sk.score_mult = 1

	_check(sk.streak_mult() == 1, "streak multiplier starts at 1")
	# Four correct answers is not yet a multiplier; the fifth is.
	for i in range(4):
		sk.correct("Go")
	_check(sk.streak_mult() == 1, "multiplier holds at 1 below five in a row")
	sk.correct("Go")
	_check(sk.streak_mult() == 2, "five in a row doubles the multiplier")

	# A wrong answer resets the streak but never the score.
	var before: int = sk.score
	sk.wrong("Go")
	_check(sk.streak == 0, "a wrong answer resets the streak")
	_check(sk.streak_mult() == 1, "multiplier falls back to 1")
	_check(sk.score == before, "a wrong answer does not cost points")

	# The multiplier is capped so a long run cannot run away with the score.
	sk.reset()
	for i in range(100):
		sk.correct("Glow")
	_check(sk.streak_mult() == 5, "multiplier caps at 5")

	# Points are base 10, scaled by difficulty and streak.
	sk.reset()
	sk.score_mult = 3
	_check(sk.correct("Grow") == 30, "first correct pays 10 x difficulty x 1")

	# Accuracy tally is per group and survives a reset boundary correctly.
	sk.reset()
	sk.correct("Go")
	sk.correct("Go")
	sk.wrong("Go")
	sk.wrong("Glow")
	_check(sk.percent("Go") == 67, "two of three rounds to 67 percent")
	_check(sk.percent("Glow") == 0, "all misses reads zero percent")
	_check(sk.percent("Grow") == 0, "an unseen group reads zero, not a crash")
	_check(int(sk.tally()["Go"]["wrong"]) == 1, "tally exposes raw counts")
```

- [ ] **Step 2: Run test to verify it fails**

```bash
powershell -ExecutionPolicy Bypass -File tools\test.ps1
```

Expected: FAIL — `res://scripts/ScoreKeeper.gd` does not exist.

- [ ] **Step 3: Write minimal implementation**

Create `scripts/ScoreKeeper.gd`:

```gdscript
extends Node
## Score, streak multiplier and per-group accuracy for ONE run.
## Deliberately free of engine and DB dependencies so tools/smoke_test.gd can
## exercise it headlessly. The Game scene owns an instance and forwards the
## tally to DB.record_answer as it goes.

const BASE_POINTS := 10
const STREAK_STEP := 5      # every N consecutive correct answers raises the multiplier
const STREAK_CAP := 5

var score: int = 0
var streak: int = 0
var score_mult: int = 1     # set from the difficulty table

var _tally: Dictionary = {}  # group -> {"correct": int, "wrong": int}

func reset() -> void:
	score = 0
	streak = 0
	_tally = {}

func streak_mult() -> int:
	return mini(1 + streak / STREAK_STEP, STREAK_CAP)

func correct(group: String) -> int:
	_bump(group, "correct")
	streak += 1
	var points: int = BASE_POINTS * score_mult * streak_mult()
	score += points
	return points

func wrong(group: String) -> void:
	_bump(group, "wrong")
	streak = 0

func tally() -> Dictionary:
	return _tally

# 0-100. An unseen group reads 0 rather than dividing by zero.
func percent(group: String) -> int:
	var row: Dictionary = _tally.get(group, {})
	var c: int = int(row.get("correct", 0))
	var w: int = int(row.get("wrong", 0))
	if c + w == 0:
		return 0
	return int(round(100.0 * float(c) / float(c + w)))

func _bump(group: String, key: String) -> void:
	if not _tally.has(group):
		_tally[group] = {"correct": 0, "wrong": 0}
	_tally[group][key] = int(_tally[group][key]) + 1
```

- [ ] **Step 4: Run test to verify it passes**

```bash
powershell -ExecutionPolicy Bypass -File tools\test.ps1
```

Expected: PASS.

Note on `streak_mult()`: `correct()` increments the streak **before** computing the multiplier, so the fifth consecutive answer is the one that pays double. That ordering is what the test pins.

- [ ] **Step 5: Commit**

```bash
git add scripts/ScoreKeeper.gd tools/smoke_test.gd
git commit -m "ScoreKeeper: streak multiplier and per-group accuracy"
```

---

## Task 8: Enemy carries its own weakness

**Files:**
- Modify: `scripts/Enemy.gd`, `scenes/Enemy.tscn`

**Interfaces:**
- Consumes: `GameData.random_nutrient_for`, `GameData.nutrient_group` from Task 4.
- Produces:
  - `var weakness: String` — the food group that defeats this monster
  - `var label_mode: String` — `"group"` or `"nutrient"`
  - `func setup(group: String, mode: String, spd: float, on_reach: Callable) -> void`
  - `func weakness_text() -> String` — what the monster displays

- [ ] **Step 1: Write the failing test**

Append to `_test_nutrients()` in `tools/smoke_test.gd` — this is pure logic, so the script is instanced directly without a scene:

```gdscript
	# A monster's displayed request must always resolve back to its weakness.
	var E = load("res://scripts/Enemy.gd").new()
	for group in gd.FOODS.keys():
		E.weakness = group
		E.label_mode = "group"
		_check(E.weakness_text().find(group.to_upper()) >= 0, "%s group label names the group" % group)
		E.label_mode = "nutrient"
		E.nutrient = gd.random_nutrient_for(group)
		_check(gd.nutrient_group(E.nutrient) == group, "%s nutrient request resolves to %s" % [group, group])
		_check(E.weakness_text() != "", "%s nutrient label is not blank" % group)
	E.free()
```

- [ ] **Step 2: Run test to verify it fails**

```bash
powershell -ExecutionPolicy Bypass -File tools\test.ps1
```

Expected: FAIL with `Invalid call ... 'weakness_text'`.

- [ ] **Step 3: Write minimal implementation**

Rewrite `scripts/Enemy.gd`. The key change from the old version is that nothing is looked up globally — the hero position and the reach callback are **injected** by the spawner, so this script no longer depends on `Main` being the active scene or on a node literally named `Hero`:

```gdscript
extends Area2D
## A Hunger Monster. Each one carries its OWN weakness (the food group that
## defeats it), which is what turns the game from one classification decision
## per level into one per monster.
##
## Nothing here reaches into the scene tree. The spawner injects the speed, the
## target position and the "I reached the hero" callback via setup().

var weakness: String = "Go"
var nutrient: String = ""        # only used when label_mode is "nutrient"
var label_mode: String = "group"
var speed: float = 70.0

var _target_x: float = 0.0
var _on_reach: Callable = Callable()
var _spent: bool = false

@onready var label: Label = $Label

func setup(group: String, mode: String, spd: float, target_x: float, on_reach: Callable) -> void:
	weakness = group
	label_mode = mode
	speed = spd
	_target_x = target_x
	_on_reach = on_reach
	if mode == "nutrient":
		nutrient = GameData.random_nutrient_for(group)
		# Grow only offers "+Protein"; if a group ever has none, fall back to
		# the group label rather than displaying an empty request.
		if nutrient == "":
			label_mode = "group"
	_refresh_label()

# What the player reads off the monster.
func weakness_text() -> String:
	if label_mode == "nutrient" and nutrient != "":
		return "needs %s" % nutrient.trim_prefix("+").to_upper()
	return weakness.to_upper()

func _refresh_label() -> void:
	if label != null:
		label.text = weakness_text()

func _process(delta: float) -> void:
	if _spent:
		return
	position.x += speed * delta
	if position.x >= _target_x:
		_spent = true
		if _on_reach.is_valid():
			_on_reach.call(self)
```

In `scenes/Enemy.tscn`, add a `Label` child named `Label` centred on the body, and set its `mouse_filter = 2` so it cannot swallow clicks. Keep the existing `CollisionShape2D`.

- [ ] **Step 4: Run test to verify it passes**

```bash
powershell -ExecutionPolicy Bypass -File tools\test.ps1
```

Expected: PASS. `weakness_text()` is called on a bare instance where `@onready` has not run, so `label` is `null` — `_refresh_label()` must null-guard, which it does.

- [ ] **Step 5: Commit**

```bash
git add scripts/Enemy.gd scenes/Enemy.tscn tools/smoke_test.gd
git commit -m "Enemy: per-monster weakness, injected references"
```

---

## Task 9: Food reads Layout and honours the colour tier

**Files:**
- Modify: `scripts/Food.gd`, `scripts/BeltManager.gd`

**Interfaces:**
- Consumes: `Layout.m` from Tasks 1–3; `DIFFICULTIES[tier]["show_food_color"]` from Task 5.
- Produces: `Food.set_food(group: String, coloured: bool) -> void`; `BeltManager` reads `Layout.m` instead of its own constants.

- [ ] **Step 1: Replace the hardcoded belt constants**

In `scripts/BeltManager.gd`, delete `STACK_FRONT_X`, `STACK_SPACING`, `ENTRY_X` and `BELT_H`, and read them from `Layout.m` at use sites:

```gdscript
# Layout owns every coordinate now; these were 1040.0 / 185.0 / -110.0 and only
# ever worked at exactly 16:9.
func _front_x() -> float:
	return Layout.m["stack_front_x"]

func _spacing() -> float:
	return Layout.m["stack_spacing"]

func _entry_base_x() -> float:
	return Layout.m["spawn_x"]
```

Replace every use of `STACK_FRONT_X` with `_front_x()`, `STACK_SPACING` with `_spacing()`, and `ENTRY_X` with `_entry_base_x()`. `MAX_FOODS` moves to `Layout.MAX_FOODS` and stays 6 on every device.

- [ ] **Step 2: Make food colour a difficulty tier**

In `scripts/Food.gd`, change `set_food` so the tint is opt-in:

```gdscript
# Assign this food a group, a random real name, and -- only on Easy -- the
# group colour. Medium and Hard render neutral so the player must read the name
# instead of matching a swatch. This is the single change that stops the game
# being winnable without reading.
const NEUTRAL := Color(0.86, 0.84, 0.78)

func set_food(group: String, coloured: bool) -> void:
	food_group = group
	var food_name: String = GameData.random_food(group)
	label.text = food_name
	rect.color = GameData.group_color(group) if coloured else NEUTRAL
	_apply_sprite(food_name)
```

In `BeltManager`, pass the tier flag when spawning:

```gdscript
	f.set_food(group, bool(GameData.difficulty_data().get("show_food_color", true)))
```

- [ ] **Step 3: Verify nothing regressed**

```bash
powershell -ExecutionPolicy Bypass -File tools\test.ps1
```

Expected: PASS, with `res://scenes/Main.tscn` still clean. `Layout.m` is populated in `Layout._ready()`, which runs before any scene because it is the first autoload.

- [ ] **Step 4: Commit**

```bash
git add scripts/Food.gd scripts/BeltManager.gd
git commit -m "Belt: read Layout coordinates, gate food colour by difficulty"
```

---

## Task 10: HudController

**Files:**
- Create: `scripts/HudController.gd`

**Interfaces:**
- Consumes: `ScoreKeeper` (Task 7), `GameData` run state.
- Produces:
  - `func bind(nodes: Dictionary) -> void` — keys `score`, `lives`, `highscore`, `level`, `target`, `hint`
  - `func refresh(ctx: Dictionary) -> void` — keys `level_name`, `boss_active`, `wave`, `total_waves`, `meal_left`
  - `func say(text: String, good: bool) -> void`

- [ ] **Step 1: Write the implementation**

Create `scripts/HudController.gd`. Every HUD string and colour lives here and nowhere else:

```gdscript
extends Node
## All HUD text and colour. Pulled out of the old 473-line Main.gd so the
## orchestrator never formats a string.

const GOOD := Color(0.10, 0.55, 0.15)
const BAD := Color(0.75, 0.10, 0.10)
const BOSS_COLOR := Color(0.42, 0.24, 0.52)

var _n: Dictionary = {}

func bind(nodes: Dictionary) -> void:
	_n = nodes

func say(text: String, good: bool) -> void:
	var hint: Label = _n.get("hint")
	if hint == null:
		return
	hint.text = text
	hint.add_theme_color_override("font_color", GOOD if good else BAD)

func refresh(ctx: Dictionary) -> void:
	_set("score", "Score: %d" % GameData.score)
	_set("lives", "Lives: %d" % GameData.lives)
	_set("highscore", "High Score: %d" % maxi(GameData.high_score, GameData.score))
	if GameData.tutorial_mode:
		_set("level", "TUTORIAL - learn the basics")
	else:
		_set("level", "Level %d: %s  [%s]" % [
			GameData.current_level, String(ctx.get("level_name", "")), GameData.current_difficulty])

	var target: Label = _n.get("target")
	if target == null:
		return
	if bool(ctx.get("boss_active", false)):
		target.text = "BOSS - build a meal!  Need: %s" % String(ctx.get("meal_left", ""))
		target.add_theme_color_override("font_color", BOSS_COLOR)
	else:
		# Per-monster weakness means there is no single level-wide target to
		# announce -- the monsters carry the question now.
		target.text = "Feed each monster what it asks for!"
		target.add_theme_color_override("font_color", Color(0.15, 0.15, 0.2))

func _set(key: String, text: String) -> void:
	var n: Label = _n.get(key)
	if n != null:
		n.text = text
```

- [ ] **Step 2: Verify it loads**

```bash
powershell -ExecutionPolicy Bypass -File tools\test.ps1
```

Expected: PASS — nothing references it yet, but a parse error would surface at import.

- [ ] **Step 3: Commit**

```bash
git add scripts/HudController.gd
git commit -m "HUD: extract all HUD text and colour from Main"
```

---

## Task 11: WaveDirector

**Files:**
- Create: `scripts/WaveDirector.gd`

**Interfaces:**
- Consumes: `GameData.is_boss_level`, `GameData.difficulty_data`, `Layout.m`, `Enemy.setup` (Task 8).
- Produces:
  - `func start(level: int, diff: Dictionary) -> void`
  - `func needed_groups() -> Array` — feeds the belt's solvability invariant
  - `func on_enemy_removed() -> void`
  - `signal wave_started(n: int, total: int)`, `signal level_cleared()`, `signal boss_ready()`

- [ ] **Step 1: Write the failing test**

Add to `_test_gamedata()` in `tools/smoke_test.gd`:

```gdscript
	# Hard mode must not ask for nutrients every single time, because Grow only
	# offers "+Protein" and the request would repeat constantly.
	var WD = load("res://scripts/WaveDirector.gd").new()
	var modes := {}
	for i in range(200):
		modes[WD.pick_label_mode("nutrient")] = true
	_check(modes.has("nutrient") and modes.has("group"), "Hard mixes nutrient and group requests")
	_check(WD.pick_label_mode("group") == "group", "Easy and Medium always ask by group")
	WD.free()
```

- [ ] **Step 2: Run test to verify it fails**

```bash
powershell -ExecutionPolicy Bypass -File tools\test.ps1
```

Expected: FAIL — `res://scripts/WaveDirector.gd` does not exist.

- [ ] **Step 3: Write minimal implementation**

Create `scripts/WaveDirector.gd`:

```gdscript
extends Node
## The level / wave / boss state machine, lifted out of Main.gd.
## Owns what spawns and when; owns nothing about scoring, HUD or effects.

signal wave_started(n: int, total: int)
signal level_cleared()
signal boss_ready()

const NUTRIENT_SHARE := 0.5   # fraction of Hard-mode monsters that ask by nutrient

var enemies_to_spawn: int = 0
var boss_level: bool = false
var wave: int = 0
var total_waves: int = 0

var _label_mode: String = "group"
var _alive_weaknesses: Array = []

# Hard asks for a nutrient only about half the time. Grow contributes a single
# unambiguous nutrient ("+Protein"), so an all-nutrient Hard mode would repeat
# it relentlessly -- see the spec, section 3.3.
func pick_label_mode(tier_mode: String) -> String:
	if tier_mode != "nutrient":
		return "group"
	return "nutrient" if randf() < NUTRIENT_SHARE else "group"

func start(level: int, diff: Dictionary) -> void:
	boss_level = GameData.is_boss_level(level)
	_label_mode = String(diff.get("monster_label", "group"))
	total_waves = GameData.BOSS_WAVES if boss_level else 1
	wave = 0
	_alive_weaknesses = []
	_next_wave(diff)

func _next_wave(diff: Dictionary) -> void:
	wave += 1
	var row: Dictionary = GameData.level_data(GameData.current_level)
	var count: int = GameData.BOSS_WAVE_SIZE if boss_level else int(row["enemies"])
	enemies_to_spawn = count + int(diff.get("enemy_bonus", 0))
	wave_started.emit(wave, total_waves)

# The belt's solvability invariant reads this: a food for every weakness on
# screen must always exist, or the level becomes unwinnable.
func needed_groups() -> Array:
	var out: Array = []
	for g in _alive_weaknesses:
		if not out.has(g):
			out.append(g)
	return out

func track(group: String) -> void:
	_alive_weaknesses.append(group)

func untrack(group: String) -> void:
	var i := _alive_weaknesses.find(group)
	if i >= 0:
		_alive_weaknesses.remove_at(i)

func on_enemy_removed() -> void:
	if enemies_to_spawn > 0 or not _alive_weaknesses.is_empty():
		return
	if boss_level and wave < total_waves:
		_next_wave(GameData.difficulty_data())
	elif boss_level:
		boss_ready.emit()
	else:
		level_cleared.emit()
```

- [ ] **Step 4: Run test to verify it passes**

```bash
powershell -ExecutionPolicy Bypass -File tools\test.ps1
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/WaveDirector.gd tools/smoke_test.gd
git commit -m "WaveDirector: level, wave and boss state machine"
```

---

## Task 12: Game orchestrator and the stun

**Files:**
- Create: `scripts/Game.gd`, `scenes/Game.tscn`
- Modify: `tools/test.ps1`

**Interfaces:**
- Consumes: every prior task.
- Produces: `func food_dropped_on_hero(food) -> bool` — the cross-script contract surface, returning `true` when the food is consumed and `false` when it should glide back.

- [ ] **Step 1: Build the scene**

Create `scenes/Game.tscn` mirroring the old `Main.tscn` node names so `FxManager` and `PauseMenu` keep working: a `Hero` Area2D as a **direct child** named exactly `Hero`, a `Foods` Node2D, a `Camera2D`, the HUD labels, and `PausePopup/Root`. Set `mouse_filter = 2` on the `Background` ColorRect and every Label, or they swallow the drag before physics picking sees it.

- [ ] **Step 2: Write the orchestrator**

Create `scripts/Game.gd`. The stun is the one mechanic that makes wrong answers cost something:

```gdscript
extends Node2D
## Plays exactly one level. A thin orchestrator: it wires the components
## together and owns the cross-script contract, nothing else.

const STUN_TIME := 1.0   # seconds the hero cannot feed after a wrong answer

var director: WaveDirector = null
var score_keeper: ScoreKeeper = null
var hud: HudController = null
var belt = null
var fx = null

var game_active: bool = false
var _stunned_until: float = 0.0

func _ready() -> void:
	get_viewport().physics_object_picking = true
	Layout.changed.connect(_reanchor)
	_reanchor()

func _is_stunned() -> bool:
	return Time.get_ticks_msec() / 1000.0 < _stunned_until

# Called by Food.gd when a food is dropped on the hero. Returns true if the
# food was consumed (remove it), false to glide it back.
func food_dropped_on_hero(food) -> bool:
	if not game_active or _is_stunned():
		return false
	var group: String = food.food_group
	var target = _closest_matching(group)
	if target == null:
		# Wrong in both senses -- no monster wants this, or none is present.
		# One path only: stun, streak reset, accuracy record.
		_punish(group, food.label.text)
		return false
	var points: int = score_keeper.correct(group)
	DB.record_answer(GameData.current_difficulty, group, true)
	GameData.score = score_keeper.score
	hud.say("Correct! %s is a %s food.  +%d" % [food.label.text, group, points], true)
	fx.play_attack(group, target.global_position)
	fx.nutrient_popup(GameData.food_nutrient(food.label.text), GameData.group_color(group))
	_despawn(target)
	return true

func _punish(group: String, food_name: String) -> void:
	score_keeper.wrong(group)
	DB.record_answer(GameData.current_difficulty, group, false)
	_stunned_until = Time.get_ticks_msec() / 1000.0 + STUN_TIME
	hud.say("Not what they asked for! %s is a %s food." % [food_name, group], false)
	Audio.play("wrong")
	fx.shake(4.0, 0.2)

func _closest_matching(group: String):
	var best = null
	var best_d := INF
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.weakness != group:
			continue
		var d: float = absf(e.global_position.x - Layout.m["hero_x"])
		if d < best_d:
			best_d = d
			best = e
	return best

func _reanchor() -> void:
	$Hero.position = Vector2(Layout.m["hero_x"], Layout.m["hero_y"])
```

- [ ] **Step 3: Point the test runner at the new scene**

In `tools/test.ps1`, replace `res://scenes/Main.tscn` with `res://scenes/Game.tscn` in step 3/5 and update the step label.

- [ ] **Step 4: Run the full check**

```bash
powershell -ExecutionPolicy Bypass -File tools\test.ps1
```

Expected: PASS with `Headless run: Game.tscn` clean. Remember `resource still in use: music.wav` on a `--quit-after` run is benign.

- [ ] **Step 5: Commit**

```bash
git add scripts/Game.gd scenes/Game.tscn tools/test.ps1
git commit -m "Game: orchestrator, per-monster targeting, wrong-answer stun"
```

---

## Task 13: Re-implement the systems the rebuild drops

**Files:**
- Modify: `scripts/Game.gd`, `scripts/PauseMenu.gd`, `scenes/Game.tscn`

A from-scratch rebuild silently loses working code. Each of these existed in the old build and must come back. Do them one at a time, running `tools\test.ps1` after each, and commit each separately.

- [ ] **Step 1: Boss fight**

Port `_spawn_boss`, `_feed_boss`, `_meal_needed` and `_boss_reached_hero` from the old `Main.gd`. While `_boss_active`, `food_dropped_on_hero` routes to `_feed_boss` and any group can be correct — a needed group lands a hit, a duplicate is rejected. Clearing all of `GameData.BOSS_MEAL_GROUPS` finishes the level with `BOSS_LESSON`.

```bash
git add scripts/Game.gd && git commit -m "Game: restore boss fight and balanced-meal mechanic"
```

- [ ] **Step 2: First-run tutorial**

Port the `TUTORIAL_PAGES` intro, `_tutorial_intro_active` rerouting `_on_continue_pressed`, and the single slow GO wave that starts only after the last page. Completing it sets `tutorial_done=1`, clears `tutorial_mode`, and goes to LevelSelect **without recording a result**.

```bash
git add scripts/Game.gd && git commit -m "Game: restore first-run tutorial"
```

- [ ] **Step 3: Pause overlay**

Keep `process_mode = 3` (ALWAYS) on `PausePopup/Root` — that is what keeps Esc handling and the buttons alive while the tree is paused. `PauseMenu` iterates `main.foods_container`, so `Game` must expose `foods_container`. Retry / Level Select / Main Menu **must unpause before `change_scene_to_file`** or the next scene loads frozen.

```bash
git add scripts/Game.gd scripts/PauseMenu.gd && git commit -m "Game: restore pause overlay"
```

- [ ] **Step 4: Verify all three**

```bash
powershell -ExecutionPolicy Bypass -File tools\test.ps1
```

Expected: PASS.

---

## Task 14: Result screen reports accuracy

**Files:**
- Modify: `scripts/ResultScreen.gd`, `scenes/ResultScreen.tscn`

**Interfaces:**
- Consumes: `DB.get_accuracy` (Task 6).

- [ ] **Step 1: Add the report**

Add a Label named `Accuracy` to `scenes/ResultScreen.tscn` with `mouse_filter = 2`, and populate it in `_ready()`:

```gdscript
func _accuracy_line() -> String:
	var acc: Dictionary = DB.get_accuracy(GameData.current_difficulty)
	if acc.is_empty():
		return ""
	var parts: Array = []
	var worst := ""
	var worst_pct := 101
	for group in ["Go", "Glow", "Grow"]:
		var row: Dictionary = acc.get(group, {})
		var c: int = int(row.get("correct", 0))
		var w: int = int(row.get("wrong", 0))
		if c + w == 0:
			continue
		var pct: int = int(round(100.0 * float(c) / float(c + w)))
		parts.append("%s %d%%" % [group, pct])
		if pct < worst_pct:
			worst_pct = pct
			worst = group
	if parts.is_empty():
		return ""
	var line: String = "  -  ".join(parts)
	if worst != "" and worst_pct < 80:
		line += "\nPractise your %s foods!" % worst
	return line
```

- [ ] **Step 2: Verify**

```bash
powershell -ExecutionPolicy Bypass -File tools\test.ps1
```

Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add scripts/ResultScreen.gd scenes/ResultScreen.tscn
git commit -m "Result: per-group accuracy report"
```

---

## Task 15: LevelSelect for 15 levels, and final verification

**Files:**
- Modify: `scripts/LevelSelect.gd`, `CLAUDE.md`

- [ ] **Step 1: Widen the grid**

`LevelSelect.gd` builds its grid dynamically from `DB.is_level_unlocked` / `DB.get_level_progress`, so 15 levels need no logic change — but the grid must wrap to a second row rather than overflowing the 1152-unit design width. Anchor the grid to `Layout.m["view"].x` and set `columns` so tiles stay at least 15mm wide. Every boss tile keeps its "BOSS n" badge and purple tint.

- [ ] **Step 2: Update the project documentation**

`CLAUDE.md` describes `Main.gd` as the controller, the `correct_group` model, the 6-level table and the `get_tree().current_scene` contract. All four are now wrong. Update those sections to describe `Game.gd`, per-monster weakness, 15 levels, the `Layout` autoload and injected references.

- [ ] **Step 3: Full verification**

```bash
powershell -ExecutionPolicy Bypass -File tools\test.ps1
```

Expected: `RESULT: PASS`.

- [ ] **Step 4: Verify what headless cannot**

Headless cannot simulate mouse drag. Open the project and press **F5**, then confirm by hand:
- drag works and a food glides back to its exact slot when dropped away from the hero
- a wrong food stuns the hero for about a second and the streak resets
- monsters display their weakness and the correct one dies
- zap / heal / slam effects and their sounds fire
- Easy shows coloured foods; Medium and Hard show neutral ones

- [ ] **Step 5: Device check (cannot be done on the dev machine)**

Safe-area insets are unverifiable headlessly — `DisplayServer.get_display_safe_area()` returns the whole desktop rect on Windows. Export an Android build and confirm the belt clears the gesture bar and the HUD clears the notch. Tune `Layout.BELT_INSET_B` if not.

- [ ] **Step 6: Commit**

```bash
git add scripts/LevelSelect.gd CLAUDE.md
git commit -m "LevelSelect: 15-level grid; docs: describe the rebuilt architecture"
```

---

## Self-Review

**Spec coverage:** §3.1 per-monster weakness → Tasks 8, 12. §3.2 difficulty ladder → Tasks 5, 9. §3.3 nutrient ambiguity → Tasks 4, 11. §3.4 stun → Task 12. §3.5 streak → Task 7. §3.6 accuracy → Tasks 6, 14. §3.7 content → Task 5. §4.1–4.2 Layout → Task 1. §4.3 safe areas → Tasks 2, 15. §4.4 spacing and solvability → Tasks 1, 9, 11. §4.6 project settings → Task 3. §5 architecture → Tasks 10, 11, 12. §5.1 fragile contract → Tasks 8, 12. §5.2 autoload order → Task 3. §5.3 dropped systems → Task 13. §6 data model → Task 6. §7 testing → every task.

**Known gap:** §4.5 touch targets needs no task — the spec's own arithmetic shows a 150-unit food lands near 15mm, above the ~9mm minimum, so there is nothing to change.

**Type consistency:** `weakness` / `label_mode` / `weakness_text()` are spelled identically in Tasks 8, 11 and 12. `Layout.m` keys are spelled identically in Tasks 1, 2, 9 and 12. `record_answer(difficulty, group, was_correct)` matches between Tasks 6, 12 and 14.
