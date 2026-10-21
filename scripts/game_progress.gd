extends Node
## Autoload "GameProgress": which level is being played, which levels are
## unlocked and the best stars per level. Saved to user://progress.cfg.
## Levels unlock in order: winning level N unlocks level N + 1.

signal progress_changed

const LEVEL_COUNT: int = 5 #Level buttons on the level map

var save_path: String = "user://progress.cfg"
var current_level: int = 1 #Level picked on the map (used by the battle)
var unlocked_level: int = 1 #Highest level that can be played
var best_stars: Dictionary = {} #level -> best stars (1-3)

func _ready() -> void:
	load_progress()

func is_unlocked(level: int) -> bool:
	return level >= 1 and level <= unlocked_level

func is_completed(level: int) -> bool:
	return best_stars.has(level)

func has_next_level(level: int) -> bool:
	return level < LEVEL_COUNT

# Record a won level: keep the best stars and unlock the next level.
func complete_level(level: int, stars: int) -> void:
	best_stars[level] = maxi(best_stars.get(level, 0), stars)
	unlocked_level = clampi(maxi(unlocked_level, level + 1), 1, LEVEL_COUNT)
	save_progress()
	progress_changed.emit()

func save_progress() -> void:
	var config := ConfigFile.new()
	config.set_value("progress", "unlocked_level", unlocked_level)
	for level: int in best_stars:
		config.set_value("stars", "level_%d" % level, best_stars[level])
	config.save(save_path)

func load_progress() -> void:
	unlocked_level = 1
	best_stars.clear()
	var config := ConfigFile.new()
	if config.load(save_path) != OK:
		return #No save yet: only level 1 is open
	unlocked_level = clampi(int(config.get_value("progress", "unlocked_level", 1)), 1, LEVEL_COUNT)
	if config.has_section("stars"):
		for key: String in config.get_section_keys("stars"):
			best_stars[key.trim_prefix("level_").to_int()] = int(config.get_value("stars", key))

# Start over from level 1 (also deletes the save file).
func reset_progress() -> void:
	unlocked_level = 1
	best_stars.clear()
	current_level = 1
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	progress_changed.emit()
