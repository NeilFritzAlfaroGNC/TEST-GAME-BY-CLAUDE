
extends Control

# --------------------------------------------------
# NODE REFERENCES
# --------------------------------------------------

@onready var conveyor: AnimatedSprite2D = get_node_or_null(
	"Conveyer Belt"
) as AnimatedSprite2D

@onready var main_character: Node2D = get_node_or_null(
	"main_character"
) as Node2D

@onready var food_items: Node2D = get_node_or_null(
	"FoodItems"
) as Node2D

var dragged_food: Node2D = null
var drag_offset: Vector2 = Vector2.ZERO


# --------------------------------------------------
# INITIALIZATION
# --------------------------------------------------

func _ready() -> void:
	if conveyor != null:
		# The belt's own script also calls play().
		# Calling it here is harmless and keeps the belt animated.
		if not conveyor.is_playing():
			conveyor.play()
	else:
		push_error(
			"[Battle] Conveyer Belt node not found. "
			+ "Check its exact name and scene-tree location."
		)

	if food_items == null:
		push_error("[Battle] FoodItems node not found.")

	if main_character == null:
		push_error("[Battle] main_character node not found.")
	else:
		print("[Battle] main_character found.")

	if is_instance_valid(conveyor):
		if not conveyor.has_method("set_dragged_food"):
			push_error(
				"[Battle] Conveyer Belt is missing "
				+ "set_dragged_food(). Check food_conveyer.gd."
			)

		if not conveyor.has_method("release_food_onto_belt"):
			push_error(
				"[Battle] Conveyer Belt is missing "
				+ "release_food_onto_belt(). Check food_conveyer.gd."
			)


# --------------------------------------------------
# INPUT: DRAG AND DROP
# --------------------------------------------------

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton

		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return

		if mouse_event.pressed:
			_start_dragging_food(get_global_mouse_position())
		else:
			_stop_dragging_food()

	elif event is InputEventMouseMotion:
		if is_instance_valid(dragged_food):
			dragged_food.global_position = (
				get_global_mouse_position() + drag_offset
			)


# --------------------------------------------------
# START DRAGGING FOOD
# --------------------------------------------------

func _start_dragging_food(mouse_position: Vector2) -> void:
	# Do not allow another food interaction while the character
	# is already processing food.
	if is_instance_valid(main_character):
		if main_character.get("is_processing_food") == true:
			return

	if is_instance_valid(dragged_food):
		return

	for node in get_tree().get_nodes_in_group("food"):
		if not is_instance_valid(node):
			continue

		# Only inspect food root nodes.
		if node is Area2D:
			continue

		var food: Node2D = node as Node2D

		if food == null:
			continue

		if not _is_mouse_over_food(food, mouse_position):
			continue

		dragged_food = food
		drag_offset = food.global_position - mouse_position

		# Remove the food from its queue while being dragged.
		food.set_meta("is_queued", false)
		food.set_meta("is_dropping", false)
		food.set_meta("drop_velocity_y", 0.0)

		if is_instance_valid(conveyor):
			if conveyor.has_method("set_dragged_food"):
				conveyor.set_dragged_food(food)

		print("[Battle] Dragging food: ", food.name)
		return


# --------------------------------------------------
# STOP DRAGGING AND PROCESS FOOD
# --------------------------------------------------

func _stop_dragging_food() -> void:
	if not is_instance_valid(dragged_food):
		dragged_food = null

		if is_instance_valid(conveyor):
			if conveyor.has_method("set_dragged_food"):
				conveyor.set_dragged_food(null)

		return

	var food: Node2D = dragged_food
	dragged_food = null

	# Tell the belt that the food is no longer being dragged.
	if is_instance_valid(conveyor):
		if conveyor.has_method("set_dragged_food"):
			conveyor.set_dragged_food(null)

	if not is_instance_valid(main_character):
		push_error("[Battle] Cannot process food: character is missing.")
		_release_food_onto_belt(food)
		return

	var food_area: Area2D = _get_food_area(food)

	if food_area == null:
		push_error("[Battle] Food has no Area2D child.")
		_release_food_onto_belt(food)
		return

	if not main_character.has_method("can_accept_food"):
		push_error(
			"[Battle] main_char.gd has no can_accept_food() method."
		)
		_release_food_onto_belt(food)
		return

	if not main_character.can_accept_food(food_area):
		print("[Battle] Character did not accept food.")
		_release_food_onto_belt(food)
		return

	if not main_character.has_method("consume_food"):
		push_error(
			"[Battle] main_char.gd has no consume_food() method."
		)
		_release_food_onto_belt(food)
		return

	print("[Battle] Character accepted food: ", food.name)

	# Preserve the existing character food-consumption behavior.
	main_character.consume_food(food_area)


# --------------------------------------------------
# RELEASE FOOD BACK ONTO THE BELT
# --------------------------------------------------

func _release_food_onto_belt(food: Node2D) -> void:
	if not is_instance_valid(food):
		return

	if not is_instance_valid(conveyor):
		push_error(
			"[Battle] Cannot release food: Conveyer Belt is missing."
		)
		return

	if not conveyor.has_method("release_food_onto_belt"):
		push_error(
			"[Battle] Cannot release food: "
			+ "release_food_onto_belt() is missing."
		)
		return

	conveyor.release_food_onto_belt(food)


# --------------------------------------------------
# FOOD HIT DETECTION
# --------------------------------------------------

func _is_mouse_over_food(
	food: Node2D,
	mouse_position: Vector2
) -> bool:
	var sprite: AnimatedSprite2D = _get_food_sprite(food)

	if sprite != null and sprite.sprite_frames != null:
		var texture: Texture2D = sprite.sprite_frames.get_frame_texture(
			sprite.animation,
			sprite.frame
		)

		if texture != null:
			var local_mouse: Vector2 = sprite.to_local(mouse_position)

			var rect: Rect2 = Rect2(
				-texture.get_size() * 0.5,
				texture.get_size()
			)

			if rect.has_point(local_mouse):
				return true

	# Fallback hit detection if the food has no usable sprite texture.
	return food.global_position.distance_to(mouse_position) < 40.0


# --------------------------------------------------
# FIND FOOD AREA
# --------------------------------------------------

func _get_food_area(food: Node) -> Area2D:
	# Check direct children first.
	for child in food.get_children():
		if child is Area2D:
			return child as Area2D

	# Then search descendants.
	return food.find_child(
		"Area2D",
		true,
		false
	) as Area2D


# --------------------------------------------------
# FIND FOOD SPRITE
# --------------------------------------------------

func _get_food_sprite(food: Node) -> AnimatedSprite2D:
	if food is AnimatedSprite2D:
		return food as AnimatedSprite2D

	return food.find_child(
		"AnimatedSprite2D",
		true,
		false
	) as AnimatedSprite2D
