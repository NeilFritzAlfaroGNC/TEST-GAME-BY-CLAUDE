
extends Marker2D

# ==================================================
# REUSABLE FOOD SPAWNER
# GODOT 4.7.1
# ==================================================
#
# Preserves:
# - Inspector-configured food scenes
# - Random food selection
# - Minimum and maximum spawn intervals
# - Maximum active food count
# - Original food spawning position
# - Conveyor queue metadata
# - Immediate first food spawn
#
# Adds:
# - start_spawning()
# - stop_spawning()
# - Spawn protection after battle shutdown
#
# Compatible with Cafeteria and Canteen.
# ==================================================


# ==================================================
# LEVEL FOOD SETTINGS
# ==================================================

@export_group("Level Food Settings")

@export var available_foods: Array[PackedScene] = []


# ==================================================
# SPAWN SETTINGS
# ==================================================

@export_group("Spawn Settings")

@export var min_spawn_time: float = 1.0
@export var max_spawn_time: float = 5.0

@export_range(1, 50, 1)
var max_food_count: int = 5


# ==================================================
# SCENE REFERENCES
# ==================================================

@export_group("Scene References")

@export var food_items_path: NodePath = ^"../FoodItems"


# ==================================================
# SPAWN STATE
# ==================================================

var spawn_timer: float = 0.0
var next_spawn_time: float = 1.0

var spawning_enabled: bool = true

var food_items: Node2D = null


# ==================================================
# INITIALIZATION
# ==================================================

func _ready() -> void:

	randomize()

	food_items = (
		get_node_or_null(food_items_path) as Node2D
	)

	if food_items == null:
		push_error(
			"[FoodSpawn] FoodItems node was not found. "
			+ "Check Food Items Path in the Inspector."
		)
		spawning_enabled = false
		set_process(false)
		return

	if _get_valid_food_scenes().is_empty():
		push_error(
			"[FoodSpawn] No valid foods selected! "
			+ "Add food scenes to Available Foods."
		)
		spawning_enabled = false
		set_process(false)
		return

	next_spawn_time = _get_next_spawn_interval()

	spawning_enabled = true
	set_process(true)

	# Preserve the immediate first food.
	spawn_food()


# ==================================================
# PROCESS SPAWN TIMER
# ==================================================

func _process(delta: float) -> void:

	if not spawning_enabled:
		return

	if not is_instance_valid(food_items):
		stop_spawning()
		return

	spawn_timer += delta

	if spawn_timer < next_spawn_time:
		return

	spawn_timer = 0.0
	next_spawn_time = _get_next_spawn_interval()

	if _get_active_food_count() >= max_food_count:
		return

	spawn_food()


# ==================================================
# START SPAWNING
# ==================================================

func start_spawning() -> void:

	if not is_instance_valid(food_items):
		push_warning(
			"[FoodSpawn] Cannot start. FoodItems missing."
		)
		return

	if _get_valid_food_scenes().is_empty():
		push_warning(
			"[FoodSpawn] Cannot start. No valid foods."
		)
		return

	if spawning_enabled:
		return

	spawning_enabled = true

	spawn_timer = 0.0
	next_spawn_time = _get_next_spawn_interval()

	set_process(true)


# ==================================================
# STOP SPAWNING
# ==================================================

func stop_spawning() -> void:

	spawning_enabled = false
	spawn_timer = 0.0

	set_process(false)


# ==================================================
# RANDOM SPAWN INTERVAL
# ==================================================

func _get_next_spawn_interval() -> float:

	var minimum: float = maxf(
		min_spawn_time,
		0.1
	)

	var maximum: float = maxf(
		max_spawn_time,
		minimum
	)

	return randf_range(
		minimum,
		maximum
	)


# ==================================================
# COUNT ACTIVE FOODS
# ==================================================

func _get_active_food_count() -> int:

	var count: int = 0

	for node in get_tree().get_nodes_in_group("level1_food"):

		if not is_instance_valid(node):
			continue

		# Count food roots, not child Area2D nodes.
		if node is Area2D:
			continue

		if node is Node2D:
			count += 1

	return count


# ==================================================
# SPAWN FOOD
# ==================================================

func spawn_food() -> void:

	if not spawning_enabled:
		return

	if not is_instance_valid(food_items):
		return

	if _get_active_food_count() >= max_food_count:
		print("[FoodSpawn] Food limit reached.")
		return

	var scene_to_spawn: PackedScene = (
		_get_random_food_scene()
	)

	if scene_to_spawn == null:
		push_error(
			"[FoodSpawn] The selected food scene "
			+ "is empty or invalid."
		)
		return

	var instance: Node = (
		scene_to_spawn.instantiate()
	)

	var food: Node2D = (
		instance as Node2D
	)

	if food == null:
		instance.free()
		push_error(
			"[FoodSpawn] Food scene root "
			+ "must inherit Node2D."
		)
		return

	food_items.add_child(food)
	food.global_position = global_position

	# ----------------------------------------------
	# PRESERVE CONVEYOR METADATA
	# ----------------------------------------------

	food.set_meta(
		"is_queued",
		false
	)

	food.set_meta(
		"is_dropping",
		false
	)

	food.set_meta(
		"drop_velocity_y",
		0.0
	)

	if not food.is_in_group("level1_food"):
		food.add_to_group("level1_food")

	food.visible = true

	print(
		"[FoodSpawn] Spawned: ",
		food.name
	)


# ==================================================
# VALID FOOD SCENES
# ==================================================

func _get_valid_food_scenes() -> Array[PackedScene]:

	var valid_foods: Array[PackedScene] = []

	for scene in available_foods:

		if scene != null:
			valid_foods.append(scene)

	return valid_foods


# ==================================================
# RANDOM FOOD SELECTION
# ==================================================

func _get_random_food_scene() -> PackedScene:

	var valid_foods: Array[PackedScene] = (
		_get_valid_food_scenes()
	)

	if valid_foods.is_empty():
		return null

	var index: int = randi_range(
		0,
		valid_foods.size() - 1
	)

	return valid_foods[index]
