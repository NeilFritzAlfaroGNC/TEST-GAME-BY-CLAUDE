
extends Control

const LEVEL_MAP_SCENE_PATH: String = "res://scenes/Level Map/level_map.tscn"
const NEXT_LEVEL_SCENE_PATH: String = ""

@onready var victory_label: Label = $ColorRect/CenterContainer/VBoxContainer/VictoryLabel
@onready var stars: Control = $ColorRect/CenterContainer/VBoxContainer/LevelStars
@onready var next_level_button: Button = $ColorRect/CenterContainer/VBoxContainer/NextLevelButton
@onready var map_button: Button = $ColorRect/CenterContainer/VBoxContainer/MapButton


func _ready() -> void:
	if not map_button.pressed.is_connected(_on_map_pressed):
		map_button.pressed.connect(_on_map_pressed)

	if not next_level_button.pressed.is_connected(_on_next_level_pressed):
		next_level_button.pressed.connect(_on_next_level_pressed)

	_refresh_stars()

	print("[Victory] Screen initialized.")


func _refresh_stars() -> void:
	if is_instance_valid(stars) and stars.has_method("refresh_stars"):
		stars.refresh_stars()
	else:
		push_error("[Victory] LevelStars instance or refresh_stars() is missing.")


func _on_map_pressed() -> void:
	print("[Victory] Returning to Level Map.")

	var error := get_tree().change_scene_to_file(LEVEL_MAP_SCENE_PATH)

	if error != OK:
		push_error("[Victory] Could not load Level Map. Error: %s" % error)


func _on_next_level_pressed() -> void:
	if NEXT_LEVEL_SCENE_PATH.is_empty():
		print("[Victory] Next level is not configured yet.")
		return

	if not ResourceLoader.exists(NEXT_LEVEL_SCENE_PATH):
		push_error("[Victory] Next Level scene does not exist.")
		return

	var error := get_tree().change_scene_to_file(NEXT_LEVEL_SCENE_PATH)

	if error != OK:
		push_error("[Victory] Could not load Next Level. Error: %s" % error)
