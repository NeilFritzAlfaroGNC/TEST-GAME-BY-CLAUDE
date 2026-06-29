extends Node
## Autoload ("DB"). Local, offline persistence for Food Heroes.
##
## Primary backend is SQLite via the `godot-sqlite` GDExtension
## (https://github.com/2shady4u/godot-sqlite). That plugin ships a native
## binary, so it is NOT bundled here. If it is installed, this layer opens
## `user://foodheroes.db` and logs scores/progress there. If it is NOT
## installed, it transparently falls back to a JSON file so the game still
## saves and never crashes.
##
## The SQLite class is reached by *string* (ClassDB) on purpose, so this
## script parses and runs whether or not the plugin is present.

const DB_PATH := "user://foodheroes.db"
const JSON_PATH := "user://foodheroes_save.json"
const MAX_RUNS_JSON := 50

var backend: String = "json"   # "sqlite" once a connection is open
var _db = null                 # the SQLite instance (Object) when in sqlite mode

func _ready() -> void:
	_open()

func _open() -> void:
	if ClassDB.class_exists("SQLite"):
		var inst = ClassDB.instantiate("SQLite")
		if inst != null:
			inst.path = DB_PATH
			if inst.open_db():
				_db = inst
				backend = "sqlite"
				_ensure_schema()
				print("[DB] SQLite connected: ", DB_PATH)
				return
	backend = "json"
	print("[DB] godot-sqlite not installed - using JSON fallback: ", JSON_PATH)

func _ensure_schema() -> void:
	_db.query("CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT);")
	_db.query(
		"CREATE TABLE IF NOT EXISTS runs (" +
		"id INTEGER PRIMARY KEY AUTOINCREMENT, " +
		"score INTEGER, result TEXT, level_reached INTEGER, played_at TEXT);"
	)
	_migrate_json_high_score()

# One-time carry-over: if the SQLite DB has no high score yet but an old JSON
# save exists, import its high score so switching backends doesn't lose it.
func _migrate_json_high_score() -> void:
	if _meta_get_int("high_score", 0) > 0:
		return
	if not FileAccess.file_exists(JSON_PATH):
		return
	var hs := int(_json_load().get("high_score", 0))
	if hs > 0:
		_db.query_with_bindings(
			"INSERT INTO meta (key, value) VALUES ('high_score', ?) " +
			"ON CONFLICT(key) DO UPDATE SET value = excluded.value;",
			[str(hs)]
		)
		print("[DB] migrated high score from JSON -> SQLite: ", hs)

# === Public API ===

# Record one finished run and bump the high score.
func record_run(score: int, result: String, level_reached: int) -> void:
	var stamp := Time.get_datetime_string_from_system()
	if backend == "sqlite":
		_db.query_with_bindings(
			"INSERT INTO runs (score, result, level_reached, played_at) VALUES (?, ?, ?, ?);",
			[score, result, level_reached, stamp]
		)
		var hs: int = maxi(score, _meta_get_int("high_score", 0))
		_db.query_with_bindings(
			"INSERT INTO meta (key, value) VALUES ('high_score', ?) " +
			"ON CONFLICT(key) DO UPDATE SET value = excluded.value;",
			[str(hs)]
		)
	else:
		var data := _json_load()
		var runs: Array = data.get("runs", [])
		runs.append({"score": score, "result": result, "level_reached": level_reached, "played_at": stamp})
		if runs.size() > MAX_RUNS_JSON:
			runs = runs.slice(runs.size() - MAX_RUNS_JSON)
		data["runs"] = runs
		data["high_score"] = maxi(score, int(data.get("high_score", 0)))
		_json_save(data)

func get_high_score() -> int:
	if backend == "sqlite":
		return _meta_get_int("high_score", 0)
	return int(_json_load().get("high_score", 0))

# Most recent runs first. Each entry: {score, result, level_reached, played_at}.
func get_recent_runs(limit: int = 5) -> Array:
	if backend == "sqlite":
		_db.query_with_bindings(
			"SELECT score, result, level_reached, played_at FROM runs ORDER BY id DESC LIMIT ?;",
			[limit]
		)
		var rows = _db.query_result
		return rows.duplicate() if rows is Array else []
	var all: Array = _json_load().get("runs", [])
	var recent := all.duplicate()
	recent.reverse()
	return recent.slice(0, limit)

# === SQLite helpers ===
func _meta_get_int(key: String, def: int) -> int:
	_db.query_with_bindings("SELECT value FROM meta WHERE key = ?;", [key])
	var rows = _db.query_result
	if rows is Array and rows.size() > 0:
		return int(rows[0]["value"])
	return def

# === JSON fallback helpers ===
func _json_load() -> Dictionary:
	if not FileAccess.file_exists(JSON_PATH):
		return {}
	var f := FileAccess.open(JSON_PATH, FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}

func _json_save(data: Dictionary) -> void:
	var f := FileAccess.open(JSON_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data))
		f.close()

func _exit_tree() -> void:
	if backend == "sqlite" and _db != null:
		_db.close_db()
