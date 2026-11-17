extends Node
class_name CafeteriaCombinationSettings

# ==================================================
# CAFETERIA LEVEL 1
# INSPECTOR FOOD COMBINATION SETTINGS
# GODOT 4.7.1
# ==================================================
#
# Add this node ONLY to the Cafeteria battle scene.
#
# Do not add it to Canteen.
#
# Existing defaults preserve:
# - GO + GO
# - GROW + GROW
# - 1 + 1 = 2
# - 2 + 2 = 4
# - Additive nutrition, charge and damage
# ==================================================


@export_group("Combination Rules")

@export var enable_combinations: bool = true

@export var allow_go_combinations: bool = true

@export var allow_grow_combinations: bool = true

@export_range(2, 4, 1)
var maximum_original_foods: int = 4

@export var require_equal_counts: bool = true


@export_group("Combination Sizes")

@export var allow_one_plus_one: bool = true

@export var allow_two_plus_two: bool = true


@export_group("Level 1 Stat Scaling")

@export_range(0.0, 5.0, 0.05)
var nutrition_multiplier: float = 1.0

@export_range(0.0, 5.0, 0.05)
var charge_multiplier: float = 1.0

@export_range(0.0, 5.0, 0.05)
var projectile_damage_multiplier: float = 1.0


@export_group("Debugging")

@export var print_debug_messages: bool = true


func get_maximum_original_foods() -> int:

	return clampi(
		maximum_original_foods,
		2,
		FoodData.MAX_ORIGINAL_FOODS
	)


func is_combination_size_allowed(
	source_count: int,
	target_count: int
) -> bool:

	if source_count <= 0 or target_count <= 0:
		return false

	if (
		source_count + target_count
		> get_maximum_original_foods()
	):
		return false

	if (
		require_equal_counts
		and source_count != target_count
	):
		return false

	if source_count == 1 and target_count == 1:
		return allow_one_plus_one

	if source_count == 2 and target_count == 2:
		return allow_two_plus_two

	# Unequal combinations are optional.
	# This permits 1 + 2 or 2 + 1 only if
	# Require Equal Counts is disabled.
	if not require_equal_counts:

		if (
			source_count == 1
			and target_count == 2
		):
			return true

		if (
			source_count == 2
			and target_count == 1
		):
			return true

	return false


func scale_combined_stat(
	stat_name: String,
	value: int
) -> int:

	var multiplier: float = 1.0

	match stat_name:

		"nutrition_restore":
			multiplier = nutrition_multiplier

		"charge_gain":
			multiplier = charge_multiplier

		"throw_damage":
			multiplier = projectile_damage_multiplier

	return maxi(
		0,
		roundi(
			float(maxi(value, 0))
			* maxf(multiplier, 0.0)
		)
	)
