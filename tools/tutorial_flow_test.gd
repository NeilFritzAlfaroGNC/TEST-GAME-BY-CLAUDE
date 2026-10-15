extends SceneTree

var failures: int = 0
var previous_tutorial: int = 0

class FoodProbe extends RefCounted:
	var food_group: String = ""
	var label: Label = Label.new()

	func _init(group: String) -> void:
		food_group = group
		label.text = "Tutorial food"

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		failures += 1
		printerr("FAIL: ", label)

func _run() -> void:
	await process_frame
	var db: Node = root.get_node("DB")
	var game_data: Node = root.get_node("GameData")
	var main_scene: PackedScene = load("res://scenes/Main.tscn") as PackedScene
	_check(main_scene != null, "Main gameplay scene loads")
	previous_tutorial = db.get_setting_int("tutorial_done", 0)
	game_data.call("start_level", "Easy", 1)
	game_data.set("tutorial_completed", false)
	game_data.set("tutorial_mode", false)
	var main: Node = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	_check(main.get_node("LessonPopup/Root").visible, "Level 1 opens the tutorial overlay")
	_check(String(main.get_node("LessonPopup/Root/Panel/LessonTitle").text) == "FOOD BELT & FOOD GROUPS", "first popup explains the belt and food groups")
	_check(String(main.get_node("LessonPopup/Root/FocusMarker").text) == "▼ FOOD BELT", "first popup points to the belt")
	_check(paused, "first popup pauses gameplay")
	main.call("_on_continue_pressed")
	_check(int(main.get("_tutorial_page")) == 1 and paused, "second popup retains paused gameplay")
	_check(String(main.get_node("LessonPopup/Root/Panel/LessonTitle").text) == "THE HUNGER MONSTER", "second popup explains enemies")
	_check(String(main.get_node("LessonPopup/Root/FocusMarker").text) == "▼ HUNGER MONSTER", "second popup points at the enemy")
	main.call("_on_continue_pressed")
	_check(int(main.get("_tutorial_page")) == 2 and not paused, "tutorial starts guided belt practice")
	await create_timer(0.5).timeout
	var foods: Node2D = main.get_node("Foods") as Node2D
	_check(foods.get_child_count() > 0, "real belt spawned draggable foods")
	var food_candidate: Node = null
	for item: Node in foods.get_children():
		if String(item.get("food_group")) == String(main.get("correct_group")):
			food_candidate = item
			break
	_check(food_candidate != null, "belt contains a matching tutorial food")
	if food_candidate != null:
		var first_drop: bool = bool(main.call("food_dropped_on_hero", food_candidate))
		_check(not first_drop and int(main.get("_tutorial_page")) == 3 and paused, "practice drop is safely returned")
		_check(String(main.get_node("LessonPopup/Root/Panel/LessonTitle").text) == "MATCH THE FOOD", "matching-food instructions follow")
		main.call("_on_continue_pressed")
		_check(int(main.get("_tutorial_page")) == 4 and not paused, "food-matching practice begins")
		var feed_probe: FoodProbe = FoodProbe.new("Go")
		var consumed: bool = bool(main.call("food_dropped_on_hero", feed_probe))
		_check(not consumed and int(main.get("_tutorial_page")) == 5 and paused, "matching drop opens the next lesson")
		main.call("_on_continue_pressed")
		_check(int(main.get("_tutorial_page")) == 6 and not paused, "wrong-food practice begins")
		var wrong_probe: FoodProbe = FoodProbe.new("Grow")
		var wrong_consumed: bool = bool(main.call("food_dropped_on_hero", wrong_probe))
		_check(not wrong_consumed and int(main.get("_tutorial_page")) == 7 and paused, "wrong food is safely rejected")
		main.call("_on_continue_pressed")
		_check(int(main.get("_tutorial_page")) == 8 and paused, "enemy practice explanation appears")
		main.call("_on_continue_pressed")
		_check(int(main.get("_tutorial_page")) == 9 and not paused, "correct-feed practice begins")
		var enemies: Array[Node] = get_nodes_in_group("enemies")
		_check(not enemies.is_empty(), "practice enemy exists")
		for enemy: Node in enemies:
			enemy.global_position = main.get_node("Hero").global_position + Vector2(-150.0, 0.0)
			enemy.set("speed", 0.0)
		var score_before: int = int(game_data.get("score"))
		var correct_probe: FoodProbe = FoodProbe.new("Go")
		var correct_consumed: bool = bool(main.call("food_dropped_on_hero", correct_probe))
		_check(correct_consumed, "matching food defeats practice enemy")
		_check(int(game_data.get("score")) == score_before + 10, "practice feed scores once")
		_check(int(main.get("_tutorial_page")) == 10 and paused, "successful practice opens lesson summary")
	while int(main.get("_tutorial_page")) < 13:
		main.call("_on_continue_pressed")
	_check(int(main.get("_tutorial_page")) == 13 and paused, "lesson reaches completion prompt")
	main.call("_on_continue_pressed")
	_check(not paused and not main.get_node("LessonPopup/Root").visible, "completion resumes the same Level 1 scene")
	await process_frame
	_check(bool(game_data.get("tutorial_completed")) and db.get_setting_int("tutorial_done", 0) == 1, "tutorial completion persists")
	main.queue_free()
	await process_frame
	db.set_setting_int("tutorial_done", previous_tutorial)
	game_data.set("tutorial_completed", previous_tutorial == 1)
	if failures == 0:
		print("TUTORIAL FLOW TEST: ALL PASS")
	else:
		printerr("TUTORIAL FLOW TEST: %d FAILURE(S)" % failures)
	quit(1 if failures > 0 else 0)
