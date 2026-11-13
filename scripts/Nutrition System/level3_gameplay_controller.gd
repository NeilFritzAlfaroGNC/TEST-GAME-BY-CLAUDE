extends Node
class_name Level3GameplayController

signal level_systems_started
signal level_systems_stopped
signal nutrition_failure(category: int)
signal level_victory_accepted

const BRIDGE_READY_FRAME_LIMIT := 120

@export_group("Level 3 Settings")
@export var automatically_start_battle: bool = true
@export var reset_throw_charge_on_start: bool = true
@export var hide_original_hearts: bool = true

@export_group("Scene References")
@export var player_path: NodePath = ^"main_character"
@export var nutrition_ui_path: NodePath = ^"NutritionUI"
@export var nutrition_system_path: NodePath = ^"NutritionSystem"
@export var food_bridge_path: NodePath = ^"NutritionFoodBridge"
@export var throw_charge_path: NodePath = ^"ThrowChargeSystem"
@export var throw_controller_path: NodePath = ^"ItemThrowController"
@export var food_spawn_path: NodePath = ^"FoodSpawn"
@export var enemy_spawn_path: NodePath = ^"EnemySpawn"
@export var health_display_path: NodePath = ^"HealthDisplay"

@export_group("Player Compatibility")
@export var require_existing_nutrition_mode: bool = true

@export_group("Debugging")
@export var print_debug_messages: bool = true

var systems_ready: bool = false
var battle_started: bool = false
var battle_finished: bool = false

var nutrition_system: NutritionSystem
var throw_charge_system: ThrowChargeSystem
var throw_controller: CafeteriaItemThrowController
var food_spawn: Node
var enemy_spawn: Node
var _resume_enemy_spawning: bool = false
var _startup_generation: int = 0


func _ready() -> void:
	_initialize_level.call_deferred(_startup_generation)


func _exit_tree() -> void:
	_startup_generation += 1


func _initialize_level(generation: int, waited_frames: int = 0) -> void:
	if generation != _startup_generation or not is_inside_tree() or is_queued_for_deletion():
		return

	var battle := get_parent()
	if battle == null:
		push_error("[Level3] Parent battle scene missing.")
		return

	var player := battle.get_node_or_null(player_path)
	var nutrition_ui := battle.get_node_or_null(nutrition_ui_path) as CanvasLayer
	var food_bridge := battle.get_node_or_null(food_bridge_path) as NutritionFoodBridge
	nutrition_system = battle.get_node_or_null(nutrition_system_path) as NutritionSystem
	throw_charge_system = battle.get_node_or_null(throw_charge_path) as ThrowChargeSystem
	throw_controller = battle.get_node_or_null(throw_controller_path) as CafeteriaItemThrowController
	food_spawn = battle.get_node_or_null(food_spawn_path)
	enemy_spawn = battle.get_node_or_null(enemy_spawn_path)

	if player == null or (require_existing_nutrition_mode and player.get("cafeteria_nutrition_mode") != true):
		push_error("[Level3] Check Player Path and enable the player's existing nutrition mode.")
		return
	if nutrition_system == null or throw_charge_system == null or nutrition_ui == null:
		push_error("[Level3] Check the nutrition, charge, and HUD paths.")
		return
	if food_bridge == null:
		push_error("[Level3] Food bridge is missing.")
		return
	if throw_controller == null or not throw_controller.controller_ready:
		push_error("[Level3] Throw controller is missing or failed to initialize.")
		return
	if enemy_spawn == null or not enemy_spawn.has_signal("level_completed"):
		push_error("[Level3] Enemy spawner is missing its level_completed signal.")
		return

	if waited_frames == 0:
		throw_charge_system.set_system_enabled(false)
		throw_controller.allow_throwing = false
		_resume_enemy_spawning = enemy_spawn.is_processing()
		enemy_spawn.set_process(false)
		if is_instance_valid(food_spawn) and food_spawn.has_method("stop_spawning"):
			food_spawn.call("stop_spawning")

	if not food_bridge.is_bridge_ready():
		if waited_frames >= BRIDGE_READY_FRAME_LIMIT:
			push_error("[Level3] Food bridge did not become ready within %d frames." % BRIDGE_READY_FRAME_LIMIT)
			return
		await get_tree().process_frame
		_initialize_level(generation, waited_frames + 1)
		return

	nutrition_system.game_over.connect(_on_nutrition_game_over)
	enemy_spawn.connect("level_completed", complete_level_systems)

	if hide_original_hearts:
		var hearts := player.get_node_or_null(health_display_path) as CanvasLayer
		if hearts != null:
			hearts.hide()
	nutrition_ui.show()

	systems_ready = true
	if automatically_start_battle:
		start_level_systems()


func start_level_systems() -> void:
	if not systems_ready or battle_started or battle_finished:
		return

	battle_started = true
	if reset_throw_charge_on_start:
		throw_charge_system.reset_all_charges()
	throw_charge_system.set_system_enabled(true)
	throw_controller.cooldown_remaining = 0.0
	throw_controller.allow_throwing = true
	nutrition_system.start_battle()

	if _resume_enemy_spawning:
		enemy_spawn.set_process(true)
	if is_instance_valid(food_spawn) and food_spawn.has_method("start_spawning"):
		food_spawn.call("start_spawning")

	if print_debug_messages:
		print("[Level3] Battle systems started.")
	level_systems_started.emit()


func complete_level_systems() -> void:
	if battle_started and not battle_finished:
		_finish_systems()
		if print_debug_messages:
			print("[Level3] Victory accepted.")
		level_victory_accepted.emit()


func _on_nutrition_game_over(category: int) -> void:
	if not battle_started or battle_finished:
		return
	if print_debug_messages:
		print("[Level3] Nutrition depleted: ", throw_charge_system.get_category_name(category))
	_finish_systems()
	nutrition_failure.emit(category)


func _finish_systems() -> void:
	battle_finished = true
	battle_started = false
	throw_controller.allow_throwing = false
	throw_controller._cancel_aim()
	throw_charge_system.set_system_enabled(false)
	nutrition_system.stop_battle()
	enemy_spawn.set_process(false)
	if is_instance_valid(food_spawn) and food_spawn.has_method("stop_spawning"):
		food_spawn.call("stop_spawning")
	throw_controller.clear_food_buffs()
	level_systems_stopped.emit()
