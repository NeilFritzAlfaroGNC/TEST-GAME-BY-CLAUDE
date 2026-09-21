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
	_put("score", "Score: %d" % GameData.score)
	_put("lives", "Lives: %d" % GameData.lives)
	_put("highscore", "High Score: %d" % maxi(GameData.high_score, GameData.score))
	if GameData.tutorial_mode:
		_put("level", "TUTORIAL - learn the basics")
	else:
		_put("level", "Level %d: %s  [%s]" % [
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

# NOT named _set: Object declares a virtual `_set(StringName, Variant) -> bool`,
# and a same-named helper with a different signature is a hard parse error that
# takes every script depending on this one down with it.
func _put(key: String, text: String) -> void:
	var n: Label = _n.get(key)
	if n != null:
		n.text = text
