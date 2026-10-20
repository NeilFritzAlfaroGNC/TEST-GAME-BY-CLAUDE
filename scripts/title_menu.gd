extends Control
## Self-contained importable copy of the title menu. The destination paths are
## Inspector properties; no game autoloads or other scripts are required.

@export_file("*.tscn") var play_scene_path: String = "res://scene/level_map_screen.tscn"
@export_file("*.tscn") var food_scene_path: String = "res://scene/main.tscn"
@export var sound_enabled: bool = true

func _ready() -> void:
	_update_sound_button()

func _on_play_pressed() -> void:
	_change_to(play_scene_path)

func _on_guess_food_pressed() -> void:
	_change_to(food_scene_path)

func _on_sound_pressed() -> void:
	sound_enabled = not sound_enabled
	_update_sound_button()

func _on_quit_pressed() -> void:
	get_tree().quit()

func _update_sound_button() -> void:
	$MenuPanel/Buttons/SoundButton.text = "Sound: ON" if sound_enabled else "Sound: OFF"

func _change_to(scene_path: String) -> void:
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		push_warning("Title menu destination scene is missing: %s" % scene_path)
		return
	get_tree().change_scene_to_file(scene_path)
