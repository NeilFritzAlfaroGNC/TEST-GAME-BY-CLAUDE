extends Control
## Win / Lose / Final Score screen. Which one is decided by GameData.last_result.

func _ready() -> void:
	var win: bool = GameData.last_result == "win"
	var title: Label = $CenterContainer/VBox/Title
	title.text = "YOU WIN!" if win else "GAME OVER"
	title.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4) if win else Color(0.95, 0.4, 0.4))
	$CenterContainer/VBox/Score.text = "Final Score: %d" % GameData.score
	$CenterContainer/VBox/HighScore.text = "High Score: %d" % GameData.high_score

func _on_play_again_pressed() -> void:
	GameData.reset_run()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
