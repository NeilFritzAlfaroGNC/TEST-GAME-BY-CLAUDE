
extends Node
class_name FoodCombination

# This script only contains rules and helper functions.
# It does NOT need to be added to any scene.
#
# Existing usage:
# FoodCombination.try_combine(source, target)

const LEVEL1_STATS_META := &"cafeteria_l1_combined_stats"

const INDICATOR_NAME: String = "CombinationIndicator"

const BADGE_SIZE: Vector2 = Vector2(46, 26)
const BADGE_FONT_SIZE: int = 18


# ==================================================
# COMBINATION VALIDATION
# ==================================================

# Returns an empty string if combination is allowed.
# Otherwise returns the reason for rejection.
static func get_reject_reason(
	source: Node2D,
	target: Node2D
) -> String:

	var source_food: FoodData = source as FoodData
	var target_food: FoodData = target as FoodData

	if source_food == null or target_food == null:
		return "One of the foods has no FoodData script."

	if not is_instance_valid(source_food):
		return "Source food is invalid."

	if not is_instance_valid(target_food):
		return "Target food is invalid."

	if source_food == target_food:
		return "A food cannot combine with itself."

	if source_food.is_queued_for_deletion() or target_food.is_queued_for_deletion():
		return "One of the foods is being deleted."

	# ----------------------------------------------
	# IDENTIFY COMBINATION CATEGORY
	# ----------------------------------------------

	var source_is_go: bool = _is_go_only(source_food)
	var target_is_go: bool = _is_go_only(target_food)

	var source_is_grow: bool = _is_grow_only(source_food)
	var target_is_grow: bool = _is_grow_only(target_food)

	var both_go: bool = (
		source_is_go and target_is_go
	)

	var both_grow: bool = (
		source_is_grow and target_is_grow
	)

	if not both_go and not both_grow:
		return (
			"Only GO + GO or GROW + GROW "
			+ "combinations are allowed."
		)

	var settings := get_cafeteria_settings(target_food)
	if settings != null:
		if not settings.enable_combinations:
			return "Food combinations are disabled."
		if both_go and not settings.allow_go_combinations:
			return "GO combinations are disabled."
		if both_grow and not settings.allow_grow_combinations:
			return "GROW combinations are disabled."
		if not settings.is_combination_size_allowed(source_food.original_food_count, target_food.original_food_count):
			return "Ingredient counts do not match the Cafeteria combination settings."
		return ""

	# ----------------------------------------------
	# CHECK ORIGINAL FOOD COUNTS
	# ----------------------------------------------

	var source_count: int = (
		source_food.original_food_count
	)

	var target_count: int = (
		target_food.original_food_count
	)

	# The two sides must contain equal numbers
	# of original foods.
	#
	# Valid:
	# 1 + 1 = 2
	# 2 + 2 = 4
	#
	# Invalid:
	# 2 + 1 = 3
	# 3 + 1 = 4

	if source_count != target_count:
		return (
			"Foods must contain an equal number "
			+ "of original ingredients. "
			+ "Source: "
			+ str(source_count)
			+ ", Target: "
			+ str(target_count)
			+ "."
		)

	# ----------------------------------------------
	# MAXIMUM FOUR ORIGINAL FOODS
	# ----------------------------------------------

	var total_foods: int = (
		source_count + target_count
	)

	if total_foods > FoodData.MAX_ORIGINAL_FOODS:
		return (
			"A combined food can hold at most "
			+ str(FoodData.MAX_ORIGINAL_FOODS)
			+ " original foods."
		)

	# ----------------------------------------------
	# ONLY 1 + 1 OR 2 + 2
	# ----------------------------------------------

	if source_count != 1 and source_count != 2:
		return (
			"Only 1 + 1 or 2 + 2 "
			+ "combinations are allowed."
		)

	return ""


# ==================================================
# COMBINE FOODS
# ==================================================

# Returns true if combination succeeded.
#
# SOURCE disappears.
# TARGET survives.
#
# Does not activate buffs or restore energy.
# Only transfers effect data.
static func try_combine(
	source: Node2D,
	target: Node2D
) -> bool:

	var reason: String = get_reject_reason(
		source,
		target
	)

	if not reason.is_empty():
		print("[Combine] Rejected: ", reason)
		return false

	var source_food: FoodData = source as FoodData
	var target_food: FoodData = target as FoodData

	if not is_instance_valid(source_food):
		return false

	if not is_instance_valid(target_food):
		return false

	var combined_stats: Array[Dictionary] = []
	if target_food.is_inside_tree():
		var battle := target_food.get_tree().current_scene
		if battle != null and battle.has_node("NutritionFoodBridge"):
			combined_stats = _merge_level1_stats(target_food, source_food, get_cafeteria_settings(target_food))

	# Capture the original food count once.
	# Each absorb method increments the count.
	# We must call only ONE absorb method.

	var source_count: int = (
		source_food.original_food_count
	)

	# ----------------------------------------------
	# GO + GO
	# ----------------------------------------------

	if _is_go_only(source_food) and _is_go_only(target_food):

		var source_go_effects: Array[Dictionary] = (
			source_food.get_all_go_effects()
		)

		target_food.absorb_go_effects(
			source_go_effects,
			source_count
		)

		print(
			"[Combine] GO combination completed."
		)

		for effect in target_food.get_all_go_effects():
			print(
				"[Combine]   GO effect stored: ",
				effect
			)

	# ----------------------------------------------
	# GROW + GROW
	# ----------------------------------------------

	elif _is_grow_only(source_food) and _is_grow_only(target_food):

		var source_grow_effects: Array[Dictionary] = (
			source_food.get_all_grow_effects()
		)

		target_food.absorb_grow_effects(
			source_grow_effects,
			source_count
		)

		print(
			"[Combine] GROW combination completed."
		)

		for effect in target_food.get_all_grow_effects():
			print(
				"[Combine]   GROW effect stored: ",
				effect
			)

	else:
		return false

	# ----------------------------------------------
	# DISPLAY COMBINATION INFORMATION
	# ----------------------------------------------

	print(
		"[Combine] '",
		source_food.food_name,
		"' was combined into '",
		target_food.food_name,
		"'. Original foods: ",
		target_food.original_food_count
	)

	if not combined_stats.is_empty():
		target_food.set_meta(LEVEL1_STATS_META, combined_stats)
		var settings := get_cafeteria_settings(target_food)
		if settings == null or settings.print_debug_messages:
			var stats := combined_stats[0]
			print("[Combine] Cafeteria stats prepared for ", target_food.food_name, " ×", target_food.original_food_count)
			print(
				"[Combine] ", target_food.get_selected_category_names()[0],
				" | Nutrition: ", stats.nutrition_restore, " | Charge: ", stats.charge_gain,
				" | Damage: ", stats.throw_damage, " | Active Buff: ", stats.buff_id,
				" | Stored Buffs: ", stats.buff_options.size()
			)

	# Show/update the existing x2 or x4 badge.
	update_indicator(target_food)

	# ----------------------------------------------
	# REMOVE SOURCE
	# ----------------------------------------------

	source_food.remove_from_group("food")
	source_food.queue_free()

	return true


static func get_cafeteria_settings(food: FoodData) -> CafeteriaCombinationSettings:
	if not food.is_inside_tree():
		return null
	var battle := food.get_tree().current_scene
	if battle == null or not battle.is_ancestor_of(food) or not battle.has_node("NutritionFoodBridge"):
		return null
	return battle.get_node_or_null("CafeteriaCombinationSettings") as CafeteriaCombinationSettings


static func get_level1_stats(food: FoodData) -> Array[Dictionary]:
	if food.is_combined() and food.has_meta(LEVEL1_STATS_META):
		var stats: Array[Dictionary] = food.get_meta(LEVEL1_STATS_META)
		return stats.duplicate(true)
	return food.get_all_level1_stats()


static func _merge_level1_stats(
	target: FoodData, source: FoodData, settings: CafeteriaCombinationSettings
) -> Array[Dictionary]:
	# Valid combinations have exactly one matching category on both sides.
	var target_stats := get_level1_stats(target)[0]
	var source_stats := get_level1_stats(source)[0]
	var merged := target_stats.duplicate(true)
	for property in ["nutrition_restore", "charge_gain", "throw_damage"]:
		var total := maxi(0, target_stats[property]) + maxi(0, source_stats[property])
		merged[property] = settings.scale_combined_stat(property, total) if settings != null else total

	var options := _get_buff_options(target_stats)
	options.append_array(_get_buff_options(source_stats))
	merged["buff_options"] = options
	# Target-first ordering also preserves the selected buff of an existing ×2.
	if not options.is_empty():
		var selected := options[0]
		merged["buff_id"] = selected.buff_id
		merged["buff_duration"] = selected.buff_duration
		merged["buff_strength"] = selected.buff_strength
	return [merged]


static func _get_buff_options(stats: Dictionary) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	if stats.has("buff_options"):
		options.assign(stats.buff_options)
	elif not String(stats.buff_id).is_empty():
		options.append({
			"source_food_name": stats.food_name,
			"buff_id": stats.buff_id,
			"buff_duration": stats.buff_duration,
			"buff_strength": stats.buff_strength,
		})
	return options


# ==================================================
# COMBINATION INDICATOR
# ==================================================

static func update_indicator(
	food: FoodData
) -> void:

	if not is_instance_valid(food):
		return

	var indicator: Node2D = (
		food.get_node_or_null(
			INDICATOR_NAME
		) as Node2D
	)

	# Ordinary food gets no badge.
	if not food.is_combined():

		if indicator != null:
			indicator.queue_free()

		return

	# Create badge if needed.
	if indicator == null:

		indicator = _create_indicator()

		food.add_child(
			indicator
		)

	# Cancel food sprite scale so the badge
	# always has a consistent screen size.

	var safe_scale: Vector2 = Vector2(
		maxf(absf(food.scale.x), 0.001),
		maxf(absf(food.scale.y), 0.001)
	)

	indicator.scale = (
		Vector2.ONE / safe_scale
	)

	# Place badge at top center.
	var half_size: Vector2 = (
		_get_food_size(food) * 0.5
	)

	indicator.position = Vector2(
		0.0,
		-half_size.y
	)

	var indicator_label: Label = (
		indicator.get_node_or_null(
			"Text"
		) as Label
	)

	if indicator_label != null:
		indicator_label.text = (
			"×" + str(food.original_food_count)
		)


# ==================================================
# CREATE COMBINATION BADGE
# ==================================================

static func _create_indicator() -> Node2D:

	var indicator: Node2D = Node2D.new()
	indicator.name = INDICATOR_NAME

	var indicator_label: Label = Label.new()
	indicator_label.name = "Text"

	indicator_label.custom_minimum_size = BADGE_SIZE
	indicator_label.size = BADGE_SIZE

	indicator_label.position = Vector2(
		-BADGE_SIZE.x * 0.5,
		-BADGE_SIZE.y - 4.0
	)

	indicator_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	indicator_label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)

	indicator_label.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	indicator_label.add_theme_font_size_override(
		"font_size",
		BADGE_FONT_SIZE
	)

	indicator_label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.85, 0.2)
	)

	indicator_label.add_theme_color_override(
		"font_outline_color",
		Color.BLACK
	)

	indicator_label.add_theme_constant_override(
		"outline_size",
		3
	)

	var badge_background: StyleBoxFlat = (
		StyleBoxFlat.new()
	)

	badge_background.bg_color = Color(
		0.1,
		0.1,
		0.1,
		0.85
	)

	badge_background.set_corner_radius_all(
		8
	)

	indicator_label.add_theme_stylebox_override(
		"normal",
		badge_background
	)

	indicator.add_child(
		indicator_label
	)

	return indicator


# ==================================================
# GET FOOD SPRITE SIZE
# ==================================================

static func _get_food_size(
	food: FoodData
) -> Vector2:

	if food.sprite_frames != null:

		var food_texture: Texture2D = (
			food.sprite_frames.get_frame_texture(
				food.animation,
				food.frame
			)
		)

		if food_texture != null:
			return food_texture.get_size()

	return Vector2(128, 128)


# ==================================================
# CATEGORY VALIDATION
# ==================================================

# True only if the food's sole category is GO.
static func _is_go_only(
	food: FoodData
) -> bool:

	if not is_instance_valid(food):
		return false

	return (
		food.has_category(
			FoodData.FoodCategory.GO
		)
		and food.get_selected_category_names().size() == 1
	)


# True only if the food's sole category is GROW.
static func _is_grow_only(
	food: FoodData
) -> bool:

	if not is_instance_valid(food):
		return false

	return (
		food.has_category(
			FoodData.FoodCategory.GROW
		)
		and food.get_selected_category_names().size() == 1
	)
