extends Node2D
## Game scene controller.
## Drives the level loop: spawn enemies, check dropped food, score, lives,
## special attack effects (Go zap / Glow heal / Grow slam), lesson popup, win/lose.

@export var enemy_scene: PackedScene

@onready var hero: Area2D = $Hero
@onready var cam: Camera2D = $Camera2D
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

# Screen-shake state (used by the Grow slam).
var _shake_time: float = 0.0
var _shake_dur: float = 0.0
var _shake_strength: float = 0.0

const SPAWN_INTERVAL := 2.2
const POINTS_PER_ENEMY := 10

func _ready() -> void:
	# Clicking/dragging Area2D foods needs physics picking on the root viewport.
	get_viewport().physics_object_picking = true
	spawn_timer.wait_time = SPAWN_INTERVAL
	spawn_timer.timeout.connect(_spawn_enemy)
	lesson_root.visible = false
	Audio.play_music("music")
	_start_level()

func _process(delta: float) -> void:
	# Camera shake decay.
	if _shake_time > 0.0:
		_shake_time -= delta
		var s := _shake_strength * (_shake_time / _shake_dur)
		cam.offset = Vector2(randf_range(-s, s), randf_range(-s, s))
	elif cam.offset != Vector2.ZERO:
		cam.offset = Vector2.ZERO

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
		var result := defeat_closest_enemy()
		if result["hit"]:
			GameData.score += POINTS_PER_ENEMY
			hint_label.text = "Correct! %s is a %s food. Monster defeated!" % [food.label.text, correct_group]
			_play_attack(correct_group, result["pos"])
		else:
			hint_label.text = "Correct! %s is a %s food. Wait for a monster!" % [food.label.text, correct_group]
			Audio.play("correct")
		_set_hint_color(Color(0.10, 0.55, 0.15))
		_refresh_one_food(food)
		_update_hud()
	else:
		hint_label.text = "Oops! %s is not a %s food. Try again!" % [food.label.text, correct_group]
		_set_hint_color(Color(0.75, 0.10, 0.10))
		Audio.play("wrong")

func defeat_closest_enemy() -> Dictionary:
	var enemies := get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return {"hit": false, "pos": Vector2.ZERO}
	var closest = null
	var best: float = INF
	for e in enemies:
		var d: float = e.global_position.distance_to(hero.global_position)
		if d < best:
			best = d
			closest = e
	if closest != null:
		var pos: Vector2 = closest.global_position
		_despawn_enemy(closest)
		return {"hit": true, "pos": pos}
	return {"hit": false, "pos": Vector2.ZERO}

# Called by Enemy.gd when it reaches the hero.
func enemy_reached_hero(enemy) -> void:
	if not game_active or not enemy.is_in_group("enemies"):
		return
	GameData.lives -= 1
	hint_label.text = "Oh no! A Hunger Monster got through!"
	_set_hint_color(Color(0.75, 0.10, 0.10))
	Audio.play("wrong")
	_shake(6.0, 0.25)
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

# === Special attack effects (Phase 8) ===
func _play_attack(group: String, target: Vector2) -> void:
	match group:
		"Go":
			_effect_zap(hero.global_position, target)
		"Glow":
			_effect_heal(hero.global_position)
		"Grow":
			_effect_slam(target)
		_:
			_effect_zap(hero.global_position, target)

# Go = ZAP: a jagged lightning bolt from the Hero to the enemy.
func _effect_zap(from: Vector2, to: Vector2) -> void:
	Audio.play("zap")
	var line := Line2D.new()
	line.width = 6.0
	line.default_color = Color(1.0, 0.95, 0.30)
	line.z_index = 50
	add_child(line)
	var pts := PackedVector2Array()
	var segments := 8
	for i in range(segments + 1):
		var t := float(i) / float(segments)
		var p := from.lerp(to, t)
		if i != 0 and i != segments:
			p += Vector2(randf_range(-18, 18), randf_range(-18, 18))
		pts.append(p)
	line.points = pts
	var tw := create_tween()
	tw.tween_interval(0.06)
	tw.tween_property(line, "modulate:a", 0.0, 0.20)
	tw.tween_callback(line.queue_free)

# Glow = HEAL: a green pulse on the Hero plus an expanding ring.
func _effect_heal(center: Vector2) -> void:
	Audio.play("heal")
	_spawn_ring(center, Color(0.30, 0.95, 0.45))
	hero.modulate = Color(0.45, 1.0, 0.55)
	var tw := create_tween()
	tw.tween_property(hero, "modulate", Color(1, 1, 1, 1), 0.4)

# Grow = SLAM: a heavy impact ring, screen shake, and a Hero lunge.
func _effect_slam(target: Vector2) -> void:
	Audio.play("slam")
	_spawn_ring(target, Color(1.0, 0.55, 0.20))
	_shake(9.0, 0.30)
	var orig := hero.position
	var dir := (target - hero.global_position).normalized()
	var tw := create_tween()
	tw.tween_property(hero, "position", orig + dir * 28.0, 0.06)
	tw.tween_property(hero, "position", orig, 0.18)

func _spawn_ring(center: Vector2, color: Color) -> void:
	var ring := Line2D.new()
	ring.width = 6.0
	ring.default_color = color
	ring.closed = true
	ring.z_index = 40
	ring.position = center
	var pts := PackedVector2Array()
	var n := 24
	for i in range(n):
		var a := TAU * float(i) / float(n)
		pts.append(Vector2(cos(a), sin(a)) * 30.0)
	ring.points = pts
	add_child(ring)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector2(3.0, 3.0), 0.4)
	tw.tween_property(ring, "modulate:a", 0.0, 0.4)
	tw.set_parallel(false)
	tw.tween_callback(ring.queue_free)

func _shake(strength: float, duration: float) -> void:
	_shake_strength = strength
	_shake_dur = duration
	_shake_time = duration

# === Lesson popup after each level ===
func _level_complete() -> void:
	game_active = false
	spawn_timer.stop()
	Audio.play("correct")
	var lvl: Dictionary = GameData.LEVELS[GameData.current_level]
	lesson_title.text = lvl["name"] + " complete!"
	lesson_label.text = lvl["lesson"]
	lesson_root.visible = true

func _on_continue_pressed() -> void:
	Audio.play("click")
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
