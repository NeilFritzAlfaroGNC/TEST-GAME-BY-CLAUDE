
extends CharacterBody2D

# Controls movement, detection, and attacks.
# Health, status effects, and knockback are handled by components.

@export var move_speed: float = 60.0

var health: int:
	get:
		return enemy_health.get_health() if is_instance_valid(enemy_health) else 0

var max_health: int:
	get:
		return enemy_health.get_max_health() if is_instance_valid(enemy_health) else 0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $DetectionArea
@onready var claw_attack: ClawAttack = $ClawAnimation
@onready var enemy_health: EnemyHealth = $EnemyHealth
@onready var status_effects: EnemyStatusEffects = $EnemyStatusEffects
@onready var enemy_knockback: EnemyKnockback = $EnemyKnockback

var main_character: Node2D = null
var is_attacking: bool = false
var is_dead: bool = false
var is_playing_burn_animation: bool = false


func _ready() -> void:
	if not is_instance_valid(enemy_health):
		push_error("Hamburger enemy: EnemyHealth node is missing.")
		set_physics_process(false)
		return

	if not is_instance_valid(status_effects):
		push_error("Hamburger enemy: EnemyStatusEffects node is missing.")
		set_physics_process(false)
		return

	if not is_instance_valid(enemy_knockback):
		push_error("Hamburger enemy: EnemyKnockback node is missing.")
		set_physics_process(false)
		return

	if not enemy_health.died.is_connected(_die):
		enemy_health.died.connect(_die)

	if not status_effects.stun_ended.is_connected(_on_stun_ended):
		status_effects.stun_ended.connect(_on_stun_ended)

	if not status_effects.freeze_ended.is_connected(_on_freeze_ended):
		status_effects.freeze_ended.connect(_on_freeze_ended)

	if not status_effects.burn_tick.is_connected(_on_burn_tick):
		status_effects.burn_tick.connect(_on_burn_tick)

	if not is_in_group("enemy"):
		add_to_group("enemy")

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

	for animation_name in ["walk", "attack", "freeze", "burn", "defeated"]:
		if not sprite.sprite_frames.has_animation(animation_name):
			push_error(
				"Hamburger enemy: Missing animation: " + animation_name
			)
			set_physics_process(false)
			return

	if not is_instance_valid(claw_attack):
		push_error("Hamburger enemy: ClawAnimation node is missing.")
		set_physics_process(false)
		return

	sprite.sprite_frames.set_animation_loop("attack", false)
	sprite.sprite_frames.set_animation_loop("freeze", false)
	sprite.sprite_frames.set_animation_loop("burn", false)
	sprite.sprite_frames.set_animation_loop("defeated", false)

	_play_walk()


# ==================================================
# HEALTH INTERFACE
# ==================================================

func take_damage(amount: int) -> void:
	if is_dead or not is_instance_valid(enemy_health):
		return

	enemy_health.take_damage(amount)


func _die() -> void:
	if is_dead:
		return

	is_dead = true
	is_attacking = false
	is_playing_burn_animation = false
	main_character = null
	velocity = Vector2.ZERO

	status_effects.clear_effects()
	enemy_knockback.clear_knockback()

	set_physics_process(false)
	detection_area.set_deferred("monitoring", false)
	detection_area.set_deferred("monitorable", false)

	claw_attack.set_physics_process(false)
	claw_attack.hide()

	sprite.play("defeated")

	print("[Hamburger] Defeated animation started.")

	await sprite.animation_finished

	if not is_inside_tree():
		return

	print("[Hamburger] Defeated animation finished.")

	queue_free()


# ==================================================
# STATUS EFFECT INTERFACE
# ==================================================

func apply_freeze(duration: float) -> void:
	if is_dead or not is_instance_valid(status_effects):
		return

	if status_effects.is_frozen:
		return

	status_effects.apply_freeze(duration)

	if status_effects.is_frozen:
		is_attacking = false
		is_playing_burn_animation = false
		velocity = Vector2.ZERO

		enemy_knockback.clear_knockback()

		sprite.play("freeze")

		print("[Hamburger] Freeze animation started.")


func apply_stun(duration: float) -> void:
	if is_dead or not is_instance_valid(status_effects):
		return

	if status_effects.is_frozen:
		return

	status_effects.apply_stun(duration)

	if status_effects.is_stunned:
		is_attacking = false
		is_playing_burn_animation = false
		velocity = Vector2.ZERO
		sprite.play("walk")


func apply_burn(
	damage: float,
	duration: float,
	tick_count: int,
	tick_interval: float
) -> void:
	if is_dead or not is_instance_valid(status_effects):
		return

	if status_effects.is_frozen:
		return

	if damage <= 0.0 or duration <= 0.0:
		return

	if tick_count <= 0 or tick_interval <= 0.0:
		return

	# Initial Burn damage happens immediately.
	var initial_damage: int = maxi(roundi(damage), 0)

	if initial_damage > 0:
		take_damage(initial_damage)
		print("[Hamburger] Initial Burn damage: ", initial_damage)

	if is_dead:
		return

	# Play the initial Burn animation.
	_play_burn_animation()

	# Start periodic Burn damage.
	status_effects.apply_burn(
		damage,
		duration,
		tick_count,
		tick_interval
	)


func _on_burn_tick() -> void:
	if is_dead:
		return

	if status_effects.is_frozen or status_effects.is_stunned:
		return

	_play_burn_animation()


func _play_burn_animation() -> void:
	if is_dead:
		return

	if status_effects.is_frozen or status_effects.is_stunned:
		return

	is_playing_burn_animation = true
	is_attacking = false
	velocity = Vector2.ZERO

	sprite.play("burn")

	print("[Hamburger] Burn animation started.")


func _on_stun_ended() -> void:
	if is_dead or status_effects.is_frozen:
		return

	_resume_behavior()


func _on_freeze_ended() -> void:
	if is_dead or status_effects.is_stunned:
		return

	print("[Hamburger] Freeze timer ended.")

	_resume_behavior()


func _resume_behavior() -> void:
	if is_dead:
		return

	if status_effects.is_frozen or status_effects.is_stunned:
		return

	if is_playing_burn_animation:
		return

	if enemy_knockback.is_active:
		return

	if is_instance_valid(main_character):
		is_attacking = true
		_play_attack()
	else:
		is_attacking = false
		_play_walk()


# ==================================================
# KNOCKBACK INTERFACE
# ==================================================

func apply_knockback(
	direction: Vector2,
	strength: float
) -> void:
	if is_dead or not is_instance_valid(enemy_knockback):
		return

	if status_effects.is_frozen:
		print("[Enemy] Knockback rejected: enemy is frozen.")
		return

	enemy_knockback.apply_knockback(direction, strength)


# ==================================================
# ENEMY MOVEMENT
# ==================================================

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if status_effects.is_frozen:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if is_playing_burn_animation:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if enemy_knockback.is_active:
		velocity = enemy_knockback.get_velocity()
		move_and_slide()

		enemy_knockback.update_recovery(delta)
		return

	if status_effects.is_stunned:
		velocity = Vector2.ZERO
		move_and_slide()
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


# ==================================================
# PLAYER DETECTION
# ==================================================

func _on_detection_area_body_entered(body: Node2D) -> void:
	if is_dead or not body.is_in_group("player"):
		return

	main_character = body

	if (
		status_effects.is_stunned
		or status_effects.is_frozen
		or is_playing_burn_animation
	):
		return

	is_attacking = true
	velocity = Vector2.ZERO

	print("Hamburger enemy: Player detected.")

	_play_attack()


func _on_detection_area_body_exited(body: Node2D) -> void:
	if is_dead or body != main_character:
		return

	print("Hamburger enemy: Player left detection area.")

	is_attacking = false
	main_character = null
	velocity = Vector2.ZERO

	if (
		not status_effects.is_stunned
		and not status_effects.is_frozen
		and not is_playing_burn_animation
	):
		_play_walk()


# ==================================================
# ENEMY ANIMATIONS AND ATTACK
# ==================================================

func _on_enemy_animation_finished() -> void:
	if is_dead:
		return

	# Freeze animation: hold its final frame.
	if sprite.animation == "freeze":
		if status_effects.is_frozen:
			var last_frame: int = (
				sprite.sprite_frames.get_frame_count("freeze") - 1
			)

			sprite.frame = last_frame
			sprite.pause()

			print("[Hamburger] Holding freeze frame: ", sprite.frame)

		return

	# Burn animation: resume previous behavior.
	if sprite.animation == "burn":
		is_playing_burn_animation = false

		print("[Hamburger] Burn animation finished.")

		_resume_behavior()
		return

	if (
		status_effects.is_stunned
		or status_effects.is_frozen
		or is_playing_burn_animation
	):
		return

	if is_attacking and is_instance_valid(main_character):
		if sprite.animation == "attack":
			_play_attack()


func _play_walk() -> void:
	if (
		is_dead
		or status_effects.is_stunned
		or status_effects.is_frozen
		or is_playing_burn_animation
		or is_attacking
		or enemy_knockback.is_active
	):
		return

	if sprite.animation != "walk" or not sprite.is_playing():
		sprite.play("walk")


func _play_attack() -> void:
	if (
		is_dead
		or status_effects.is_stunned
		or status_effects.is_frozen
		or is_playing_burn_animation
	):
		return

	sprite.play("attack")

	await get_tree().create_timer(1.5).timeout

	if (
		is_dead
		or status_effects.is_stunned
		or status_effects.is_frozen
		or is_playing_burn_animation
		or not is_attacking
	):
		return

	if not is_instance_valid(main_character):
		return

	claw_attack.attack()

	print("Hamburger enemy: Attack started.")
	print("Hamburger enemy: Claw attack triggered.")
