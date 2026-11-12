extends Control

const LEVEL_MAP_SCENE_PATH: String = "res://scenes/Level Map/level_map.tscn"

@onready var retry_button: Button = $Background/CenterContainer/VBoxContainer/RetryButton
@onready var main_menu_button: Button = $Background/CenterContainer/VBoxContainer/MainMenuButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	if not retry_button.pressed.is_connected(_on_retry_pressed):
		retry_button.pressed.connect(_on_retry_pressed)

	if not main_menu_button.pressed.is_connected(_on_main_menu_pressed):
		main_menu_button.pressed.connect(_on_main_menu_pressed)

	print("[GameOver] Screen initialized.")


func _close_game_over_screen() -> void:
	var scene_root := get_tree().root

	if get_parent() == scene_root:
		scene_root.remove_child(self)

	queue_free()


func _on_retry_pressed() -> void:
	print("[GameOver] Restarting battle...")

	var tree := get_tree()
	tree.paused = false

	_close_game_over_screen()

	var error := tree.reload_current_scene()

	if error != OK:
		push_error("[GameOver] Could not reload battle. Error: %s" % error)


func _on_main_menu_pressed() -> void:
	if not ResourceLoader.exists(LEVEL_MAP_SCENE_PATH):
		push_error("[GameOver] Level Map scene does not exist.")
		return

	print("[GameOver] Returning to Level Map...")

	var tree := get_tree()
	tree.paused = false

	_close_game_over_screen()

	var error := tree.change_scene_to_file(LEVEL_MAP_SCENE_PATH)

	if error != OK:
		push_error("[GameOver] Could not load Level Map. Error: %s" % error)
