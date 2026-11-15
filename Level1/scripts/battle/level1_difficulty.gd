class_name Level1Difficulty
extends Node

@export_group("Difficulty Profiles")
@export var easy: Level1DifficultyProfile
@export var normal: Level1DifficultyProfile
@export var hard: Level1DifficultyProfile

@export_group("Testing")
@export_enum("Saved difficulty", "Easy", "Normal", "Hard") var test_difficulty := 0
@export var log_spawn_details := false

var _monsters: Array[Level1MonsterSpawnConfig] = []
var _remaining: Array[int] = []
var _ready_at: Array[float] = []


func get_profile_difficulty(saved: String) -> String:
	if OS.is_debug_build() and test_difficulty > 0:
		return ["easy", "normal", "hard"][test_difficulty - 1]
	return saved


func prepare(difficulty: String) -> int:
	var profile: Level1DifficultyProfile = {"easy": easy, "normal": normal, "hard": hard}.get(difficulty)
	_monsters.clear()
	_remaining.clear()
	_ready_at.clear()
	var total := 0
	if profile == null:
		return total
	for config in profile.monsters:
		if config == null or not config.enabled or config.monster_count <= 0:
			continue
		if config.monster_scene == null:
			push_warning("[Level 1] Enabled monster in %s has no scene assigned." % difficulty.capitalize())
			continue
		_monsters.append(config)
		_remaining.append(config.monster_count)
		_ready_at.append(config.initial_spawn_delay)
		total += config.monster_count
	if log_spawn_details:
		print("[Level 1] %s profile: %d enabled entries, %d monsters." % [difficulty.capitalize(), _monsters.size(), total])
		for config in _monsters:
			print("[Level 1] Configured %s × %d." % [config.monster_scene.resource_path, config.monster_count])
	return total


func next_spawn(elapsed: float) -> int:
	var next := -1
	for i in range(_monsters.size()):
		if _remaining[i] > 0 and _ready_at[i] <= elapsed:
			if next == -1 or _ready_at[i] < _ready_at[next]:
				next = i
	return next


func get_monster(index: int) -> Level1MonsterSpawnConfig:
	return _monsters[index]


func register_spawn(index: int, elapsed: float) -> void:
	var config := _monsters[index]
	_remaining[index] -= 1
	_ready_at[index] = elapsed + maxf(config.spawn_interval, 0.1) + randf() * maxf(config.spawn_interval_variation, 0.0)
	if log_spawn_details:
		print("[Level 1] Spawned %s. Remaining for this entry: %d." % [config.monster_scene.resource_path, _remaining[index]])
