extends Node2D
class_name EnemySpawner

@export var enemy_scene: PackedScene = preload("res://scene/enemy1.tscn")
@export var spawn_duration: float = 10.0
@export var min_spawn_interval: float = 1.0
@export var max_spawn_interval: float = 5.0
@export var spawn_position: Vector2 = Vector2.ZERO
@export var spawn_x_range: Vector2 = Vector2(-280.0, 280.0)

var _spawn_elapsed: float = 0.0
var _spawning: bool = true
var _random: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	_random.randomize()
	_spawn_until_time()

func _spawn_until_time() -> void:
	while _spawning and _spawn_elapsed < spawn_duration:
		var interval: float = _random.randf_range(min_spawn_interval, max_spawn_interval)
		var wait_time: float = minf(interval, spawn_duration - _spawn_elapsed)
		await get_tree().create_timer(wait_time).timeout
		if not is_inside_tree():
			return
		_spawn_elapsed += wait_time
		if _spawn_elapsed <= spawn_duration:
			var enemy: Node2D = enemy_scene.instantiate() as Node2D
			get_parent().add_child(enemy)
			enemy.global_position = Vector2(_random.randf_range(spawn_x_range.x, spawn_x_range.y), spawn_position.y)
	_spawning = false
