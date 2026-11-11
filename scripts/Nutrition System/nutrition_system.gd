extends Node
class_name NutritionSystem

# ==================================================
# CAFETERIA LEVEL 1 - NUTRITION SYSTEM
# GODOT 4.7.1
# ==================================================
#
# Preserves all original signals and public methods.
#
# Adds optional Inspector overrides for:
# - GO, GLOW and GROW maximum nutrition
# - Starting nutrition
# - Natural depletion
# - Deficiency thresholds
# - Critical thresholds
#
# Existing shared settings remain the defaults.
# Existing gameplay is unchanged when overrides
# are disabled.
# ==================================================


# ==================================================
# SIGNALS
# ==================================================

signal nutrition_changed(
	food_type: int,
	current_value: int,
	previous_value: int
)

signal deficiency_changed(
	food_type: int,
	is_deficient: bool
)

signal special_started(food_type: int, duration: float)
signal special_ended(food_type: int)

signal status_started(food_type: int, duration: float)
signal status_ended(food_type: int)

signal nutrition_depleted(food_type: int)
signal game_over(food_type: int)


# ==================================================
# FOOD TYPES
# ==================================================

enum FoodType {
	GO,
	GLOW,
	GROW
}


# ==================================================
# ORIGINAL SHARED NUTRITION SETTINGS
# ==================================================

@export_group("Nutrition Settings")

@export_range(1, 1000, 1)
var maximum_nutrition: int = 100

@export_range(0, 1000, 1)
var starting_nutrition: int = 100

@export_range(0, 100, 1)
var depletion_amount: int = 1

@export_range(0.1, 10.0, 0.1)
var depletion_interval: float = 1.0

@export var automatic_depletion: bool = true


# ==================================================
# OPTIONAL CATEGORY-SPECIFIC NUTRITION SETTINGS
# ==================================================

@export_group("Per-Category Nutrition Overrides")

@export var use_category_nutrition_overrides: bool = false


@export_subgroup("GO Nutrition")

@export_range(1, 1000, 1)
var go_maximum_nutrition: int = 100

@export_range(0, 1000, 1)
var go_starting_nutrition: int = 100

@export_range(0, 100, 1)
var go_depletion_amount: int = 1


@export_subgroup("GLOW Nutrition")

@export_range(1, 1000, 1)
var glow_maximum_nutrition: int = 100

@export_range(0, 1000, 1)
var glow_starting_nutrition: int = 100

@export_range(0, 100, 1)
var glow_depletion_amount: int = 1


@export_subgroup("GROW Nutrition")

@export_range(1, 1000, 1)
var grow_maximum_nutrition: int = 100

@export_range(0, 1000, 1)
var grow_starting_nutrition: int = 100

@export_range(0, 100, 1)
var grow_depletion_amount: int = 1


# ==================================================
# ORIGINAL DEFICIENCY SETTINGS
# ==================================================

@export_group("Deficiency Settings")

@export_range(1, 100, 1)
var deficiency_threshold: int = 40

@export_range(1, 100, 1)
var critical_threshold: int = 25

@export_range(0.1, 1.0, 0.05)
var grow_damage_multiplier: float = 0.60

@export_range(0.1, 1.0, 0.05)
var grow_throw_power_multiplier: float = 0.65

@export_range(0.0, 45.0, 1.0)
var glow_accuracy_penalty: float = 12.0

@export_range(0.1, 1.0, 0.05)
var go_movement_multiplier: float = 0.75

@export_range(1.0, 3.0, 0.1)
var go_cooldown_multiplier: float = 1.30


# ==================================================
# OPTIONAL CATEGORY-SPECIFIC THRESHOLDS
# ==================================================

@export_group("Per-Category Threshold Overrides")

@export var use_category_threshold_overrides: bool = false


@export_subgroup("GO Thresholds")

@export_range(0, 1000, 1)
var go_deficiency_threshold: int = 40

@export_range(0, 1000, 1)
var go_critical_threshold: int = 25


@export_subgroup("GLOW Thresholds")

@export_range(0, 1000, 1)
var glow_deficiency_threshold: int = 40

@export_range(0, 1000, 1)
var glow_critical_threshold: int = 25


@export_subgroup("GROW Thresholds")

@export_range(0, 1000, 1)
var grow_deficiency_threshold: int = 40

@export_range(0, 1000, 1)
var grow_critical_threshold: int = 25


# ==================================================
# SPECIAL EFFECT SETTINGS
# ==================================================

@export_group("Special Effects")

@export var enable_special_effects: bool = true

@export_range(1.0, 60.0, 0.5)
var special_duration: float = 8.0

@export_range(0, 100, 1)
var special_rearm_threshold: int = 70

@export_range(1.0, 3.0, 0.05)
var go_special_speed_multiplier: float = 1.25

@export_range(0.1, 1.0, 0.05)
var go_special_cooldown_multiplier: float = 0.50

@export_range(1.0, 5.0, 0.1)
var grow_special_damage_multiplier: float = 2.0

@export_range(1.0, 5.0, 0.1)
var grow_special_knockback_multiplier: float = 2.0


# ==================================================
# ENEMY STATUS EFFECT SETTINGS
# ==================================================

@export_group("Enemy Status Effects")

@export_range(0.1, 10.0, 0.1)
var grow_stun_duration: float = 1.5

@export_range(0.1, 20.0, 0.1)
var glow_blur_duration: float = 4.0

@export_range(0.1, 20.0, 0.1)
var go_fatigue_duration: float = 4.0

@export_range(0.0, 30.0, 1.0)
var glow_critical_accuracy_penalty: float = 8.0

@export_range(0.1, 1.0, 0.05)
var go_fatigue_speed_multiplier: float = 0.80

@export_range(1.0, 3.0, 0.1)
var go_fatigue_cooldown_multiplier: float = 1.40


# ==================================================
# INTERNAL DATA
# ==================================================

var nutrition: Dictionary = {}

var special_remaining: Dictionary = {}
var special_armed: Dictionary = {}

var status_remaining: Dictionary = {}

var battle_active: bool = false
var is_game_over: bool = false

var depletion_timer: Timer


# ==================================================
# CATEGORY CONFIGURATION HELPERS
# ==================================================

func get_maximum_nutrition(food_type: int) -> int:

	if not use_category_nutrition_overrides:
		return maxi(1, maximum_nutrition)

	match food_type:
		FoodType.GO:
			return maxi(1, go_maximum_nutrition)

		FoodType.GLOW:
			return maxi(1, glow_maximum_nutrition)

		FoodType.GROW:
			return maxi(1, grow_maximum_nutrition)

	return maxi(1, maximum_nutrition)


func get_starting_nutrition(food_type: int) -> int:

	if not use_category_nutrition_overrides:
		return clampi(
			starting_nutrition,
			0,
			get_maximum_nutrition(food_type)
		)

	var configured_value: int = starting_nutrition

	match food_type:
		FoodType.GO:
			configured_value = go_starting_nutrition

		FoodType.GLOW:
			configured_value = glow_starting_nutrition

		FoodType.GROW:
			configured_value = grow_starting_nutrition

	return clampi(
		configured_value,
		0,
		get_maximum_nutrition(food_type)
	)


func get_depletion_amount(food_type: int) -> int:

	if not use_category_nutrition_overrides:
		return maxi(0, depletion_amount)

	match food_type:
		FoodType.GO:
			return maxi(0, go_depletion_amount)

		FoodType.GLOW:
			return maxi(0, glow_depletion_amount)

		FoodType.GROW:
			return maxi(0, grow_depletion_amount)

	return maxi(0, depletion_amount)


func get_deficiency_threshold(food_type: int) -> int:

	if not use_category_threshold_overrides:
		return deficiency_threshold

	match food_type:
		FoodType.GO:
			return go_deficiency_threshold

		FoodType.GLOW:
			return glow_deficiency_threshold

		FoodType.GROW:
			return grow_deficiency_threshold

	return deficiency_threshold


func get_critical_threshold(food_type: int) -> int:

	if not use_category_threshold_overrides:
		return critical_threshold

	match food_type:
		FoodType.GO:
			return go_critical_threshold

		FoodType.GLOW:
			return glow_critical_threshold

		FoodType.GROW:
			return grow_critical_threshold

	return critical_threshold


# ==================================================
# INITIALIZATION
# ==================================================

func _ready() -> void:
	_initialize_data()
	_create_depletion_timer()


func _initialize_data() -> void:

	nutrition.clear()
	special_remaining.clear()
	special_armed.clear()
	status_remaining.clear()

	for food_type in FoodType.values():

		nutrition[food_type] = (
			get_starting_nutrition(food_type)
		)

		special_remaining[food_type] = 0.0
		special_armed[food_type] = true
		status_remaining[food_type] = 0.0


func _create_depletion_timer() -> void:

	depletion_timer = Timer.new()
	depletion_timer.name = "DepletionTimer"
	depletion_timer.one_shot = false
	depletion_timer.wait_time = maxf(
		0.1,
		depletion_interval
	)

	add_child(depletion_timer)

	depletion_timer.timeout.connect(
		_on_depletion_timer_timeout
	)


# ==================================================
# BATTLE CONTROL
# ==================================================

func start_battle() -> void:

	if battle_active:
		return

	_initialize_data()

	battle_active = true
	is_game_over = false

	for food_type in FoodType.values():

		nutrition_changed.emit(
			food_type,
			nutrition[food_type],
			nutrition[food_type]
		)

	for food_type in FoodType.values():
		if get_nutrition(food_type) == 0:
			_check_starting_depletion.call_deferred()
			return

	if automatic_depletion:

		depletion_timer.wait_time = maxf(
			0.1,
			depletion_interval
		)

		depletion_timer.start()


func _check_starting_depletion() -> void:
	if not battle_active:
		return
	for food_type in FoodType.values():
		if get_nutrition(food_type) == 0:
			_trigger_game_over(food_type)
			return


func stop_battle() -> void:

	battle_active = false

	if is_instance_valid(depletion_timer):
		depletion_timer.stop()


func _process(delta: float) -> void:

	if not battle_active or is_game_over:
		return

	_update_special_effects(delta)
	_update_status_effects(delta)


# ==================================================
# NATURAL DEPLETION
# ==================================================

func _on_depletion_timer_timeout() -> void:

	if not battle_active or is_game_over:
		return

	# Preserve original GLOW special behavior:
	# Natural depletion pauses for all categories.

	if is_special_active(FoodType.GLOW):
		return

	for food_type in FoodType.values():

		if is_game_over:
			return

		var amount: int = get_depletion_amount(
			food_type
		)

		if amount <= 0:
			continue

		_change_nutrition(
			food_type,
			-amount
		)


# ==================================================
# NUTRITION MANAGEMENT
# ==================================================

func get_nutrition(food_type: int) -> int:

	return int(
		nutrition.get(food_type, 0)
	)


func get_nutrition_percentage(food_type: int) -> float:

	var maximum: int = get_maximum_nutrition(
		food_type
	)

	return float(
		get_nutrition(food_type)
	) / float(maximum)


func is_deficient(food_type: int) -> bool:

	return (
		get_nutrition(food_type)
		<= get_deficiency_threshold(food_type)
	)


func _change_nutrition(
	food_type: int,
	amount: int
) -> void:

	if not battle_active or is_game_over:
		return

	if not nutrition.has(food_type):

		push_warning(
			"[NutritionSystem] Invalid food type."
		)

		return

	var previous_value: int = (
		get_nutrition(food_type)
	)

	var new_value: int = clampi(
		previous_value + amount,
		0,
		get_maximum_nutrition(food_type)
	)

	if previous_value == new_value:
		return

	var was_deficient: bool = (
		previous_value
		<= get_deficiency_threshold(food_type)
	)

	nutrition[food_type] = new_value

	nutrition_changed.emit(
		food_type,
		new_value,
		previous_value
	)

	var now_deficient: bool = (
		new_value
		<= get_deficiency_threshold(food_type)
	)

	if was_deficient != now_deficient:

		deficiency_changed.emit(
			food_type,
			now_deficient
		)

	if (
		not special_armed[food_type]
		and new_value <= special_rearm_threshold
	):

		special_armed[food_type] = true

	# Recovering above the deficiency threshold
	# removes the related enemy status.

	if new_value > get_deficiency_threshold(food_type):

		_end_status_effect(food_type)

	if new_value <= 0:

		_trigger_game_over(food_type)


# ==================================================
# FOOD CONSUMPTION
# ==================================================

func eat_food(
	food_type: int,
	restoration_amount: int
) -> void:

	if not battle_active or is_game_over:
		return

	if restoration_amount <= 0:
		return

	if not nutrition.has(food_type):
		return

	var previous_value: int = get_nutrition(
		food_type
	)

	_change_nutrition(
		food_type,
		restoration_amount
	)

	var current_value: int = get_nutrition(
		food_type
	)

	if (
		enable_special_effects
		and previous_value < get_maximum_nutrition(food_type)
		and current_value == get_maximum_nutrition(food_type)
		and special_armed[food_type]
		and not is_game_over
	):

		_activate_special(food_type)


# ==================================================
# ENEMY DAMAGE
# ==================================================

func apply_enemy_hit(
	food_type: int,
	damage: int
) -> void:

	if not battle_active or is_game_over:
		return

	if damage <= 0:
		return

	if not nutrition.has(food_type):
		return

	var previous_value: int = get_nutrition(
		food_type
	)

	_change_nutrition(
		food_type,
		-damage
	)

	if is_game_over:
		return

	var current_value: int = get_nutrition(
		food_type
	)

	if (
		previous_value > get_critical_threshold(food_type)
		and current_value <= get_critical_threshold(food_type)
	):

		_activate_status_effect(food_type)


# ==================================================
# SPECIAL EFFECTS
# ==================================================

func _activate_special(food_type: int) -> void:

	special_remaining[food_type] = special_duration
	special_armed[food_type] = false

	special_started.emit(
		food_type,
		special_duration
	)


func is_special_active(food_type: int) -> bool:

	return float(
		special_remaining.get(food_type, 0.0)
	) > 0.0


func _update_special_effects(delta: float) -> void:

	for food_type in FoodType.values():

		if not is_special_active(food_type):
			continue

		special_remaining[food_type] = maxf(
			0.0,
			float(special_remaining[food_type]) - delta
		)

		if not is_special_active(food_type):

			special_ended.emit(food_type)


# ==================================================
# ENEMY-INDUCED STATUS EFFECTS
# ==================================================

func _activate_status_effect(food_type: int) -> void:

	var duration: float = 0.0

	match food_type:

		FoodType.GO:
			duration = go_fatigue_duration

		FoodType.GLOW:
			duration = glow_blur_duration

		FoodType.GROW:
			duration = grow_stun_duration

	if duration <= 0.0:
		return

	status_remaining[food_type] = duration

	status_started.emit(
		food_type,
		duration
	)


func is_status_active(food_type: int) -> bool:

	return float(
		status_remaining.get(food_type, 0.0)
	) > 0.0


func _end_status_effect(food_type: int) -> void:

	if not is_status_active(food_type):
		return

	status_remaining[food_type] = 0.0

	status_ended.emit(food_type)


func _update_status_effects(delta: float) -> void:

	for food_type in FoodType.values():

		if not is_status_active(food_type):
			continue

		status_remaining[food_type] = maxf(
			0.0,
			float(status_remaining[food_type]) - delta
		)

		if not is_status_active(food_type):

			status_ended.emit(food_type)


# ==================================================
# THROWING MODIFIERS
# ==================================================

func get_throw_damage_multiplier() -> float:

	var multiplier: float = 1.0

	if is_deficient(FoodType.GROW):
		multiplier *= grow_damage_multiplier

	if is_special_active(FoodType.GROW):
		multiplier *= grow_special_damage_multiplier

	return multiplier


func get_throw_power_multiplier() -> float:

	if is_deficient(FoodType.GROW):
		return grow_throw_power_multiplier

	return 1.0


func get_accuracy_deviation() -> float:

	var deviation: float = 0.0

	if is_deficient(FoodType.GLOW):
		deviation += glow_accuracy_penalty

	if is_status_active(FoodType.GLOW):
		deviation += glow_critical_accuracy_penalty

	return deviation


func get_throw_cooldown_multiplier() -> float:

	var multiplier: float = 1.0

	if is_deficient(FoodType.GO):
		multiplier *= go_cooldown_multiplier

	if is_status_active(FoodType.GO):
		multiplier *= go_fatigue_cooldown_multiplier

	if is_special_active(FoodType.GO):
		multiplier *= go_special_cooldown_multiplier

	return multiplier


func get_movement_speed_multiplier() -> float:

	var multiplier: float = 1.0

	if is_deficient(FoodType.GO):
		multiplier *= go_movement_multiplier

	if is_status_active(FoodType.GO):
		multiplier *= go_fatigue_speed_multiplier

	if is_special_active(FoodType.GO):
		multiplier *= go_special_speed_multiplier

	return multiplier


func get_knockback_multiplier() -> float:

	if is_special_active(FoodType.GROW):
		return grow_special_knockback_multiplier

	return 1.0


func can_player_move() -> bool:

	if not battle_active or is_game_over:
		return false

	return not is_status_active(FoodType.GROW)


func can_player_throw() -> bool:

	if not battle_active or is_game_over:
		return false

	return not is_status_active(FoodType.GROW)


# ==================================================
# GAME OVER
# ==================================================

func _trigger_game_over(food_type: int) -> void:

	if is_game_over:
		return

	is_game_over = true
	battle_active = false

	if is_instance_valid(depletion_timer):
		depletion_timer.stop()

	nutrition_depleted.emit(food_type)
	game_over.emit(food_type)
