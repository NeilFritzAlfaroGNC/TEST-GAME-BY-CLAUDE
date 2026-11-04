
extends Node

signal buff_activated(damage_bonus: float, uses: int, duration: float)
signal buff_use_consumed(remaining_uses: int)
signal buff_expired

var damage_bonus: float = 0.0
var uses_remaining: int = 0
var is_active: bool = false

var buff_token: int = 0


func activate_buff(
	bonus: float,
	duration: float,
	uses: int
) -> void:
	buff_token += 1
	var this_token := buff_token

	damage_bonus = maxf(bonus, 0.0)
	uses_remaining = maxi(uses, 1)
	is_active = true

	print(
		"[GROW] Buff activated. Bonus: +",
		damage_bonus,
		" | Uses: ",
		uses_remaining,
		" | Duration: ",
		duration
	)

	buff_activated.emit(damage_bonus, uses_remaining, duration)

	if duration <= 0.0:
		return

	_expire_after_duration(duration, this_token)


func _expire_after_duration(
	duration: float,
	this_token: int
) -> void:
	await get_tree().create_timer(duration).timeout

	if this_token != buff_token:
		return

	if not is_active:
		return

	clear_buff()

	print("[GROW] Buff expired.")
	buff_expired.emit()


func has_active_buff() -> bool:
	return is_active and uses_remaining > 0


func get_damage_bonus() -> float:
	if not has_active_buff():
		return 0.0

	return damage_bonus


func consume_buff_use() -> void:
	if not has_active_buff():
		return

	uses_remaining -= 1

	print(
		"[GROW] Remaining buff uses: ",
		uses_remaining
	)

	buff_use_consumed.emit(uses_remaining)

	if uses_remaining <= 0:
		clear_buff()

		print("[GROW] Buff fully consumed.")


func clear_buff() -> void:
	buff_token += 1

	damage_bonus = 0.0
	uses_remaining = 0
	is_active = false
