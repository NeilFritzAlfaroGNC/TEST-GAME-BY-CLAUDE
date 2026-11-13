extends Node2D
class_name Level1FoodDragController

signal monster_fed
signal food_drop_missed

# ==================================================
# LEVEL 1 - FOOD DRAG AND MONSTER CONSUMPTION
# GODOT 4.7.1
# ==================================================
#
# FEATURES:
# - Drag food from the conveyor
# - Drop food directly onto roaming monsters
# - Stop a monster after a successful drop
# - Play the food's "eaten" animation once
# - Remove food and monster afterward
# - Return rejected food to the conveyor
#
# Uses Level1EnemyRoaming enemies.
# Does not require a main character.
#
# All behavior is exclusive to Level 1.
# ==================================================


# ==================================================
# INSPECTOR SETTINGS
# ==================================================

@export_group("Conveyor")

@export var conveyor_path: NodePath

@export_group("Food Settings")

@export var food_group: StringName = &"level1_food"

@export var eaten_animation: StringName = &"eaten"

@export_range(5.0, 100.0, 1.0)
var food_pickup_fallback_radius: float = 35.0

@export_group("Monster Detection")

@export_flags_2d_physics
var enemy_collision_mask: int = 2

@export_group("Consumption")

@export var stop_monster_during_eating: bool = true

@export var snap_food_to_monster: bool = true

@export_group("Debug")

@export var show_debug_messages: bool = false


# ==================================================
# REFERENCES
# ==================================================

var conveyor: Node = null


# ==================================================
# DRAG VARIABLES
# ==================================================

var dragged_food: AnimatedSprite2D = null

var drag_offset: Vector2 = Vector2.ZERO

var drag_start_position: Vector2 = Vector2.ZERO
var interactions_enabled: bool = true


# ==================================================
# INITIALIZATION
# ==================================================

func _ready() -> void:
	_find_conveyor()

	set_process_input(true)

	_debug("Food drag controller ready.")


# ==================================================
# FIND CONVEYOR
# ==================================================

func _find_conveyor() -> void:
	if not conveyor_path.is_empty():
		conveyor = get_node_or_null(conveyor_path)

	if not is_instance_valid(conveyor):
		conveyor = get_tree().get_first_node_in_group(
			"level1_conveyor"
		)

	if not is_instance_valid(conveyor):
		push_warning(
			"[Level1FoodDragController] "
			+ "Conveyor not found. "
			+ "Assign Conveyor Path in the Inspector."
		)


# ==================================================
# INPUT
# ==================================================

func set_interactions_enabled(enabled: bool) -> void:
	interactions_enabled = enabled
	if enabled:
		return

	var food := dragged_food
	dragged_food = null
	if is_instance_valid(conveyor) and conveyor.has_method("set_dragged_food"):
		conveyor.call("set_dragged_food", null)
	_return_food_to_conveyor(food)


func _input(event: InputEvent) -> void:
	if not interactions_enabled:
		return

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = (
			event as InputEventMouseButton
		)

		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return

		if mouse_event.pressed:
			_start_drag(get_canvas_transform().affine_inverse() * mouse_event.position)
		else:
			_finish_drag(get_canvas_transform().affine_inverse() * mouse_event.position)

	elif event is InputEventMouseMotion:
		_update_drag_position(get_canvas_transform().affine_inverse() * event.position)


# ==================================================
# START DRAG
# ==================================================

func _start_drag(mouse_position: Vector2) -> void:
	if is_instance_valid(dragged_food):
		return

	var selected_food: AnimatedSprite2D = (
		_find_food_at_position(mouse_position)
	)

	if not is_instance_valid(selected_food):
		return

	dragged_food = selected_food

	drag_start_position = selected_food.global_position

	drag_offset = (
		selected_food.global_position
		- mouse_position
	)

	# Stop conveyor handling while dragging.
	selected_food.set_meta(
		"is_held_for_attack",
		true
	)

	selected_food.set_meta(
		"is_queued",
		false
	)

	selected_food.set_meta(
		"is_dropping",
		false
	)

	if is_instance_valid(conveyor):
		if conveyor.has_method("set_dragged_food"):
			conveyor.call(
				"set_dragged_food",
				selected_food
			)

	_debug(
		"Dragging food: " + selected_food.name
	)


# ==================================================
# UPDATE FOOD POSITION
# ==================================================

func _update_drag_position(mouse_position: Vector2) -> void:
	if not is_instance_valid(dragged_food):
		return

	dragged_food.global_position = (
		mouse_position
		+ drag_offset
	)


# ==================================================
# FINISH DRAG
# ==================================================

func _finish_drag(drop_position: Vector2) -> void:
	if not is_instance_valid(dragged_food):
		dragged_food = null
		return

	_update_drag_position(drop_position)
	var food: AnimatedSprite2D = dragged_food

	dragged_food = null

	# Find a monster at the release position.
	var monster: Level1EnemyRoaming = (
		_find_monster_at_position(drop_position)
	)

	# Clear active conveyor drag reference.
	if is_instance_valid(conveyor):
		if conveyor.has_method("set_dragged_food"):
			conveyor.call(
				"set_dragged_food",
				null
			)

	# Valid monster found.
	if is_instance_valid(monster):
		if _can_consume_food(food, monster):
			_consume_food(food, monster)
			return

	# Invalid drop: return to conveyor.
	_return_food_to_conveyor(food)
	food_drop_missed.emit()


# ==================================================
# FIND FOOD UNDER MOUSE
# ==================================================

func _find_food_at_position(
	mouse_position: Vector2
) -> AnimatedSprite2D:

	var foods: Array[Node] = (
		get_tree().get_nodes_in_group(food_group)
	)

	for index in range(foods.size() - 1, -1, -1):
		var food: AnimatedSprite2D = (
			foods[index] as AnimatedSprite2D
		)

		if not is_instance_valid(food):
			continue

		if food.is_queued_for_deletion():
			continue

		if not food.is_visible_in_tree():
			continue

		if food.get_meta(
			"is_held_for_attack",
			false
		):
			continue

		if _is_point_over_food(
			food,
			mouse_position
		):
			return food

	return null


# ==================================================
# FOOD HIT TEST
# ==================================================

func _is_point_over_food(
	food: AnimatedSprite2D,
	mouse_position: Vector2
) -> bool:

	if food.sprite_frames != null and food.sprite_frames.has_animation(food.animation):
		var frame_texture: Texture2D = (
			food.sprite_frames.get_frame_texture(
				food.animation,
				food.frame
			)
		)

		if frame_texture != null:
			var local_point: Vector2 = (
				food.to_local(mouse_position)
			)

			var frame_size := frame_texture.get_size()
			var top_left := food.offset
			if food.centered:
				top_left -= frame_size * 0.5
			if Rect2(top_left, frame_size).has_point(local_point):
				return true

	# Fallback for small or missing sprite frames.
	return (
		food.global_position.distance_to(
			mouse_position
		)
		<= food_pickup_fallback_radius
	)


# ==================================================
# FIND MONSTER UNDER DROP POSITION
# ==================================================

func _find_monster_at_position(
	drop_position: Vector2
) -> Level1EnemyRoaming:

	var query: PhysicsPointQueryParameters2D = (
		PhysicsPointQueryParameters2D.new()
	)

	query.position = drop_position

	query.collision_mask = enemy_collision_mask

	query.collide_with_bodies = true
	query.collide_with_areas = false

	var results: Array[Dictionary] = (
		get_world_2d().direct_space_state.intersect_point(
			query,
			64
		)
	)

	for result in results:
		var collider: Object = result.get(
			"collider"
		)

		if not collider is Node:
			continue

		var current_node: Node = collider as Node

		# Find the Level 1 roaming enemy root.
		while current_node != null:
			if current_node is Level1EnemyRoaming:
				var monster: Level1EnemyRoaming = (
					current_node as Level1EnemyRoaming
				)

				if not monster.is_queued_for_deletion() and monster.can_receive_food():
					if not monster.get_meta(
						"level1_being_consumed",
						false
					):
						return monster

			current_node = current_node.get_parent()

	return null


# ==================================================
# VALIDATE CONSUMPTION
# ==================================================

func _can_consume_food(
	food: AnimatedSprite2D,
	monster: Level1EnemyRoaming
) -> bool:

	if not is_instance_valid(food):
		return false

	if not is_instance_valid(monster):
		return false

	if monster.is_queued_for_deletion() or not monster.can_receive_food():
		return false

	if monster.get_meta(
		"level1_being_consumed",
		false
	):
		return false

	if food.sprite_frames == null:
		return false

	if not food.sprite_frames.has_animation(
		eaten_animation
	):
		push_warning(
			"[Level1FoodDragController] "
			+ food.name
			+ " has no eaten animation."
		)

		return false

	if food.sprite_frames.get_frame_count(
		eaten_animation
	) <= 0:
		return false

	return true


# ==================================================
# CONSUME FOOD
# ==================================================

func _consume_food(
	food: AnimatedSprite2D,
	monster: Level1EnemyRoaming
) -> void:

	if not _can_consume_food(food, monster):
		_return_food_to_conveyor(food)
		food_drop_missed.emit()
		return

	# Prevent two foods from consuming
	# the same monster simultaneously.
	monster.set_meta(
		"level1_being_consumed",
		true
	)

	food.set_meta(
		"is_held_for_attack",
		true
	)

	_debug(
		"Monster consuming: "
		+ monster.name
		+ " | Food: "
		+ food.name
	)

	# Pause horizontal movement while leaving gravity active.
	var previous_movement_speed := monster.movement_speed
	if stop_monster_during_eating:
		monster.movement_speed = 0.0
		monster.velocity.x = 0.0

		if is_instance_valid(monster.sprite):
			monster.sprite.pause()

	# Place food over the monster.
	if snap_food_to_monster:
		food.global_position = (
			monster.global_position
		)

	# Display food in front of the monster.
	food.z_index = 10

	# Duplicate frames before changing looping.
	# This prevents other food instances from
	# having their animation settings changed.
	var unique_frames: SpriteFrames = (
		food.sprite_frames.duplicate(true) as SpriteFrames
	)

	food.sprite_frames = unique_frames

	# The eaten animation must finish once.
	unique_frames.set_animation_loop(
		eaten_animation,
		false
	)

	food.stop()
	food.play(eaten_animation)

	_debug("Playing eaten animation.")

	# Wait until the animation has completed.
	await food.animation_finished

	# Remove the consumed food.
	if is_instance_valid(food):
		if not food.is_queued_for_deletion():
			food.queue_free()

	if not is_instance_valid(monster) or monster.is_queued_for_deletion():
		return

	if stop_monster_during_eating:
		monster.movement_speed = previous_movement_speed

	if monster.defeat_by_food():
		# Do not count the rescue (or freeze for Victory) until the poof ends.
		# Missing-effect/legacy scenes finish synchronously and need no wait.
		if monster.character_state == Level1EnemyRoaming.CharacterState.DEFEAT_POOF:
			await monster.rescue_finished
		monster_fed.emit()
		_debug("Food consumed. Monster defeated.")
	else:
		monster.set_meta("level1_being_consumed", false)
		if is_instance_valid(monster.sprite) and monster.can_receive_food():
			monster.sprite.play()


# ==================================================
# RETURN REJECTED FOOD
# ==================================================

func _return_food_to_conveyor(
	food: AnimatedSprite2D
) -> void:

	if not is_instance_valid(food):
		return

	food.set_meta(
		"is_held_for_attack",
		false
	)

	if is_instance_valid(conveyor):
		if conveyor.has_method(
			"release_food_onto_belt"
		):
			conveyor.call(
				"release_food_onto_belt",
				food
			)

			_debug("Food returned to conveyor.")
			return

	# Fallback if the conveyor does not
	# provide a return method.
	food.global_position = drag_start_position

	_debug("Food restored to original position.")


# ==================================================
# DEBUG
# ==================================================

func _debug(message: String) -> void:
	if show_debug_messages:
		print(
			"[Level1FoodDrag] ",
			message
		)
