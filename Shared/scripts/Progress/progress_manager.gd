
extends Node

# ==================================================
# FOOD HEROES — PROGRESS MANAGER
# ==================================================

const SAVE_PATH: String = "user://food_heroes_progress.cfg"

const CAFETERIA_LEVEL_ID: String = "cafeteria_level_1"
const CANTEEN_LEVEL_ID: String = "canteen_level_2"

const REQUIRED_CANTEEN_UNLOCK_STARS: int = 1
const REQUIRED_HARD_UNLOCK_STARS: int = 1

var progress: Dictionary = {
	"easy": {},
	"normal": {},
	"hard": {}
}

var current_difficulty: String = "easy"
var current_run_stars: int = 0
var last_completed_level_id: String = ""


# ==================================================
# INITIALIZATION
# ==================================================

func _ready() -> void:
	load_progress()


# ==================================================
# VALIDATE DIFFICULTY
# ==================================================

func is_valid_difficulty(difficulty: String) -> bool:
	return progress.has(difficulty)


# ==================================================
# CALCULATE STARS
# ==================================================

func calculate_stars(total_hits: int) -> int:
	if total_hits == 0:
		return 3
	elif total_hits == 1:
		return 2
	elif total_hits == 2:
		return 1
	else:
		return 0


# ==================================================
# SAVE LEVEL STARS
# ==================================================

func save_level_stars(
	difficulty: String,
	level_id: String,
	stars: int
) -> void:
	if not is_valid_difficulty(difficulty):
		push_warning(
			"[Progress] Unknown difficulty: " + difficulty
		)
		return

	if level_id.is_empty():
		push_warning("[Progress] Level ID is empty.")
		return

	last_completed_level_id = level_id

	var valid_stars: int = clampi(stars, 0, 3)

	var previous_stars: int = get_level_stars(
		difficulty,
		level_id
	)

	if valid_stars > previous_stars:
		progress[difficulty][level_id] = valid_stars

		save_progress()

		print(
			"[Progress] Saved ",
			valid_stars,
			" stars for ",
			level_id,
			" (",
			difficulty,
			")"
		)


# ==================================================
# GET LEVEL STARS
# ==================================================

func get_level_stars(
	difficulty: String,
	level_id: String
) -> int:
	if not is_valid_difficulty(difficulty):
		return 0

	return int(
		progress[difficulty].get(level_id, 0)
	)


# ==================================================
# CANTEEN UNLOCK
# ==================================================

func is_canteen_unlocked() -> bool:
	var easy_stars: int = get_level_stars(
		"easy",
		CAFETERIA_LEVEL_ID
	)

	var normal_stars: int = get_level_stars(
		"normal",
		CAFETERIA_LEVEL_ID
	)

	return (
		easy_stars >= REQUIRED_CANTEEN_UNLOCK_STARS
		or normal_stars >= REQUIRED_CANTEEN_UNLOCK_STARS
	)


# ==================================================
# HARD UNLOCK
# ==================================================

func is_hard_unlocked() -> bool:
	var canteen_normal_stars: int = get_level_stars(
		"normal",
		CANTEEN_LEVEL_ID
	)

	return (
		canteen_normal_stars >= REQUIRED_HARD_UNLOCK_STARS
	)


# ==================================================
# SET CURRENT DIFFICULTY
# ==================================================

func set_current_difficulty(difficulty: String) -> bool:
	if not is_valid_difficulty(difficulty):
		push_warning(
			"[Progress] Invalid difficulty: " + difficulty
		)
		return false

	if difficulty == "hard" and not is_hard_unlocked():
		push_warning(
			"[Progress] Hard difficulty is locked."
		)
		return false

	current_difficulty = difficulty

	print(
		"[Progress] Current difficulty: ",
		current_difficulty
	)

	return true


# ==================================================
# SAVE PROGRESS
# ==================================================

func save_progress() -> void:
	var config := ConfigFile.new()

	for difficulty in progress:
		for level_id in progress[difficulty]:
			config.set_value(
				difficulty,
				level_id,
				progress[difficulty][level_id]
			)

	var error: Error = config.save(SAVE_PATH)

	if error != OK:
		push_error(
			"[Progress] Could not save progress. Error: %s"
			% error
		)
	else:
		print("[Progress] Progress saved.")


# ==================================================
# LOAD PROGRESS
# ==================================================

func load_progress() -> void:
	var config := ConfigFile.new()

	var error: Error = config.load(SAVE_PATH)

	if error != OK:
		print(
			"[Progress] No saved progress found. "
			+ "Starting fresh."
		)
		return

	for difficulty in progress:
		progress[difficulty] = {}

		if not config.has_section(difficulty):
			continue

		for level_id in config.get_section_keys(difficulty):
			progress[difficulty][level_id] = clampi(
				int(
					config.get_value(
						difficulty,
						level_id,
						0
					)
				),
				0,
				3
			)

	print("[Progress] Progress loaded.")

	print(
		"[Progress] Canteen unlocked: ",
		is_canteen_unlocked()
	)

	print(
		"[Progress] Hard unlocked: ",
		is_hard_unlocked()
	)
