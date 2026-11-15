extends CanvasLayer
class_name ThrowChargeUI

@export_group("Position")
@export var follow_nutrition_ui: bool = true
@export var manual_position: Vector2 = Vector2(800, 136)
@export_range(0, 30, 1) var vertical_gap: int = 4

@export_group("Appearance")
@export_range(1, 5, 1) var pixel_scale: int = 1
@export_range(0, 30, 1) var bar_spacing: int = 8
@export var show_selection_outline: bool = true
@export var show_ready_glow: bool = true

@export_group("Player Boost Indicators")
@export var show_player_buffs: bool = true
@export_range(0, 40, 1) var boost_vertical_gap: int = 10
@export_range(100, 260, 1) var boost_panel_width: int = 160
@export_range(16, 36, 1) var boost_row_height: int = 22
@export_range(0, 12, 1) var boost_row_spacing: int = 3
@export_range(8, 20, 1) var boost_font_size: int = 11

@export_group("Debugging")
@export var show_debug_messages: bool = false

const INDICATOR_SIZE := Vector2(34, 12)
const MANUAL_SLOT_WIDTH := 42.0
const FRAME_DARK := Color("#111D29")
const FRAME_MID := Color("#46536A")
const FRAME_LIGHT := Color("#8996A8")
const EMPTY_COLOR := Color("#192635")
const BUFF_PANEL_COLOR := Color(0.07, 0.11, 0.17, 0.92)
const BUFF_TEXT_COLOR := Color("#F5F7FA")
const BOOST_ROWS := [
	[CafeteriaItemThrowController.BUFF_DAMAGE, "DMG +", Color("#F47C69")],
	[CafeteriaItemThrowController.BUFF_COOLDOWN, "CD −", Color("#74B9FF")],
	[CafeteriaItemThrowController.BUFF_CHARGE, "CHG +", Color("#F5C842")],
]

var charge_system: ThrowChargeSystem
var throw_controller: CafeteriaItemThrowController
var display_control: Control
var nutrition_bars: Dictionary = {}


func _ready() -> void:
	set_process(false)
	layer = 21
	var battle := get_parent()
	charge_system = battle.get_node_or_null("ThrowChargeSystem") as ThrowChargeSystem
	throw_controller = battle.get_node_or_null("ItemThrowController") as CafeteriaItemThrowController
	if charge_system == null or throw_controller == null:
		push_error("[ThrowChargeUI] ThrowChargeSystem or ItemThrowController missing.")
		return

	display_control = Control.new()
	display_control.name = "ChargeIndicators"
	display_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	display_control.draw.connect(_draw_indicators)
	add_child(display_control)

	var nutrition_ui := battle.get_node_or_null("NutritionUI") as CanvasLayer
	if follow_nutrition_ui and nutrition_ui != null:
		nutrition_bars = nutrition_ui.get("bars")
		layer = nutrition_ui.layer + 1
		nutrition_ui.visibility_changed.connect(_follow_visibility.bind(nutrition_ui))
		_follow_visibility(nutrition_ui)
		for bar: Control in nutrition_bars.values():
			bar.item_rect_changed.connect(display_control.queue_redraw)

	charge_system.charge_changed.connect(_on_charge_changed)
	throw_controller.throw_category_selected.connect(_on_category_selected)
	throw_controller.combat_buff_started.connect(_refresh_boost_display.unbind(3))
	throw_controller.combat_buff_expired.connect(_refresh_boost_display.unbind(1))
	get_viewport().size_changed.connect(display_control.queue_redraw)
	var coordinator := battle.get_node_or_null("CafeteriaLevel1Controller") as CafeteriaLevel1Controller
	if coordinator != null:
		coordinator.level_systems_started.connect(_refresh_boost_display)
		coordinator.level_systems_stopped.connect(_refresh_boost_display)
	if show_debug_messages:
		_refresh_boost_display()
	print("[ThrowChargeUI] Three charge indicators ready.")


func _follow_visibility(nutrition_ui: CanvasLayer) -> void:
	display_control.visible = nutrition_ui.visible
	_refresh_boost_display()


func _on_charge_changed(category: int, current_value: int, _previous_value: int) -> void:
	display_control.queue_redraw()
	if show_debug_messages:
		print("[ThrowChargeUI] ", charge_system.get_category_name(category), " = ", current_value)


func _on_category_selected(_category: int) -> void:
	display_control.queue_redraw()


func _get_indicator_rect(category: int) -> Rect2:
	var size := INDICATOR_SIZE * pixel_scale
	var position := manual_position + Vector2(
		category * (MANUAL_SLOT_WIDTH * pixel_scale + bar_spacing)
		+ (MANUAL_SLOT_WIDTH * pixel_scale - size.x) * 0.5, 0
	)
	var bar := nutrition_bars.get(category) as Control
	if bar != null:
		var rect := bar.get_global_rect()
		var scale_factor := rect.size.x / MANUAL_SLOT_WIDTH
		size = INDICATOR_SIZE * scale_factor
		position = Vector2(rect.get_center().x - size.x * 0.5, rect.end.y + vertical_gap)
	return Rect2(position.round(), size.round())


func _draw_indicators() -> void:
	for category in ThrowChargeSystem.ThrowCategory.values():
		_draw_indicator(category, _get_indicator_rect(category))
	if show_player_buffs and charge_system.system_enabled:
		_draw_player_buffs()


func _draw_indicator(category: int, rect: Rect2) -> void:
	var color := throw_controller._get_category_color(category)
	var scale_factor := rect.size.x / INDICATOR_SIZE.x
	var fraction := charge_system.get_charge_percent(category)
	var ready_to_throw := charge_system.is_throw_ready(category)

	if show_ready_glow and ready_to_throw:
		display_control.draw_rect(rect.grow(3), Color(color, 0.55), false, 2)
	if show_selection_outline and category == throw_controller.selected_category:
		display_control.draw_rect(rect.grow(2), color, false, 1)

	display_control.draw_rect(rect, FRAME_DARK)
	display_control.draw_rect(rect.grow(-2 * scale_factor), FRAME_MID)
	var track := rect.grow(-4 * scale_factor)
	display_control.draw_rect(track, EMPTY_COLOR)
	if fraction > 0.0:
		var fill := Rect2(track.position, Vector2(roundf(track.size.x * fraction), track.size.y))
		display_control.draw_rect(fill, color)
	var top_highlight := Rect2(
		Vector2(track.position.x, rect.position.y + scale_factor),
		Vector2(track.size.x, scale_factor)
	)
	display_control.draw_rect(top_highlight, FRAME_LIGHT)
	if ready_to_throw:
		var ready_pixel := Vector2(rect.end.x - 4 * scale_factor, rect.position.y + 2 * scale_factor)
		display_control.draw_rect(Rect2(ready_pixel, Vector2.ONE * 2 * scale_factor), Color.WHITE)


func _refresh_boost_display() -> void:
	set_process(
		show_player_buffs and display_control.visible and charge_system.system_enabled
		and not throw_controller.get_active_food_buffs().is_empty()
	)
	display_control.queue_redraw()


func _process(_delta: float) -> void:
	display_control.queue_redraw()


func _get_boost_panel_rect() -> Rect2:
	var left := INF
	var bottom := -INF
	for category in ThrowChargeSystem.ThrowCategory.values():
		var meter := _get_indicator_rect(category)
		left = minf(left, meter.position.x)
		bottom = maxf(bottom, meter.end.y)
	var viewport := get_viewport().get_visible_rect()
	var width := minf(boost_panel_width, viewport.size.x)
	var x := clampf(left, viewport.position.x, viewport.end.x - width)
	return Rect2(roundf(x), roundf(bottom + boost_vertical_gap), width, boost_row_height)


func _draw_player_buffs() -> void:
	var row := _get_boost_panel_rect()
	for boost in BOOST_ROWS:
		var remaining := throw_controller.get_food_buff_remaining(boost[0])
		if remaining <= 0.0:
			continue
		var strength := throw_controller.get_food_buff_strength(boost[0])
		var percent := str(roundi(strength)) if is_equal_approx(strength, roundf(strength)) else "%.1f" % strength
		_draw_boost_row(row, boost[1] + percent + "%", remaining, boost[2])
		row.position.y += boost_row_height + boost_row_spacing


func _draw_boost_row(row: Rect2, title: String, remaining: float, accent: Color) -> void:
	display_control.draw_rect(row, BUFF_PANEL_COLOR)
	display_control.draw_rect(row, FRAME_MID, false, 1.0)
	display_control.draw_rect(Rect2(row.position + Vector2(2, 2), Vector2(3, row.size.y - 4)), accent)

	var font := ThemeDB.fallback_font
	var baseline := roundf(row.get_center().y + (font.get_ascent(boost_font_size) - font.get_descent(boost_font_size)) * 0.5)
	display_control.draw_string(
		font, Vector2(row.position.x + 11, baseline), title,
		HORIZONTAL_ALIGNMENT_LEFT, -1, boost_font_size, BUFF_TEXT_COLOR
	)
	var timer_text := "%.1fs" % (ceilf(remaining * 10.0) / 10.0)
	var timer_width := font.get_string_size(timer_text, HORIZONTAL_ALIGNMENT_LEFT, -1, boost_font_size).x
	display_control.draw_string(
		font, Vector2(row.end.x - timer_width - 7, baseline), timer_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, boost_font_size, accent
	)
