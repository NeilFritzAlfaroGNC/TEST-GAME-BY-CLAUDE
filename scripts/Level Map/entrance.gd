
extends Button

const CAFETERIA_STORY_SCENE_PATH: String = "res://scenes/Story Scene/cafeteria_story_scene.tscn"


func _ready() -> void:
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	if not ResourceLoader.exists(CAFETERIA_STORY_SCENE_PATH):
		push_error(
			"Cafeteria story scene not found: "
			+ CAFETERIA_STORY_SCENE_PATH
		)
		return

	var error: Error = get_tree().change_scene_to_file(
		CAFETERIA_STORY_SCENE_PATH
	)

	if error != OK:
		push_error(
			"Failed to load cafeteria story scene. Error code: "
			+ str(error)
		)
