extends Node

# ==================================================
# FOOD HEROES - AUTO DYNAMIC RESOLUTION CONTROLLER
# GODOT 4.7.1
#
# GLOBAL DISPLAY SYSTEM
#
# Automatically scales the game to different
# screen and window sizes.
#
# The original game design remains 956 x 440.
#
# IMPORTANT:
# All dynamic resolution settings are located
# under "AUTO DYNAMIC RESOLUTION" in Inspector.
#
# This script does NOT resize the device screen.
# Godot automatically adjusts the game's content
# based on the actual window or device display.
#
# Works across:
# - Main Menu
# - Story Scenes
# - Level 1
# - Level 2
# - Level 3
# - Victory / Game Over
# ==================================================


# ==================================================
# AUTO DYNAMIC RESOLUTION - MAIN SWITCH
# ==================================================

@export_group("AUTO DYNAMIC RESOLUTION")

# Enable automatic scaling across different screens.
@export var auto_dynamic_resolution_enabled: bool = true


# ==================================================
# AUTO DYNAMIC RESOLUTION - BASE SIZE
# ==================================================

@export_group("AUTO DYNAMIC - Base Resolution")

# Original game design width.
# This is NOT the physical device screen width.
@export_range(320, 7680, 1)
var base_resolution_width: int = 956

# Original game design height.
# This is NOT the physical device screen height.
@export_range(240, 4320, 1)
var base_resolution_height: int = 440


# ==================================================
# AUTO DYNAMIC RESOLUTION - ASPECT MODE
# ==================================================

@export_group("AUTO DYNAMIC - Screen Adaptation")

# KEEP:
# - Preserves the original gameplay area
# - May add letterboxing
# - Safest for existing levels
#
# EXPAND:
# - Expands the visible gameplay area
# - Reduces letterboxing
# - May expose space outside the original layout
#
# Start with KEEP for your current project.
@export_enum(
	"Keep (Letterbox):0",
	"Expand (Show More):1"
)
var screen_adaptation_mode: int = 0


# ==================================================
# AUTO DYNAMIC RESOLUTION - SCALING
# ==================================================

@export_group("AUTO DYNAMIC - Scaling")

# CANVAS ITEMS:
# Recommended for your Food Heroes 2D gameplay.
#
# VIEWPORT:
# Scales a fixed rendering resolution.
@export_enum(
	"Canvas Items:0",
	"Viewport:1"
)
var scaling_mode: int = 0

# Additional user interface scaling.
# 1.0 = normal.
@export_range(0.5, 2.0, 0.05)
var additional_scale_factor: float = 1.0


# ==================================================
# AUTO DYNAMIC RESOLUTION - DEBUG
# ==================================================

@export_group("AUTO DYNAMIC - Debug")

# Prints the detected window size.
@export var show_resolution_debug: bool = false


# ==================================================
# INTERNAL VARIABLES
# ==================================================

var game_window: Window = null

var last_detected_size: Vector2i = Vector2i.ZERO


# ==================================================
# INITIALIZATION
# ==================================================

func _ready() -> void:

	game_window = get_tree().root

	if not is_instance_valid(game_window):
		push_error(
			"[DynamicResolution] Root window missing."
		)
		return

	if not auto_dynamic_resolution_enabled:
		_debug("Automatic resolution disabled.")
		return

	# ==================================================
	# AUTO DYNAMIC RESOLUTION - APPLY SETTINGS
	# ==================================================

	_apply_dynamic_resolution()

	# ==================================================
	# AUTO DYNAMIC RESOLUTION - WATCH WINDOW CHANGES
	# ==================================================

	# Godot performs automatic content scaling
	# internally whenever the window changes size.
	#
	# This signal is only used to detect changes
	# for debugging. We do NOT manually resize
	# the window every frame.

	if not game_window.size_changed.is_connected(
		_on_window_size_changed
	):
		game_window.size_changed.connect(
			_on_window_size_changed
		)

	last_detected_size = game_window.size

	_debug(
		"Automatic resolution system initialized."
	)


# ==================================================
# AUTO DYNAMIC RESOLUTION - APPLY
# ==================================================

func _apply_dynamic_resolution() -> void:

	if not is_instance_valid(game_window):
		return

	if not auto_dynamic_resolution_enabled:
		return

	# ==================================================
	# 1. BASE DESIGN RESOLUTION
	#
	# The game's original coordinate system.
	# Change these values in the Inspector.
	# ==================================================

	var base_size: Vector2i = Vector2i(
		maxi(base_resolution_width, 320),
		maxi(base_resolution_height, 240)
	)

	game_window.content_scale_size = base_size

	# ==================================================
	# 2. AUTO DYNAMIC SCALING MODE
	#
	# Canvas Items scales 2D game content
	# automatically based on window dimensions.
	# ==================================================

	if scaling_mode == 0:

		game_window.content_scale_mode = (
			Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		)

	else:

		game_window.content_scale_mode = (
			Window.CONTENT_SCALE_MODE_VIEWPORT
		)

	# ==================================================
	# 3. AUTO DYNAMIC SCREEN ADAPTATION
	#
	# KEEP:
	# Preserves aspect ratio and adds letterboxing.
	#
	# EXPAND:
	# Adapts the visible area to different ratios.
	# ==================================================

	if screen_adaptation_mode == 0:

		game_window.content_scale_aspect = (
			Window.CONTENT_SCALE_ASPECT_KEEP
		)

	else:

		game_window.content_scale_aspect = (
			Window.CONTENT_SCALE_ASPECT_EXPAND
		)

	# ==================================================
	# 4. ADDITIONAL DISPLAY SCALING
	#
	# Normal value = 1.0.
	# Godot still calculates automatic scaling.
	# ==================================================

	game_window.content_scale_factor = (
		additional_scale_factor
	)

	_debug(
		"Base design resolution: "
		+ str(base_size)
	)

	_debug(
		"Current device/window resolution: "
		+ str(game_window.size)
	)

	_debug(
		"Screen adaptation: "
		+ (
			"KEEP"
			if screen_adaptation_mode == 0
			else "EXPAND"
		)
	)


# ==================================================
# AUTO DYNAMIC RESOLUTION - WINDOW DETECTION
# ==================================================

func _on_window_size_changed() -> void:

	if not auto_dynamic_resolution_enabled:
		return

	if not is_instance_valid(game_window):
		return

	var new_size: Vector2i = game_window.size

	if new_size == last_detected_size:
		return

	last_detected_size = new_size

	# IMPORTANT:
	# Do not set the window size here.
	#
	# Godot automatically recalculates the
	# content scaling whenever the window changes.
	#
	# This method only reports the new size.

	_debug(
		"Screen/window changed to: "
		+ str(new_size.x)
		+ " x "
		+ str(new_size.y)
	)


# ==================================================
# AUTO DYNAMIC RESOLUTION - PUBLIC REFRESH
# ==================================================

# Can be called if you change the configuration
# during gameplay and want to reapply settings.

func refresh_dynamic_resolution() -> void:

	if not auto_dynamic_resolution_enabled:
		return

	_apply_dynamic_resolution()


# ==================================================
# AUTO DYNAMIC RESOLUTION - GET CURRENT SIZE
# ==================================================

func get_current_screen_size() -> Vector2i:

	if not is_instance_valid(game_window):
		return Vector2i.ZERO

	return game_window.size


# ==================================================
# AUTO DYNAMIC RESOLUTION - GET DESIGN SIZE
# ==================================================

func get_base_resolution() -> Vector2i:

	return Vector2i(
		base_resolution_width,
		base_resolution_height
	)


# ==================================================
# DEBUG
# ==================================================

func _debug(message: String) -> void:

	if show_resolution_debug:

		print(
			"[DynamicResolution] ",
			message
		)
