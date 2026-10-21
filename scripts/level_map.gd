extends Control

@export_file("*.tscn") var destination_scene: String = "res://scene/main.tscn"
@export_file("*.tscn") var back_scene: String = "res://scene/main_menu.tscn"
@export var selected_difficulty: String = "Easy"

func _ready() -> void:
	$MapLevel/LevelSelectControls/ControlsColumn/EasyButton.pressed.connect(_on_easy)
	$MapLevel/LevelSelectControls/ControlsColumn/MediumButton.pressed.connect(_on_medium)
	$MapLevel/LevelSelectControls/ControlsColumn/HardButton.pressed.connect(_on_hard)
	$MapLevel/LevelSelectControls/ControlsColumn/BackButton.pressed.connect(_on_back)
	for level: int in range(1, 6):
		var button: Button = get_node("MapLevel/Level%d" % level) as Button
		button.pressed.connect(_on_level_pressed.bind(level))
	_refresh_difficulty()
	_refresh_levels()

func _on_easy() -> void:
	_set_difficulty("Easy")

func _on_medium() -> void:
	_set_difficulty("Medium")

func _on_hard() -> void:
	_set_difficulty("Hard")

func _set_difficulty(value: String) -> void:
	selected_difficulty = value
	_refresh_difficulty()

func _refresh_difficulty() -> void:
	var buttons: Array[Button] = [
		$MapLevel/LevelSelectControls/ControlsColumn/EasyButton,
		$MapLevel/LevelSelectControls/ControlsColumn/MediumButton,
		$MapLevel/LevelSelectControls/ControlsColumn/HardButton
	]
	var names: Array[String] = ["Easy", "Medium", "Hard"]
	for index: int in range(buttons.size()):
		buttons[index].modulate = Color(1.0, 0.85, 0.3) if names[index] == selected_difficulty else Color.WHITE

# Levels unlock in order (see GameProgress): locked ones are dimmed and can't be pressed.
func _refresh_levels() -> void:
	for level: int in range(1, 6):
		var button: Button = get_node("MapLevel/Level%d" % level) as Button
		var unlocked: bool = GameProgress.is_unlocked(level)
		button.disabled = not unlocked
		button.text = "Level %d" % level if unlocked else "Locked"
		button.modulate = Color.WHITE if unlocked else Color(0.55, 0.55, 0.6, 0.85)
		button.tooltip_text = "" if unlocked else "Finish Level %d to unlock" % (level - 1)
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if unlocked else Control.CURSOR_FORBIDDEN
		_show_stars(button, GameProgress.best_stars.get(level, 0))

# Row of 3 stars under a level marker: gold for each star earned (best result),
# dark for the rest. Hidden until the level has been won once.
func _show_stars(button: Button, earned: int) -> void:
	var row: HBoxContainer = button.get_node_or_null("Stars")
	if row == null:
		row = HBoxContainer.new()
		row.name = "Stars"
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 2)
		for i in 3:
			var star := StarIcon.new()
			star.custom_minimum_size = Vector2(22, 22)
			star.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(star)
		button.add_child(row)
		# Centred just below the marker.
		row.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		row.offset_left = -36.0
		row.offset_right = 36.0
		row.offset_top = 0.0
		row.offset_bottom = 22.0
	row.visible = earned > 0
	for i in row.get_child_count():
		(row.get_child(i) as StarIcon).filled = i < earned

func _on_level_pressed(level: int) -> void:
	if not GameProgress.is_unlocked(level):
		return
	var status: Label = $MapLevel/LevelSelectControls/ControlsColumn/Status
	status.text = "Level %d selected (%s)." % [level, selected_difficulty]
	GameProgress.current_level = level #The battle reads this
	if not destination_scene.is_empty():
		get_tree().change_scene_to_file(destination_scene)

func _on_back() -> void:
	if not back_scene.is_empty():
		get_tree().change_scene_to_file(back_scene)
