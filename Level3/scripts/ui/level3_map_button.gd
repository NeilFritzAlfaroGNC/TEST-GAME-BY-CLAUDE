extends Button
class_name Level3MapButton

# ==================================================
# FOOD HEROES - LEVEL 3 MAP ENTRY
# GODOT 4.7.1
#
# Controls the Scene3PlayButton on the Level Map.
#
# - Works with existing map_enlargement.gd
# - Only clickable when the map is enlarged
# - Optional Level 2 completion requirement
# - Opens independent Level 3 battle
# - All important settings editable in Inspector
#
# No changes to Level 1 or Level 2.
# ==================================================


# ==================================================
# LEVEL 3 - BATTLE SCENE
# ==================================================

@export_group("Level 3 Scene")

@export_file("*.tscn")
var level_3_battle_scene: String = (
	"res://Level3/scenes/battle/"
	+ "battle_scene_level3.tscn"
)


# ==================================================
# LEVEL 3 - ENTRY SETTINGS
# ==================================================

@export_group("Level 3 Entry")

# IMPORTANT:
# Keep OFF until Level 3 progression is tested.
@export var enable_level_3_entry: bool = false

# Require completing Canteen on Easy or Normal.
@export var require_level_2_clear: bool = true

@export_range(1, 3, 1)
var required_level_2_stars: int = 1


# ==================================================
# LEVEL 3 - MAP DISPLAY
# ==================================================

@export_group("Map Display")

# Empty text allows the map artwork to show.
@export var button_label: String = ""

# Only show the button after clicking to enlarge
# the whole map.
@export var only_when_map_enlarged: bool = true

# A flat button does not draw a default background.
@export var transparent_button: bool = true


# ==================================================
# DEBUG
# ==================================================

@export_group("Debug")

@export var show_debug_messages: bool = true


# ==================================================
# REFERENCES
# ==================================================

var map_controller: Node = null

var transition_started: bool = false


# ==================================================
# MAP ZOOM STATE
#
# Existing map_enlargement.gd:
# NORMAL       = 0
# MAP_ENLARGED = 1
# ==================================================

const MAP_ENLARGED_STATE: int = 1


# ==================================================
# INITIALIZATION
# ==================================================

func _ready() -> void:

	text = button_label
	flat = transparent_button

	focus_mode = Control.FOCUS_NONE

	map_controller = get_parent()

	if not pressed.is_connected(
		_on_level_3_pressed
	):
		pressed.connect(
			_on_level_3_pressed
		)

	set_process(true)

	_refresh_button_state()

	_debug("Scene3 map entry initialized.")


# ==================================================
# CHECK LEVEL 2 PROGRESSION
# ==================================================

func _is_level_3_unlocked() -> bool:

	if not require_level_2_clear:
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
		easy_stars >= required_level_2_stars
		or normal_stars >= required_level_2_stars
	)


# ==================================================
# CHECK MAP ZOOM STATE
# ==================================================

func _is_map_enlarged() -> bool:

	if not is_instance_valid(map_controller):
		return false

	var value: Variant = (
		map_controller.get("zoom_state")
	)

	if value == null:
		return false

	return int(value) == MAP_ENLARGED_STATE


# ==================================================
# REFRESH BUTTON
# ==================================================

func _process(_delta: float) -> void:
	_refresh_button_state()


func _refresh_button_state() -> void:

	var map_ready: bool = true

	if only_when_map_enlarged:
		map_ready = _is_map_enlarged()

	var can_enter: bool = (
		enable_level_3_entry
		and _is_level_3_unlocked()
		and map_ready
		and not transition_started
	)

	visible = map_ready

	disabled = not can_enter

	mouse_filter = (
		Control.MOUSE_FILTER_STOP
		if can_enter
		else Control.MOUSE_FILTER_IGNORE
	)


# ==================================================
# OPEN LEVEL 3
# ==================================================

func _on_level_3_pressed() -> void:

	if transition_started:
		return

	if not enable_level_3_entry:
		_debug("Level 3 entry disabled.")
		return

	if not _is_level_3_unlocked():
		_debug(
			"Level 3 locked. Complete Level 2 first."
		)
		return

	if only_when_map_enlarged:
		if not _is_map_enlarged():
			return

	if level_3_battle_scene.is_empty():
		push_error(
			"[Level3Map] Battle scene path is empty."
		)
		return

	if not ResourceLoader.exists(
		level_3_battle_scene
	):
		push_error(
			"[Level3Map] Missing battle scene: "
			+ level_3_battle_scene
		)
		return

	transition_started = true
	disabled = true

	_debug(
		"Opening: "
		+ level_3_battle_scene
	)

	get_tree().call_deferred(
		"change_scene_to_file",
		level_3_battle_scene
	)


# ==================================================
# DEBUG
# ==================================================

func _debug(message: String) -> void:

	if show_debug_messages:
		print(
			"[Level3Map] ",
			message
		)
