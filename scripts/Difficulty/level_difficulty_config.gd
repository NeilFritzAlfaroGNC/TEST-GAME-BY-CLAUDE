
extends Resource
class_name LevelDifficultyConfig

@export_group("Enemy Objective")
@export_range(1, 100, 1) var enemies_to_defeat: int = 5

@export_group("Spawn Settings")
@export_range(1, 50, 1) var max_active_enemies: int = 2
@export_range(0.1, 60.0, 0.1) var min_spawn_time: float = 2.0
@export_range(0.1, 60.0, 0.1) var max_spawn_time: float = 5.0

@export_group("Enemy Configuration")
@export var available_enemies: Array[PackedScene] = []

@export_group("Enemy Stat Overrides")
@export var enemy_stat_overrides: Array[EnemyStatOverride] = []
