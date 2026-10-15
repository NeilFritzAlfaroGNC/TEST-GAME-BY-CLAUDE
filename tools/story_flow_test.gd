extends SceneTree

var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		printerr("FAIL: ", description)

func _run() -> void:
	await process_frame
	var menu_scene: PackedScene = load("res://scenes/MainMenu.tscn") as PackedScene
	var level_select_scene: PackedScene = load("res://scenes/LevelSelect.tscn") as PackedScene
	var story_scene: PackedScene = load("res://scenes/StoryScene.tscn") as PackedScene
	var gameplay_scene: PackedScene = load("res://scenes/Main.tscn") as PackedScene
	var story_data: StoryCollection = load("res://resources/story/Level1Story.tres") as StoryCollection
	_check(menu_scene != null and level_select_scene != null and story_scene != null and gameplay_scene != null, "menu, level select, story, and gameplay scenes load")
	_check(story_data != null and story_data.sequences.size() == 2, "initial data contains exactly two sequences")
	if story_data != null and story_data.sequences.size() == 2:
		var first: StorySequence = story_data.sequences[0]
		var second: StorySequence = story_data.sequences[1]
		_check(first.background != null and first.background.resource_path == "res://assets/story/level 1/Story 1.png", "sequence 1 loads exact Story 1 image")
		_check(second.background != null and second.background.resource_path == "res://assets/story/level 1/Story 2.png", "sequence 2 loads exact Story 2 image")
		_check(first.dialogue_entries.size() == 1 and first.dialogue_entries[0].length() == 212, "sequence 1 placeholder is one entry")
		_check(second.dialogue_entries.size() == 1 and second.dialogue_entries[0].length() == 212, "sequence 2 placeholder is one entry")
	var menu: Node = menu_scene.instantiate()
	root.add_child(menu)
	await process_frame
	_check(not menu.has_node("MenuPanel/Buttons/HowToPlayButton"), "title menu no longer contains How to Play")
	menu.queue_free()
	await process_frame
	var game_data: Node = root.get_node("GameData")
	game_data.call("start_level", "Easy", 1)
	var level_select: Node = level_select_scene.instantiate()
	root.add_child(level_select)
	await process_frame
	level_select.call("_on_level_pressed", 1)
	await process_frame
	var story: Node = current_scene
	_check(story != null and story.scene_file_path == "res://scenes/StoryScene.tscn", "Level 1 selection routes into dedicated story scene")
	_check(current_scene.scene_file_path != "res://scenes/Main.tscn", "gameplay is absent before story completion")
	var story_node: StoryScene = story as StoryScene
	_check(story_node != null and story_node.background.texture == story_data.sequences[0].background, "story opens on Story 1 background")
	_check(story_node.dialogue_text == story_data.sequences[0].dialogue_entries[0], "sequence 1 first entry is displayed")
	if story_node != null:
		story_node._advance_dialogue()
		_check(story_node.sequence_index == 1 and story_node.dialogue_index == 0, "last entry advances automatically to sequence 2 first entry")
		_check(story_node.background.texture == story_data.sequences[1].background, "Story 2 image is displayed")
		_check(not story_node._finished, "story remains active until final sequence entry advances")
		story_node._advance_dialogue()
		_check(story_node._finished, "advancing final entry marks story complete")
		_check(story_node._finished, "story completion is latched exactly once")
	await process_frame
	if failures == 0:
		print("STORY FLOW TEST: ALL PASS")
	else:
		printerr("STORY FLOW TEST: %d FAILURE(S)" % failures)
	quit(1 if failures > 0 else 0)
