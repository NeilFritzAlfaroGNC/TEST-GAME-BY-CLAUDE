extends Control
## Standalone food-sorting round using the existing GameData categories and images.
## ROUND_QUESTIONS and FEEDBACK_SECONDS tune the round length and response pause.
## A food must be held and moved before its release over a basket can submit it;
## outside drops return it home. Correct answers add score; results return to menu.

const ROUND_QUESTIONS: int = 10
const FEEDBACK_SECONDS: float = 0.9
const FOOD_PATH: String = "res://assets/food/%s.png"

var _pool: Array[Dictionary] = []
var _round: Array[Dictionary] = []
var _index: int = 0
var _score: int = 0
var _dragging: bool = false
var _submitted: bool = false
var _input_locked: bool = false
var _last_pointer: Vector2 = Vector2.ZERO
var _home_position: Vector2 = Vector2.ZERO
var _current: Dictionary = {}
var _drop_targets: Dictionary = {}

var _title: Label
var _instruction: Label
var _counter: Label
var _score_label: Label
var _feedback: Label
var _food: TextureRect
var _food_name: Label
var _basket_row: HBoxContainer
var _round_ui: VBoxContainer
var _results_ui: VBoxContainer

func _ready() -> void:
	_build_food_pool()
	_build_ui()
	if _pool.is_empty():
		_show_error("No foods with a usable image and a verified Go/Glow/Grow category were found.")
		return
	_start_round()

func _build_food_pool() -> void:
	for group: String in GameData.FOODS:
		for food_name: String in GameData.FOODS[group]:
			var path: String = FOOD_PATH % food_name.to_lower().replace(" ", "_")
			if not ResourceLoader.exists(path):
				continue
			var texture: Texture2D = load(path) as Texture2D
			if texture != null and group in ["Go", "Glow", "Grow"]:
				_pool.append({"name": food_name, "group": group, "texture": texture})

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var background: ColorRect = ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("#183b37")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var root: VBoxContainer = VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 5)
	root.offset_left = 12
	root.offset_top = 8
	root.offset_right = -12
	root.offset_bottom = -8
	add_child(root)
	_title = _label("GUESS THE FOOD", 28, Color("#ffe06a"))
	root.add_child(_title)
	_counter = _label("Question 1/10", 17, Color.WHITE)
	root.add_child(_counter)
	_score_label = _label("Score: 0", 17, Color("#f4d889"))
	root.add_child(_score_label)
	_instruction = _label("Drag the food into the correct basket!", 16, Color.WHITE)
	root.add_child(_instruction)
	_feedback = _label("", 18, Color("#b8f29e"))
	_feedback.custom_minimum_size.y = 28
	root.add_child(_feedback)
	var play_area: Control = Control.new()
	play_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	play_area.custom_minimum_size.y = 88
	root.add_child(play_area)
	_food = TextureRect.new()
	_food.name = "FoodImage"
	_food.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_food.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_food.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_food.mouse_filter = Control.MOUSE_FILTER_STOP
	_food.gui_input.connect(_on_food_gui_input)
	play_area.add_child(_food)
	_food_name = _label("", 17, Color.WHITE)
	_food_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_food_name.visible = false
	play_area.add_child(_food_name)
	_basket_row = HBoxContainer.new()
	_basket_row.custom_minimum_size.y = 105
	_basket_row.add_theme_constant_override("separation", 8)
	root.add_child(_basket_row)
	for group: String in ["Go", "Glow", "Grow"]:
		var basket: PanelContainer = PanelContainer.new()
		basket.name = group + "Basket"
		basket.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		basket.size_flags_vertical = Control.SIZE_EXPAND_FILL
		basket.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = _group_color(group)
		style.border_color = Color("#f6e6ae")
		style.set_border_width_all(3)
		style.set_corner_radius_all(10)
		basket.add_theme_stylebox_override("panel", style)
		var label: Label = _label("%s BASKET\n%s" % [_group_icon(group), group.to_upper()], 13, Color.WHITE)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		basket.add_child(label)
		_basket_row.add_child(basket)
		_drop_targets[group] = basket
	var bottom: HBoxContainer = HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(bottom)
	var menu: Button = Button.new()
	menu.text = "RETURN TO MENU"
	menu.pressed.connect(_return_to_menu)
	bottom.add_child(menu)
	_round_ui = root
	_results_ui = VBoxContainer.new()
	_results_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_results_ui.alignment = BoxContainer.ALIGNMENT_CENTER
	_results_ui.add_theme_constant_override("separation", 12)
	_results_ui.visible = false
	add_child(_results_ui)

func _label(text_value: String, font_size: int, color: Color) -> Label:
	var result: Label = Label.new()
	result.text = text_value
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	result.add_theme_color_override("font_shadow_color", Color("#172521"))
	result.add_theme_constant_override("shadow_offset_x", 1)
	result.add_theme_constant_override("shadow_offset_y", 1)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return result

func _start_round() -> void:
	_score = 0
	_index = 0
	_round = _pool.duplicate()
	_round.shuffle()
	var count: int = mini(ROUND_QUESTIONS, _round.size())
	_round.resize(count)
	_round_ui.visible = true
	_results_ui.visible = false
	_load_question()

func _load_question() -> void:
	if _index >= _round.size():
		_show_results()
		return
	_current = _round[_index]
	_submitted = false
	_input_locked = false
	_dragging = false
	_food.texture = _current["texture"] as Texture2D
	_food.scale = Vector2.ONE
	_food.z_index = 0
	_instruction.text = "Drag the food into the correct basket!"
	_feedback.text = ""
	_food_name.text = ""
	_food_name.visible = false
	_update_counter()
	await get_tree().process_frame
	_place_food_home()

func _place_food_home() -> void:
	if _food == null or _food.get_parent() == null:
		return
	var area: Control = _food.get_parent() as Control
	var max_size: Vector2 = Vector2(minf(area.size.x * 0.70, 230.0), minf(area.size.y * 0.82, 190.0))
	_food.size = max_size
	_food.position = (area.size - max_size) * 0.5
	_home_position = _food.position
	_food_name.position = Vector2(0, _food.position.y + _food.size.y - 5)
	_food_name.size = Vector2(area.size.x, 30)

func _on_food_gui_input(event: InputEvent) -> void:
	if _input_locked or _submitted:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_begin_drag(get_global_mouse_position())

# Keep tracking the active pointer globally so the image can move over baskets.
func _process(_delta: float) -> void:
	# Poll mouse state during an active drag. This keeps tracking continuous even
	# after the food Control has moved away from the pointer over a basket.
	if _dragging and not DisplayServer.is_touchscreen_available():
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_last_pointer = get_global_mouse_position()
			_move_food(_last_pointer)
		else:
			_last_pointer = get_global_mouse_position()
			_end_drag()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenDrag and _dragging:
		_last_pointer = event.position
		_move_food(event.position)
	elif event is InputEventScreenTouch:
		_last_pointer = event.position
		if event.pressed and not _dragging and not _input_locked and not _submitted and _food.get_global_rect().has_point(event.position):
			_begin_drag(event.position)
		elif not event.pressed and _dragging:
			_end_drag()

func _begin_drag(pointer: Vector2) -> void:
	if _dragging or _input_locked or _submitted:
		return
	_dragging = true
	_food.z_index = 20
	_food.scale = Vector2(1.08, 1.08)
	_last_pointer = pointer

func _move_food(pointer: Vector2) -> void:
	_last_pointer = pointer
	_food.global_position = pointer - _food.size * 0.5
	if _food.get_parent() is Control:
		_food.position = (_food.get_parent() as Control).get_global_transform().affine_inverse() * _food.global_position

func _end_drag() -> void:
	if not _dragging:
		return
	_dragging = false
	_food.scale = Vector2.ONE
	_food.z_index = 0
	var group: String = _basket_at(_last_pointer)
	if group.is_empty():
		_food.position = _home_position
		return
	_submit_answer(group)

func _basket_at(point: Vector2) -> String:
	for group: String in ["Go", "Glow", "Grow"]:
		var basket: Control = _drop_targets[group] as Control
		if basket.get_global_rect().has_point(point):
			return group
	return ""

func _submit_answer(group: String) -> void:
	if _submitted or _input_locked:
		return
	_submitted = true
	_input_locked = true
	var correct: String = str(_current["group"])
	if group == correct:
		_score += 1
		_feedback.text = "Correct! +1 point"
		_feedback.add_theme_color_override("font_color", Color("#b8f29e"))
		Audio.play("correct")
	else:
		_feedback.text = "Not quite — %s belongs in the %s basket." % [_current["name"], correct.to_upper()]
		_feedback.add_theme_color_override("font_color", Color("#ffd38a"))
		Audio.play("click")
	_index += 1
	_update_counter()
	await get_tree().create_timer(FEEDBACK_SECONDS).timeout
	_load_question()


func _update_counter() -> void:
	var total: int = _round.size()
	_counter.text = "Question %d/%d" % [mini(_index + 1, total), total]
	_score_label.text = "Score: %d" % _score

func _show_results() -> void:
	_round_ui.visible = false
	_results_ui.visible = true
	for child: Node in _results_ui.get_children():
		child.queue_free()
	var heading: Label = _label("ROUND COMPLETE!", 28, Color("#ffe06a"))
	_results_ui.add_child(heading)
	_results_ui.add_child(_label("Final score: %d/%d" % [_score, _round.size()], 23, Color.WHITE))
	if _pool.size() < ROUND_QUESTIONS:
		_results_ui.add_child(_label("Only %d eligible foods are available." % _pool.size(), 15, Color.WHITE))
	var again: Button = Button.new()
	again.text = "PLAY AGAIN"
	again.pressed.connect(_start_round)
	_results_ui.add_child(again)
	var menu: Button = Button.new()
	menu.text = "RETURN TO MENU"
	menu.pressed.connect(_return_to_menu)
	_results_ui.add_child(menu)

func _show_error(message: String) -> void:
	var error_label: Label = _label(message, 18, Color.WHITE)
	error_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	error_label.custom_minimum_size = Vector2(360, 100)
	add_child(error_label)

func _group_color(group: String) -> Color:
	match group:
		"Go": return Color("#ad7c22")
		"Glow": return Color("#347a48")
		_: return Color("#a8453e")

func _group_icon(group: String) -> String:
	match group:
		"Go": return "⚡"
		"Glow": return "✿"
		_: return "★"

func _return_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
