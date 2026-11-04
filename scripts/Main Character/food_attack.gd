
extends Node
class_name FoodAttack

const FOOD_THROW_SCENE: PackedScene = preload(
	"res://scenes/Foods/food_throw.tscn"
)

@onready var character: CharacterBody2D = get_parent() as CharacterBody2D

@onready var energy_system: Node = character.get_node_or_null(
	"EnergySystem"
)
@onready var grow_buff: Node = character.get_node_or_null(
	"GrowBuff"
)


func perform_glow_attack(
	food: FoodData,
	target: Node2D
) -> bool:
	if not is_instance_valid(food):
		return false

	if not is_instance_valid(character):
		return false

	if not is_instance_valid(target):
		return false

	# Calculate damage, including the active GROW bonus.
	var final_damage: float = food.base_damage
	var buff_bonus: float = 0.0

	if is_instance_valid(grow_buff):
		buff_bonus = grow_buff.get_damage_bonus()

	final_damage += buff_bonus

	print("[Attack] Base damage: ", food.base_damage)
	print("[Attack] GROW bonus: ", buff_bonus)
	print("[Attack] Final damage: ", final_damage)

	# Spend energy before preparing the projectile.
	var energy_spent: bool = false

	if is_instance_valid(energy_system):
		if not energy_system.use_energy(food.energy_cost):
			print("[Attack] Not enough energy.")
			return false

		energy_spent = true

	# Create the projectile.
	var projectile: Node = FOOD_THROW_SCENE.instantiate()

	if projectile == null:
		_refund_energy(food, energy_spent)
		return false

	add_child(projectile)

	if not projectile.has_method("prepare_food"):
		push_error("[Projectile] Missing prepare_food().")
		projectile.queue_free()
		_refund_energy(food, energy_spent)
		return false

	# Prepare the original food instance.
	var prepared: bool = projectile.prepare_food(food, character)

	if not prepared:
		projectile.queue_free()
		_refund_energy(food, energy_spent)
		return false

	# Play the character's existing attack animation.
	var animation_success: bool = await character.play_attack()

	if not animation_success:
		_return_and_remove_projectile(projectile)
		_refund_energy(food, energy_spent)
		return false

	# Recheck the target after the animation.
	if not is_instance_valid(target):
		target = character.find_nearest_enemy()

	if not is_instance_valid(target):
		_return_and_remove_projectile(projectile)
		_refund_energy(food, energy_spent)
		return false

	var current_scene: Node = get_tree().current_scene

	if current_scene == null:
		_return_and_remove_projectile(projectile)
		_refund_energy(food, energy_spent)
		return false

	# Move the projectile out of this component.
	projectile.reparent(current_scene, true)

	var projectile_success: bool = projectile.launch(
		target.global_position,
		target,
		food.food_name,
		final_damage,
		food
	)

	if not projectile_success:
		_return_and_remove_projectile(projectile)
		_refund_energy(food, energy_spent)
		return false

	print("[Projectile] Original food launched: ", food.food_name)

	return true


func _refund_energy(
	food: FoodData,
	energy_spent: bool
) -> void:
	if not energy_spent:
		return

	if not is_instance_valid(energy_system):
		return

	energy_system.restore_energy(food.energy_cost)


func _return_and_remove_projectile(projectile: Node) -> void:
	if not is_instance_valid(projectile):
		return

	if projectile.has_method("return_food_to_original_parent"):
		projectile.return_food_to_original_parent()

	projectile.queue_free()
