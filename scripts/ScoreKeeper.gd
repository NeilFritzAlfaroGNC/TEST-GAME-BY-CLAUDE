extends Node
## Score, streak multiplier and per-group accuracy for ONE run.
## Deliberately free of engine and DB dependencies so tools/smoke_test.gd can
## exercise it headlessly. The Game scene owns an instance and forwards the
## tally to DB.record_answer as it goes.

const BASE_POINTS := 10
const STREAK_STEP := 5      # every N consecutive correct answers raises the multiplier
const STREAK_CAP := 5

var score: int = 0
var streak: int = 0
var score_mult: int = 1     # set from the difficulty table

var _tally: Dictionary = {}  # group -> {"correct": int, "wrong": int}

func reset() -> void:
	score = 0
	streak = 0
	_tally = {}

func streak_mult() -> int:
	return mini(1 + streak / STREAK_STEP, STREAK_CAP)

func correct(group: String) -> int:
	_bump(group, "correct")
	streak += 1
	var points: int = BASE_POINTS * score_mult * streak_mult()
	score += points
	return points

func wrong(group: String) -> void:
	_bump(group, "wrong")
	streak = 0

func tally() -> Dictionary:
	return _tally.duplicate(true)

# 0-100. An unseen group reads 0 rather than dividing by zero.
func percent(group: String) -> int:
	var row: Dictionary = _tally.get(group, {})
	var c: int = int(row.get("correct", 0))
	var w: int = int(row.get("wrong", 0))
	if c + w == 0:
		return 0
	return int(round(100.0 * float(c) / float(c + w)))

func _bump(group: String, key: String) -> void:
	if not _tally.has(group):
		_tally[group] = {"correct": 0, "wrong": 0}
	_tally[group][key] = int(_tally[group][key]) + 1
