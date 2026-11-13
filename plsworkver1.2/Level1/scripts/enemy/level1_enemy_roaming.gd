extends CharacterBody2D
class_name Level1EnemyRoaming

enum CharacterState {
	STUDENT, STOPPED_AT_WALL, WAITING_TO_TRANSFORM, TRANSFORMING,
	MONSTER, DEFEAT_POOF, RETURNED_STUDENT, VANISHING
}

# ==================================================
# LEVEL 1 - ENEMY ROAMING CONTROLLER
# GODOT 4.7.1
# ==================================================
#
# FEATURES:
# - Random left/right starting direction
# - Horizontal roaming and optional gravity
# - Reverses when touching a wall
# - Independently adjustable movement speed
# - Independently adjustable monster scale
# - Walk animation
# - Automatic sprite flipping
#
# NO PLAYER CHASING
# NO PLAYER ATTACKING
#
# Intended for the new Level 1 floor system.
# ==================================================


# ==================================================
# MOVEMENT SETTINGS
# ==================================================

@export_group("Roaming Movement")

@export_range(0.0, 500.0, 1.0)
var movement_speed: float = 60.0

@export var random_starting_direction: bool = false

@export_enum("Left:-1", "Right:1")
var starting_direction: int = -1


@export_group("Gravity")

# The standalone Level 1 enemy scenes opt in. The original Soda stays horizontal.
@export var gravity_enabled: bool = false

@export_range(0.0, 5.0, 0.1)
var gravity_multiplier: float = 1.0

@export_range(50.0, 2000.0, 10.0)
var maximum_fall_speed: float = 900.0

@export_range(0.0, 20.0, 0.5)
var floor_snap_distance: float = 4.0

# ==================================================
# MONSTER APPEARANCE
# ==================================================

@export_group("Monster Appearance")

@export_range(0.1, 5.0, 0.05)
var monster_scale: float = 1.0

@export var sprite_faces_right_by_default: bool = true

@export var flip_sprite_when_turning: bool = true

@export var walk_animation: StringName = &"walk"

@export var sprite_path: NodePath = ^"AnimatedSprite2D"


# ==================================================
# COLLISION SETTINGS
# ==================================================

@export_group("Student Transformation")

@export var start_as_student: bool = false
@export var transform_on_wall_hit: bool = true
@export var student_sprite_path: NodePath = ^"StudentSprite"
@export var student_walk_animation: StringName = &"walk"
@export_range(0.0, 10.0, 0.1) var wall_stop_duration: float = 0.5
@export_range(0.1, 10.0, 0.1) var thought_duration: float = 2.0
@export var thought_text: String = "...."
@export var thought_bubble_offset: Vector2 = Vector2(0, -75)

@export_group("Defeat And Return")

@export var return_to_student_when_defeated: bool = true
@export var vanish_on_next_wall_hit: bool = true
@export var play_student_walk_after_return: bool = true

@export_group("Poof Animation")

@export var poof_sprite_path: NodePath = ^"PoofSprite"
@export var poof_animation: StringName = &"poof"

@export_group("Collision")

# Level 1 floors use physics layer 4,
# which has the bit value 8.
@export_flags_2d_physics
# Zero preserves the body mask and wall handling on legacy scenes.
var roaming_collision_mask: int = 0


# ==================================================
# DEBUG SETTINGS
# ==================================================

@export_group("Debug")

@export var show_debug_messages: bool = false


# ==================================================
# NODE REFERENCES
# ==================================================

@onready var sprite: AnimatedSprite2D = (
	get_node_or_null(sprite_path) as AnimatedSprite2D
)


# ==================================================
# INTERNAL STATE
# ==================================================

@onready var student_sprite := get_node_or_null(student_sprite_path) as AnimatedSprite2D
@onready var poof_sprite := get_node_or_null(poof_sprite_path) as AnimatedSprite2D

var character_state: CharacterState = CharacterState.MONSTER
var original_collision_layer: int
var thought_bubble: PanelContainer
var movement_direction: int = -1
var original_scale: Vector2 = Vector2.ONE
var gravity_strength: float = float(ProjectSettings.get_setting("physics/2d/default_gravity"))


# ==================================================
# INITIALIZATION
# ==================================================

func _ready() -> void:

	original_scale = scale

	scale = original_scale * monster_scale

	if roaming_collision_mask != 0:
		collision_mask = roaming_collision_mask

	if gravity_enabled:
		floor_snap_length = floor_snap_distance

	# Randomize initial roaming direction.
	if random_starting_direction:
		movement_direction = (
			-1 if randi_range(0, 1) == 0 else 1
		)
	else:
		movement_direction = (
			-1 if starting_direction < 0 else 1
		)

	velocity = Vector2.ZERO

	original_collision_layer = collision_layer
	if start_as_student and _has_animation(student_sprite, student_walk_animation):
		_begin_as_student()
	elif sprite == null:
		push_warning(
			"[Level1EnemyRoaming] "
			+ "AnimatedSprite2D not found."
		)
	else:
		if start_as_student:
			push_warning("Student walk animation missing. Starting as a monster.")
		_begin_as_monster()

	if show_debug_messages:
		print(
			"[Level1EnemyRoaming] Spawned: ",
			name,
			" | Direction: ",
			movement_direction,
			" | Speed: ",
			movement_speed
		)


# ==================================================
# PHYSICS MOVEMENT
# ==================================================

func _physics_process(delta: float) -> void:

	if movement_speed <= 0.0 and not gravity_enabled:
		velocity = Vector2.ZERO
		return

	var transforming := character_state in [
		CharacterState.STOPPED_AT_WALL,
		CharacterState.WAITING_TO_TRANSFORM,
		CharacterState.TRANSFORMING,
		CharacterState.DEFEAT_POOF,
		CharacterState.VANISHING
	]
	velocity.x = 0.0 if transforming else float(movement_direction) * movement_speed

	if gravity_enabled:
		velocity.y = minf(velocity.y + gravity_strength * gravity_multiplier * delta, maximum_fall_speed)
	else:
		velocity.y = 0.0

	move_and_slide()
	if transforming:
		return

	if roaming_collision_mask == 0:
		if is_on_wall():
			_handle_wall_collision()
		return

	# Reverse only on horizontal wall collisions.
	for index in range(get_slide_collision_count()):

		var collision: KinematicCollision2D = (
			get_slide_collision(index)
		)

		var normal: Vector2 = collision.get_normal()

		# Horizontal collision surface.
		if absf(normal.x) > 0.5:
			_handle_wall_collision()
			break


# ==================================================
# REVERSE DIRECTION
# ==================================================

func _reverse_direction() -> void:

	movement_direction *= -1

	_update_sprite_direction()

	if show_debug_messages:
		print(
			"[Level1EnemyRoaming] ",
			name,
			" reversed direction. New direction: ",
			movement_direction
		)


# ==================================================
# UPDATE SPRITE DIRECTION
# ==================================================

func _update_sprite_direction() -> void:

	if not flip_sprite_when_turning:
		return

	var should_flip := (movement_direction < 0) == sprite_faces_right_by_default
	if is_instance_valid(sprite):
		sprite.flip_h = should_flip
	if is_instance_valid(student_sprite):
		student_sprite.flip_h = should_flip


# ==================================================
# WALK ANIMATION
# ==================================================

func _play_walk_animation() -> void:

	if not is_instance_valid(sprite):
		return

	if sprite.sprite_frames == null:
		return

	if not sprite.sprite_frames.has_animation(
		walk_animation
	):
		push_warning(
			"[Level1EnemyRoaming] "
			+ "Walk animation not found: "
			+ String(walk_animation)
		)
		return

	sprite.play(walk_animation)


func _has_animation(animated_sprite: AnimatedSprite2D, animation: StringName) -> bool:
	return (
		is_instance_valid(animated_sprite)
		and animated_sprite.sprite_frames != null
		and animated_sprite.sprite_frames.has_animation(animation)
		and animated_sprite.sprite_frames.get_frame_count(animation) > 0
	)


func _begin_as_student(returning: bool = false) -> void:
	character_state = CharacterState.RETURNED_STUDENT if returning else CharacterState.STUDENT
	# The mask still detects floors, but food queries cannot see the student.
	collision_layer = 0
	sprite.hide()
	sprite.stop()
	if is_instance_valid(poof_sprite):
		poof_sprite.hide()
		poof_sprite.stop()
	student_sprite.show()
	if not returning or play_student_walk_after_return:
		student_sprite.play(student_walk_animation)
	_update_sprite_direction()


func _handle_wall_collision() -> void:
	if character_state == CharacterState.STUDENT and transform_on_wall_hit:
		_start_transformation()
	elif character_state == CharacterState.RETURNED_STUDENT and vanish_on_next_wall_hit:
		_vanish()
	else:
		_reverse_direction()


func _start_transformation() -> void:
	character_state = CharacterState.STOPPED_AT_WALL
	velocity.x = 0.0
	student_sprite.pause()
	if wall_stop_duration > 0.0:
		_start_transformation_timer(wall_stop_duration, _show_transformation_bubble)
	else:
		_show_transformation_bubble()


func _show_transformation_bubble() -> void:
	character_state = CharacterState.WAITING_TO_TRANSFORM
	_show_thought_bubble()
	_start_transformation_timer(thought_duration, _play_poof)


func _start_transformation_timer(duration: float, callback: Callable) -> void:
	# A child timer inherits the battle's processing state at victory.
	var timer := Timer.new()
	timer.one_shot = true
	add_child(timer)
	timer.timeout.connect(callback)
	timer.timeout.connect(timer.queue_free)
	timer.start(duration)


func _play_poof() -> void:
	thought_bubble.hide()
	thought_bubble.queue_free()
	character_state = CharacterState.TRANSFORMING
	student_sprite.hide()
	_play_poof_animation(_finish_transformation)


func _play_poof_animation(on_finished: Callable) -> void:
	if not _has_animation(poof_sprite, poof_animation):
		push_warning("Poof animation missing. Transforming immediately.")
		on_finished.call()
		return

	var frames := poof_sprite.sprite_frames.duplicate() as SpriteFrames
	frames.set_animation_loop(poof_animation, false)
	poof_sprite.sprite_frames = frames
	poof_sprite.show()
	poof_sprite.animation_finished.connect(on_finished, CONNECT_ONE_SHOT)
	poof_sprite.play(poof_animation)


func _finish_transformation() -> void:
	movement_direction *= -1
	_begin_as_monster()


func _begin_as_monster() -> void:
	character_state = CharacterState.MONSTER
	collision_layer = original_collision_layer
	if is_instance_valid(student_sprite):
		student_sprite.hide()
		student_sprite.stop()
	if is_instance_valid(poof_sprite):
		poof_sprite.hide()
		poof_sprite.stop()
	sprite.show()
	_update_sprite_direction()
	_play_walk_animation()


func _show_thought_bubble() -> void:
	thought_bubble = PanelContainer.new()
	thought_bubble.name = "ThoughtBubble"
	thought_bubble.z_index = 20
	thought_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.border_color = Color.BLACK
	style.set_border_width_all(2)
	style.set_corner_radius_all(9)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	thought_bubble.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = thought_text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", Color.BLACK)
	label.add_theme_font_size_override("font_size", 18)
	thought_bubble.add_child(label)
	add_child(thought_bubble)
	thought_bubble.position = thought_bubble_offset - Vector2(thought_bubble.get_combined_minimum_size().x * 0.5, 0)


func defeat_by_food() -> bool:
	if not can_receive_food() or is_queued_for_deletion():
		return false

	# Standalone monsters without a student form keep the original removal behavior.
	if not start_as_student or not is_instance_valid(student_sprite):
		_vanish()
		return true

	character_state = CharacterState.DEFEAT_POOF
	velocity.x = 0.0
	collision_layer = 0
	sprite.hide()
	sprite.stop()
	_play_poof_animation(_finish_defeat)
	return true


func _finish_defeat() -> void:
	if return_to_student_when_defeated:
		_begin_as_student(true)
	else:
		_vanish()


func _vanish() -> void:
	character_state = CharacterState.VANISHING
	collision_layer = 0
	hide()
	queue_free()


func can_receive_food() -> bool:
	return character_state == CharacterState.MONSTER


func is_transformed_monster() -> bool:
	return can_receive_food()
