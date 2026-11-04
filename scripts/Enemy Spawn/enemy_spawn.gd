
extends Marker2D

signal level_completed

@export_group("Scene References")
@export var level_difficulty_setting_path: NodePath = ^"../LevelDifficultySetting"
@export var enemy_items_path: NodePath = ^"../EnemyItem"

var level_difficulty_setting: LevelDifficultySetting = null
var enemy_items: Node2D = null
var current_settings: LevelDifficultyConfig = null

var min_spawn_time: float = 1.0
var max_spawn_time: float = 5.0
var max_enemy_count: int = 5
var max_enemies_to_kill: int = 5

var available_enemies: Array[PackedScene] = []

var spawn_timer: float = 0.0
var next_spawn_time: float = 1.0

var total_enemies_spawned: int = 0
var defeated_enemy_count: int = 0
var is_level_completed: bool = false


func _ready() -> void:
	randomize()

	level_difficulty_setting = get_node_or_null(
		level_difficulty_setting_path
	) as LevelDifficultySetting

	if level_difficulty_setting == null:
		push_error("[EnemySpawn] LevelDifficultySetting was not found.")
		set_process(false)
		return

	current_settings = level_difficulty_setting.get_current_settings()

	if current_settings == null:
		push_error("[EnemySpawn] No settings found for current difficulty.")
		set_process(false)
		return

	min_spawn_time = maxf(current_settings.min_spawn_time, 0.1)
	max_spawn_time = maxf(current_settings.max_spawn_time, min_spawn_time)
	max_enemy_count = maxi(current_settings.max_active_enemies, 1)
	max_enemies_to_kill = maxi(current_settings.enemies_to_defeat, 1)

	available_enemies = current_settings.available_enemies.duplicate()

	enemy_items = get_node_or_null(enemy_items_path) as Node2D

	if enemy_items == null:
		push_error("[EnemySpawn] EnemyItem was not found. Check Enemy Items Path.")
		set_process(false)
		return

	if _get_valid_enemy_scenes().is_empty():
		push_error("[EnemySpawn] No valid enemy scenes assigned.")
		set_process(false)
		return

	next_spawn_time = randf_range(min_spawn_time, max_spawn_time)

	print("[EnemySpawn] Ready. EnemyItem found.")
	print("[EnemySpawn] Difficulty: ", ProgressManager.current_difficulty)
	print("[EnemySpawn] Available enemy types: ", _get_valid_enemy_scenes().size())
	print("[EnemySpawn] Objective: Defeat ", max_enemies_to_kill, " enemies.")
	print("[EnemySpawn] Maximum active enemies: ", max_enemy_count)
	print("[EnemySpawn] Spawn interval: ", min_spawn_time, " - ", max_spawn_time)


func _process(delta: float) -> void:
	if is_level_completed:
		return

	if total_enemies_spawned >= max_enemies_to_kill:
		set_process(false)
		return

	spawn_timer += delta

	if spawn_timer < next_spawn_time:
		return

	spawn_timer = 0.0
	next_spawn_time = randf_range(min_spawn_time, max_spawn_time)

	if _get_active_enemy_count() >= max_enemy_count:
		return

	spawn_enemy()


func _get_valid_enemy_scenes() -> Array[PackedScene]:
	var valid_scenes: Array[PackedScene] = []

	for scene in available_enemies:
		if scene != null:
			valid_scenes.append(scene)

	return valid_scenes


func _get_random_enemy_scene() -> PackedScene:
	var valid_scenes := _get_valid_enemy_scenes()

	if valid_scenes.is_empty():
		return null

	var random_index := randi_range(0, valid_scenes.size() - 1)

	return valid_scenes[random_index]


func _get_active_enemy_count() -> int:
	if not is_instance_valid(enemy_items):
		return 0

	var count: int = 0

	for child in enemy_items.get_children():
		if not is_instance_valid(child):
			continue

		if child.is_in_group("enemy"):
			count += 1

	return count


func spawn_enemy() -> void:
	if is_level_completed:
		return

	if total_enemies_spawned >= max_enemies_to_kill:
		set_process(false)
		return

	if not is_instance_valid(enemy_items):
		push_error("[EnemySpawn] Cannot spawn: EnemyItem is missing.")
		return

	if _get_active_enemy_count() >= max_enemy_count:
		return

	var scene_to_spawn := _get_random_enemy_scene()

	if scene_to_spawn == null:
		push_error("[EnemySpawn] No valid enemy scene available.")
		return

	var instance: Node = scene_to_spawn.instantiate()

	if not instance is CharacterBody2D:
		instance.free()
		push_error("[EnemySpawn] Enemy scene root must inherit CharacterBody2D.")
		return

	var enemy := instance as CharacterBody2D

	# Apply difficulty overrides before entering the scene tree.
	_apply_enemy_overrides(enemy, scene_to_spawn)

	# Add the enemy only after its stats have been configured.
	enemy_items.add_child(enemy)
	enemy.global_position = global_position

	if not enemy.is_in_group("enemy"):
		enemy.add_to_group("enemy")

	enemy.visible = true

	var enemy_health := enemy.get_node_or_null("EnemyHealth") as EnemyHealth

	if enemy_health == null:
		push_error("[EnemySpawn] EnemyHealth node missing in: " + enemy.name)
	else:
		if not enemy_health.died.is_connected(_on_enemy_died):
			enemy_health.died.connect(_on_enemy_died)

	total_enemies_spawned += 1

	var sprite := enemy.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D

	if sprite == null:
		push_warning("[EnemySpawn] Enemy has no direct AnimatedSprite2D child: " + enemy.name)
	else:
		sprite.visible = true

		if sprite.sprite_frames == null:
			push_warning("[EnemySpawn] Enemy SpriteFrames resource is missing: " + enemy.name)

	print(
		"[EnemySpawn] Spawned: ", enemy.name,
		" | Total spawned: ", total_enemies_spawned,
		"/", max_enemies_to_kill,
		" | Active enemies: ", _get_active_enemy_count()
	)

	if total_enemies_spawned >= max_enemies_to_kill:
		set_process(false)
		print("[EnemySpawn] All required enemies have spawned.")


# ==================================================
# ENEMY STAT OVERRIDES
# ==================================================

func _apply_enemy_overrides(
	enemy: CharacterBody2D,
	enemy_scene: PackedScene
) -> void:
	if current_settings == null:
		return

	for override in current_settings.enemy_stat_overrides:
		if override == null:
			continue

		if override.enemy_scene == null:
			continue

		if override.enemy_scene.resource_path != enemy_scene.resource_path:
			continue

		var enemy_health := enemy.get_node_or_null("EnemyHealth") as EnemyHealth

		if enemy_health == null:
			push_warning("[EnemySpawn] Cannot apply health override. EnemyHealth is missing.")
		elif override.override_health:
			enemy_health.max_health = maxi(override.health, 1)
			print("[EnemySpawn] Health override applied: ", enemy_health.max_health)

		var claw_attack := enemy.get_node_or_null("ClawAnimation") as ClawAttack

		if claw_attack == null:
			push_warning("[EnemySpawn] Cannot apply attack override. ClawAnimation is missing.")
		elif override.override_attack:
			claw_attack.attack_damage = maxi(override.attack, 1)
			print("[EnemySpawn] Attack override applied: ", claw_attack.attack_damage)

		return


# ==================================================
# ENEMY DEFEAT AND LEVEL COMPLETION
# ==================================================

func _on_enemy_died() -> void:
	if is_level_completed:
		return

	defeated_enemy_count += 1

	print(
		"[EnemySpawn] Enemies defeated: ",
		defeated_enemy_count,
		"/",
		max_enemies_to_kill
	)

	if defeated_enemy_count >= max_enemies_to_kill:
		_complete_level()


func _complete_level() -> void:
	if is_level_completed:
		return

	is_level_completed = true
	set_process(false)

	print("[EnemySpawn] LEVEL COMPLETED!")

	level_completed.emit()
