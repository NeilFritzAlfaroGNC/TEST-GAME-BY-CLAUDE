extends Area2D
## A draggable food box. Its Go/Glow/Grow group + name are assigned by Main.
## Drag it onto the Hero to feed him.

@export var food_group: String = "Go"

var dragging: bool = false
var start_position: Vector2

@onready var rect: ColorRect = $ColorRect
@onready var label: Label = $Label

func _ready() -> void:
	start_position = global_position
	input_pickable = true
	input_event.connect(_on_input_event)

# Called by Main to give this food a group ("Go"/"Glow"/"Grow") and a random
# real food name from that group, plus the matching color.
func set_food(group: String) -> void:
	food_group = group
	label.text = GameData.random_food(group)
	rect.color = GameData.group_color(group)

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		dragging = true
		z_index = 1   # draw on top of the other foods while dragging

func _process(_delta: float) -> void:
	if dragging:
		# Follow the mouse (or finger, on Android) while held.
		global_position = get_global_mouse_position()
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			drop()

func drop() -> void:
	dragging = false
	z_index = 0
	var main = get_tree().current_scene
	var hero: Area2D = main.get_node("Hero")
	# If the food is touching the hero, tell the game.
	if overlaps_area(hero):
		main.food_dropped_on_hero(self)
	# Snap back to where it started.
	global_position = start_position
