
extends Node
class_name EnemyHealth

signal health_changed(current_health: int, maximum_health: int)
signal died

@export var max_health: int = 10

var health: int = 0
var is_dead: bool = false


func _ready() -> void:
	max_health = maxi(max_health, 1)
	health = max_health

	health_changed.emit(health, max_health)


func take_damage(amount: int) -> void:
	if is_dead or amount <= 0:
		return

	health = maxi(health - amount, 0)

	print(
		"[EnemyHealth] Took ", amount,
		" damage. Health: ", health, "/", max_health
	)

	health_changed.emit(health, max_health)

	if health <= 0:
		_die()


func _die() -> void:
	if is_dead:
		return

	is_dead = true

	print("[EnemyHealth] Enemy defeated.")

	died.emit()


func get_health() -> int:
	return health


func get_max_health() -> int:
	return max_health


func is_defeated() -> bool:
	return is_dead
