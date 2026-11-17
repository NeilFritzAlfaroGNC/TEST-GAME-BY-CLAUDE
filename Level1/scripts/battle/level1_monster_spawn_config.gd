class_name Level1MonsterSpawnConfig
extends Resource

@export var enabled := true
@export var monster_scene: PackedScene
## Added to the monster scene's base speed. Use -1 or 0 for no bonus.
@export_range(-1.0, 500.0, 1.0, "or_greater", "suffix:px/s") var movement_speed := -1.0
@export_range(0, 100, 1, "or_greater") var monster_count := 1
@export_range(0.1, 60.0, 0.1, "or_greater", "suffix:s") var spawn_interval := 2.0
@export_range(0.0, 60.0, 0.1, "or_greater", "suffix:s") var spawn_interval_variation := 2.0
@export_range(0.0, 60.0, 0.1, "or_greater", "suffix:s") var initial_spawn_delay := 0.0
@export_range(1, 20, 1, "or_greater") var foods_required := 1
