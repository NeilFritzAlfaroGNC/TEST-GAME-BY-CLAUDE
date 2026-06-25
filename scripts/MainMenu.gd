extends Control
## Main Menu. Flow: Menu -> Game -> Result -> Menu.

func _ready() -> void:
	$CenterContainer/VBox/HighScore.text = "High Score: %d" % GameData.high_score
	Audio.play_music("music")

func _on_play_pressed() -> void:
	Audio.play("click")
	GameData.reset_run()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_quit_pressed() -> void:
	Audio.play("click")
	get_tree().quit()
