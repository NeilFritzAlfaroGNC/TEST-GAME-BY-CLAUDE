extends Control
## Main Menu. Flow: Menu -> Game -> Result -> Menu.

func _ready() -> void:
	$CenterContainer/VBox/HighScore.text = "High Score: %d" % GameData.high_score
	_update_sound_button()
	Audio.play_music("music")

func _on_play_pressed() -> void:
	Audio.play("click")
	get_tree().change_scene_to_file("res://scenes/LevelSelect.tscn")

func _on_sound_pressed() -> void:
	Audio.toggle_muted()
	Audio.play("click")
	_update_sound_button()

func _update_sound_button() -> void:
	$CenterContainer/VBox/SoundButton.text = "Sound: OFF" if Audio.muted else "Sound: ON"

func _on_quit_pressed() -> void:
	Audio.play("click")
	get_tree().quit()
