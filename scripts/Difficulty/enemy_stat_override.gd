
extends Resource
class_name EnemyStatOverride

@export_group("Enemy")
@export var enemy_scene: PackedScene

@export_group("Health Override")
@export var override_health: bool = false
@export_range(1, 9999, 1) var health: int = 5

@export_group("Attack Override")
@export var override_attack: bool = false
@export_range(0, 9999, 1) var attack: int = 5
