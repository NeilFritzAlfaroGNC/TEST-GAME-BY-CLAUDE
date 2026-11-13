extends CharacterBody2D
class_name Level3NutritionMonster

# ==================================================
# FOOD HEROES - LEVEL 3 NUTRITION MONSTER
# GODOT 4.7.1
#
# GRAVITY-BASED MONSTER
#
# - Uses CharacterBody2D and CollisionShape2D
# - Falls onto platforms
# - Walks left using move_and_slide()
# - Can be selected by clicking or tapping
# - Contains independent GO/GLOW/GROW nutrition
# - Full bars permanently lock at 100%
# - All three full = cured
# - No attacks or projectiles
# ==================================================

signal selected(monster: Level3NutritionMonster)
signal nutrition_changed(monster: Level3NutritionMonster)
signal cured(monster: Level3NutritionMonster)


# ==================================================
# LEVEL 3 - GRAVITY AND MOVEMENT
# EDIT THESE SETTINGS IN INSPECTOR
# ==================================================

@export_group("Level 3 - Gravity Movement")

@export var enable_gravity: bool = true

@export_range(0.0, 3000.0, 10.0)
var gravity_strength: float = 980.0

@export_range(0.0, 300.0, 1.0)
var movement_speed: float = 30.0

@export var move_left: bool = true

@export var move_only_when_on_floor: bool = false

@export_range(0.0, 32.0, 1.0)
var floor_snap_distance: float = 6.0


# ==================================================
# LEVEL 3 - COLLISION SETTINGS
# ==================================================

@export_group("Level 3 - Collision")

# Monster occupies physics Layer 2.
@export_flags_2d_physics
var monster_collision_layer: int = 2

# Floors and walls occupy physics Layer 4.
@export_flags_2d_physics
var environment_collision_mask: int = 8


# ==================================================
# LEVEL 3 - STARTING NUTRITION
# ==================================================

@export_group("Level 3 - Starting Nutrition")

@export_range(0.0, 100.0, 1.0)
var starting_go: float = 40.0

@export_range(0.0, 100.0, 1.0)
var starting_glow: float = 40.0

@export_range(0.0, 100.0, 1.0)
var starting_grow: float = 40.0


# ==================================================
# LEVEL 3 - NUTRITION DEPLETION
# ==================================================

@export_group("Level 3 - Nutrition Decay")

@export_range(0.0, 20.0, 0.1)
var nutrition_decay_per_second: float = 1.0


# ==================================================
# LEVEL 3 - FOOD RESTORATION
# ==================================================

@export_group("Level 3 - Food Restoration")

@export_range(1.0, 100.0, 1.0)
var nutrition_gain_per_food: float = 25.0


# ==================================================
# RUNTIME NUTRITION
# ==================================================

var go: float = 0.0
var glow: float = 0.0
var grow: float = 0.0

var go_locked: bool = false
var glow_locked: bool = false
var grow_locked: bool = false

var is_cured: bool = false
var is_active: bool = true


# ==================================================
# INITIALIZATION
# ==================================================

func _ready() -> void:

	motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED

	collision_layer = monster_collision_layer
	collision_mask = environment_collision_mask

	floor_snap_length = floor_snap_distance
	input_pickable = true

	go = clampf(starting_go, 0.0, 100.0)
	glow = clampf(starting_glow, 0.0, 100.0)
	grow = clampf(starting_grow, 0.0, 100.0)

	go_locked = go >= 100.0
	glow_locked = glow >= 100.0
	grow_locked = grow >= 100.0

	if not input_event.is_connected(_on_input_event):
		input_event.connect(_on_input_event)

	nutrition_changed.emit(self)
	_check_cure()


# ==================================================
# GRAVITY-BASED PHYSICS
# ==================================================

func _physics_process(delta: float) -> void:

	if not is_active:
		velocity = Vector2.ZERO
		return

	# ----------------------------------------------
	# GRAVITY
	#
	# Unlike Area2D, CharacterBody2D has
	# collision-aware movement.
	# ----------------------------------------------

	if enable_gravity:

		if not is_on_floor():
			velocity.y += gravity_strength * delta
		else:
			if velocity.y > 0.0:
				velocity.y = 0.0

	else:
		velocity.y = 0.0

	# ----------------------------------------------
	# HORIZONTAL WALKING
	# ----------------------------------------------

	var can_walk: bool = true

	if move_only_when_on_floor:
		can_walk = is_on_floor()

	if can_walk:

		if move_left:
			velocity.x = -movement_speed
		else:
			velocity.x = movement_speed

	else:
		velocity.x = 0.0

	# ----------------------------------------------
	# PHYSICAL MOVEMENT
	#
	# This handles collisions with platforms,
	# floors and walls.
	# ----------------------------------------------

	move_and_slide()

	# ----------------------------------------------
	# NUTRITION DEPLETION
	# ----------------------------------------------

	_update_nutrition(delta)


# ==================================================
# NUTRITION DEPLETION
# ==================================================

func _update_nutrition(delta: float) -> void:

	var decay: float = (
		nutrition_decay_per_second * delta
	)

	# Once full, a bar never decreases again.

	if not go_locked:
		go = maxf(0.0, go - decay)

	if not glow_locked:
		glow = maxf(0.0, glow - decay)

	if not grow_locked:
		grow = maxf(0.0, grow - decay)

	nutrition_changed.emit(self)


# ==================================================
# CLICK OR TAP MONSTER
# ==================================================

func _on_input_event(
	_viewport: Node,
	event: InputEvent,
	_shape_index: int
) -> void:

	if not is_active:
		return

	if event is InputEventMouseButton:

		if (
			event.button_index == MOUSE_BUTTON_LEFT
			and event.pressed
		):
			selected.emit(self)

	elif event is InputEventScreenTouch:

		if event.pressed:
			selected.emit(self)


# ==================================================
# FEED THE MONSTER
#
# 0 = GO
# 1 = GLOW
# 2 = GROW
# ==================================================

func feed_category(
	category: int,
	amount: float = -1.0
) -> void:

	if not is_active:
		return

	var gain: float = nutrition_gain_per_food

	if amount >= 0.0:
		gain = amount

	if gain <= 0.0:
		return

	match category:

		0:
			if not go_locked:
				go = minf(100.0, go + gain)

				if go >= 100.0:
					go = 100.0
					go_locked = true

		1:
			if not glow_locked:
				glow = minf(100.0, glow + gain)

				if glow >= 100.0:
					glow = 100.0
					glow_locked = true

		2:
			if not grow_locked:
				grow = minf(100.0, grow + gain)

				if grow >= 100.0:
					grow = 100.0
					grow_locked = true

		_:
			return

	nutrition_changed.emit(self)
	_check_cure()


# ==================================================
# CHECK WHETHER MONSTER IS CURED
# ==================================================

func _check_cure() -> void:

	if is_cured:
		return

	if not go_locked:
		return

	if not glow_locked:
		return

	if not grow_locked:
		return

	is_cured = true
	is_active = false

	_stop_movement()

	cured.emit(self)


# ==================================================
# MONSTER ESCAPED UNCURED
# ==================================================

func mark_escaped() -> void:

	if not is_active:
		return

	is_active = false
	_stop_movement()


# ==================================================
# STOP PHYSICAL MOVEMENT
# ==================================================

func _stop_movement() -> void:

	velocity = Vector2.ZERO
	set_physics_process(false)
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)


# ==================================================
# GET NUTRITION VALUES
# ==================================================

func get_nutrition_values() -> Dictionary:

	return {
		"GO": go,
		"GLOW": glow,
		"GROW": grow
	}


# ==================================================
# GET PERMANENTLY FULL BARS
# ==================================================

func get_locked_values() -> Dictionary:

	return {
		"GO": go_locked,
		"GLOW": glow_locked,
		"GROW": grow_locked
	}
