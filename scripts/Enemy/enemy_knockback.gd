extends Node
class_name EnemyKnockback

@export var knockback_recovery: float = 5.0

var knockback_velocity: Vector2 = Vector2.ZERO
var is_active: bool = false


func apply_knockback(
	direction: Vector2,
	strength: float
) -> void:
	if strength <= 0.0:
		return

	if direction == Vector2.ZERO:
		return

	# Prevent knockback while the parent enemy is frozen.
	var enemy := get_parent()

	if not is_instance_valid(enemy):
		return

	var status_effects := enemy.get_node_or_null("EnemyStatusEffects")

	if is_instance_valid(status_effects):
		if status_effects.is_frozen:
			print("[Enemy] Knockback rejected: enemy is frozen.")
			return

	knockback_velocity = direction.normalized() * strength
	is_active = true

	print(
		"[Enemy] Knockback applied. Strength: ",
		strength
	)


func get_velocity() -> Vector2:
	if not is_active:
		return Vector2.ZERO

	return knockback_velocity


func update_recovery(delta: float) -> void:
	if not is_active:
		return

	knockback_velocity = knockback_velocity.move_toward(
		Vector2.ZERO,
		knockback_recovery * 60.0 * delta
	)

	if knockback_velocity.length() < 5.0:
		knockback_velocity = Vector2.ZERO
		is_active = false


func clear_knockback() -> void:
	knockback_velocity = Vector2.ZERO
	is_active = false
