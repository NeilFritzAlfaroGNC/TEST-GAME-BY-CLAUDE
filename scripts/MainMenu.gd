extends Control
## Main Menu. Flow: Menu -> Game -> Result -> Menu.

func _ready() -> void:
	$CenterContainer/VBox/HighScore.text = "High Score: %d" % GameData.high_score

func _on_play_pressed() -> void:
	GameData.reset_run()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
