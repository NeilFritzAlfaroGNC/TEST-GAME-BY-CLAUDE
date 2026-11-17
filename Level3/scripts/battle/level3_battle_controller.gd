# Level 3 battle controller. Independent copy of the preserved Cafeteria controller.
# Saves stars under scene3_level_3.


extends Control

# ==================================================
# BATTLE SCENE — CAFETERIA
# ==================================================
#
# ONE FOOD INSPECTOR FOR GO AND GROW.
#
# No GrowFoodInspector Autoload is required.
#
# PRESERVED:
# - Cafeteria Control root
# - FoodItems container
# - Player group reference
# - Conveyor group reference
# - EnemySpawn completion
# - Food dragging
# - Conveyor release behavior
# - Player food consumption
# - GO and GROW food combinations
# - ProgressManager stars
# - Victory scene transition
#
# INSPECTION:
# - Right-click food
# - Long-press food
# - Both GO and GROW use the same food_inspector.gd
# ==================================================


# ==================================================
# LEVEL SETTINGS
# ==================================================

const VICTORY_SCREEN_PATH: String = (
	"res://scenes/UI/victory_screen.tscn"
)

const LEVEL_ID: String = "scene3_level_3"

const LONG_PRESS_TIME: float = 0.5
const LONG_PRESS_MOVE_LIMIT: float = 12.0


# ==================================================
# INSPECTOR SETTINGS
# ==================================================

@export_group("Food Inspectors")

# Keep the existing food_inspector.gd assignment.
# Both GO and GROW use this one script.
@export var go_inspector_script: Script


# ==================================================
# SCENE REFERENCES
# ==================================================

@onready var food_items: Node2D = (
	get_node_or_null("FoodItems") as Node2D
)

var conveyor: AnimatedSprite2D = null
var main_character: Node2D = null
var enemy_spawn: Node = null


# ==================================================
# FOOD DRAGGING
# ==================================================

var dragged_food: Node2D = null
var drag_offset: Vector2 = Vector2.ZERO

var drag_start_position: Vector2 = Vector2.ZERO
var drag_start_mouse_position: Vector2 = Vector2.ZERO

var food_drop_in_progress: bool = false


# ==================================================
# LEVEL COMPLETION
# ==================================================

var level_completion_started: bool = false


# ==================================================
# SINGLE FOOD INSPECTOR
# ==================================================

var food_inspector: Node = null


# ==================================================
# LONG-PRESS TRACKING
# ==================================================

var long_press_active: bool = false
var long_press_timer: float = 0.0

var long_press_start_position: Vector2 = (
	Vector2.ZERO
)

var long_press_triggered: bool = false


# ==================================================
# INITIALIZATION
# ==================================================

func _ready() -> void:
	_create_food_inspector()

	call_deferred(
		"_find_scene_references"
	)

	set_process(true)
	set_process_input(true)

	print("")
	print("===================================")
	print("[Battle] Cafeteria ready.")
	print("[Battle] Single food inspector enabled.")
	print("[Battle] GO and GLOW inspection supported.")
	print("[Battle] GROW inspection supported.")
	print("[Battle] GO and GROW combinations supported.")
	print("===================================")


# ==================================================
# CREATE SINGLE FOOD INSPECTOR
# ==================================================

func _create_food_inspector() -> void:
	# Reuse a food inspector already present
	# in the cafeteria scene, if one exists.
	var existing_inspector: Node = (
		get_node_or_null("FoodInspector")
	)

	if existing_inspector != null:
		food_inspector = existing_inspector

		print(
			"[Battle] Existing FoodInspector node found."
		)

		return

	# Use the existing script assignment.
	if go_inspector_script == null:
		push_warning(
			"[Battle] Food Inspector Script is not assigned. "
			+ "Assign your existing food_inspector.gd "
			+ "to the GO Inspector Script property."
		)

		return

	var inspector_instance: Object = (
		go_inspector_script.new()
	)

	if not inspector_instance is Node:
		push_error(
			"[Battle] food_inspector.gd must extend "
			+ "a Node-based type."
		)

		return

	food_inspector = inspector_instance as Node

	food_inspector.name = "FoodInspector"

	add_child(food_inspector)

	print(
		"[Battle] Food inspector created successfully."
	)


# ==================================================
# PROCESS
# ==================================================

func _process(delta: float) -> void:
	if level_completion_started:
		return

	if not long_press_active:
		return

	if not is_instance_valid(dragged_food):
		long_press_active = false
		return

	long_press_timer += delta

	if long_press_timer >= LONG_PRESS_TIME:
		_trigger_long_press()


# ==================================================
# FIND SCENE REFERENCES
# ==================================================

func _find_scene_references() -> void:
	# ----------------------------------------------
	# PLAYER
	# ----------------------------------------------

	var player_node: Node = (
		get_tree().get_first_node_in_group(
			"player"
		)
	)

	main_character = player_node as Node2D

	if main_character == null:
		push_error(
			"[Battle] No Node2D player found "
			+ "in the 'player' group."
		)
	else:
		print(
			"[Battle] Player found through group."
		)

	# ----------------------------------------------
	# CONVEYOR
	# ----------------------------------------------

	var conveyor_node: Node = (
		get_tree().get_first_node_in_group(
			"conveyor"
		)
	)

	conveyor = conveyor_node as AnimatedSprite2D

	if conveyor == null:
		push_error(
			"[Battle] No AnimatedSprite2D found "
			+ "in the 'conveyor' group."
		)
	else:
		if not conveyor.is_playing():
			conveyor.play()

		print(
			"[Battle] Conveyor found through group."
		)

	# ----------------------------------------------
	# ENEMY SPAWNER
	# ----------------------------------------------

	enemy_spawn = get_node_or_null(
		"EnemySpawn"
	)

	if enemy_spawn == null:
		push_error(
			"[Battle] EnemySpawn node was not found."
		)

	elif not enemy_spawn.has_signal(
		"level_completed"
	):
		push_error(
			"[Battle] EnemySpawn is missing "
			+ "level_completed signal."
		)

	else:
		var completion_callback: Callable = Callable(
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

		print(
			"[Battle] Enemy completion signal connected."
		)

	# ----------------------------------------------
	# FOOD CONTAINER
	# ----------------------------------------------

	if food_items == null:
		push_error(
			"[Battle] FoodItems not found."
		)
	else:
		print(
			"[Battle] FoodItems found."
		)

	# The old GrowFoodInspector Autoload check
	# has intentionally been removed.


# ==================================================
# LEVEL COMPLETION
# ==================================================

func _on_level_completed() -> void:
	if level_completion_started:
		return

	level_completion_started = true

	long_press_active = false
	long_press_triggered = false

	_hide_food_inspector()

	print(
		"[Battle] All five enemies defeated!"
	)

	if not is_instance_valid(main_character):
		push_error(
			"[Battle] Cannot calculate stars: "
			+ "Player is missing."
		)

		level_completion_started = false
		return

	# ----------------------------------------------
	# PLAYER HITS
	# ----------------------------------------------

	var total_hits: int = int(
		main_character.get(
			"total_hits_received"
		)
	)

	# ----------------------------------------------
	# STAR CALCULATION
	# ----------------------------------------------

	var earned_stars: int = (
		ProgressManager.calculate_stars(
			total_hits
		)
	)

	# ----------------------------------------------
	# CURRENT RUN
	# ----------------------------------------------

	ProgressManager.current_run_stars = (
		earned_stars
	)

	print(
		"[Battle] Total hits received: ",
		total_hits
	)

	print(
		"[Battle] Stars earned this run: ",
		earned_stars
	)

	# ----------------------------------------------
	# SAVE BEST RATING
	# ----------------------------------------------

	ProgressManager.save_level_stars(
		ProgressManager.current_difficulty,
		LEVEL_ID,
		earned_stars
	)

	# ----------------------------------------------
	# OPEN VICTORY
	# ----------------------------------------------

	call_deferred(
		"_open_victory_screen"
	)


# ==================================================
# VICTORY SCREEN
# ==================================================

func _open_victory_screen() -> void:
	print(
		"[Battle] Opening Victory screen."
	)

	var scene_error: Error = (
		get_tree().change_scene_to_file(
			VICTORY_SCREEN_PATH
		)
	)

	if scene_error != OK:
		push_error(
			"[Battle] Could not open Victory screen. "
			+ "Error: "
			+ str(scene_error)
		)

		level_completion_started = false


# ==================================================
# INPUT HANDLING
# ==================================================

func _input(event: InputEvent) -> void:
	if level_completion_started:
		return

	if food_drop_in_progress:
		return

	# ----------------------------------------------
	# MOUSE BUTTONS
	# ----------------------------------------------

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = (
			event as InputEventMouseButton
		)

		# ------------------------------------------
		# RIGHT CLICK — INSPECT
		# ------------------------------------------

		if mouse_event.button_index == (
			MOUSE_BUTTON_RIGHT
		):
			if mouse_event.pressed:
				_inspect_food_under_mouse(mouse_event.position)

			return

		# ------------------------------------------
		# LEFT CLICK — DRAG
		# ------------------------------------------

		if mouse_event.button_index != (
			MOUSE_BUTTON_LEFT
		):
			return

		if mouse_event.pressed:
			if is_pointer_over_food_inspector(mouse_event.position):
				return
			_hide_food_inspector()

			long_press_triggered = false

			_start_dragging_food(
				get_global_mouse_position()
			)

			_begin_long_press_timer()

		else:
			_finish_left_button()

	# ----------------------------------------------
	# MOUSE MOTION
	# ----------------------------------------------

	elif event is InputEventMouseMotion:
		_check_long_press_movement()

		if is_instance_valid(dragged_food):
			dragged_food.global_position = (
				get_global_mouse_position()
				+ drag_offset
			)


# ==================================================
# START FOOD DRAGGING
# ==================================================

func _start_dragging_food(
	mouse_position: Vector2
) -> void:
	if is_instance_valid(dragged_food):
		return

	if food_drop_in_progress:
		return

	for food_node in get_tree().get_nodes_in_group(
		"food"
	):
		if not is_instance_valid(food_node):
			continue

		if food_node is Area2D:
			continue

		if not food_node is Node2D:
			continue

		var food: Node2D = (
			food_node as Node2D
		)

		if food.is_queued_for_deletion():
			continue

		if food.get_meta(
			"is_held_for_attack",
			false
		):
			continue

		if not _is_mouse_over_food(
			food,
			mouse_position
		):
			continue

		# ------------------------------------------
		# STORE DRAG STATE
		# ------------------------------------------

		dragged_food = food

		drag_offset = (
			food.global_position
			- mouse_position
		)

		drag_start_position = (
			food.global_position
		)

		drag_start_mouse_position = (
			get_viewport().get_mouse_position()
		)

		# ------------------------------------------
		# TEMPORARILY STOP CONVEYOR MOVEMENT
		# ------------------------------------------

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

		if is_instance_valid(conveyor):
			if conveyor.has_method(
				"set_dragged_food"
			):
				conveyor.set_dragged_food(
					food
				)

		print(
			"[Battle] Dragging food: ",
			food.name
		)

		return


# ==================================================
# FINISH LEFT CLICK
# ==================================================

func _finish_left_button() -> void:
	long_press_active = false

	# Releasing after a long press does not
	# consume or combine the inspected food.
	if long_press_triggered:
		long_press_triggered = false

		_cancel_drag_after_long_press()
		return

	_stop_dragging_food()


# ==================================================
# STOP DRAGGING FOOD
# ==================================================

func _stop_dragging_food() -> void:
	if not is_instance_valid(dragged_food):
		dragged_food = null

		if is_instance_valid(conveyor):
			if conveyor.has_method(
				"set_dragged_food"
			):
				conveyor.set_dragged_food(null)

		return

	var food: Node2D = dragged_food

	dragged_food = null

	food.set_meta(
		"is_held_for_attack",
		true
	)

	if is_instance_valid(conveyor):
		if conveyor.has_method(
			"set_dragged_food"
		):
			conveyor.set_dragged_food(null)

	# ----------------------------------------------
	# PLAYER CHECK
	# ----------------------------------------------

	if not is_instance_valid(main_character):
		print(
			"[Battle] Character missing."
		)

		_release_food_onto_belt(food)
		return

	# ----------------------------------------------
	# FOOD AREA2D
	# ----------------------------------------------

	var food_area: Area2D = (
		_get_food_area(food)
	)

	if food_area == null:
		print(
			"[Battle] Food Area2D not found."
		)

		_release_food_onto_belt(food)
		return

	# Wait for the latest physics overlap update.
	food_drop_in_progress = true

	await get_tree().physics_frame

	food_drop_in_progress = false

	if not is_instance_valid(food):
		return

	if not is_instance_valid(food_area):
		_release_food_onto_belt(food)
		return

	if not is_instance_valid(main_character):
		_release_food_onto_belt(food)
		return

	# ----------------------------------------------
	# CHARACTER FOOD RANGE
	# ----------------------------------------------

	if not main_character.has_method(
		"is_food_in_range"
	):
		push_error(
			"[Battle] Player is missing "
			+ "is_food_in_range()."
		)

		_release_food_onto_belt(food)
		return

	if not main_character.is_food_in_range(
		food_area
	):
		# ------------------------------------------
		# FOOD COMBINATION
		# ------------------------------------------

		var target_food: Node2D = (
			_find_food_at_position(
				food, get_global_mouse_position()
			)
		)

		if target_food != null:
			if FoodCombination.try_combine(
				food,
				target_food
			):
				print(
					"[Battle] Food combination successful."
				)

				return
		else:
			print(
				"[Battle] Food dropped outside "
				+ "character range."
			)

		_release_food_onto_belt(food)
		return

	# ----------------------------------------------
	# CHARACTER ACCEPTS FOOD
	# ----------------------------------------------

	if not main_character.has_method(
		"can_accept_food"
	):
		_release_food_onto_belt(food)
		return

	if not main_character.can_accept_food(
		food_area
	):
		print(
			"[Battle] Character rejected food."
		)

		_release_food_onto_belt(food)
		return

	if not main_character.has_method(
		"consume_food"
	):
		_release_food_onto_belt(food)
		return

	# ----------------------------------------------
	# CONSUME FOOD
	# ----------------------------------------------

	print(
		"[Battle] Character accepted food: ",
		food.name,
		" at ",
		food.global_position
	)

	main_character.consume_food(
		food_area
	)


# ==================================================
# RETURN FOOD TO CONVEYOR
# ==================================================

func _release_food_onto_belt(
	food: Node2D
) -> void:
	if not is_instance_valid(food):
		return

	if not is_instance_valid(conveyor):
		push_error(
			"[Battle] Cannot return food: "
			+ "conveyor missing."
		)

		food.set_meta(
			"is_held_for_attack",
			false
		)

		return

	if not conveyor.has_method(
		"release_food_onto_belt"
	):
		push_error(
			"[Battle] Conveyor missing "
			+ "release_food_onto_belt()."
		)

		food.set_meta(
			"is_held_for_attack",
			false
		)

		return

	conveyor.release_food_onto_belt(
		food
	)


# ==================================================
# RIGHT-CLICK FOOD INSPECTION
# ==================================================

func _inspect_food_under_mouse(screen_position: Vector2) -> void:
	# Do not open the inspector while dragging.
	if is_instance_valid(dragged_food):
		return

	var food: FoodData = (
		_find_food_at_position(null, get_canvas_transform().affine_inverse() * screen_position) as FoodData
	)

	if food == null:
		_hide_food_inspector()
		return

	# ----------------------------------------------
	# NUTRITION FOOD
	# ----------------------------------------------

	if not _is_inspectable_food(food):
		_hide_food_inspector()
		return

	_show_food_inspector(
		food,
		screen_position,
		false
	)


# ==================================================
# CHECK INSPECTABLE CATEGORIES
# ==================================================

func is_pointer_over_food_inspector(screen_position: Vector2) -> bool:
	return (
		is_instance_valid(food_inspector)
		and food_inspector.has_method("contains_screen_position")
		and food_inspector.contains_screen_position(screen_position)
	)


func _is_inspectable_food(food: FoodData) -> bool:
	return is_instance_valid(food) and food.has_level1_nutrition_category()


# ==================================================
# SHOW THE EXISTING FOOD INSPECTOR
# ==================================================

func _show_food_inspector(
	food: FoodData,
	screen_position: Vector2,
	pinned: bool = false
) -> void:
	if not is_instance_valid(food_inspector):
		push_warning(
			"[Battle] Food inspector is unavailable."
		)
		return

	if not _is_inspectable_food(food):
		return

	# ----------------------------------------------
	# EXISTING GO-STYLE INSPECTOR INTERFACE
	#
	# show_food(food, position, pinned)
	# ----------------------------------------------

	if food_inspector.has_method(
		"show_food"
	):
		if pinned:
			food_inspector.call(
				"show_food",
				food,
				screen_position,
				true
			)
		else:
			food_inspector.call(
				"show_food",
				food,
				screen_position
			)

		print(
			"[Battle] Inspecting food: ",
			food.food_name
		)

		return

	# ----------------------------------------------
	# ALTERNATE INSPECTOR INTERFACE
	#
	# open_inspector(food)
	# ----------------------------------------------

	if food_inspector.has_method(
		"open_inspector"
	):
		food_inspector.call(
			"open_inspector",
			food
		)

		print(
			"[Battle] Inspecting food: ",
			food.food_name
		)

		return

	push_warning(
		"[Battle] Food inspector has neither "
		+ "show_food() nor open_inspector()."
	)


# ==================================================
# HIDE THE EXISTING FOOD INSPECTOR
# ==================================================

func _hide_food_inspector() -> void:
	if not is_instance_valid(food_inspector):
		return

	# Preserve original inspector API.
	if food_inspector.has_method(
		"hide_inspector"
	):
		food_inspector.call(
			"hide_inspector"
		)

		return

	# Also support an inspector using
	# close_inspector() instead.
	if food_inspector.has_method(
		"close_inspector"
	):
		food_inspector.call(
			"close_inspector"
		)


# ==================================================
# BEGIN LONG-PRESS TIMER
# ==================================================

func _begin_long_press_timer() -> void:
	if not is_instance_valid(dragged_food):
		return

	long_press_active = true
	long_press_timer = 0.0

	long_press_start_position = (
		get_viewport().get_mouse_position()
	)


# ==================================================
# CHECK LONG-PRESS MOVEMENT
# ==================================================

func _check_long_press_movement() -> void:
	if (
		not long_press_active
		and not long_press_triggered
	):
		return

	var current_position: Vector2 = (
		get_viewport().get_mouse_position()
	)

	var moved_distance: float = (
		current_position.distance_to(
			long_press_start_position
		)
	)

	if moved_distance <= LONG_PRESS_MOVE_LIMIT:
		return

	long_press_active = false

	# Preserve the original behavior:
	# moving after inspection closes the panel
	# and lets the food continue being dragged.
	if long_press_triggered:
		long_press_triggered = false

		_hide_food_inspector()


# ==================================================
# TRIGGER LONG PRESS
# ==================================================

func _trigger_long_press() -> void:
	long_press_active = false

	var food: FoodData = (
		dragged_food as FoodData
	)

	if food == null:
		return

	# Both GO and GROW use the existing inspector.
	if not _is_inspectable_food(food):
		return

	if not is_instance_valid(food_inspector):
		return

	long_press_triggered = true

	_show_food_inspector(
		food,
		get_viewport().get_mouse_position(),
		true
	)

	print(
		"[Battle] Long press: inspecting ",
		food.food_name
	)


# ==================================================
# CANCEL DRAG AFTER LONG PRESS
# ==================================================

func _cancel_drag_after_long_press() -> void:
	var food: Node2D = dragged_food

	dragged_food = null

	long_press_active = false
	long_press_timer = 0.0

	if is_instance_valid(conveyor):
		if conveyor.has_method(
			"set_dragged_food"
		):
			conveyor.set_dragged_food(null)

	_hide_food_inspector()

	if is_instance_valid(food):
		food.global_position = (
			drag_start_position
		)

		_release_food_onto_belt(food)


# ==================================================
# FIND ANOTHER FOOD UNDER MOUSE
# ==================================================

func _find_food_at_position(dropped_food: Node2D, mouse_position: Vector2) -> Node2D:
	for food_node in get_tree().get_nodes_in_group(
		"food"
	):
		if not is_instance_valid(food_node):
			continue

		if food_node is Area2D:
			continue

		if not food_node is Node2D:
			continue

		var other_food: Node2D = (
			food_node as Node2D
		)

		if other_food == dropped_food:
			continue

		if other_food.is_queued_for_deletion():
			continue

		if other_food.get_meta(
			"is_held_for_attack",
			false
		):
			continue

		if _is_mouse_over_food(
			other_food,
			mouse_position
		):
			return other_food

	return null


# ==================================================
# FOOD SPRITE HIT DETECTION
# ==================================================

func _is_mouse_over_food(
	food: Node2D,
	mouse_position: Vector2
) -> bool:
	var sprite: AnimatedSprite2D = (
		_get_food_sprite(food)
	)

	if (
		sprite != null
		and sprite.sprite_frames != null
	):
		if sprite.sprite_frames.has_animation(
			sprite.animation
		):
			var frame_count: int = (
				sprite.sprite_frames.get_frame_count(
					sprite.animation
				)
			)

			if frame_count > 0:
				var frame_index: int = clampi(
					sprite.frame,
					0,
					frame_count - 1
				)

				var texture: Texture2D = (
					sprite.sprite_frames.get_frame_texture(
						sprite.animation,
						frame_index
					)
				)

				if texture != null:
					var local_mouse: Vector2 = (
						sprite.to_local(
							mouse_position
						)
					)

					var texture_size: Vector2 = (
						texture.get_size()
					)

					var top_left: Vector2 = (
						sprite.offset
					)

					if sprite.centered:
						top_left -= (
							texture_size * 0.5
						)

					var food_rect: Rect2 = Rect2(
						top_left,
						texture_size
					)

					if food_rect.has_point(
						local_mouse
					):
						return true

	# Preserve the original proximity fallback.
	return (
		food.global_position.distance_to(
			mouse_position
		) < 40.0
	)


# ==================================================
# GET FOOD AREA2D
# ==================================================

func _get_food_area(
	food: Node
) -> Area2D:
	for child in food.get_children():
		if child is Area2D:
			return child as Area2D

	return food.find_child(
		"Area2D",
		true,
		false
	) as Area2D


# ==================================================
# GET FOOD ANIMATEDSPRITE2D
# ==================================================

func _get_food_sprite(
	food: Node
) -> AnimatedSprite2D:
	if food is AnimatedSprite2D:
		return food as AnimatedSprite2D

	return food.find_child(
		"AnimatedSprite2D",
		true,
		false
	) as AnimatedSprite2D
