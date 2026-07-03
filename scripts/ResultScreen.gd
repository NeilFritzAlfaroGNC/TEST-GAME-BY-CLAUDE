extends Control
## Win / Lose screen for a single level. Shows stars, score, level best, and
## high score (all from the DB), and routes to Next / Retry / Level Select / Menu.

func _ready() -> void:
	var win: bool = GameData.last_result == "win"
	var title: Label = $CenterContainer/VBox/Title
	title.text = "LEVEL CLEAR!" if win else "GAME OVER"
	title.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4) if win else Color(0.95, 0.4, 0.4))

	$CenterContainer/VBox/Stars.text = _stars(GameData.last_stars)
	$CenterContainer/VBox/Score.text = "Score: %d   (Level %d - %s)" % [GameData.score, GameData.current_level, GameData.current_difficulty]

	var prog: Dictionary = DB.get_level_progress(GameData.current_difficulty, GameData.current_level)
	$CenterContainer/VBox/Best.text = "Level best: %d" % int(prog["best_score"])
	$CenterContainer/VBox/HighScore.text = "High Score: %d" % GameData.high_score
	_show_recent()

	# "Next Level" only when this level was cleared and another level exists
	# (completing it unlocks the next one).
	$CenterContainer/VBox/ButtonRow/NextButton.visible = win and GameData.has_next_level()

	Audio.stop_music()
	Audio.play("win" if win else "lose")

func _stars(s: int) -> String:
	s = clampi(s, 0, 3)
	return "[ %s ]" % ("*".repeat(s) + "-".repeat(3 - s))

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

func _on_next_pressed() -> void:
	Audio.play("click")
	GameData.start_level(GameData.current_difficulty, GameData.current_level + 1)
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_retry_pressed() -> void:
	Audio.play("click")
	GameData.start_level(GameData.current_difficulty, GameData.current_level)
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_level_select_pressed() -> void:
	Audio.play("click")
	get_tree().change_scene_to_file("res://scenes/LevelSelect.tscn")

func _on_menu_pressed() -> void:
	Audio.play("click")
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
