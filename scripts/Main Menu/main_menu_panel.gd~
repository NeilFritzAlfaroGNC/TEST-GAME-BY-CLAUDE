
extends Panel

@onready var play_button: TextureButton = $main_menu_button_container/Play
@onready var quit_button: TextureButton = $main_menu_button_container/Quit


func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	quit_button.pressed.connect(_on_quit_pressed)


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file(
		"res://scenes/Level Map/level_map.tscn"
	)


func _on_quit_pressed() -> void:
	get_tree().quit()
