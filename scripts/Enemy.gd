extends Area2D
## A Hunger Monster. Each one carries its OWN weakness (the food group that
## defeats it), which is what turns the game from one classification decision
## per level into one per monster.
##
## Nothing here reaches into the scene tree. The spawner injects the speed, the
## target position and the "I reached the hero" callback via setup().

var weakness: String = "Go"
var nutrient: String = ""        # only used when label_mode is "nutrient"
var label_mode: String = "group"
var speed: float = 70.0

var _target_x: float = 0.0
var _on_reach: Callable = Callable()
var _spent: bool = false

@onready var label: Label = $Label

func setup(group: String, mode: String, spd: float, target_x: float, on_reach: Callable) -> void:
	weakness = group
	label_mode = mode
	speed = spd
	_target_x = target_x
	_on_reach = on_reach
	if mode == "nutrient":
		nutrient = GameData.random_nutrient_for(group)
		# Grow only offers "+Protein"; if a group ever has none, fall back to
		# the group label rather than displaying an empty request.
		if nutrient == "":
			label_mode = "group"
	_refresh_label()

# What the player reads off the monster.
func weakness_text() -> String:
	if label_mode == "nutrient" and nutrient != "":
		return "needs %s" % nutrient.trim_prefix("+").to_upper()
	return weakness.to_upper()

func _refresh_label() -> void:
	if label != null:
		label.text = weakness_text()

func _process(delta: float) -> void:
	if _spent:
		return
	position.x += speed * delta
	if position.x >= _target_x:
		_spent = true
		if _on_reach.is_valid():
			_on_reach.call(self)
