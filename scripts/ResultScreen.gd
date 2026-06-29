extends Control
## Win / Lose / Final Score screen. Which one is decided by GameData.last_result.

func _ready() -> void:
	var win: bool = GameData.last_result == "win"
	var title: Label = $CenterContainer/VBox/Title
	title.text = "YOU WIN!" if win else "GAME OVER"
	title.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4) if win else Color(0.95, 0.4, 0.4))
	$CenterContainer/VBox/Score.text = "Final Score: %d" % GameData.score
	$CenterContainer/VBox/HighScore.text = "High Score: %d" % GameData.high_score
	_show_recent()
	Audio.stop_music()
	Audio.play("win" if win else "lose")

func _show_recent() -> void:
	var recent: Array = DB.get_recent_runs(5)
	var label: Label = $CenterContainer/VBox/Recent
	if recent.is_empty():
		label.text = ""
		return
	var parts: Array = []
	for r in recent:
		parts.append(str(int(r["score"])))
	label.text = "Recent scores: " + ", ".join(parts)

func _on_play_again_pressed() -> void:
	Audio.play("click")
	GameData.reset_run()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_menu_pressed() -> void:
	Audio.play("click")
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
