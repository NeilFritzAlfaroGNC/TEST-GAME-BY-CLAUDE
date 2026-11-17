
extends Control

# ==================================================
# DIFFICULTY SELECTION
# ==================================================
# EASY, NORMAL, HARD
#
# Hard unlock:
# Complete Canteen Level 2 on Normal
# with at least 1 star.
# ==================================================

const MAIN_MENU_SCENE_PATH: String = "res://scenes/Main Menu/main_menu_screen.tscn"

const CAFETERIA_LEVEL_ID: String = "cafeteria_level_1"
const CANTEEN_LEVEL_ID: String = "canteen_level_2"

const BUTTON_STATES = [
	"normal",
	"hover",
	"pressed",
	"focus",
	"disabled"
]

const OUTLINE_COLOR: Color = Color.WHITE
const OUTLINE_WIDTH: int = 2

const LOCKED_COLOR: Color = Color("#353535")
const LOCKED_FONT_COLOR: Color = Color("#999999")


# ==================================================
# BUTTON REFERENCES
# ==================================================

@onready var easy_button: Button = $Background/Margins/Content/EasyButton
@onready var normal_button: Button = $Background/Margins/Content/NormalButton
@onready var hard_button: Button = $Background/Margins/Content/HardButton
@onready var mini_games_button: Button = $Background/Margins/Content/MiniGamesButton
@onready var endless_button: Button = $Background/Margins/Content/EndlessButton
@onready var main_menu_button: Button = $Background/Margins/Content/MainMenuButton


# ==================================================
# ORIGINAL BUTTON STYLES
# ==================================================

var easy_original_styles: Dictionary = {}
var normal_original_styles: Dictionary = {}
var hard_original_styles: Dictionary = {}


# ==================================================
# INITIALIZATION
# ==================================================

func _ready() -> void:
	_save_original_styles()
	_connect_buttons()
	_style_locked_buttons()

	_refresh_hard_unlock()
	_update_difficulty_indicator()

	call_deferred("_refresh_map_stars")

	print("[Difficulty] Selection system ready.")


# ==================================================
# SAVE ORIGINAL STYLES
# ==================================================

func _save_original_styles() -> void:
	for state in BUTTON_STATES:
		easy_original_styles[state] = (
			easy_button.get_theme_stylebox(state).duplicate()
		)

		normal_original_styles[state] = (
			normal_button.get_theme_stylebox(state).duplicate()
		)

		hard_original_styles[state] = (
			hard_button.get_theme_stylebox(state).duplicate()
		)


# ==================================================
# CONNECT BUTTONS
# ==================================================

func _connect_buttons() -> void:
	if not easy_button.pressed.is_connected(_on_easy_pressed):
		easy_button.pressed.connect(_on_easy_pressed)

	if not normal_button.pressed.is_connected(_on_normal_pressed):
		normal_button.pressed.connect(_on_normal_pressed)

	if not hard_button.pressed.is_connected(_on_hard_pressed):
		hard_button.pressed.connect(_on_hard_pressed)

	if not mini_games_button.pressed.is_connected(
		_on_mini_games_pressed
	):
		mini_games_button.pressed.connect(
			_on_mini_games_pressed
		)

	if not endless_button.pressed.is_connected(
		_on_endless_pressed
	):
		endless_button.pressed.connect(
			_on_endless_pressed
		)

	if not main_menu_button.pressed.is_connected(
		_on_main_menu_pressed
	):
		main_menu_button.pressed.connect(
			_on_main_menu_pressed
		)


# ==================================================
# LOCKED BUTTON STYLES
# ==================================================

func _style_locked_buttons() -> void:
	_apply_locked_style(hard_button)
	_apply_locked_style(mini_games_button)
	_apply_locked_style(endless_button)

	mini_games_button.disabled = true
	endless_button.disabled = true


func _apply_locked_style(button: Button) -> void:
	var locked_style := StyleBoxFlat.new()

	locked_style.bg_color = LOCKED_COLOR
	locked_style.set_corner_radius_all(12)
	locked_style.set_border_width_all(1)
	locked_style.border_color = Color("#555555")

	for state in BUTTON_STATES:
		button.add_theme_stylebox_override(
			state,
			locked_style.duplicate()
		)

	for color_name in [
		"font_color",
		"font_hover_color",
		"font_pressed_color",
		"font_focus_color",
		"font_disabled_color"
	]:
		button.add_theme_color_override(
			color_name,
			LOCKED_FONT_COLOR
		)


# ==================================================
# EASY SELECTION
# ==================================================

func _on_easy_pressed() -> void:
	_select_difficulty("easy")


# ==================================================
# NORMAL SELECTION
# ==================================================

func _on_normal_pressed() -> void:
	_select_difficulty("normal")


# ==================================================
# HARD SELECTION
# ==================================================

func _on_hard_pressed() -> void:
	if not ProgressManager.is_hard_unlocked():
		print("[Difficulty] HARD is locked.")
		return

	_select_difficulty("hard")


# ==================================================
# SELECT DIFFICULTY
# ==================================================

func _select_difficulty(difficulty: String) -> void:
	var success: bool = (
		ProgressManager.set_current_difficulty(difficulty)
	)

	if not success:
		return

	print(
		"[Difficulty] Selected: ",
		difficulty.to_upper()
	)

	_refresh_hard_unlock()
	_update_difficulty_indicator()
	_refresh_map_stars()


# ==================================================
# HARD UNLOCK STATUS
# ==================================================

func _refresh_hard_unlock() -> void:
	var unlocked: bool = (
		ProgressManager.is_hard_unlocked()
	)

	hard_button.disabled = not unlocked

	if unlocked:
		hard_button.text = "HARD"

		_restore_original_styles(
			hard_button,
			hard_original_styles
		)

		for color_name in [
			"font_color",
			"font_hover_color",
			"font_pressed_color",
			"font_focus_color",
			"font_disabled_color"
		]:
			hard_button.remove_theme_color_override(
				color_name
			)

	else:
		hard_button.text = "🔒"

		_apply_locked_style(hard_button)

	print(
		"[Difficulty] HARD unlocked: ",
		unlocked
	)


# ==================================================
# UPDATE DIFFICULTY INDICATOR
# ==================================================

func _update_difficulty_indicator() -> void:
	_restore_original_styles(
		easy_button,
		easy_original_styles
	)

	_restore_original_styles(
		normal_button,
		normal_original_styles
	)

	# Restore unlocked Hard appearance.
	if ProgressManager.is_hard_unlocked():
		_restore_original_styles(
			hard_button,
			hard_original_styles
		)

	match ProgressManager.current_difficulty:
		"easy":
			_apply_white_outline(easy_button)

		"normal":
			_apply_white_outline(normal_button)

		"hard":
			if ProgressManager.is_hard_unlocked():
				_apply_white_outline(hard_button)


# ==================================================
# RESTORE ORIGINAL STYLES
# ==================================================

func _restore_original_styles(
	button: Button,
	original_styles: Dictionary
) -> void:
	for state in BUTTON_STATES:
		if original_styles.has(state):
			button.add_theme_stylebox_override(
				state,
				original_styles[state]
			)


# ==================================================
# WHITE SELECTION OUTLINE
# ==================================================

func _apply_white_outline(button: Button) -> void:
	for state in BUTTON_STATES:
		var original_style: StyleBox = (
			button.get_theme_stylebox(state)
		)

		if original_style is StyleBoxFlat:
			var outlined_style: StyleBoxFlat = (
				original_style.duplicate() as StyleBoxFlat
			)

			outlined_style.set_border_width_all(
				OUTLINE_WIDTH
			)

			outlined_style.border_color = (
				OUTLINE_COLOR
			)

			button.add_theme_stylebox_override(
				state,
				outlined_style
			)


# ==================================================
# REFRESH MAP STARS
# ==================================================

func _refresh_map_stars() -> void:
	var scene_root: Node = get_tree().current_scene

	if scene_root == null:
		return

	var cafeteria_found: bool = false
	var canteen_found: bool = false

	var nodes_to_check: Array[Node] = [scene_root]

	while not nodes_to_check.is_empty():
		var current_node: Node = nodes_to_check.pop_back()

		for child in current_node.get_children():
			nodes_to_check.append(child)

		if not current_node.has_method("refresh_stars"):
			continue

		if not _has_property(current_node, "level_id"):
			continue

		if not _has_property(
			current_node,
			"show_current_run"
		):
			continue

		if bool(current_node.get("show_current_run")):
			continue

		var found_level_id: String = str(
			current_node.get("level_id")
		)

		if found_level_id == CAFETERIA_LEVEL_ID:
			current_node.call("refresh_stars")
			cafeteria_found = true

		elif found_level_id == CANTEEN_LEVEL_ID:
			current_node.call("refresh_stars")
			canteen_found = true

	if not cafeteria_found:
		print(
			"[Difficulty] Cafeteria star display "
			+ "not found in current scene."
		)

	if not canteen_found:
		print(
			"[Difficulty] Canteen star display "
			+ "not found in current scene."
		)

	_print_saved_ratings()


# ==================================================
# CHECK PROPERTY
# ==================================================

func _has_property(
	object: Object,
	property_name: String
) -> bool:
	for property_info in object.get_property_list():
		if str(property_info.get("name", "")) == property_name:
			return true

	return false


# ==================================================
# DISPLAY SAVED RATINGS
# ==================================================

func _print_saved_ratings() -> void:
	print("")
	print("========== LEVEL STAR RATINGS ==========")

	for difficulty in ["easy", "normal", "hard"]:
		var cafeteria_stars: int = (
			ProgressManager.get_level_stars(
				difficulty,
				CAFETERIA_LEVEL_ID
			)
		)

		var canteen_stars: int = (
			ProgressManager.get_level_stars(
				difficulty,
				CANTEEN_LEVEL_ID
			)
		)

		print(
			"[Progress] ",
			difficulty,
			" | Cafeteria: ",
			cafeteria_stars,
			" | Canteen: ",
			canteen_stars
		)

	print("========================================")
	print("")


# ==================================================
# MINI GAMES
# ==================================================

func _on_mini_games_pressed() -> void:
	print("[Difficulty] Mini Games unavailable.")


# ==================================================
# ENDLESS MODE
# ==================================================

func _on_endless_pressed() -> void:
	print("[Difficulty] Endless unavailable.")


# ==================================================
# MAIN MENU
# ==================================================

func _on_main_menu_pressed() -> void:
	if not ResourceLoader.exists(
		MAIN_MENU_SCENE_PATH
	):
		push_error(
			"[Difficulty] Main Menu scene does not exist."
		)
		return

	print("Returning to Main Menu...")

	var error: Error = get_tree().change_scene_to_file(
		MAIN_MENU_SCENE_PATH
	)

	if error != OK:
		push_error(
			"[Difficulty] Could not return to Main Menu. "
			+ "Error: "
			+ str(error)
		)
