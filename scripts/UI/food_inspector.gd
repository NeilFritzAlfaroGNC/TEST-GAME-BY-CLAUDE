
extends CanvasLayer

# ==================================================
# GO FOOD INSPECTOR
#
# Created automatically by battle_scene_cafeteria.gd.
#
# Supports:
# - Ordinary GO foods
# - Combined GO foods (x2 and x4)
# - Total instant energy restoration
# - Energy over time
# - Regeneration boost
# - Energy discount
# - Energy protection
#
# Public interface:
# show_food(food, screen_position, pinned)
# hide_inspector()
#
# Does not modify or consume food.
# ==================================================

const PANEL_WIDTH: float = 360.0
const PANEL_HEIGHT: float = 430.0

const COLOR_BACKGROUND: Color = Color(
	0.10, 0.13, 0.19, 0.97
)

const COLOR_SECTION: Color = Color(
	0.17, 0.21, 0.28, 1.0
)

const COLOR_ACCENT: Color = Color(
	0.49, 0.80, 1.0
)

const COLOR_SECONDARY: Color = Color(
	0.72, 0.77, 0.83
)

var inspector_open: bool = false
var inspected_food: FoodData = null

var overlay: Control = null
var inspector_panel: PanelContainer = null
var content: VBoxContainer = null


# ==================================================
# READY
# ==================================================

func _ready() -> void:
	layer = 90
	_create_interface()
	hide_inspector()


# ==================================================
# CREATE INTERFACE
# ==================================================

func _create_interface() -> void:
	overlay = Control.new()
	overlay.name = "GOInspectorOverlay"
	add_child(overlay)

	overlay.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	inspector_panel = PanelContainer.new()
	inspector_panel.name = "GOInspectorPanel"
	overlay.add_child(inspector_panel)

	inspector_panel.custom_minimum_size = Vector2(
		PANEL_WIDTH,
		PANEL_HEIGHT
	)

	inspector_panel.mouse_filter = (
		Control.MOUSE_FILTER_STOP
	)

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = COLOR_BACKGROUND
	style.set_corner_radius_all(12)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 16.0
	style.content_margin_bottom = 16.0

	inspector_panel.add_theme_stylebox_override(
		"panel",
		style
	)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "Scroll"
	inspector_panel.add_child(scroll)

	scroll.custom_minimum_size = Vector2(
		PANEL_WIDTH - 32.0,
		PANEL_HEIGHT - 32.0
	)

	scroll.horizontal_scroll_mode = (
		ScrollContainer.SCROLL_MODE_DISABLED
	)

	content = VBoxContainer.new()
	content.name = "Content"
	scroll.add_child(content)

	content.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)

	content.add_theme_constant_override(
		"separation",
		10
	)


# ==================================================
# SHOW FOOD
# ==================================================

func show_food(
	food: FoodData,
	screen_position: Vector2,
	_pinned: bool = false
) -> void:
	if not is_instance_valid(food):
		return

	if not food.has_category(FoodData.FoodCategory.GO):
		return

	inspected_food = food
	inspector_open = true

	_clear_content()
	_build_food_details(food)

	overlay.show()

	# Keep the panel within the viewport.
	var viewport_size: Vector2 = (
		get_viewport().get_visible_rect().size
	)

	var available_width: float = maxf(
		160.0,
		minf(PANEL_WIDTH, viewport_size.x - 20.0)
	)

	var available_height: float = maxf(
		160.0,
		minf(PANEL_HEIGHT, viewport_size.y - 20.0)
	)

	inspector_panel.custom_minimum_size = Vector2(
		available_width,
		available_height
	)

	var desired_position: Vector2 = (
		screen_position + Vector2(16.0, 16.0)
	)

	desired_position.x = clampf(
		desired_position.x,
		0.0,
		maxf(
			0.0,
			viewport_size.x - available_width
		)
	)

	desired_position.y = clampf(
		desired_position.y,
		0.0,
		maxf(
			0.0,
			viewport_size.y - available_height
		)
	)

	inspector_panel.position = desired_position

	print(
		"[GO Inspector] Opened: ",
		food.food_name
	)


# ==================================================
# HIDE INSPECTOR
# ==================================================

func hide_inspector() -> void:
	inspector_open = false
	inspected_food = null

	if is_instance_valid(overlay):
		overlay.hide()


# ==================================================
# INPUT
# ==================================================

func _input(event: InputEvent) -> void:
	if not inspector_open:
		return

	if event is InputEventKey:
		var key_event: InputEventKey = (
			event as InputEventKey
		)

		if key_event.pressed:
			if key_event.keycode == KEY_ESCAPE:
				hide_inspector()
				get_viewport().set_input_as_handled()


# ==================================================
# CLEAR PREVIOUS FOOD INFORMATION
# ==================================================

func _clear_content() -> void:
	if not is_instance_valid(content):
		return

	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()


# ==================================================
# DISPLAY FOOD DETAILS
# ==================================================

func _build_food_details(food: FoodData) -> void:
	var display_name: String = food.food_name

	if display_name.strip_edges().is_empty():
		display_name = food.name

	if food.is_combined():
		display_name += (
			" ×" + str(food.original_food_count)
		)

	var header: HBoxContainer = HBoxContainer.new()
	content.add_child(header)

	var title_container: VBoxContainer = (
		VBoxContainer.new()
	)

	title_container.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)

	header.add_child(title_container)

	_add_label(
		title_container,
		display_name,
		23,
		Color.WHITE
	)

	_add_label(
		title_container,
		"GO FOOD • "
		+ str(food.original_food_count)
		+ " original ingredient(s)",
		12,
		COLOR_SECONDARY
	)

	var close_button: Button = Button.new()
	close_button.text = "X"
	close_button.pressed.connect(hide_inspector)
	header.add_child(close_button)

	content.add_child(HSeparator.new())

	_add_label(
		content,
		"TOTAL GO EFFECTS",
		16,
		COLOR_ACCENT
	)

	var effects: Array[Dictionary] = (
		food.get_all_go_effects()
	)

	if effects.is_empty():
		_add_label(
			content,
			"No enabled GO effects.",
			14,
			COLOR_SECONDARY
		)
		return

	# ----------------------------------------------
	# TOTAL INSTANT RESTORATION
	# ----------------------------------------------

	var total_restore: float = 0.0

	for effect in effects:
		if str(effect.get("type", "")) == "instant_restore":
			total_restore += float(
				effect.get("amount", 0.0)
			)

	if total_restore > 0.0:
		_add_effect_card(
			"Instant Energy",
			"+" + _format_number(total_restore)
		)

	# ----------------------------------------------
	# ALL EFFECTS, INCLUDING INHERITED ONES
	# ----------------------------------------------

	_add_label(
		content,
		"INDIVIDUAL EFFECTS",
		16,
		COLOR_ACCENT
	)

	var effect_number: int = 0

	for effect in effects:
		effect_number += 1
		_add_individual_effect(
			effect,
			effect_number
		)

	content.add_child(HSeparator.new())

	if food.original_food_count == 1:
		_add_label(
			content,
			"Combination: Can combine with one ordinary GO food.",
			12,
			COLOR_SECONDARY
		)

	elif food.original_food_count == 2:
		_add_label(
			content,
			"Combination: Can combine with another ×2 GO food.",
			12,
			COLOR_SECONDARY
		)

	else:
		_add_label(
			content,
			"Combination: Maximum level reached.",
			12,
			COLOR_SECONDARY
		)


# ==================================================
# DISPLAY INDIVIDUAL EFFECTS
# ==================================================

func _add_individual_effect(
	effect: Dictionary,
	effect_number: int
) -> void:
	var effect_type: String = str(
		effect.get("type", "")
	)

	var effect_title: String = ""
	var effect_value: String = ""

	match effect_type:
		"instant_restore":
			effect_title = "Instant Energy"
			effect_value = (
				"+"
				+ _format_number(
					float(effect.get("amount", 0.0))
				)
			)

		"energy_over_time":
			effect_title = "Energy Over Time"
			effect_value = (
				"+"
				+ _format_number(
					float(effect.get("rate", 0.0))
				)
				+ "/sec for "
				+ _format_number(
					float(effect.get("duration", 0.0))
				)
				+ " sec"
			)

		"regeneration_boost":
			effect_title = "Regeneration Boost"
			effect_value = (
				"+"
				+ _format_number(
					float(effect.get("bonus", 0.0))
				)
				+ "/sec for "
				+ _format_number(
					float(effect.get("duration", 0.0))
				)
				+ " sec"
			)

		"energy_discount":
			effect_title = "Energy Discount"
			effect_value = (
				_format_number(
					float(effect.get("percent", 0.0))
				)
				+ "% for "
				+ _format_number(
					float(effect.get("duration", 0.0))
				)
				+ " sec"
			)

		"energy_protection":
			effect_title = "Energy Protection"
			effect_value = (
				str(int(effect.get("charges", 0)))
				+ " charge(s)"
			)

		_:
			effect_title = effect_type.capitalize()
			effect_value = str(effect)

	_add_effect_card(
		str(effect_number) + ". " + effect_title,
		effect_value
	)


# ==================================================
# EFFECT CARD
# ==================================================

func _add_effect_card(
	effect_title: String,
	effect_value: String
) -> void:
	var panel: PanelContainer = PanelContainer.new()
	content.add_child(panel)

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = COLOR_SECTION
	style.set_corner_radius_all(8)

	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 9.0
	style.content_margin_bottom = 9.0

	panel.add_theme_stylebox_override(
		"panel",
		style
	)

	var column: VBoxContainer = VBoxContainer.new()
	panel.add_child(column)

	_add_label(
		column,
		effect_title,
		14,
		Color.WHITE
	)

	_add_label(
		column,
		effect_value,
		13,
		COLOR_ACCENT
	)


# ==================================================
# LABEL HELPER
# ==================================================

func _add_label(
	parent_node: Node,
	message: String,
	font_size: int,
	font_color: Color
) -> Label:
	var text_label: Label = Label.new()
	text_label.text = message

	text_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)

	text_label.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)

	text_label.add_theme_font_size_override(
		"font_size",
		font_size
	)

	text_label.add_theme_color_override(
		"font_color",
		font_color
	)

	parent_node.add_child(text_label)

	return text_label


# ==================================================
# NUMBER FORMATTER
# ==================================================

func _format_number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(roundi(value))

	return str(snappedf(value, 0.01))
