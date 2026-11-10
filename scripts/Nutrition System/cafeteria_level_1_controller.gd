
extends Node
class_name CafeteriaLevel1Controller

# ==================================================
# CAFETERIA LEVEL 1 CONTROLLER
# GODOT 4.7.1
# ==================================================
#
# Preserves:
# - Nutrition battle initialization
# - NutritionFoodBridge readiness check
# - Throw Charge initialization
# - Manual throwing
# - Original hearts visibility
# - Victory detection
# - Game Over detection
# - Existing controller signals
#
# Adds:
# - Explicit food spawning shutdown
# - Explicit enemy spawning shutdown
# - Duplicate signal connection protection
# - Safe battle initialization checks
# ==================================================


# ==================================================
# SIGNALS
# ==================================================

signal level_systems_started
signal level_systems_stopped
signal nutrition_failure(category: int)


# ==================================================
# LEVEL SETTINGS
# ==================================================

@export_group("Level 1 Settings")

@export var automatically_start_battle: bool = true
@export var reset_throw_charge_on_start: bool = true
@export var hide_original_hearts: bool = true


# ==================================================
# DEBUGGING
# ==================================================

@export_group("Debugging")

@export var print_debug_messages: bool = true


# ==================================================
# LEVEL STATE
# ==================================================

var systems_ready: bool = false
var battle_started: bool = false
var battle_finished: bool = false


# ==================================================
# SYSTEM REFERENCES
# ==================================================

var nutrition_system: NutritionSystem = null

var throw_charge_system: ThrowChargeSystem = null

var throw_controller: CafeteriaItemThrowController = null

var food_spawn: Node = null
var enemy_spawn: Node = null


# ==================================================
# READY
# ==================================================

func _ready() -> void:

	_initialize_level.call_deferred()


# ==================================================
# INITIALIZE LEVEL
# ==================================================

func _initialize_level() -> void:

	var battle_scene: Node = get_parent()

	if battle_scene == null:
		push_error(
			"[Level1] Battle scene missing."
		)
		return

	var player: Node = (
		battle_scene.get_node_or_null(
			"main_character"
		)
	)

	var nutrition_ui: CanvasLayer = (
		battle_scene.get_node_or_null(
			"NutritionUI"
		) as CanvasLayer
	)

	var food_bridge: NutritionFoodBridge = (
		battle_scene.get_node_or_null(
			"NutritionFoodBridge"
		) as NutritionFoodBridge
	)

	food_spawn = (
		battle_scene.get_node_or_null(
			"FoodSpawn"
		)
	)

	enemy_spawn = (
		battle_scene.get_node_or_null(
			"EnemySpawn"
		)
	)

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

	throw_controller = (
		battle_scene.get_node_or_null(
			"ItemThrowController"
		) as CafeteriaItemThrowController
	)

	# ----------------------------------------------
	# VALIDATE PLAYER
	# ----------------------------------------------

	if (
		player == null
		or player.get(
			"cafeteria_nutrition_mode"
		) != true
	):

		push_error(
			"[Level1] The Cafeteria player "
			+ "must have nutrition mode enabled."
		)

		return

	# ----------------------------------------------
	# VALIDATE NUTRITION SYSTEMS
	# ----------------------------------------------

	if (
		nutrition_system == null
		or throw_charge_system == null
		or nutrition_ui == null
	):

		push_error(
			"[Level1] NutritionSystem, "
			+ "ThrowChargeSystem or NutritionUI missing."
		)

		return

	# ----------------------------------------------
	# VALIDATE FOOD BRIDGE AND THROWING
	# ----------------------------------------------

	if (
		food_bridge == null
		or not food_bridge.is_bridge_ready()
		or throw_controller == null
		or not throw_controller.controller_ready
	):

		push_error(
			"[Level1] Food bridge or throw "
			+ "controller could not initialize."
		)

		return

	# ----------------------------------------------
	# VALIDATE ENEMY SPAWNER
	# ----------------------------------------------

	if (
		enemy_spawn == null
		or not enemy_spawn.has_signal(
			"level_completed"
		)
	):

		push_error(
			"[Level1] EnemySpawn is missing "
			+ "its level_completed signal."
		)

		return

	# ----------------------------------------------
	# VALIDATE FOOD SPAWNER
	# ----------------------------------------------

	if food_spawn == null:

		push_warning(
			"[Level1] FoodSpawn node missing. "
			+ "Automatic food spawning cannot "
			+ "be controlled."
		)

	elif not food_spawn.has_method(
		"stop_spawning"
	):

		push_warning(
			"[Level1] FoodSpawn does not "
			+ "support stop_spawning()."
		)

	# ----------------------------------------------
	# CONNECT GAME OVER SIGNAL
	# ----------------------------------------------

	if not nutrition_system.game_over.is_connected(
		_on_nutrition_game_over
	):

		nutrition_system.game_over.connect(
			_on_nutrition_game_over
		)

	# ----------------------------------------------
	# CONNECT LEVEL COMPLETION SIGNAL
	# ----------------------------------------------

	var completion_callback: Callable = Callable(
		self,
		"complete_level_systems"
	)

	if not enemy_spawn.is_connected(
		"level_completed",
		completion_callback
	):

		enemy_spawn.connect(
			"level_completed",
			completion_callback
		)

	# ----------------------------------------------
	# DISABLE THROWING UNTIL BATTLE START
	# ----------------------------------------------

	throw_charge_system.set_system_enabled(
		false
	)

	throw_controller.allow_throwing = false

	# ----------------------------------------------
	# HIDE ORIGINAL HEARTS
	# ----------------------------------------------

	if hide_original_hearts:

		var hearts: CanvasLayer = (
			player.get_node_or_null(
				"HealthDisplay"
			) as CanvasLayer
		)

		if hearts != null:
			hearts.hide()

	nutrition_ui.show()

	systems_ready = true

	if print_debug_messages:

		print(
			"[Level1] Nutrition and manual "
			+ "throwing systems connected."
		)

	# ----------------------------------------------
	# START LEVEL
	# ----------------------------------------------

	if automatically_start_battle:

		start_level_systems()


# ==================================================
# START BATTLE SYSTEMS
# ==================================================

func start_level_systems() -> void:

	if not systems_ready:
		return

	if battle_started or battle_finished:
		return

	battle_started = true

	# ----------------------------------------------
	# RESET THROW CHARGE
	# ----------------------------------------------

	if reset_throw_charge_on_start:

		throw_charge_system.reset_all_charges()

	# ----------------------------------------------
	# ENABLE THROWING
	# ----------------------------------------------

	throw_charge_system.set_system_enabled(
		true
	)

	throw_controller.cooldown_remaining = 0.0
	throw_controller.allow_throwing = true

	# ----------------------------------------------
	# START NUTRITION SYSTEM
	# ----------------------------------------------

	nutrition_system.start_battle()

	# ----------------------------------------------
	# START FOOD SPAWNER IF NEEDED
	# ----------------------------------------------

	if (
		is_instance_valid(food_spawn)
		and food_spawn.has_method(
			"start_spawning"
		)
	):

		food_spawn.call(
			"start_spawning"
		)

	if print_debug_messages:

		print(
			"[Level1] Battle systems started."
		)

	level_systems_started.emit()


# ==================================================
# VICTORY
# ==================================================

func complete_level_systems() -> void:

	if battle_finished:
		return

	if print_debug_messages:

		print(
			"[Level1] Victory detected."
		)

	_finish_systems()


# ==================================================
# NUTRITION GAME OVER
# ==================================================

func _on_nutrition_game_over(
	category: int
) -> void:

	if battle_finished:
		return

	if print_debug_messages:

		var category_name: String = (
			str(category)
		)

		if is_instance_valid(
			throw_charge_system
		):

			category_name = (
				throw_charge_system.get_category_name(
					category
				)
			)

		print(
			"[Level1] Game Over. Depleted: ",
			category_name
		)

	_finish_systems()

	nutrition_failure.emit(
		category
	)


# ==================================================
# FINISH BATTLE SYSTEMS
# ==================================================

func _finish_systems() -> void:

	if battle_finished:
		return

	battle_finished = true
	battle_started = false

	# ----------------------------------------------
	# STOP THROWING
	# ----------------------------------------------

	if is_instance_valid(throw_controller):

		throw_controller.allow_throwing = false

		throw_controller._cancel_aim()

	# ----------------------------------------------
	# DISABLE CHARGE SYSTEM
	# ----------------------------------------------

	if is_instance_valid(
		throw_charge_system
	):

		throw_charge_system.set_system_enabled(
			false
		)

	# ----------------------------------------------
	# STOP NUTRITION SYSTEM
	# ----------------------------------------------

	if is_instance_valid(nutrition_system):

		nutrition_system.stop_battle()

	# ----------------------------------------------
	# STOP FOOD SPAWNING
	# ----------------------------------------------

	if is_instance_valid(food_spawn):

		if food_spawn.has_method(
			"stop_spawning"
		):

			food_spawn.call(
				"stop_spawning"
			)

	# ----------------------------------------------
	# STOP ENEMY SPAWNING
	# ----------------------------------------------

	if is_instance_valid(enemy_spawn):

		enemy_spawn.set_process(
			false
		)

	# ----------------------------------------------
	# NOTIFY OTHER LEVEL SYSTEMS
	# ----------------------------------------------

	level_systems_stopped.emit()
