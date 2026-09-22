extends Control
## Main Menu. Flow: Menu -> Game -> Result -> Menu.

func _ready() -> void:
	_update_sound_button()
	Audio.play_music("music")

func _on_play_pressed() -> void:
	Audio.play("click")
	# First time ever pressing Play: run the guided tutorial instead of the
	# level select. Completing it sets "tutorial_done" (see Game.gd).
	if DB.get_setting_int("tutorial_done", 0) == 0:
		GameData.start_tutorial()
		get_tree().change_scene_to_file("res://scenes/Game.tscn")
		return
	get_tree().change_scene_to_file("res://scenes/LevelSelect.tscn")

func _on_howto_pressed() -> void:
	Audio.play("click")
	get_tree().change_scene_to_file("res://scenes/HowToPlay.tscn")

func _on_sound_pressed() -> void:
	Audio.toggle_muted()
	Audio.play("click")
	_update_sound_button()

func _update_sound_button() -> void:
	$CenterContainer/VBox/SoundButton.text = "Sound: OFF" if Audio.muted else "Sound: ON"

func _on_quit_pressed() -> void:
	Audio.play("click")
	get_tree().quit()
