
extends Control

# ==================================================
# VICTORY SCREEN
# ==================================================
# Cafeteria victory:
#   Next Level -> Canteen Story
#
# Canteen victory:
#   Next Level disabled until Level 3 exists
#
# Map button:
#   Always returns to Level Map
# ==================================================

const LEVEL_MAP_SCENE_PATH: String = "res://scenes/Level Map/level_map.tscn"

const CANTEEN_STORY_SCENE_PATH: String = "res://scenes/Story Scene/canteen_story_scene.tscn"

const CAFETERIA_LEVEL_ID: String = "cafeteria_level_1"
const CANTEEN_LEVEL_ID: String = "canteen_level_2"

@onready var victory_label: Label = (
	$ColorRect/CenterContainer/VBoxContainer/VictoryLabel
)

@onready var stars: Control = (
	$ColorRect/CenterContainer/VBoxContainer/LevelStars
)

@onready var next_level_button: Button = (
	$ColorRect/CenterContainer/VBoxContainer/NextLevelButton
)

@onready var map_button: Button = (
	$ColorRect/CenterContainer/VBoxContainer/MapButton
)

var transition_started: bool = false


# ==================================================
# INITIALIZATION
# ==================================================

func _ready() -> void:
	if not map_button.pressed.is_connected(
		_on_map_pressed
	):
		map_button.pressed.connect(
			_on_map_pressed
		)

	if not next_level_button.pressed.is_connected(
		_on_next_level_pressed
	):
		next_level_button.pressed.connect(
			_on_next_level_pressed
		)

	_refresh_stars()
	_configure_next_level_button()

	print("[Victory] Screen initialized.")
	print(
		"[Victory] Completed level: ",
		ProgressManager.last_completed_level_id
	)


# ==================================================
# REFRESH VICTORY STARS
# ==================================================

func _refresh_stars() -> void:
	if not is_instance_valid(stars):
		push_error(
			"[Victory] LevelStars instance is missing."
		)
		return

	# Victory displays stars earned during this run.
	if _has_property(stars, "show_current_run"):
		stars.set("show_current_run", true)

	if stars.has_method("refresh_stars"):
		stars.call("refresh_stars")
	else:
		push_error(
			"[Victory] LevelStars is missing refresh_stars()."
		)


# ==================================================
# CHECK OBJECT PROPERTY
# ==================================================

func _has_property(
	object: Object,
	property_name: String
) -> bool:
	for property_info in object.get_property_list():
		if str(property_info.get("name", "")) == property_name:
			return true

	return false


# ==================================================
# CONFIGURE NEXT LEVEL BUTTON
# ==================================================

func _configure_next_level_button() -> void:
	var completed_level: String = (
		ProgressManager.last_completed_level_id
	)

	next_level_button.text = "NEXT LEVEL"

	match completed_level:
		CAFETERIA_LEVEL_ID:
			if ProgressManager.is_canteen_unlocked():
				next_level_button.disabled = false

				print(
					"[Victory] Canteen unlocked. "
					+ "Next Level is available."
				)
			else:
				next_level_button.disabled = true

				print(
					"[Victory] Canteen locked. "
					+ "At least 1 Cafeteria star required."
				)

		CANTEEN_LEVEL_ID:
			next_level_button.disabled = true

			print(
				"[Victory] Canteen completed. "
				+ "Next level is not configured yet."
			)

		_:
			next_level_button.disabled = true

			print(
				"[Victory] No next level configured for: ",
				completed_level
			)


# ==================================================
# RETURN TO LEVEL MAP
# ==================================================

func _on_map_pressed() -> void:
	if transition_started:
		return

	print("[Victory] Returning to Level Map.")

	_change_scene(LEVEL_MAP_SCENE_PATH)


# ==================================================
# NEXT LEVEL BUTTON
# ==================================================

func _on_next_level_pressed() -> void:
	if transition_started:
		return

	var completed_level: String = (
		ProgressManager.last_completed_level_id
	)

	if completed_level == CAFETERIA_LEVEL_ID:
		if not ProgressManager.is_canteen_unlocked():
			push_warning(
				"[Victory] Canteen is still locked."
			)
			return

		print(
			"[Victory] Moving from Cafeteria "
			+ "to Canteen Story."
		)

		_change_scene(CANTEEN_STORY_SCENE_PATH)
		return

	if completed_level == CANTEEN_LEVEL_ID:
		print(
			"[Victory] Level 3 is not available yet."
		)
		return

	print(
		"[Victory] No next level assigned."
	)


# ==================================================
# CHANGE SCENE
# ==================================================

func _change_scene(scene_path: String) -> void:
	if transition_started:
		return

	if not ResourceLoader.exists(scene_path):
		push_error(
			"[Victory] Scene not found: " + scene_path
		)
		return

	transition_started = true

	var error: Error = get_tree().change_scene_to_file(
		scene_path
	)

	if error != OK:
		transition_started = false

		push_error(
			"[Victory] Could not load scene. Error: "
			+ str(error)
		)
