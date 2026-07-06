extends Area2D
## A conveyor-belt food. Main spawns these on the left; they ride the belt to
## the right. Drag one onto the Hero to feed him. If it isn't grabbed within
## LIFETIME seconds it blinks and then disappears (it wasn't touched/used).

const LIFETIME := 5.0        # max seconds a food stays on the belt if untouched
const BLINK_AT := 3.5        # start blinking this many seconds in (warns it's leaving)
const BELT_SPEED := 130.0    # left -> right belt speed (px/s)
const SPAWN_X := -90.0       # just off the left edge
const RETURN_TIME := 0.22    # seconds to glide back to the grab slot after a non-feeding drop
# The belt lane Y comes from the shared layout consts: GameData.BELT_Y.

@export var food_group: String = "Go"

var dragging: bool = false
var returning: bool = false     # gliding back to its grab slot (belt-ride + layout skip it)
var age: float = 0.0            # only advances while on the belt (paused while held)
var target_x: float = SPAWN_X   # stack slot assigned by Main; the food slides toward it
var _return_tween: Tween

@onready var rect: ColorRect = $ColorRect
@onready var label: Label = $Label

func _ready() -> void:
	input_pickable = true
	input_event.connect(_on_input_event)
	position = Vector2(SPAWN_X, GameData.BELT_Y)

# Assign this food a group ("Go"/"Glow"/"Grow"), a random real name, and color.
func set_food(group: String) -> void:
	food_group = group
	label.text = GameData.random_food(group)
	rect.color = GameData.group_color(group)

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# One food at a time: if another food is already held (foods can briefly
		# overlap on the belt), ignore this click so a single press can't pick up
		# a whole stack at once.
		for sib in get_parent().get_children():
			if sib != self and is_instance_valid(sib) and sib.dragging:
				return
		# Re-grabbed mid-return: cancel the glide-back and follow the mouse.
		_cancel_return()
		dragging = true
		z_index = 10          # draw above other foods while dragging
		modulate.a = 1.0      # cancel any mid-blink transparency

func _process(delta: float) -> void:
	if dragging:
		# Follow the mouse (or finger on Android). Age is paused while held.
		global_position = get_global_mouse_position()
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_drop()
		return
	if returning:
		# A tween is gliding it back to its grab slot; skip the belt-ride/aging.
		return
	# Ride the belt.
	age += delta
	# Slide toward the stack slot Main assigned; stop once we reach it so foods
	# pile up instead of running off the right of the screen.
	var step := BELT_SPEED * delta
	if position.x < target_x:
		position.x = min(position.x + step, target_x)
	elif position.x > target_x:
		position.x = max(position.x - step, target_x)
	if age >= LIFETIME:
		queue_free()
		return
	# Blink during the final stretch so the player knows it's about to vanish.
	if age >= BLINK_AT:
		modulate.a = 1.0 if (int(age * 8.0) % 2 == 0) else 0.25
	else:
		modulate.a = 1.0

# Return a held food to the belt WITHOUT the drop check (used when the game
# pauses mid-drag: a mouse release during the pause would otherwise complete
# the drop — and could feed the Hero — the moment the game resumes).
func cancel_drag() -> void:
	if not dragging:
		return
	dragging = false
	z_index = 0
	modulate.a = 1.0
	position.y = GameData.BELT_Y

func _drop() -> void:
	dragging = false
	z_index = 0
	modulate.a = 1.0
	var main = get_tree().current_scene
	if main == null:
		queue_free()
		return
	var hero = main.get_node_or_null("Hero")
	# If dropped on the Hero and it was actually used, it's consumed (removed).
	if hero != null and overlaps_area(hero):
		if main.food_dropped_on_hero(self):
			queue_free()
			return
	# Not consumed — either dropped away from the Hero, OR a WRONG food the Hero
	# rejected (food_dropped_on_hero returned false). Either way it glides smoothly
	# back to the exact slot it was grabbed from (never the start/back of the belt).
	# The slot stayed reserved while the food was held — BeltManager._layout ranks
	# it by target_x — so it drops right back into place with no reshuffle.
	returning = true
	_return_tween = create_tween()
	_return_tween.tween_property(self, "position", Vector2(target_x, GameData.BELT_Y), RETURN_TIME)
	_return_tween.tween_callback(func(): returning = false)

# Stop an in-progress glide-back (e.g. the food was grabbed again mid-return).
func _cancel_return() -> void:
	if _return_tween != null and _return_tween.is_valid():
		_return_tween.kill()
	returning = false
