extends CanvasLayer

func show_result(reason: String, retry_text: String, retry: Callable, return_to_menu: Callable = Callable()) -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Fill the entire screen.
	var backdrop: ColorRect = ColorRect.new()

	backdrop.name = "Backdrop"

	backdrop.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	backdrop.color = Color(
		0.04,
		0.07,
		0.09,
		0.88
	)

	backdrop.mouse_filter = (
		Control.MOUSE_FILTER_STOP
	)

	add_child(backdrop)

	# Keep the layout centered.
	var center: CenterContainer = CenterContainer.new()

	center.name = "GameOverCenter"

	center.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	add_child(center)

	var panel: PanelContainer = PanelContainer.new()

	panel.custom_minimum_size = Vector2(
		350.0,
		250.0
	)

	center.add_child(panel)

	var style: StyleBoxFlat = StyleBoxFlat.new()

	style.bg_color = Color("#172322")
	style.border_color = Color("#ce7777")

	style.set_border_width_all(2)
	style.set_corner_radius_all(12)

	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 22
	style.content_margin_bottom = 22

	panel.add_theme_stylebox_override(
		"panel",
		style
	)

	var content: VBoxContainer = VBoxContainer.new()

	content.add_theme_constant_override(
		"separation",
		16
	)

	panel.add_child(content)

	var title_label: Label = Label.new()

	title_label.text = "GAME OVER"

	title_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	title_label.add_theme_font_size_override(
		"font_size",
		32
	)

	title_label.add_theme_color_override(
		"font_color",
		Color("#ff9d9d")
	)

	content.add_child(title_label)

	var reason_label: Label = Label.new()

	reason_label.text = reason

	reason_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	reason_label.add_theme_font_size_override(
		"font_size",
		17
	)

	content.add_child(reason_label)

	var retry_button: Button = Button.new()

	retry_button.text = retry_text

	retry_button.custom_minimum_size = Vector2(
		220.0,
		44.0
	)

	content.add_child(retry_button)

	retry_button.pressed.connect(
		retry
	)

	if return_to_menu.is_valid():

		var menu_button: Button = Button.new()

		menu_button.text = "Main Menu"

		menu_button.custom_minimum_size = Vector2(
			220.0,
			40.0
		)

		content.add_child(menu_button)

		menu_button.pressed.connect(
			return_to_menu
		)

	retry_button.grab_focus()
