
extends CharacterBody2D

# ==================================================
# REUSABLE ENEMY CONTROLLER
#
# Attack sequence:
# 1. Play AnimatedSprite2D attack animation.
# 2. Wait until that animation finishes.
# 3. Trigger EnemyAttack claw animation.
# 4. Wait for the next attack interval.
# 5. Repeat while the player is detected.
# ==================================================


# ==================================================
# INSPECTOR SETTINGS
# ==================================================

@export_group("Enemy Identity")
@export var enemy_name: String = "Enemy"

@export_group("Movement")
@export var move_speed: float = 60.0
@export var move_direction: Vector2 = Vector2.RIGHT
@export var face_player: bool = true

@export_group("Attack Timing")

# Time between the claw attack being triggered
# and the next monster attack animation starting.
@export_range(0.05, 20.0, 0.05) var attack_interval: float = 1.5

# Delay before the very first monster attack animation.
@export_range(0.0, 10.0, 0.05) var first_attack_delay: float = 0.0

@export var attack_node_path: NodePath = ^"EnemyAttack"

@export_group("Animations")
@export var walk_animation: StringName = &"walk"
@export var attack_animation: StringName = &"attack"
@export var freeze_animation: StringName = &"freeze"
@export var burn_animation: StringName = &"burn"
@export var defeated_animation: StringName = &"defeated"

@export_group("Component Paths")
@export var sprite_path: NodePath = ^"AnimatedSprite2D"
@export var detection_path: NodePath = ^"DetectionArea"
@export var health_path: NodePath = ^"EnemyHealth"
@export var status_path: NodePath = ^"EnemyStatusEffects"
@export var knockback_path: NodePath = ^"EnemyKnockback"

@export_group("Debug")
@export var show_debug_messages: bool = false


# ==================================================
# HEALTH PROPERTIES
# ==================================================

var health: int:
	get:
		if is_instance_valid(enemy_health):
			return enemy_health.get_health()
		return 0


var max_health: int:
	get:
		if is_instance_valid(enemy_health):
			return enemy_health.get_max_health()
		return 0


# ==================================================
# NODE REFERENCES
# ==================================================

@onready var sprite: AnimatedSprite2D = (
	get_node_or_null(sprite_path) as AnimatedSprite2D
)

@onready var detection_area: Area2D = (
	get_node_or_null(detection_path) as Area2D
)

@onready var attack_component: Node2D = (
	get_node_or_null(attack_node_path) as Node2D
)

@onready var enemy_health: EnemyHealth = (
	get_node_or_null(health_path) as EnemyHealth
)

@onready var status_effects: EnemyStatusEffects = (
	get_node_or_null(status_path) as EnemyStatusEffects
)

@onready var enemy_knockback: EnemyKnockback = (
	get_node_or_null(knockback_path) as EnemyKnockback
)


# ==================================================
# ENEMY STATES
# ==================================================

var main_character: Node2D = null

var is_attacking: bool = false
var is_dead: bool = false
var is_playing_burn_animation: bool = false

# True only while the monster's own attack
# animation is playing.
var is_attack_animation_playing: bool = false

var attack_timer: float = 0.0
var initialized: bool = false


# ==================================================
# INITIALIZATION
# ==================================================

func _ready() -> void:
	if not is_instance_valid(sprite):
		_fail_setup("AnimatedSprite2D missing.")
		return

	if not is_instance_valid(detection_area):
		_fail_setup("DetectionArea missing.")
		return

	if not is_instance_valid(attack_component):
		_fail_setup("Attack component missing.")
		return

	if not attack_component.has_method("attack"):
		_fail_setup("Attack component requires attack().")
		return

	if not attack_component.has_method("stop_attack"):
		_fail_setup("Attack component requires stop_attack().")
		return

	if not is_instance_valid(enemy_health):
		_fail_setup("EnemyHealth missing.")
		return

	if not is_instance_valid(status_effects):
		_fail_setup("EnemyStatusEffects missing.")
		return

	if not is_instance_valid(enemy_knockback):
		_fail_setup("EnemyKnockback missing.")
		return

	if sprite.sprite_frames == null:
		_fail_setup("SpriteFrames missing.")
		return

	var required_animations: Array[StringName] = [
		walk_animation,
		attack_animation,
		freeze_animation,
		burn_animation,
		defeated_animation
	]

	for animation_name in required_animations:
		if not sprite.sprite_frames.has_animation(animation_name):
			_fail_setup(
				"Missing animation: " + String(animation_name)
			)
			return

	for animation_name in [
		attack_animation,
		freeze_animation,
		burn_animation,
		defeated_animation
	]:
		sprite.sprite_frames.set_animation_loop(
			animation_name,
			false
		)

	if not enemy_health.died.is_connected(_die):
		enemy_health.died.connect(_die)

	if not status_effects.stun_ended.is_connected(
		_on_stun_ended
	):
		status_effects.stun_ended.connect(
			_on_stun_ended
		)

	if not status_effects.freeze_ended.is_connected(
		_on_freeze_ended
	):
		status_effects.freeze_ended.connect(
			_on_freeze_ended
		)

	if not status_effects.burn_tick.is_connected(
		_on_burn_tick
	):
		status_effects.burn_tick.connect(
			_on_burn_tick
		)

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

	if not is_in_group("enemy"):
		add_to_group("enemy")

	move_speed = maxf(move_speed, 0.0)
	attack_interval = maxf(attack_interval, 0.05)
	first_attack_delay = maxf(first_attack_delay, 0.0)

	is_attacking = false
	is_dead = false
	is_playing_burn_animation = false
	is_attack_animation_playing = false
	attack_timer = 0.0

	initialized = true

	_debug("Initialized successfully.")

	_play_walk()


func _fail_setup(message: String) -> void:
	push_error(
		"[Enemy: " + enemy_name + "] " + message
	)

	set_physics_process(false)


func _debug(message: String) -> void:
	if show_debug_messages:
		print(
			"[Enemy: ",
			enemy_name,
			"] ",
			message
		)


# ==================================================
# EXTERNAL INTERFACE
# ==================================================

func get_attack_component() -> Node2D:
	return attack_component


func take_damage(amount: int) -> void:
	if is_dead:
		return

	if not is_instance_valid(enemy_health):
		return

	enemy_health.take_damage(amount)


# ==================================================
# DEATH
# ==================================================

func _die() -> void:
	if is_dead:
		return

	is_dead = true

	_stop_current_attack()

	main_character = null
	is_playing_burn_animation = false
	velocity = Vector2.ZERO

	status_effects.clear_effects()
	enemy_knockback.clear_knockback()

	set_physics_process(false)

	detection_area.set_deferred("monitoring", false)
	detection_area.set_deferred("monitorable", false)

	if is_instance_valid(attack_component):
		attack_component.set_physics_process(false)

	sprite.play(defeated_animation)

	_debug("Defeated animation started.")

	await sprite.animation_finished

	if not is_inside_tree():
		return

	_debug("Defeated.")

	queue_free()


# ==================================================
# FREEZE
# ==================================================

func apply_freeze(duration: float) -> void:
	if is_dead or not initialized:
		return

	if status_effects.is_frozen:
		return

	status_effects.apply_freeze(duration)

	if status_effects.is_frozen:
		_stop_current_attack()

		is_playing_burn_animation = false
		velocity = Vector2.ZERO

		enemy_knockback.clear_knockback()

		sprite.play(freeze_animation)

		_debug("Frozen.")


# ==================================================
# STUN
# ==================================================

func apply_stun(duration: float) -> void:
	if is_dead or not initialized:
		return

	if status_effects.is_frozen:
		return

	status_effects.apply_stun(duration)

	if status_effects.is_stunned:
		_stop_current_attack()

		is_playing_burn_animation = false
		velocity = Vector2.ZERO

		sprite.play(walk_animation)

		_debug("Stunned.")


# ==================================================
# BURN
# ==================================================

func apply_burn(
	damage: float,
	duration: float,
	tick_count: int,
	tick_interval: float
) -> void:
	if is_dead or not initialized:
		return

	if status_effects.is_frozen:
		return

	if damage <= 0.0 or duration <= 0.0:
		return

	if tick_count <= 0 or tick_interval <= 0.0:
		return

	var initial_damage: int = maxi(
		roundi(damage),
		0
	)

	if initial_damage > 0:
		take_damage(initial_damage)

	if is_dead:
		return

	_play_burn_animation()

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

	_stop_current_attack()

	is_playing_burn_animation = true
	velocity = Vector2.ZERO

	sprite.play(burn_animation)

	_debug("Burn animation started.")


# ==================================================
# STATUS RECOVERY
# ==================================================

func _on_stun_ended() -> void:
	if is_dead or status_effects.is_frozen:
		return

	_resume_behavior()


func _on_freeze_ended() -> void:
	if is_dead or status_effects.is_stunned:
		return

	_resume_behavior()


func _resume_behavior() -> void:
	if is_dead or not initialized:
		return

	if status_effects.is_frozen or status_effects.is_stunned:
		return

	if is_playing_burn_animation:
		return

	if enemy_knockback.is_active:
		return

	if is_instance_valid(main_character):
		_start_attacking()
	else:
		_play_walk()


# ==================================================
# KNOCKBACK
# ==================================================

func apply_knockback(
	direction: Vector2,
	strength: float
) -> void:
	if is_dead or not initialized:
		return

	if status_effects.is_frozen:
		return

	_stop_current_attack()

	enemy_knockback.apply_knockback(
		direction,
		strength
	)


# ==================================================
# MOVEMENT
# ==================================================

func _physics_process(delta: float) -> void:
	if not initialized or is_dead:
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

		if not enemy_knockback.is_active:
			_resume_behavior()

		return

	if status_effects.is_stunned:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if is_attacking:
		velocity = Vector2.ZERO
		move_and_slide()

		_update_attack(delta)
		return

	if is_instance_valid(main_character):
		var difference: Vector2 = (
			main_character.global_position - global_position
		)

		if face_player and difference.x != 0.0:
			sprite.flip_h = difference.x < 0.0

		if difference.length() > 0.0:
			velocity = difference.normalized() * move_speed
		else:
			velocity = Vector2.ZERO
	else:
		if move_direction.length_squared() > 0.0:
			velocity = move_direction.normalized() * move_speed
		else:
			velocity = Vector2.ZERO

	_play_walk()
	move_and_slide()


# ==================================================
# PLAYER DETECTION
# ==================================================

func _on_detection_area_body_entered(
	body: Node2D
) -> void:
	if is_dead or not initialized:
		return

	if not body.is_in_group("player"):
		return

	main_character = body

	if face_player:
		var direction_x: float = (
			body.global_position.x - global_position.x
		)

		if direction_x != 0.0:
			sprite.flip_h = direction_x < 0.0

	velocity = Vector2.ZERO

	_debug("Player detected.")

	_resume_behavior()


func _on_detection_area_body_exited(
	body: Node2D
) -> void:
	if is_dead:
		return

	if body != main_character:
		return

	main_character = null

	_stop_current_attack()

	velocity = Vector2.ZERO

	if (
		not status_effects.is_stunned
		and not status_effects.is_frozen
		and not is_playing_burn_animation
	):
		_play_walk()


# ==================================================
# ATTACK START
# ==================================================

func _start_attacking() -> void:
	if is_dead or not initialized:
		return

	if (
		status_effects.is_stunned
		or status_effects.is_frozen
		or is_playing_burn_animation
		or enemy_knockback.is_active
	):
		return

	if not is_instance_valid(main_character):
		return

	if is_attacking:
		return

	is_attacking = true
	is_attack_animation_playing = false

	velocity = Vector2.ZERO

	attack_timer = first_attack_delay

	_debug("Attack sequence started.")

	if attack_timer <= 0.0:
		_begin_attack_animation()


# ==================================================
# ATTACK TIMER
# ==================================================

func _update_attack(delta: float) -> void:
	if not is_attacking:
		return

	if not is_instance_valid(main_character):
		_stop_current_attack()
		_play_walk()
		return

	# Important:
	# Do not start another attack while the
	# monster's attack animation is playing.
	if is_attack_animation_playing:
		return

	attack_timer -= delta

	if attack_timer > 0.0:
		return

	_begin_attack_animation()


# ==================================================
# PLAY MONSTER ATTACK ANIMATION
# ==================================================

func _begin_attack_animation() -> void:
	if is_dead or not is_attacking:
		return

	if not is_instance_valid(main_character):
		_stop_current_attack()
		return

	if (
		status_effects.is_stunned
		or status_effects.is_frozen
		or is_playing_burn_animation
		or enemy_knockback.is_active
	):
		return

	if is_attack_animation_playing:
		return

	is_attack_animation_playing = true

	# Start the monster's windup animation.
	# Do NOT trigger the claw yet.
	sprite.stop()
	sprite.play(attack_animation)

	_debug("Monster attack animation started.")


# ==================================================
# TRIGGER CLAW AFTER MONSTER ANIMATION
# ==================================================

func _trigger_attack_effect() -> void:
	if is_dead or not is_attacking:
		return

	if not is_instance_valid(main_character):
		_stop_current_attack()
		return

	if (
		status_effects.is_stunned
		or status_effects.is_frozen
		or is_playing_burn_animation
		or enemy_knockback.is_active
	):
		_stop_current_attack()
		return

	if not is_instance_valid(attack_component):
		_stop_current_attack()
		return

	if not attack_component.has_method("attack"):
		_stop_current_attack()
		return

	# The claw animation begins ONLY AFTER the
	# AnimatedSprite2D attack animation finishes.
	attack_component.call("attack")

	_debug("Monster animation finished. Claw triggered.")

	# Cooldown before starting the next windup.
	attack_timer = maxf(attack_interval, 0.05)


# ==================================================
# STOP ATTACK
# ==================================================

func _stop_current_attack() -> void:
	is_attacking = false
	is_attack_animation_playing = false
	attack_timer = 0.0

	if is_instance_valid(attack_component):
		if attack_component.has_method("stop_attack"):
			attack_component.call("stop_attack")


# ==================================================
# ANIMATION FINISHED
# ==================================================

func _on_enemy_animation_finished() -> void:
	if is_dead:
		return

	# ----------------------------------------------
	# FREEZE ANIMATION
	# ----------------------------------------------

	if sprite.animation == freeze_animation:
		if status_effects.is_frozen:
			var last_frame: int = (
				sprite.sprite_frames.get_frame_count(
					freeze_animation
				) - 1
			)

			sprite.frame = maxi(last_frame, 0)
			sprite.pause()

		return

	# ----------------------------------------------
	# BURN ANIMATION
	# ----------------------------------------------

	if sprite.animation == burn_animation:
		is_playing_burn_animation = false
		_resume_behavior()
		return

	# ----------------------------------------------
	# ATTACK ANIMATION
	# ----------------------------------------------

	if sprite.animation == attack_animation:
		if not is_attacking:
			return

		if not is_attack_animation_playing:
			return

		# Monster's windup is now complete.
		is_attack_animation_playing = false

		_debug("Monster attack animation finished.")

		# NOW trigger the actual claw attack.
		_trigger_attack_effect()

		return


# ==================================================
# WALK ANIMATION
# ==================================================

func _play_walk() -> void:
	if is_dead or not initialized:
		return

	if (
		status_effects.is_stunned
		or status_effects.is_frozen
		or is_playing_burn_animation
		or is_attacking
		or enemy_knockback.is_active
	):
		return

	if sprite.animation != walk_animation or not sprite.is_playing():
		sprite.play(walk_animation)
