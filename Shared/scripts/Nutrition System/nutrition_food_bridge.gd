
extends Node
class_name NutritionFoodBridge

# ==================================================
# CAFETERIA LEVEL 1
# NUTRITION + THROW CHARGE + PLAYER BUFFS
# GODOT 4.7.1
# ==================================================
#
# Preserves:
# - Ordinary food consumption
# - Combined GO and GROW food statistics
# - Nutrition restoration
# - Throw Charge
# - Projectile damage and projectile buffs
# - Compatibility with CafeteriaLevel1Controller
#
# Adds:
# - Damage Boost from eating
# - Cooldown Reduction from eating
# - Charge Boost from eating
# - Charge Boost multiplier for subsequent food
#
# ==================================================


signal food_processed(
	food_name: String,
	category: int,
	nutrition_restored: int,
	throw_charge_added: int
)


# ==================================================
# SETTINGS
# ==================================================

@export_group("Nutrition and Throw Charge")

@export var enable_nutrition_restoration: bool = true
@export var enable_throw_charge: bool = true
@export var print_debug_messages: bool = true


# ==================================================
# PLAYER FOOD BUFF SETTINGS
# ==================================================

@export_group("Temporary Player Food Buffs")

@export var enable_player_food_buffs: bool = true
@export var enable_food_name_presets: bool = true


# ==================================================
# DAMAGE BOOST
# ==================================================

@export_subgroup("Damage Boost")

@export var damage_boost_food_names: PackedStringArray = (
	PackedStringArray(["bread"])
)

@export_range(0.0, 200.0, 1.0)
var damage_boost_percent: float = 25.0

@export_range(0.0, 120.0, 0.5)
var damage_boost_duration: float = 8.0


# ==================================================
# COOLDOWN REDUCTION
# ==================================================

@export_subgroup("Cooldown Reduction")

@export var cooldown_boost_food_names: PackedStringArray = (
	PackedStringArray(["apple"])
)

@export_range(0.0, 75.0, 1.0)
var cooldown_reduction_percent: float = 20.0

@export_range(0.0, 120.0, 0.5)
var cooldown_reduction_duration: float = 8.0


# ==================================================
# CHARGE BOOST
# ==================================================

@export_subgroup("Charge Boost")

@export var charge_boost_food_names: PackedStringArray = (
	PackedStringArray(["bean"])
)

@export_range(0.0, 200.0, 1.0)
var charge_boost_percent: float = 50.0

@export_range(0.0, 120.0, 0.5)
var charge_boost_duration: float = 8.0


# ==================================================
# CONSTANTS
# ==================================================

const LEVEL1_STATS_META: String = (
	"cafeteria_l1_combined_stats"
)

const BUFF_DAMAGE: String = "damage_boost"
const BUFF_COOLDOWN: String = "cooldown_reduction"
const BUFF_CHARGE: String = "charge_boost"


# ==================================================
# REFERENCES
# ==================================================

var nutrition_system: NutritionSystem = null
var throw_charge_system: ThrowChargeSystem = null

var item_throw_controller: CafeteriaItemThrowController = null

var main_character: Node = null
var battle_scene: Node = null

var bridge_ready: bool = false


# ==================================================
# READY
# ==================================================

func _ready() -> void:

	call_deferred("_initialize_bridge")


# ==================================================
# INITIALIZE BRIDGE
# ==================================================

func _initialize_bridge() -> void:

	bridge_ready = false

	battle_scene = get_parent()

	if battle_scene == null:
		push_error(
			"[NutritionFoodBridge] Battle scene missing."
		)
		return

	nutrition_system = (
		battle_scene.get_node_or_null(
			"NutritionSystem"
		) as NutritionSystem
	)

	throw_charge_system = (
		battle_scene.get_node_or_null(
			"ThrowChargeSystem"
		) as ThrowChargeSystem
	)

	item_throw_controller = (
		battle_scene.get_node_or_null(
			"ItemThrowController"
		) as CafeteriaItemThrowController
	)

	if item_throw_controller == null:

		for child in battle_scene.get_children():

			if child is CafeteriaItemThrowController:

				item_throw_controller = (
					child as CafeteriaItemThrowController
				)
				break

	main_character = (
		get_tree().get_first_node_in_group(
			"player"
		)
	)

	if main_character == null:

		main_character = (
			battle_scene.get_node_or_null(
				"main_character"
			)
		)

	if nutrition_system == null:
		push_error(
			"[NutritionFoodBridge] NutritionSystem missing."
		)
		return

	if throw_charge_system == null:
		push_error(
			"[NutritionFoodBridge] ThrowChargeSystem missing."
		)
		return

	if main_character == null:
		push_error(
			"[NutritionFoodBridge] Main character missing."
		)
		return

	if not main_character.has_signal("food_consumed"):
		push_error(
			"[NutritionFoodBridge] Player missing "
			+ "food_consumed signal."
		)
		return

	var callback: Callable = Callable(
		self,
		"_on_food_consumed"
	)

	if not main_character.is_connected(
		"food_consumed",
		callback
	):

		main_character.connect(
			"food_consumed",
			callback
		)

	bridge_ready = true

	if print_debug_messages:

		print(
			"[NutritionFoodBridge] Nutrition "
			+ "and Throw Charge connected."
		)

		if is_instance_valid(item_throw_controller):

			print(
				"[NutritionFoodBridge] "
				+ "Temporary player buffs connected."
			)

		else:

			push_warning(
				"[NutritionFoodBridge] Throw controller "
				+ "not found. Player buffs unavailable."
			)


# ==================================================
# COMPATIBILITY WITH LEVEL 1 CONTROLLER
# ==================================================
#
# CafeteriaLevel1Controller calls:
#
# nutrition_food_bridge.is_bridge_ready()
#
# This function must remain available.
# ==================================================

func is_bridge_ready() -> bool:

	return (
		bridge_ready
		and is_instance_valid(nutrition_system)
		and is_instance_valid(throw_charge_system)
		and is_instance_valid(main_character)
	)


# ==================================================
# FOOD CONSUMPTION
# ==================================================

func _on_food_consumed(
	food: FoodData
) -> void:

	if not is_bridge_ready():
		return

	if not is_instance_valid(food):
		return

	if not nutrition_system.battle_active:
		return

	if nutrition_system.is_game_over:
		return

	if not food.has_level1_nutrition_category():
		return

	var food_name: String = food.food_name

	if food_name.strip_edges().is_empty():
		food_name = food.name

	var stats_list: Array[Dictionary] = (
		_get_food_statistics(food)
	)

	if stats_list.is_empty():
		return

	# Apply only boosts already active
	# BEFORE this food is consumed.

	var charge_multiplier: float = 1.0

	if (
		enable_player_food_buffs
		and is_instance_valid(item_throw_controller)
	):

		charge_multiplier = maxf(
			1.0,
			item_throw_controller.get_charge_gain_multiplier()
		)

	for stats in stats_list:

		_process_food_category(
			food_name,
			stats,
			charge_multiplier
		)

	# Activate the new food boost AFTER charge gain.

	if enable_player_food_buffs:

		_activate_food_player_buff(
			food,
			food_name
		)


# ==================================================
# READ ORDINARY / COMBINED FOOD STATISTICS
# ==================================================

func _get_food_statistics(
	food: FoodData
) -> Array[Dictionary]:

	var result: Array[Dictionary] = []

	if food.has_meta(LEVEL1_STATS_META):

		var stored: Variant = (
			food.get_meta(
				LEVEL1_STATS_META
			)
		)

		if stored is Array:

			for entry in stored:

				if entry is Dictionary:

					result.append(
						entry.duplicate(true)
					)

			if print_debug_messages:

				print(
					"[NutritionFoodBridge] "
					+ "Using combined food statistics: ",
					food.food_name,
					" ×",
					food.original_food_count
				)

			return result

	return food.get_all_level1_stats()


# ==================================================
# PROCESS NUTRITION AND THROW CHARGE
# ==================================================

func _process_food_category(
	food_name: String,
	stats: Dictionary,
	charge_multiplier: float
) -> void:

	var category: int = int(
		stats.get(
			"category",
			-1
		)
	)

	if not throw_charge_system.is_valid_category(
		category
	):
		return

	var nutrition_amount: int = maxi(
		0,
		int(
			stats.get(
				"nutrition_restore",
				0
			)
		)
	)

	var base_charge_gain: int = maxi(
		0,
		int(
			stats.get(
				"charge_gain",
				0
			)
		)
	)

	var throw_damage: int = maxi(
		0,
		int(
			stats.get(
				"throw_damage",
				0
			)
		)
	)

	# Projectile effects are separate from
	# the temporary player boosts.

	var projectile_buff_id: String = str(
		stats.get(
			"buff_id",
			""
		)
	)

	var projectile_buff_duration: float = float(
		stats.get(
			"buff_duration",
			0.0
		)
	)

	var projectile_buff_strength: float = float(
		stats.get(
			"buff_strength",
			0.0
		)
	)

	# ----------------------------------------------
	# NUTRITION RESTORATION
	# ----------------------------------------------

	var actual_nutrition_gain: int = 0

	if enable_nutrition_restoration:

		var nutrition_before: int = int(
			nutrition_system.get_nutrition(
				category
			)
		)

		nutrition_system.eat_food(
			category,
			nutrition_amount
		)

		var nutrition_after: int = int(
			nutrition_system.get_nutrition(
				category
			)
		)

		actual_nutrition_gain = maxi(
			0,
			nutrition_after - nutrition_before
		)

	# ----------------------------------------------
	# CHARGE BOOST
	# ----------------------------------------------

	var boosted_charge_gain: int = maxi(
		0,
		roundi(
			float(base_charge_gain)
			* charge_multiplier
		)
	)

	var actual_charge_gain: int = 0

	if enable_throw_charge:

		var charge_before: int = (
			throw_charge_system.get_charge(
				category
			)
		)

		throw_charge_system.add_food_charge(
			category,
			boosted_charge_gain,
			throw_damage,
			projectile_buff_id,
			projectile_buff_duration,
			food_name,
			projectile_buff_strength
		)

		var charge_after: int = (
			throw_charge_system.get_charge(
				category
			)
		)

		actual_charge_gain = maxi(
			0,
			charge_after - charge_before
		)

	if print_debug_messages:

		print(
			"[NutritionFoodBridge] ",
			food_name,
			" | ",
			_get_category_name(category),
			" | Nutrition +",
			actual_nutrition_gain,
			" | Charge +",
			actual_charge_gain,
			" | Throw Damage: ",
			throw_damage,
			" | Buff: ",
			projectile_buff_id,
			" | Strength: ",
			projectile_buff_strength
		)

		if (
			charge_multiplier > 1.0
			and enable_throw_charge
		):

			print(
				"[NutritionFoodBridge] Charge Boost: ",
				base_charge_gain,
				" -> ",
				boosted_charge_gain,
				" (before meter cap)"
			)

	food_processed.emit(
		food_name,
		category,
		actual_nutrition_gain,
		actual_charge_gain
	)


# ==================================================
# ACTIVATE TEMPORARY PLAYER BUFF
# ==================================================

func _activate_food_player_buff(
	food: FoodData,
	food_name: String
) -> void:

	if not is_instance_valid(item_throw_controller):
		return

	var settings: Dictionary = (
		_get_player_buff_settings(
			food,
			food_name
		)
	)

	if settings.is_empty():
		return

	var buff_id: String = str(
		settings.get(
			"id",
			""
		)
	).strip_edges().to_lower()

	var duration: float = maxf(
		0.0,
		float(
			settings.get(
				"duration",
				0.0
			)
		)
	)

	var strength: float = maxf(
		0.0,
		float(
			settings.get(
				"strength",
				0.0
			)
		)
	)

	if buff_id.is_empty():
		return

	if duration <= 0.0 or strength <= 0.0:
		return

	item_throw_controller.apply_food_buff(
		buff_id,
		duration,
		strength
	)

	if print_debug_messages:

		print(
			"[NutritionFoodBridge] ",
			food_name,
			" activated ",
			buff_id,
			" | ",
			strength,
			"% | ",
			duration,
			"s"
		)


# ==================================================
# GET PLAYER BUFF SETTINGS
# ==================================================

func _get_player_buff_settings(
	food: FoodData,
	food_name: String
) -> Dictionary:

	# Explicit food metadata takes priority.

	if food.has_meta("player_buff_id"):

		return {
			"id": str(
				food.get_meta(
					"player_buff_id",
					""
				)
			),
			"duration": float(
				food.get_meta(
					"player_buff_duration",
					0.0
				)
			),
			"strength": float(
				food.get_meta(
					"player_buff_strength",
					0.0
				)
			)
		}

	if not enable_food_name_presets:
		return {}

	var normalized_name: String = (
		food_name.strip_edges().to_lower()
	)

	if _food_name_in_list(
		normalized_name,
		damage_boost_food_names
	):

		return {
			"id": BUFF_DAMAGE,
			"duration": damage_boost_duration,
			"strength": damage_boost_percent
		}

	if _food_name_in_list(
		normalized_name,
		cooldown_boost_food_names
	):

		return {
			"id": BUFF_COOLDOWN,
			"duration": cooldown_reduction_duration,
			"strength": cooldown_reduction_percent
		}

	if _food_name_in_list(
		normalized_name,
		charge_boost_food_names
	):

		return {
			"id": BUFF_CHARGE,
			"duration": charge_boost_duration,
			"strength": charge_boost_percent
		}

	return {}


# ==================================================
# FOOD NAME MATCHING
# ==================================================

func _food_name_in_list(
	food_name: String,
	food_names: PackedStringArray
) -> bool:

	for entry in food_names:

		if (
			entry.strip_edges().to_lower()
			== food_name
		):
			return true

	return false


# ==================================================
# CATEGORY NAME
# ==================================================

func _get_category_name(
	category: int
) -> String:

	match category:

		0:
			return "GO"

		1:
			return "GLOW"

		2:
			return "GROW"

	return "UNKNOWN"
