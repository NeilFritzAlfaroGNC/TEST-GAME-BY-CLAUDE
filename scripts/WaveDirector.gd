extends Node
## The level / wave / boss state machine, lifted out of Main.gd.
## Owns what spawns and when; owns nothing about scoring, HUD or effects.

signal wave_started(n: int, total: int)
signal level_cleared()
signal boss_ready()

const NUTRIENT_SHARE := 0.5   # fraction of Hard-mode monsters that ask by nutrient

var enemies_to_spawn: int = 0
var boss_level: bool = false
var wave: int = 0
var total_waves: int = 0

var _alive_weaknesses: Array = []

# Hard asks for a nutrient only about half the time. Grow contributes a single
# unambiguous nutrient ("+Protein"), so an all-nutrient Hard mode would repeat
# it relentlessly -- see the spec, section 3.3.
func pick_label_mode(tier_mode: String) -> String:
	if tier_mode != "nutrient":
		return "group"
	return "nutrient" if randf() < NUTRIENT_SHARE else "group"

func start(level: int, diff: Dictionary) -> void:
	boss_level = GameData.is_boss_level(level)
	total_waves = GameData.BOSS_WAVES if boss_level else 1
	wave = 0
	_alive_weaknesses = []
	_next_wave(diff)

# Clears the same per-run bookkeeping start() resets, WITHOUT touching the
# wave/boss state machine (boss_level/wave/total_waves/enemies_to_spawn) --
# those are set directly by Game.gd's tutorial branch, which never calls
# start(). Call this unconditionally before any leftover-enemy sweep so a
# stale _alive_weaknesses list can never survive into a reused director
# (see Game.gd:_start_level for why that matters on the tutorial path).
func reset() -> void:
	_alive_weaknesses = []

func _next_wave(diff: Dictionary) -> void:
	wave += 1
	var row: Dictionary = GameData.level_data(GameData.current_level)
	var count: int = GameData.BOSS_WAVE_SIZE if boss_level else int(row["enemies"])
	enemies_to_spawn = count + int(diff.get("enemy_bonus", 0))
	wave_started.emit(wave, total_waves)

# The belt's solvability invariant reads this: a food for every weakness on
# screen must always exist, or the level becomes unwinnable.
func needed_groups() -> Array:
	var out: Array = []
	for g in _alive_weaknesses:
		if not out.has(g):
			out.append(g)
	return out

func track(group: String) -> void:
	_alive_weaknesses.append(group)

func untrack(group: String) -> void:
	var i := _alive_weaknesses.find(group)
	if i >= 0:
		_alive_weaknesses.remove_at(i)

func on_enemy_removed() -> void:
	if enemies_to_spawn > 0 or not _alive_weaknesses.is_empty():
		return
	if boss_level and wave < total_waves:
		_next_wave(GameData.difficulty_data())
	elif boss_level:
		boss_ready.emit()
	else:
		level_cleared.emit()
