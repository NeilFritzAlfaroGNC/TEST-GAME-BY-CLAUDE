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
##  - PauseMenu.gd calls `can_pause()` and iterates `foods_container`.
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

# Boss looks: it reuses Enemy.tscn, scaled up, slowed down and tinted a neutral
# purple because it wants every group rather than one.
const BOSS_SPEED_MULT := 0.5
const BOSS_SCALE := Vector2(2.2, 2.2)
const BOSS_COLOR := Color(0.42, 0.24, 0.52)

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

# PauseMenu's single source of truth for whether Esc/Pause should be allowed
# to open the overlay right now. game_active alone is not enough: it is set
# true before the tutorial's intro pages are shown (see _start_level), so a
# raw game_active check would let the pause overlay layer on top of the
# lesson popup mid-intro. _tutorial_intro_active excludes exactly that window.
func can_pause() -> bool:
	return game_active and not _tutorial_intro_active

var _diff: Dictionary = {}
var _enemy_speed: float = BASE_ENEMY_SPEED
# _stunned_until is compared against _stun_clock, NOT the wall clock: _stun_clock
# only advances in _process(), which the engine skips while get_tree().paused is
# true (Game's process_mode is the default PAUSABLE). Using Time.get_ticks_msec()
# here would let a stun tick down (or even finish) while the game is paused,
# quietly forgiving a wrong-answer penalty the player never waited out.
var _stunned_until: float = 0.0
var _stun_clock: float = 0.0

# Boss state. `boss` is the live boss Enemy instance (untyped, like every other
# cross-node reference here); _meal_needed holds the balanced-meal groups still
# missing, and doubles as the belt's guarantee list while _boss_active.
var _boss_active: bool = false
var _meal_needed: Array = []
var boss = null

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

# Advances the pause-immune stun clock. Nothing else needs a per-frame update,
# which is why the whole node went this long without a _process() at all.
func _process(delta: float) -> void:
	_stun_clock += delta

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
	_stunned_until = 0.0   # a restart (retry, tutorial retry, game-over) must not inherit a stun
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
	_clear_boss()   # a restart mid-boss must not leave the old boss on screen
	belt.clear_foods()
	game_active = true
	if GameData.tutorial_mode:
		# Guided first run: the TUTORIAL_PAGES intro shows one page at a time through
		# the lesson popup (_tutorial_intro_active reroutes _on_continue_pressed);
		# monsters and the belt only start once the last page closes, in
		# _advance_tutorial_intro(). WaveDirector is bypassed here -- there is no
		# wave/boss structure to run, same as the retired Main.gd's tutorial branch --
		# but enemies_to_spawn stays a director field so _spawn_enemy/_despawn keep
		# going through the normal track/untrack path (and on_enemy_removed's
		# level_cleared signal fires the same way once the wave is cleared).
		_enemy_speed = BASE_ENEMY_SPEED * GameData.TUTORIAL_SPEED_MULT
		spawn_timer.wait_time = SPAWN_INTERVAL * GameData.TUTORIAL_SPAWN_MULT
		director.boss_level = false
		director.wave = 1
		director.total_waves = 1
		director.enemies_to_spawn = GameData.TUTORIAL_ENEMIES
		hud.say("Drag GO (yellow) foods onto the Hero!", true)
		_refresh_hud()
		_show_tutorial_page(0)
		return
	director.start(level, _diff)   # emits wave_started -> _on_wave_started
	# Start the belt AFTER the first wave so its seeded foods already match the
	# weaknesses of the monsters that just spawned.
	belt.start()
	_refresh_hud()

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
	# The tutorial's single teaching wave must have every monster want the SAME
	# group, so a first-time player meets one idea at a time instead of three.
	var group: String = "Go" if GameData.tutorial_mode else GameData.random_group()
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
			# Deliberately good=true. HudController has exactly two colours and red
			# is this HUD's "you got it wrong" signal — the entire point of this
			# branch is that the child did NOT get anything wrong, so red would say
			# the opposite of what just happened. Green reads as "you're fine", and
			# the wording carries the neutrality the two-colour palette cannot:
			# no points, no praise, just "not yet".
			hud.say("No monster to feed yet — wait for the next one!", true)
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
	return _stun_clock < _stunned_until

# A wrong answer has to cost something, or guessing is free.
func _punish(group: String, food_name: String) -> void:
	score_keeper.wrong(group)
	DB.record_answer(GameData.current_difficulty, group, false)
	_stunned_until = _stun_clock + STUN_TIME
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

# === Boss fight: build a BALANCED MEAL ===
# WaveDirector says WHEN to unleash the boss (boss_ready, once the last wave is
# clear) but has no signal for the boss being BEATEN, so the win path is wired
# here: _feed_boss -> _boss_defeated -> _level_complete.
#
# The boss reuses Enemy.tscn — bigger, slower, and in the "boss" group so it is
# never mistaken for a one-hit monster and never enters the director's
# track/untrack bookkeeping. You beat it by building a balanced meal: one food
# from each group in GameData.BOSS_MEAL_GROUPS. A still-needed group lands a
# hit; a duplicate is rejected.
func _on_boss_ready() -> void:
	if not game_active:
		return
	_spawn_boss()

func _spawn_boss() -> void:
	# THE ORDER OF THESE TWO LINES IS LOAD-BEARING. _needed_groups() starts
	# returning _meal_needed the instant _boss_active is true, and
	# BeltManager._ensure_needed() calls it EVERY FRAME. Arming the flag first
	# would leave the belt guaranteeing an empty list for at least one frame, and
	# the fight could open with nothing feedable on the conveyor. Fill the meal
	# FIRST, then arm the flag.
	_meal_needed = GameData.BOSS_MEAL_GROUPS.duplicate()
	_boss_active = true
	spawn_timer.stop()
	boss = enemy_scene.instantiate()
	add_child(boss)   # before setup(): it refreshes the @onready Label
	boss.global_position = _boss_spawn_pos()
	# The group handed to setup() is inert — while _boss_active every group is a
	# valid answer and food_dropped_on_hero routes to _feed_boss — but setup() is
	# also what injects the speed, the walk target and the reached-hero callback,
	# so the boss is built through the same door as any other monster.
	boss.setup(GameData.BOSS_MEAL_GROUPS[0], "group",
		_enemy_speed * BOSS_SPEED_MULT, Layout.m["hero_x"], _boss_reached_hero)
	boss.add_to_group("boss")
	boss.scale = BOSS_SCALE
	var rect = boss.get_node_or_null("ColorRect")
	if rect != null:
		rect.color = BOSS_COLOR
	var lbl = boss.get_node_or_null("Label")
	if lbl != null:
		lbl.text = "BOSS"
	Audio.play("slam")
	fx.shake(9.0, 0.4)
	hud.say("BOSS! Build a balanced meal — feed one Go, one Grow, and one Glow food!", false)
	_refresh_hud()

# A food was fed while the boss is up. Every still-needed group lands a hit; a
# group already on the plate does nothing (the meal needs one of EACH, not
# duplicates). Returns true if the food was consumed, false to glide it back.
func _feed_boss(food) -> bool:
	# _clear_boss always drops the instance and the flag together, so a missing
	# boss here is a broken invariant: keep the food on the belt rather than run
	# meal logic with nothing to feed.
	if not is_instance_valid(boss):
		return false
	var g: String = food.food_group
	if not _meal_needed.has(g):
		# Deliberately NOT _punish(). The group was read correctly — it is just
		# already on the plate — so stunning the hero (or writing a wrong answer
		# into the accuracy table) would charge the child for a bookkeeping slip
		# instead of a knowledge gap.
		hud.say("Already added a %s food! The meal still needs: %s." % [g, _meal_left_text()], false)
		Audio.play("wrong")
		return false
	_meal_needed.erase(g)
	# Points and streak as usual, but NOTHING goes to DB.record_answer here.
	# While the boss is up ANY group is a correct answer, so a feed is not a
	# classification decision and does not belong in the per-group accuracy
	# table — that table is the educational telemetry, and only the per-monster
	# weakness game actually tests the knowledge it claims to measure.
	var points: int = score_keeper.correct(g)
	GameData.score = score_keeper.score
	fx.play_attack(g, boss.global_position)
	fx.nutrient_popup(GameData.food_nutrient(food.label.text), GameData.group_color(g))
	if _meal_needed.is_empty():
		hud.say("Balanced meal complete! BOSS DEFEATED!  +%d" % points, true)
		_boss_defeated()
		return true
	# Boss survived — flash it white; the belt keeps offering what is still missing.
	_flash_boss()
	hud.say("Added a %s food! Still need: %s.  +%d" % [g, _meal_left_text(), points], true)
	_refresh_hud()
	return true

# Called from _feed_boss once _meal_needed empties. This is the boss equivalent
# of WaveDirector.level_cleared, which the director structurally cannot emit.
func _boss_defeated() -> void:
	_boss_active = false
	_meal_needed = []
	_clear_boss()
	_refresh_hud()
	_level_complete()

# Injected into the boss through setup(): the boss reaching the Hero costs a
# life and is then knocked back, so the fight carries on instead of ending.
func _boss_reached_hero(b) -> void:
	if not game_active or not _boss_active or not is_instance_valid(b):
		return
	GameData.lives -= 1
	hud.say("The BOSS struck the Hero!", false)
	Audio.play("wrong")
	fx.shake(9.0, 0.3)
	if GameData.lives <= 0:
		_boss_active = false
		_meal_needed = []
		_clear_boss()
		_refresh_hud()
		_game_over()
		return
	# Enemy latches itself "spent" on arrival so the callback fires once per
	# charge; re-arming that latch is exactly what a knockback is.
	b.knock_back_to(_boss_spawn_pos())
	_refresh_hud()

func _clear_boss() -> void:
	if is_instance_valid(boss):
		boss.remove_from_group("boss")
		boss.queue_free()
	boss = null

# Where the boss enters (and returns to after a knockback): the monster spawn
# line, centred in the lane band. Read from Layout so it follows a resize.
func _boss_spawn_pos() -> Vector2:
	var m: Dictionary = Layout.m
	return Vector2(m["spawn_x"], (float(m["lane_top"]) + float(m["lane_bottom"])) * 0.5)

func _flash_boss() -> void:
	var rect = boss.get_node_or_null("ColorRect")
	if rect == null:
		return
	var base: Color = rect.color
	rect.color = Color(1, 1, 1)
	var tw := create_tween()
	tw.tween_property(rect, "color", base, 0.25)

# Comma-joined list of the meal groups still missing (HUD + hint text).
func _meal_left_text() -> String:
	return ", ".join(PackedStringArray(_meal_needed))

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
	# Idempotent: the win path already cleared it, but a loss during the fight
	# must not leave the boss standing over the lesson popup.
	_clear_boss()

func _level_complete() -> void:
	_stop_level()
	Audio.play("correct")
	if GameData.tutorial_mode:
		lesson_title.text = "Tutorial Complete!"
		lesson_label.text = "You're ready, Hero! Remember: GO gives energy, GLOW protects you, GROW builds your body — eat from all three groups every day. Now pick a level and save the day!"
	elif GameData.is_boss_level(GameData.current_level):
		lesson_title.text = "Balanced Meal Complete!"
		lesson_label.text = GameData.BOSS_LESSON
	else:
		lesson_title.text = "Level %d Complete!" % GameData.current_level
		lesson_label.text = String(GameData.current_level_data()["lesson"])
	lesson_root.visible = true

func _on_continue_pressed() -> void:
	Audio.play("click")
	if _tutorial_intro_active:
		_advance_tutorial_intro()
		return
	lesson_root.visible = false
	if GameData.tutorial_mode:
		# Tutorial cleared: remember it, then hand over to the real game. Nothing
		# is recorded -- the tutorial doesn't count as level 1.
		DB.set_setting_int("tutorial_done", 1)
		GameData.tutorial_mode = false
		get_tree().change_scene_to_file("res://scenes/LevelSelect.tscn")
		return
	GameData.record_result(true)
	get_tree().change_scene_to_file("res://scenes/ResultScreen.tscn")

func _game_over() -> void:
	_stop_level()
	if GameData.tutorial_mode:
		# The tutorial can't be failed out of -- just run it again.
		GameData.start_tutorial()
		get_tree().change_scene_to_file("res://scenes/Game.tscn")
		return
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
		"meal_left": _meal_left_text(),
	})
