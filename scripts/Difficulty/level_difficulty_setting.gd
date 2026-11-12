extends Node
class_name LevelDifficultySetting

# ==================================================
# LEVEL DIFFICULTY CONFIGURATION
# ==================================================
# Each battle scene assigns its own resources
# for Easy, Normal, and Hard.
# ==================================================

@export_group("Easy Settings")
@export var easy_settings: LevelDifficultyConfig

@export_group("Normal Settings")
@export var normal_settings: LevelDifficultyConfig

@export_group("Hard Settings")
@export var hard_settings: LevelDifficultyConfig


# ==================================================
# GET CURRENT DIFFICULTY CONFIGURATION
# ==================================================

func get_current_settings() -> LevelDifficultyConfig:
	var selected_settings: LevelDifficultyConfig = null

	match ProgressManager.current_difficulty:
		"easy":
			selected_settings = easy_settings

		"normal":
			selected_settings = normal_settings

		"hard":
			if not ProgressManager.is_hard_unlocked():
				push_error(
					"[LevelDifficultySetting] "
					+ "Hard difficulty has not been unlocked."
				)
				return null

			selected_settings = hard_settings

		_:
			push_warning(
				"[LevelDifficultySetting] Unknown difficulty: "
				+ ProgressManager.current_difficulty
			)
			return null

	if selected_settings == null:
		push_error(
			"[LevelDifficultySetting] No configuration assigned "
			+ "for difficulty: "
			+ ProgressManager.current_difficulty
		)

	return selected_settings
