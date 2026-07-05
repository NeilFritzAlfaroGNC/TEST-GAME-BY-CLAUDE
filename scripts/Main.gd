extends Node2D
## Game scene controller (the façade other scripts talk to).
## Drives the level state machine: spawn enemies, check dropped food, score,
## lives, waves + boss fights, lesson popup, win/lose. The conveyor belt lives
## in BeltManager ("Belt" child) and all procedural effects in FxManager
## ("Fx" child) — both created here in code.
##
## CONTRACT (do not break): Food.gd / Enemy.gd reach this script via
## get_tree().current_scene and call food_dropped_on_hero / enemy_reached_hero
## with untyped params; they find the hero at get_node("Hero"); PauseMenu.gd
## reads `game_active` and iterates `foods_container`.

const BeltManagerScript := preload("res://scripts/BeltManager.gd")
const FxManagerScript := preload("res://scripts/FxManager.gd")

@export var enemy_scene: PackedScene
@export var food_scene: PackedScene

@onready var hero: Area2D = $Hero
@onready var cam: Camera2D = $Camera2D
@onready var hint_label: Label = $HUD/HintLabel
@onready var score_label: Label = $HUD/ScoreLabel
@onready var lives_label: Label = $HUD/LivesLabel
@onready var level_label: Label = $HUD/LevelLabel
@onready var highscore_label: Label = $HUD/HighScoreLabel
@onready var target_label: Label = $HUD/TargetLabel
@onready var spawn_timer: Timer = $Timer
@onready var lesson_root: Control = $LessonPopup/Root
@onready var lesson_title: Label = $LessonPopup/Root/Panel/LessonTitle
@onready var lesson_label: Label = $LessonPopup/Root/Panel/LessonLabel
@onready var foods_container: Node2D = $Foods

var correct_group: String = "Go"
var enemies_to_spawn: int = 0
var game_active: bool = false

# The two code-created components (untyped, called dynamically).
var belt = null
var fx = null

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
const BOSS_COLOR := Color(0.42, 0.24, 0.52)   # neutral purple: the boss wants every group

# Tutorial intro pages, shown one by one through the lesson popup before the
# guided first wave starts (GameData.tutorial_mode). [title, text] pairs.
const TUTORIAL_PAGES := [
	["Welcome to Food Heroes!",
	 "The blue box is the HERO. Hungry Monsters march in from the left — don't let them reach him!"],
	["The Food Belt",
	 "Foods ride the conveyor belt at the bottom.\nYELLOW = GO (energy)   GREEN = GLOW (protect)   RED = GROW (build)\nGrab a food before it blinks away — new ones keep coming!"],
	["Feed the Hero",
	 "DRAG a food from the belt and DROP it on the Hero.\nThe RIGHT food group defeats the closest monster.\nA wrong food just rides back onto the belt — no harm done, try again!"],
	["Your First Mission",
	 "Feed the Hero GO foods (yellow) to defeat 3 slow monsters.\nYou have 5 lives, and you can pause any time with Esc or the Pause button.\nGood luck, Hero!"],
]
var _tutorial_page: int = 0
var _tutorial_intro_active: bool = false

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
	fx = FxManagerScript.new()
	fx.name = "Fx"
	add_child(fx)
	fx.setup(hero, cam)
	belt = BeltManagerScript.new()
	belt.name = "Belt"
	add_child(belt)
	belt.setup(food_scene, foods_container, _needed_groups)
	lesson_root.visible = false
	Audio.play_music("music")
	_start_level()

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
	belt.clear_foods()
	game_active = true
	if GameData.tutorial_mode:
		# Guided first run: one small, extra-slow GO wave. The intro pages show
		# first; monsters and the belt only start when the last page is closed.
		_boss_level = false
		correct_group = "Go"
		_enemy_speed = BASE_ENEMY_SPEED * GameData.TUTORIAL_SPEED_MULT
		_score_mult = 1
		spawn_timer.wait_time = SPAWN_INTERVAL * GameData.TUTORIAL_SPAWN_MULT
		enemies_to_spawn = GameData.TUTORIAL_ENEMIES
		hint_label.text = "Drag GO (yellow) foods onto the Hero!"
		_set_hint_color(Color(0.12, 0.12, 0.12))
		_update_hud()
		_show_tutorial_page(0)
		return
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
	# Start the belt AFTER the branch above so the seeded foods match the
	# actual first wave/level group (not level data a boss level ignores).
	belt.start()
	_update_hud()

# === Tutorial intro (pages through the lesson popup, then a slow wave) ===
func _show_tutorial_page(i: int) -> void:
	_tutorial_page = i
	_tutorial_intro_active = true
	lesson_title.text = TUTORIAL_PAGES[i][0]
	lesson_label.text = TUTORIAL_PAGES[i][1]
	lesson_root.visible = true

func _advance_tutorial_intro() -> void:
	if _tutorial_page + 1 < TUTORIAL_PAGES.size():
		_show_tutorial_page(_tutorial_page + 1)
		return
	# Intro done: unleash the (slow) monsters and roll the belt.
	_tutorial_intro_active = false
	lesson_root.visible = false
	spawn_timer.start()
	_spawn_enemy()   # first monster right away
	belt.start()
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
	# The belt auto-adjusts: it always keeps this wave's group available.
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
# Called by Food.gd when a food is dropped on the hero. Returns true if the
# food was used (so the belt food should be consumed), false to keep it riding.
func food_dropped_on_hero(food) -> bool:
	if not game_active:
		return false
	# During the boss fight, ANY group can be part of the balanced meal, so the
	# boss handles its own right/wrong logic (build one Go + one Grow + one Glow).
	if _boss_active:
		# _clear_boss always drops _boss_active together with the instance, so a
		# missing boss here is a broken invariant — keep the food on the belt and
		# never fall through to the (stale) last-wave group check below.
		if not is_instance_valid(boss):
			return false
		return _feed_boss(food)
	# In the waves (and normal levels), only this wave's group counts.
	if food.food_group != correct_group:
		hint_label.text = "Oops! %s is not a %s food. Try again!" % [food.label.text, correct_group]
		_set_hint_color(Color(0.75, 0.10, 0.10))
		Audio.play("wrong")
		return false
	# Cache the fed food's name now: defeating the last enemy can start the next
	# wave (deferred).
	var fed_name: String = food.label.text
	var result := defeat_closest_enemy()
	if result["hit"]:
		GameData.score += POINTS_PER_ENEMY * _score_mult
		hint_label.text = "Correct! %s is a %s food. Monster defeated!" % [fed_name, correct_group]
		fx.play_attack(correct_group, result["pos"])
	else:
		hint_label.text = "Correct! %s is a %s food. Wait for a monster!" % [fed_name, correct_group]
		Audio.play("correct")
	fx.nutrient_popup(GameData.food_nutrient(fed_name), GameData.group_color(correct_group))
	_set_hint_color(Color(0.10, 0.55, 0.15))
	_update_hud()
	return true

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
	fx.shake(6.0, 0.25)
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
	# Deferred so the caller (e.g. food_dropped_on_hero) finishes its own
	# popup before a wave transition.
	_check_level_complete.call_deferred()

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
		rect.color = BOSS_COLOR
	var lbl = boss.get_node_or_null("Label")
	if lbl != null:
		lbl.text = "BOSS"
	Audio.play("slam")
	fx.shake(9.0, 0.4)
	hint_label.text = "BOSS! Build a balanced meal — feed one Go, one Grow, and one Glow food!"
	_set_hint_color(Color(0.75, 0.10, 0.10))
	_update_hud()

# A food was fed to the boss. Each still-needed group lands a hit; a group that
# is already in the meal does nothing (you need one of EACH, not duplicates).
# Returns true if the food was accepted (consumed), false otherwise.
func _feed_boss(food) -> bool:
	var g: String = food.food_group
	if not _meal_needed.has(g):
		hint_label.text = "Already added a %s food! The meal still needs: %s." % [g, _meal_left_text()]
		_set_hint_color(Color(0.75, 0.10, 0.10))
		Audio.play("wrong")
		return false
	# Valid new part of the meal.
	_meal_needed.erase(g)
	GameData.score += POINTS_PER_ENEMY * _score_mult
	fx.play_attack(g, boss.global_position)
	fx.nutrient_popup(GameData.food_nutrient(food.label.text), GameData.group_color(g))
	if _meal_needed.is_empty():
		_boss_active = false
		_clear_boss()
		hint_label.text = "Balanced meal complete! BOSS DEFEATED!"
		_set_hint_color(Color(0.10, 0.55, 0.15))
		_update_hud()
		_level_complete()
		return true
	# Boss survived — flash it white; the belt keeps offering the remaining groups.
	var rect = boss.get_node_or_null("ColorRect")
	if rect != null:
		var base: Color = rect.color
		rect.color = Color(1, 1, 1)
		var tw := create_tween()
		tw.tween_property(rect, "color", base, 0.25)
	hint_label.text = "Added a %s food! Still need: %s." % [g, _meal_left_text()]
	_set_hint_color(Color(0.85, 0.45, 0.10))
	_update_hud()
	return true

# Comma-joined list of the meal groups still missing.
func _meal_left_text() -> String:
	return ", ".join(PackedStringArray(_meal_needed))

# The boss reached the hero: costs a life, then it is knocked back to keep fighting.
func _boss_reached_hero(b) -> void:
	GameData.lives -= 1
	hint_label.text = "The BOSS struck the Hero!"
	_set_hint_color(Color(0.75, 0.10, 0.10))
	Audio.play("wrong")
	fx.shake(9.0, 0.3)
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

# Shared end-of-level shutdown (win AND lose take the same path): freeze the
# loop and empty the belt.
func _stop_level() -> void:
	game_active = false
	spawn_timer.stop()
	belt.stop()
	belt.clear_foods()

# === Lesson popup after each level ===
func _level_complete() -> void:
	_stop_level()
	Audio.play("correct")
	var lvl: Dictionary = GameData.current_level_data()
	if GameData.tutorial_mode:
		lesson_title.text = "Tutorial Complete!"
		lesson_label.text = "You're ready, Hero! Remember: GO gives energy, GLOW protects you, GROW builds your body — eat from all three groups every day. Now pick a level and save the day!"
	elif _boss_level:
		lesson_title.text = "Balanced Meal Complete!"
		lesson_label.text = GameData.BOSS_LESSON
	else:
		lesson_title.text = "Level %d Complete!" % GameData.current_level
		lesson_label.text = lvl["lesson"]
	lesson_root.visible = true

func _on_continue_pressed() -> void:
	Audio.play("click")
	if _tutorial_intro_active:
		_advance_tutorial_intro()
		return
	lesson_root.visible = false
	if GameData.tutorial_mode:
		# Tutorial cleared: remember it, then hand over to the real game.
		# Nothing is recorded — the tutorial doesn't count as level 1.
		DB.set_setting_int("tutorial_done", 1)
		GameData.tutorial_mode = false
		get_tree().change_scene_to_file("res://scenes/LevelSelect.tscn")
		return
	GameData.record_result(true)
	get_tree().change_scene_to_file("res://scenes/ResultScreen.tscn")

func _game_over() -> void:
	_stop_level()
	if GameData.tutorial_mode:
		# The tutorial can't be failed out of — just run it again.
		GameData.start_tutorial()
		get_tree().change_scene_to_file("res://scenes/Main.tscn")
		return
	GameData.record_result(false)
	get_tree().change_scene_to_file("res://scenes/ResultScreen.tscn")

# === Belt contract ===
# The groups the belt must keep available: this wave/level's group, or (during
# the boss) every group still missing from the balanced meal. BeltManager
# calls this every frame through the Callable handed over in _ready.
func _needed_groups() -> Array:
	if _boss_active:
		return _meal_needed.duplicate()   # copy — callers must never alias the live meal state
	return [correct_group]

# === HUD ===
func _update_hud() -> void:
	score_label.text = "Score: %d" % GameData.score
	lives_label.text = "Lives: %d" % GameData.lives
	highscore_label.text = "High Score: %d" % maxi(GameData.high_score, GameData.score)
	# Boss levels ignore their LEVELS row (waves + boss instead), so show a
	# boss title rather than the unused level name.
	var lvl_name: String = "BOSS: Balanced Meal" if _boss_level else String(GameData.current_level_data()["name"])
	if GameData.tutorial_mode:
		level_label.text = "TUTORIAL — learn the basics"
	else:
		level_label.text = "Level %d: %s  [%s]" % [GameData.current_level, lvl_name, GameData.current_difficulty]
	if _boss_active:
		target_label.text = "BOSS — build a meal!  Need: %s" % _meal_left_text()
		target_label.add_theme_color_override("font_color", BOSS_COLOR)
	elif _boss_level:
		target_label.text = "Wave %d/%d   Feed  %s  foods!" % [_wave, _total_waves, correct_group]
		target_label.add_theme_color_override("font_color", GameData.group_color(correct_group))
	else:
		target_label.text = "Feed the Hero  %s  foods!" % correct_group
		target_label.add_theme_color_override("font_color", GameData.group_color(correct_group))

func _set_hint_color(c: Color) -> void:
	hint_label.add_theme_color_override("font_color", c)
