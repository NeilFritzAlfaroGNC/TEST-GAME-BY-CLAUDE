
extends Node2D

# ==================================================
# REUSABLE ENEMY ATTACK COMPONENT
# ==================================================

signal hit_landed(target: Node2D)

@export_group("Attack Stats")
@export_range(1, 999, 1) var attack_damage: int = 1

@export_group("Animation Settings")
@export var attack_animation: StringName = &"attack"
@export var hide_sprite_when_idle: bool = true

@export_group("Node Paths")
@export var sprite_path: NodePath = ^"Sprite2D"
@export var animation_player_path: NodePath = ^"AnimationPlayer"
@export var hitbox_path: NodePath = ^"HitBox"

@export_group("Debug")
@export var show_debug_messages: bool = false


# ==================================================
# NODE REFERENCES
# ==================================================

@onready var sprite: Sprite2D = (
	get_node_or_null(sprite_path) as Sprite2D
)

@onready var animation_player: AnimationPlayer = (
	get_node_or_null(animation_player_path) as AnimationPlayer
)

@onready var hitbox: Area2D = (
	get_node_or_null(hitbox_path) as Area2D
)


# ==================================================
# ATTACK STATE
# ==================================================

var _swing_hit: bool = false
var _is_attacking: bool = false
var _initialized: bool = false


# ==================================================
# INITIALIZATION
# ==================================================

func _ready() -> void:
	if not is_instance_valid(sprite):
		_fail_setup("Sprite2D is missing.")
		return

	if not is_instance_valid(animation_player):
		_fail_setup("AnimationPlayer is missing.")
		return

	if not is_instance_valid(hitbox):
		_fail_setup("HitBox is missing.")
		return

	if not animation_player.has_animation(attack_animation):
		_fail_setup(
			"Missing attack animation: "
			+ String(attack_animation)
		)
		return

	var animation: Animation = (
		animation_player.get_animation(attack_animation)
	)

	if animation != null:
		animation.loop_mode = Animation.LOOP_NONE

	if not animation_player.animation_finished.is_connected(
		_on_animation_finished
	):
		animation_player.animation_finished.connect(
			_on_animation_finished
		)

	_swing_hit = false
	_is_attacking = false
	_initialized = true

	if hide_sprite_when_idle:
		sprite.hide()

	if show_debug_messages:
		print(
			"[EnemyAttack] Ready: ",
			get_parent().name
		)


func _fail_setup(message: String) -> void:
	push_error(
		"[EnemyAttack] " + message
	)

	set_physics_process(false)


# ==================================================
# START ATTACK
# ==================================================

func attack() -> void:
	if not _initialized:
		return

	if not is_inside_tree():
		return

	if not animation_player.has_animation(attack_animation):
		return

	_swing_hit = false
	_is_attacking = true

	animation_player.stop()

	sprite.show()

	animation_player.play(attack_animation)

	if show_debug_messages:
		print(
			"[EnemyAttack] Attack triggered: ",
			get_parent().name
		)


# ==================================================
# HIT DETECTION
# ==================================================

func _physics_process(_delta: float) -> void:
	if not _initialized:
		return

	if not _is_attacking:
		return

	if _swing_hit:
		return

	if not sprite.visible:
		return

	if not animation_player.is_playing():
		return

	if not hitbox.monitoring:
		return

	for body: Node2D in hitbox.get_overlapping_bodies():
		if not is_instance_valid(body):
			continue

		if not body.has_method("take_hit"):
			continue

		_swing_hit = true

		body.call(
			"take_hit",
			attack_damage
		)

		hit_landed.emit(body)

		if show_debug_messages:
			print(
				"[EnemyAttack] Hit: ",
				body.name,
				" | Damage: ",
				attack_damage
			)

		return


# ==================================================
# ANIMATION FINISHED
# ==================================================

func _on_animation_finished(
	animation_name: StringName
) -> void:
	if animation_name != attack_animation:
		return

	_is_attacking = false
	_swing_hit = false

	if hide_sprite_when_idle:
		sprite.hide()

	if show_debug_messages:
		print("[EnemyAttack] Animation finished.")


# ==================================================
# STOP ATTACK
# ==================================================

func stop_attack() -> void:
	_is_attacking = false
	_swing_hit = false

	if is_instance_valid(animation_player):
		animation_player.stop()

	if is_instance_valid(sprite):
		if hide_sprite_when_idle:
			sprite.hide()


# ==================================================
# ATTACK STATUS
# ==================================================

func is_attack_active() -> bool:
	return _is_attacking
