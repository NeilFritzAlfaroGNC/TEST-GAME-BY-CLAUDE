
extends Button

# ==================================================
# HARD DIFFICULTY UNLOCK SYSTEM
# ==================================================
# Unlock Hard after completing Canteen Level 2
# on Normal difficulty with at least 1 star.
#
# No additional Autoload required.
# Uses existing ProgressManager save data.
# ==================================================

const REQUIRED_LEVEL_ID: String = "canteen_level_2"
const REQUIRED_DIFFICULTY: String = "normal"
const REQUIRED_STARS: int = 1

const LOCKED_TEXT: String = "🔒"
const UNLOCKED_TEXT: String = "HARD"


func _ready() -> void:
	refresh_unlock_status()


# ==================================================
# CHECK HARD UNLOCK CONDITION
# ==================================================

func is_hard_unlocked() -> bool:
	var earned_stars: int = (
		ProgressManager.get_level_stars(
			REQUIRED_DIFFICULTY,
			REQUIRED_LEVEL_ID
		)
	)

	return earned_stars >= REQUIRED_STARS


# ==================================================
# UPDATE HARD BUTTON
# ==================================================

func refresh_unlock_status() -> void:
	var unlocked: bool = is_hard_unlocked()

	disabled = not unlocked
	text = UNLOCKED_TEXT if unlocked else LOCKED_TEXT

	if unlocked:
		print(
			"[Difficulty] HARD unlocked! "
			+ "Canteen Level 2 completed on Normal."
		)
	else:
		print(
			"[Difficulty] HARD locked. "
			+ "Complete Canteen Level 2 on Normal "
			+ "with at least one star."
		)
