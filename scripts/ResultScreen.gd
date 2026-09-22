extends Control
## Win / Lose screen for a single level. Shows stars, score, level best, and
## high score (all from the DB), and routes to Next / Retry / Level Select / Menu.

func _ready() -> void:
	var win: bool = GameData.last_result == "win"
	var title: Label = $CenterContainer/VBox/Title
	title.text = "LEVEL CLEAR!" if win else "GAME OVER"
	title.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4) if win else Color(0.95, 0.4, 0.4))

	$CenterContainer/VBox/Stars.text = "[ %s ]" % GameData.stars_text(GameData.last_stars)
	$CenterContainer/VBox/Score.text = "Score: %d   (Level %d - %s)" % [GameData.score, GameData.current_level, GameData.current_difficulty]

	var prog: Dictionary = DB.get_level_progress(GameData.current_difficulty, GameData.current_level)
	$CenterContainer/VBox/Best.text = "Level best: %d" % int(prog["best_score"])
	$CenterContainer/VBox/HighScore.text = "High Score: %d" % GameData.high_score

	var accuracy_label: Label = $CenterContainer/VBox/Accuracy
	var accuracy_text: String = _accuracy_line()
	accuracy_label.text = accuracy_text
	accuracy_label.visible = not accuracy_text.is_empty()

	# "Next Level" only when this level was cleared and another level exists
	# (completing it unlocks the next one).
	$CenterContainer/VBox/ButtonRow/NextButton.visible = win and GameData.has_next_level()

	Audio.stop_music()
	Audio.play("win" if win else "lose")

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

func _accuracy_line() -> String:
	var acc: Dictionary = DB.get_accuracy(GameData.current_difficulty)
	if acc.is_empty():
		return ""
	var parts: Array = []
	var worst := ""
	var worst_pct := 101
	for group in ["Go", "Glow", "Grow"]:
		var row: Dictionary = acc.get(group, {})
		var c: int = int(row.get("correct", 0))
		var w: int = int(row.get("wrong", 0))
		if c + w == 0:
			continue
		var pct: int = int(round(100.0 * float(c) / float(c + w)))
		parts.append("%s %d%%" % [group, pct])
		if pct < worst_pct:
			worst_pct = pct
			worst = group
	if parts.is_empty():
		return ""
	var line: String = "  -  ".join(parts)
	if worst != "" and worst_pct < 80:
		line += "\nPractise your %s foods!" % worst
	return line
