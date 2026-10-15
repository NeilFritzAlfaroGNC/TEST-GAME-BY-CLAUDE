extends Area2D
## Hunger Monster. Walks toward the Hero on its own.
## If it reaches the Hero, the player loses a life.
## Enemy.tscn supplies SpaghettiSprite and its looping walk animation. Main sets
## speed after instancing and receives enemy_reached_hero(self) at close range.

var speed: float = 70.0
var lane_y: float = NAN
var reached: bool = false

@onready var walking_sprite: AnimatedSprite2D = $SpaghettiSprite

func _ready() -> void:
	walking_sprite.animation_finished.connect(_on_animation_finished)
	walking_sprite.play("walk")

# Damage the hero only after the one-shot attack animation reaches its final frame.
func _on_animation_finished() -> void:
	if walking_sprite.animation != &"attack" or not reached:
		return
	var main: Node = get_tree().current_scene
	if main != null:
		main.enemy_reached_hero(self)

func _process(delta: float) -> void:
	var main = get_tree().current_scene
	if main == null:
		return
	var hero = main.get_node_or_null("Hero")
	if hero == null or reached:
		# The one-shot attack animation owns the enemy until its finish callback.
		return
	if is_nan(lane_y):
		lane_y = global_position.y
	var to_hero: Vector2 = hero.global_position - global_position
	to_hero.y = lane_y - global_position.y
	if not reached and to_hero.length() < 45.0:
		reached = true
		speed = 0.0
		# Stop walking and play the attack once; its finish signal applies damage.
		walking_sprite.play("attack")
		return
	if speed > 0.0 and not reached:
		if not walking_sprite.is_playing():
			walking_sprite.play("walk")
		# Preserve the grass-aligned foot lane while moving toward the hero.
		var horizontal_direction: float = signf(to_hero.x)
		global_position.x += horizontal_direction * speed * delta
		global_position.y = lane_y
	else:
		walking_sprite.stop()
