extends Node
## All HUD text and colour. Pulled out of the old 473-line Main.gd so the
## orchestrator never formats a string.

const GOOD := Color(0.10, 0.55, 0.15)
const BAD := Color(0.75, 0.10, 0.10)
const BOSS_COLOR := Color(0.42, 0.24, 0.52)

var _n: Dictionary = {}

func bind(nodes: Dictionary) -> void:
	_n = nodes

func say(text: String, good: bool) -> void:
	var hint: Label = _n.get("hint")
	if hint == null:
		return
	hint.text = text
	hint.add_theme_color_override("font_color", GOOD if good else BAD)

func refresh(ctx: Dictionary) -> void:
	_set("score", "Score: %d" % GameData.score)
	_set("lives", "Lives: %d" % GameData.lives)
	_set("highscore", "High Score: %d" % maxi(GameData.high_score, GameData.score))
	if GameData.tutorial_mode:
		_set("level", "TUTORIAL - learn the basics")
	else:
		_set("level", "Level %d: %s  [%s]" % [
			GameData.current_level, String(ctx.get("level_name", "")), GameData.current_difficulty])

	var target: Label = _n.get("target")
	if target == null:
		return
	if bool(ctx.get("boss_active", false)):
		target.text = "BOSS - build a meal!  Need: %s" % String(ctx.get("meal_left", ""))
		target.add_theme_color_override("font_color", BOSS_COLOR)
	else:
		# Per-monster weakness means there is no single level-wide target to
		# announce -- the monsters carry the question now.
		target.text = "Feed each monster what it asks for!"
		target.add_theme_color_override("font_color", Color(0.15, 0.15, 0.2))

func _set(key: String, text: String) -> void:
	var n: Label = _n.get(key)
	if n != null:
		n.text = text
