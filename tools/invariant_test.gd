extends Node
## Headless driver for the half of the SOLVABILITY INVARIANT that lives in
## Game.gd. Run with:
##   & "C:\SHIZ\Godot_v4.6.3-stable_win64.exe" --headless --path "D:\TEST" res://tools/invariant_test.tscn --quit-after 900
## (or via tools/test.ps1, which gates on the "INVARIANT: ALL PASS" line and the
## exit code.)
##
## WHY THIS EXISTS
## tools/smoke_test.gd unit-tests WaveDirector.track / untrack / needed_groups.
## Nothing asserted that Game.gd actually CALLS them in pairs — so deleting
## `director.untrack(group)` from _despawn(), or `director.track(group)` from
## _spawn_enemy(), passed the whole suite clean while quietly making levels
## unwinnable: BeltManager._ensure_needed() would either guarantee food for dead
## monsters forever, or stop guaranteeing it for a live one and leave a child
## facing a monster they cannot feed. That is the worst failure mode in the
## design, so it gets a test that fails loudly.
##
## It drives the REAL scenes/Game.tscn through its real spawn and despawn paths
## and compares, as a multiset, the weaknesses WaveDirector believes are alive
## against the weaknesses of the monsters actually in the "enemies" group.
##
## DB SAFETY: FILE-LEVEL isolation. This driver runs as an ordinary scene, so
## all four autoloads boot first and DB._open() has already connected to the real
## save (user://foodheroes.db) by the time _ready() here runs. Before any phase
## executes, _isolate_db() closes that connection and reopens DB against the
## throwaway TEST_DB, so EVERY write this run causes — the punish probe included
## — lands in a disposable file that _finish() deletes. A decoy key inside the
## live save is not good enough: a --quit-after kill, which CLAUDE.md documents
## as a real occurrence here, would strand a row in a player's save, and even a
## correctly deleted row leaves its bytes in the file's free pages.
##
## The real save is still OPENED at boot by the DB autoload itself — that happens
## in every headless run of every scene, including smoke_test.gd's, and is not
## something a test scene can prevent. What this guarantees is that no WRITE from
## this driver ever reaches it.

const GameScene := preload("res://scenes/Game.tscn")

# Throwaway save, mirroring tools/smoke_test.gd's user://smoke_test.db.
const TEST_DB := "user://invariant_test.db"

var _game: Node = null
var _fails: int = 0
var _frame: int = 0

func _ready() -> void:
	_isolate_db()
	# Easy level 1 = 4 monsters. The driver never spawns all of them, so
	# enemies_to_spawn stays > 0 and the level can never complete underneath it.
	GameData.start_level("Easy", 1)
	_game = GameScene.instantiate()
	add_child(_game)   # Game._ready -> _start_level -> first wave -> one monster

# === Database isolation ===

func _isolate_db() -> void:
	_remove_test_db()   # a previously killed run may have left one behind
	if DB._db != null:
		DB._db.close_db()
	DB._db = null
	DB.db_file = TEST_DB
	DB._open()
	_check(DB.db_file == TEST_DB and DB._db != null, "isolation: DB reopened against the throwaway file")
	# The real save has accuracy rows in it; a fresh throwaway cannot. If this
	# ever passes on the real file, that assertion is what catches it.
	_check(DB.get_accuracy("Easy").is_empty(), "isolation: the throwaway save starts empty, so this is NOT foodheroes.db")

func _teardown_db() -> void:
	if DB._db != null:
		DB._db.close_db()
		DB._db = null
	_remove_test_db()
	_check(not FileAccess.file_exists(TEST_DB), "cleanup: the throwaway save is removed")

func _remove_test_db() -> void:
	var gpath := ProjectSettings.globalize_path(TEST_DB)
	if FileAccess.file_exists(gpath):
		DirAccess.remove_absolute(gpath)

func _process(_d: float) -> void:
	_frame += 1
	match _frame:
		1: _phase_boot()
		2: _phase_second_spawn()
		4: _phase_belt_covers_needs()
		5: _phase_kill_one()
		6: _phase_kill_last()
		7: _phase_no_monster_is_not_a_wrong_answer()
		8: _phase_punish_is_recorded()
		9: _phase_stunned_drop_is_refused()
		10: _phase_restart_resets_cleanly()
		11: _finish()

# === Phases ===

func _phase_boot() -> void:
	_check(_game.game_active, "boot: the level is running")
	_check(_live().size() == 1, "boot: the first wave spawned exactly one monster")
	_pairing("boot")

func _phase_second_spawn() -> void:
	_game._spawn_enemy()
	_check(_live().size() == 2, "spawn: a second monster joined the enemies group")
	_pairing("after a second spawn")

func _phase_belt_covers_needs() -> void:
	# The belt has had frames to run _ensure_needed at least once.
	var needed: Array = _game.director.needed_groups()
	_check(not needed.is_empty(), "belt: live monsters report at least one needed group")
	var on_belt: Array = _belt_groups()
	for g in needed:
		_check(on_belt.has(g), "belt: a %s food is present for the monster that needs it" % g)
	_pairing("while the belt is refilling")

func _phase_kill_one() -> void:
	var before: int = _live().size()
	_game._despawn(_live()[0])
	_check(_live().size() == before - 1, "despawn: the monster left the enemies group the same frame")
	_pairing("after one despawn")

func _phase_kill_last() -> void:
	_game._despawn(_live()[0])
	_check(_live().is_empty(), "despawn: no monsters remain")
	# THE ASSERTION THAT DISCRIMINATES. Without director.untrack in _despawn,
	# needed_groups() still names the dead monsters' groups here.
	_check(_game.director.needed_groups().is_empty(),
		"despawn: nothing is needed once nothing is alive (needed=%s)" % str(_game.director.needed_groups()))
	_pairing("after every monster is gone")
	_check(_game.game_active, "the level is still running (monsters left to spawn)")

# Item 1 of the round-1 fixes: a food dropped with NO monster on screen is a
# timing artifact, not a misclassification. It must not stun and must not reach
# the per-group accuracy table — the educational telemetry the rebuild exists to
# produce. Streak survival is the DB-free proxy for ScoreKeeper.wrong() (and so
# DB.record_answer) not having been called.
func _phase_no_monster_is_not_a_wrong_answer() -> void:
	_check(_live().is_empty(), "gate: the no-monster case is actually set up")
	_game.score_keeper.streak = 3
	var food = _make_food("Go")
	var consumed: bool = _game.food_dropped_on_hero(food)
	_check(not consumed, "gate: the food is not consumed, so it glides back")
	_check(_game.score_keeper.streak == 3, "gate: the streak survives (no wrong answer recorded)")
	_check(not _game._is_stunned(), "gate: the hero is not stunned for a timing artifact")
	food.queue_free()

# The other half of Item 1: with a monster on screen, a food not one of them
# wants IS a misclassification — the child chose which food to pick up — so it
# must stun, reset the streak, and land in the accuracy table. The write goes to
# the isolated TEST_DB, so this exercises the real difficulty key on a real
# DB.record_answer call without any of it reaching the player's save.
func _phase_punish_is_recorded() -> void:
	_game._spawn_enemy()
	_check(_live().size() == 1, "punish: one monster is on screen to classify against")
	var wants: String = _live()[0].weakness
	var other: String = ""
	for g in ["Go", "Glow", "Grow"]:
		if g != wants:
			other = g
			break
	_game.score_keeper.streak = 3
	var food = _make_food(other)
	var consumed: bool = _game.food_dropped_on_hero(food)
	food.queue_free()
	_check(not consumed, "punish: a %s food no live monster wants is rejected" % other)
	_check(_game.score_keeper.streak == 0, "punish: the streak resets")
	_check(_game._is_stunned(), "punish: the hero is stunned")
	var acc: Dictionary = DB.get_accuracy(GameData.current_difficulty)
	_check(acc.has(other) and int(acc[other]["wrong"]) == 1,
		"punish: exactly one wrong answer reached the isolated accuracy table for %s (acc=%s)" % [other, str(acc)])

# The stun has to bite, and it must bite the CORRECT food too — that is what
# makes a wrong answer cost something rather than being a free retry.
func _phase_stunned_drop_is_refused() -> void:
	_check(_game._is_stunned(), "stun: still stunned on the following frame")
	var wants: String = _live()[0].weakness
	var food = _make_food(wants)
	var consumed: bool = _game.food_dropped_on_hero(food)
	food.queue_free()
	_check(not consumed, "stun: even the correct %s food is refused while stunned" % wants)
	_check(_live().size() == 1, "stun: the monster it would have killed is still alive")
	_check(_game.score_keeper.streak == 0, "stun: a refused drop scores nothing")

# The one free-without-untrack in Game.gd is the leftover sweep in _start_level,
# which is safe only because director.start() resets the tracked list wholesale.
# Prove that, rather than leaving a future reader to take it on trust.
func _phase_restart_resets_cleanly() -> void:
	_game._start_level()
	_check(_live().size() == 1, "restart: the sweep ran and a fresh wave spawned one monster")
	_pairing("after _start_level swept and restarted")

func _finish() -> void:
	_teardown_db()
	if _fails == 0:
		print("INVARIANT: ALL PASS")
		get_tree().quit(0)
	else:
		printerr("INVARIANT: %d FAILURE(S)" % _fails)
		get_tree().quit(1)

# === Helpers ===

# The core check: WaveDirector's live weakness list must equal, as a MULTISET,
# the weaknesses of the monsters actually on screen. A multiset (not a set)
# because two monsters can share a weakness and each needs its own track entry —
# a set comparison would miss a half-dropped pair.
#
# _alive_weaknesses is private on purpose and this is the one place the raw
# count matters. If it is ever renamed, this read raises "Invalid access", which
# tools/test.ps1 already treats as a failure — so the test breaks loudly rather
# than silently passing.
func _pairing(what: String) -> void:
	var live: Array = []
	for e in _live():
		live.append(e.weakness)
	var tracked: Array = (_game.director._alive_weaknesses as Array).duplicate()
	live.sort()
	tracked.sort()
	_check(tracked.size() == live.size(),
		"%s: director tracks %d weakness(es) for %d live monster(s)" % [what, tracked.size(), live.size()])
	_check(tracked == live,
		"%s: tracked weaknesses match the live monsters exactly (tracked=%s live=%s)" % [what, str(tracked), str(live)])

func _live() -> Array:
	return get_tree().get_nodes_in_group("enemies")

func _belt_groups() -> Array:
	var out: Array = []
	for f in _game.foods_container.get_children():
		if is_instance_valid(f) and not f.is_queued_for_deletion():
			out.append(f.food_group)
	return out

# A real Food node of a chosen group. It has to enter the tree for Food's
# @onready label to resolve before set_food writes to it.
func _make_food(group: String):
	var f = _game.food_scene.instantiate()
	_game.foods_container.add_child(f)
	f.set_food(group, true)
	return f

func _check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   - ", what)
	else:
		_fails += 1
		printerr("  FAIL - ", what)
