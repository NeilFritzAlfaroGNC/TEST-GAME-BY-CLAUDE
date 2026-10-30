
extends CharacterBody2D

# Controls movement, detection, attacks, and health.
# ClawAnimation plays once during every enemy attack cycle.

@export var move_speed: float = 60.0
@export var max_health: int = 10

var health: int = 10

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $DetectionArea
@onready var claw_attack: ClawAttack = $ClawAnimation

var main_character: Node2D = null
var is_attacking: bool = false
var is_dead: bool = false


func _ready() -> void:
	health = max_health

	if not detection_area.body_entered.is_connected(
		_on_detection_area_body_entered
	):
		detection_area.body_entered.connect(
			_on_detection_area_body_entered
		)

	if not detection_area.body_exited.is_connected(
		_on_detection_area_body_exited
	):
		detection_area.body_exited.connect(
			_on_detection_area_body_exited
		)

	if not sprite.animation_finished.is_connected(
		_on_enemy_animation_finished
	):
		sprite.animation_finished.connect(
			_on_enemy_animation_finished
		)

	if sprite.sprite_frames == null:
		push_error("Hamburger enemy: SpriteFrames is missing.")
		set_physics_process(false)
		return

	if not sprite.sprite_frames.has_animation("walk"):
		push_error("Hamburger enemy: 'walk' animation is missing.")
		set_physics_process(false)
		return

	if not sprite.sprite_frames.has_animation("attack"):
		push_error("Hamburger enemy: 'attack' animation is missing.")
		set_physics_process(false)
		return

	if not is_instance_valid(claw_attack):
		push_error("Hamburger enemy: ClawAnimation node is missing.")
		set_physics_process(false)
		return

	sprite.sprite_frames.set_animation_loop("attack", false)

	_play_walk()


# Called by the food projectile when it hits this enemy.
func take_damage(amount: int) -> void:
	if is_dead or amount <= 0:
		return

	health = maxi(health - amount, 0)

	print(
		"Hamburger enemy took ", amount,
		" damage. Health: ", health, "/", max_health
	)

	if health <= 0:
		_die()


func _die() -> void:
	if is_dead:
		return

	is_dead = true
	is_attacking = false
	main_character = null
	velocity = Vector2.ZERO

	# Stop detection and movement before removing the enemy.
	set_physics_process(false)
	detection_area.set_deferred("monitoring", false)

	print("Hamburger enemy defeated.")

	queue_free()


func _physics_process(_delta: float) -> void:
	if is_dead:
		return

	if is_attacking:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if is_instance_valid(main_character):
		var difference: Vector2 = (
			main_character.global_position - global_position
		)

		if difference.x != 0.0:
			sprite.flip_h = difference.x < 0.0

		if difference.length() > 0.0:
			velocity = difference.normalized() * move_speed
		else:
			velocity = Vector2.ZERO
	else:
		velocity = Vector2(move_speed, 0.0)

	_play_walk()
	move_and_slide()


func _on_detection_area_body_entered(body: Node2D) -> void:
	if is_dead or body.name != "main_character":
		return

	main_character = body
	is_attacking = true
	velocity = Vector2.ZERO

	print("Hamburger enemy: Main character detected.")

	_play_attack()


func _on_detection_area_body_exited(body: Node2D) -> void:
	if is_dead or body != main_character:
		return

	print("Hamburger enemy: Main character left detection area.")

	is_attacking = false
	main_character = null
	velocity = Vector2.ZERO

	_play_walk()


func _on_enemy_animation_finished() -> void:
	if is_dead:
		return

	if is_attacking and is_instance_valid(main_character):
		if sprite.animation == "attack":
			_play_attack()


func _play_walk() -> void:
	if is_dead or is_attacking:
		return

	if sprite.animation != "walk" or not sprite.is_playing():
		sprite.play("walk")


func _play_attack() -> void:
	if is_dead:
		return

	sprite.play("attack")

	# Wait 1 second before triggering the claw animation.
	await get_tree().create_timer(1.5).timeout

	# Do not trigger the claw if the enemy died during the delay.
	if is_dead:
		return

	claw_attack.attack()

	print("Hamburger enemy: Attack started.")
	print("Hamburger enemy: Claw attack triggered.")
