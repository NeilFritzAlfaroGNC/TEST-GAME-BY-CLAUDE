
extends TextureRect

enum ZoomState {
	NORMAL,
	MAP_ENLARGED,
	ENTRANCE_ENLARGED,
	CAFETERIA_ENLARGED
}

@export var map_zoom: float = 1.5
@export var location_zoom: float = 1.5
@export var zoom_duration: float = 0.3
@export var drag_threshold: float = 8.0

const ENTRANCE_SCENE_PATH: String = "res://scenes/Battle Screen/entrance_battle_background.tscn"
const CAFETERIA_SCENE_PATH: String = "res://scenes/Story Scene/cafeteria_story_scene.tscn"

@onready var entrance_overlay: Control = get_node_or_null("enlarging_entrance")
@onready var entrance_button: Button = get_node_or_null("Entrance")
@onready var cafeteria_overlay: Control = get_node_or_null("enlarging_cafeteria")
@onready var cafeteria_button: Button = get_node_or_null("Cafeteria")

var zoom_state: ZoomState = ZoomState.NORMAL
var original_scale: Vector2
var original_position: Vector2
var original_pivot: Vector2

var busy: bool = false
var is_dragging: bool = false
var press_start_mouse: Vector2 = Vector2.ZERO
var drag_start_mouse: Vector2 = Vector2.ZERO
var drag_start_position: Vector2 = Vector2.ZERO

var zoom_tween: Tween
var scene_transition_started: bool = false
var saved_scene_tree: SceneTree


func _ready() -> void:
	saved_scene_tree = get_tree()

	original_scale = scale
	original_position = position
	original_pivot = pivot_offset

	mouse_filter = Control.MOUSE_FILTER_STOP

	_set_button_enabled(entrance_button, false)
	_set_button_enabled(cafeteria_button, false)

	_set_overlay_enabled(entrance_overlay, true)
	_set_overlay_enabled(cafeteria_overlay, true)

	if entrance_overlay is Button:
		if not entrance_overlay.pressed.is_connected(_on_entrance_overlay_pressed):
			entrance_overlay.pressed.connect(_on_entrance_overlay_pressed)

	if cafeteria_overlay is Button:
		if not cafeteria_overlay.pressed.is_connected(_on_cafeteria_overlay_pressed):
			cafeteria_overlay.pressed.connect(_on_cafeteria_overlay_pressed)

	if entrance_button != null:
		if not entrance_button.pressed.is_connected(_on_entrance_button_pressed):
			entrance_button.pressed.connect(_on_entrance_button_pressed)

	if cafeteria_button != null:
		if not cafeteria_button.pressed.is_connected(_on_cafeteria_button_pressed):
			cafeteria_button.pressed.connect(_on_cafeteria_button_pressed)

	print("Map script ready.")
	print("Cafeteria story path: ", CAFETERIA_SCENE_PATH)
	print("Entrance overlay found: ", entrance_overlay != null)
	print("Entrance button found: ", entrance_button != null)
	print("Cafeteria overlay found: ", cafeteria_overlay != null)
	print("Cafeteria button found: ", cafeteria_button != null)


func _gui_input(event: InputEvent) -> void:
	if busy or scene_transition_started:
		return

	if event is InputEventMouseButton:
		if event.button_index != MOUSE_BUTTON_LEFT:
			return

		if event.pressed:
			press_start_mouse = get_global_mouse_position()
			drag_start_mouse = press_start_mouse
			drag_start_position = global_position
			is_dragging = false
		else:
			var release_pos: Vector2 = get_global_mouse_position()
			var moved: bool = press_start_mouse.distance_to(release_pos) >= drag_threshold

			if is_dragging or moved:
				is_dragging = false
				accept_event()
				return

			if zoom_state == ZoomState.NORMAL:
				_zoom_to_map()

			accept_event()


func _input(event: InputEvent) -> void:
	if busy or scene_transition_started or zoom_state == ZoomState.NORMAL:
		return

	# Outside-click cancellation works at every zoom level.
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var map_clip := get_parent() as Control

			if map_clip != null:
				var mouse_position := get_global_mouse_position()

				if not map_clip.get_global_rect().has_point(mouse_position):
					is_dragging = false
					_restore_map()
					return

	if event is InputEventMouseMotion:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			return

		var mouse_pos: Vector2 = get_global_mouse_position()

		if not is_dragging and press_start_mouse.distance_to(mouse_pos) >= drag_threshold:
			is_dragging = true

		if is_dragging:
			global_position = drag_start_position + mouse_pos - drag_start_mouse

	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			is_dragging = false


func _on_entrance_overlay_pressed() -> void:
	print("Entrance overlay clicked.")

	if busy or scene_transition_started:
		return

	if zoom_state == ZoomState.NORMAL:
		_open_scene(ENTRANCE_SCENE_PATH)
	elif zoom_state == ZoomState.MAP_ENLARGED:
		await _zoom_to_location(
			entrance_overlay,
			ZoomState.ENTRANCE_ENLARGED
		)


func _on_cafeteria_overlay_pressed() -> void:
	print("Cafeteria overlay clicked. Zoom state: ", zoom_state)

	if busy or scene_transition_started:
		return

	if zoom_state == ZoomState.NORMAL:
		_open_scene(CAFETERIA_SCENE_PATH)
	elif zoom_state == ZoomState.MAP_ENLARGED:
		await _zoom_to_location(
			cafeteria_overlay,
			ZoomState.CAFETERIA_ENLARGED
		)


func _on_entrance_button_pressed() -> void:
	print("Entrance button clicked.")

	if busy or scene_transition_started:
		return

	if zoom_state == ZoomState.ENTRANCE_ENLARGED:
		_open_scene(ENTRANCE_SCENE_PATH)


func _on_cafeteria_button_pressed() -> void:
	print("Cafeteria button clicked. Zoom state: ", zoom_state)

	if busy or scene_transition_started:
		return

	if zoom_state == ZoomState.CAFETERIA_ENLARGED:
		_open_scene(CAFETERIA_SCENE_PATH)


func _open_scene(scene_path: String) -> void:
	if scene_transition_started:
		return

	print("Attempting to open scene: ", scene_path)

	if not ResourceLoader.exists(scene_path):
		push_error("Scene file does not exist: " + scene_path)
		return

	if saved_scene_tree == null:
		push_error("Saved SceneTree reference is unavailable.")
		return

	scene_transition_started = true

	saved_scene_tree.call_deferred(
		"change_scene_to_file",
		scene_path
	)


func _zoom_to_map() -> void:
	if busy or zoom_state != ZoomState.NORMAL:
		return

	busy = true
	pivot_offset = size / 2.0

	zoom_tween = create_tween()
	zoom_tween.tween_property(
		self,
		"scale",
		original_scale * map_zoom,
		zoom_duration
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	await zoom_tween.finished

	if not is_inside_tree():
		return

	zoom_state = ZoomState.MAP_ENLARGED

	_set_overlay_enabled(entrance_overlay, true)
	_set_overlay_enabled(cafeteria_overlay, true)

	busy = false


func _zoom_to_location(
	overlay: Control,
	destination: ZoomState
) -> void:
	if overlay == null or busy:
		return

	busy = true

	_set_overlay_enabled(entrance_overlay, false)
	_set_overlay_enabled(cafeteria_overlay, false)

	_set_button_enabled(entrance_button, false)
	_set_button_enabled(cafeteria_button, false)

	pivot_offset = overlay.position + overlay.size / 2.0

	zoom_tween = create_tween()
	zoom_tween.tween_property(
		self,
		"scale",
		original_scale * map_zoom * location_zoom,
		zoom_duration
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	await zoom_tween.finished

	if not is_inside_tree():
		return

	zoom_state = destination

	if destination == ZoomState.ENTRANCE_ENLARGED:
		_set_button_enabled(entrance_button, true)
	elif destination == ZoomState.CAFETERIA_ENLARGED:
		_set_button_enabled(cafeteria_button, true)

	busy = false


func _restore_map() -> void:
	if busy or scene_transition_started:
		return

	busy = true

	_set_button_enabled(entrance_button, false)
	_set_button_enabled(cafeteria_button, false)

	zoom_tween = create_tween()
	zoom_tween.set_parallel(true)

	zoom_tween.tween_property(
		self,
		"scale",
		original_scale,
		zoom_duration
	)

	zoom_tween.tween_property(
		self,
		"position",
		original_position,
		zoom_duration
	)

	zoom_tween.tween_property(
		self,
		"pivot_offset",
		original_pivot,
		zoom_duration
	)

	await zoom_tween.finished

	if not is_inside_tree():
		return

	zoom_state = ZoomState.NORMAL

	_set_overlay_enabled(entrance_overlay, true)
	_set_overlay_enabled(cafeteria_overlay, true)

	busy = false


func _set_button_enabled(button: Button, enabled: bool) -> void:
	if button == null:
		return

	button.disabled = not enabled
	button.mouse_filter = (
		Control.MOUSE_FILTER_STOP
		if enabled
		else Control.MOUSE_FILTER_IGNORE
	)


func _set_overlay_enabled(overlay: Control, enabled: bool) -> void:
	if overlay == null:
		return

	overlay.mouse_filter = (
		Control.MOUSE_FILTER_STOP
		if enabled
		else Control.MOUSE_FILTER_IGNORE
	)
