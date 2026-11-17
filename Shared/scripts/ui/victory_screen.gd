
extends Control

# ==================================================
# SHARED VICTORY SCREEN
# ==================================================

const TOKEN_UNLOCKS := preload("res://scripts/codex/codex_token_unlocks.gd")
const LEVEL_MAP_SCENE_PATH := "res://Shared/scenes/level_map/level_map.tscn"
const CANTEEN_STORY_SCENE_PATH := "res://Level2/scenes/story/canteen_story_scene.tscn"
const TANJANGCO_STORY_SCENE_PATH := "res://Level3/scenes/story/story_scene_level3.tscn"
const TANJANGCO_BATTLE_SCENE_PATH := "res://Level3/scenes/battle/battle_scene_level3.tscn"

const CAFETERIA_LEVEL_ID := "cafeteria_level_1"
const CANTEEN_LEVEL_ID := "canteen_level_2"
const TANJANGCO_LEVEL_ID := "scene3_level_3"

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
	_show_token_rewards()

	print("[Victory] Screen initialized.")
	print(
		"[Victory] Completed level: ",
		ProgressManager.last_completed_level_id
	)


# ==================================================
# REFRESH VICTORY STARS
# ==================================================

func _show_token_rewards() -> void:
	if not ProgressManager.has_meta(TOKEN_UNLOCKS.REWARD_META):
		return
	var rewards: PackedStringArray = ProgressManager.get_meta(TOKEN_UNLOCKS.REWARD_META)
	ProgressManager.remove_meta(TOKEN_UNLOCKS.REWARD_META)
	if rewards.is_empty():
		return
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color("#ffe398"))
	var lines := PackedStringArray()
	var quantities := {}
	for reward in rewards:
		quantities[reward] = int(quantities.get(reward, 0)) + 1
	for reward: String in quantities:
		var count: int = quantities[reward]
		lines.append("You got %s Token!" % reward if count == 1 else "You got %d %s Tokens!" % [count, reward])
	label.text = "\n".join(lines)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var reward_list := ScrollContainer.new()
	reward_list.name = "TokenRewards"
	reward_list.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	reward_list.custom_minimum_size = Vector2(440.0, minf(label.get_minimum_size().y, 88.0))
	reward_list.add_child(label)
	var column := victory_label.get_parent()
	column.add_child(reward_list)
	column.move_child(reward_list, stars.get_index() + 1)


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
	var completed_level: String = ProgressManager.last_completed_level_id
	next_level_button.text = "RETRY" if completed_level == TANJANGCO_LEVEL_ID else "NEXT LEVEL"
	next_level_button.disabled = _next_action_path().is_empty()


func _next_action_path() -> String:
	match ProgressManager.last_completed_level_id:
		CAFETERIA_LEVEL_ID:
			return CANTEEN_STORY_SCENE_PATH if ProgressManager.is_canteen_unlocked() else ""
		CANTEEN_LEVEL_ID:
			return TANJANGCO_STORY_SCENE_PATH
		TANJANGCO_LEVEL_ID:
			return TANJANGCO_BATTLE_SCENE_PATH
	return ""


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
	var path := _next_action_path()
	if not path.is_empty():
		_change_scene(path)


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
