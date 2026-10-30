
extends Marker2D

# Add any food scenes you want to spawn in this list
# through the Godot Inspector.
@export_group("Level Food Settings")
@export var available_foods: Array[PackedScene] = []

@export_group("Spawn Settings")
@export var min_spawn_time: float = 1.0
@export var max_spawn_time: float = 5.0
@export_range(1, 50, 1) var max_food_count: int = 5

@export_group("Scene References")
@export var food_items_path: NodePath = ^"../FoodItems"

var spawn_timer: float = 0.0
var next_spawn_time: float = 1.0

var food_items: Node2D


func _ready() -> void:
	randomize()

	food_items = get_node_or_null(food_items_path) as Node2D

	if food_items == null:
		push_error(
			"[FoodSpawn] FoodItems node was not found. "
			+ "Check Food Items Path in the Inspector."
		)
		set_process(false)
		return

	if available_foods.is_empty():
		push_error(
			"[FoodSpawn] No foods selected! "
			+ "Add food scenes to Available Foods in the Inspector."
		)
		set_process(false)
		return

	next_spawn_time = randf_range(
		min_spawn_time,
		max_spawn_time
	)

	# Spawn the first food immediately.
	spawn_food()


func _process(delta: float) -> void:
	spawn_timer += delta

	if spawn_timer < next_spawn_time:
		return

	spawn_timer = 0.0

	next_spawn_time = randf_range(
		min_spawn_time,
		max_spawn_time
	)

	if _get_active_food_count() >= max_food_count:
		return

	spawn_food()


func _get_active_food_count() -> int:
	var count: int = 0

	for node in get_tree().get_nodes_in_group("food"):
		if not is_instance_valid(node):
			continue

		# Count food roots, not child Area2D nodes.
		if node is Area2D:
			continue

		if node is Node2D:
			count += 1

	return count


func spawn_food() -> void:
	if _get_active_food_count() >= max_food_count:
		print("[FoodSpawn] Food limit reached.")
		return

	# Select a random scene from the Inspector list.
	var scene_to_spawn: PackedScene = _get_random_food_scene()

	if scene_to_spawn == null:
		push_error(
			"[FoodSpawn] The selected food scene is empty or invalid."
		)
		return

	var instance: Node = scene_to_spawn.instantiate()
	var food := instance as Node2D

	if food == null:
		instance.free()
		push_error(
			"[FoodSpawn] Food scene root must inherit Node2D."
		)
		return

	food_items.add_child(food)
	food.global_position = global_position

	# Preserve conveyor queue metadata.
	food.set_meta("is_queued", false)
	food.set_meta("is_dropping", false)
	food.set_meta("drop_velocity_y", 0.0)

	food.add_to_group("food")
	food.visible = true

	print("[FoodSpawn] Spawned: ", food.name)


func _get_random_food_scene() -> PackedScene:
	var valid_foods: Array[PackedScene] = []

	for scene in available_foods:
		if scene != null:
			valid_foods.append(scene)

	if valid_foods.is_empty():
		return null

	return valid_foods[randi_range(0, valid_foods.size() - 1)]
