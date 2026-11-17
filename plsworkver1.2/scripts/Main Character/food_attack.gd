extends Node
class_name FoodAttack

const FOOD_THROW_SCENE: PackedScene = preload(
	"res://scenes/Foods/food_throw.tscn"
)

@onready var character: CharacterBody2D = (
	get_parent() as CharacterBody2D
)

@onready var energy_system: Node = (
	character.get_node_or_null("EnergySystem")
)

@onready var grow_buff: Node = (
	character.get_node_or_null("GrowBuff")
)


# ==================================================
# PERFORM GLOW ATTACK
# ==================================================

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

	# ----------------------------------------------
	# CAPTURE FIVE GROW EFFECT TYPES
	# ----------------------------------------------

	var grow_effects: Dictionary = {
		"damage_bonus": 0.0,
		"size_multiplier": 1.0,
		"knockback_strength": 0.0,
		"stun_duration": 0.0,
		"flopping": {
			"enabled": false,
			"max_hits": 5,
			"bounce_range": 250.0,
			"bounce_duration": 0.3,
			"bounce_height": 65.0,
			"random_fallback": true
		}
	}

	if is_instance_valid(grow_buff):
		if grow_buff.has_method("get_effect_snapshot"):
			grow_effects = grow_buff.get_effect_snapshot()
		else:
			grow_effects["damage_bonus"] = (
				grow_buff.get_damage_bonus()
			)

	var bonus_damage: float = float(
		grow_effects.get("damage_bonus", 0.0)
	)

	var final_damage: float = (
		food.base_damage + bonus_damage
	)

	print("")
	print("========== GLOW ATTACK ==========")
	print("[Attack] Food: ", food.food_name)
	print("[Attack] Base damage: ", food.base_damage)
	print("[Attack] GROW bonus: ", bonus_damage)
	print("[Attack] Final damage: ", final_damage)
	print(
		"[GROW] Size multiplier: ",
		grow_effects.get("size_multiplier", 1.0)
	)
	print(
		"[GROW] Extra knockback: ",
		grow_effects.get("knockback_strength", 0.0)
	)
	print(
		"[GROW] Extra stun: ",
		grow_effects.get("stun_duration", 0.0)
	)
	print(
		"[GROW] Flopping: ",
		grow_effects.get("flopping", {})
	)
	print("=================================")

	# ----------------------------------------------
	# ENERGY COST
	# ----------------------------------------------

	var actual_energy_cost: float = food.energy_cost

	if is_instance_valid(energy_system):
		actual_energy_cost = (
			energy_system.get_discounted_energy_cost(
				food.energy_cost
			)
		)

	var energy_spent: bool = false
	var protection_spent: bool = false

	if is_instance_valid(energy_system):
		if energy_system.has_energy_protection():
			protection_spent = (
				energy_system.consume_energy_protection()
			)

			if protection_spent:
				print(
					"[Attack] Energy protection used."
				)

		if not protection_spent:
			if not energy_system.use_energy(
				actual_energy_cost
			):
				print("[Attack] Insufficient energy.")
				return false

			energy_spent = true

			print(
				"[Attack] Energy spent: ",
				actual_energy_cost
			)

	# ----------------------------------------------
	# PREPARE ORIGINAL FOOD
	# ----------------------------------------------

	var projectile: Node = (
		FOOD_THROW_SCENE.instantiate()
	)

	if projectile == null:
		_refund_attack_resources(
			actual_energy_cost,
			energy_spent,
			protection_spent
		)
		return false

	add_child(projectile)

	if not projectile.has_method("prepare_food"):
		projectile.queue_free()

		_refund_attack_resources(
			actual_energy_cost,
			energy_spent,
			protection_spent
		)

		return false

	var prepared: bool = projectile.prepare_food(
		food,
		character
	)

	if not prepared:
		projectile.queue_free()

		_refund_attack_resources(
			actual_energy_cost,
			energy_spent,
			protection_spent
		)

		return false

	# Pass the GROW modifiers before the player's
	# attack animation begins.
	if projectile.has_method("set_grow_effects"):
		projectile.set_grow_effects(
			grow_effects
		)

	# ----------------------------------------------
	# ATTACK ANIMATION
	# ----------------------------------------------

	var animation_success: bool = (
		await character.play_attack()
	)

	if not animation_success:
		_return_and_remove_projectile(projectile)

		_refund_attack_resources(
			actual_energy_cost,
			energy_spent,
			protection_spent
		)

		return false

	# ----------------------------------------------
	# RECHECK TARGET
	# ----------------------------------------------

	if not is_instance_valid(target):
		target = character.find_nearest_enemy()

	if not is_instance_valid(target):
		_return_and_remove_projectile(projectile)

		_refund_attack_resources(
			actual_energy_cost,
			energy_spent,
			protection_spent
		)

		return false

	var current_scene: Node = (
		get_tree().current_scene
	)

	if current_scene == null:
		_return_and_remove_projectile(projectile)

		_refund_attack_resources(
			actual_energy_cost,
			energy_spent,
			protection_spent
		)

		return false

	# ----------------------------------------------
	# LAUNCH ONE PROJECTILE
	# ----------------------------------------------

	projectile.reparent(
		current_scene,
		true
	)

	var launched: bool = projectile.launch(
		target.global_position,
		target,
		food.food_name,
		final_damage,
		food
	)

	if not launched:
		_return_and_remove_projectile(projectile)

		_refund_attack_resources(
			actual_energy_cost,
			energy_spent,
			protection_spent
		)

		return false

	print(
		"[Projectile] Original food launched: ",
		food.food_name
	)

	return true


# ==================================================
# REFUND ATTACK
# ==================================================

func _refund_attack_resources(
	energy_cost: float,
	energy_spent: bool,
	protection_spent: bool
) -> void:
	if not is_instance_valid(energy_system):
		return

	if energy_spent:
		energy_system.restore_energy(
			energy_cost
		)

		print(
			"[Attack] Refunded energy: ",
			energy_cost
		)

	if protection_spent:
		energy_system.add_energy_protection(1)

		print(
			"[Attack] Refunded protection charge."
		)


# ==================================================
# RESTORE FOOD AFTER FAILURE
# ==================================================

func _return_and_remove_projectile(
	projectile: Node
) -> void:
	if not is_instance_valid(projectile):
		return

	if projectile.has_method(
		"return_food_to_original_parent"
	):
		projectile.return_food_to_original_parent()

	projectile.queue_free()
