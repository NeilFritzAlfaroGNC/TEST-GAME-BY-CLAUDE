extends TextureRect
## Animate the editable image, while its BaseButton keeps the original hit area/navigation.
@export_group("Image Animation")
@export_range(1.0, 1.5, 0.01) var hover_scale_multiplier: float = 1.08
@export_range(0.5, 1.0, 0.01) var pressed_scale_multiplier: float = 0.94
@export_range(0.0, 0.5, 0.01) var animation_duration: float = 0.12

var _button: BaseButton
var _rest_scale: Vector2
var _feedback_tween: Tween

func _ready() -> void:
	_button = get_parent() as BaseButton
	_rest_scale = scale
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _button == null:
		push_warning("[Button Image] Parent must be a Button or TextureButton.")
		return
	_button.mouse_entered.connect(_on_mouse_entered)
	_button.mouse_exited.connect(_on_mouse_exited)
	_button.button_down.connect(_on_button_down)
	_button.button_up.connect(_on_button_up)
	resized.connect(_update_pivot)
	visibility_changed.connect(_on_visibility_changed)
	_update_pivot()
	call_deferred("_update_pivot")

func _update_pivot() -> void:
	pivot_offset = size * 0.5

func _on_mouse_entered() -> void:
	_animate(pressed_scale_multiplier if _button.button_pressed else hover_scale_multiplier)

func _on_mouse_exited() -> void:
	_animate(1.0)

func _on_button_down() -> void:
	_animate(pressed_scale_multiplier)

func _on_button_up() -> void:
	_animate(hover_scale_multiplier if _button.is_hovered() else 1.0)

func _animate(multiplier: float) -> void:
	if not is_instance_valid(_button) or _button.disabled:
		multiplier = 1.0
	_stop_tween()
	var target_scale := _rest_scale * multiplier
	if animation_duration <= 0.0:
		scale = target_scale
		return
	_feedback_tween = create_tween()
	_feedback_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_feedback_tween.tween_property(self,"scale",target_scale,animation_duration)

func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		_reset_image()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready():
		_reset_image()

func _reset_image() -> void:
	_stop_tween()
	scale = _rest_scale

func _stop_tween() -> void:
	if _feedback_tween != null and _feedback_tween.is_valid():
		_feedback_tween.kill()

func _exit_tree() -> void:
	_stop_tween()
