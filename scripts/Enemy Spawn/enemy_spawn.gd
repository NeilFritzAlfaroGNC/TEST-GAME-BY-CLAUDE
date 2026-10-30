
extends Marker2D

# --------------------------------------------------
# ENEMY SCENE
# --------------------------------------------------

const ENEMY_PATH: String = "res://scenes/Enemy/hamburger_enemy.tscn"

@export var enemy_scene: PackedScene


# --------------------------------------------------
# SPAWN SETTINGS
# --------------------------------------------------

@export var min_spawn_time: float = 1.0
@export var max_spawn_time: float = 5.0

# Maximum number of enemies allowed at the same time.
@export var max_enemy_count: int = 5


# --------------------------------------------------
# ENEMY CONTAINER
# --------------------------------------------------

# EnemySpawn and EnemyItems must be siblings.
@export var enemy_items_path: NodePath = ^"../EnemyItems"

var enemy_items: Node2D


# --------------------------------------------------
# INTERNAL VARIABLES
# --------------------------------------------------

var spawn_timer: float = 0.0
var next_spawn_time: float = 1.0


# --------------------------------------------------
# INITIALIZATION
# --------------------------------------------------

func _ready() -> void:
	randomize()

	# Find the EnemyItems container.
	enemy_items = get_node_or_null(
		enemy_items_path
	) as Node2D

	if enemy_items == null:
		push_error(
			"[EnemySpawn] EnemyItems node was not found. "
			+ "Check enemy_items_path."
		)
		set_process(false)
		return

	# Validate the spawn interval.
	if min_spawn_time < 0.1:
		min_spawn_time = 0.1

	if max_spawn_time < min_spawn_time:
		max_spawn_time = min_spawn_time

	# Choose the first spawning interval.
	next_spawn_time = randf_range(
		min_spawn_time,
		max_spawn_time
	)

	print("[EnemySpawn] Ready. EnemyItems found.")


# --------------------------------------------------
# SPAWN TIMER
# --------------------------------------------------

func _process(delta: float) -> void:
	spawn_timer += delta

	if spawn_timer < next_spawn_time:
		return

	# Reset the timer and select the next interval.
	spawn_timer = 0.0

	next_spawn_time = randf_range(
		min_spawn_time,
		max_spawn_time
	)

	# Do not exceed the enemy limit.
	if _get_active_enemy_count() >= max_enemy_count:
		return

	spawn_enemy()


# --------------------------------------------------
# GET ENEMY SCENE
# --------------------------------------------------

func _get_enemy_scene() -> PackedScene:
	if enemy_scene != null:
		return enemy_scene

	return load(ENEMY_PATH) as PackedScene


# --------------------------------------------------
# COUNT ACTIVE ENEMIES
# --------------------------------------------------

func _get_active_enemy_count() -> int:
	var count: int = 0

	if enemy_items == null:
		return count

	for child in enemy_items.get_children():
		if not is_instance_valid(child):
			continue

		if child.is_in_group("enemy"):
			count += 1

	return count


# --------------------------------------------------
# SPAWN ENEMY
# --------------------------------------------------

func spawn_enemy() -> void:
	if enemy_items == null:
		push_error(
			"[EnemySpawn] Cannot spawn: EnemyItems is missing."
		)
		return

	if _get_active_enemy_count() >= max_enemy_count:
		return

	var scene_to_spawn: PackedScene = _get_enemy_scene()

	if scene_to_spawn == null:
		push_error(
			"[EnemySpawn] Cannot load enemy scene: "
			+ ENEMY_PATH
		)
		return

	# Create the enemy instance.
	var instance: Node = scene_to_spawn.instantiate()

	# The enemy root must be CharacterBody2D.
	var enemy := instance as CharacterBody2D

	if enemy == null:
		instance.free()

		push_error(
			"[EnemySpawn] Enemy root must inherit CharacterBody2D."
		)
		return

	# Add the enemy to EnemyItems, not directly to the battle scene.
	enemy_items.add_child(enemy)

	# Spawn at the EnemySpawn marker's global position.
	enemy.global_position = global_position

	# Register the enemy for systems that search the enemy group.
	enemy.add_to_group("enemy")
	enemy.visible = true

	# Validate the enemy's AnimatedSprite2D.
	var sprite := enemy.get_node_or_null(
		"AnimatedSprite2D"
	) as AnimatedSprite2D

	if sprite == null:
		push_warning(
			"[EnemySpawn] Enemy has no direct AnimatedSprite2D child: "
			+ enemy.name
		)
	else:
		sprite.visible = true

		if sprite.sprite_frames == null:
			push_warning(
				"[EnemySpawn] Enemy SpriteFrames resource is missing: "
				+ enemy.name
			)

	print(
		"[EnemySpawn] Enemy spawned: ",
		enemy.name,
		" | Active enemies: ",
		_get_active_enemy_count()
	)
