@tool
extends Control

# ==================================================
# FOOD HEROES - SCENE3 STARS
# GODOT 4.7.1
#
# SCENE3 ONLY
#
# PURPOSE:
# - Adjust spacing between all three stars.
# - Preview changes directly in Godot Editor.
# - Keep the three stars centered together.
# - Preserve saved star ratings.
# - Prevent stars from blocking map clicks.
#
# IMPORTANT:
# @tool allows Inspector changes to appear
# immediately in the 2D Editor.
#
# Does NOT affect Cafeteria, Canteen, or Victory.
# ==================================================


# ==================================================
# SCENE3 - PROGRESS SETTINGS
# ==================================================

@export_group("Scene3 Progress")

@export var level_id: String = "scene3_level_3"

@export var show_current_run: bool = false


# ==================================================
# SCENE3 - STAR SPACING
# ==================================================

@export_group("Scene3 Star Spacing")

# Distance between the CENTERS of two stars.
#
# Smaller = stars closer together.
# Larger = stars farther apart.
#
# Recommended: 18
@export_range(8.0, 80.0, 1.0)
var star_spacing: float = 18.0:
	set(value):
		star_spacing = value
		_update_layout()


# ==================================================
# SCENE3 - STAR POSITION
# ==================================================

@export_group("Scene3 Star Position")

# Move all three stars horizontally.
@export_range(-200.0, 200.0, 1.0)
var stars_offset_x: float = 0.0:
	set(value):
		stars_offset_x = value
		_update_layout()

# Move all three stars vertically.
@export_range(-200.0, 200.0, 1.0)
var stars_offset_y: float = 0.0:
	set(value):
		stars_offset_y = value
		_update_layout()


# ==================================================
# SCENE3 - STAR APPEARANCE
# ==================================================

@export_group("Scene3 Star Appearance")

# Font size of each star.
@export_range(8, 64, 1)
var star_font_size: int = 18:
	set(value):
		star_font_size = value
		_update_layout()


# ==================================================
# COLORS
# ==================================================

const GOLD: Color = Color("#E5B94B")
const WHITE: Color = Color("#FFFFFF")


# ==================================================
# INTERNAL STATE
# ==================================================

var _last_size: Vector2 = Vector2.ZERO


# ==================================================
# INITIALIZATION
# ==================================================

func _ready() -> void:

	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_update_layout()

	if not Engine.is_editor_hint():
		refresh_stars()

	set_process(true)


# ==================================================
# AUTOMATIC EDITOR UPDATE
# ==================================================

func _process(_delta: float) -> void:

	if size != _last_size:
		_update_layout()


# ==================================================
# GET STAR LABELS
# ==================================================

func _get_stars() -> Array[Label]:

	var result: Array[Label] = []

	for path: String in [
		"Stars/Star1",
		"Stars/Star2",
		"Stars/Star3"
	]:

		var star: Label = get_node_or_null(
			path
		) as Label

		if star != null:
			result.append(star)

	return result


# ==================================================
# SCENE3 - APPLY STAR SPACING
# ==================================================

func _update_layout() -> void:

	if not is_inside_tree():
		return

	var stars_container: Control = (
		get_node_or_null("Stars") as Control
	)

	if stars_container == null:
		return

	var stars: Array[Label] = _get_stars()

	if stars.size() != 3:
		return

	_last_size = size

	# Prevent the star group from blocking clicks.
	stars_container.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	stars_container.set_anchors_preset(
		Control.PRESET_TOP_LEFT
	)

	stars_container.position = Vector2.ZERO
	stars_container.size = size

	# ==================================================
	# SCENE3 STAR SPACING CONTROL
	#
	# Three positions:
	#
	# Star1 = center - spacing
	# Star2 = center
	# Star3 = center + spacing
	#
	# Changing star_spacing adjusts all three
	# symmetrically without moving the group center.
	# ==================================================

	var center_x: float = (
		size.x * 0.5 + stars_offset_x
	)

	var center_y: float = (
		size.y * 0.5 + stars_offset_y
	)

	var label_width: float = maxf(
		24.0,
		float(star_font_size) * 1.6
	)

	var label_height: float = maxf(
		24.0,
		float(star_font_size) * 1.6
	)

	for i: int in range(3):

		var star: Label = stars[i]

		star.mouse_filter = (
			Control.MOUSE_FILTER_IGNORE
		)

		star.set_anchors_preset(
			Control.PRESET_TOP_LEFT
		)

		star.add_theme_font_size_override(
			"font_size",
			star_font_size
		)

		star.horizontal_alignment = (
			HORIZONTAL_ALIGNMENT_CENTER
		)

		star.vertical_alignment = (
			VERTICAL_ALIGNMENT_CENTER
		)

		# Editor themes can impose a larger Label minimum size.
		var minimum := star.get_combined_minimum_size()
		var actual_label_size := Vector2(
			maxf(label_width, minimum.x),
			maxf(label_height, minimum.y)
		)

		var star_center_x: float = (
			center_x
			+ float(i - 1) * star_spacing
		)

		star.position = Vector2(
			star_center_x - actual_label_size.x * 0.5,
			center_y - actual_label_size.y * 0.5
		)

		star.size = actual_label_size


# ==================================================
# REFRESH SAVED STARS
# ==================================================

func refresh_stars() -> void:

	if Engine.is_editor_hint():
		return

	var count: int = 0

	if show_current_run:

		count = ProgressManager.current_run_stars

	else:

		count = ProgressManager.get_level_stars(
			ProgressManager.current_difficulty,
			level_id
		)

	set_stars(count)


# ==================================================
# DISPLAY STAR RATINGS
# ==================================================

func set_stars(star_count: int) -> void:

	var count: int = clampi(
		star_count,
		0,
		3
	)

	var stars: Array[Label] = _get_stars()

	for i: int in range(stars.size()):

		var star: Label = stars[i]

		if i < count:

			star.text = "★"

			star.add_theme_color_override(
				"font_color",
				GOLD
			)

		else:

			star.text = "☆"

			star.add_theme_color_override(
				"font_color",
				WHITE
			)

