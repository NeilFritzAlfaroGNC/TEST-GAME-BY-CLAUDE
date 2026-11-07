
extends Node
class_name FoodCombination

# This script only contains rules and helper functions.
# It does NOT need to be added to any scene.
#
# Existing usage:
# FoodCombination.try_combine(source, target)

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

	# Show/update the existing x2 or x4 badge.
	update_indicator(target_food)

	# ----------------------------------------------
	# REMOVE SOURCE
	# ----------------------------------------------

	source_food.remove_from_group("food")
	source_food.queue_free()

	return true


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
