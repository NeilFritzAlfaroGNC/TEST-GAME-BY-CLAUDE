extends CafeteriaItemProjectile
class_name Level3ItemProjectile


func _ready() -> void:
	super._ready()

	var battle := get_parent()
	if battle == null:
		return

	var coordinator := battle.get_node_or_null("Level3GameplayController") as Level3GameplayController
	if coordinator == null:
		return

	if coordinator.battle_finished:
		_on_level3_combat_stopped()
		return

	if not coordinator.level_systems_stopped.is_connected(_on_level3_combat_stopped):
		coordinator.level_systems_stopped.connect(_on_level3_combat_stopped)


func launch(
	start_position: Vector2,
	initial_velocity: Vector2,
	projectile_damage: int,
	player: Node2D,
	projectile_category: int = 0,
	prepared_data: Dictionary = {}
) -> void:
	# The throw controller calls launch after adding the projectile to the tree.
	if is_queued_for_deletion():
		return

	super.launch(
		start_position, initial_velocity, projectile_damage, player, projectile_category, prepared_data
	)


func _on_level3_combat_stopped() -> void:
	active = false
	set_physics_process(false)
	queue_free()
