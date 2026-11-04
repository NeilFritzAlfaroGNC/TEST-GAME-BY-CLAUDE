
extends Node

const SAVE_PATH = "user://food_heroes_progress.cfg"

var progress = {
	"easy": {},
	"normal": {}
}

var current_difficulty: String = "easy"
var current_run_stars: int = 0


func _ready() -> void:
	load_progress()


func calculate_stars(total_hits: int) -> int:
	if total_hits == 0:
		return 3
	elif total_hits == 1:
		return 2
	elif total_hits == 2:
		return 1
	else:
		return 0


func save_level_stars(difficulty: String, level_id: String, stars: int) -> void:
	if not progress.has(difficulty):
		return

	var previous_stars: int = get_level_stars(difficulty, level_id)

	if stars > previous_stars:
		progress[difficulty][level_id] = stars
		save_progress()
		print("[Progress] Saved ", stars, " stars for ", level_id, " (", difficulty, ")")


func get_level_stars(difficulty: String, level_id: String) -> int:
	if not progress.has(difficulty):
		return 0

	return progress[difficulty].get(level_id, 0)


func save_progress() -> void:
	var config := ConfigFile.new()

	for difficulty in progress:
		for level_id in progress[difficulty]:
			config.set_value(difficulty, level_id, progress[difficulty][level_id])

	var error := config.save(SAVE_PATH)

	if error != OK:
		push_error("[Progress] Could not save progress. Error: %s" % error)
	else:
		print("[Progress] Progress saved.")


func load_progress() -> void:
	var config := ConfigFile.new()
	var error := config.load(SAVE_PATH)

	if error != OK:
		print("[Progress] No saved progress found. Starting fresh.")
		return

	for difficulty in progress:
		if not config.has_section(difficulty):
			continue

		for level_id in config.get_section_keys(difficulty):
			progress[difficulty][level_id] = config.get_value(difficulty, level_id, 0)

	print("[Progress] Progress loaded.")
