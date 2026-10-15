extends CharacterBody2D
## Level 2+ candy monster. It walks toward the hero and reports a hit at close range.
## Uses the standalone Enemy2 scene so it can be added without changing Enemy.tscn.

var speed: float = 70.0
var lane_y: float = NAN
var reached: bool = false

@onready var walking_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	walking_sprite.play("walk")

func _process(delta: float) -> void:
	if reached:
		return
	var main: Node = get_tree().current_scene
	if main == null:
		return
	var hero: Node2D = main.get_node_or_null("Hero") as Node2D
	if hero == null:
		return
	if is_nan(lane_y):
		lane_y = global_position.y
	var to_hero: Vector2 = hero.global_position - global_position
	to_hero.y = lane_y - global_position.y
	if to_hero.length() < 45.0:
		reached = true
		main.enemy_reached_hero(self)
		return
	var horizontal_direction: float = signf(to_hero.x)
	global_position.x += horizontal_direction * speed * delta
	global_position.y = lane_y
