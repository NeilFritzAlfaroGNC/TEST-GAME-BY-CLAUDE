@tool
extends EditorScript

# ==================================================
# LEVEL 3 - BATTLE CONTROLLER GENERATOR
# GODOT 4.7.1
#
# PURPOSE:
# Copies the complete script attached to the
# CURRENTLY OPEN Level 3 battle scene.
#
# Preserves:
# - GO, GLOW, GROW gameplay
# - Food dragging and inspection
# - Food combinations
# - Nutrition and enemy systems
# - Existing Victory logic
#
# Changes:
# - cafeteria_level_1 -> scene3_level_3
#
# DOES NOT:
# - Modify the original script
# - Modify ProgressManager
# - Change the original battle scene
# - Automatically activate Level 3
#
# Run once from the Godot Script Editor.
# ==================================================


const OUTPUT_PATH: String = (
	"res://Level3/scripts/battle/"
	+ "level3_battle_controller.gd"
)

const OLD_LEVEL_ID_LINE: String = (
	'const LEVEL_ID: String = "cafeteria_level_1"'
)

const NEW_LEVEL_ID_LINE: String = (
	'const LEVEL_ID: String = "scene3_level_3"'
)


func _run() -> void:

	# ==============================================
	# STEP 1 - READ THE OPEN BATTLE SCENE
	# ==============================================

	var scene_root: Node = (
		EditorInterface.get_edited_scene_root()
	)

	if scene_root == null:
		push_error(
			"[Level3Generator] "
			+ "Open battle_scene_level3.tscn first."
		)
		return

	var source_script: Script = (
		scene_root.get_script() as Script
	)

	if source_script == null:
		push_error(
			"[Level3Generator] "
			+ "Battle root has no attached script."
		)
		return

	# ==============================================
	# STEP 2 - VALIDATE THE SOURCE
	# ==============================================

	if FileAccess.file_exists(OUTPUT_PATH):
		push_error(
			"[Level3Generator] Output already exists. "
			+ "No file was overwritten: "
			+ OUTPUT_PATH
		)
		return

	var source_code: String = (
		source_script.source_code
	)

	var match_count: int = (
		source_code.count(OLD_LEVEL_ID_LINE)
	)

	if match_count != 1:
		push_error(
			"[Level3Generator] Expected exactly "
			+ "one Cafeteria LEVEL_ID declaration. "
			+ "Found: "
			+ str(match_count)
		)
		return

	# ==============================================
	# STEP 3 - CREATE THE LEVEL 3 SOURCE
	# ==============================================

	var updated_code: String = (
		source_code.replace(
			OLD_LEVEL_ID_LINE,
			NEW_LEVEL_ID_LINE
		)
	)

	var header: String = (
		"# ==================================================\n"
		+ "# LEVEL 3 - INDEPENDENT BATTLE CONTROLLER\n"
		+ "#\n"
		+ "# Generated from the preserved Cafeteria battle.\n"
		+ "#\n"
		+ "# LEVEL 3 PROGRESSION:\n"
		+ "# Uses scene3_level_3 instead of\n"
		+ "# cafeteria_level_1 for saved stars.\n"
		+ "#\n"
		+ "# The original battle script is unchanged.\n"
		+ "# ==================================================\n\n"
	)

	updated_code = header + updated_code

	# ==============================================
	# STEP 4 - WRITE THE INDEPENDENT SCRIPT
	# ==============================================

	var output_file: FileAccess = (
		FileAccess.open(
			OUTPUT_PATH,
			FileAccess.WRITE
		)
	)

	if output_file == null:
		push_error(
			"[Level3Generator] Cannot create file. "
			+ "Error: "
			+ str(FileAccess.get_open_error())
		)
		return

	output_file.store_string(updated_code)
	output_file.close()

	# ==============================================
	# STEP 5 - REFRESH GODOT FILESYSTEM
	# ==============================================

	EditorInterface.get_resource_filesystem().scan()

	print("")
	print("======================================")
	print("[Level3Generator] SUCCESS")
	print("Created: ", OUTPUT_PATH)
	print("Original script: ", source_script.resource_path)
	print("Level ID: scene3_level_3")
	print("Original script left unchanged.")
	print("======================================")
	print("")
