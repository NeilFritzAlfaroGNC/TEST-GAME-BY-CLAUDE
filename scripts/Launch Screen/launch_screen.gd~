extends Control

const DISPLAY_DURATION: float = 0.5
const FADE_DURATION: float = 0.18

func _ready() -> void:
	var tween := create_tween()
	modulate.a = 0.0
	tween.tween_property(self, "modulate:a", 1.0, FADE_DURATION)
	tween.tween_interval(DISPLAY_DURATION)
	tween.tween_property(self, "modulate:a", 0.0, FADE_DURATION)
	tween.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/Main Menu/main_menu_screen.tscn"))
