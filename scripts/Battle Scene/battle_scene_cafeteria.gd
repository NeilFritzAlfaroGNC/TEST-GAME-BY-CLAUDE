
extends Control

const VICTORY_SCREEN_PATH: String = "res://scenes/UI/victory_screen.tscn"
const LEVEL_ID: String = "cafeteria_level_1"

@onready var food_items: Node2D = get_node_or_null(
	"FoodItems"
) as Node2D

var conveyor: AnimatedSprite2D = null
var main_character: Node2D = null
var enemy_spawn: Node = null

var dragged_food: Node2D = null
var drag_offset: Vector2 = Vector2.ZERO

var level_completion_started: bool = false


func _ready() -> void:
	call_deferred("_find_scene_references")


func _find_scene_references() -> void:
	# Find the player through the player group.
	var player_node := get_tree().get_first_node_in_group(
		"player"
	)

	main_character = player_node as Node2D

	if main_character == null:
		push_error(
			"[Battle] No Node2D player found in the 'player' group."
		)
	else:
		print("[Battle] Player found through group.")

	# Find the conveyor through the conveyor group.
	var conveyor_node := get_tree().get_first_node_in_group(
		"conveyor"
	)

	conveyor = conveyor_node as AnimatedSprite2D

	if conveyor == null:
		push_error(
			"[Battle] No AnimatedSprite2D found in the 'conveyor' group."
		)
	else:
		if not conveyor.is_playing():
			conveyor.play()

		print("[Battle] Conveyor found through group.")

	# Find EnemySpawn and connect its completion signal.
	enemy_spawn = get_node_or_null("EnemySpawn")

	if enemy_spawn == null:
		push_error("[Battle] EnemySpawn node was not found.")
	elif not enemy_spawn.has_signal("level_completed"):
		push_error(
			"[Battle] EnemySpawn is missing level_completed signal."
		)
	else:
		var completion_callback := Callable(
			self,
			"_on_level_completed"
		)

		if not enemy_spawn.is_connected(
			"level_completed",
			completion_callback
		):
			enemy_spawn.connect(
				"level_completed",
				completion_callback
			)

		print("[Battle] Enemy completion signal connected.")

	if food_items == null:
		push_error("[Battle] FoodItems not found.")


# ==================================================
# LEVEL COMPLETION
# ==================================================

func _on_level_completed() -> void:
	if level_completion_started:
		return

	level_completion_started = true

	print("[Battle] All five enemies defeated!")

	if not is_instance_valid(main_character):
		push_error("[Battle] Cannot calculate stars: Player is missing.")
		level_completion_started = false
		return

	# Read the number of hits received by the player.
	var total_hits: int = int(
		main_character.get("total_hits_received")
	)

	# Calculate stars for this attempt.
	var earned_stars: int = ProgressManager.calculate_stars(
		total_hits
	)

	# Store the current attempt's rating for the Victory screen.
	ProgressManager.current_run_stars = earned_stars

	print("[Battle] Total hits received: ", total_hits)
	print("[Battle] Stars earned this run: ", earned_stars)

	# Save the best rating without downgrading previous progress.
	ProgressManager.save_level_stars(
		ProgressManager.current_difficulty,
		LEVEL_ID,
		earned_stars
	)

	# Defer the scene transition until the physics callback finishes.
	call_deferred("_open_victory_screen")


func _open_victory_screen() -> void:
	print("[Battle] Opening Victory screen.")

	var error := get_tree().change_scene_to_file(
		VICTORY_SCREEN_PATH
	)

	if error != OK:
		push_error(
			"[Battle] Could not open Victory screen. Error: %s" % error
		)
		level_completion_started = false


# ==================================================
# FOOD DRAGGING
# ==================================================

func _input(event: InputEvent) -> void:
	if level_completion_started:
		return

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


func _start_dragging_food(mouse_position: Vector2) -> void:
	if is_instance_valid(dragged_food):
		return

	for node in get_tree().get_nodes_in_group("food"):
		if not is_instance_valid(node):
			continue

		if node is Area2D:
			continue

		if not node is Node2D:
			continue

		var food := node as Node2D

		if food.get_meta("is_held_for_attack", false):
			continue

		if not _is_mouse_over_food(food, mouse_position):
			continue

		dragged_food = food
		drag_offset = food.global_position - mouse_position

		food.set_meta("is_queued", false)
		food.set_meta("is_dropping", false)
		food.set_meta("drop_velocity_y", 0.0)

		if is_instance_valid(conveyor):
			if conveyor.has_method("set_dragged_food"):
				conveyor.set_dragged_food(food)

		print("[Battle] Dragging food: ", food.name)
		return


func _stop_dragging_food() -> void:
	if not is_instance_valid(dragged_food):
		dragged_food = null

		if is_instance_valid(conveyor):
			conveyor.set_dragged_food(null)

		return

	var food = dragged_food
	dragged_food = null

	food.set_meta("is_held_for_attack", true)

	if is_instance_valid(conveyor):
		conveyor.set_dragged_food(null)

	if not is_instance_valid(main_character):
		print("[Battle] Character missing.")
		_release_food_onto_belt(food)
		return

	var food_area := _get_food_area(food)

	if food_area == null:
		print("[Battle] Food Area2D not found.")
		_release_food_onto_belt(food)
		return

	await get_tree().physics_frame

	if not is_instance_valid(food):
		return

	if not is_instance_valid(food_area):
		_release_food_onto_belt(food)
		return

	if not is_instance_valid(main_character):
		_release_food_onto_belt(food)
		return

	if not main_character.has_method("is_food_in_range"):
		push_error(
			"[Battle] Player is missing is_food_in_range()."
		)
		_release_food_onto_belt(food)
		return

	if not main_character.is_food_in_range(food_area):
		print("[Battle] Food dropped outside character range.")
		_release_food_onto_belt(food)
		return

	if not main_character.has_method("can_accept_food"):
		_release_food_onto_belt(food)
		return

	if not main_character.can_accept_food(food_area):
		print("[Battle] Character rejected food.")
		_release_food_onto_belt(food)
		return

	print(
		"[Battle] Character accepted food: ",
		food.name,
		" at ",
		food.global_position
	)

	main_character.consume_food(food_area)


func _release_food_onto_belt(food: Node2D) -> void:
	if not is_instance_valid(food):
		return

	if not is_instance_valid(conveyor):
		push_error(
			"[Battle] Cannot return food: conveyor missing."
		)

		food.set_meta("is_held_for_attack", false)
		return

	if not conveyor.has_method("release_food_onto_belt"):
		push_error(
			"[Battle] release_food_onto_belt() missing."
		)

		food.set_meta("is_held_for_attack", false)
		return

	conveyor.release_food_onto_belt(food)


# ==================================================
# FOOD HELPERS
# ==================================================

func _is_mouse_over_food(
	food: Node2D,
	mouse_position: Vector2
) -> bool:
	var sprite := _get_food_sprite(food)

	if sprite != null and sprite.sprite_frames != null:
		var texture := sprite.sprite_frames.get_frame_texture(
			sprite.animation,
			sprite.frame
		)

		if texture != null:
			var local_mouse := sprite.to_local(mouse_position)

			var rect := Rect2(
				-texture.get_size() * 0.5,
				texture.get_size()
			)

			if rect.has_point(local_mouse):
				return true

	return food.global_position.distance_to(mouse_position) < 40.0


func _get_food_area(food: Node) -> Area2D:
	for child in food.get_children():
		if child is Area2D:
			return child as Area2D

	return food.find_child(
		"Area2D",
		true,
		false
	) as Area2D


func _get_food_sprite(food: Node) -> AnimatedSprite2D:
	if food is AnimatedSprite2D:
		return food as AnimatedSprite2D

	return food.find_child(
		"AnimatedSprite2D",
		true,
		false
	) as AnimatedSprite2D
