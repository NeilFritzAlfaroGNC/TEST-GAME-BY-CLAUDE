extends Node
## Autoload ("DB"). Local, offline persistence for Food Heroes.
##
## Backend is SQLite via the `godot-sqlite` GDExtension
## (https://github.com/2shady4u/godot-sqlite), whose binary is committed in
## `addons/godot-sqlite/`. This opens `user://foodheroes.db` and logs
## scores/progress there.
##
## The SQLite class is reached by *string* (ClassDB) rather than a typed
## `SQLite` reference, so this script still parses even if the native
## extension is ever removed. There is NO fallback backend: if the extension
## is missing or the database cannot open, `_fail()` alerts the player and
## quits. These are runtime checks (not `assert`s) on purpose — asserts are
## compiled out of release exports and the failure must stay loud there too.
## `quit()` only takes effect at the end of the frame, so every query helper
## also guards `_db == null` and public methods return safe defaults instead
## of crashing while the quit is pending.

const DB_PATH := "user://foodheroes.db"

# Overridable before entering the tree — the smoke test points this at a
# throwaway file so it never touches real progress.
var db_file: String = DB_PATH

var _db = null   # the SQLite instance (Object)

func _ready() -> void:
	_open()

func _open() -> void:
	if not ClassDB.class_exists("SQLite"):
		_fail("The godot-sqlite extension is missing from addons/godot-sqlite/.")
		return
	var inst = ClassDB.instantiate("SQLite")
	if inst == null:
		_fail("The SQLite extension class could not be instantiated.")
		return
	inst.path = db_file
	if not inst.open_db():
		_fail("Could not open the save database at %s." % db_file)
		return
	_db = inst
	_ensure_schema()
	print("[DB] SQLite connected: ", db_file)

# Loud, release-safe failure: report the problem and close the game rather
# than silently running without saves.
func _fail(msg: String) -> void:
	push_error("[DB] " + msg)
	OS.alert(msg + "\n\nFood Heroes needs its save database and will close.", "Food Heroes - save error")
	get_tree().quit(1)

# === Generic persisted settings (stored in the meta table) ===

func get_setting_int(key: String, def: int) -> int:
	return _meta_get_int(key, def)

func set_setting_int(key: String, value: int) -> void:
	_exec_bound(
		"INSERT INTO meta (key, value) VALUES (?, ?) " +
		"ON CONFLICT(key) DO UPDATE SET value = excluded.value;",
		[key, str(value)]
	)

func _ensure_schema() -> void:
	_exec("CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT);")
	# The per-run history (recent scores) has been removed entirely — drop it
	# from any existing database as well.
	_exec("DROP TABLE IF EXISTS runs;")
	# Per-(difficulty, level) progress: best score, best stars, completed flag.
	_exec(
		"CREATE TABLE IF NOT EXISTS progress (" +
		"difficulty TEXT, level INTEGER, best_score INTEGER DEFAULT 0, " +
		"stars INTEGER DEFAULT 0, completed INTEGER DEFAULT 0, " +
		"PRIMARY KEY (difficulty, level));"
	)
	# Per-(difficulty, group) accuracy: the evidence-of-learning record.
	# "group" is a reserved SQL word and must stay quoted everywhere it appears.
	_exec("""
		CREATE TABLE IF NOT EXISTS accuracy (
			difficulty TEXT NOT NULL,
			"group"    TEXT NOT NULL,
			correct    INTEGER NOT NULL DEFAULT 0,
			wrong      INTEGER NOT NULL DEFAULT 0,
			PRIMARY KEY (difficulty, "group")
		)""")

# === Public API ===

func get_high_score() -> int:
	return _meta_get_int("high_score", 0)

func _set_high_score(score: int) -> void:
	var hs: int = maxi(score, _meta_get_int("high_score", 0))
	_exec_bound(
		"INSERT INTO meta (key, value) VALUES ('high_score', ?) " +
		"ON CONFLICT(key) DO UPDATE SET value = excluded.value;",
		[str(hs)]
	)

# === Per-level progress (the campaign state) ===

# Record the outcome of one level: bumps the high score and upserts the best
# score / best stars / completed flag for (difficulty, level).
func record_level_result(difficulty: String, level: int, score: int, stars: int, won: bool) -> void:
	_set_high_score(score)
	var done := 1 if won else 0
	_exec_bound(
		"INSERT INTO progress (difficulty, level, best_score, stars, completed) " +
		"VALUES (?, ?, ?, ?, ?) " +
		"ON CONFLICT(difficulty, level) DO UPDATE SET " +
		"best_score = MAX(best_score, excluded.best_score), " +
		"stars = MAX(stars, excluded.stars), " +
		"completed = MAX(completed, excluded.completed);",
		[difficulty, level, score, stars, done]
	)

# Returns {best_score, stars, completed} for a level (zeros if never played).
func get_level_progress(difficulty: String, level: int) -> Dictionary:
	if _exec_bound(
		"SELECT best_score, stars, completed FROM progress WHERE difficulty = ? AND level = ?;",
		[difficulty, level]
	):
		var rows = _db.query_result
		if rows is Array and rows.size() > 0:
			var r = rows[0]
			return {"best_score": int(r["best_score"]), "stars": int(r["stars"]), "completed": int(r["completed"])}
	return {"best_score": 0, "stars": 0, "completed": 0}

# Level 1 is always open; later levels open once the previous one is completed.
func is_level_unlocked(difficulty: String, level: int) -> bool:
	if level <= 1:
		return true
	return get_level_progress(difficulty, level - 1)["completed"] > 0

# === Per-group accuracy (evidence of learning) ===

# Records one answer against its food group. Fire-and-forget: a failure here
# must never interrupt play, so it logs and returns.
func record_answer(difficulty: String, group: String, was_correct: bool) -> void:
	if _db == null:
		return
	var col := "correct" if was_correct else "wrong"
	var sql := """
		INSERT INTO accuracy (difficulty, "group", correct, wrong) VALUES (?, ?, ?, ?)
		ON CONFLICT(difficulty, "group") DO UPDATE SET %s = %s + 1""" % [col, col]
	var ok: bool = _db.query_with_bindings(sql, [difficulty, group, 1 if was_correct else 0, 0 if was_correct else 1])
	if not ok:
		push_error("[DB] record_answer failed: %s" % _db.error_message)

func get_accuracy(difficulty: String) -> Dictionary:
	var out := {}
	if _db == null:
		return out
	var ok: bool = _db.query_with_bindings(
		'SELECT "group", correct, wrong FROM accuracy WHERE difficulty = ?', [difficulty])
	if not ok:
		push_error("[DB] get_accuracy failed: %s" % _db.error_message)
		return out
	for row in _db.query_result:
		out[String(row["group"])] = {"correct": int(row["correct"]), "wrong": int(row["wrong"])}
	return out

# === SQLite helpers ===
# Both return true only if the DB is open AND the statement succeeded, and
# push_error on failure so broken SQL never fails silently.
func _exec(sql: String) -> bool:
	if _db == null:
		return false
	if not _db.query(sql):
		push_error("[DB] query failed: %s (%s)" % [sql, str(_db.error_message)])
		return false
	return true

func _exec_bound(sql: String, bindings: Array) -> bool:
	if _db == null:
		return false
	if not _db.query_with_bindings(sql, bindings):
		push_error("[DB] query failed: %s (%s)" % [sql, str(_db.error_message)])
		return false
	return true

func _meta_get_int(key: String, def: int) -> int:
	if _exec_bound("SELECT value FROM meta WHERE key = ?;", [key]):
		var rows = _db.query_result
		if rows is Array and rows.size() > 0:
			return int(rows[0]["value"])
	return def

func _exit_tree() -> void:
	if _db != null:
		_db.close_db()
