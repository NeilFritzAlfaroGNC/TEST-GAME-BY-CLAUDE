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

# Boss/wave state (only used on boss levels — every 5th level).
var _boss_level: bool = false
var _wave: int = 0
var _total_waves: int = 0
var _wave_size: int = 0
var _wave_groups: Array = []    # the target food group for each wave (wave 1 = Go, rest random)
var boss = null                 # the boss enemy instance (untyped, like other cross-node refs)
var _meal_needed: Array = []    # boss meal groups still to feed (a balanced Go+Grow+Glow dish)
var _boss_active: bool = false

const BOSS_SPAWN_POS := Vector2(120, 320)

# Screen-shake state (used by the Grow slam).
var _shake_time: float = 0.0
var _shake_dur: float = 0.0
var _shake_strength: float = 0.0

const SPAWN_INTERVAL := 2.2
const POINTS_PER_ENEMY := 10
const BASE_ENEMY_SPEED := 70.0

# Set from the chosen difficulty in _start_level.
var _enemy_speed: float = BASE_ENEMY_SPEED
var _score_mult: int = 1

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
	var lvl: Dictionary = GameData.current_level_data()
	var diff: Dictionary = GameData.difficulty_data()
	correct_group = lvl["correct_group"]
	_enemy_speed = BASE_ENEMY_SPEED * float(diff["speed_mult"])
	_score_mult = int(diff["score_mult"])
	spawn_timer.wait_time = SPAWN_INTERVAL * float(diff["spawn_mult"])
	# Clear any leftover enemies from a previous level.
	for e in get_tree().get_nodes_in_group("enemies"):
		e.remove_from_group("enemies")
		e.queue_free()
	_clear_boss()
	_refresh_all_foods()
	game_active = true
	_boss_level = GameData.is_boss_level(GameData.current_level)
	if _boss_level:
		# Boss level: fight through waves, then the boss.
		_boss_active = false
		_total_waves = GameData.BOSS_WAVES
		_wave_size = GameData.BOSS_WAVE_SIZE + int(diff["enemy_bonus"])
		_wave = 0
		_build_wave_groups()
		_start_wave()
	else:
		# Normal level: one flat batch of monsters.
		enemies_to_spawn = int(lvl["enemies"]) + int(diff["enemy_bonus"])
		hint_label.text = "Drag a %s food onto the Hero!" % correct_group
		_set_hint_color(Color(0.12, 0.12, 0.12))
		spawn_timer.start()
		_spawn_enemy()   # first enemy right away
	_update_hud()

# Pick each wave's target group: wave 1 is always Go, wave 2 is a random
# Glow/Grow, and any further waves are fully random.
func _build_wave_groups() -> void:
	_wave_groups = ["Go"]
	for i in range(1, _total_waves):
		if i == 1:
			_wave_groups.append(["Glow", "Grow"][randi() % 2])
		else:
			_wave_groups.append(GameData.random_group())

# Start the next wave of a boss level.
func _start_wave() -> void:
	_wave += 1
	# Each wave teaches a different food group.
	correct_group = _wave_groups[_wave - 1]
	enemies_to_spawn = _wave_size
	_refresh_all_foods()   # re-roll foods so this wave's group is available
	hint_label.text = "Wave %d of %d — feed %s foods to clear the monsters!" % [_wave, _total_waves, correct_group]
	_set_hint_color(Color(0.12, 0.12, 0.12))
	spawn_timer.start()
	_spawn_enemy()   # first enemy right away
	_update_hud()

# === Enemy spawning (the WHILE loop) ===
func _spawn_enemy() -> void:
	if not game_active or enemies_to_spawn <= 0 or enemy_scene == null:
		return
	enemies_to_spawn -= 1
	var enemy = enemy_scene.instantiate()
	add_child(enemy)
	enemy.add_to_group("enemies")
	enemy.speed = _enemy_speed
	enemy.global_position = Vector2(120, randf_range(180, 470))

# === The teaching moment: right vs. wrong food (the IF/ELSE) ===
# Called by Food.gd when a food is dropped on the hero.
func food_dropped_on_hero(food) -> void:
	if not game_active:
		return
	# During the boss fight, ANY group can be part of the balanced meal, so the
	# boss handles its own right/wrong logic (build one Go + one Grow + one Glow).
	if _boss_active and is_instance_valid(boss):
		_feed_boss(food)
		return
	# In the waves (and normal levels), only this wave's group counts.
	if food.food_group != correct_group:
		hint_label.text = "Oops! %s is not a %s food. Try again!" % [food.label.text, correct_group]
		_set_hint_color(Color(0.75, 0.10, 0.10))
		Audio.play("wrong")
		return
	var result := defeat_closest_enemy()
	if result["hit"]:
		GameData.score += POINTS_PER_ENEMY * _score_mult
		hint_label.text = "Correct! %s is a %s food. Monster defeated!" % [food.label.text, correct_group]
		_play_attack(correct_group, result["pos"])
	else:
		hint_label.text = "Correct! %s is a %s food. Wait for a monster!" % [food.label.text, correct_group]
		Audio.play("correct")
	_show_nutrient_popup(GameData.food_nutrient(food.label.text), GameData.group_color(correct_group))
	_set_hint_color(Color(0.10, 0.55, 0.15))
	_refresh_one_food(food)
	_update_hud()

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
	if not game_active:
		return
	if enemy.is_in_group("boss"):
		_boss_reached_hero(enemy)
		return
	if not enemy.is_in_group("enemies"):
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
	# Still monsters left to spawn or fight in the current batch.
	if enemies_to_spawn > 0 or not get_tree().get_nodes_in_group("enemies").is_empty():
		return
	if _boss_level and not _boss_active:
		# A wave just cleared: start the next one, or unleash the boss.
		if _wave < _total_waves:
			_start_wave()
		else:
			_spawn_boss()
		return
	if not _boss_level:
		_level_complete()

# === Boss fight (build a balanced meal) ===
# Spawn the boss after the last wave. It reuses the Enemy scene but is bigger,
# slower, and lives in the "boss" group so it is never treated as a normal
# one-hit monster. To beat it the player builds a balanced meal: one food from
# each group (Go + Grow + Glow).
func _spawn_boss() -> void:
	_boss_active = true
	_meal_needed = GameData.BOSS_MEAL_GROUPS.duplicate()
	spawn_timer.stop()
	boss = enemy_scene.instantiate()
	add_child(boss)
	boss.add_to_group("boss")
	boss.speed = _enemy_speed * 0.5
	boss.scale = Vector2(2.2, 2.2)
	boss.global_position = BOSS_SPAWN_POS
	var rect = boss.get_node_or_null("ColorRect")
	if rect != null:
		rect.color = Color(0.42, 0.24, 0.52)   # neutral purple: it wants every group
	var lbl = boss.get_node_or_null("Label")
	if lbl != null:
		lbl.text = "BOSS"
	Audio.play("slam")
	_shake(9.0, 0.4)
	_refresh_boss_foods()
	hint_label.text = "BOSS! Build a balanced meal — feed one Go, one Grow, and one Glow food!"
	_set_hint_color(Color(0.75, 0.10, 0.10))
	_update_hud()

# A food was fed to the boss. Each still-needed group lands a hit; a group that
# is already in the meal does nothing (you need one of EACH, not duplicates).
func _feed_boss(food) -> void:
	var g: String = food.food_group
	if not _meal_needed.has(g):
		hint_label.text = "Already added a %s food! The meal still needs: %s." % [g, _meal_left_text()]
		_set_hint_color(Color(0.75, 0.10, 0.10))
		Audio.play("wrong")
		return
	# Valid new part of the meal.
	_meal_needed.erase(g)
	GameData.score += POINTS_PER_ENEMY * _score_mult
	_play_attack(g, boss.global_position)
	_show_nutrient_popup(GameData.food_nutrient(food.label.text), GameData.group_color(g))
	if _meal_needed.is_empty():
		_boss_active = false
		_clear_boss()
		hint_label.text = "Balanced meal complete! BOSS DEFEATED!"
		_set_hint_color(Color(0.10, 0.55, 0.15))
		_update_hud()
		_level_complete()
		return
	# Boss survived — flash it white and offer the remaining groups.
	var rect = boss.get_node_or_null("ColorRect")
	if rect != null:
		var base: Color = rect.color
		rect.color = Color(1, 1, 1)
		var tw := create_tween()
		tw.tween_property(rect, "color", base, 0.25)
	hint_label.text = "Added a %s food! Still need: %s." % [g, _meal_left_text()]
	_set_hint_color(Color(0.85, 0.45, 0.10))
	_refresh_boss_foods()
	_update_hud()

# Comma-joined list of the meal groups still missing.
func _meal_left_text() -> String:
	return ", ".join(PackedStringArray(_meal_needed))

# Fill the three food slots so every still-needed meal group is offered.
func _refresh_boss_foods() -> void:
	var groups: Array = _meal_needed.duplicate()
	while groups.size() < foods.size():
		groups.append(GameData.random_group())
	groups.shuffle()
	for i in range(foods.size()):
		foods[i].set_food(groups[i])

# The boss reached the hero: costs a life, then it is knocked back to keep fighting.
func _boss_reached_hero(b) -> void:
	GameData.lives -= 1
	hint_label.text = "The BOSS struck the Hero!"
	_set_hint_color(Color(0.75, 0.10, 0.10))
	Audio.play("wrong")
	_shake(9.0, 0.3)
	if GameData.lives <= 0:
		_boss_active = false
		_clear_boss()
		_update_hud()
		_game_over()
		return
	if is_instance_valid(b):
		b.global_position = BOSS_SPAWN_POS
		b.reached = false
	_update_hud()

func _clear_boss() -> void:
	if is_instance_valid(boss):
		boss.remove_from_group("boss")
		boss.queue_free()
	boss = null

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

# Floating "+nutrient" text that rises from the Hero and fades — a small visual
# reward that also teaches what each correct food provides.
func _show_nutrient_popup(text: String, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.z_index = 60
	lbl.add_theme_font_size_override("font_size", 28)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	lbl.add_theme_constant_override("outline_size", 5)
	lbl.position = hero.position + Vector2(randf_range(-40, 0), -80)
	add_child(lbl)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 80.0, 0.9)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.9)
	tw.set_parallel(false)
	tw.tween_callback(lbl.queue_free)

# === Lesson popup after each level ===
func _level_complete() -> void:
	game_active = false
	spawn_timer.stop()
	Audio.play("correct")
	var lvl: Dictionary = GameData.current_level_data()
	if _boss_level:
		lesson_title.text = "Balanced Meal Complete!"
		lesson_label.text = GameData.BOSS_LESSON
	else:
		lesson_title.text = "Level %d Complete!" % GameData.current_level
		lesson_label.text = lvl["lesson"]
	lesson_root.visible = true

func _on_continue_pressed() -> void:
	Audio.play("click")
	lesson_root.visible = false
	GameData.record_result(true)
	get_tree().change_scene_to_file("res://scenes/ResultScreen.tscn")

func _game_over() -> void:
	game_active = false
	spawn_timer.stop()
	GameData.record_result(false)
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
	level_label.text = "Level %d: %s  [%s]" % [GameData.current_level, GameData.current_level_data()["name"], GameData.current_difficulty]
	if _boss_active:
		target_label.text = "BOSS — build a meal!  Need: %s" % _meal_left_text()
	elif _boss_level:
		target_label.text = "Wave %d/%d   Feed  %s  foods!" % [_wave, _total_waves, correct_group]
	else:
		target_label.text = "Feed the Hero  %s  foods!" % correct_group
	target_label.add_theme_color_override("font_color", GameData.group_color(correct_group))

func _set_hint_color(c: Color) -> void:
	hint_label.add_theme_color_override("font_color", c)
