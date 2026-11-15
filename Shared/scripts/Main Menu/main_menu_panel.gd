
extends Panel

const TOKEN_UNLOCKS := preload("res://scripts/codex/codex_token_unlocks.gd")

const TUTORIAL_SAVE_PATH: String = "user://food_heroes_tutorials.cfg"

@onready var play_button: TextureButton = $main_menu_button_container/Play
@onready var reset_button: TextureButton = $main_menu_button_container/Reset
@onready var quit_button: TextureButton = $main_menu_button_container/Quit

var reset_confirmation: ConfirmationDialog


func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	reset_button.pressed.connect(_on_reset_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	# Create confirmation dialog.
	reset_confirmation = ConfirmationDialog.new()
	reset_confirmation.title = "Reset Progress"
	reset_confirmation.dialog_text = "Are you sure you want to erase all saved progress?"
	reset_confirmation.ok_button_text = "Reset"
	reset_confirmation.confirmed.connect(_on_reset_confirmed)

	add_child(reset_confirmation)


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file(
		"res://Shared/scenes/level_map/level_map.tscn"
	)


func _on_reset_pressed() -> void:
	reset_confirmation.popup_centered()


func _on_reset_confirmed() -> void:
	var codex_result := TOKEN_UNLOCKS.reset_all()
	if codex_result != OK:
		push_error("[Main Menu] Could not reset Codex tokens: " + error_string(codex_result))
	if ProgressManager.has_meta(TOKEN_UNLOCKS.REWARD_META):
		ProgressManager.remove_meta(TOKEN_UNLOCKS.REWARD_META)

	ProgressManager.progress = {
		"easy": {},
		"normal": {},
		"hard": {}
	}

	ProgressManager.current_run_stars = 0
	ProgressManager.last_completed_level_id = ""
	ProgressManager.current_difficulty = "easy"
	ProgressManager.save_progress()

	# Tutorial completion belongs to saved progress too. Removing only this
	# dedicated store restores all tutorial defaults, including Show Only Once.
	if FileAccess.file_exists(TUTORIAL_SAVE_PATH):
		var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(TUTORIAL_SAVE_PATH))
		if error != OK:
			push_error("[Main Menu] Could not reset tutorial completion. Error: %s" % error)

	print("[Main Menu] All progress has been reset.")


func _on_quit_pressed() -> void:
	get_tree().quit()
