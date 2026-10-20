extends Node2D
class_name FoodThrow
## A tossed food (one scene per food: <name>_animation.tscn). Flies along an arc showing "static" with the food-shaped
## StaticHitbox. When it hits an enemy (or lands at the target point) it plays
## "animation" (burst + juice) and switches to the larger SplashHitbox.
## Any enemy touched by either hitbox is removed from the game.

signal enemy_hit(enemy: Node2D)

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var static_hitbox: Area2D = $StaticHitbox
@onready var splash_hitbox: Area2D = $SplashHitbox

var velocity: Vector2 = Vector2.ZERO
var gravity: float = 980.0
var flight_time: float = 1.0
var _time: float = 0.0
var _flying: bool = false
var _splashing: bool = false

func _ready() -> void:
	sprite.play("static")
	static_hitbox.body_entered.connect(_on_body_hit)
	splash_hitbox.body_entered.connect(_on_body_hit)
	splash_hitbox.monitoring = false
	sprite.animation_finished.connect(_on_animation_finished)

# Start flying from the current position so the mango lands on `target`
# after `time` seconds (a ballistic arc under `gravity`).
func launch(target: Vector2, time: float) -> void:
	flight_time = maxf(time, 0.1)
	var gravity_vec := Vector2(0.0, gravity)
	velocity = (target - global_position - 0.5 * gravity_vec * flight_time * flight_time) / flight_time
	_time = 0.0
	_flying = true

func _physics_process(delta: float) -> void:
	if not _flying:
		return
	velocity.y += gravity * delta
	global_position += velocity * delta
	sprite.rotation += -8.0 * delta #Spin while flying
	_time += delta
	if _time >= flight_time:
		splash() #Reached the target point without hitting anything

func _on_body_hit(body: Node2D) -> void:
	if body.has_method("hit_by_food"):
		body.hit_by_food()
		enemy_hit.emit(body)
		splash()

# Stop flying and play the burst animation with the splash hitbox.
func splash() -> void:
	if _splashing:
		return
	_splashing = true
	_flying = false
	sprite.rotation = 0.0
	sprite.play("animation")
	static_hitbox.set_deferred("monitoring", false)
	splash_hitbox.set_deferred("monitoring", true)

func _on_animation_finished() -> void:
	if sprite.animation == "animation":
		queue_free()
