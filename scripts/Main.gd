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
## The scene supplies Hero, HUD, Timer, Foods, and packed food/enemy scenes.
## Food.gd calls food_dropped_on_hero(); Enemy.gd reports arrivals here. This
## controller owns level phases, scoring, boss requirements, lessons, and results.

const BeltManagerScript := preload("res://scripts/BeltManager.gd")
const FxManagerScript := preload("res://scripts/FxManager.gd")
const TutorialWords := preload("res://scripts/TutorialText.gd")

@export var enemy_scene: PackedScene
@export var enemy2_scene: PackedScene
@export var food_scene: PackedScene

@onready var hero: Area2D = $Hero
@onready var hero_sprite: AnimatedSprite2D = $Hero/Sprite
@onready var background_rect: TextureRect = $BackgroundLayer/Background
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
@onready var tutorial_focus: Label = $LessonPopup/Root/FocusMarker
@onready var foods_container: Node2D = $Foods

var correct_group: String = "Go"
var enemies_to_spawn: int = 0
var _enemy_spawn_count: int = 0
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

# === Landscape play-field layout (GameData.DESIGN_SIZE) ===
# HUD and belt use the growing visible world rect; characters use its background
# grass landmark so the authored landscape art remains the ground reference.
const HERO_RIGHT_INSET := 105.0   # hero ground-contact point inset from the right edge
const SPAWN_LEFT_INSET := 90.0     # monster ground-contact point inset from the left edge
const BOSS_LEFT_INSET := 120.0     # boss enters further in
const HUD_SAFE_TOP := 170.0
const PLAY_BOTTOM_INSET := 18.0    # feet remain above the belt; belt begins below grass
const HERO_SPRITE_SCALE := 1.1     # a small proportional increase from the previous size
const CHARACTER_LANE_RAISE := 22.0 # move hero feet slightly above the grass landmark
const MONSTER_LANE_RAISE := 12.0 # monsters sit a little higher than the hero
const HERO_COLLISION_SIZE := Vector2(55.0, 72.0)
const HERO_COLLISION_OFFSET := Vector2(0.0, -36.0)
const BACKGROUND_ART_SIZE := Vector2(1536.0, 1024.0)
const GRASS_SOURCE_Y := 710.0
const BOSS_COLOR := Color(0.42, 0.24, 0.52)   # neutral purple: the boss wants every group

# Lesson phases pause at prompts and unpause only while a real food action is needed.
var _tutorial_page: int = 0
var _tutorial_overlay_active: bool = false
var _tutorial_enemy: Node2D
var _tutorial_score_before: int = 0
var _grass_ground_y_cache: float = 0.0
var _background_rendered_size: Vector2 = Vector2.ZERO
var _background_cover_scale: float = 1.0
var _tutorial_enemies_before: int = 0
var _tutorial_enemy_speed_before: float = BASE_ENEMY_SPEED
var _tutorial_lives_before: int = 0
var _punch_playing: bool = false

const SPAWN_INTERVAL := 2.2
const POINTS_PER_ENEMY := 10
const BASE_ENEMY_SPEED := 70.0  # tuned for the 956px-wide landscape play field

# Set from the chosen difficulty in _start_level.
var _enemy_speed: float = BASE_ENEMY_SPEED
var _score_mult: int = 1

func _ready() -> void:
	# Clicking/dragging Area2D foods needs physics picking on the root viewport.
	get_viewport().physics_object_picking = true
	# Refit world, grass alignment, and background coverage after a resize.
	_layout_world()
	get_viewport().size_changed.connect(_layout_world)
	spawn_timer.wait_time = SPAWN_INTERVAL
	spawn_timer.timeout.connect(_spawn_enemy)
	fx = FxManagerScript.new()
	fx.name = "Fx"
	add_child(fx)
	fx.setup(hero, cam)
	hero_sprite.animation_finished.connect(_on_hero_animation_finished)
	belt = BeltManagerScript.new()
	belt.name = "Belt"
	add_child(belt)
	belt.setup(food_scene, foods_container, _needed_groups)
	lesson_root.visible = false
	$LessonPopup/Root.mouse_filter = Control.MOUSE_FILTER_STOP
	Audio.play_music("music")
	_start_level()

# Put a centered lesson over the live Level 1 scene, then freeze all gameplay behind it.
func _begin_tutorial_overlay() -> void:
	# Save campaign state while the player reads the intro explanations.
	_tutorial_score_before = GameData.score
	_tutorial_enemies_before = enemies_to_spawn
	_tutorial_enemy_speed_before = _enemy_speed
	_tutorial_lives_before = GameData.lives
	GameData.tutorial_mode = true
	spawn_timer.stop()
	belt.stop()
	belt.clear_foods()
	enemies_to_spawn = 0
	_tutorial_overlay_active = true
	_tutorial_page = 0
	for old_enemy: Node in get_tree().get_nodes_in_group("enemies"):
		old_enemy.remove_from_group("enemies")
		old_enemy.queue_free()
	_tutorial_enemy = null
	$LessonPopup.process_mode = Node.PROCESS_MODE_ALWAYS
	lesson_root.process_mode = Node.PROCESS_MODE_ALWAYS
	$LessonPopup/Root/Dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_set_tutorial_step(TutorialWords.BELT_TITLE, TutorialWords.BELT_DESCRIPTION)
	tutorial_focus.text = "▼ FOOD BELT"
	tutorial_focus.position = Vector2(GameData.design_center().x - 470.0, GameData.belt_y() - 155.0)
	tutorial_focus.visible = true
	lesson_root.visible = true
	$LessonPopup/Root/Panel/ContinueButton.text = "Next: Monster"
	$LessonPopup/Root/Panel/ContinueButton.visible = true
	get_tree().paused = true

func _set_tutorial_step(title: String, message: String) -> void:
	lesson_title.text = title
	lesson_label.text = message
	lesson_root.visible = true

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
		_enemy_spawn_count = 0
		enemies_to_spawn = int(lvl["enemies"]) + int(diff["enemy_bonus"])
		hint_label.text = "Drag a %s food onto the Hero!" % correct_group
		_set_hint_color(Color(0.12, 0.12, 0.12))
		spawn_timer.start()
		_spawn_enemy()   # first enemy right away
	# Start the belt AFTER the branch above so the seeded foods match the
	# actual first wave/level group (not level data a boss level ignores).
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
	_enemy_spawn_count = 0
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
func _spawn_one_tutorial_enemy() -> void:
	if enemy_scene == null:
		return
	var enemy: Node2D = enemy_scene.instantiate() as Node2D
	add_child(enemy)
	enemy.add_to_group("enemies")
	enemy.set("speed", _enemy_speed)
	enemy.global_position = _spawn_pos()
	enemy.set("lane_y", enemy.global_position.y)

func _begin_interactive_tutorial() -> void:
	# The second popup points to a real, protected monster while gameplay is paused.
	GameData.tutorial_mode = true
	game_active = true
	enemies_to_spawn = 0
	correct_group = "Go"
	_enemy_speed = BASE_ENEMY_SPEED * GameData.TUTORIAL_SPEED_MULT
	_tutorial_page = 1
	_tutorial_enemy = enemy_scene.instantiate() as Node2D
	add_child(_tutorial_enemy)
	_tutorial_enemy.add_to_group("enemies")
	_tutorial_enemy.set("speed", _enemy_speed)
	_tutorial_enemy.global_position = _spawn_pos()
	_tutorial_enemy.set("lane_y", _tutorial_enemy.global_position.y)
	tutorial_focus.text = "▼ HUNGER MONSTER"
	tutorial_focus.position = get_viewport().get_canvas_transform() * _tutorial_enemy.global_position + Vector2(20.0, 35.0)
	tutorial_focus.visible = true
	_set_tutorial_step(TutorialWords.ENEMY_TITLE, TutorialWords.ENEMY_DESCRIPTION)
	$LessonPopup/Root/Panel/ContinueButton.text = "Start Practice"
	$LessonPopup/Root/Panel/ContinueButton.visible = true
	get_tree().paused = true

func _tutorial_start_food_belt_after_demo() -> void:
	# Run the same belt for the guided food practice after the intro popups.
	belt.start()
	_set_tutorial_step(TutorialWords.BELT_TITLE, TutorialWords.BELT_DESCRIPTION)
	$LessonPopup/Root/Panel/ContinueButton.text = "Try Food"
	$LessonPopup/Root/Panel/ContinueButton.visible = false
	var attempts: int = 0
	while _tutorial_overlay_active and _tutorial_page == 2 and not belt.has_group(correct_group) and attempts < 20:
		await get_tree().create_timer(0.1).timeout
		attempts += 1
	if not _tutorial_overlay_active or _tutorial_page != 2:
		return
	for food: Node in foods_container.get_children():
		if food.get("food_group") == correct_group:
			food.modulate = Color(1.0, 1.0, 0.45, 1.0)

func _spawn_enemy() -> void:
	if not game_active or enemies_to_spawn <= 0 or enemy_scene == null:
		return
	enemies_to_spawn -= 1
	# Level 1 keeps its original monster. From level 2 onward, alternate between
	# the original and Enemy2 so both types are guaranteed in each batch/wave.
	var selected_scene: PackedScene = enemy_scene
	if GameData.current_level >= 2 and enemy2_scene != null and _enemy_spawn_count % 2 == 1:
		selected_scene = enemy2_scene
	_enemy_spawn_count += 1
	var enemy: Node2D = selected_scene.instantiate() as Node2D
	add_child(enemy)
	enemy.add_to_group("enemies")
	enemy.set("speed", _enemy_speed)
	enemy.global_position = _spawn_pos()
	enemy.set("lane_y", enemy.global_position.y)

# === HERO ANIMATION ===
func _on_hero_animation_finished() -> void:
	if hero_sprite.animation == &"punch":
		hero_sprite.play("idle")
		hero_sprite.flip_h = true
		_punch_playing = false

func _play_correct_action_punch() -> void:
	if _punch_playing:
		return
	_punch_playing = true
	# Face left throughout the punch; idle uses the same left-facing direction.
	hero_sprite.flip_h = true
	hero_sprite.play("punch")
	hero_sprite.frame = 0

# === The teaching moment: right vs. wrong food (the IF/ELSE) ===
# Called by Food.gd when a food is dropped on the hero. Returns true if the
# food was used (so the belt food should be consumed), false to keep it riding.
func food_dropped_on_hero(food) -> bool:
	if not game_active:
		return false
	if GameData.tutorial_mode:
		if _tutorial_overlay_active and _tutorial_page in [2, 3, 4, 5, 6, 7, 8, 9]:
			return _tutorial_food_dropped(food)
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
	# Resolve a live target first so a correct food with no monster cannot trigger
	# an attack animation. The food is still accepted and feedback stays positive.
	var fed_name: String = food.label.text
	var result: Dictionary = defeat_closest_enemy()
	if result["hit"]:
		_play_correct_action_punch()
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

# Each drag returns true only when the existing food scene should consume it.
# Incorrect choices and lesson checks stay non-punitive; the final correct feed
# calls the existing defeat, points, attack, and nutrient systems exactly once.
func _tutorial_food_dropped(food) -> bool:
	if food == null or not is_instance_valid(food):
		return false
	if _tutorial_page == 2:
		# Belt introduction ends; the next popup demonstrates matching food.
		_tutorial_page = 3
		_set_tutorial_step("MATCH THE FOOD", "Drag the highlighted matching food onto your Hero to defeat the monster.")
		$LessonPopup/Root/Panel/ContinueButton.text = "Try Matching Food"
		$LessonPopup/Root/Panel/ContinueButton.visible = true
		get_tree().paused = true
		return false
	if _tutorial_page == 4:
		_tutorial_page = 5
		_set_tutorial_step(TutorialWords.WRONG_FOOD_TITLE, TutorialWords.WRONG_FOOD_DESCRIPTION)
		$LessonPopup/Root/Panel/ContinueButton.text = "Try Wrong Food"
		$LessonPopup/Root/Panel/ContinueButton.visible = true
		get_tree().paused = true
		return false
	if _tutorial_page == 6:
		if food.food_group == correct_group:
			return false
		_tutorial_page = 7
		_set_tutorial_step(TutorialWords.ENEMY_TITLE, TutorialWords.ENEMY_DESCRIPTION)
		$LessonPopup/Root/Panel/ContinueButton.text = "Start Practice"
		$LessonPopup/Root/Panel/ContinueButton.visible = true
		get_tree().paused = true
		return false
	if _tutorial_page == 8:
		if food.food_group != correct_group:
			return false
		var consumed: bool = _feed_tutorial_enemy(food)
		if consumed:
			_tutorial_page = 9
			tutorial_focus.visible = false
			_tutorial_enemy = null
			_set_tutorial_step(TutorialWords.FEED_SUCCESS_TITLE, TutorialWords.FEED_SUCCESS_DESCRIPTION)
			$LessonPopup/Root/Panel/ContinueButton.text = "Continue"
			$LessonPopup/Root/Panel/ContinueButton.visible = true
			get_tree().paused = true
		return consumed
	return false

func _feed_tutorial_enemy(food) -> bool:
	if get_tree().get_nodes_in_group("enemies").is_empty():
		_spawn_one_tutorial_enemy()
	var result: Dictionary = defeat_closest_enemy()
	if not result["hit"]:
		return false
	_play_correct_action_punch()
	GameData.score += POINTS_PER_ENEMY
	fx.play_attack(correct_group, result["pos"])
	fx.nutrient_popup(GameData.food_nutrient(food.label.text), GameData.group_color(correct_group))
	_update_hud()
	return true

func _tutorial_continue_lesson() -> void:
	if _tutorial_page == 9:
		_tutorial_page = 10
		_set_tutorial_step(TutorialWords.FEED_SUCCESS_TITLE, TutorialWords.FEED_SUCCESS_DESCRIPTION)
	elif _tutorial_page == 10:
		_tutorial_page = 11
		_set_tutorial_step(TutorialWords.LIVES_TITLE, TutorialWords.LIVES_DESCRIPTION)
	elif _tutorial_page == 11:
		_tutorial_page = 12
		_set_tutorial_step(TutorialWords.BOSSES_TITLE, TutorialWords.BOSSES_DESCRIPTION)
	elif _tutorial_page == 12:
		_tutorial_page = 13
		_set_tutorial_step(TutorialWords.PAUSE_TITLE, TutorialWords.PAUSE_DESCRIPTION)
		$LessonPopup/Root/Panel/ContinueButton.text = "Finish Tutorial"
	$LessonPopup/Root/Panel/ContinueButton.visible = true
	get_tree().paused = true

func defeat_closest_enemy() -> Dictionary:
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	if GameData.tutorial_mode and enemies.is_empty():
		_spawn_one_tutorial_enemy()
		enemies = get_tree().get_nodes_in_group("enemies")
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
	if GameData.tutorial_mode:
		enemy.queue_free()
		_tutorial_enemy = null
		_tutorial_page = 10
		tutorial_focus.visible = false
		_set_tutorial_step(TutorialWords.LIVES_TITLE, TutorialWords.LIVES_DESCRIPTION)
		$LessonPopup/Root/Panel/ContinueButton.visible = true
		get_tree().paused = true
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
	if not game_active or GameData.tutorial_mode:
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
	boss.global_position = _boss_spawn_pos()
	boss.set("lane_y", boss.global_position.y)
	var walking_sprite: AnimatedSprite2D = boss.get_node_or_null("SpaghettiSprite")
	if walking_sprite != null:
		walking_sprite.visible = false
	var rect = boss.get_node_or_null("ColorRect")
	if rect != null:
		rect.visible = true
		rect.color = BOSS_COLOR
	var lbl = boss.get_node_or_null("Label")
	if lbl != null:
		lbl.visible = true
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
	# Boss attacks only animate when feeding advances its active meal.
	_play_correct_action_punch()
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
	if rect != null and rect.visible:
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
		b.global_position = _boss_spawn_pos()
		b.reached = false
		b.speed = _enemy_speed * 0.5
		var boss_sprite: AnimatedSprite2D = b.get_node_or_null("SpaghettiSprite") as AnimatedSprite2D
		if boss_sprite != null:
			boss_sprite.play("walk")
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

# Completion resumes this exact Level 1 run; it does not restart or award progress.
func _finish_tutorial_overlay() -> void:
	spawn_timer.stop()
	belt.stop()
	belt.clear_foods()
	game_active = true
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		enemy.remove_from_group("enemies")
		enemy.queue_free()
	GameData.tutorial_mode = false
	GameData.tutorial_completed = true
	GameData.tutorial_entry_pending = false
	DB.set_setting_int("tutorial_done", 1)
	lesson_root.visible = false
	tutorial_focus.visible = false
	_tutorial_overlay_active = false
	$LessonPopup/Root/Dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lesson_root.process_mode = Node.PROCESS_MODE_INHERIT
	$LessonPopup.process_mode = Node.PROCESS_MODE_INHERIT
	get_tree().paused = false
	_tutorial_page = 0
	if is_instance_valid(_tutorial_enemy):
		_tutorial_enemy.queue_free()
	_tutorial_enemy = null
	GameData.score = _tutorial_score_before
	GameData.lives = _tutorial_lives_before
	_update_hud()
	_start_normal_level_after_tutorial()

func _start_normal_level_after_tutorial() -> void:
	# Restore the untouched Level 1 batch and let regular gameplay begin.
	game_active = true
	GameData.tutorial_mode = false
	_boss_level = false
	correct_group = String(GameData.current_level_data()["correct_group"])
	_enemy_speed = _tutorial_enemy_speed_before
	_score_mult = int(GameData.difficulty_data()["score_mult"])
	enemies_to_spawn = _tutorial_enemies_before
	spawn_timer.wait_time = SPAWN_INTERVAL * float(GameData.difficulty_data()["spawn_mult"])
	hint_label.text = "Drag a %s food onto the Hero!" % correct_group
	_set_hint_color(Color(0.12, 0.12, 0.12))
	spawn_timer.start()
	_spawn_enemy()
	belt.start()
	_update_hud()

func _on_continue_pressed() -> void:
	Audio.play("click")
	if not _tutorial_overlay_active:
		lesson_root.visible = false
		GameData.record_result(true)
		get_tree().change_scene_to_file("res://scenes/ResultScreen.tscn")
		return
	match _tutorial_page:
		0:
			_tutorial_page = 1
			_begin_interactive_tutorial()
		1:
			_tutorial_page = 2
			_set_tutorial_step(TutorialWords.BELT_TITLE, TutorialWords.BELT_DESCRIPTION)
			$LessonPopup/Root/Panel/ContinueButton.visible = false
			get_tree().paused = false
			_tutorial_start_food_belt_after_demo()
		2:
			_tutorial_page = 3
			_set_tutorial_step("MATCH THE FOOD", "Drag the highlighted yellow GO food from the belt onto your Hero to defeat the monster.")
			$LessonPopup/Root/Panel/ContinueButton.text = "Continue"
			$LessonPopup/Root/Panel/ContinueButton.visible = true
			get_tree().paused = true
		3:
			_tutorial_page = 4
			_set_tutorial_step("MATCH THE FOOD", "Drag the highlighted yellow GO food from the belt onto your Hero to defeat the monster.")
			$LessonPopup/Root/Panel/ContinueButton.text = "Continue"
			$LessonPopup/Root/Panel/ContinueButton.visible = true
		4:
			_tutorial_page = 5
			$LessonPopup/Root/Panel/ContinueButton.visible = false
			get_tree().paused = false
		5:
			_tutorial_page = 6
			_set_tutorial_step(TutorialWords.WRONG_FOOD_TITLE, TutorialWords.WRONG_FOOD_DESCRIPTION)
			$LessonPopup/Root/Panel/ContinueButton.text = "Try Wrong Food"
			$LessonPopup/Root/Panel/ContinueButton.visible = true
		6:
			_tutorial_page = 7
			$LessonPopup/Root/Panel/ContinueButton.visible = false
			get_tree().paused = false
		7:
			_tutorial_page = 8
			_set_tutorial_step(TutorialWords.ENEMY_TITLE, TutorialWords.ENEMY_DESCRIPTION)
			$LessonPopup/Root/Panel/ContinueButton.text = "Start Practice"
			$LessonPopup/Root/Panel/ContinueButton.visible = true
			get_tree().paused = true
		8:
			_tutorial_page = 9
			$LessonPopup/Root/Panel/ContinueButton.visible = false
			get_tree().paused = false
		9:
			_tutorial_page = 10
			_tutorial_continue_lesson()
		10, 11, 12:
			_tutorial_continue_lesson()
		13:
			_tutorial_page = 14
			_set_tutorial_step(TutorialWords.COMPLETE_TITLE, TutorialWords.COMPLETE_DESCRIPTION)
			$LessonPopup/Root/Panel/ContinueButton.text = "Start Level 1"
		14:
			_finish_tutorial_overlay()

func _game_over() -> void:
	if GameData.tutorial_mode:
		# A practice run must never produce campaign failure/progression records.
		GameData.score = _tutorial_score_before
		GameData.lives = _tutorial_lives_before
		for enemy: Node in get_tree().get_nodes_in_group("enemies"):
			enemy.queue_free()
		_tutorial_enemy = null
		_tutorial_page = 10
		tutorial_focus.visible = false
		_set_tutorial_step(TutorialWords.LIVES_TITLE, TutorialWords.LIVES_DESCRIPTION)
		$LessonPopup/Root/Panel/ContinueButton.visible = true
		get_tree().paused = true
		_update_hud()
		return
	_stop_level()
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

# === Adaptive landscape play-field layout ===
# The camera sits on the design centre; ground placement follows the centered
# cover-scaled courtyard art, and UI/belt use the expanding visible world rect.
func _layout_world() -> void:
	cam.position = GameData.design_center()
	var view: Rect2 = GameData.view_world_rect()
	# Reflow existing belt food centers along with a resized viewport.
	if belt != null:
		belt._layout()
	_update_background_rect()
	# Scale artwork first, then calculate root placement from its visible foot pixels.
	hero_sprite.scale = Vector2.ONE * HERO_SPRITE_SCALE
	var hero_ground_y: float = _ground_y_for_sprite(hero_sprite, view) - CHARACTER_LANE_RAISE
	# Keep visible feet slightly above the authored grass landmark.
	hero.position = Vector2(_hero_x(), hero_ground_y)
	hero.z_index = 1
	# Scale the hit area with the hero artwork while it remains centered on root.
	var hero_shape: RectangleShape2D = $Hero/CollisionShape2D.shape.duplicate() as RectangleShape2D
	hero_shape.size = HERO_COLLISION_SIZE
	$Hero/CollisionShape2D.shape = hero_shape
	$Hero/CollisionShape2D.position = HERO_COLLISION_OFFSET
	if fx != null:
		fx.setup(hero, cam)

# The grass landmark uses the same centered cover scaling as Background.
func _update_background_rect() -> void:
	var view: Rect2 = GameData.view_world_rect()
	var size: Vector2 = background_rect.texture.get_size()
	var cover_scale: float = maxf(view.size.x / size.x, view.size.y / size.y)
	_background_cover_scale = cover_scale
	_background_rendered_size = size * cover_scale
	# The full art fills the whole play view; the belt draws over its lower edge.
	background_rect.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	background_rect.position = view.position
	background_rect.size = view.size
	background_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	background_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# Covering crop is centered horizontally/vertically; the belt overlays bottom.
	_grass_ground_y_cache = _grass_ground_y(view)

func _grass_ground_y(view: Rect2) -> float:
	var background_size: Vector2 = BACKGROUND_ART_SIZE
	var cover_scale: float = maxf(view.size.x / background_size.x, view.size.y / background_size.y)
	_background_cover_scale = cover_scale
	_background_rendered_size = background_size * cover_scale
	var crop_top: float = (_background_rendered_size.y - view.size.y) * 0.5
	_grass_ground_y_cache = view.position.y + GRASS_SOURCE_Y * cover_scale - crop_top
	return _grass_ground_y_cache

func _hero_x() -> float:
	return GameData.view_world_rect().end.x - HERO_RIGHT_INSET

# Character roots are aligned to actual transparent-alpha foot pixels instead of
# their sprite's transparent canvas centre. Collision shapes remain attached to
# the same root, below the gameplay artwork and above the conveyor lane.
func _ground_y_for_sprite(sprite: AnimatedSprite2D, view: Rect2) -> float:
	var frame_texture: Texture2D = sprite.sprite_frames.get_frame_texture(sprite.animation, 0)
	var frame_image: Image = frame_texture.get_image()
	var alpha_bottom: int = frame_image.get_height() - 1
	for y in range(frame_image.get_height() - 1, -1, -1):
		var row_has_pixel: bool = false
		for x in range(frame_image.get_width()):
			if frame_image.get_pixel(x, y).a > 0.1:
				row_has_pixel = true
				break
		if row_has_pixel:
			alpha_bottom = y
			break
	var bottom_from_root: float = (float(alpha_bottom) - frame_image.get_height() * 0.5) * sprite.scale.y + sprite.position.y
	return _grass_ground_y(view) - bottom_from_root

# Monsters enter on the left while their visible feet share the grass line.
func _spawn_pos() -> Vector2:
	var view: Rect2 = GameData.view_world_rect()
	var spawn_x: float = view.position.x + SPAWN_LEFT_INSET
	# Enemies use the same ground lane as the hero so their feet share one horizon.
	return Vector2(spawn_x, hero.global_position.y - MONSTER_LANE_RAISE)

func _boss_spawn_pos() -> Vector2:
	return Vector2(GameData.view_world_rect().position.x + BOSS_LEFT_INSET, hero.position.y - MONSTER_LANE_RAISE)
