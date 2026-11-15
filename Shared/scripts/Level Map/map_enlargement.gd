extends TextureRect

# ==================================================
# FOOD HEROES - LEVEL MAP ENLARGEMENT
# GODOT 4.7.1
#
# PRESERVED:
# - Normal map
# - Whole-map zoom
# - Cafeteria zoom and navigation
# - Canteen zoom and navigation
# - Map dragging
# - Outside-click restoration
# - Canteen unlock requirements
#
# NEW:
# - Tanjangco direct entry from normal map
# - Tanjangco second zoom when map is enlarged
# - Tanjangco battle entry after second zoom
# - Level 2 completion requirement for Tanjangco
#
# All Tanjangco settings are grouped in Inspector.
# ==================================================


# ==================================================
# ZOOM STATES
# ==================================================

enum ZoomState {
	NORMAL,
	MAP_ENLARGED,
	CAFETERIA_ENLARGED,
	CANTEEN_ENLARGED,
	TANJANGCO_ENLARGED
}


# ==================================================
# ORIGINAL MAP ZOOM SETTINGS
# ==================================================

@export_group("Map Zoom Settings")

@export var map_zoom: float = 1.5
@export var location_zoom: float = 1.5
@export var zoom_duration: float = 0.3
@export var drag_threshold: float = 8.0


# ==================================================
# TANJANGCO - INSPECTOR SETTINGS
# ==================================================

@export_group("Tanjangco - Level 3")

# Enable Tanjangco navigation.
# Keep this enabled after gameplay tests pass.
@export var enable_tanjangco: bool = true

# Require a Canteen completion to enter Level 3.
@export var require_canteen_completion: bool = true

# Minimum Canteen stars on Easy or Normal.
@export_range(1, 3, 1)
var required_canteen_stars: int = 1

# Path to the independent Level 3 battle.
@export_file("*.tscn")
var tanjangco_battle_path: String = (
	"res://Level3/scenes/battle/"
	+ "battle_scene_level3.tscn"
)

# Independent Tanjangco zoom multiplier.
# 1.5 means the same second zoom as other levels.
@export_range(1.0, 4.0, 0.05)
var tanjangco_location_zoom: float = 1.5

# Debug output.
@export var tanjangco_debug: bool = true


# ==================================================
# ORIGINAL SCENE PATHS
# ==================================================

const CAFETERIA_SCENE_PATH: String = (
	"res://Level1/scenes/story/cafeteria_story_scene.tscn"
)

const CANTEEN_SCENE_PATH: String = (
	"res://Level2/scenes/story/canteen_story_scene.tscn"
)


# ==================================================
# ORIGINAL NODE REFERENCES
# ==================================================

@onready var cafeteria_overlay: Control = (
	get_node_or_null("enlarging_cafeteria") as Control
)

@onready var cafeteria_button: Button = (
	get_node_or_null("Cafeteria") as Button
)

@onready var canteen_overlay: Control = (
	get_node_or_null("enlarging_canteen") as Control
)

@onready var canteen_button: Button = (
	get_node_or_null("Canteen") as Button
)


# ==================================================
# TANJANGCO - NEW NODE REFERENCES
# ==================================================

@onready var tanjangco_overlay: Control = (
	get_node_or_null("enlarging_tanjangco") as Control
)

@onready var tanjangco_button: Button = (
	get_node_or_null("Tanjangco") as Button
)

# Legacy button from the first Level 3 integration.
# It must not compete with the new zoom system.
@onready var old_tanjangco_play_button: Control = (
	get_node_or_null("TanjangcoPlayButton") as Control
)


# ==================================================
# MAP STATE
# ==================================================

var zoom_state: ZoomState = ZoomState.NORMAL

var original_scale: Vector2 = Vector2.ONE
var original_position: Vector2 = Vector2.ZERO
var original_pivot: Vector2 = Vector2.ZERO

var busy: bool = false
var is_dragging: bool = false

var press_start_mouse: Vector2 = Vector2.ZERO
var drag_start_mouse: Vector2 = Vector2.ZERO
var drag_start_position: Vector2 = Vector2.ZERO

var zoom_tween: Tween = null

var scene_transition_started: bool = false
var saved_scene_tree: SceneTree = null


# ==================================================
# INITIALIZATION
# ==================================================

func _ready() -> void:

	saved_scene_tree = get_tree()

	original_scale = scale
	original_position = position
	original_pivot = pivot_offset

	mouse_filter = Control.MOUSE_FILTER_STOP

	# Disable all location buttons initially.
	_set_all_buttons_enabled(false)

	# Enable map overlays.
	_set_all_overlays_enabled(true)

	# IMPORTANT:
	# The old separate Level 3 map button is
	# no longer used. Prevent click conflicts.
	if old_tanjangco_play_button != null:
		old_tanjangco_play_button.visible = false
		old_tanjangco_play_button.mouse_filter = (
			Control.MOUSE_FILTER_IGNORE
		)

	# Original cafeteria signals.
	_connect_overlay(
		cafeteria_overlay,
		_on_cafeteria_overlay_pressed
	)

	_connect_button(
		cafeteria_button,
		_on_cafeteria_button_pressed
	)

	# Original canteen signals.
	_connect_overlay(
		canteen_overlay,
		_on_canteen_overlay_pressed
	)

	_connect_button(
		canteen_button,
		_on_canteen_button_pressed
	)

	# ==================================================
	# TANJANGCO - SIGNAL CONNECTIONS
	# ==================================================

	_connect_overlay(
		tanjangco_overlay,
		_on_tanjangco_overlay_pressed
	)

	_connect_button(
		tanjangco_button,
		_on_tanjangco_button_pressed
	)

	if tanjangco_overlay == null:
		push_warning(
			"[Map] enlarging_tanjangco not found."
		)

	if tanjangco_button == null:
		push_warning(
			"[Map] Tanjangco button not found."
		)

	_refresh_canteen_lock()
	_refresh_tanjangco_lock()

	print("[Map] Map enlargement ready.")
	print(
		"[Map] Tanjangco battle path: ",
		tanjangco_battle_path
	)


# ==================================================
# SIGNAL HELPERS
# ==================================================

func _connect_overlay(
	overlay: Control,
	callback: Callable
) -> void:

	if overlay == null:
		return

	if not overlay is BaseButton:
		push_warning(
			"[Map] Overlay must be a Button: "
			+ overlay.name
		)
		return

	var overlay_button: BaseButton = (
		overlay as BaseButton
	)

	if not overlay_button.pressed.is_connected(
		callback
	):
		overlay_button.pressed.connect(
			callback
		)


func _connect_button(
	button: Button,
	callback: Callable
) -> void:

	if button == null:
		return

	if not button.pressed.is_connected(
		callback
	):
		button.pressed.connect(
			callback
		)


# ==================================================
# CANTEEN UNLOCK - ORIGINAL BEHAVIOR
# ==================================================

func _is_canteen_unlocked() -> bool:
	return ProgressManager.is_canteen_unlocked()


func _refresh_canteen_lock() -> void:

	var unlocked: bool = _is_canteen_unlocked()

	# Preserve clickability of overlay so
	# locked messages can be displayed.
	_set_overlay_enabled(
		canteen_overlay,
		true
	)

	if canteen_button != null:

		canteen_button.disabled = not unlocked

		if not unlocked:
			canteen_button.mouse_filter = (
				Control.MOUSE_FILTER_IGNORE
			)

	print(
		"[Map] Canteen unlocked: ",
		unlocked
	)


func _show_canteen_locked_message() -> void:

	print(
		"[Map] Canteen is locked! "
		+ "Earn at least 1 Cafeteria star "
		+ "on Easy or Normal."
	)


# ==================================================
# TANJANGCO - LEVEL 3 UNLOCK
# ==================================================

func _is_tanjangco_unlocked() -> bool:

	if not enable_tanjangco:
		return false

	if not require_canteen_completion:
		return true

	var easy_stars: int = (
		ProgressManager.get_level_stars(
			"easy",
			"canteen_level_2"
		)
	)

	var normal_stars: int = (
		ProgressManager.get_level_stars(
			"normal",
			"canteen_level_2"
		)
	)

	return (
		easy_stars >= required_canteen_stars
		or normal_stars >= required_canteen_stars
	)


func _refresh_tanjangco_lock() -> void:

	# Keep the overlay clickable for messages.
	_set_overlay_enabled(
		tanjangco_overlay,
		true
	)

	if tanjangco_button != null:

		var allow_button: bool = (
			_is_tanjangco_unlocked()
			and zoom_state == ZoomState.TANJANGCO_ENLARGED
			and not busy
		)

		_set_button_enabled(
			tanjangco_button,
			allow_button
		)


func _show_tanjangco_locked_message() -> void:

	_tanjangco_log(
		"Tanjangco locked! Earn at least "
		+ str(required_canteen_stars)
		+ " Canteen star(s) on Easy or Normal."
	)


# ==================================================
# TANJANGCO - DEBUG
# ==================================================

func _tanjangco_log(message: String) -> void:

	if tanjangco_debug:
		print(
			"[Tanjangco] ",
			message
		)


# ==================================================
# MAP INPUT - ORIGINAL BEHAVIOR
# ==================================================

func _gui_input(event: InputEvent) -> void:

	if busy or scene_transition_started:
		return

	if event is InputEventMouseButton:

		if event.button_index != MOUSE_BUTTON_LEFT:
			return

		if event.pressed:

			press_start_mouse = (
				get_global_transform() * event.position
			)

			drag_start_mouse = press_start_mouse
			drag_start_position = global_position
			is_dragging = false

		else:

			var release_pos: Vector2 = (
				get_global_transform() * event.position
			)

			var moved: bool = (
				press_start_mouse.distance_to(
					release_pos
				) >= drag_threshold
			)

			if is_dragging or moved:

				is_dragging = false
				accept_event()
				return

			if zoom_state == ZoomState.NORMAL:
				_zoom_to_map()

			accept_event()


# ==================================================
# DRAG AND OUTSIDE CLICK
# ==================================================

func _input(event: InputEvent) -> void:

	if busy or scene_transition_started:
		return

	if zoom_state == ZoomState.NORMAL:
		return

	if event is InputEventMouseButton:

		if (
			event.button_index == MOUSE_BUTTON_LEFT
			and event.pressed
		):

			var map_clip: Control = (
				get_parent() as Control
			)

			if map_clip != null:

				var mouse_position: Vector2 = (
					get_canvas_transform().affine_inverse() * event.position
				)

				if not map_clip.get_global_rect().has_point(
					mouse_position
				):

					is_dragging = false
					_restore_map()
					return

	if event is InputEventMouseMotion:

		if (event.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
			return

		var mouse_pos: Vector2 = (
			get_canvas_transform().affine_inverse() * event.position
		)

		if (
			not is_dragging
			and press_start_mouse.distance_to(
				mouse_pos
			) >= drag_threshold
		):
			is_dragging = true

		if is_dragging:

			global_position = (
				drag_start_position
				+ mouse_pos
				- drag_start_mouse
			)

	elif event is InputEventMouseButton:

		if (
			event.button_index == MOUSE_BUTTON_LEFT
			and not event.pressed
		):
			is_dragging = false


# ==================================================
# CAFETERIA OVERLAY
# ==================================================

func _on_cafeteria_overlay_pressed() -> void:

	if busy or scene_transition_started:
		return

	print("[Map] Cafeteria overlay clicked.")

	if zoom_state == ZoomState.NORMAL:
		_open_scene(CAFETERIA_SCENE_PATH)

	elif zoom_state == ZoomState.MAP_ENLARGED:
		await _zoom_to_location(
			cafeteria_overlay,
			ZoomState.CAFETERIA_ENLARGED
		)


# ==================================================
# CANTEEN OVERLAY
# ==================================================

func _on_canteen_overlay_pressed() -> void:

	if busy or scene_transition_started:
		return

	if not _is_canteen_unlocked():
		_show_canteen_locked_message()
		return

	print("[Map] Canteen overlay clicked.")

	if zoom_state == ZoomState.NORMAL:
		_open_scene(CANTEEN_SCENE_PATH)

	elif zoom_state == ZoomState.MAP_ENLARGED:
		await _zoom_to_location(
			canteen_overlay,
			ZoomState.CANTEEN_ENLARGED
		)


# ==================================================
# TANJANGCO - OVERLAY
#
# NORMAL MAP:
# Click Tanjangco -> Open Level 3 directly.
#
# WHOLE MAP ENLARGED:
# Click Tanjangco -> Zoom into Tanjangco.
# ==================================================

func _on_tanjangco_overlay_pressed() -> void:

	if busy or scene_transition_started:
		return

	_tanjangco_log("Tanjangco overlay clicked.")

	if not _is_tanjangco_unlocked():
		_show_tanjangco_locked_message()
		return

	if zoom_state == ZoomState.NORMAL:

		_tanjangco_log(
			"Normal map: opening Level 3."
		)

		_open_scene(tanjangco_battle_path)

	elif zoom_state == ZoomState.MAP_ENLARGED:

		_tanjangco_log(
			"Enlarged map: zooming into Tanjangco."
		)

		await _zoom_to_location(
			tanjangco_overlay,
			ZoomState.TANJANGCO_ENLARGED
		)


# ==================================================
# ORIGINAL LOCATION BUTTONS
# ==================================================

func _on_cafeteria_button_pressed() -> void:

	if busy or scene_transition_started:
		return

	if zoom_state == ZoomState.CAFETERIA_ENLARGED:
		_open_scene(CAFETERIA_SCENE_PATH)


func _on_canteen_button_pressed() -> void:

	if busy or scene_transition_started:
		return

	if not _is_canteen_unlocked():
		_show_canteen_locked_message()
		return

	if zoom_state == ZoomState.CANTEEN_ENLARGED:
		_open_scene(CANTEEN_SCENE_PATH)


# ==================================================
# TANJANGCO - LOCATION BUTTON
#
# Only works after the second Tanjangco zoom.
# ==================================================

func _on_tanjangco_button_pressed() -> void:

	if busy or scene_transition_started:
		return

	if not _is_tanjangco_unlocked():
		_show_tanjangco_locked_message()
		return

	if zoom_state != ZoomState.TANJANGCO_ENLARGED:
		return

	_tanjangco_log(
		"Tanjangco enlarged: opening Level 3."
	)

	_open_scene(tanjangco_battle_path)


# ==================================================
# OPEN SCENE
# ==================================================

func _open_scene(scene_path: String) -> void:

	if scene_transition_started:
		return

	# Preserve Canteen lock.
	if scene_path == CANTEEN_SCENE_PATH:

		if not _is_canteen_unlocked():
			_show_canteen_locked_message()
			return

	# Protect Level 3 independently.
	if scene_path == tanjangco_battle_path:

		if not _is_tanjangco_unlocked():
			_show_tanjangco_locked_message()
			return

	print(
		"[Map] Attempting to open: ",
		scene_path
	)

	if scene_path.is_empty():
		push_error("[Map] Scene path is empty.")
		return

	if not ResourceLoader.exists(scene_path):

		push_error(
			"[Map] Scene file does not exist: "
			+ scene_path
		)
		return

	if saved_scene_tree == null:

		push_error(
			"[Map] SceneTree is unavailable."
		)
		return

	scene_transition_started = true

	saved_scene_tree.call_deferred(
		"change_scene_to_file",
		scene_path
	)


# ==================================================
# ZOOM TO WHOLE MAP
# ==================================================

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
	).set_trans(
		Tween.TRANS_CUBIC
	).set_ease(
		Tween.EASE_OUT
	)

	await zoom_tween.finished

	if not is_inside_tree():
		return

	zoom_state = ZoomState.MAP_ENLARGED

	_set_all_overlays_enabled(true)

	_refresh_canteen_lock()
	_refresh_tanjangco_lock()

	busy = false


# ==================================================
# ZOOM TO LOCATION
# ==================================================

func _zoom_to_location(
	overlay: Control,
	destination: ZoomState
) -> void:

	if overlay == null or busy:
		return

	if destination == ZoomState.CANTEEN_ENLARGED:

		if not _is_canteen_unlocked():
			_show_canteen_locked_message()
			return

	# ==================================================
	# TANJANGCO - ENLARGEMENT PROTECTION
	# ==================================================

	if destination == ZoomState.TANJANGCO_ENLARGED:

		if not _is_tanjangco_unlocked():
			_show_tanjangco_locked_message()
			return

	busy = true

	_set_all_overlays_enabled(false)
	_set_all_buttons_enabled(false)

	# Zoom around selected location's center.
	pivot_offset = (
		overlay.position
		+ overlay.size / 2.0
	)

	var target_location_zoom: float = location_zoom

	if destination == ZoomState.TANJANGCO_ENLARGED:
		target_location_zoom = tanjangco_location_zoom

	zoom_tween = create_tween()

	zoom_tween.tween_property(
		self,
		"scale",
		original_scale
		* map_zoom
		* target_location_zoom,
		zoom_duration
	).set_trans(
		Tween.TRANS_CUBIC
	).set_ease(
		Tween.EASE_OUT
	)

	await zoom_tween.finished

	if not is_inside_tree():
		return

	zoom_state = destination

	if destination == ZoomState.CAFETERIA_ENLARGED:

		_set_button_enabled(
			cafeteria_button,
			true
		)

	elif destination == ZoomState.CANTEEN_ENLARGED:

		_set_button_enabled(
			canteen_button,
			_is_canteen_unlocked()
		)

	elif destination == ZoomState.TANJANGCO_ENLARGED:

		_set_button_enabled(
			tanjangco_button,
			_is_tanjangco_unlocked()
		)

		_tanjangco_log(
			"Second zoom completed. "
			+ "Tanjangco button enabled."
		)

	busy = false


# ==================================================
# RESTORE ORIGINAL MAP
# ==================================================

func _restore_map() -> void:

	if busy or scene_transition_started:
		return

	busy = true

	_set_all_buttons_enabled(false)

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

	_set_all_overlays_enabled(true)

	_refresh_canteen_lock()
	_refresh_tanjangco_lock()

	busy = false


# ==================================================
# ENABLE / DISABLE ALL LOCATION BUTTONS
# ==================================================

func _set_all_buttons_enabled(
	enabled: bool
) -> void:

	_set_button_enabled(
		cafeteria_button,
		enabled
	)

	_set_button_enabled(
		canteen_button,
		enabled and _is_canteen_unlocked()
	)

	# NEW - Tanjangco button.
	_set_button_enabled(
		tanjangco_button,
		enabled and _is_tanjangco_unlocked()
	)


# ==================================================
# ENABLE / DISABLE ALL OVERLAYS
# ==================================================

func _set_all_overlays_enabled(
	enabled: bool
) -> void:

	_set_overlay_enabled(
		cafeteria_overlay,
		enabled
	)

	_set_overlay_enabled(
		canteen_overlay,
		enabled
	)

	# NEW - Tanjangco overlay.
	_set_overlay_enabled(
		tanjangco_overlay,
		enabled
	)


# ==================================================
# BUTTON HELPER
# ==================================================

func _set_button_enabled(
	button: Button,
	enabled: bool
) -> void:

	if button == null:
		return

	button.disabled = not enabled

	button.mouse_filter = (
		Control.MOUSE_FILTER_STOP
		if enabled
		else Control.MOUSE_FILTER_IGNORE
	)


# ==================================================
# OVERLAY HELPER
# ==================================================

func _set_overlay_enabled(
	overlay: Control,
	enabled: bool
) -> void:

	if overlay == null:
		return

	overlay.mouse_filter = (
		Control.MOUSE_FILTER_STOP
		if enabled
		else Control.MOUSE_FILTER_IGNORE
	)
