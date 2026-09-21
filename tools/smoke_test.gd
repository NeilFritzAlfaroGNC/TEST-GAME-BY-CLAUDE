extends SceneTree
## Headless logic smoke test. Run with:
##   & "C:\SHIZ\Godot_v4.6.3-stable_win64.exe" --headless --path "D:\TEST" -s res://tools/smoke_test.gd
## (or via tools/test.ps1, which also does the headless scene runs.)
##
## Exit code 0 = every check passed, 1 = failures (look for "FAIL" lines).
## Covers the pure logic + the DB layer against a THROWAWAY database file —
## it never touches the real user://foodheroes.db. Scene behavior (drag,
## spawning, effects) is covered by the headless scene runs, not here.
##
## NOTE: this runs in script mode, so autoload singletons (DB/GameData/Audio)
## are NOT instantiated. Scripts are loaded and instanced manually, and only
## code paths that don't touch other autoloads are exercised.

const TEST_DB := "user://smoke_test.db"

var _fails: int = 0

func _initialize() -> void:
	_test_gamedata()
	_test_layout()
	_test_database()
	if _fails == 0:
		print("SMOKE TEST: ALL PASS")
	else:
		print("SMOKE TEST: %d FAILURE(S)" % _fails)
	quit(1 if _fails > 0 else 0)

func _check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   - ", what)
	else:
		_fails += 1
		printerr("  FAIL - ", what)

# === GameData: pure logic (never enters the tree, so _ready/DB is not hit) ===
func _test_gamedata() -> void:
	print("[GameData]")
	var gd = load("res://scripts/GameData.gd").new()

	# Boss cadence.
	_check(gd.is_boss_level(5) and gd.is_boss_level(10), "every 5th level is a boss")
	_check(not (gd.is_boss_level(1) or gd.is_boss_level(4) or gd.is_boss_level(6)), "1/4/6 are not boss levels")

	# level_data clamps out-of-range numbers instead of crashing.
	_check(gd.level_data(0) == gd.LEVELS[0], "level_data clamps low")
	_check(gd.level_data(999) == gd.LEVELS[gd.LEVELS.size() - 1], "level_data clamps high")

	# Star math across every difficulty's starting lives.
	for diff in gd.DIFFICULTY_ORDER:
		var lives_start: int = int(gd.DIFFICULTIES[diff]["lives"])
		gd.starting_lives = lives_start
		gd.lives = lives_start
		_check(gd._compute_stars(true) == 3, "%s: no lives lost -> 3 stars" % diff)
		gd.lives = 0
		_check(gd._compute_stars(false) == 0, "%s: loss -> 0 stars" % diff)
		gd.lives = int(ceil(lives_start / 2.0))
		_check(gd._compute_stars(true) == 2, "%s: kept half -> 2 stars" % diff)
		if lives_start >= 3:
			gd.lives = 1
			_check(gd._compute_stars(true) == 1, "%s: barely survived -> 1 star" % diff)

	# Every food in FOODS must have a nutrient (the popup relies on it).
	var missing := []
	for group in gd.FOODS:
		for food_name in gd.FOODS[group]:
			if not gd.FOOD_NUTRIENTS.has(food_name):
				missing.append(food_name)
	_check(missing.is_empty(), "every food has a nutrient" + ("" if missing.is_empty() else " (missing: %s)" % str(missing)))

	# Difficulty tables must stay complete — Main reads all five keys.
	for diff in gd.DIFFICULTY_ORDER:
		var d: Dictionary = gd.DIFFICULTIES[diff]
		_check(d.has_all(["lives", "speed_mult", "spawn_mult", "enemy_bonus", "score_mult"]),
			"%s difficulty has all five modifiers" % diff)

	# Boss meal groups must all exist in FOODS (or the boss is unbeatable).
	var meal_ok := true
	for g in gd.BOSS_MEAL_GROUPS:
		if not gd.FOODS.has(g):
			meal_ok = false
	_check(meal_ok, "boss meal groups all exist in FOODS")

	# Shared star string.
	_check(gd.stars_text(0) == "---" and gd.stars_text(2) == "**-", "stars_text formats")
	_check(gd.stars_text(99) == "***" and gd.stars_text(-5) == "---", "stars_text clamps")

	# Tutorial state transitions (pure — no DB involved).
	gd.start_tutorial()
	_check(gd.tutorial_mode and gd.lives == 5 and gd.score == 0 and gd.current_difficulty == "Easy",
		"start_tutorial primes a fresh guided run")
	gd.start_level("Medium", 2)
	_check(not gd.tutorial_mode, "start_level clears tutorial_mode")

	gd.free()

# === Layout: pure geometry at every shipped aspect ===
func _test_layout() -> void:
	print("[Layout]")
	var L = load("res://scripts/Layout.gd")

	# Scale is the smaller of the two axis ratios; with a fixed 648 design
	# height in landscape that is always the height ratio.
	_check(is_equal_approx(L.design_scale(Vector2(1152, 648), L.BASE), 1.0), "scale is 1.0 at the design size")
	_check(is_equal_approx(L.design_scale(Vector2(2400, 1080), L.BASE), 1080.0 / 648.0), "scale follows the height ratio")

	# Visible width grows with the device; height stays at the design 648.
	var vis: Vector2 = L.visible_size(Vector2(2400, 1080), L.BASE)
	_check(is_equal_approx(vis.y, 648.0), "visible height stays 648")
	_check(int(round(vis.x)) == 1440, "20:9 reveals 1440 design units of width")

	# Every shipped aspect must produce a sane, ordered play field.
	var windows := [Vector2(1152, 648), Vector2(2556, 1179), Vector2(2400, 1080), Vector2(2520, 1080)]
	for w in windows:
		var v: Vector2 = L.visible_size(w, L.BASE)
		var safe: Rect2 = Rect2(Vector2.ZERO, v)          # no insets: the desktop case
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

# === Database: real SQLite roundtrip against a throwaway file ===
func _test_database() -> void:
	print("[Database]")
	_remove_test_db()

	var db = load("res://scripts/Database.gd").new()
	db.db_file = TEST_DB
	# Call _open() directly: the node never enters the tree, so _ready would
	# not run during _initialize (and the real DB autoload must stay untouched).
	db._open()
	_check(db._db != null, "sqlite opened (throwaway db)")
	if db._db == null:
		db.free()
		return

	# Fresh DB defaults.
	_check(db.get_high_score() == 0, "fresh high score is 0")
	var p: Dictionary = db.get_level_progress("Easy", 1)
	_check(int(p["best_score"]) == 0 and int(p["completed"]) == 0, "fresh progress is zeroed")
	_check(db.is_level_unlocked("Easy", 1), "level 1 always unlocked")
	_check(not db.is_level_unlocked("Easy", 2), "level 2 locked at start")

	# Record a win: unlock chain + high score.
	db.record_level_result("Easy", 1, 120, 2, true)
	_check(db.get_high_score() == 120, "high score recorded")
	_check(db.is_level_unlocked("Easy", 2), "clearing level 1 unlocks level 2")
	_check(not db.is_level_unlocked("Medium", 2), "unlocks are per difficulty")

	# A worse retry must never lower the stored bests.
	db.record_level_result("Easy", 1, 50, 1, false)
	p = db.get_level_progress("Easy", 1)
	_check(int(p["best_score"]) == 120 and int(p["stars"]) == 2 and int(p["completed"]) == 1,
		"worse retry keeps best score/stars/completed")

	# A better retry raises them.
	db.record_level_result("Easy", 1, 300, 3, true)
	p = db.get_level_progress("Easy", 1)
	_check(int(p["best_score"]) == 300 and int(p["stars"]) == 3, "better retry raises bests")
	_check(db.get_high_score() == 300, "high score follows the best run")

	# Generic settings roundtrip (used by the mute toggle).
	db.set_setting_int("muted", 1)
	_check(db.get_setting_int("muted", 0) == 1, "settings roundtrip (muted=1)")
	db.set_setting_int("muted", 0)
	_check(db.get_setting_int("muted", 1) == 0, "settings roundtrip (muted=0)")

	db._db.close_db()   # never entered the tree, so close explicitly
	db.free()
	_remove_test_db()
	_check(not FileAccess.file_exists(TEST_DB), "throwaway db removed")

func _remove_test_db() -> void:
	var gpath := ProjectSettings.globalize_path(TEST_DB)
	if FileAccess.file_exists(gpath):
		DirAccess.remove_absolute(gpath)
