extends Area2D
class_name FoodItem
## A food that rides the conveyor belt. Click and drag it with the mouse;
## drop it on the main character to make them attack.

# Emitted when the food is dropped on a body that has play_attack() (the main character).
signal fed(food: FoodItem, target: Node2D)

@export var food_name: String = "" #e.g. "corn", set by the conveyor belt

@onready var sprite: Sprite2D = $Sprite

var dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var belt_y: float = 0.0 #Height on the belt to return to when dropped elsewhere

# Show only the first 128x128 cell (the whole food) of a 256x256 food sheet.
func set_food_texture(sheet: Texture2D) -> void:
	var icon := AtlasTexture.new()
	icon.atlas = sheet
	icon.region = Rect2(0, 0, 128, 128)
	$Sprite.texture = icon

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var pointer: Vector2 = _to_world(event.position)
		if event.pressed and not dragging and _is_over(pointer):
			# Pick up the food.
			dragging = true
			drag_offset = global_position - pointer
			z_index = 10
			get_viewport().set_input_as_handled()
		elif not event.pressed and dragging:
			global_position = pointer + drag_offset
			_drop()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and dragging:
		# Follow the mouse (or finger, on touch screens) while dragging.
		global_position = _to_world(event.position) + drag_offset

# Screen position of an input event -> world position (accounts for the camera).
func _to_world(screen_pos: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * screen_pos

func _is_over(world_pos: Vector2) -> bool:
	return sprite.get_rect().has_point(sprite.to_local(world_pos))

func _drop() -> void:
	dragging = false
	z_index = 0
	# Feed the main character if the food was dropped on them.
	for body: Node2D in get_overlapping_bodies():
		if body.has_method("receive_food"):
			body.receive_food(food_name)
			fed.emit(self, body)
			queue_free()
			return
	# Otherwise put the food back on the belt where it was dropped.
	position.y = belt_y
