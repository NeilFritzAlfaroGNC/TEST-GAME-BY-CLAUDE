extends Node2D
class_name CafeteriaItemProjectile

# ==================================================
# CAFETERIA LEVEL 1
# FOOD ENERGY PROJECTILE
# GODOT 4.7.1
# ==================================================
#
# Three categories:
# GO   = Yellow
# GLOW = Green
# GROW = Red
#
# Features:
# - Gravity-based projectile movement
# - Enemy collision detection
# - Food-specific damage
# - Category-specific appearance
# - One enemy hit per projectile
#
# Buff data is preserved for later integration.
# ==================================================


signal projectile_hit(enemy: Node, damage: int)
signal projectile_finished


# ==================================================
# SETTINGS
# ==================================================

@export_group("Projectile Physics")

@export var gravity: float = 720.0

@export var maximum_lifetime: float = 5.0

@export var collision_radius: float = 28.0

@export var maximum_fall_distance: float = 700.0


@export_group("Appearance")

@export var projectile_radius: float = 8.0

@export var draw_trail: bool = true

@export_range(1, 30, 1)
var maximum_trail_points: int = 12


@export_group("Temporary Buff Defaults")
@export_range(1.0, 1000.0, 1.0) var default_knockback_strength: float = 250.0
@export_range(0.1, 30.0, 0.1) var default_status_duration: float = 2.0
@export_range(0.0, 100.0, 0.5) var default_burn_damage: float = 2.0
@export_range(1, 20, 1) var default_burn_tick_count: int = 5
@export_range(0.1, 10.0, 0.1) var default_burn_tick_interval: float = 1.0

@export_group("Debugging")
@export var print_debug_messages: bool = true


# ==================================================
# COLORS
# ==================================================

const GO_COLOR: Color = Color("#F5C842")
const GLOW_COLOR: Color = Color("#86F456")
const GROW_COLOR: Color = Color("#F47C69")


# ==================================================
# PROJECTILE DATA
# ==================================================

var category: int = 0

var damage: int = 10

var velocity: Vector2 = Vector2.ZERO

var source_player: Node2D = null

var attack_data: Dictionary = {}

var projectile_color: Color = GO_COLOR


# ==================================================
# INTERNAL STATE
# ==================================================

var active: bool = false

var lifetime: float = 0.0

var starting_position: Vector2 = Vector2.ZERO

var trail_points: Array[Vector2] = []


# ==================================================
# INITIALIZATION
# ==================================================

func _ready() -> void:

	set_physics_process(false)

	z_index = 20


# ==================================================
# LAUNCH
# ==================================================

func launch(
	start_position: Vector2,
	initial_velocity: Vector2,
	projectile_damage: int,
	player: Node2D,
	projectile_category: int = 0,
	prepared_data: Dictionary = {}
) -> void:

	global_position = start_position

	starting_position = start_position

	velocity = initial_velocity

	damage = maxi(projectile_damage, 0)

	source_player = player

	category = projectile_category

	attack_data = prepared_data.duplicate(true)
	if print_debug_messages:
		print("[EnergyProjectile] Launched: ", _get_category_name(category),
			" | Damage: ", damage, " | Buff: ", _get_buff_id())

	projectile_color = _get_category_color(
		category
	)

	lifetime = 0.0

	active = true

	trail_points.clear()

	set_physics_process(true)

	queue_redraw()


# ==================================================
# PHYSICS
# ==================================================

func _physics_process(delta: float) -> void:

	if not active:
		return

	lifetime += delta

	if lifetime >= maximum_lifetime:
		_finish_projectile()
		return

	var previous_position: Vector2 = (
		global_position
	)

	# ----------------------------------------------
	# APPLY GRAVITY
	# ----------------------------------------------

	var movement: Vector2 = (
		velocity * delta
		+ Vector2(
			0.0,
			0.5 * gravity * delta * delta
		)
	)

	global_position += movement

	velocity.y += gravity * delta

	# ----------------------------------------------
	# CHECK ENEMY COLLISION
	# ----------------------------------------------

	var hit_enemy: Node2D = (
		_find_hit_enemy(
			previous_position,
			global_position
		)
	)

	if is_instance_valid(hit_enemy):

		_apply_enemy_hit(hit_enemy)

		_finish_projectile()
		return

	# ----------------------------------------------
	# UPDATE VISUAL TRAIL
	# ----------------------------------------------

	if draw_trail:

		trail_points.append(
			previous_position
		)

		while (
			trail_points.size()
			> maximum_trail_points
		):
			trail_points.remove_at(0)

		queue_redraw()

	# ----------------------------------------------
	# OUT-OF-RANGE CHECK
	# ----------------------------------------------

	if (
		global_position.y
		> starting_position.y + maximum_fall_distance
	):
		_finish_projectile()


# ==================================================
# ENEMY DETECTION
# ==================================================

func _find_hit_enemy(
	previous_position: Vector2,
	current_position: Vector2
) -> Node2D:

	var closest_enemy: Node2D = null

	var closest_distance: float = INF

	for enemy_node in get_tree().get_nodes_in_group(
		"enemy"
	):

		if not is_instance_valid(enemy_node):
			continue

		if not enemy_node is Node2D:
			continue

		var enemy: Node2D = (
			enemy_node as Node2D
		)

		if enemy == source_player:
			continue

		if not enemy.is_inside_tree():
			continue

		if enemy.get("is_dead") == true:
			continue

		if not enemy.has_method("take_damage"):
			continue

		# Swept collision detection:
		# Check the projectile's path between
		# previous and current positions.

		var closest_point: Vector2 = (
			Geometry2D.get_closest_point_to_segment(
				enemy.global_position,
				previous_position,
				current_position
			)
		)

		var distance: float = (
			closest_point.distance_to(
				enemy.global_position
			)
		)

		if distance > collision_radius:
			continue

		if distance < closest_distance:

			closest_distance = distance

			closest_enemy = enemy

	return closest_enemy


# ==================================================
# DEAL ENEMY DAMAGE
# ==================================================

func _apply_enemy_hit(enemy: Node2D) -> void:
	if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or enemy.get("is_dead") == true:
		return
	if not enemy.has_method("take_damage"):
		return

	enemy.call("take_damage", damage)
	if not is_instance_valid(enemy):
		return
	if print_debug_messages:
		print("[EnergyProjectile] ", _get_category_name(category), " hit ", enemy.name, " | Damage: ", damage)
	projectile_hit.emit(enemy, damage)

	if is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and enemy.get("is_dead") != true:
		_apply_projectile_buff(enemy)


func _apply_projectile_buff(enemy: Node2D) -> void:
	var buff_id := _get_buff_id()
	var duration := float(attack_data.get("buff_duration", 0.0))
	if duration <= 0.0:
		duration = default_status_duration

	match buff_id:
		"stun", "freeze":
			var method := StringName("apply_" + buff_id)
			if enemy.has_method(method):
				enemy.call(method, duration)
		"knockback":
			if enemy.has_method("apply_knockback"):
				var direction := velocity.normalized()
				if is_instance_valid(source_player):
					direction = source_player.global_position.direction_to(enemy.global_position)
				if direction.is_zero_approx():
					direction = Vector2.RIGHT
				var strength := _get_buff_strength(default_knockback_strength)
				enemy.call("apply_knockback", direction, strength)
				if print_debug_messages:
					print("[EnergyProjectile] KNOCKBACK: ", enemy.name, " | Strength: ", strength)
		"burn":
			if enemy.has_method("apply_burn"):
				var burn_damage := _get_buff_strength(default_burn_damage)
				var tick_count := default_burn_tick_count
				# Preserve the existing burn schedule for foods using fallback strength.
				if float(attack_data.get("buff_strength", 0.0)) > 0.0:
					tick_count = clampi(floori(duration / default_burn_tick_interval), 1, default_burn_tick_count)
				enemy.call("apply_burn", burn_damage, duration, tick_count, default_burn_tick_interval)
				if print_debug_messages:
					print("[EnergyProjectile] BURN: ", enemy.name, " | Damage value: ", burn_damage,
						" | Duration: ", duration, " | Ticks: ", tick_count)


func _get_buff_strength(fallback: float) -> float:
	var strength := float(attack_data.get("buff_strength", 0.0))
	return strength if strength > 0.0 else fallback


func _get_buff_id() -> String:
	return str(attack_data.get("buff_id", "")).strip_edges().to_lower()


# ==================================================
# FINISH
# ==================================================

func _finish_projectile() -> void:

	if not active:
		return

	active = false

	set_physics_process(false)

	projectile_finished.emit()

	queue_free()


# ==================================================
# DRAW PROJECTILE
# ==================================================

func _draw() -> void:

	if not active:
		return

	# ----------------------------------------------
	# TRAIL
	# ----------------------------------------------

	if draw_trail:

		for i in range(trail_points.size()):

			var fraction: float = (
				float(i + 1)
				/ float(
					maxi(trail_points.size(), 1)
				)
			)

			var trail_color: Color = (
				projectile_color
			)

			trail_color.a = (
				fraction * 0.55
			)

			draw_circle(
				to_local(trail_points[i]),
				maxf(
					1.0,
					projectile_radius
					* fraction
					* 0.5
				),
				trail_color
			)

	# ----------------------------------------------
	# OUTER ENERGY
	# ----------------------------------------------

	var outer_color: Color = (
		projectile_color.darkened(0.35)
	)

	draw_circle(
		Vector2.ZERO,
		projectile_radius + 3.0,
		outer_color
	)

	# ----------------------------------------------
	# INNER ENERGY
	# ----------------------------------------------

	draw_circle(
		Vector2.ZERO,
		projectile_radius,
		projectile_color
	)

	# ----------------------------------------------
	# HIGHLIGHT
	# ----------------------------------------------

	draw_circle(
		Vector2(-2.0, -2.0),
		maxf(
			1.5,
			projectile_radius * 0.32
		),
		projectile_color.lightened(0.55)
	)


# ==================================================
# CATEGORY COLORS
# ==================================================

func _get_category_color(
	throw_category: int
) -> Color:

	match throw_category:

		0:
			return GO_COLOR

		1:
			return GLOW_COLOR

		2:
			return GROW_COLOR

	return Color.WHITE


# ==================================================
# CATEGORY NAMES
# ==================================================

func _get_category_name(
	throw_category: int
) -> String:

	match throw_category:

		0:
			return "GO"

		1:
			return "GLOW"

		2:
			return "GROW"

	return "UNKNOWN"
