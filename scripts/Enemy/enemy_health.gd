extends Node
class_name EnemyHealth

# ==================================================
# REUSABLE ENEMY HEALTH
# GODOT 4.7.1
# ==================================================
#
# Preserves:
# - max_health
# - health and is_dead
# - health_changed and died signals
# - take_damage()
# - get_health()
# - get_max_health()
# - is_defeated()
#
# Adds:
# - Optional starting health override
# - Debug message toggle
#
# Difficulty health overrides remain compatible.
# ==================================================


# ==================================================
# SIGNALS
# ==================================================

signal health_changed(
	current_health: int,
	maximum_health: int
)

signal died


# ==================================================
# HEALTH SETTINGS
# ==================================================

@export_group("Health Settings")

@export_range(1, 9999, 1)
var max_health: int = 10

@export var override_starting_health: bool = false

@export_range(1, 9999, 1)
var starting_health: int = 10


# ==================================================
# DEBUGGING
# ==================================================

@export_group("Debugging")

@export var print_debug_messages: bool = true


# ==================================================
# INTERNAL STATE
# ==================================================

var health: int = 0
var is_dead: bool = false


# ==================================================
# INITIALIZATION
# ==================================================

func _ready() -> void:

	max_health = maxi(max_health, 1)

	if override_starting_health:
		health = clampi(
			starting_health,
			1,
			max_health
		)
	else:
		health = max_health

	is_dead = false

	health_changed.emit(
		health,
		max_health
	)

	if print_debug_messages:
		print(
			"[EnemyHealth] Starting HP: ",
			health,
			"/",
			max_health
		)


# ==================================================
# TAKE DAMAGE
# ==================================================

func take_damage(amount: int) -> void:

	if is_dead or amount <= 0:
		return

	var previous_health: int = health

	health = maxi(
		health - amount,
		0
	)

	if health == previous_health:
		return

	if print_debug_messages:
		print(
			"[EnemyHealth] Took ",
			amount,
			" damage. Health: ",
			health,
			"/",
			max_health
		)

	health_changed.emit(
		health,
		max_health
	)

	if health <= 0:
		_die()


# ==================================================
# DEATH
# ==================================================

func _die() -> void:

	if is_dead:
		return

	is_dead = true

	if print_debug_messages:
		print(
			"[EnemyHealth] Enemy defeated."
		)

	died.emit()


# ==================================================
# PUBLIC QUERIES
# ==================================================

func get_health() -> int:
	return health


func get_max_health() -> int:
	return max_health


func is_defeated() -> bool:
	return is_dead
