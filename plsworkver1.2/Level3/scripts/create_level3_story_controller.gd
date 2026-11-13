@tool
extends EditorScript

# ==================================================
# FOOD HEROES - LEVEL 3 STORY GENERATOR
# GODOT 4.7.1
#
# OPEN story_scene_level3.tscn FIRST.
#
# Copies the complete existing story controller.
# Changes its battle destination to Level 3.
#
# Preserves:
# - Dialogue pages
# - Dialogue animations
# - Tap and hold controls
# - Story transitions
# - Inspector configuration
#
# Does not modify the Level 2 story script.
# ==================================================


# ==================================================
# LEVEL 3 - STORY SETTINGS
# ==================================================

const OUTPUT_SCRIPT: String = (
	"res://Level3/scripts/"
	+ "story_scene_level3.gd"
)

const LEVEL3_BATTLE_SCENE: String = (
	"res://Level3/scenes/battle/"
	+ "battle_scene_level3.tscn"
)


# ==================================================
# GENERATE COMPLETE STORY CONTROLLER
# ==================================================

func _run() -> void:

	var scene_root: Node = (
		EditorInterface.get_edited_scene_root()
	)

	if scene_root == null:
		push_error(
			"[Level3Story] Open the Level 3 story first."
		)
		return

	if scene_root.scene_file_path != (
		"res://Level3/scenes/story_scene_level3.tscn"
	):
		push_error(
			"[Level3Story] The currently edited scene "
			+ "must be story_scene_level3.tscn."
		)
		return

	var source_script: Script = (
		scene_root.get_script() as Script
	)

	if source_script == null:
		push_error(
			"[Level3Story] Story root has no script."
		)
		return

	if FileAccess.file_exists(OUTPUT_SCRIPT):
		push_error(
			"[Level3Story] Output already exists. "
			+ "It will not be overwritten."
		)
		return

	var source_code: String = source_script.source_code

	# ==================================================
	# FIND THE ORIGINAL BATTLE DESTINATION
	#
	# Recognizes a quoted res:// scene path
	# containing the word "battle".
	#
	# Fails safely instead of guessing when
	# the destination is not identifiable.
	# ==================================================

	var regex := RegEx.new()

	var regex_error: Error = regex.compile(
		"res://[^\"'\\r\\n]*[Bb]attle[^\"'\\r\\n]*\\.tscn"
	)

	if regex_error != OK:
		push_error(
			"[Level3Story] Regex compilation failed."
		)
		return

	var matches: Array[RegExMatch] = (
		regex.search_all(source_code)
	)

	var original_paths: Dictionary = {}

	for match_result: RegExMatch in matches:
		original_paths[match_result.get_string()] = true

	if original_paths.size() != 1:
		push_error(
			"[Level3Story] Expected exactly one "
			+ "unique battle scene path. Found: "
			+ str(original_paths.keys())
			+ ". The source was not modified."
		)
		return

	var old_battle_path: String = str(
		original_paths.keys()[0]
	)

	var updated_code: String = source_code.replace(
		old_battle_path,
		LEVEL3_BATTLE_SCENE
	)

	# ==================================================
	# LEVEL 3 - GENERATOR COMMENTS
	# ==================================================

	var header: String = (
		"# ==================================================\n"
		+ "# FOOD HEROES - LEVEL 3 STORY\n"
		+ "# Independent copy of Level 2 story controller.\n"
		+ "#\n"
		+ "# STORY FLOW:\n"
		+ "# Scene3 Map -> Level 3 Story -> Level 3 Battle\n"
		+ "#\n"
		+ "# LEVEL 3 BATTLE DESTINATION:\n"
		+ "# res://Level3/scenes/battle/\n"
		+ "# battle_scene_level3.tscn\n"
		+ "#\n"
		+ "# Original Level 2 controller preserved.\n"
		+ "# ==================================================\n\n"
	)

	updated_code = header + updated_code

	# ==================================================
	# WRITE NEW SCRIPT
	# ==================================================

	var output_file: FileAccess = FileAccess.open(
		OUTPUT_SCRIPT,
		FileAccess.WRITE
	)

	if output_file == null:
		push_error(
			"[Level3Story] Cannot create script: "
			+ str(FileAccess.get_open_error())
		)
		return

	output_file.store_string(updated_code)
	output_file.close()

	EditorInterface.get_resource_filesystem().scan()

	print("")
	print("==========================================")
	print("[Level3Story] STORY CONTROLLER CREATED")
	print("[Level3Story] Original: ", old_battle_path)
	print("[Level3Story] New: ", LEVEL3_BATTLE_SCENE)
	print("[Level3Story] File: ", OUTPUT_SCRIPT)
	print("==========================================")
