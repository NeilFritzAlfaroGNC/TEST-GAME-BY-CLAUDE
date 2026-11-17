extends Node
class_name EnemyKnockback

# ==================================================
# REUSABLE ENEMY KNOCKBACK
# GODOT 4.7.1
# ==================================================
#
# Preserves:
# - apply_knockback()
# - get_velocity()
# - update_recovery()
# - clear_knockback()
# - Freeze protection
# - Existing recovery behavior
#
# Adds:
# - Per-enemy knockback strength multiplier
# - Configurable recovery scale
# - Configurable stopping threshold
# - Debug toggle
# ==================================================


# ==================================================
# KNOCKBACK SETTINGS
# ==================================================

@export_group("Knockback Settings")

@export_range(0.0, 10.0, 0.1)
var knockback_recovery: float = 5.0

@export_range(0.0, 5.0, 0.05)
var knockback_strength_multiplier: float = 1.0

@export_range(1.0, 240.0, 1.0)
var recovery_scale: float = 60.0

@export_range(0.0, 100.0, 0.5)
var stopping_speed: float = 5.0


# ==================================================
# DEBUGGING
# ==================================================

@export_group("Debugging")

@export var print_debug_messages: bool = true


# ==================================================
# STATE
# ==================================================

var knockback_velocity: Vector2 = Vector2.ZERO

var is_active: bool = false


# ==================================================
# APPLY KNOCKBACK
# ==================================================

func apply_knockback(
	direction: Vector2,
	strength: float
) -> void:

	if strength <= 0.0:
		return

	if direction.is_zero_approx():
		return

	# Preserve protection against knockback
	# while the enemy is frozen.

	var enemy: Node = get_parent()

	if not is_instance_valid(enemy):
		return

	var status_effects: Node = (
		enemy.get_node_or_null(
			"EnemyStatusEffects"
		)
	)

	if is_instance_valid(status_effects):

		if status_effects.get("is_frozen") == true:

			if print_debug_messages:
				print(
					"[Enemy] Knockback rejected: ",
					"enemy is frozen."
				)

			return

	var actual_strength: float = (
		strength
		* maxf(
			knockback_strength_multiplier,
			0.0
		)
	)

	if actual_strength <= 0.0:
		return

	knockback_velocity = (
		direction.normalized()
		* actual_strength
	)

	is_active = true

	if print_debug_messages:
		print(
			"[Enemy] Knockback applied. Strength: ",
			actual_strength
		)


# ==================================================
# GET KNOCKBACK VELOCITY
# ==================================================

func get_velocity() -> Vector2:

	if not is_active:
		return Vector2.ZERO

	return knockback_velocity


# ==================================================
# RECOVERY
# ==================================================

func update_recovery(delta: float) -> void:

	if not is_active:
		return

	var recovery_amount: float = (
		maxf(knockback_recovery, 0.0)
		* maxf(recovery_scale, 0.0)
		* delta
	)

	knockback_velocity = (
		knockback_velocity.move_toward(
			Vector2.ZERO,
			recovery_amount
		)
	)

	if knockback_velocity.is_zero_approx() or knockback_velocity.length() < stopping_speed:

		knockback_velocity = Vector2.ZERO
		is_active = false


# ==================================================
# CLEAR KNOCKBACK
# ==================================================

func clear_knockback() -> void:

	knockback_velocity = Vector2.ZERO
	is_active = false
