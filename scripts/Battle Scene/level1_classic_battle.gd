extends "res://scripts/Battle Scene/battle_scene_canteen.gd"
class_name Level1ClassicBattle

# ==================================================
# LEVEL 1 — ORIGINAL FOOD COMBAT GAMEPLAY
# GODOT 4.7.1
# ==================================================
#
# Inherits the original Canteen gameplay.
#
# PRESERVED MECHANICS:
# - Food dragging
# - Food inspection
# - Long-press food inspection
# - Food combinations
# - Feeding the player
# - Original HP-based combat
# - Enemy completion handling
# - Victory screen transition
#
# LEVEL 1 ADAPTATIONS:
# - Level 1 identity
# - Level 1 progress saving
# - Level 1 victory messages
#
# Does not change existing scenes,
# progression scripts, or save files.
# ==================================================


# ==================================================
# LEVEL 1 PROGRESSION
# ==================================================

const LEVEL1_PROGRESS_ID: String = "cafeteria_level_1"


# ==================================================
# INITIALIZATION
# ==================================================

func _ready() -> void:

	_create_food_inspector()

	call_deferred("_find_scene_references")

	set_process(true)
	set_process_input(true)

	print("")
	print("===================================")
	print("[Level1] Original food combat ready.")
	print("[Level1] Food inspection enabled.")
	print("[Level1] Food combinations enabled.")
	print("[Level1] HP-based gameplay prepared.")
	print("[Level1] Progress ID: ", LEVEL1_PROGRESS_ID)
	print("===================================")


# ==================================================
# LEVEL 1 COMPLETION
# ==================================================

func _on_level_completed() -> void:

	if level_completion_started:
		return

	level_completion_started = true

	long_press_active = false
	long_press_triggered = false

	_hide_food_inspector()

	print("[Level1] All required enemies defeated.")

	# ----------------------------------------------
	# VALIDATE PLAYER
	# ----------------------------------------------

	if not is_instance_valid(main_character):

		push_error(
			"[Level1] Cannot calculate stars: "
			+ "Player is missing."
		)

		level_completion_started = false
		return

	# ----------------------------------------------
	# COUNT PLAYER HITS
	# ----------------------------------------------

	var total_hits: int = int(
		main_character.get("total_hits_received")
	)

	# ----------------------------------------------
	# CALCULATE STARS
	# ----------------------------------------------

	var earned_stars: int = (
		ProgressManager.calculate_stars(
			total_hits
		)
	)

	# ----------------------------------------------
	# SET CURRENT RUN RATING
	# ----------------------------------------------

	ProgressManager.current_run_stars = earned_stars

	print(
		"[Level1] Hits received: ",
		total_hits
	)

	print(
		"[Level1] Stars earned: ",
		earned_stars
	)

	# ----------------------------------------------
	# SAVE UNDER LEVEL 1
	# ----------------------------------------------

	ProgressManager.save_level_stars(
		ProgressManager.current_difficulty,
		LEVEL1_PROGRESS_ID,
		earned_stars
	)

	print(
		"[Level1] Progress recorded under: ",
		LEVEL1_PROGRESS_ID
	)

	# ----------------------------------------------
	# OPEN ORIGINAL VICTORY SCREEN
	# ----------------------------------------------

	call_deferred("_open_victory_screen")
