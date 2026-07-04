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
## extension is ever removed (it will simply fail loudly at `_ready`).

const DB_PATH := "user://foodheroes.db"

var _db = null   # the SQLite instance (Object)

func _ready() -> void:
	_open()

func _open() -> void:
	assert(ClassDB.class_exists("SQLite"), "godot-sqlite extension is missing from addons/godot-sqlite/")
	var inst = ClassDB.instantiate("SQLite")
	inst.path = DB_PATH
	var ok: bool = inst.open_db()
	assert(ok, "Failed to open SQLite database at " + DB_PATH)
	_db = inst
	_ensure_schema()
	print("[DB] SQLite connected: ", DB_PATH)

func _ensure_schema() -> void:
	_db.query("CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT);")
	# The per-run history (recent scores) has been removed entirely — drop it
	# from any existing database as well.
	_db.query("DROP TABLE IF EXISTS runs;")
	# Per-(difficulty, level) progress: best score, best stars, completed flag.
	_db.query(
		"CREATE TABLE IF NOT EXISTS progress (" +
		"difficulty TEXT, level INTEGER, best_score INTEGER DEFAULT 0, " +
		"stars INTEGER DEFAULT 0, completed INTEGER DEFAULT 0, " +
		"PRIMARY KEY (difficulty, level));"
	)

# === Public API ===

func get_high_score() -> int:
	return _meta_get_int("high_score", 0)

func _set_high_score(score: int) -> void:
	var hs: int = maxi(score, _meta_get_int("high_score", 0))
	_db.query_with_bindings(
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
	_db.query_with_bindings(
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
	_db.query_with_bindings(
		"SELECT best_score, stars, completed FROM progress WHERE difficulty = ? AND level = ?;",
		[difficulty, level]
	)
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

# === SQLite helpers ===
func _meta_get_int(key: String, def: int) -> int:
	_db.query_with_bindings("SELECT value FROM meta WHERE key = ?;", [key])
	var rows = _db.query_result
	if rows is Array and rows.size() > 0:
		return int(rows[0]["value"])
	return def

func _exit_tree() -> void:
	if _db != null:
		_db.close_db()
