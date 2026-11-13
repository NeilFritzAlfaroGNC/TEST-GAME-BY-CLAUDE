
extends Button

@export_file("*.tscn") var canteen_scene_path: String = ""


func _ready() -> void:
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)


func _on_pressed() -> void:
	if canteen_scene_path.is_empty():
		push_error("Canteen scene path has not been assigned.")
		return

	if not ResourceLoader.exists(canteen_scene_path):
		push_error(
			"Canteen scene not found: "
			+ canteen_scene_path
		)
		return

	var error: Error = get_tree().change_scene_to_file(
		canteen_scene_path
	)

	if error != OK:
		push_error(
			"Failed to load Canteen scene. Error code: "
			+ str(error)
		)
