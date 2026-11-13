extends CanvasLayer
# Independent adaptation of the original Cafeteria liquid nutrition UI.
@export var display_position := Vector2(800, 20)
@export_range(1, 5, 1) var pixel_scale: int = 1
@export_range(0, 60, 1) var bar_spacing: int = 8
@export var invert_bars: bool = true
@export var animate_liquid: bool = true
@export_range(0.05, 2.0, 0.05) var liquid_animation_duration: float = 0.35
const CATEGORY_NAMES = ["GO", "GLOW", "GROW"]
const CATEGORY_COLORS = [Color("#F5C842"), Color("#86F456"), Color("#F47C69")]

class PixelNutritionBar extends Control:

	var bar_color: Color = Color.WHITE

	var current_value: float = 100.0
	var maximum_value: float = 100.0

	var displayed_value: float = 100.0:
		set(value):
			displayed_value = value
			queue_redraw()

	var deficient: bool = false
	var special_active: bool = false
	var critical_active: bool = false

	var pixel_size: int = 1
	var inverted: bool = true

	var animation_enabled: bool = true
	var animation_duration: float = 0.35

	var active_tween: Tween = null

	const WIDTH: int = 42
	const HEIGHT: int = 112

	const DARK: Color = Color("#192635")
	const OUTLINE: Color = Color("#111D29")
	const METAL: Color = Color("#46536A")
	const METAL_LIGHT: Color = Color("#768099")
	const METAL_SHADOW: Color = Color("#30394D")


	# ==================================================
	# SETUP
	# ==================================================

	func setup(
		color_value: Color,
		scale_value: int,
		invert_value: bool,
		animate_value: bool,
		duration_value: float
	) -> void:

		bar_color = color_value
		pixel_size = scale_value
		inverted = invert_value

		animation_enabled = animate_value
		animation_duration = duration_value

		custom_minimum_size = Vector2(
			WIDTH * pixel_size,
			HEIGHT * pixel_size
		)

		mouse_filter = Control.MOUSE_FILTER_IGNORE

		queue_redraw()


	# ==================================================
	# UPDATE NUTRITION
	# ==================================================

	func update_state(
		value: float,
		maximum: float,
		is_deficient: bool,
		is_special: bool,
		is_critical: bool,
		immediate: bool = false
	) -> void:

		maximum_value = maxf(maximum, 1.0)

		var new_value: float = clampf(
			value,
			0.0,
			maximum_value
		)

		var value_changed: bool = (
			not is_equal_approx(current_value, new_value)
		)

		current_value = new_value

		deficient = is_deficient
		special_active = is_special
		critical_active = is_critical

		if immediate or not animation_enabled:

			if active_tween != null:
				if active_tween.is_valid():
					active_tween.kill()

			displayed_value = current_value
			return

		if value_changed:
			_animate_to_value(current_value)
		else:
			queue_redraw()


	# ==================================================
	# SMOOTH ANIMATION
	# ==================================================

	func _animate_to_value(target_value: float) -> void:

		if active_tween != null:
			if active_tween.is_valid():
				active_tween.kill()

		active_tween = create_tween()

		active_tween.set_trans(Tween.TRANS_LINEAR)

		active_tween.set_ease(Tween.EASE_IN_OUT)

		active_tween.tween_property(
			self,
			"displayed_value",
			target_value,
			maxf(animation_duration, 0.01)
		)


	# ==================================================
	# DRAW
	# ==================================================

	func _draw() -> void:

		# Draw the entire frame upside down.
		_set_frame_transform()

		_draw_frame()

		# Liquid is drawn independently.
		# It always drains from top to bottom.
		_set_normal_transform()

		_draw_liquid()

		# Frame decorations remain inverted.
		_set_frame_transform()

		_draw_frame_details()
		_draw_status_effect()

		# Reset transformation.
		draw_set_transform(
			Vector2.ZERO,
			0.0,
			Vector2.ONE
		)


	# ==================================================
	# DRAW TRANSFORMS
	# ==================================================

	func _set_frame_transform() -> void:

		if inverted:

			draw_set_transform(
				Vector2(0, HEIGHT * pixel_size),
				0.0,
				Vector2(pixel_size, -pixel_size)
			)

		else:
			_set_normal_transform()


	func _set_normal_transform() -> void:

		draw_set_transform(
			Vector2.ZERO,
			0.0,
			Vector2(pixel_size, pixel_size)
		)


	# ==================================================
	# PIXEL RECTANGLE
	# ==================================================

	func _pixel_rect(
		x: float,
		y: float,
		width: float,
		height: float,
		color_value: Color
	) -> void:

		draw_rect(
			Rect2(x, y, width, height),
			color_value,
			true
		)


	# ==================================================
	# METALLIC FRAME
	# ==================================================

	func _draw_frame() -> void:

		# Outer silhouette
		_pixel_rect(12, 1, 18, 3, OUTLINE)
		_pixel_rect(9, 4, 24, 4, OUTLINE)
		_pixel_rect(7, 8, 28, 80, OUTLINE)

		# Left metallic border
		_pixel_rect(8, 8, 4, 80, METAL)
		_pixel_rect(9, 10, 1, 76, METAL_LIGHT)

		# Right metallic border
		_pixel_rect(30, 8, 4, 80, METAL_SHADOW)
		_pixel_rect(31, 10, 1, 76, METAL)

		# Upper cap
		_pixel_rect(12, 3, 18, 4, METAL)
		_pixel_rect(15, 2, 12, 2, METAL_LIGHT)

		# Inner chamber
		_pixel_rect(12, 10, 18, 76, DARK)
		_pixel_rect(14, 11, 14, 72, OUTLINE)

		# Bottom housing
		_pixel_rect(5, 86, 32, 5, OUTLINE)
		_pixel_rect(3, 91, 36, 12, OUTLINE)

		_pixel_rect(6, 90, 30, 12, METAL)
		_pixel_rect(8, 92, 26, 9, METAL_SHADOW)

		# Rounded silhouette
		_pixel_rect(9, 103, 24, 4, OUTLINE)
		_pixel_rect(13, 107, 16, 3, OUTLINE)


	# ==================================================
	# LIQUID FILL
	# ==================================================

	func _draw_liquid() -> void:

		var fraction: float = clampf(
			displayed_value / maximum_value,
			0.0,
			1.0
		)

		# Chamber is 70 pixels tall.
		var liquid_height: float = (
			70.0 * fraction
		)

		if liquid_height <= 0.0:
			return

		# IMPORTANT:
		#
		# When the frame is inverted, its chamber
		# moves to Y = 30 through Y = 100.
		#
		# When upright, the liquid chamber is
		# Y = 12 through Y = 82.
		#
		# Liquid remains anchored at the BOTTOM.
		# Therefore, decreasing nutrition lowers
		# the liquid surface from TOP to BOTTOM.

		var chamber_bottom: float = 82.0

		if inverted:
			chamber_bottom = 100.0

		var liquid_top: float = (
			chamber_bottom - liquid_height
		)

		var liquid_color: Color = bar_color

		if deficient:
			liquid_color = bar_color.darkened(0.30)

		# ------------------------------------------
		# MAIN LIQUID
		# ------------------------------------------

		_pixel_rect(
			15,
			liquid_top,
			12,
			liquid_height,
			liquid_color
		)

		# ------------------------------------------
		# LEFT SHADING
		# ------------------------------------------

		_pixel_rect(
			15,
			liquid_top,
			2,
			liquid_height,
			liquid_color.darkened(0.18)
		)

		# ------------------------------------------
		# RIGHT HIGHLIGHT
		# ------------------------------------------

		_pixel_rect(
			25,
			liquid_top,
			2,
			liquid_height,
			liquid_color.lightened(0.18)
		)

		# ------------------------------------------
		# LIQUID TOP SURFACE
		# ------------------------------------------

		_pixel_rect(
			16,
			liquid_top,
			10,
			minf(2.0, liquid_height),
			liquid_color.lightened(0.25)
		)

		# ------------------------------------------
		# PIXEL REFLECTIONS
		# ------------------------------------------

		if liquid_height >= 12.0:

			_pixel_rect(
				18,
				liquid_top + 4,
				3,
				5,
				liquid_color.lightened(0.45)
			)

		if liquid_height >= 26.0:

			_pixel_rect(
				21,
				liquid_top + 16,
				3,
				4,
				liquid_color.lightened(0.32)
			)

		if liquid_height >= 42.0:

			_pixel_rect(
				17,
				liquid_top + 31,
				2,
				6,
				liquid_color.lightened(0.38)
			)


	# ==================================================
	# FRAME DETAILS
	# ==================================================

	func _draw_frame_details() -> void:

		# Attachment
		_pixel_rect(10, 87, 22, 5, METAL_LIGHT)
		_pixel_rect(12, 89, 18, 3, METAL_SHADOW)

		# Circular housing
		_pixel_rect(11, 93, 20, 10, OUTLINE)
		_pixel_rect(14, 94, 14, 8, METAL_LIGHT)

		_pixel_rect(
			16,
			96,
			10,
			5,
			bar_color.darkened(0.25)
		)

		# Center emblem
		_pixel_rect(19, 95, 4, 3, OUTLINE)
		_pixel_rect(19, 101, 4, 2, OUTLINE)
		_pixel_rect(16, 98, 3, 3, OUTLINE)
		_pixel_rect(23, 98, 3, 3, OUTLINE)

		# Bottom trim
		_pixel_rect(13, 105, 16, 3, METAL)
		_pixel_rect(16, 108, 10, 2, METAL_SHADOW)


	# ==================================================
	# STATUS EFFECTS
	# ==================================================

	func _draw_status_effect() -> void:

		if critical_active:

			_pixel_rect(
				8, 8, 2, 75,
				Color("#FF5275")
			)

			_pixel_rect(
				32, 8, 2, 75,
				Color("#FF5275")
			)

		elif special_active:

			_pixel_rect(
				8, 8, 2, 75,
				Color("#FFF1A8")
			)

			_pixel_rect(
				32, 8, 2, 75,
				Color("#FFF1A8")
			)

		elif deficient:

			_pixel_rect(
				8, 8, 2, 75,
				Color("#F09948")
			)


# ==================================================

var root_control: Control
var bars: Array[PixelNutritionBar] = []
var status_labels: Array[Label] = []
var selected_monster: Level3NutritionMonster

func _ready() -> void:
	layer = 10
	root_control = Control.new()
	root_control.name = "SelectedMonsterNutrition"
	root_control.position = display_position
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)
	var row := HBoxContainer.new()
	row.name = "LiquidBars"
	row.add_theme_constant_override("separation", bar_spacing)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(row)
	for i in range(3):
		var column := VBoxContainer.new()
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(column)
		var label := Label.new()
		label.text = CATEGORY_NAMES[i]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 12)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(label)
		var bar := PixelNutritionBar.new()
		bar.name = CATEGORY_NAMES[i] + "Bar"
		column.add_child(bar)
		bar.setup(CATEGORY_COLORS[i], pixel_scale, invert_bars, animate_liquid, liquid_animation_duration)
		bars.append(bar)
		var status := Label.new()
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status.add_theme_font_size_override("font_size", 10)
		status.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(status)
		status_labels.append(status)
	root_control.hide()

func show_monster(monster: Level3NutritionMonster) -> void:
	if monster == selected_monster and is_instance_valid(monster) and monster.is_active:
		return
	_disconnect_monster()
	selected_monster = monster
	if not is_instance_valid(monster) or not monster.is_active:
		root_control.hide()
		return
	monster.nutrition_changed.connect(_on_nutrition_changed)
	monster.tree_exiting.connect(_clear_selection)
	root_control.show()
	_refresh(true)

func _disconnect_monster() -> void:
	if is_instance_valid(selected_monster):
		if selected_monster.nutrition_changed.is_connected(_on_nutrition_changed):
			selected_monster.nutrition_changed.disconnect(_on_nutrition_changed)
		if selected_monster.tree_exiting.is_connected(_clear_selection):
			selected_monster.tree_exiting.disconnect(_clear_selection)

func _clear_selection() -> void:
	show_monster(null)

func _on_nutrition_changed(_monster: Level3NutritionMonster) -> void:
	_refresh(false)

func _refresh(immediate: bool) -> void:
	if not is_instance_valid(selected_monster):
		_clear_selection()
		return
	var values := selected_monster.get_nutrition_values()
	var locks := selected_monster.get_locked_values()
	for i in range(3):
		var value: float = values[CATEGORY_NAMES[i]]
		var locked: bool = locks[CATEGORY_NAMES[i]]
		bars[i].update_state(value, 100.0, value <= 25.0, locked, false, immediate)
		status_labels[i].text = "LOCKED" if locked else "%d%%" % int(value)
		status_labels[i].modulate = Color("#FFF1A8") if locked else Color.WHITE

func _exit_tree() -> void:
	_disconnect_monster()
