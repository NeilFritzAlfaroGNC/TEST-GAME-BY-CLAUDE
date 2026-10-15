extends Control
## Main Menu. Flow: Menu -> Level Select.
## Buttons are declared in MainMenu.tscn and connected to these handlers. The
## tutorial flag and sound setting live in DB; the food mini-game is a separate scene.

var play_transition_started: bool = false

func _ready() -> void:
	_update_sound_button()
	Audio.play_music("music")

func _on_play_pressed() -> void:
	if play_transition_started:
		return
	play_transition_started = true
	$MenuPanel/Buttons/PlayButton.disabled = true
	Audio.play("click")
	# Refresh the saved completion flag; Level 1 decides whether its overlay is needed.
	GameData.tutorial_mode = false
	GameData.tutorial_completed = DB.get_setting_int("tutorial_done", 0) == 1
	GameData.tutorial_entry_pending = false
	get_tree().change_scene_to_file("res://scenes/LevelSelect.tscn")

func _on_guess_food_pressed() -> void:
	Audio.play("click")
	get_tree().change_scene_to_file("res://scenes/GuessTheFood.tscn")

func _on_sound_pressed() -> void:
	Audio.toggle_muted()
	Audio.play("click")
	_update_sound_button()

func _update_sound_button() -> void:
	$MenuPanel/Buttons/SoundButton.text = "Sound: OFF" if Audio.muted else "Sound: ON"

func _on_quit_pressed() -> void:
	Audio.play("click")
	get_tree().quit()
