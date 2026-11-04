
extends Node
class_name LevelDifficultySetting

@export_group("Easy Settings")
@export var easy_settings: LevelDifficultyConfig

@export_group("Normal Settings")
@export var normal_settings: LevelDifficultyConfig


func get_current_settings() -> LevelDifficultyConfig:
	match ProgressManager.current_difficulty:
		"easy":
			return easy_settings

		"normal":
			return normal_settings

		_:
			push_warning(
				"LevelDifficultySetting: Unknown difficulty: "
				+ ProgressManager.current_difficulty
			)
			return easy_settings
