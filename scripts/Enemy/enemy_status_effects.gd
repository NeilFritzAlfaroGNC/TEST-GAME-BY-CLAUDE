
extends Node
class_name EnemyStatusEffects

signal stun_ended
signal freeze_ended
signal burn_tick

var is_frozen: bool = false
var is_stunned: bool = false

var freeze_token: int = 0
var stun_token: int = 0
var burn_token: int = 0

var enemy: Node = null


func _ready() -> void:
	enemy = get_parent()


func apply_freeze(duration: float) -> void:
	if not _can_apply_effect():
		return

	if is_frozen:
		print("[Enemy] Freeze rejected: enemy is already frozen.")
		return

	if duration <= 0.0:
		return

	freeze_token += 1
	var this_token := freeze_token

	is_frozen = true

	print("[Enemy] Frozen for ", duration, " seconds.")

	await get_tree().create_timer(duration).timeout

	if not _effect_is_valid() or this_token != freeze_token:
		return

	is_frozen = false

	print("[Enemy] Freeze ended.")

	freeze_ended.emit()


func apply_stun(duration: float) -> void:
	if not _can_apply_effect():
		return

	if is_frozen:
		print("[Enemy] Stun rejected: enemy is frozen.")
		return

	if duration <= 0.0:
		return

	stun_token += 1
	var this_token := stun_token

	is_stunned = true

	print("[Enemy] Stunned for ", duration, " seconds.")

	await get_tree().create_timer(duration).timeout

	if not _effect_is_valid() or this_token != stun_token:
		return

	is_stunned = false

	print("[Enemy] Stun ended.")

	stun_ended.emit()


func apply_burn(
	damage: float,
	duration: float,
	tick_count: int,
	tick_interval: float
) -> void:
	if not _can_apply_effect():
		return

	if is_frozen:
		print("[Enemy] Burn rejected: enemy is frozen.")
		return

	if damage <= 0.0 or duration <= 0.0:
		return

	if tick_count <= 0 or tick_interval <= 0.0:
		return

	burn_token += 1
	var this_token := burn_token

	var elapsed_time: float = 0.0
	var completed_ticks: int = 0

	print(
		"[Enemy] Burn started. Duration: ",
		duration,
		" | Tick damage: ",
		damage,
		" | Tick count: ",
		tick_count,
		" | Interval: ",
		tick_interval
	)

	while elapsed_time < duration and completed_ticks < tick_count:
		var remaining_duration: float = duration - elapsed_time
		var wait_time: float = minf(tick_interval, remaining_duration)

		await get_tree().create_timer(wait_time).timeout

		if not _effect_is_valid() or this_token != burn_token:
			return

		elapsed_time += wait_time

		if elapsed_time >= duration:
			break

		if is_frozen:
			print("[Enemy] Burn tick skipped: enemy is frozen.")
			continue

		completed_ticks += 1

		_apply_burn_damage(
			damage,
			this_token,
			"Tick " + str(completed_ticks) + "/" + str(tick_count)
		)

		if not _effect_is_valid() or this_token != burn_token:
			return

	# Apply all remaining ticks together when duration expires.
	if completed_ticks < tick_count:
		if not _effect_is_valid() or this_token != burn_token:
			return

		var remaining_ticks: int = tick_count - completed_ticks

		if is_frozen:
			print(
				"[Enemy] Remaining Burn ticks cancelled because enemy is frozen."
			)
			return

		var burst_damage: int = roundi(damage * remaining_ticks)

		print(
			"[Enemy] Burn expiration burst! Remaining ticks: ",
			remaining_ticks,
			" | Total burst damage: ",
			burst_damage
		)

		if burst_damage > 0 and enemy.has_method("take_damage"):
			enemy.take_damage(burst_damage)
			burn_tick.emit()

	print("[Enemy] Burn ended.")


func _apply_burn_damage(
	damage: float,
	this_token: int,
	description: String
) -> void:
	if not _effect_is_valid() or this_token != burn_token:
		return

	var amount: int = maxi(roundi(damage), 0)

	if amount <= 0:
		return

	if enemy.has_method("take_damage"):
		enemy.take_damage(amount)

		print(
			"[Enemy] Burn ",
			description,
			": ",
			amount,
			" damage."
		)

		burn_tick.emit()


func _can_apply_effect() -> bool:
	return (
		is_instance_valid(enemy)
		and not enemy.is_queued_for_deletion()
		and not bool(enemy.get("is_dead"))
	)


func _effect_is_valid() -> bool:
	return _can_apply_effect()


func clear_effects() -> void:
	freeze_token += 1
	stun_token += 1
	burn_token += 1

	is_frozen = false
	is_stunned = false
