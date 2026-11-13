extends Node
class_name ThrowChargeSystem

# ==================================================
# CAFETERIA LEVEL 1
# INSPECTOR-CONFIGURABLE THROW CHARGE SYSTEM
# GODOT 4.7.1
# ==================================================
#
# PRESERVES:
# - Independent GO, GLOW and GROW charge meters
# - Food-based charge gain
# - Prepared projectile attack data
# - Projectile damage and effects
# - Charge consumption
# - Existing public methods and signals
# - Compatibility with existing Level 1 systems
#
# ADDS:
# - Configurable starting charge per category
# - Optional configurable charge requirement
# - Adjustable maximum capacity
# - Default attack preparation when starting ready
#
# NOT INCLUDED:
# - Automatic charge regeneration (To-Do #5)
# ==================================================


# ==================================================
# CATEGORIES
# ==================================================

enum ThrowCategory {
	GO,
	GLOW,
	GROW
}


# ==================================================
# SIGNALS
# ==================================================

signal charge_changed(
	category: int,
	current_value: int,
	previous_value: int
)

signal throw_ready(category: int)

signal throw_consumed(
	category: int,
	attack_data: Dictionary
)

signal charge_reset


# ==================================================
# THROW CHARGE SETTINGS
# ==================================================

@export_group("Throw Charge Settings")

@export_range(1, 1000, 1)
var maximum_charge: int = 100

@export_range(1, 1000, 1)
var default_charge_gain: int = 25

@export var use_custom_throw_requirement: bool = false

@export_range(1, 1000, 1)
var charge_required_to_throw: int = 100


# ==================================================
# STARTING CHARGE SETTINGS
# ==================================================

@export_group("Starting Charge")

@export_range(0, 1000, 1)
var starting_go_charge: int = 0

@export_range(0, 1000, 1)
var starting_glow_charge: int = 0

@export_range(0, 1000, 1)
var starting_grow_charge: int = 0


# ==================================================
# TEMPORARY ATTACK DEFAULTS
# ==================================================

@export_group("Temporary Attack Defaults")

@export_range(0, 999, 1)
var default_throw_damage: int = 10

@export var default_buff_id: String = ""

@export_range(0.0, 60.0, 0.1)
var default_buff_duration: float = 0.0

@export_range(0.0, 999.0, 0.1)
var default_buff_strength: float = 0.0


# ==================================================
# DEBUGGING
# ==================================================

@export_group("Debugging")

@export var print_debug_messages: bool = true


# ==================================================
# INTERNAL DATA
# ==================================================

var charges: Dictionary = {}

var prepared_attacks: Dictionary = {}

var system_enabled: bool = true


# ==================================================
# INITIALIZATION
# ==================================================

func _ready() -> void:
	reset_all_charges()


# ==================================================
# GET MAXIMUM CHARGE
# ==================================================

func get_maximum_charge() -> int:

	return maxi(
		1,
		maximum_charge
	)


# ==================================================
# GET REQUIRED CHARGE
# ==================================================

func get_required_charge() -> int:

	var charge_limit: int = get_maximum_charge()

	if not use_custom_throw_requirement:
		return charge_limit

	return clampi(
		charge_required_to_throw,
		1,
		charge_limit
	)


# ==================================================
# GET STARTING CHARGE
# ==================================================

func get_starting_charge(category: int) -> int:

	if not is_valid_category(category):
		return 0

	var configured_charge: int = 0

	match category:

		ThrowCategory.GO:
			configured_charge = starting_go_charge

		ThrowCategory.GLOW:
			configured_charge = starting_glow_charge

		ThrowCategory.GROW:
			configured_charge = starting_grow_charge

	return clampi(
		configured_charge,
		0,
		get_required_charge()
	)


# ==================================================
# CREATE DEFAULT ATTACK DATA
# ==================================================

func _create_default_attack(
	category: int
) -> Dictionary:

	return {
		"category": category,
		"category_name": get_category_name(
			category
		),
		"damage": maxi(
			0,
			default_throw_damage
		),
		"buff_id": default_buff_id,
		"buff_duration": maxf(
			0.0,
			default_buff_duration
		),
		"buff_strength": maxf(
			0.0,
			default_buff_strength
		),
		"source_food_name": ""
	}


# ==================================================
# RESET ALL CHARGES
# ==================================================

func reset_all_charges() -> void:
	var previous_charges := charges.duplicate()
	charges.clear()
	prepared_attacks.clear()

	for category in ThrowCategory.values():
		var starting_value := get_starting_charge(category)
		charges[category] = starting_value
		prepared_attacks[category] = _create_default_attack(category) if starting_value >= get_required_charge() else {}

	for category in ThrowCategory.values():
		charge_changed.emit(category, get_charge(category), int(previous_charges.get(category, 0)))

	charge_reset.emit()

	if print_debug_messages:

		print(
			"[ThrowCharge] All meters reset."
		)

		for category in ThrowCategory.values():

			print(
				"[ThrowCharge] ",
				get_category_name(category),
				" starting charge: ",
				get_charge(category),
				"/",
				get_required_charge()
			)


# ==================================================
# VALIDATE CATEGORY
# ==================================================

func is_valid_category(category: int) -> bool:

	return (
		category == ThrowCategory.GO
		or category == ThrowCategory.GLOW
		or category == ThrowCategory.GROW
	)


# ==================================================
# GET CURRENT CHARGE
# ==================================================

func get_charge(category: int) -> int:

	if not is_valid_category(category):
		return 0

	return int(
		charges.get(category, 0)
	)


# ==================================================
# GET CHARGE PERCENTAGE
# ==================================================

func get_charge_percent(category: int) -> float:

	if not is_valid_category(category):
		return 0.0

	var required_charge: int = (
		get_required_charge()
	)

	return clampf(
		float(get_charge(category))
		/ float(required_charge),
		0.0,
		1.0
	)


# ==================================================
# CHECK WHETHER THROW IS READY
# ==================================================

func is_throw_ready(category: int) -> bool:

	if not system_enabled:
		return false

	if not is_valid_category(category):
		return false

	return (
		get_charge(category)
		>= get_required_charge()
	)


# ==================================================
# ADD FOOD CHARGE
# ==================================================

func add_food_charge(
	category: int,
	charge_amount: int = -1,
	throw_damage: int = -1,
	buff_id: String = "",
	buff_duration: float = -1.0,
	food_name: String = "",
	buff_strength: float = -1.0
) -> void:

	if not system_enabled:
		return

	if not is_valid_category(category):

		push_warning(
			"[ThrowCharge] Invalid food category."
		)

		return

	# ----------------------------------------------
	# RESOLVE FOOD CHARGE
	# ----------------------------------------------

	var actual_gain: int = charge_amount

	if actual_gain < 0:
		actual_gain = default_charge_gain

	actual_gain = maxi(
		0,
		actual_gain
	)

	# ----------------------------------------------
	# RESOLVE PROJECTILE DAMAGE
	# ----------------------------------------------

	var actual_damage: int = throw_damage

	if actual_damage < 0:
		actual_damage = default_throw_damage

	actual_damage = maxi(
		0,
		actual_damage
	)

	# ----------------------------------------------
	# RESOLVE PROJECTILE EFFECT
	# ----------------------------------------------

	var actual_buff_id: String = buff_id

	if actual_buff_id.is_empty():
		actual_buff_id = default_buff_id

	var actual_duration: float = buff_duration

	if actual_duration < 0.0:
		actual_duration = default_buff_duration

	actual_duration = maxf(
		0.0,
		actual_duration
	)

	var actual_strength: float = buff_strength

	if actual_strength < 0.0:
		actual_strength = default_buff_strength

	actual_strength = maxf(
		0.0,
		actual_strength
	)

	# ----------------------------------------------
	# PROTECT EXISTING PREPARED ATTACK
	# ----------------------------------------------

	if is_throw_ready(category):

		if print_debug_messages:

			print(
				"[ThrowCharge] ",
				get_category_name(category),
				" is already READY."
			)

		return

	# ----------------------------------------------
	# ADD CHARGE
	# ----------------------------------------------

	var previous_value: int = (
		get_charge(category)
	)

	var required_charge: int = (
		get_required_charge()
	)

	var new_value: int = mini(
		previous_value + actual_gain,
		required_charge
	)

	if new_value == previous_value:
		return

	charges[category] = new_value

	if new_value >= required_charge:

		prepared_attacks[category] = {
			"category": category,
			"category_name": get_category_name(
				category
			),
			"damage": actual_damage,
			"buff_id": actual_buff_id,
			"buff_duration": actual_duration,
			"buff_strength": actual_strength,
			"source_food_name": food_name
		}


	charge_changed.emit(
		category,
		new_value,
		previous_value
	)

	if print_debug_messages:

		print(
			"[ThrowCharge] ",
			get_category_name(category),
			" charge: ",
			previous_value,
			" -> ",
			new_value
		)

	# ----------------------------------------------
	# PREPARE ATTACK WHEN READY
	# ----------------------------------------------

	if new_value >= required_charge and is_throw_ready(category):
		throw_ready.emit(category)

		if print_debug_messages:

			print(
				"[ThrowCharge] ",
				get_category_name(category),
				" THROW READY! | Food: ",
				food_name,
				" | Buff: ",
				actual_buff_id,
				" | Strength: ",
				actual_strength
			)


# ==================================================
# GET PREPARED ATTACK
# ==================================================

func get_prepared_attack(category: int) -> Dictionary:

	if not is_throw_ready(category):
		return {}

	var attack_data: Dictionary = (
		prepared_attacks.get(
			category,
			{}
		)
	)

	return attack_data.duplicate(true)


# ==================================================
# CONSUME PREPARED THROW
# ==================================================

func consume_throw(category: int) -> Dictionary:

	if not is_throw_ready(category):
		return {}

	var attack_data: Dictionary = (
		get_prepared_attack(category)
	)

	if attack_data.is_empty():
		return {}

	var previous_value: int = (
		get_charge(category)
	)

	charges[category] = 0
	prepared_attacks[category] = {}

	charge_changed.emit(
		category,
		0,
		previous_value
	)

	throw_consumed.emit(
		category,
		attack_data
	)

	if print_debug_messages:

		print(
			"[ThrowCharge] ",
			get_category_name(category),
			" throw consumed. Damage: ",
			attack_data.get(
				"damage",
				0
			)
		)

	return attack_data


# ==================================================
# CHECK FOR ANY READY THROW
# ==================================================

func has_any_ready_throw() -> bool:

	for category in ThrowCategory.values():

		if is_throw_ready(category):
			return true

	return false


# ==================================================
# GET ALL READY CATEGORIES
# ==================================================

func get_ready_categories() -> Array[int]:

	var ready_categories: Array[int] = []

	for category in ThrowCategory.values():

		if is_throw_ready(category):
			ready_categories.append(category)

	return ready_categories


# ==================================================
# RESET SPECIFIC CATEGORY
# ==================================================

func reset_category(category: int) -> void:

	if not is_valid_category(category):
		return

	var previous_value: int = (
		get_charge(category)
	)

	charges[category] = 0
	prepared_attacks[category] = {}

	charge_changed.emit(
		category,
		0,
		previous_value
	)


# ==================================================
# ENABLE OR DISABLE SYSTEM
# ==================================================

func set_system_enabled(enabled: bool) -> void:

	system_enabled = enabled


# ==================================================
# GET CATEGORY NAME
# ==================================================

func get_category_name(category: int) -> String:

	match category:

		ThrowCategory.GO:
			return "GO"

		ThrowCategory.GLOW:
			return "GLOW"

		ThrowCategory.GROW:
			return "GROW"

	return "UNKNOWN"


# ==================================================
# DEBUGGING
# ==================================================

func print_charge_status() -> void:

	print(
		"========== THROW CHARGE =========="
	)

	for category in ThrowCategory.values():

		print(
			get_category_name(category),
			": ",
			get_charge(category),
			"/",
			get_required_charge(),
			" | Ready: ",
			is_throw_ready(category)
		)

	print(
		"=================================="
	)
