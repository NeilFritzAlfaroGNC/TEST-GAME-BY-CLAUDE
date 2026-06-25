extends Node2D
## Game scene controller.
## Drives the level loop: spawn enemies, check dropped food, score, lives,
## lesson popup after each level, then win or lose.

@export var enemy_scene: PackedScene

@onready var hero: Area2D = $Hero
@onready var hint_label: Label = $HUD/HintLabel
@onready var score_label: Label = $HUD/ScoreLabel
@onready var lives_label: Label = $HUD/LivesLabel
@onready var level_label: Label = $HUD/LevelLabel
@onready var target_label: Label = $HUD/TargetLabel
@onready var spawn_timer: Timer = $Timer
@onready var lesson_root: Control = $LessonPopup/Root
@onready var lesson_title: Label = $LessonPopup/Root/Panel/LessonTitle
@onready var lesson_label: Label = $LessonPopup/Root/Panel/LessonLabel
@onready var foods: Array = [$Foods/Food1, $Foods/Food2, $Foods/Food3]

var correct_group: String = "Go"
var enemies_to_spawn: int = 0
var game_active: bool = false

const SPAWN_INTERVAL := 2.2
const POINTS_PER_ENEMY := 10

func _ready() -> void:
	# Clicking/dragging Area2D foods needs physics picking on the root viewport.
	get_viewport().physics_object_picking = true
	spawn_timer.wait_time = SPAWN_INTERVAL
	spawn_timer.timeout.connect(_spawn_enemy)
	lesson_root.visible = false
	_start_level()

# === Level setup ===
func _start_level() -> void:
	var lvl: Dictionary = GameData.LEVELS[GameData.current_level]
	correct_group = lvl["correct_group"]
	enemies_to_spawn = lvl["enemies"]
	# Clear any leftover enemies from a previous level.
	for e in get_tree().get_nodes_in_group("enemies"):
		e.remove_from_group("enemies")
		e.queue_free()
	_refresh_all_foods()
	_update_hud()
	hint_label.text = "Drag a %s food onto the Hero!" % correct_group
	_set_hint_color(Color(0.12, 0.12, 0.12))
	game_active = true
	spawn_timer.start()
	_spawn_enemy()   # first enemy right away

# === Enemy spawning (the WHILE loop) ===
func _spawn_enemy() -> void:
	if not game_active or enemies_to_spawn <= 0 or enemy_scene == null:
		return
	enemies_to_spawn -= 1
	var enemy = enemy_scene.instantiate()
	add_child(enemy)
	enemy.add_to_group("enemies")
	enemy.global_position = Vector2(120, randf_range(180, 470))

# === The teaching moment: right vs. wrong food (the IF/ELSE) ===
# Called by Food.gd when a food is dropped on the hero.
func food_dropped_on_hero(food) -> void:
	if not game_active:
		return
	if food.food_group == correct_group:
		var defeated := defeat_closest_enemy()
		if defeated:
			GameData.score += POINTS_PER_ENEMY
			hint_label.text = "Correct! %s is a %s food. Monster defeated!" % [food.label.text, correct_group]
		else:
			hint_label.text = "Correct! %s is a %s food. Wait for a monster!" % [food.label.text, correct_group]
		_set_hint_color(Color(0.10, 0.55, 0.15))
		_refresh_one_food(food)
		_update_hud()
	else:
		hint_label.text = "Oops! %s is not a %s food. Try again!" % [food.label.text, correct_group]
		_set_hint_color(Color(0.75, 0.10, 0.10))

func defeat_closest_enemy() -> bool:
	var enemies := get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return false
	var closest = null
	var best: float = INF
	for e in enemies:
		var d: float = e.global_position.distance_to(hero.global_position)
		if d < best:
			best = d
			closest = e
	if closest != null:
		_despawn_enemy(closest)
		return true
	return false

# Called by Enemy.gd when it reaches the hero.
func enemy_reached_hero(enemy) -> void:
	if not game_active or not enemy.is_in_group("enemies"):
		return
	GameData.lives -= 1
	hint_label.text = "Oh no! A Hunger Monster got through!"
	_set_hint_color(Color(0.75, 0.10, 0.10))
	if GameData.lives <= 0:
		enemy.remove_from_group("enemies")
		enemy.queue_free()
		_update_hud()
		_game_over()
		return
	_update_hud()
	_despawn_enemy(enemy)

func _despawn_enemy(enemy) -> void:
	if not is_instance_valid(enemy):
		return
	if enemy.is_in_group("enemies"):
		enemy.remove_from_group("enemies")
	enemy.queue_free()
	_check_level_complete()

func _check_level_complete() -> void:
	if not game_active:
		return
	if enemies_to_spawn <= 0 and get_tree().get_nodes_in_group("enemies").is_empty():
		_level_complete()

# === Lesson popup after each level ===
func _level_complete() -> void:
	game_active = false
	spawn_timer.stop()
	var lvl: Dictionary = GameData.LEVELS[GameData.current_level]
	lesson_title.text = lvl["name"] + " complete!"
	lesson_label.text = lvl["lesson"]
	lesson_root.visible = true

func _on_continue_pressed() -> void:
	lesson_root.visible = false
	GameData.current_level += 1
	if GameData.current_level >= GameData.LEVELS.size():
		GameData.last_result = "win"
		GameData.save_game()
		get_tree().change_scene_to_file("res://scenes/ResultScreen.tscn")
	else:
		_start_level()

func _game_over() -> void:
	game_active = false
	spawn_timer.stop()
	GameData.last_result = "lose"
	GameData.save_game()
	get_tree().change_scene_to_file("res://scenes/ResultScreen.tscn")

# === Food helpers (keep the level solvable) ===
func _refresh_all_foods() -> void:
	var groups: Array = [correct_group]   # guarantee at least one correct food
	for i in range(foods.size() - 1):
		groups.append(GameData.random_group())
	groups.shuffle()
	for i in range(foods.size()):
		foods[i].set_food(groups[i])

func _refresh_one_food(food) -> void:
	food.set_food(GameData.random_group())
	# Make sure at least one correct food is always available.
	var has_correct := false
	for f in foods:
		if f.food_group == correct_group:
			has_correct = true
			break
	if not has_correct:
		food.set_food(correct_group)

# === HUD ===
func _update_hud() -> void:
	score_label.text = "Score: %d" % GameData.score
	lives_label.text = "Lives: %d" % GameData.lives
	level_label.text = GameData.LEVELS[GameData.current_level]["name"]
	target_label.text = "Feed the Hero  %s  foods!" % correct_group
	target_label.add_theme_color_override("font_color", GameData.group_color(correct_group))

func _set_hint_color(c: Color) -> void:
	hint_label.add_theme_color_override("font_color", c)
