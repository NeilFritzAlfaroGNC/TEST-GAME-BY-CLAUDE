
@tool
extends AnimatedSprite2D
class_name FoodData


# ==================================================
# FOOD ENUMS
# ==================================================

enum FoodRarity {
	NORMAL,
	LEGENDARY
}

enum FoodCategory {
	GO,
	GLOW,
	GROW,
	WHOA
}

enum Level1Buff {
	NONE,
	DAMAGE_BOOST,
	SPEED_BOOST,
	COOLDOWN_REDUCTION,
	KNOCKBACK,
	STUN,
	FREEZE,
	BURN
}


const MAX_ORIGINAL_FOODS: int = 4


# ==================================================
# FOOD IDENTITY
# ==================================================

@export_group("Food Information")

@export var food_name: String = ""

@export var food_rarity: FoodRarity = FoodRarity.NORMAL:
	set(value):
		food_rarity = value
		notify_property_list_changed()

@export var normal_category: FoodCategory = FoodCategory.GO:
	set(value):
		normal_category = value
		notify_property_list_changed()

@export_flags("GO", "GLOW", "GROW", "WHOA")
var legendary_categories: int = 0:
	set(value):
		legendary_categories = value
		notify_property_list_changed()


@export_group("Level 1 - GO", "l1_go_")

@export_range(0, 100, 1)
var l1_go_nutrition_restore: int = 20

@export_range(0, 100, 1)
var l1_go_charge_gain: int = 25

@export_range(0, 999, 1)
var l1_go_throw_damage: int = 10

@export var l1_go_buff: Level1Buff = Level1Buff.NONE:
	set(value):
		l1_go_buff = value
		notify_property_list_changed()

@export_range(0.0, 60.0, 0.1)
var l1_go_buff_duration: float = 0.0

@export_range(0.0, 999.0, 0.1)
var l1_go_buff_strength: float = 0.0


# ==================================================
# CAFETERIA LEVEL 1 — GLOW
# ==================================================

@export_group("Level 1 - GLOW", "l1_glow_")

@export_range(0, 100, 1)
var l1_glow_nutrition_restore: int = 20

@export_range(0, 100, 1)
var l1_glow_charge_gain: int = 25

@export_range(0, 999, 1)
var l1_glow_throw_damage: int = 10

@export var l1_glow_buff: Level1Buff = Level1Buff.NONE:
	set(value):
		l1_glow_buff = value
		notify_property_list_changed()

@export_range(0.0, 60.0, 0.1)
var l1_glow_buff_duration: float = 0.0

@export_range(0.0, 999.0, 0.1)
var l1_glow_buff_strength: float = 0.0


# ==================================================
# CAFETERIA LEVEL 1 — GROW
# ==================================================

@export_group("Level 1 - GROW", "l1_grow_")

@export_range(0, 100, 1)
var l1_grow_nutrition_restore: int = 20

@export_range(0, 100, 1)
var l1_grow_charge_gain: int = 25

@export_range(0, 999, 1)
var l1_grow_throw_damage: int = 10

@export var l1_grow_buff: Level1Buff = Level1Buff.NONE:
	set(value):
		l1_grow_buff = value
		notify_property_list_changed()

@export_range(0.0, 60.0, 0.1)
var l1_grow_buff_duration: float = 0.0

@export_range(0.0, 999.0, 0.1)
var l1_grow_buff_strength: float = 0.0


# ==================================================
# GO — ENERGY EFFECTS
# ==================================================

@export_group("Legacy GO - Energy")


# --------------------------------------------------
# 1. INSTANT ENERGY RESTORATION
# --------------------------------------------------

@export_subgroup("Instant Energy")

@export var energy_restore: float = 20.0


# --------------------------------------------------
# 2. ENERGY OVER TIME
# --------------------------------------------------

@export_subgroup("Energy Over Time")

@export var enable_energy_over_time: bool = false:
	set(value):
		enable_energy_over_time = value
		notify_property_list_changed()

@export var energy_over_time_rate: float = 5.0

@export var energy_over_time_duration: float = 5.0


# --------------------------------------------------
# 3. REGENERATION BOOST
# --------------------------------------------------

@export_subgroup("Regeneration Boost")

@export var enable_regeneration_boost: bool = false:
	set(value):
		enable_regeneration_boost = value
		notify_property_list_changed()

@export var regeneration_bonus: float = 1.0

@export var regeneration_boost_duration: float = 10.0


# --------------------------------------------------
# 4. ENERGY DISCOUNT
# --------------------------------------------------

@export_subgroup("Energy Discount")

@export var enable_energy_discount: bool = false:
	set(value):
		enable_energy_discount = value
		notify_property_list_changed()

@export_range(0.0, 100.0, 1.0)
var energy_discount_percent: float = 20.0

@export var energy_discount_duration: float = 10.0


# --------------------------------------------------
# 5. ENERGY PROTECTION
# --------------------------------------------------

@export_subgroup("Energy Protection")

@export var enable_energy_protection: bool = false:
	set(value):
		enable_energy_protection = value
		notify_property_list_changed()

@export_range(1, 10, 1)
var energy_protection_charges: int = 1


# ==================================================
# GLOW — ATTACK EFFECTS
# ==================================================

@export_group("Legacy GLOW - Attack")


# --------------------------------------------------
# BASE ATTACK
# --------------------------------------------------

@export var energy_cost: float = 10.0

@export var base_damage: float = 10.0


# --------------------------------------------------
# 1. FREEZE
# --------------------------------------------------

@export_subgroup("Freeze")

@export var enable_freeze: bool = false:
	set(value):
		enable_freeze = value
		notify_property_list_changed()

@export var freeze_duration: float = 3.0


# --------------------------------------------------
# 2. STUN
# --------------------------------------------------

@export_subgroup("Stun")

@export var enable_stun: bool = false:
	set(value):
		enable_stun = value
		notify_property_list_changed()

@export var stun_duration: float = 2.0


# --------------------------------------------------
# 3. BURN
# --------------------------------------------------

@export_subgroup("Burn")

@export var enable_burn: bool = false:
	set(value):
		enable_burn = value
		notify_property_list_changed()

@export var burn_tick_damage: float = 2.0

@export var burn_duration: float = 5.0

@export_range(1, 100, 1)
var burn_tick_count: int = 5

@export_range(0.1, 60.0, 0.1)
var burn_tick_interval: float = 2.0


# --------------------------------------------------
# 4. KNOCKBACK
# --------------------------------------------------

@export_subgroup("Knockback")

@export var enable_knockback: bool = false:
	set(value):
		enable_knockback = value
		notify_property_list_changed()

@export var knockback_strength: float = 100.0


# ==================================================
# GROW — FIVE BUFF EFFECTS
# ==================================================

@export_group("Legacy GROW - Buff")


# --------------------------------------------------
# 1. DAMAGE
# --------------------------------------------------

@export_subgroup("1. Damage")

@export var grow_enable_damage: bool = true:
	set(value):
		grow_enable_damage = value
		notify_property_list_changed()

@export var damage_bonus: float = 10.0


# --------------------------------------------------
# 2. ENLARGE
# --------------------------------------------------

@export_subgroup("2. Enlarge")

@export var grow_enable_enlarge: bool = false:
	set(value):
		grow_enable_enlarge = value
		notify_property_list_changed()

@export_range(1.0, 10.0, 0.1)
var grow_size_multiplier: float = 2.5


# --------------------------------------------------
# 3. KNOCKBACK
# --------------------------------------------------

@export_subgroup("3. Knockback")

@export var grow_enable_knockback: bool = false:
	set(value):
		grow_enable_knockback = value
		notify_property_list_changed()

@export_range(0.0, 2000.0, 1.0)
var grow_knockback_strength: float = 250.0


# --------------------------------------------------
# 4. STUN
# --------------------------------------------------

@export_subgroup("4. Stun")

@export var grow_enable_stun: bool = false:
	set(value):
		grow_enable_stun = value
		notify_property_list_changed()

@export_range(0.0, 30.0, 0.1)
var grow_stun_duration: float = 2.0


# --------------------------------------------------
# 5. FLOPPING TRAJECTORY
# --------------------------------------------------

@export_subgroup("5. Flopping Trajectory")

@export var grow_enable_flopping: bool = false:
	set(value):
		grow_enable_flopping = value
		notify_property_list_changed()

# Maximum number of different enemies
# a single projectile can damage.
@export_range(1, 20, 1)
var grow_flop_max_hits: int = 5

# Maximum distance to search for
# another unhit enemy.
@export_range(50.0, 1000.0, 10.0)
var grow_flop_bounce_range: float = 250.0

# Time needed to bounce toward
# the next enemy.
@export_range(0.05, 2.0, 0.05)
var grow_flop_bounce_duration: float = 0.3

# Height of the curved bouncing path.
@export_range(0.0, 300.0, 5.0)
var grow_flop_bounce_height: float = 65.0

# When no other enemy is available,
# bounce randomly once before disappearing.
@export var grow_flop_random_fallback: bool = true


# --------------------------------------------------
# GROW DURATION AND USES
# --------------------------------------------------

@export_subgroup("Duration and Uses")

# How long the player has to use the buff.
@export_range(0.0, 120.0, 0.5)
var buff_duration: float = 5.0

# Number of GLOW attacks that can use the buff.
@export_range(1, 100, 1)
var buff_uses: int = 1


# ==================================================
# WHOA — RISK AND REWARD
# ==================================================

@export_group("Legacy WHOA - Risk and Reward")

@export var whoa_energy_restore: float = 0.0

@export var whoa_energy_cost: float = 0.0

@export var whoa_debuff_duration: float = 0.0


# ==================================================
# FOOD COMBINATION DATA
# ==================================================

# One original food counts as one ingredient.
# Existing combination data is retained.
# New GROW combination gameplay will be added later.

var original_food_count: int = 1

var inherited_go_effects: Array[Dictionary] = []

var inherited_grow_effects: Array[Dictionary] = []
var inherited_level1_stats: Array[Dictionary] = []


# ==================================================
# CHECK IF FOOD IS COMBINED
# ==================================================

func is_combined() -> bool:
	return original_food_count > 1


# ==================================================
# CHECK FOOD CATEGORY
# ==================================================

func has_category(
	category: FoodCategory
) -> bool:

	if food_rarity == FoodRarity.NORMAL:
		return normal_category == category

	# Legendary foods may belong to
	# multiple food categories.
	return (
		legendary_categories
		& (1 << category)
	) != 0


# ==================================================
# GET FOOD CATEGORY NAMES
# ==================================================

func get_selected_category_names() -> Array[String]:

	var category_names: Array[String] = []

	if food_rarity == FoodRarity.NORMAL:

		category_names.append(
			FoodCategory.keys()[normal_category]
		)

	else:

		for category in FoodCategory.size():

			if has_category(category):

				category_names.append(
					FoodCategory.keys()[category]
				)

	return category_names


func has_level1_nutrition_category() -> bool:

	return (
		has_category(FoodCategory.GO)
		or has_category(FoodCategory.GLOW)
		or has_category(FoodCategory.GROW)
	)


func get_level1_categories() -> Array[int]:

	var categories: Array[int] = []

	for category in [
		FoodCategory.GO,
		FoodCategory.GLOW,
		FoodCategory.GROW
	]:

		if has_category(category):
			categories.append(category)

	return categories


# ==================================================
# LEVEL 1 FOOD STAT LOOKUP
# ==================================================
#
# Returns the properties for ONE category.
#
# GO   = 0
# GLOW = 1
# GROW = 2
#
# Returns {} when the food does not contain
# the requested category.
# ==================================================

func get_level1_stats(category: int) -> Dictionary:

	if not has_level1_nutrition_category():
		return {}

	var statistics: Dictionary = {}

	match category:

		FoodCategory.GO:

			if not has_category(FoodCategory.GO):
				return {}

			statistics = {
				"nutrition_restore":
					l1_go_nutrition_restore,
				"charge_gain":
					l1_go_charge_gain,
				"throw_damage":
					l1_go_throw_damage,
				"buff_id":
					_get_level1_buff_name(l1_go_buff),
				"buff_duration":
					l1_go_buff_duration,
				"buff_strength":
					l1_go_buff_strength
			}

		FoodCategory.GLOW:

			if not has_category(FoodCategory.GLOW):
				return {}

			statistics = {
				"nutrition_restore":
					l1_glow_nutrition_restore,
				"charge_gain":
					l1_glow_charge_gain,
				"throw_damage":
					l1_glow_throw_damage,
				"buff_id":
					_get_level1_buff_name(l1_glow_buff),
				"buff_duration":
					l1_glow_buff_duration,
				"buff_strength":
					l1_glow_buff_strength
			}

		FoodCategory.GROW:

			if not has_category(FoodCategory.GROW):
				return {}

			statistics = {
				"nutrition_restore":
					l1_grow_nutrition_restore,
				"charge_gain":
					l1_grow_charge_gain,
				"throw_damage":
					l1_grow_throw_damage,
				"buff_id":
					_get_level1_buff_name(l1_grow_buff),
				"buff_duration":
					l1_grow_buff_duration,
				"buff_strength":
					l1_grow_buff_strength
			}

		_:
			return {}

	statistics["category"] = category
	statistics["food_name"] = food_name

	return statistics


# ==================================================
# LEVEL 1 ALL FOOD STATS
# ==================================================

func get_all_level1_stats() -> Array[Dictionary]:

	var results: Array[Dictionary] = []

	for category in get_level1_categories():

		var statistics: Dictionary = (
			get_level1_stats(category)
		)

		if not statistics.is_empty():
			results.append(statistics)

	return results


# ==================================================
# LEVEL 1 BUFF NAME
# ==================================================

func _get_level1_buff_name(
	buff: Level1Buff
) -> String:

	match buff:

		Level1Buff.DAMAGE_BOOST:
			return "damage_boost"

		Level1Buff.SPEED_BOOST:
			return "speed_boost"

		Level1Buff.COOLDOWN_REDUCTION:
			return "cooldown_reduction"

		Level1Buff.KNOCKBACK:
			return "knockback"

		Level1Buff.STUN:
			return "stun"

		Level1Buff.FREEZE:
			return "freeze"

		Level1Buff.BURN:
			return "burn"

	return ""


# ==================================================
# GO — GET OWN EFFECTS
# ==================================================

func get_own_go_effects() -> Array[Dictionary]:

	var effects: Array[Dictionary] = []

	if not has_category(FoodCategory.GO):
		return effects

	# ----------------------------------------------
	# INSTANT ENERGY RESTORATION
	# ----------------------------------------------

	if energy_restore > 0.0:

		effects.append({
			"type": "instant_restore",
			"amount": energy_restore
		})

	# ----------------------------------------------
	# ENERGY OVER TIME
	# ----------------------------------------------

	if enable_energy_over_time:

		effects.append({
			"type": "energy_over_time",
			"rate": energy_over_time_rate,
			"duration": energy_over_time_duration
		})

	# ----------------------------------------------
	# REGENERATION BOOST
	# ----------------------------------------------

	if enable_regeneration_boost:

		effects.append({
			"type": "regeneration_boost",
			"bonus": regeneration_bonus,
			"duration": regeneration_boost_duration
		})

	# ----------------------------------------------
	# ENERGY DISCOUNT
	# ----------------------------------------------

	if enable_energy_discount:

		effects.append({
			"type": "energy_discount",
			"percent": energy_discount_percent,
			"duration": energy_discount_duration
		})

	# ----------------------------------------------
	# ENERGY PROTECTION
	# ----------------------------------------------

	if enable_energy_protection:

		effects.append({
			"type": "energy_protection",
			"charges": energy_protection_charges
		})

	return effects


# ==================================================
# GO — GET ALL EFFECTS
# ==================================================

func get_all_go_effects() -> Array[Dictionary]:

	var effects: Array[Dictionary] = (
		get_own_go_effects()
	)

	for inherited_effect in inherited_go_effects:

		effects.append(
			inherited_effect.duplicate(true)
		)

	return effects


# ==================================================
# GO — ABSORB EFFECTS FROM ANOTHER FOOD
# ==================================================

func absorb_go_effects(
	effects: Array[Dictionary],
	food_count: int
) -> void:

	for effect in effects:

		inherited_go_effects.append(
			effect.duplicate(true)
		)

	original_food_count += food_count


# ==================================================
# GROW — GET OWN EFFECTS
# ==================================================

func get_own_grow_effects() -> Array[Dictionary]:

	var effects: Array[Dictionary] = []

	if not has_category(FoodCategory.GROW):
		return effects

	# ----------------------------------------------
	# 1. DAMAGE
	# ----------------------------------------------

	if grow_enable_damage and damage_bonus > 0.0:

		effects.append({
			"type": "damage",
			"value": damage_bonus,
			"duration": buff_duration,
			"uses": buff_uses
		})

	# ----------------------------------------------
	# 2. ENLARGE
	# ----------------------------------------------

	if (
		grow_enable_enlarge
		and grow_size_multiplier > 1.0
	):

		effects.append({
			"type": "enlarge",
			"value": grow_size_multiplier,
			"duration": buff_duration,
			"uses": buff_uses
		})

	# ----------------------------------------------
	# 3. KNOCKBACK
	# ----------------------------------------------

	if (
		grow_enable_knockback
		and grow_knockback_strength > 0.0
	):

		effects.append({
			"type": "knockback",
			"value": grow_knockback_strength,
			"duration": buff_duration,
			"uses": buff_uses
		})

	# ----------------------------------------------
	# 4. STUN
	# ----------------------------------------------

	if (
		grow_enable_stun
		and grow_stun_duration > 0.0
	):

		effects.append({
			"type": "stun",
			"value": grow_stun_duration,
			"duration": buff_duration,
			"uses": buff_uses
		})

	# ----------------------------------------------
	# 5. FLOPPING TRAJECTORY
	# ----------------------------------------------

	if grow_enable_flopping:

		effects.append({
			"type": "flopping",
			"value": float(grow_flop_max_hits),
			"duration": buff_duration,
			"uses": buff_uses,
			"settings": {
				"bounce_range": grow_flop_bounce_range,
				"bounce_duration": grow_flop_bounce_duration,
				"bounce_height": grow_flop_bounce_height,
				"random_fallback": grow_flop_random_fallback
			}
		})

	return effects


# ==================================================
# GROW — GET ALL EFFECTS
# ==================================================

func get_all_grow_effects() -> Array[Dictionary]:

	var effects: Array[Dictionary] = (
		get_own_grow_effects()
	)

	for inherited_effect in inherited_grow_effects:

		effects.append(
			inherited_effect.duplicate(true)
		)

	return effects


# ==================================================
# GROW — ABSORB EFFECTS FROM ANOTHER FOOD
# ==================================================

func absorb_grow_effects(
	effects: Array[Dictionary],
	food_count: int
) -> void:

	for effect in effects:

		inherited_grow_effects.append(
			effect.duplicate(true)
		)

	original_food_count += food_count


# ==================================================
# DYNAMIC INSPECTOR VISIBILITY
# ==================================================

func _validate_property(
	property: Dictionary
) -> void:

	# FIXED:
	# Do not use "name" as a local variable,
	# because Node already has a name property.

	var property_name: String = str(
		property.get("name", "")
	)

	# ----------------------------------------------
	# FOOD CATEGORY SELECTION
	# ----------------------------------------------

	if property_name == "normal_category":

		if food_rarity != FoodRarity.NORMAL:

			property.usage = (
				PROPERTY_USAGE_NO_EDITOR
			)

		return

	if property_name == "legendary_categories":

		if food_rarity != FoodRarity.LEGENDARY:

			property.usage = (
				PROPERTY_USAGE_NO_EDITOR
			)

		return

	if property_name.begins_with("l1_go_"):

		if not has_category(FoodCategory.GO):
			property.usage &= ~PROPERTY_USAGE_EDITOR

		elif property_name in [
			"l1_go_buff_duration",
			"l1_go_buff_strength"
		] and l1_go_buff == Level1Buff.NONE:
			property.usage &= ~PROPERTY_USAGE_EDITOR

		return

	if property_name.begins_with("l1_glow_"):

		if not has_category(FoodCategory.GLOW):
			property.usage &= ~PROPERTY_USAGE_EDITOR

		elif property_name in [
			"l1_glow_buff_duration",
			"l1_glow_buff_strength"
		] and l1_glow_buff == Level1Buff.NONE:
			property.usage &= ~PROPERTY_USAGE_EDITOR

		return

	if property_name.begins_with("l1_grow_"):

		if not has_category(FoodCategory.GROW):
			property.usage &= ~PROPERTY_USAGE_EDITOR

		elif property_name in [
			"l1_grow_buff_duration",
			"l1_grow_buff_strength"
		] and l1_grow_buff == Level1Buff.NONE:
			property.usage &= ~PROPERTY_USAGE_EDITOR

		return

	# ----------------------------------------------
	# CATEGORY FLAGS
	# ----------------------------------------------

	var is_go: bool = has_category(
		FoodCategory.GO
	)

	var is_glow: bool = has_category(
		FoodCategory.GLOW
	)

	var is_grow: bool = has_category(
		FoodCategory.GROW
	)

	var is_whoa: bool = has_category(
		FoodCategory.WHOA
	)

	# ==================================================
	# GO INSPECTOR PROPERTIES
	# ==================================================

	if property_name in [
		"energy_restore",
		"enable_energy_over_time",
		"enable_regeneration_boost",
		"enable_energy_discount",
		"enable_energy_protection"
	]:

		if not is_go:

			property.usage = (
				PROPERTY_USAGE_NO_EDITOR
			)

		return

	# ----------------------------------------------
	# ENERGY OVER TIME
	# ----------------------------------------------

	if property_name in [
		"energy_over_time_rate",
		"energy_over_time_duration"
	]:

		if (
			not is_go
			or not enable_energy_over_time
		):

			property.usage = (
				PROPERTY_USAGE_NO_EDITOR
			)

		return

	# ----------------------------------------------
	# REGENERATION BOOST
	# ----------------------------------------------

	if property_name in [
		"regeneration_bonus",
		"regeneration_boost_duration"
	]:

		if (
			not is_go
			or not enable_regeneration_boost
		):

			property.usage = (
				PROPERTY_USAGE_NO_EDITOR
			)

		return

	# ----------------------------------------------
	# ENERGY DISCOUNT
	# ----------------------------------------------

	if property_name in [
		"energy_discount_percent",
		"energy_discount_duration"
	]:

		if (
			not is_go
			or not enable_energy_discount
		):

			property.usage = (
				PROPERTY_USAGE_NO_EDITOR
			)

		return

	# ----------------------------------------------
	# ENERGY PROTECTION
	# ----------------------------------------------

	if property_name == "energy_protection_charges":

		if (
			not is_go
			or not enable_energy_protection
		):

			property.usage = (
				PROPERTY_USAGE_NO_EDITOR
			)

		return

	# ==================================================
	# GLOW INSPECTOR PROPERTIES
	# ==================================================

	if property_name in [
		"energy_cost",
		"base_damage",
		"enable_freeze",
		"enable_stun",
		"enable_burn",
		"enable_knockback"
	]:

		if not is_glow:

			property.usage = (
				PROPERTY_USAGE_NO_EDITOR
			)

		return

	# ----------------------------------------------
	# FREEZE
	# ----------------------------------------------

	if property_name == "freeze_duration":

		if (
			not is_glow
			or not enable_freeze
		):

			property.usage = (
				PROPERTY_USAGE_NO_EDITOR
			)

		return

	# ----------------------------------------------
	# STUN
	# ----------------------------------------------

	if property_name == "stun_duration":

		if (
			not is_glow
			or not enable_stun
		):

			property.usage = (
				PROPERTY_USAGE_NO_EDITOR
			)

		return

	# ----------------------------------------------
	# BURN
	# ----------------------------------------------

	if property_name in [
		"burn_tick_damage",
		"burn_duration",
		"burn_tick_count",
		"burn_tick_interval"
	]:

		if (
			not is_glow
			or not enable_burn
		):

			property.usage = (
				PROPERTY_USAGE_NO_EDITOR
			)

		return

	# ----------------------------------------------
	# KNOCKBACK
	# ----------------------------------------------

	if property_name == "knockback_strength":

		if (
			not is_glow
			or not enable_knockback
		):

			property.usage = (
				PROPERTY_USAGE_NO_EDITOR
			)

		return

	# ==================================================
	# GROW INSPECTOR PROPERTIES
	# ==================================================

	# Main GROW checkboxes and settings.
	if property_name in [
		"grow_enable_damage",
		"grow_enable_enlarge",
		"grow_enable_knockback",
		"grow_enable_stun",
		"grow_enable_flopping",
		"buff_duration",
		"buff_uses"
	]:

		if not is_grow:

			property.usage = (
				PROPERTY_USAGE_NO_EDITOR
			)

		return

	# ----------------------------------------------
	# 1. DAMAGE
	# ----------------------------------------------

	if property_name == "damage_bonus":

		if (
			not is_grow
			or not grow_enable_damage
		):

			property.usage = (
				PROPERTY_USAGE_NO_EDITOR
			)

		return

	# ----------------------------------------------
	# 2. ENLARGE
	# ----------------------------------------------

	if property_name == "grow_size_multiplier":

		if (
			not is_grow
			or not grow_enable_enlarge
		):

			property.usage = (
				PROPERTY_USAGE_NO_EDITOR
			)

		return

	# ----------------------------------------------
	# 3. KNOCKBACK
	# ----------------------------------------------

	if property_name == "grow_knockback_strength":

		if (
			not is_grow
			or not grow_enable_knockback
		):

			property.usage = (
				PROPERTY_USAGE_NO_EDITOR
			)

		return

	# ----------------------------------------------
	# 4. STUN
	# ----------------------------------------------

	if property_name == "grow_stun_duration":

		if (
			not is_grow
			or not grow_enable_stun
		):

			property.usage = (
				PROPERTY_USAGE_NO_EDITOR
			)

		return

	# ----------------------------------------------
	# 5. FLOPPING TRAJECTORY
	# ----------------------------------------------

	if property_name in [
		"grow_flop_max_hits",
		"grow_flop_bounce_range",
		"grow_flop_bounce_duration",
		"grow_flop_bounce_height",
		"grow_flop_random_fallback"
	]:

		if (
			not is_grow
			or not grow_enable_flopping
		):

			property.usage = (
				PROPERTY_USAGE_NO_EDITOR
			)

		return

	# ==================================================
	# WHOA INSPECTOR PROPERTIES
	# ==================================================

	if property_name in [
		"whoa_energy_restore",
		"whoa_energy_cost",
		"whoa_debuff_duration"
	]:

		if not is_whoa:

			property.usage = (
				PROPERTY_USAGE_NO_EDITOR
			)

		return
