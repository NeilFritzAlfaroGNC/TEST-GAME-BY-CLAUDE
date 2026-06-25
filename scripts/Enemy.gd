extends Area2D
## Hunger Monster. Walks toward the Hero on its own.
## If it reaches the Hero, the player loses a life.

var speed: float = 70.0
var reached: bool = false

func _process(delta: float) -> void:
	var main = get_tree().current_scene
	if main == null:
		return
	var hero = main.get_node_or_null("Hero")
	if hero == null:
		return
	var to_hero: Vector2 = hero.global_position - global_position
	if not reached and to_hero.length() < 45.0:
		reached = true
		main.enemy_reached_hero(self)
		return
	global_position += to_hero.normalized() * speed * delta
