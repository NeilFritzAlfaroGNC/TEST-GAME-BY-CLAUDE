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

# The boss is not a one-hit monster: instead of despawning it when it reaches
# the Hero, Game knocks it back to the far side and the fight continues. _spent
# is a one-shot latch so _on_reach fires exactly once per charge, and re-arming
# that latch is precisely what "knocked back" means. Nothing else calls this.
func knock_back_to(pos: Vector2) -> void:
	global_position = pos
	_spent = false

func _process(delta: float) -> void:
	if _spent:
		return
	position.x += speed * delta
	if position.x >= _target_x:
		_spent = true
		if _on_reach.is_valid():
			_on_reach.call(self)
