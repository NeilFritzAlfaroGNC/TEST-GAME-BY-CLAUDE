extends Node2D
## Plays exactly one level. A thin orchestrator: it builds the components,
## wires them together, and owns the cross-script contract — nothing else.
## Scoring lives in ScoreKeeper, HUD text in HudController, what-spawns-when in
## WaveDirector, the conveyor in BeltManager, and every effect in FxManager.
##
## CONTRACT (do not break):
##  - Food.gd reaches this script through get_tree().current_scene and calls
##    food_dropped_on_hero(food) with an UNTYPED param (typing it would make the
##    static checker reject food.food_group / food.label); it finds the hero at
##    get_node("Hero"), so the Hero must stay a direct child named exactly that.
##  - PauseMenu.gd reads `game_active` and iterates `foods_container`.
##
## TYPE NOTE: none of the component scripts declares `class_name`, so they are
## preloaded as consts and held in UNTYPED vars. Annotating them
## (`var director: WaveDirector`) makes GDScript's static checker reject the
## file, and adding `class_name` would register project-wide global symbols.

const WaveDirectorScript := preload("res://scripts/WaveDirector.gd")
const ScoreKeeperScript := preload("res://scripts/ScoreKeeper.gd")
const HudControllerScript := preload("res://scripts/HudController.gd")
const BeltManagerScript := preload("res://scripts/BeltManager.gd")
const FxManagerScript := preload("res://scripts/FxManager.gd")

const STUN_TIME := 1.0         # seconds the hero cannot feed after a wrong answer
const SPAWN_INTERVAL := 2.2    # base seconds between monsters (scaled by difficulty)
const BASE_ENEMY_SPEED := 70.0

@export var enemy_scene: PackedScene
@export var food_scene: PackedScene

@onready var hero: Area2D = $Hero
@onready var cam: Camera2D = $Camera2D
@onready var spawn_timer: Timer = $Timer
@onready var foods_container: Node2D = $Foods
@onready var lesson_root: Control = $LessonPopup/Root
@onready var lesson_title: Label = $LessonPopup/Root/Panel/LessonTitle
@onready var lesson_label: Label = $LessonPopup/Root/Panel/LessonLabel

# The five code-created components (untyped, called dynamically — see TYPE NOTE).
var director = null
var score_keeper = null
var hud = null
var belt = null
var fx = null

var game_active: bool = false

var _diff: Dictionary = {}
var _enemy_speed: float = BASE_ENEMY_SPEED
var _stunned_until: float = 0.0

# Boss state. Task 12 builds only the HOOK; Task 13 ports the real fight.
var _boss_active: bool = false
var _meal_needed: Array = []

func _ready() -> void:
	# Clicking/dragging Area2D foods needs physics picking on the root viewport.
	get_viewport().physics_object_picking = true
	Layout.changed.connect(_reanchor)
	_reanchor()

	score_keeper = ScoreKeeperScript.new()
	score_keeper.name = "Score"
	add_child(score_keeper)

	hud = HudControllerScript.new()
	hud.name = "Hud"
	add_child(hud)
	hud.bind({
		"score": $HUD/ScoreLabel,
		"lives": $HUD/LivesLabel,
		"highscore": $HUD/HighScoreLabel,
		"level": $HUD/LevelLabel,
		"target": $HUD/TargetLabel,
		"hint": $HUD/HintLabel,
	})

	director = WaveDirectorScript.new()
	director.name = "Director"
	add_child(director)
	# Connect BEFORE director.start() — it emits wave_started synchronously.
	director.wave_started.connect(_on_wave_started)
	director.level_cleared.connect(_on_level_cleared)
	director.boss_ready.connect(_on_boss_ready)

	fx = FxManagerScript.new()
	fx.name = "Fx"
	add_child(fx)
	fx.setup(hero, cam)

	belt = BeltManagerScript.new()
	belt.name = "Belt"
	add_child(belt)
	# === SOLVABILITY INVARIANT ===
	# BeltManager._ensure_needed() calls this Callable every frame and spawns,
	# cap-free, a food for every group it names. It resolves to
	# WaveDirector.needed_groups() — the distinct weaknesses of the monsters
	# currently alive — so a food the player needs can never be missing.
	# _spawn_enemy/director.track and _despawn/director.untrack are what keep
	# that list honest, and they must ALWAYS pair.
	belt.setup(food_scene, foods_container, _needed_groups)

	spawn_timer.timeout.connect(_spawn_enemy)
	lesson_root.visible = false
	Audio.play_music("music")
	_start_level()

# === Layout ===
# Layout.changed (a resize or device rotation): re-place everything positioned
# once. Belt foods and monster lanes re-derive from Layout every frame, and the
# belt graphic re-anchors itself (BeltManager listens to the same signal).
func _reanchor() -> void:
	var m: Dictionary = Layout.m
	var h: Node2D = get_node_or_null("Hero")
	if h != null:
		h.position = Vector2(m["hero_x"], m["hero_y"])
	var c: Camera2D = get_node_or_null("Camera2D")
	if c != null:
		# stretch aspect "expand" reveals surplus width, so the camera has to
		# re-centre or the right-anchored food stack slides off screen.
		c.position = m["view"] * 0.5
	if fx != null:
		# Refresh FxManager's cached hero home, or the slam lunge re-anchors to
		# the pre-resize spot.
		fx.setup(hero, cam)

# === Level setup ===
func _start_level() -> void:
	# WaveDirector.start() uses its `level` argument for is_boss_level but reads
	# GameData.current_level itself for the wave sizes — pass exactly that value
	# so the two can never disagree.
	var level: int = GameData.current_level
	_diff = GameData.difficulty_data()
	_enemy_speed = BASE_ENEMY_SPEED * float(_diff["speed_mult"])
	spawn_timer.wait_time = SPAWN_INTERVAL * float(_diff["spawn_mult"])
	score_keeper.reset()
	score_keeper.score_mult = int(_diff["score_mult"])
	GameData.score = score_keeper.score
	_boss_active = false
	_meal_needed = []
	# Clear anything left over from a previous level in this scene instance. This
	# is the ONE free-without-untrack in the file, and it is safe only because
	# director.start() three lines below resets _alive_weaknesses to [] wholesale
	# — untracking each enemy here would be redundant work on a list about to be
	# thrown away. Anywhere else, a free MUST go through _despawn() so track() and
	# untrack() stay paired. (Today this loop is also a no-op: _start_level runs
	# once, from _ready, on a freshly instantiated scene.)
	for e in get_tree().get_nodes_in_group("enemies"):
		e.remove_from_group("enemies")
		e.queue_free()
	belt.clear_foods()
	game_active = true
	director.start(level, _diff)   # emits wave_started -> _on_wave_started
	# Start the belt AFTER the first wave so its seeded foods already match the
	# weaknesses of the monsters that just spawned.
	belt.start()
	_refresh_hud()

func _on_wave_started(n: int, total: int) -> void:
	if not game_active:
		return
	if total > 1:
		hud.say("Wave %d of %d — feed each monster what it asks for!" % [n, total], true)
	else:
		hud.say("Drag the food each monster asks for onto the Hero!", true)
	spawn_timer.start()
	_spawn_enemy()   # first monster right away
	_refresh_hud()

# === Enemy spawning ===
func _spawn_enemy() -> void:
	if not game_active or _boss_active or enemy_scene == null:
		return
	if director.enemies_to_spawn <= 0:
		return
	director.enemies_to_spawn -= 1
	var m: Dictionary = Layout.m
	var group: String = GameData.random_group()
	var mode: String = director.pick_label_mode(String(_diff.get("monster_label", "group")))
	var enemy = enemy_scene.instantiate()
	add_child(enemy)   # before setup(): it refreshes the @onready Label
	enemy.global_position = Vector2(m["spawn_x"], randf_range(m["lane_top"], m["lane_bottom"]))
	enemy.setup(group, mode, _enemy_speed, m["hero_x"], _on_enemy_reached)
	enemy.add_to_group("enemies")
	director.track(group)   # pairs with untrack() in _despawn

# === The teaching moment: per-monster weakness (the IF/ELSE) ===
# Called by Food.gd when a food is dropped on the hero. Returns true if the food
# was consumed (remove it), false to glide it back to its belt slot.
func food_dropped_on_hero(food) -> bool:
	if not game_active:
		return false
	if _is_stunned():
		# Say so. Without this the previous "Not what they asked for!" is the only
		# thing on screen, so a correct food being ignored looks like a bug.
		hud.say("The Hero is still dazed — wait a moment, then try again!", false)
		return false
	var group: String = food.food_group
	if _boss_active:
		return _feed_boss(food)
	var target = _closest_matching(group)
	if target == null:
		# Nothing on screen to classify against — between waves, or the wave's last
		# monster just died. That is a TIMING artifact, not a misclassification, so
		# it must never stun and must never reach the per-group accuracy table: that
		# table is the educational telemetry the whole game exists to produce, and a
		# non-knowledge failure written into it makes it lie about what the child
		# knows. The live "enemies" group is the test — never needed_groups(), so
		# the two can never drift.
		if get_tree().get_nodes_in_group("enemies").is_empty():
			hud.say("Wait for a monster!", true)
			return false
		# Monsters ARE out there and not one of them wants this group. The child
		# chose which food to pick up, so this is a genuine classification error:
		# stun, reset the streak, record the miss.
		_punish(group, food.label.text)
		return false
	var points: int = score_keeper.correct(group)
	DB.record_answer(GameData.current_difficulty, group, true)
	GameData.score = score_keeper.score
	hud.say("Correct! %s is a %s food.  +%d" % [food.label.text, group, points], true)
	fx.play_attack(group, target.global_position)
	fx.nutrient_popup(GameData.food_nutrient(food.label.text), GameData.group_color(group))
	_despawn(target)
	_refresh_hud()
	return true

func _is_stunned() -> bool:
	return Time.get_ticks_msec() / 1000.0 < _stunned_until

# A wrong answer has to cost something, or guessing is free.
func _punish(group: String, food_name: String) -> void:
	score_keeper.wrong(group)
	DB.record_answer(GameData.current_difficulty, group, false)
	_stunned_until = Time.get_ticks_msec() / 1000.0 + STUN_TIME
	hud.say("Not what they asked for! %s is a %s food." % [food_name, group], false)
	Audio.play("wrong")
	fx.shake(4.0, 0.2)

# The monster nearest the hero whose weakness is this food's group.
func _closest_matching(group: String):
	var best = null
	var best_d := INF
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.weakness != group:
			continue
		var d: float = absf(e.global_position.x - Layout.m["hero_x"])
		if d < best_d:
			best_d = d
			best = e
	return best

# === Enemy removal ===
# Ordering is load-bearing: the enemy must leave the "enemies" group BEFORE
# queue_free so the group count is right in this same frame, untrack() must pair
# with the track() done at spawn, and the completion check runs deferred so the
# caller finishes before a wave transition.
func _despawn(enemy) -> void:
	if not is_instance_valid(enemy):
		return
	var group: String = enemy.weakness
	enemy.remove_from_group("enemies")
	enemy.queue_free()
	director.untrack(group)
	director.on_enemy_removed.call_deferred()

# Injected into every Enemy via setup(); called when one reaches the hero.
func _on_enemy_reached(enemy) -> void:
	if not game_active or not is_instance_valid(enemy):
		return
	if not enemy.is_in_group("enemies"):
		return
	GameData.lives -= 1
	hud.say("Oh no! A Hunger Monster got through!", false)
	Audio.play("wrong")
	fx.shake(6.0, 0.25)
	_refresh_hud()
	_despawn(enemy)
	if GameData.lives <= 0:
		_game_over()

func _on_level_cleared() -> void:
	# Deferred, so a game over may already have ended the run.
	if not game_active:
		return
	_level_complete()

# === Boss hook ===
# WaveDirector says WHEN to unleash the boss but has no signal for the boss being
# BEATEN, so the win path is wired here: _feed_boss -> _boss_defeated ->
# _level_complete.
#
# !!! STUB !!! _spawn_boss and _feed_boss below are placeholders. Task 13 ports
# the real balanced-meal fight (_spawn_boss / _feed_boss / _boss_reached_hero)
# from the old Main.gd. Until then the hook is exercised end to end but the fight
# is skipped, so a boss level finishes instead of hanging on an empty screen.
func _on_boss_ready() -> void:
	if not game_active:
		return
	_spawn_boss()

func _spawn_boss() -> void:
	push_warning("Game._spawn_boss is a STUB (Task 12); Task 13 ports the real boss fight.")
	spawn_timer.stop()
	_boss_active = false
	_meal_needed = []
	_boss_defeated()

# Task 13's _feed_boss calls this once _meal_needed empties. This is the boss
# equivalent of WaveDirector.level_cleared, which the director cannot emit.
func _boss_defeated() -> void:
	_boss_active = false
	_meal_needed = []
	_refresh_hud()
	_level_complete()

# STUB — replaced in Task 13 by the real balanced-meal logic. Unreachable while
# _boss_active is never set true.
func _feed_boss(_food) -> bool:
	return false

# === Belt contract ===
# The groups the belt must keep available. Normally the live monsters' distinct
# weaknesses; during the boss, the meal groups still missing (Task 13 fills
# _meal_needed). Returns a COPY so callers never alias live state.
func _needed_groups() -> Array:
	if _boss_active:
		return _meal_needed.duplicate()
	return director.needed_groups()

# === End of level ===
# Shared shutdown — win and lose take the same path: freeze the loop, empty belt.
func _stop_level() -> void:
	game_active = false
	spawn_timer.stop()
	belt.stop()
	belt.clear_foods()

func _level_complete() -> void:
	_stop_level()
	Audio.play("correct")
	if GameData.is_boss_level(GameData.current_level):
		lesson_title.text = "Balanced Meal Complete!"
		lesson_label.text = GameData.BOSS_LESSON
	else:
		lesson_title.text = "Level %d Complete!" % GameData.current_level
		lesson_label.text = String(GameData.current_level_data()["lesson"])
	lesson_root.visible = true

func _on_continue_pressed() -> void:
	Audio.play("click")
	lesson_root.visible = false
	GameData.record_result(true)
	get_tree().change_scene_to_file("res://scenes/ResultScreen.tscn")

func _game_over() -> void:
	_stop_level()
	GameData.record_result(false)
	get_tree().change_scene_to_file("res://scenes/ResultScreen.tscn")

# === HUD ===
func _refresh_hud() -> void:
	var boss_level: bool = GameData.is_boss_level(GameData.current_level)
	hud.refresh({
		"level_name": "BOSS: Balanced Meal" if boss_level else String(GameData.current_level_data()["name"]),
		"boss_active": _boss_active,
		"wave": director.wave,
		"total_waves": director.total_waves,
		"meal_left": ", ".join(PackedStringArray(_meal_needed)),
	})
