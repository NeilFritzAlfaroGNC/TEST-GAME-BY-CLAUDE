extends Node2D
class_name CafeteriaItemThrowController

# ==================================================
# CAFETERIA LEVEL 1
# FOOD-POWERED MANUAL THROWING
# GODOT 4.7.1
# ==================================================
#
# Controls:
#
# 1 = GO Throw
# 2 = GLOW Throw
# 3 = GROW Throw
#
# Hold left click to charge and aim.
# Release left click to throw.
#
# Requirements:
# - Selected category has 100 charge
# - Player is alive
# - Nutrition system permits throwing
# - Player is not dragging food
#
# The original automatic FoodThrow system
# is not used by this controller.
# ==================================================


# ==================================================
# SIGNALS
# ==================================================

signal throw_category_selected(category: int)
signal combat_buff_started(buff_id: String, duration: float, strength: float)
signal combat_buff_expired(buff_id: String)

signal energy_projectile_launched(
	category: int,
	damage: int
)


# ==================================================
# THROW SETTINGS
# ==================================================

@export_group("Throw Settings")

@export_range(0.0, 3000.0, 10.0) var base_launch_speed: float = 660.0

@export_range(0.0, 3000.0, 10.0) var projectile_gravity: float = 720.0

@export_range(0.0, 30.0, 0.05) var base_cooldown: float = 1.0

@export_range(0.05, 10.0, 0.05) var maximum_charge_time: float = 1.5

@export_range(0.05, 1.0, 0.05)
var minimum_power: float = 0.35

@export_range(0.05, 2.0, 0.05) var maximum_power: float = 1.0

@export_range(0.0, 45.0, 1.0)
var minimum_angle_degrees: float = 10.0

@export_range(45.0, 90.0, 1.0)
var maximum_angle_degrees: float = 80.0

@export var launch_offset: Vector2 = (
	Vector2(0.0, -25.0)
)


# ==================================================
# PREVIEW SETTINGS
# ==================================================

@export_group("Accuracy Settings")
@export_range(0.0, 45.0, 1.0) var accuracy_minimum_angle: float = 5.0
@export_range(45.0, 90.0, 1.0) var accuracy_maximum_angle: float = 85.0

@export_group("Projectile Configuration")
@export var projectile_scene: PackedScene
@export var override_projectile_gravity: bool = true

@export_group("Trajectory Preview")

@export var show_trajectory: bool = true

@export_range(5, 100, 1)
var preview_point_count: int = 35

@export_range(1.0, 10.0, 0.5)
var preview_dot_radius: float = 2.5


# ==================================================
# CONTROLLER SETTINGS
# ==================================================

@export_group("Category Colors")
@export var go_color: Color = Color("#F5C842")
@export var glow_color: Color = Color("#86F456")
@export var grow_color: Color = Color("#F47C69")

@export_group("Controller")

@export var allow_throwing: bool = true

@export_enum("GO", "GLOW", "GROW")
var starting_category: int = 0

@export var print_debug_messages: bool = true


# ==================================================
# PROJECTILE SCRIPT
# ==================================================

@export_group("Temporary Food Buffs")
@export var enable_combat_buffs: bool = true
@export_range(0.0, 300.0, 1.0) var maximum_damage_boost_percent: float = 200.0
@export_range(0.0, 90.0, 1.0) var maximum_cooldown_reduction_percent: float = 75.0
@export_range(0.0, 300.0, 1.0) var maximum_charge_boost_percent: float = 200.0

const BUFF_DAMAGE := "damage_boost"
const BUFF_COOLDOWN := "cooldown_reduction"
const BUFF_CHARGE := "charge_boost"

const PROJECTILE_SCRIPT: Script = preload(
	"res://scripts/Nutrition System/item_projectile.gd"
)


# ==================================================
# COLORS
# ==================================================



# ==================================================
# REFERENCES
# ==================================================

var player: Node2D = null

var nutrition_system: NutritionSystem = null

var throw_charge_system: ThrowChargeSystem = null

var battle_scene: Node = null


# ==================================================
# THROWING STATE
# ==================================================

var selected_category: int = 0

var is_aiming: bool = false

var charge_time: float = 0.0

var cooldown_remaining: float = 0.0

var aim_direction: float = 1.0

var aim_angle: float = 0.0

var preview_points: Array[Vector2] = []
var _cached_projectile_scene: PackedScene
var _cached_scene_gravity: float = -1.0

var controller_ready: bool = false
var active_combat_buffs: Dictionary = {}


# ==================================================
# INITIALIZATION
# ==================================================

func _ready() -> void:

	selected_category = clampi(
		starting_category,
		0,
		2
	)

	set_process(true)

	set_process_input(true)

	call_deferred(
		"_initialize_controller"
	)


# ==================================================
# INITIALIZE REFERENCES
# ==================================================

func _initialize_controller() -> void:

	controller_ready = false

	battle_scene = get_parent()

	if battle_scene == null:
		push_error(
			"[ItemThrow] Battle scene missing."
		)
		return

	player = battle_scene.get_node_or_null("main_character") as Node2D

	if not is_instance_valid(player):

		push_error(
			"[ItemThrow] Player missing."
		)

		return

	nutrition_system = (
		battle_scene.get_node_or_null(
			"NutritionSystem"
		) as NutritionSystem
	)

	if nutrition_system == null:

		push_error(
			"[ItemThrow] NutritionSystem missing."
		)

		return

	throw_charge_system = (
		battle_scene.get_node_or_null(
			"ThrowChargeSystem"
		) as ThrowChargeSystem
	)

	if throw_charge_system == null:

		push_error(
			"[ItemThrow] ThrowChargeSystem missing."
		)

		return

	if not nutrition_system.game_over.is_connected(
		_on_nutrition_game_over
	):

		nutrition_system.game_over.connect(
			_on_nutrition_game_over
		)

	controller_ready = true

	throw_category_selected.emit(
		selected_category
	)

	if print_debug_messages:

		print(
			"[ItemThrow] Food-powered throwing ready."
		)

		print(
			"[ItemThrow] Selected: ",
			_get_category_name(
				selected_category
			)
		)


# ==================================================
# PROCESS
# ==================================================

func _process(delta: float) -> void:
	_update_combat_buffs(delta)

	if cooldown_remaining > 0.0:

		cooldown_remaining = maxf(
			0.0,
			cooldown_remaining - delta
		)

	if not is_aiming:
		return

	if not _can_throw_selected():
		_cancel_aim()
		return

	if _battle_is_dragging_food():
		_cancel_aim()
		return

	charge_time = minf(
		charge_time + delta,
		maximum_charge_time
	)

	_update_aim()

	_update_trajectory()

	queue_redraw()


# ==================================================
# INPUT
# ==================================================

func _input(event: InputEvent) -> void:

	if not controller_ready:
		return

	if event is InputEventKey:

		var key_event: InputEventKey = (
			event as InputEventKey
		)

		if (
			key_event.pressed
			and not key_event.echo
		):

			match key_event.keycode:

				KEY_1:
					select_throw_category(0)

				KEY_2:
					select_throw_category(1)

				KEY_3:
					select_throw_category(2)

		return

	if not event is InputEventMouseButton:
		return

	var mouse_event: InputEventMouseButton = (
		event as InputEventMouseButton
	)

	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	if mouse_event.pressed:
		if battle_scene.is_pointer_over_food_inspector(mouse_event.position):
			return

		# Delayed until after the battle scene
		# has had a chance to register food
		# dragging from this mouse press.

		call_deferred(
			"_try_start_aim"
		)

	else:

		if is_aiming:
			_release_throw()


# ==================================================
# SELECT CATEGORY
# ==================================================

func select_throw_category(
	category: int
) -> void:

	if not controller_ready or not throw_charge_system.is_valid_category(category):
		return

	if is_aiming:
		_cancel_aim()

	selected_category = category

	throw_category_selected.emit(
		selected_category
	)

	if print_debug_messages:

		var category_name: String = (
			_get_category_name(category)
		)

		if throw_charge_system.is_throw_ready(
			category
		):

			print(
				"[ItemThrow] ",
				category_name,
				" selected. READY."
			)

		else:

			print(
				"[ItemThrow] ",
				category_name,
				" selected. Charge: ",
				throw_charge_system.get_charge(
					category
				),
				"/",
				throw_charge_system.get_required_charge()
			)


# ==================================================
# START AIM
# ==================================================

func _try_start_aim() -> void:

	if not Input.is_mouse_button_pressed(
		MOUSE_BUTTON_LEFT
	):
		return

	if is_aiming:
		return

	if _battle_is_dragging_food():
		return

	if not _can_throw_selected():
		return

	is_aiming = true

	charge_time = 0.0

	_update_aim()

	_update_trajectory()

	queue_redraw()


# ==================================================
# THROW PERMISSION
# ==================================================

func _can_throw_selected() -> bool:

	if not controller_ready:
		return false

	if not allow_throwing:
		return false

	if not is_instance_valid(player):
		return false

	if not is_instance_valid(nutrition_system):
		return false

	if not is_instance_valid(throw_charge_system):
		return false

	if cooldown_remaining > 0.0:
		return false

	if player.get("is_dead") == true:
		return false

	if not nutrition_system.battle_active:
		return false

	if nutrition_system.is_game_over:
		return false

	if not nutrition_system.can_player_throw():
		return false

	if not throw_charge_system.is_throw_ready(
		selected_category
	):
		return false

	return true


# ==================================================
# PREVENT FOOD DRAG CONFLICTS
# ==================================================

func _battle_is_dragging_food() -> bool:

	if not is_instance_valid(battle_scene):
		return false

	return (
		is_instance_valid(battle_scene.get("dragged_food"))
		or battle_scene.get("food_drop_in_progress") == true
		or battle_scene.get("long_press_active") == true
	)


# ==================================================
# AIMING
# ==================================================

func _update_aim() -> void:

	var origin: Vector2 = (
		_get_launch_position()
	)

	var mouse_position: Vector2 = (
		get_global_mouse_position()
	)

	var difference: Vector2 = (
		mouse_position - origin
	)

	if absf(difference.x) > 2.0:

		aim_direction = signf(
			difference.x
		)

	var horizontal_distance: float = maxf(
		absf(difference.x),
		1.0
	)

	var vertical_distance: float = (
		-difference.y
	)

	aim_angle = atan2(
		vertical_distance,
		horizontal_distance
	)

	aim_angle = clampf(
		aim_angle,
		deg_to_rad(
			minimum_angle_degrees
		),
		deg_to_rad(
			maximum_angle_degrees
		)
	)


# ==================================================
# CHARGE POWER
# ==================================================

func _get_charge_fraction() -> float:

	if maximum_charge_time <= 0.0:
		return 1.0

	return clampf(
		charge_time
		/ maximum_charge_time,
		0.0,
		1.0
	)


func _get_throw_power() -> float:

	return lerpf(
		minimum_power,
		maxf(minimum_power, maximum_power),
		_get_charge_fraction()
	)


# ==================================================
# LAUNCH POSITION
# ==================================================

func _get_launch_position() -> Vector2:

	if not is_instance_valid(player):
		return global_position

	return (
		player.global_position
		+ launch_offset
	)


# ==================================================
# PROJECTILE VELOCITY
# ==================================================

func _calculate_velocity(
	apply_accuracy_deviation: bool
) -> Vector2:

	var final_angle: float = aim_angle

	# ----------------------------------------------
	# GLOW DEFICIENCY ACCURACY
	# ----------------------------------------------

	if apply_accuracy_deviation:

		var deviation: float = (
			nutrition_system.get_accuracy_deviation()
		)

		if deviation > 0.0:

			final_angle += deg_to_rad(
				randf_range(
					-deviation,
					deviation
				)
			)

			final_angle = clampf(
				final_angle,
				deg_to_rad(accuracy_minimum_angle),
				deg_to_rad(accuracy_maximum_angle)
			)

	# ----------------------------------------------
	# THROW POWER
	# ----------------------------------------------

	var speed: float = (
		base_launch_speed
		* _get_throw_power()
	)

	# ----------------------------------------------
	# GROW DEFICIENCY RANGE PENALTY
	# ----------------------------------------------

	var range_multiplier: float = (
		nutrition_system.get_throw_power_multiplier()
	)

	# Godot GDScript uses sqrt(), not sqrtf().
	#
	# Projectile range is approximately
	# proportional to speed squared.

	speed *= sqrt(
		maxf(
			range_multiplier,
			0.0
		)
	)

	return Vector2(
		aim_direction
		* cos(final_angle)
		* speed,
		-sin(final_angle)
		* speed
	)


# ==================================================
# UPDATE TRAJECTORY
# ==================================================

func _get_effective_gravity() -> float:
	if override_projectile_gravity or projectile_scene == null:
		return maxf(projectile_gravity, 0.0)

	if _cached_projectile_scene != projectile_scene:
		_cached_projectile_scene = projectile_scene
		_cached_scene_gravity = -1.0
		var sample := projectile_scene.instantiate()
		if sample is CafeteriaItemProjectile:
			_cached_scene_gravity = maxf(sample.gravity, 0.0)
		if sample != null:
			sample.free()

	return _cached_scene_gravity if _cached_scene_gravity >= 0.0 else maxf(projectile_gravity, 0.0)


func _update_trajectory() -> void:

	preview_points.clear()

	if not show_trajectory:
		return

	if not is_instance_valid(player):
		return

	var gravity := _get_effective_gravity()

	var origin: Vector2 = (
		_get_launch_position()
	)

	var launch_velocity: Vector2 = (
		_calculate_velocity(false)
	)

	# Expected flight time for return
	# to the initial launch height.

	var flight_time := 2.0 * absf(launch_velocity.y) / gravity if gravity > 0.0 else 1.0

	var point_count: int = maxi(
		preview_point_count,
		2
	)

	for i in range(point_count):

		var fraction: float = (
			float(i)
			/ float(point_count - 1)
		)

		var time_value: float = (
			flight_time * fraction
		)

		var displacement: Vector2 = Vector2(
			launch_velocity.x * time_value,
			launch_velocity.y * time_value
			+ 0.5
			* gravity
			* time_value
			* time_value
		)

		preview_points.append(
			to_local(
				origin + displacement
			)
		)


# ==================================================
# DRAW TRAJECTORY
# ==================================================

func _draw() -> void:

	if not is_aiming:
		return

	if not show_trajectory:
		return

	var preview_color: Color = (
		_get_category_color(
			selected_category
		)
	)

	for point in preview_points:

		draw_circle(
			point,
			preview_dot_radius,
			preview_color
		)


# ==================================================
# RELEASE THROW
# ==================================================

func _create_projectile() -> CafeteriaItemProjectile:
	var instance: Node = projectile_scene.instantiate() if projectile_scene != null else PROJECTILE_SCRIPT.new()
	if instance is CafeteriaItemProjectile:
		return instance
	if instance != null:
		instance.free()
	push_error("[ItemThrow] Projectile Scene root must use item_projectile.gd.")
	return null


func _release_throw() -> void:

	if not is_aiming:
		return

	if _battle_is_dragging_food():
		_cancel_aim()
		return

	if not _can_throw_selected():
		_cancel_aim()
		return

	if PROJECTILE_SCRIPT == null:

		push_error(
			"[ItemThrow] Projectile script missing."
		)

		_cancel_aim()
		return

	# ----------------------------------------------
	# GET PREPARED FOOD ATTACK
	# ----------------------------------------------

	var category := selected_category
	var attack_data: Dictionary = (
		throw_charge_system.get_prepared_attack(
			category
		)
	)

	if attack_data.is_empty():

		_cancel_aim()
		return

	var food_damage: int = maxi(
		0,
		int(
			attack_data.get(
				"damage",
				0
			)
		)
	)

	# ----------------------------------------------
	# APPLY NUTRITION DAMAGE MODIFIER
	# ----------------------------------------------

	var damage_multiplier: float = (
		nutrition_system.get_throw_damage_multiplier()
	)

	var final_damage: int = maxi(
		0,
		roundi(
			float(food_damage)
			* damage_multiplier
			* get_damage_boost_multiplier()
		)
	)

	# ----------------------------------------------
	# CREATE PROJECTILE
	# ----------------------------------------------

	var projectile := _create_projectile()

	if projectile == null:

		push_error(
			"[ItemThrow] Could not create projectile."
		)

		_cancel_aim()
		return

	battle_scene.add_child(projectile)

	# ----------------------------------------------
	# CALCULATE ACTUAL THROW
	# ----------------------------------------------

	var launch_velocity: Vector2 = (
		_calculate_velocity(true)
	)

	projectile.gravity = _get_effective_gravity()

	projectile.launch(
		_get_launch_position(),
		launch_velocity,
		final_damage,
		player,
		category,
		attack_data
	)
	projectile.projectile_color = _get_category_color(category)

	# ----------------------------------------------
	# CONSUME THROW CHARGE
	# ----------------------------------------------

	# Charge is consumed only after
	# a projectile has been launched.

	throw_charge_system.consume_throw(
		category
	)

	# ----------------------------------------------
	# START THROW COOLDOWN
	# ----------------------------------------------

	var cooldown_multiplier: float = (
		nutrition_system.get_throw_cooldown_multiplier()
	)

	cooldown_remaining = maxf(
		0.0,
		base_cooldown
		* cooldown_multiplier
		* get_cooldown_boost_multiplier()
	)

	energy_projectile_launched.emit(
		category,
		final_damage
	)

	if print_debug_messages:

		print(
			"[ItemThrow] ",
			_get_category_name(
				category
			),
			" energy thrown! Damage: ",
			final_damage,
			" | Power: ",
			snappedf(
				_get_throw_power(),
				0.01
			)
		)

	_cancel_aim()


# ==================================================
# CANCEL AIMING
# ==================================================

func _cancel_aim() -> void:

	is_aiming = false

	charge_time = 0.0

	preview_points.clear()

	queue_redraw()


func apply_food_buff(buff_id: String, duration: float, strength: float) -> void:
	if not enable_combat_buffs or not controller_ready or not is_instance_valid(nutrition_system):
		return
	if not nutrition_system.battle_active or nutrition_system.is_game_over or duration <= 0.0:
		return

	var id := buff_id.strip_edges().to_lower()
	var limit := _get_maximum_buff_strength(id)
	var percent := clampf(strength, 0.0, limit)
	if percent <= 0.0:
		return

	# Reapplying refreshes the timer and retains the stronger percentage.
	percent = maxf(percent, get_food_buff_strength(id))
	active_combat_buffs[id] = {"strength": percent, "remaining": duration}
	combat_buff_started.emit(id, duration, percent)
	if print_debug_messages:
		print("[ItemThrow Buff] Activated: ", id, " | Strength: ", percent, "% | Duration: ", duration, "s")


func _update_combat_buffs(delta: float) -> void:
	for id: String in active_combat_buffs.keys():
		var buff: Dictionary = active_combat_buffs.get(id, {})
		if buff.is_empty():
			continue
		buff.remaining -= delta
		if buff.remaining <= 0.0:
			active_combat_buffs.erase(id)
			combat_buff_expired.emit(id)
			if print_debug_messages:
				print("[ItemThrow Buff] Expired: ", id)


func get_damage_boost_multiplier() -> float:
	return 1.0 + get_food_buff_strength(BUFF_DAMAGE) / 100.0


func get_cooldown_boost_multiplier() -> float:
	return clampf(1.0 - get_food_buff_strength(BUFF_COOLDOWN) / 100.0, 0.1, 1.0)


func get_charge_gain_multiplier() -> float:
	return 1.0 + get_food_buff_strength(BUFF_CHARGE) / 100.0


func get_food_buff_strength(buff_id: String) -> float:
	if not enable_combat_buffs:
		return 0.0
	var buff: Dictionary = active_combat_buffs.get(buff_id.strip_edges().to_lower(), {})
	return float(buff.get("strength", 0.0))


func get_food_buff_remaining(buff_id: String) -> float:
	if not enable_combat_buffs:
		return 0.0
	var buff: Dictionary = active_combat_buffs.get(buff_id.strip_edges().to_lower(), {})
	return float(buff.get("remaining", 0.0))


func has_food_buff(buff_id: String) -> bool:
	return get_food_buff_remaining(buff_id) > 0.0


func get_active_food_buffs() -> Dictionary:
	return active_combat_buffs.duplicate(true)


func clear_food_buffs() -> void:
	var ids := active_combat_buffs.keys()
	active_combat_buffs.clear()
	for id: String in ids:
		combat_buff_expired.emit(id)


func _get_maximum_buff_strength(buff_id: String) -> float:
	match buff_id:
		BUFF_DAMAGE:
			return maximum_damage_boost_percent
		BUFF_COOLDOWN:
			return maximum_cooldown_reduction_percent
		BUFF_CHARGE:
			return maximum_charge_boost_percent
	return 0.0


# ==================================================
# GAME OVER
# ==================================================

func _on_nutrition_game_over(
	_category: int
) -> void:

	allow_throwing = false

	_cancel_aim()
	clear_food_buffs()


# ==================================================
# CATEGORY NAMES
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


# ==================================================
# CATEGORY COLORS
# ==================================================

func _get_category_color(
	category: int
) -> Color:

	match category:

		0:
			return go_color

		1:
			return glow_color

		2:
			return grow_color

	return Color.WHITE
