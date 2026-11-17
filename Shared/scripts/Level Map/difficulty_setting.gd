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

const CHARACTER_EQUIPMENT := preload("res://scripts/character_codex/character_equipment.gd")

const MAIN_MENU_SCENE_PATH: String = "res://Shared/scenes/main_menu/main_menu_screen.tscn"

const CAFETERIA_LEVEL_ID: String = "cafeteria_level_1"
const CANTEEN_LEVEL_ID: String = "canteen_level_2"

const DESCRIPTIONS := {
	"easy": "Recommended for beginners. Enemies are weaker, making battles easier.",
	"normal": "A balanced experience with standard enemies and a greater challenge.",
	"hard": "A tougher Food Heroes challenge with stronger enemies.",
}
const HARD_UNLOCK_HINT := "Earn at least one star in Canteen Level 2 on Normal to unlock Hard."

const BUTTON_STATES = [
	"normal",
	"hover",
	"pressed",
	"focus",
	"disabled"
]

const OUTLINE_COLOR: Color = Color("#FFF0A0")
const OUTLINE_WIDTH: int = 2

const LOCKED_COLOR: Color = Color("#746069")
const LOCKED_FONT_COLOR: Color = Color("#dfd0bd")


# ==================================================
# BUTTON REFERENCES
# ==================================================

@onready var easy_button: Button = $MenuPanel/DifficultyPanel/EasyButton
@onready var normal_button: Button = $MenuPanel/DifficultyPanel/NormalButton
@onready var hard_button: Button = $MenuPanel/DifficultyPanel/HardButton
@onready var endless_button: Button = $MenuPanel/DifficultyPanel/EndlessButton
@onready var main_menu_button: Button = $MenuPanel/MainMenuButton


# ==================================================
# ORIGINAL BUTTON STYLES
# ==================================================

@onready var character_button: Button = $MenuPanel/CharacterPanel/CharacterPreview/CharacterButton
@onready var character_select_panel: Panel = $CharacterSelectPanel
@onready var close_button: Button = $CharacterSelectPanel/CloseButton

@onready var description_label: Label = $MenuPanel/DescriptionPanel/DescriptionLabel

var viewed_difficulty: String
var easy_original_styles: Dictionary = {}
var normal_original_styles: Dictionary = {}
var hard_original_styles: Dictionary = {}


# ==================================================
# INITIALIZATION
# ==================================================

func _ready() -> void:
	_show_equipped_character()
	_save_original_styles()
	_connect_buttons()
	_style_locked_buttons()

	_refresh_hard_unlock()
	viewed_difficulty = ProgressManager.current_difficulty
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
	easy_button.pressed.connect(_on_easy_pressed)
	normal_button.pressed.connect(_on_normal_pressed)
	hard_button.pressed.connect(_on_hard_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	character_button.pressed.connect(_open_character_selection)
	close_button.pressed.connect(character_select_panel.hide)


func _show_equipped_character() -> void:
	var equipped_id := CHARACTER_EQUIPMENT.load_id()
	var sprite: AnimatedSprite2D = $MenuPanel/CharacterPanel/CharacterPreview/CharacterSprite
	var question: Label = $MenuPanel/CharacterPanel/CharacterPreview/EquipmentQuestion
	sprite.hide()
	sprite.stop()
	question.show()
	if equipped_id == &"":
		return
	for entry in CHARACTER_EQUIPMENT.unlocked_characters():
		if entry.id == equipped_id:
			if CHARACTER_EQUIPMENT.apply_preview(sprite, entry, Vector2(110, 66)):
				sprite.show()
				question.hide()
			return


func _open_character_selection() -> void:
	var result := get_tree().change_scene_to_file("res://Shared/scenes/character_codex/CharacterCodex.tscn")
	if result == OK:
		return
	push_error("Could not open Character + Codex: %s" % error_string(result))
	character_select_panel.show()
	close_button.grab_focus()


# ==================================================
# LOCKED BUTTON STYLES
# ==================================================

func _style_locked_buttons() -> void:
	_apply_locked_style(endless_button)



func _apply_locked_style(button: Button) -> void:
	var locked_style := StyleBoxFlat.new()

	locked_style.bg_color = LOCKED_COLOR
	locked_style.set_corner_radius_all(3)
	locked_style.set_border_width_all(2)
	locked_style.border_color = Color("#423029")

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

	viewed_difficulty = ProgressManager.current_difficulty
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
	hard_button.tooltip_text = "" if unlocked else HARD_UNLOCK_HINT

	if unlocked:
		hard_button.text = "Hard"

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
		hard_button.text = "Hard (Locked)"

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

	description_label.text = DESCRIPTIONS[viewed_difficulty]
	var active_button: Button = {"easy": easy_button, "normal": normal_button, "hard": hard_button}[viewed_difficulty]
	$MenuPanel/DifficultyPanel/SelectionArrow.position.y = active_button.position.y

	match viewed_difficulty:

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
		if state == "focus" or state == "disabled":
			continue
		var original_style: StyleBox = (
			button.get_theme_stylebox(state)
		)

		if original_style is StyleBoxFlat:
			var outlined_style: StyleBoxFlat = (
				original_style.duplicate() as StyleBoxFlat
			)

			outlined_style.set_border_width_all(OUTLINE_WIDTH + 1)

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

		elif found_level_id == "Tanjangco Hall":
			current_node.call("refresh_stars")

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
