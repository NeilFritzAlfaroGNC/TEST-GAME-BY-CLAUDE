extends Node2D
class_name Level1EnemySpawner

# ==================================================
# LEVEL 1 - FLOOR ENEMY SPAWNER
# GODOT 4.7.1
#
# - Three spawn points
# - Random enemy scenes
# - Independent active enemy limit per floor
# - Independent spawn interval per floor
# - Battle Controller controls shared quota
# - Counts each successful spawn once
# - Defeated / vanished enemies do not refund quota
# - Supports Student -> Soda -> Student lifecycle
# ==================================================


# ==================================================
# ENEMY SCENES
# ==================================================

@export_group("Enemy Scenes")

@export var enemy_scenes: Array[PackedScene] = []


# ==================================================
# SPAWN POINTS
# ==================================================

@export_group("Spawn Points")

@export var spawn_point_1: NodePath = ^"SpawnPoint1"
@export var spawn_point_2: NodePath = ^"SpawnPoint2"
@export var spawn_point_3: NodePath = ^"SpawnPoint3"


# ==================================================
# DEFAULT SPAWNING SETTINGS
# ==================================================

@export_group("Spawning")

@export var spawning_enabled: bool = true
@export var spawn_immediately: bool = true

@export_range(1, 3, 1)
var maximum_active_enemies: int = 3

@export_range(0.1, 60.0, 0.1)
var minimum_spawn_interval: float = 2.0

@export_range(0.1, 60.0, 0.1)
var maximum_spawn_interval: float = 4.0


# ==================================================
# MONSTER APPEARANCE
# ==================================================

@export_group("Floor Monster Settings")

@export_range(0.1, 5.0, 0.05)
var monster_scale_multiplier: float = 1.0

@export_range(-300.0, 300.0, 1.0)
var spawn_height_offset: float = 0.0


# ==================================================
# SCENE REFERENCES
# ==================================================

@export_group("Scene References")

@export var enemy_container_path: NodePath = NodePath("")


# ==================================================
# DEBUG
# ==================================================

@export_group("Debug")

@export var show_debug_messages: bool = false


# ==================================================
# INTERNAL STATE
# ==================================================

var spawn_timer: float = 0.0

var spawn_markers: Array[Marker2D] = []

var occupied_enemies: Array[Node2D] = [
	null,
	null,
	null
]

var enemy_container: Node2D = null

var battle_controller: Level1BattleController = null

var initialized: bool = false
var battle_spawning_started: bool = false

var total_spawned_by_this_floor: int = 0


# ==================================================
# INITIALIZATION
# ==================================================

func _ready() -> void:

	initialized = false
	battle_spawning_started = false

	set_process(false)

	_find_enemy_container()
	_find_spawn_points()

	if not is_instance_valid(enemy_container):
		push_error(
			"[Level1EnemySpawner] "
			+ "Enemy container not found: "
			+ name
		)
		return

	if spawn_markers.size() != 3:
		push_error(
			"[Level1EnemySpawner] "
			+ "Three spawn points are required: "
			+ name
		)
		return

	if _get_valid_enemy_scenes().is_empty():
		push_warning(
			"[Level1EnemySpawner] "
			+ "No valid enemy scenes: "
			+ name
		)
		return

	initialized = true

	_reset_spawn_timer()

	_debug(
		"Spawner initialized. "
		+ "Waiting for Battle Controller."
	)


# ==================================================
# FIND ENEMY CONTAINER
# ==================================================

func _find_enemy_container() -> void:

	enemy_container = null

	if not enemy_container_path.is_empty():

		enemy_container = (
			get_node_or_null(enemy_container_path)
			as Node2D
		)

		if is_instance_valid(enemy_container):
			return

	var scene_root: Node = get_tree().current_scene

	if not is_instance_valid(scene_root):
		return

	enemy_container = (
		scene_root.get_node_or_null("Level1Enemies")
		as Node2D
	)


# ==================================================
# FIND SPAWN POINTS
# ==================================================

func _find_spawn_points() -> void:

	spawn_markers.clear()

	var paths: Array[NodePath] = [
		spawn_point_1,
		spawn_point_2,
		spawn_point_3
	]

	for path in paths:

		var marker: Marker2D = (
			get_node_or_null(path) as Marker2D
		)

		if not is_instance_valid(marker):

			push_error(
				"[Level1EnemySpawner] "
				+ "Missing spawn point: "
				+ String(path)
			)
			return

		spawn_markers.append(marker)


# ==================================================
# BATTLE CONTROLLER CONNECTION
# ==================================================

func set_battle_controller(
	controller: Level1BattleController
) -> void:

	battle_controller = controller

	if is_instance_valid(battle_controller):
		_debug("Battle Controller connected.")


# ==================================================
# CONFIGURE FLOOR SETTINGS
# ==================================================

func configure_spawn_limits(
	max_active: int,
	min_interval: float,
	max_interval: float
) -> void:

	maximum_active_enemies = clampi(
		max_active,
		1,
		3
	)

	minimum_spawn_interval = maxf(
		min_interval,
		0.1
	)

	maximum_spawn_interval = maxf(
		max_interval,
		minimum_spawn_interval
	)

	_reset_spawn_timer()

	_debug(
		"Configured | Maximum active: "
		+ str(maximum_active_enemies)
		+ " | Interval: "
		+ str(minimum_spawn_interval)
		+ "-"
		+ str(maximum_spawn_interval)
	)


# ==================================================
# START FLOOR SPAWNING
# ==================================================

func start_spawning() -> void:

	if not initialized:
		return

	if not spawning_enabled:
		return

	if not is_instance_valid(battle_controller):

		push_error(
			"[Level1EnemySpawner] "
			+ "Cannot spawn without Battle Controller."
		)
		return

	if not battle_controller.battle_running:
		return

	if battle_controller.battle_finished:
		return

	if not battle_controller.can_spawn_more_enemies():
		return

	if battle_spawning_started:
		return

	battle_spawning_started = true

	_reset_spawn_timer()

	if spawn_immediately:
		_spawn_random_enemy()

	if spawning_enabled:
		set_process(true)

	_debug("Floor spawning started.")


# ==================================================
# STOP FLOOR SPAWNING
# ==================================================

func stop_spawning() -> void:

	spawning_enabled = false
	battle_spawning_started = false

	set_process(false)

	_debug("Floor spawning stopped.")


# ==================================================
# SPAWN PROCESS
# ==================================================

func _process(delta: float) -> void:

	if not initialized:
		return

	if not battle_spawning_started:
		return

	if not spawning_enabled:
		return

	if not is_instance_valid(battle_controller):
		stop_spawning()
		return

	if not battle_controller.battle_running:
		return

	if battle_controller.battle_finished:
		stop_spawning()
		return

	# Strict shared quota check.
	if not battle_controller.can_spawn_more_enemies():
		stop_spawning()
		return

	_refresh_occupied_slots()

	if _count_active_enemies() >= maximum_active_enemies:
		return

	spawn_timer -= delta

	if spawn_timer > 0.0:
		return

	_spawn_random_enemy()

	_reset_spawn_timer()


# ==================================================
# RANDOM SPAWN INTERVAL
# ==================================================

func _reset_spawn_timer() -> void:

	var low: float = maxf(
		minf(
			minimum_spawn_interval,
			maximum_spawn_interval
		),
		0.1
	)

	var high: float = maxf(
		maxf(
			minimum_spawn_interval,
			maximum_spawn_interval
		),
		low
	)

	spawn_timer = randf_range(
		low,
		high
	)


# ==================================================
# REFRESH OCCUPIED SLOTS
# ==================================================

func _refresh_occupied_slots() -> void:

	for index in range(occupied_enemies.size()):

		var enemy: Node2D = occupied_enemies[index]

		if not is_instance_valid(enemy):
			occupied_enemies[index] = null
			continue

		if enemy.is_queued_for_deletion():
			occupied_enemies[index] = null
			continue

		if enemy.get_parent() != enemy_container:
			occupied_enemies[index] = null


# ==================================================
# COUNT ACTIVE ENEMIES
# ==================================================

func _count_active_enemies() -> int:

	_refresh_occupied_slots()

	var count: int = 0

	for enemy in occupied_enemies:

		if not is_instance_valid(enemy):
			continue

		if enemy.is_queued_for_deletion():
			continue

		count += 1

	return count


func get_active_enemy_count() -> int:

	return _count_active_enemies()


func get_total_spawned_count() -> int:

	return total_spawned_by_this_floor


# ==================================================
# AVAILABLE SPAWN SLOTS
# ==================================================

func _get_available_slots() -> Array[int]:

	var available: Array[int] = []

	for index in range(spawn_markers.size()):

		if not is_instance_valid(
			occupied_enemies[index]
		):
			available.append(index)

	return available


# ==================================================
# GET VALID ENEMY SCENES
# ==================================================

func _get_valid_enemy_scenes() -> Array[PackedScene]:

	var valid_scenes: Array[PackedScene] = []

	for scene in enemy_scenes:
		if scene != null:
			valid_scenes.append(scene)

	return valid_scenes


# ==================================================
# SPAWN RANDOM ENEMY
# ==================================================

func _spawn_random_enemy() -> void:

	if not initialized:
		return

	if not spawning_enabled:
		return

	if not battle_spawning_started:
		return

	if not is_instance_valid(enemy_container):
		return

	if not is_instance_valid(battle_controller):
		return

	if not battle_controller.can_spawn_more_enemies():
		return

	_refresh_occupied_slots()

	if _count_active_enemies() >= maximum_active_enemies:
		return

	var available_slots: Array[int] = (
		_get_available_slots()
	)

	if available_slots.is_empty():
		return

	var valid_scenes: Array[PackedScene] = (
		_get_valid_enemy_scenes()
	)

	if valid_scenes.is_empty():

		push_warning(
			"[Level1EnemySpawner] "
			+ "No valid enemy scenes."
		)
		return

	# ----------------------------------------------
	# RANDOM SPAWN SLOT
	# ----------------------------------------------

	var slot_index: int = available_slots[
		randi_range(
			0,
			available_slots.size() - 1
		)
	]

	var marker: Marker2D = spawn_markers[
		slot_index
	]

	# ----------------------------------------------
	# RANDOM ENEMY SCENE
	# ----------------------------------------------

	var selected_scene: PackedScene = valid_scenes[
		randi_range(
			0,
			valid_scenes.size() - 1
		)
	]

	var instance: Node = (
		selected_scene.instantiate()
	)

	if not instance is CharacterBody2D:

		push_error(
			"[Level1EnemySpawner] "
			+ "Enemy root must be CharacterBody2D."
		)

		if is_instance_valid(instance):
			instance.free()

		return

	var enemy: CharacterBody2D = (
		instance as CharacterBody2D
	)

	# ----------------------------------------------
	# REQUEST ONE SLOT IN GLOBAL QUOTA
	#
	# The Battle Controller increments its total
	# immediately when approval is granted.
	# This prevents other floors from using
	# the same remaining quota.
	# ----------------------------------------------

	if not battle_controller.try_register_spawn(self):

		enemy.free()
		return

	# ----------------------------------------------
	# APPLY FLOOR SCALE
	# ----------------------------------------------

	enemy.scale *= monster_scale_multiplier

	# ----------------------------------------------
	# POSITION BEFORE ENTERING TREE
	# ----------------------------------------------

	enemy.position = enemy_container.to_local(
		marker.global_position
		+ Vector2(
			0.0,
			spawn_height_offset
		)
	)

	enemy_container.add_child(enemy)

	# ----------------------------------------------
	# REGISTER ACTIVE SLOT
	# ----------------------------------------------

	occupied_enemies[slot_index] = enemy

	total_spawned_by_this_floor += 1

	_debug(
		"Spawned: "
		+ enemy.name
		+ " | Floor total: "
		+ str(total_spawned_by_this_floor)
		+ " | Global: "
		+ str(battle_controller.total_enemies_spawned)
		+ "/"
		+ str(battle_controller.target_monsters)
	)


# ==================================================
# DEBUG
# ==================================================

func _debug(message: String) -> void:

	if show_debug_messages:

		print(
			"[Level1EnemySpawner: ",
			name,
			"] ",
			message
		)
