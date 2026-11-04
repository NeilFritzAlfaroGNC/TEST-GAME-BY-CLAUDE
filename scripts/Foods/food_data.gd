
@tool
extends AnimatedSprite2D
class_name FoodData

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

@export_group("Food Information")
@export var food_name: String = ""

@export var food_rarity: FoodRarity = FoodRarity.NORMAL:
	set(value):
		food_rarity = value
		notify_property_list_changed()

@export_enum("GO", "GLOW", "GROW", "WHOA")
var normal_category: int = FoodCategory.GO:
	set(value):
		normal_category = value
		notify_property_list_changed()

@export_flags("GO", "GLOW", "GROW", "WHOA")
var legendary_categories: int = 0:
	set(value):
		legendary_categories = value
		notify_property_list_changed()


@export_group("GO — Energy")
@export var energy_restore: float = 20.0


@export_group("GLOW — Attack")
@export var energy_cost: float = 10.0
@export var base_damage: float = 10.0


@export_subgroup("Attack Effects")

@export var enable_freeze: bool = false:
	set(value):
		enable_freeze = value
		notify_property_list_changed()

@export var freeze_duration: float = 3.0


@export var enable_stun: bool = false:
	set(value):
		enable_stun = value
		notify_property_list_changed()

@export var stun_duration: float = 2.0


@export var enable_burn: bool = false:
	set(value):
		enable_burn = value
		notify_property_list_changed()

@export var burn_tick_damage: float = 2.0
@export var burn_duration: float = 5.0
@export_range(1, 100, 1) var burn_tick_count: int = 5
@export_range(0.1, 60.0, 0.1) var burn_tick_interval: float = 2.0


@export var enable_knockback: bool = false:
	set(value):
		enable_knockback = value
		notify_property_list_changed()

@export var knockback_strength: float = 100.0


@export_group("GROW — Buff")
@export var damage_bonus: float = 10.0
@export var buff_duration: float = 5.0
@export var buff_uses: int = 1


@export_group("WHOA — Risk and Reward")
@export var whoa_energy_restore: float = 0.0
@export var whoa_energy_cost: float = 0.0
@export var whoa_debuff_duration: float = 0.0


func has_category(category: FoodCategory) -> bool:
	if food_rarity == FoodRarity.NORMAL:
		return normal_category == category

	return (legendary_categories & (1 << category)) != 0


func get_selected_category_names() -> Array[String]:
	var categories: Array[String] = []

	if food_rarity == FoodRarity.NORMAL:
		categories.append(FoodCategory.keys()[normal_category])
	else:
		for category in FoodCategory.size():
			if has_category(category):
				categories.append(FoodCategory.keys()[category])

	return categories


func _validate_property(property: Dictionary) -> void:
	var property_name: String = property.name

	if property_name == "normal_category":
		if food_rarity != FoodRarity.NORMAL:
			property.usage = PROPERTY_USAGE_NO_EDITOR
		return

	if property_name == "legendary_categories":
		if food_rarity != FoodRarity.LEGENDARY:
			property.usage = PROPERTY_USAGE_NO_EDITOR
		return

	if property_name == "energy_restore":
		if not has_category(FoodCategory.GO):
			property.usage = PROPERTY_USAGE_NO_EDITOR
		return

	if property_name == "freeze_duration":
		if not has_category(FoodCategory.GLOW) or not enable_freeze:
			property.usage = PROPERTY_USAGE_NO_EDITOR
		return

	if property_name == "stun_duration":
		if not has_category(FoodCategory.GLOW) or not enable_stun:
			property.usage = PROPERTY_USAGE_NO_EDITOR
		return

	if property_name in [
		"burn_tick_damage",
		"burn_duration",
		"burn_tick_count",
		"burn_tick_interval"
	]:
		if not has_category(FoodCategory.GLOW) or not enable_burn:
			property.usage = PROPERTY_USAGE_NO_EDITOR
		return

	if property_name == "knockback_strength":
		if not has_category(FoodCategory.GLOW) or not enable_knockback:
			property.usage = PROPERTY_USAGE_NO_EDITOR
		return

	if property_name in [
		"energy_cost",
		"base_damage",
		"enable_freeze",
		"enable_stun",
		"enable_burn",
		"enable_knockback"
	]:
		if not has_category(FoodCategory.GLOW):
			property.usage = PROPERTY_USAGE_NO_EDITOR
		return

	if property_name in ["damage_bonus", "buff_duration", "buff_uses"]:
		if not has_category(FoodCategory.GROW):
			property.usage = PROPERTY_USAGE_NO_EDITOR
		return

	if property_name in [
		"whoa_energy_restore",
		"whoa_energy_cost",
		"whoa_debuff_duration"
	]:
		if not has_category(FoodCategory.WHOA):
			property.usage = PROPERTY_USAGE_NO_EDITOR
		return
