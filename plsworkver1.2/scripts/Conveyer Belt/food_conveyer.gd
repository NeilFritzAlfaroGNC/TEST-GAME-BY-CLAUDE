extends AnimatedSprite2D

@export var food_speed: float = 100.0
@export var queue_spacing: float = 80.0
@export var queue_right_margin: float = 80.0
@export var belt_surface_offset: float = 0.0
@export var drop_gravity: float = 900.0

var food_spawn: Marker2D = null
var dragged_food: Node2D = null


func _ready() -> void:
	add_to_group("conveyor")

	play()

	food_spawn = get_parent().get_node_or_null(
		"FoodSpawn"
	) as Marker2D

	if food_spawn == null:
		push_warning(
			"[FoodConveyor] FoodSpawn node not found. "
			+ "The belt position will be used instead."
		)


func set_dragged_food(food: Node2D) -> void:
	dragged_food = food


func release_food_onto_belt(food: Node2D) -> void:
	if not is_instance_valid(food):
		return

	food.set_meta("is_held_for_attack", false)

	var surface_y: float = _get_belt_surface_y()

	if food.global_position.y < surface_y:
		food.set_meta("is_dropping", true)
		food.set_meta("drop_velocity_y", 0.0)
		food.set_meta("is_queued", false)
	else:
		food.global_position.y = surface_y
		food.set_meta("is_dropping", false)
		food.set_meta("drop_velocity_y", 0.0)
		food.set_meta("is_queued", false)


func _get_active_foods() -> Array[Node2D]:
	var foods: Array[Node2D] = []

	for node in get_tree().get_nodes_in_group("food"):
		if not is_instance_valid(node):
			continue

		if node is Area2D:
			continue

		if node is Node2D:
			foods.append(node as Node2D)

	return foods


func _is_locked(food: Node2D) -> bool:
	if not is_instance_valid(food):
		return true

	return food.get_meta("is_held_for_attack", false)


func _get_belt_surface_y() -> float:
	return global_position.y + belt_surface_offset


func _get_queue_right_x() -> float:
	return (
		get_viewport().get_visible_rect().size.x
		- queue_right_margin
	)


func _get_queued_foods() -> Array[Node2D]:
	var queued: Array[Node2D] = []

	for food in _get_active_foods():
		if not is_instance_valid(food):
			continue

		if _is_locked(food):
			continue

		if food.get_meta("is_queued", false):
			if food != dragged_food:
				queued.append(food)

	queued.sort_custom(
		func(a: Node2D, b: Node2D) -> bool:
			return a.global_position.x > b.global_position.x
	)

	return queued


func _process(delta: float) -> void:
	_move_food(delta)


func _move_food(delta: float) -> void:
	var surface_y: float = _get_belt_surface_y()
	var right_x: float = _get_queue_right_x()
	var foods: Array[Node2D] = _get_active_foods()

	# Update falling food.
	for food in foods:
		if not is_instance_valid(food):
			continue

		if food == dragged_food or _is_locked(food):
			continue

		if food.get_meta("is_dropping", false):
			var fall_velocity: float = float(
				food.get_meta("drop_velocity_y", 0.0)
			)

			fall_velocity += drop_gravity * delta
			food.global_position.y += fall_velocity * delta

			food.set_meta("drop_velocity_y", fall_velocity)

			if food.global_position.y >= surface_y:
				food.global_position.y = surface_y
				food.set_meta("is_dropping", false)
				food.set_meta("drop_velocity_y", 0.0)
				food.set_meta("is_queued", false)

			continue

	# Keep queued food aligned and close gaps.
	var queued: Array[Node2D] = _get_queued_foods()

	for i in range(queued.size()):
		var food: Node2D = queued[i]

		if not is_instance_valid(food) or _is_locked(food):
			continue

		var target_x: float = right_x - (i * queue_spacing)

		food.global_position.y = surface_y
		food.global_position.x = move_toward(
			food.global_position.x,
			target_x,
			food_speed * delta
		)

	# Move incoming food toward the next queue slot.
	var moving_foods: Array[Node2D] = []

	for food in _get_active_foods():
		if not is_instance_valid(food):
			continue

		if food == dragged_food or _is_locked(food):
			continue

		if food.get_meta("is_dropping", false):
			continue

		if food.get_meta("is_queued", false):
			continue

		moving_foods.append(food)

	moving_foods.sort_custom(
		func(a: Node2D, b: Node2D) -> bool:
			return a.global_position.x < b.global_position.x
	)

	for food in moving_foods:
		if not is_instance_valid(food):
			continue

		queued = _get_queued_foods()

		var slot_x: float = (
			right_x - (queued.size() * queue_spacing)
		)

		food.global_position.y = surface_y
		food.global_position.x += food_speed * delta

		if food.global_position.x >= slot_x:
			food.global_position.x = slot_x
			food.set_meta("is_queued", true)
