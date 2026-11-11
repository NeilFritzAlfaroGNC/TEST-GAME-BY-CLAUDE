
extends Marker2D

signal level_completed

# ==================================================
# REUSABLE ENEMY SPAWNER
# ==================================================

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


# ==================================================
# INITIALIZATION
# ==================================================

func _ready() -> void:
	randomize()

	level_difficulty_setting = get_node_or_null(
		level_difficulty_setting_path
	) as LevelDifficultySetting

	if level_difficulty_setting == null:
		push_error(
			"[EnemySpawn] LevelDifficultySetting missing."
		)
		set_process(false)
		return

	current_settings = (
		level_difficulty_setting.get_current_settings()
	)

	if current_settings == null:
		push_error(
			"[EnemySpawn] Difficulty settings missing."
		)
		set_process(false)
		return

	min_spawn_time = maxf(
		current_settings.min_spawn_time,
		0.1
	)

	max_spawn_time = maxf(
		current_settings.max_spawn_time,
		min_spawn_time
	)

	max_enemy_count = maxi(
		current_settings.max_active_enemies,
		1
	)

	max_enemies_to_kill = maxi(
		current_settings.enemies_to_defeat,
		1
	)

	available_enemies = (
		current_settings.available_enemies.duplicate()
	)

	enemy_items = get_node_or_null(
		enemy_items_path
	) as Node2D

	if enemy_items == null:
		push_error(
			"[EnemySpawn] EnemyItem container missing."
		)
		set_process(false)
		return

	if _get_valid_enemy_scenes().is_empty():
		push_error(
			"[EnemySpawn] No enemy scenes configured."
		)
		set_process(false)
		return

	next_spawn_time = randf_range(
		min_spawn_time,
		max_spawn_time
	)

	print("[EnemySpawn] Ready.")
	print(
		"[EnemySpawn] Difficulty: ",
		ProgressManager.current_difficulty
	)
	print(
		"[EnemySpawn] Enemy types: ",
		_get_valid_enemy_scenes().size()
	)
	print(
		"[EnemySpawn] Enemies to defeat: ",
		max_enemies_to_kill
	)


# ==================================================
# SPAWN TIMER
# ==================================================

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

	next_spawn_time = randf_range(
		min_spawn_time,
		max_spawn_time
	)

	if _get_active_enemy_count() >= max_enemy_count:
		return

	spawn_enemy()


# ==================================================
# ENEMY SCENE SELECTION
# ==================================================

func _get_valid_enemy_scenes() -> Array[PackedScene]:
	var valid_scenes: Array[PackedScene] = []

	for scene in available_enemies:
		if scene != null:
			valid_scenes.append(scene)

	return valid_scenes


func _get_random_enemy_scene() -> PackedScene:
	var valid_scenes: Array[PackedScene] = (
		_get_valid_enemy_scenes()
	)

	if valid_scenes.is_empty():
		return null

	var index: int = randi_range(
		0,
		valid_scenes.size() - 1
	)

	return valid_scenes[index]


# ==================================================
# ACTIVE ENEMY COUNT
# ==================================================

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


# ==================================================
# SPAWN ENEMY
# ==================================================

func spawn_enemy() -> void:
	if is_level_completed:
		return

	if total_enemies_spawned >= max_enemies_to_kill:
		return

	if not is_instance_valid(enemy_items):
		push_error(
			"[EnemySpawn] Enemy container unavailable."
		)
		return

	if _get_active_enemy_count() >= max_enemy_count:
		return

	var scene_to_spawn: PackedScene = (
		_get_random_enemy_scene()
	)

	if scene_to_spawn == null:
		push_error(
			"[EnemySpawn] No valid enemy scene."
		)
		return

	var instance: Node = scene_to_spawn.instantiate()

	if not instance is CharacterBody2D:
		instance.free()
		push_error(
			"[EnemySpawn] Enemy root must be CharacterBody2D."
		)
		return

	var enemy: CharacterBody2D = (
		instance as CharacterBody2D
	)

	# Apply stats before entering the scene tree.
	_apply_enemy_overrides(
		enemy,
		scene_to_spawn
	)

	enemy_items.add_child(enemy)

	enemy.global_position = global_position

	if not enemy.is_in_group("enemy"):
		enemy.add_to_group("enemy")

	enemy.visible = true

	var enemy_health: EnemyHealth = (
		enemy.get_node_or_null("EnemyHealth") as EnemyHealth
	)

	if enemy_health == null:
		push_error(
			"[EnemySpawn] EnemyHealth missing in: "
			+ enemy.name
		)
	else:
		if not enemy_health.died.is_connected(
			_on_enemy_died
		):
			enemy_health.died.connect(
				_on_enemy_died
			)

	total_enemies_spawned += 1

	var sprite: AnimatedSprite2D = (
		enemy.get_node_or_null("AnimatedSprite2D")
		as AnimatedSprite2D
	)

	if sprite != null:
		sprite.visible = true

		if sprite.sprite_frames == null:
			push_warning(
				"[EnemySpawn] SpriteFrames missing: "
				+ enemy.name
			)

	print(
		"[EnemySpawn] Spawned: ",
		enemy.name,
		" | ",
		total_enemies_spawned,
		"/",
		max_enemies_to_kill
	)

	if total_enemies_spawned >= max_enemies_to_kill:
		set_process(false)
		print(
			"[EnemySpawn] All required enemies spawned."
		)


# ==================================================
# DIFFICULTY STAT OVERRIDES
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

		# HEALTH OVERRIDE
		if override.override_health:
			var enemy_health: EnemyHealth = (
				enemy.get_node_or_null("EnemyHealth")
				as EnemyHealth
			)

			if enemy_health != null:
				enemy_health.max_health = maxi(
					override.health,
					1
				)

				print(
					"[EnemySpawn] Health override: ",
					enemy.name,
					" = ",
					enemy_health.max_health
				)
			else:
				push_warning(
					"[EnemySpawn] Health component missing: "
					+ enemy.name
				)

		if override.override_move_speed:
			_apply_optional_override(enemy, "move_speed", clampf(override.move_speed, 0.0, 2000.0))
		if override.override_attack_interval:
			_apply_optional_override(enemy, "attack_interval", clampf(override.attack_interval, 0.05, 20.0))
		if override.override_first_attack_delay:
			_apply_optional_override(enemy, "first_attack_delay", clampf(override.first_attack_delay, 0.0, 10.0))

		if (
			override.override_attack
			or override.override_nutrition_damage_multiplier
			or override.override_nutrition_damage_category
		):
			var attack_component := _find_attack_component(enemy)
			if attack_component == null:
				push_warning("[EnemySpawn] Attack component missing: " + enemy.name)
				return

			if override.override_attack:
				var damage := maxi(override.attack, 1)
				attack_component.set("attack_damage", damage)
				print("[EnemySpawn] Attack override: ", enemy.name, " = ", damage)

			if override.override_nutrition_damage_multiplier:
				if _has_property(attack_component, "nutrition_damage_multiplier"):
					var multiplier := clampi(override.nutrition_damage_multiplier, 1, 100)
					attack_component.set("nutrition_damage_multiplier", multiplier)
					print("[EnemySpawn] Nutrition multiplier override: ", enemy.name, " = ", multiplier)
				else:
					push_warning("[EnemySpawn] Attack component has no nutrition damage multiplier: " + enemy.name)

			if override.override_nutrition_damage_category:
				var category := clampi(override.nutrition_damage_category, 0, NutritionSystem.FoodType.size() - 1)
				_apply_optional_override(attack_component, "nutrition_damage_category", category)

		return


func _apply_optional_override(target: Node, property_name: String, value: Variant) -> void:
	if not _has_property(target, property_name):
		push_warning("[EnemySpawn] Override property missing: " + property_name + " on " + target.name)
		return

	target.set(property_name, value)
	print("[EnemySpawn] ", property_name, " override: ", target.name, " = ", value)


# ==================================================
# FIND ATTACK COMPONENT
# ==================================================

func _find_attack_component(
	enemy: CharacterBody2D
) -> Node:
	# First use the Attack Node Path in enemy.gd.
	# This works before the enemy enters the tree.

	if _has_property(enemy, "attack_node_path"):
		var configured_path: Variant = enemy.get(
			"attack_node_path"
		)

		if configured_path is NodePath:
			var configured_node: Node = (
				enemy.get_node_or_null(configured_path)
			)

			if _is_valid_attack_component(configured_node):
				return configured_node

	# Fallback: inspect direct children.
	for child in enemy.get_children():
		if _is_valid_attack_component(child):
			return child

	return null


# ==================================================
# ATTACK VALIDATION
# ==================================================

func _is_valid_attack_component(
	component: Node
) -> bool:
	if not is_instance_valid(component):
		return false

	if not component.has_method("attack"):
		return false

	if not _has_property(
		component,
		"attack_damage"
	):
		return false

	return true


# ==================================================
# PROPERTY CHECK
# ==================================================

func _has_property(
	target: Object,
	property_name: String
) -> bool:
	if not is_instance_valid(target):
		return false

	for property in target.get_property_list():
		if String(property.name) == property_name:
			return true

	return false


# ==================================================
# DEFEAT TRACKING
# ==================================================

func _on_enemy_died() -> void:
	if is_level_completed:
		return

	defeated_enemy_count += 1

	print(
		"[EnemySpawn] Defeated: ",
		defeated_enemy_count,
		"/",
		max_enemies_to_kill
	)

	if defeated_enemy_count >= max_enemies_to_kill:
		_complete_level()


# ==================================================
# LEVEL COMPLETION
# ==================================================

func _complete_level() -> void:
	if is_level_completed:
		return

	is_level_completed = true

	set_process(false)

	print("[EnemySpawn] LEVEL COMPLETED!")

	level_completed.emit()
