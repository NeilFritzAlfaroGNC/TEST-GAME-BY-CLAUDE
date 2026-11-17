extends Control

# ==================================================
# LEVEL STAR DISPLAY
# ==================================================
# Shared by Cafeteria, Canteen, Victory Screen,
# and now Scene3.
#
# NORMAL USE:
#   - CafeteriaStars
#   - CanteenStars
#   - Victory screen stars
#
# SCENE3 USE:
#   - Turn on "Use Scene3 Custom Layout"
#   - This lets you reduce spacing ONLY for Scene3
# ==================================================

@export_group("Level Settings")
@export var level_id: String = "cafeteria_level_1"
@export var show_current_run: bool = false

# ==================================================
# SCENE3 ONLY LAYOUT
# ==================================================
# Turn this ON only for Scene3Stars.
#
# scene3_star_group_width_ratio:
# - 1.0 = stars spread across full width
# - 0.6 = stars closer together
# - 0.5 = even closer together
# ==================================================

@export_group("Scene3 Only")
@export var use_scene3_custom_layout: bool = false

@export_node_path("Control")
var scene3_button_path: NodePath = NodePath("../Scene3")

@export_range(0.20, 1.00, 0.05)
var scene3_star_group_width_ratio: float = 0.60

@export_range(-200.0, 200.0, 1.0)
var scene3_layout_offset_x: float = 0.0

@export_range(-200.0, 200.0, 1.0)
var scene3_layout_offset_y: float = 0.0

@export_range(0.30, 1.50, 0.05)
var scene3_star_size_factor: float = 0.75

@export var auto_refresh_scene3_layout: bool = true


@onready var stars_root: Control = $Stars
@onready var star_1: Label = $Stars/Star1
@onready var star_2: Label = $Stars/Star2
@onready var star_3: Label = $Stars/Star3

const GOLD: Color = Color("#E5B94B")
const WHITE: Color = Color("#FFFFFF")

var scene3_button: Control = null
var _last_layout: Array = []


func _ready() -> void:
	# Prevent map click blocking.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stars_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	star_1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	star_2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	star_3.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if use_scene3_custom_layout:
		scene3_button = (
			get_node_or_null(scene3_button_path) as Control
		)

		if not is_instance_valid(scene3_button):
			push_warning(
				"[Stars] Scene3 button not found at path: "
				+ String(scene3_button_path)
			)
		else:
			_apply_scene3_custom_layout()

	refresh_stars()

	set_process(
		use_scene3_custom_layout
		and auto_refresh_scene3_layout
	)


func _process(_delta: float) -> void:
	if not use_scene3_custom_layout:
		return

	if not is_instance_valid(scene3_button):
		return

	if _last_layout != [scene3_button.size, scene3_star_group_width_ratio, scene3_layout_offset_x, scene3_layout_offset_y, scene3_star_size_factor]:
		_apply_scene3_custom_layout()


# ==================================================
# REFRESH STAR DISPLAY
# ==================================================

func refresh_stars() -> void:
	var star_count: int = 0

	if show_current_run:
		star_count = ProgressManager.current_run_stars

		print(
			"[Stars] Victory | Current run: ",
			star_count
		)
	else:
		star_count = ProgressManager.get_level_stars(
			ProgressManager.current_difficulty,
			level_id
		)

		print(
			"[Stars] Level: ",
			level_id,
			" | Difficulty: ",
			ProgressManager.current_difficulty,
			" | Saved stars: ",
			star_count
		)

	set_stars(star_count)


# ==================================================
# DISPLAY STARS
# ==================================================

func set_stars(star_count: int) -> void:
	var count: int = clampi(star_count, 0, 3)

	update_star(star_1, 1, count)
	update_star(star_2, 2, count)
	update_star(star_3, 3, count)


# ==================================================
# UPDATE INDIVIDUAL STAR
# ==================================================

func update_star(
	star: Label,
	star_number: int,
	star_count: int
) -> void:
	if star_number <= star_count:
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


# ==================================================
# SCENE3 CUSTOM LAYOUT
# ==================================================
# Makes the 3 stars take up only part of the
# Scene3 width, so spacing becomes smaller.
# ==================================================

func _apply_scene3_custom_layout() -> void:
	if not is_instance_valid(scene3_button):
		return

	var button_size: Vector2 = scene3_button.size

	if button_size.x <= 0.0 or button_size.y <= 0.0:
		return

	_last_layout = [button_size, scene3_star_group_width_ratio, scene3_layout_offset_x, scene3_layout_offset_y, scene3_star_size_factor]

	# Preserve the outer area's map position and dimensions.
	var group_width := button_size.x * clampf(scene3_star_group_width_ratio, 0.20, 1.00)
	var group_height := button_size.y
	var section_width := group_width / 3.0
	var font_size := maxi(1, floori(minf(section_width, group_height) * scene3_star_size_factor))
	var font := star_1.get_theme_font("font")
	while font_size > 1 and (
		font.get_height(font_size) > group_height
		or font.get_string_size("★", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > section_width
		or font.get_string_size("☆", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > section_width
	):
		font_size -= 1

	# HBoxContainer manages its children, so narrow the container itself.
	var container := stars_root as HBoxContainer
	container.add_theme_constant_override("separation", 0)
	for star in [star_1, star_2, star_3]:
		star.custom_minimum_size = Vector2.ZERO
		star.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		star.size_flags_stretch_ratio = 1.0
		star.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		star.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		star.add_theme_font_size_override("font_size", font_size)

	container.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	container.position = Vector2(
		(size.x - group_width) * 0.5 + scene3_layout_offset_x,
		scene3_layout_offset_y
	)
	container.size = Vector2(group_width, group_height)
