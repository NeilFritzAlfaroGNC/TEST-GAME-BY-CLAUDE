extends TextureButton

# ==================================================
# MAIN MENU - RESOLUTION SELECTOR
# GODOT 4.7.1
#
# Attach to the existing Sound: ON button.
#
# FEATURES:
# - Replaces Sound: ON with Resolution
# - Mobile and Tablet options
# - Resolution sizes editable in Inspector
# - Optional saving of selection
# - Loads saved selection on startup
# - Does not modify any battle or level scripts
# ==================================================


# ==================================================
# RESOLUTION OPTIONS
# ==================================================

@export_group("Mobile Resolution")

@export_range(320, 7680, 1)
var mobile_width: int = 956

@export_range(240, 4320, 1)
var mobile_height: int = 440

@export_group("Tablet Resolution")

@export_range(320, 7680, 1)
var tablet_width: int = 2360

@export_range(240, 4320, 1)
var tablet_height: int = 1640


# ==================================================
# BUTTON SETTINGS
# ==================================================

@export_group("Button Settings")

@export var button_text: String = "Resolution"

@export var mobile_option_name: String = "Mobile"

@export var tablet_option_name: String = "Tablet"

@export var show_resolution_dimensions: bool = true


# ==================================================
# SAVE SETTINGS
# ==================================================

@export_group("Save Settings")

@export var remember_resolution: bool = true

@export var apply_saved_resolution_on_start: bool = true

@export var save_file_path: String = (
	"user://food_heroes_display_settings.cfg"
)


# ==================================================
# WINDOW SETTINGS
# ==================================================

@export_group("Window Settings")

@export var switch_to_windowed_mode: bool = true

@export var center_window_after_change: bool = true


# ==================================================
# DEBUG
# ==================================================

@export_group("Debug")

@export var show_debug_messages: bool = false


# ==================================================
# CONSTANTS
# ==================================================

const MOBILE_ID: int = 0
const TABLET_ID: int = 1


# ==================================================
# VARIABLES
# ==================================================

var resolution_popup: PopupMenu = null

var current_resolution_id: int = -1


# ==================================================
# INITIALIZATION
# ==================================================

func _ready() -> void:

	$Label.text = button_text

	_create_resolution_popup()

	if not pressed.is_connected(
		_on_resolution_button_pressed
	):
		pressed.connect(
			_on_resolution_button_pressed
		)

	if remember_resolution and apply_saved_resolution_on_start:
		_load_resolution_settings()

	_debug("Resolution selector ready.")


# ==================================================
# CREATE POPUP
# ==================================================

func _create_resolution_popup() -> void:

	resolution_popup = PopupMenu.new()

	resolution_popup.name = "ResolutionPopup"

	add_child(resolution_popup)

	resolution_popup.add_radio_check_item(
		_get_mobile_option_text(),
		MOBILE_ID
	)

	resolution_popup.add_radio_check_item(
		_get_tablet_option_text(),
		TABLET_ID
	)

	resolution_popup.id_pressed.connect(
		_on_resolution_selected
	)

	_update_popup_selection()


# ==================================================
# OPTION TEXT
# ==================================================

func _get_mobile_option_text() -> String:

	if show_resolution_dimensions:

		return (
			mobile_option_name
			+ " ("
			+ str(mobile_width)
			+ " × "
			+ str(mobile_height)
			+ ")"
		)

	return mobile_option_name


func _get_tablet_option_text() -> String:

	if show_resolution_dimensions:

		return (
			tablet_option_name
			+ " ("
			+ str(tablet_width)
			+ " × "
			+ str(tablet_height)
			+ ")"
		)

	return tablet_option_name


# ==================================================
# BUTTON PRESSED
# ==================================================

func _on_resolution_button_pressed() -> void:

	if not is_instance_valid(resolution_popup):
		return

	resolution_popup.set_item_text(
		0,
		_get_mobile_option_text()
	)

	resolution_popup.set_item_text(
		1,
		_get_tablet_option_text()
	)

	_update_popup_selection()

	resolution_popup.popup_centered(
		Vector2i(300, 100)
	)


# ==================================================
# RESOLUTION SELECTED
# ==================================================

func _on_resolution_selected(
	option_id: int
) -> void:

	match option_id:

		MOBILE_ID:

			_apply_resolution(
				Vector2i(
					mobile_width,
					mobile_height
				),
				MOBILE_ID
			)

		TABLET_ID:

			_apply_resolution(
				Vector2i(
					tablet_width,
					tablet_height
				),
				TABLET_ID
			)
		_:
			return

	if remember_resolution:
		_save_resolution_settings()


# ==================================================
# APPLY RESOLUTION
# ==================================================

func _apply_resolution(
	new_size: Vector2i,
	option_id: int
) -> void:

	var game_window: Window = get_window()

	if not is_instance_valid(game_window):
		return

	if switch_to_windowed_mode:

		game_window.mode = (
			Window.MODE_WINDOWED
		)

	# Resize the game window.
	game_window.size = new_size

	# Center if requested.
	if center_window_after_change:
		_center_game_window(game_window)

	current_resolution_id = option_id

	_update_popup_selection()

	_debug(
		"Resolution changed to: "
		+ str(new_size.x)
		+ " × "
		+ str(new_size.y)
	)


# ==================================================
# CENTER GAME WINDOW
# ==================================================

func _center_game_window(
	game_window: Window
) -> void:

	var screen_index: int = (
		game_window.current_screen
	)

	var usable_rect: Rect2i = (
		DisplayServer.screen_get_usable_rect(
			screen_index
		)
	)

	var window_size: Vector2i = (
		game_window.size
	)

	var centered_position: Vector2i = (
		usable_rect.position
		+ Vector2i(Vector2(usable_rect.size - window_size) * 0.5)
	)

	# Avoid putting the top-left corner outside
	# the usable screen when the chosen resolution
	# is larger than the monitor.
	centered_position.x = maxi(
		centered_position.x,
		usable_rect.position.x
	)

	centered_position.y = maxi(
		centered_position.y,
		usable_rect.position.y
	)

	game_window.position = (
		centered_position
	)


# ==================================================
# UPDATE CHECKED OPTION
# ==================================================

func _update_popup_selection() -> void:

	if not is_instance_valid(
		resolution_popup
	):
		return

	for index in range(
		resolution_popup.item_count
	):

		var item_id: int = (
			resolution_popup.get_item_id(index)
		)

		resolution_popup.set_item_checked(
			index,
			item_id == current_resolution_id
		)


# ==================================================
# SAVE SELECTED RESOLUTION
# ==================================================

func _save_resolution_settings() -> void:

	var config: ConfigFile = ConfigFile.new()

	config.set_value(
		"Display",
		"resolution_id",
		current_resolution_id
	)

	var error: Error = (
		config.save(save_file_path)
	)

	if error != OK:

		push_warning(
			"[Resolution] Cannot save settings: "
			+ str(error)
		)
		return

	_debug("Resolution preference saved.")


# ==================================================
# LOAD SELECTED RESOLUTION
# ==================================================

func _load_resolution_settings() -> void:

	var config: ConfigFile = ConfigFile.new()

	var error: Error = (
		config.load(save_file_path)
	)

	if error != OK:
		return

	var saved_id: int = int(
		config.get_value(
			"Display",
			"resolution_id",
			-1
		)
	)

	match saved_id:

		MOBILE_ID:

			_apply_resolution(
				Vector2i(
					mobile_width,
					mobile_height
				),
				MOBILE_ID
			)

		TABLET_ID:

			_apply_resolution(
				Vector2i(
					tablet_width,
					tablet_height
				),
				TABLET_ID
			)


# ==================================================
# DEBUG
# ==================================================

func _debug(message: String) -> void:

	if show_debug_messages:

		print(
			"[MainMenuResolution] ",
			message
		)
