
extends Control

const MAIN_MENU_SCENE_PATH: String = "res://scenes/Main Menu/main_menu_screen.tscn"

@onready var easy_button: Button = $Background/Margins/Content/EasyButton
@onready var normal_button: Button = $Background/Margins/Content/NormalButton
@onready var hard_button: Button = $Background/Margins/Content/HardButton
@onready var mini_games_button: Button = $Background/Margins/Content/MiniGamesButton
@onready var endless_button: Button = $Background/Margins/Content/EndlessButton
@onready var main_menu_button: Button = $Background/Margins/Content/MainMenuButton

const BUTTON_STATES = ["normal", "hover", "pressed", "focus", "disabled"]
const OUTLINE_COLOR = Color.WHITE
const OUTLINE_WIDTH: int = 2

var easy_original_styles: Dictionary = {}
var normal_original_styles: Dictionary = {}


func _ready() -> void:
	_save_original_styles()
	_connect_buttons()
	_update_difficulty_indicator()


func _save_original_styles() -> void:
	for state in BUTTON_STATES:
		easy_original_styles[state] = easy_button.get_theme_stylebox(state).duplicate()
		normal_original_styles[state] = normal_button.get_theme_stylebox(state).duplicate()


func _connect_buttons() -> void:
	if not easy_button.pressed.is_connected(_on_easy_pressed):
		easy_button.pressed.connect(_on_easy_pressed)

	if not normal_button.pressed.is_connected(_on_normal_pressed):
		normal_button.pressed.connect(_on_normal_pressed)

	if not hard_button.pressed.is_connected(_on_hard_pressed):
		hard_button.pressed.connect(_on_hard_pressed)

	if not mini_games_button.pressed.is_connected(_on_mini_games_pressed):
		mini_games_button.pressed.connect(_on_mini_games_pressed)

	if not endless_button.pressed.is_connected(_on_endless_pressed):
		endless_button.pressed.connect(_on_endless_pressed)

	if not main_menu_button.pressed.is_connected(_on_main_menu_pressed):
		main_menu_button.pressed.connect(_on_main_menu_pressed)


func _on_easy_pressed() -> void:
	ProgressManager.current_difficulty = "easy"
	_refresh_map_stars()
	_update_difficulty_indicator()


func _on_normal_pressed() -> void:
	ProgressManager.current_difficulty = "normal"
	_refresh_map_stars()
	_update_difficulty_indicator()


func _on_hard_pressed() -> void:
	print("Hard difficulty is not available yet.")


func _on_mini_games_pressed() -> void:
	print("Mini Games are not available yet.")


func _on_endless_pressed() -> void:
	print("Endless mode is not available yet.")


func _on_main_menu_pressed() -> void:
	if not ResourceLoader.exists(MAIN_MENU_SCENE_PATH):
		push_error("Main Menu scene does not exist.")
		return

	print("Returning to Main Menu...")

	var error := get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)

	if error != OK:
		push_error("Could not return to Main Menu. Error: %s" % error)


func _refresh_map_stars() -> void:
	var map_stars = get_node_or_null("../Map/CafeteriaStars")

	if map_stars:
		map_stars.refresh_stars()


func _update_difficulty_indicator() -> void:
	_restore_original_styles(easy_button, easy_original_styles)
	_restore_original_styles(normal_button, normal_original_styles)

	if ProgressManager.current_difficulty == "easy":
		_apply_white_outline(easy_button)

	elif ProgressManager.current_difficulty == "normal":
		_apply_white_outline(normal_button)


func _restore_original_styles(button: Button, original_styles: Dictionary) -> void:
	for state in BUTTON_STATES:
		button.add_theme_stylebox_override(state, original_styles[state])


func _apply_white_outline(button: Button) -> void:
	for state in BUTTON_STATES:
		var original_style = button.get_theme_stylebox(state)

		if original_style is StyleBoxFlat:
			var outlined_style = original_style.duplicate() as StyleBoxFlat
			outlined_style.set_border_width_all(OUTLINE_WIDTH)
			outlined_style.border_color = OUTLINE_COLOR
			button.add_theme_stylebox_override(state, outlined_style)
