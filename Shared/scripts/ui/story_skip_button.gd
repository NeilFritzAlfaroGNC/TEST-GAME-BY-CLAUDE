extends Button
class_name StorySkipButton

signal skip_requested

@export_group("Skip Story Settings")
@export var button_text: String = "Skip Story"
@export var skip_enabled: bool = true

func _ready() -> void:
	text = button_text
	disabled = not skip_enabled
	focus_mode = Control.FOCUS_NONE
	if not pressed.is_connected(_on_skip_pressed):
		pressed.connect(_on_skip_pressed)

func _on_skip_pressed() -> void:
	if not skip_enabled or disabled:
		return
	skip_requested.emit()

# Story-wide tap/hold input runs before GUI input. Reserve this button's area
# so a Skip press, hold or release cannot also advance/fast-forward the story.
func contains_pointer_event(event: InputEvent) -> bool:
	if not is_visible_in_tree():
		return false
	var point: Vector2
	if event is InputEventMouseButton:
		point = event.position
	elif event is InputEventScreenTouch:
		point = event.position
	else:
		return false
	return Rect2(Vector2.ZERO,size).has_point(get_global_transform_with_canvas().affine_inverse()*point)
