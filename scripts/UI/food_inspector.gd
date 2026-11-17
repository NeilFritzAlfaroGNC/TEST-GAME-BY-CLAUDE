
extends CanvasLayer

# ==================================================
# FOOD INSPECTOR - GO / GLOW / GROW
# CAFETERIA LEVEL 1 - GODOT 4.7.1
# ==================================================
#
# Preserves the existing:
# - Dark inspector panel
# - Scrollable cards
# - GO energy effects
# - GROW effects
# - Combination labels
# - show_food() interface
# - hide_inspector() interface
# - contains_screen_position() interface
#
# Cafeteria:
# - Ordinary GO / GLOW / GROW foods
# - Combined GO / GROW foods
# - Nutrition restoration
# - Throw Charge
# - Projectile damage
# - Active buff, duration and strength
# - Retained combined-food buffs
#
# Other scenes:
# - Existing GO-only inspection behavior
#
# Does not modify or consume food.
# ==================================================


const PANEL_WIDTH: float = 360.0
const PANEL_HEIGHT: float = 430.0

const LEVEL1_STATS_META: String = (
	"cafeteria_l1_combined_stats"
)

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

const COLOR_GO: Color = Color("#F5C842")
const COLOR_GLOW: Color = Color("#86F456")
const COLOR_GROW: Color = Color("#F47C69")


var inspector_open: bool = false
var inspected_food: FoodData = null

var overlay: Control = null
var inspector_panel: PanelContainer = null
var content: VBoxContainer = null
var scroll: ScrollContainer = null


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

	overlay.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

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

	scroll = ScrollContainer.new()
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
# SCENE IDENTIFICATION
# ==================================================

func _is_cafeteria() -> bool:

	var battle: Node = get_parent()

	return (
		battle != null
		and battle.has_node(
			"NutritionFoodBridge"
		)
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

	if food.is_queued_for_deletion():
		return

	if _is_cafeteria():

		if not food.has_level1_nutrition_category():
			return

	elif not food.has_category(
		FoodData.FoodCategory.GO
	):
		return

	inspected_food = food
	inspector_open = true

	_clear_content()
	_build_food_details(food)

	overlay.show()

	_resize_and_position(
		screen_position
	)

	print(
		"[FoodInspector] Opened: ",
		food.food_name,
		" | Combined: ",
		food.original_food_count
	)


# ==================================================
# SUPPORT OTHER BATTLE SCRIPT INTERFACE
# ==================================================

func open_inspector(food: FoodData) -> void:

	show_food(
		food,
		get_viewport().get_mouse_position(),
		true
	)


# ==================================================
# PANEL POSITION
# ==================================================

func _resize_and_position(
	screen_position: Vector2
) -> void:

	var viewport_size: Vector2 = (
		get_viewport().get_visible_rect().size
	)

	var available_width: float = maxf(
		64.0,
		minf(
			PANEL_WIDTH,
			viewport_size.x - 20.0
		)
	)

	var available_height: float = maxf(
		64.0,
		minf(
			PANEL_HEIGHT,
			viewport_size.y - 20.0
		)
	)

	inspector_panel.custom_minimum_size = Vector2(
		available_width,
		available_height
	)

	scroll.custom_minimum_size = Vector2(
		maxf(32.0, available_width - 32.0),
		maxf(32.0, available_height - 32.0)
	)

	inspector_panel.size = (
		inspector_panel.custom_minimum_size
	)

	scroll.set_deferred(
		"scroll_vertical",
		0
	)

	var position_to_use: Vector2 = (
		screen_position
		+ Vector2(16.0, 16.0)
	)

	position_to_use.x = clampf(
		position_to_use.x,
		0.0,
		maxf(
			0.0,
			viewport_size.x - available_width
		)
	)

	position_to_use.y = clampf(
		position_to_use.y,
		0.0,
		maxf(
			0.0,
			viewport_size.y - available_height
		)
	)

	inspector_panel.position = position_to_use


# ==================================================
# HIDE / HIT TEST / STATUS
# ==================================================

func hide_inspector() -> void:

	inspector_open = false
	inspected_food = null

	if is_instance_valid(overlay):
		overlay.hide()


func contains_screen_position(
	screen_position: Vector2
) -> bool:

	if not inspector_open:
		return false

	if not is_instance_valid(inspector_panel):
		return false

	return inspector_panel.get_global_rect().has_point(
		screen_position
	)


func is_inspector_open() -> bool:
	return inspector_open


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

		if (
			key_event.pressed
			and key_event.keycode == KEY_ESCAPE
		):

			hide_inspector()

			get_viewport().set_input_as_handled()


# ==================================================
# CLEAR PREVIOUS CONTENT
# ==================================================

func _clear_content() -> void:

	if not is_instance_valid(content):
		return

	for child in content.get_children():

		content.remove_child(child)
		child.queue_free()


# ==================================================
# BUILD FOOD DETAILS
# ==================================================

func _build_food_details(
	food: FoodData
) -> void:

	var display_name: String = food.food_name

	if display_name.strip_edges().is_empty():
		display_name = food.name

	if food.is_combined():

		display_name += (
			" ×"
			+ str(food.original_food_count)
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
		" / ".join(
			food.get_selected_category_names()
		)
		+ " FOOD • "
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

	# CAFETERIA-ONLY NUTRITION INFORMATION.

	if _is_cafeteria():

		_build_level1_stats(food)

		content.add_child(
			HSeparator.new()
		)

	# EXISTING GO INFORMATION.

	if food.has_category(
		FoodData.FoodCategory.GO
	):

		_build_go_effects(food)

	# EXISTING GROW INFORMATION.
	# Only added to this shared inspector in
	# the Cafeteria scene.

	if (
		_is_cafeteria()
		and food.has_category(
			FoodData.FoodCategory.GROW
		)
	):

		_build_grow_effects(food)

	# COMBINATION RULES.

	if _is_cafeteria():

		_build_combination_details(food)


# ==================================================
# GET CAFETERIA LEVEL 1 STATISTICS
# ==================================================
#
# This matches NutritionFoodBridge:
#
# Combined food: metadata
# Ordinary food: FoodData.get_all_level1_stats()
# ==================================================

func _get_level1_stats(
	food: FoodData
) -> Array[Dictionary]:

	var statistics: Array[Dictionary] = []

	if not is_instance_valid(food):
		return statistics

	if food.has_meta(LEVEL1_STATS_META):

		var stored: Variant = (
			food.get_meta(
				LEVEL1_STATS_META
			)
		)

		if stored is Array:

			for entry in stored:

				if entry is Dictionary:

					statistics.append(
						entry.duplicate(true)
					)

			return statistics

	return food.get_all_level1_stats()


# ==================================================
# BUILD LEVEL 1 STATISTICS
# ==================================================

func _build_level1_stats(
	food: FoodData
) -> void:

	_add_label(
		content,
		"CAFETERIA NUTRITION & THROWING",
		16,
		COLOR_ACCENT
	)

	var statistics: Array[Dictionary] = (
		_get_level1_stats(food)
	)

	if statistics.is_empty():

		_add_label(
			content,
			"No Level 1 statistics found.",
			13,
			COLOR_SECONDARY
		)

		return

	for stats in statistics:

		_build_category_stats(stats)


# ==================================================
# CATEGORY STATISTICS
# ==================================================

func _build_category_stats(
	stats: Dictionary
) -> void:

	var category: int = int(
		stats.get(
			"category",
			-1
		)
	)

	if category < 0 or category > 2:
		return

	var category_name: String = (
		_get_category_name(category)
	)

	var category_color: Color = (
		_get_category_color(category)
	)

	_add_label(
		content,
		category_name + " NUTRITION",
		15,
		category_color
	)

	var nutrition_amount: int = maxi(
		0,
		int(
			stats.get(
				"nutrition_restore",
				0
			)
		)
	)

	var charge_amount: int = maxi(
		0,
		int(
			stats.get(
				"charge_gain",
				0
			)
		)
	)

	var damage_amount: int = maxi(
		0,
		int(
			stats.get(
				"throw_damage",
				0
			)
		)
	)

	_add_effect_card(
		"Nutrition Restoration",
		"+" + str(nutrition_amount)
	)

	var charge_system := get_parent().get_node_or_null("ThrowChargeSystem") as ThrowChargeSystem
	var charge_text := "+%d" % charge_amount
	if charge_system != null:
		charge_text += " / %d" % charge_system.get_required_charge()
	_add_effect_card("Throw Charge Gain", charge_text)

	_add_effect_card(
		"Prepared Projectile Damage",
		str(damage_amount)
	)

	var buff_id: String = str(
		stats.get(
			"buff_id",
			""
		)
	).strip_edges()

	var buff_duration: float = maxf(
		0.0,
		float(
			stats.get(
				"buff_duration",
				0.0
			)
		)
	)

	var buff_strength: float = maxf(
		0.0,
		float(
			stats.get(
				"buff_strength",
				0.0
			)
		)
	)

	if buff_id.is_empty():

		_add_effect_card(
			"Projectile Buff",
			"None"
		)

	else:

		_add_effect_card(
			"Projectile Buff",
			buff_id.capitalize()
		)

		_add_effect_card(
			"Buff Duration",
			_format_number(buff_duration)
			+ " seconds"
		)

		var strength_text: String = (
			_format_number(buff_strength)
		)

		if buff_strength <= 0.0:

			strength_text = (
				"Default projectile strength"
			)

		_add_effect_card(
			"Buff Strength",
			strength_text
		)

	# SHOW PRESERVED BUFF OPTIONS.
	# Only one buff is selected by the current
	# prepared projectile system.

	var options_variant: Variant = (
		stats.get(
			"buff_options",
			[]
		)
	)

	if options_variant is Array:

		var options: Array = options_variant

		if options.is_empty():
			return

		_add_label(
			content,
			"INHERITED BUFFS",
			14,
			category_color
		)

		_add_label(
			content,
			"Only the selected buff is applied "
			+ "to the prepared projectile.",
			12,
			COLOR_SECONDARY
		)

		for index in range(options.size()):

			if not options[index] is Dictionary:
				continue

			var option: Dictionary = (
				options[index]
			)

			var option_food: String = str(
				option.get(
					"source_food_name",
					"Food"
				)
			)

			var option_buff: String = str(
				option.get(
					"buff_id",
					""
				)
			)

			var option_duration: float = float(
				option.get(
					"buff_duration",
					0.0
				)
			)

			var option_strength: float = float(
				option.get(
					"buff_strength",
					0.0
				)
			)

			var option_title: String = (
				option_food
				+ " — "
				+ option_buff.capitalize()
			)

			if index == 0:

				option_title += " (Selected)"

			else:

				option_title += " (Retained)"

			_add_effect_card(
				option_title,
				"Duration: "
				+ _format_number(option_duration)
				+ "s | Strength: "
				+ _format_number(option_strength)
			)


# ==================================================
# ORIGINAL GO EFFECTS
# ==================================================

func _build_go_effects(
	food: FoodData
) -> void:

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

	var total_restore: float = 0.0

	for effect in effects:

		if str(
			effect.get(
				"type",
				""
			)
		) == "instant_restore":

			total_restore += float(
				effect.get(
					"amount",
					0.0
				)
			)

	if total_restore > 0.0:

		_add_effect_card(
			"Instant Energy",
			"+" + _format_number(total_restore)
		)

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


# ==================================================
# ORIGINAL GO INDIVIDUAL EFFECTS
# ==================================================

func _add_individual_effect(
	effect: Dictionary,
	effect_number: int
) -> void:

	var effect_type: String = str(
		effect.get(
			"type",
			""
		)
	)

	var effect_title: String = ""
	var effect_value: String = ""

	match effect_type:

		"instant_restore":

			effect_title = "Instant Energy"

			effect_value = (
				"+"
				+ _format_number(
					float(
						effect.get(
							"amount",
							0.0
						)
					)
				)
			)

		"energy_over_time":

			effect_title = "Energy Over Time"

			effect_value = (
				"+"
				+ _format_number(
					float(
						effect.get(
							"rate",
							0.0
						)
					)
				)
				+ "/sec for "
				+ _format_number(
					float(
						effect.get(
							"duration",
							0.0
						)
					)
				)
				+ " sec"
			)

		"regeneration_boost":

			effect_title = "Regeneration Boost"

			effect_value = (
				"+"
				+ _format_number(
					float(
						effect.get(
							"bonus",
							0.0
						)
					)
				)
				+ "/sec for "
				+ _format_number(
					float(
						effect.get(
							"duration",
							0.0
						)
					)
				)
				+ " sec"
			)

		"energy_discount":

			effect_title = "Energy Discount"

			effect_value = (
				_format_number(
					float(
						effect.get(
							"percent",
							0.0
						)
					)
				)
				+ "% for "
				+ _format_number(
					float(
						effect.get(
							"duration",
							0.0
						)
					)
				)
				+ " sec"
			)

		"energy_protection":

			effect_title = "Energy Protection"

			effect_value = (
				str(
					int(
						effect.get(
							"charges",
							0
						)
					)
				)
				+ " charge(s)"
			)

		_:

			effect_title = (
				effect_type.capitalize()
			)

			effect_value = str(effect)

	_add_effect_card(
		str(effect_number)
		+ ". "
		+ effect_title,
		effect_value
	)


# ==================================================
# EXISTING GROW EFFECTS
# ==================================================

func _build_grow_effects(
	food: FoodData
) -> void:

	if not food.has_method(
		"get_all_grow_effects"
	):
		return

	_add_label(
		content,
		"EXISTING GROW EFFECTS",
		16,
		COLOR_ACCENT
	)

	var effects: Array[Dictionary] = (
		food.get_all_grow_effects()
	)

	if effects.is_empty():

		_add_label(
			content,
			"No enabled GROW effects.",
			14,
			COLOR_SECONDARY
		)

		return

	var effect_number: int = 0

	for effect in effects:

		effect_number += 1

		var effect_name: String = str(
			effect.get(
				"type",
				""
			)
		)

		var effect_value: float = float(
			effect.get(
				"value",
				0.0
			)
		)

		var duration: float = float(
			effect.get(
				"duration",
				0.0
			)
		)

		var uses: int = int(
			effect.get(
				"uses",
				1
			)
		)

		var value_text: String = (
			_format_number(effect_value)
		)

		match effect_name:

			"damage":
				value_text = (
					"+" + _format_number(effect_value)
				)

			"enlarge":
				value_text = (
					_format_number(effect_value) + "×"
				)

			"knockback":
				value_text = (
					"+" + _format_number(effect_value)
				)

			"stun":
				value_text = (
					_format_number(effect_value)
					+ " seconds"
				)

			"flopping":
				value_text = (
					str(int(effect_value))
					+ " unique hits"
				)

		_add_effect_card(
			str(effect_number)
			+ ". "
			+ effect_name.capitalize(),
			value_text
			+ " | Duration: "
			+ _format_number(duration)
			+ "s | Uses: "
			+ str(uses)
		)


# ==================================================
# COMBINATION INFORMATION
# ==================================================

func _build_combination_details(
	food: FoodData
) -> void:

	content.add_child(
		HSeparator.new()
	)

	var category_name: String = (
		" / ".join(
			food.get_selected_category_names()
		)
	)

	var message: String = ""
	var settings := FoodCombination.get_cafeteria_settings(food)
	if settings != null:
		message = _get_cafeteria_combination_hint(food, category_name, settings)
	elif food.original_food_count >= 4:

		message = (
			"Maximum combination level reached."
		)

	elif food.original_food_count == 2:

		if (
			category_name == "GO"
			or category_name == "GROW"
		):

			message = (
				"Can combine with another ×2 "
				+ category_name
				+ " food."
			)

		else:

			message = (
				"No combination available "
				+ "for this category."
			)

	elif (
		category_name == "GO"
		or category_name == "GROW"
	):

		message = (
			"Can combine with another ordinary "
			+ category_name
			+ " food."
		)

	else:

		message = (
			"No combination available "
			+ "for this category."
		)

	_add_label(
		content,
		"Combination: " + message,
		12,
		COLOR_SECONDARY
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
# CATEGORY HELPERS
# ==================================================

func _get_category_name(
	category: int
) -> String:

	match category:

		0:
			return "GO"

		1:
			return "GLOW"

		2:
			return "GROW"

	return "UNKNOWN"


func _get_category_color(
	category: int
) -> Color:

	match category:

		0:
			return COLOR_GO

		1:
			return COLOR_GLOW

		2:
			return COLOR_GROW

	return COLOR_ACCENT


# ==================================================
# NUMBER FORMATTER
# ==================================================

func _format_number(
	value: float
) -> String:

	if is_equal_approx(
		value,
		roundf(value)
	):

		return str(roundi(value))

	return str(
		snappedf(
			value,
			0.01
		)
	)


func _get_cafeteria_combination_hint(
	food: FoodData, category_name: String, settings: CafeteriaCombinationSettings
) -> String:
	if not settings.enable_combinations:
		return "Food combining is disabled."
	if not ((category_name == "GO" and settings.allow_go_combinations)
		or (category_name == "GROW" and settings.allow_grow_combinations)):
		return "No combination available for this category."
	var counts: PackedStringArray = []
	for count in range(1, settings.get_maximum_original_foods()):
		if settings.is_combination_size_allowed(count, food.original_food_count):
			counts.append("ordinary" if count == 1 else "×%d" % count)
	if counts.is_empty():
		return "No valid ingredient count under the current rules."
	return "Can combine with %s %s food." % [" or ".join(counts), category_name]
