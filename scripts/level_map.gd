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

func _on_level_pressed(level: int) -> void:
	var status: Label = $MapLevel/LevelSelectControls/ControlsColumn/Status
	status.text = "Level %d selected (%s)." % [level, selected_difficulty]
	if not destination_scene.is_empty():
		get_tree().change_scene_to_file(destination_scene)

func _on_back() -> void:
	if not back_scene.is_empty():
		get_tree().change_scene_to_file(back_scene)
