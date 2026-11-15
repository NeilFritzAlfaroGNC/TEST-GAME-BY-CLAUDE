extends Node
class_name EnemyStatusEffects

# ==================================================
# REUSABLE ENEMY STATUS EFFECTS
# GODOT 4.7.1
# ==================================================
#
# Preserves:
# - Stun and freeze timers
# - Freeze preventing stun and burn
# - Burn ticks and expiration burst
# - Effect cancellation tokens
# - Existing signals and public methods
#
# Adds:
# - Per-enemy stun duration multiplier
# - Per-enemy freeze duration multiplier
# - Per-enemy burn duration multiplier
# - Per-enemy burn damage multiplier
# - Debug message toggle
#
# Default multipliers of 1.0 preserve
# existing gameplay.
# ==================================================


# ==================================================
# SIGNALS
# ==================================================

signal stun_ended
signal freeze_ended
signal burn_tick


# ==================================================
# STUN SETTINGS
# ==================================================

@export_group("Stun Resistance")

@export_range(0.0, 5.0, 0.05)
var stun_duration_multiplier: float = 1.0


# ==================================================
# FREEZE SETTINGS
# ==================================================

@export_group("Freeze Resistance")

@export_range(0.0, 5.0, 0.05)
var freeze_duration_multiplier: float = 1.0


# ==================================================
# BURN SETTINGS
# ==================================================

@export_group("Burn Resistance")

@export_range(0.0, 5.0, 0.05)
var burn_duration_multiplier: float = 1.0

@export_range(0.0, 5.0, 0.05)
var burn_damage_multiplier: float = 1.0


# ==================================================
# DEBUGGING
# ==================================================

@export_group("Debugging")

@export var print_debug_messages: bool = true


# ==================================================
# STATUS STATE
# ==================================================

var is_frozen: bool = false
var is_stunned: bool = false

var freeze_token: int = 0
var stun_token: int = 0
var burn_token: int = 0

var enemy: Node = null


# ==================================================
# INITIALIZATION
# ==================================================

func _ready() -> void:
	enemy = get_parent()


# ==================================================
# FREEZE
# ==================================================

func apply_freeze(duration: float) -> void:

	if not _can_apply_effect():
		return

	if is_frozen:
		if print_debug_messages:
			print(
				"[Enemy] Freeze rejected: ",
				"enemy is already frozen."
			)
		return

	if duration <= 0.0:
		return

	var actual_duration: float = (
		duration
		* maxf(freeze_duration_multiplier, 0.0)
	)

	if actual_duration <= 0.0:
		return

	freeze_token += 1

	var this_token: int = freeze_token

	is_frozen = true

	if print_debug_messages:
		print(
			"[Enemy] Frozen for ",
			actual_duration,
			" seconds."
		)

	await get_tree().create_timer(
		actual_duration
	).timeout

	if not _effect_is_valid():
		return

	if this_token != freeze_token:
		return

	is_frozen = false

	if print_debug_messages:
		print("[Enemy] Freeze ended.")

	freeze_ended.emit()


# ==================================================
# STUN
# ==================================================

func apply_stun(duration: float) -> void:

	if not _can_apply_effect():
		return

	if is_frozen:
		if print_debug_messages:
			print(
				"[Enemy] Stun rejected: ",
				"enemy is frozen."
			)
		return

	if duration <= 0.0:
		return

	var actual_duration: float = (
		duration
		* maxf(stun_duration_multiplier, 0.0)
	)

	if actual_duration <= 0.0:
		return

	stun_token += 1

	var this_token: int = stun_token

	is_stunned = true

	if print_debug_messages:
		print(
			"[Enemy] Stunned for ",
			actual_duration,
			" seconds."
		)

	await get_tree().create_timer(
		actual_duration
	).timeout

	if not _effect_is_valid():
		return

	if this_token != stun_token:
		return

	is_stunned = false

	if print_debug_messages:
		print("[Enemy] Stun ended.")

	stun_ended.emit()


# ==================================================
# BURN
# ==================================================

func apply_burn(
	damage: float,
	duration: float,
	tick_count: int,
	tick_interval: float
) -> void:

	if not _can_apply_effect():
		return

	if is_frozen:
		if print_debug_messages:
			print(
				"[Enemy] Burn rejected: ",
				"enemy is frozen."
			)
		return

	if damage <= 0.0 or duration <= 0.0:
		return

	if tick_count <= 0 or tick_interval <= 0.0:
		return

	var actual_damage: float = (
		damage
		* maxf(burn_damage_multiplier, 0.0)
	)

	var actual_duration: float = (
		duration
		* maxf(burn_duration_multiplier, 0.0)
	)

	if actual_damage <= 0.0:
		return

	if actual_duration <= 0.0:
		return

	burn_token += 1

	var this_token: int = burn_token

	var elapsed_time: float = 0.0
	var completed_ticks: int = 0

	if print_debug_messages:
		print(
			"[Enemy] Burn started. Duration: ",
			actual_duration,
			" | Tick damage: ",
			actual_damage,
			" | Tick count: ",
			tick_count,
			" | Interval: ",
			tick_interval
		)

	while (
		elapsed_time < actual_duration
		and completed_ticks < tick_count
	):

		var remaining_duration: float = (
			actual_duration - elapsed_time
		)

		var wait_time: float = minf(
			tick_interval,
			remaining_duration
		)

		await get_tree().create_timer(
			wait_time
		).timeout

		if not _effect_is_valid():
			return

		if this_token != burn_token:
			return

		elapsed_time += wait_time

		if elapsed_time >= actual_duration:
			break

		if is_frozen:

			if print_debug_messages:
				print(
					"[Enemy] Burn tick skipped: ",
					"enemy is frozen."
				)

			continue

		completed_ticks += 1

		_apply_burn_damage(
			actual_damage,
			this_token,
			"Tick "
			+ str(completed_ticks)
			+ "/"
			+ str(tick_count)
		)

		if not _effect_is_valid():
			return

		if this_token != burn_token:
			return

	# Preserve the existing expiration burst.
	# Any remaining ticks are applied together.

	if completed_ticks < tick_count:

		if not _effect_is_valid():
			return

		if this_token != burn_token:
			return

		var remaining_ticks: int = (
			tick_count - completed_ticks
		)

		if is_frozen:

			if print_debug_messages:
				print(
					"[Enemy] Remaining Burn ticks ",
					"cancelled because enemy is frozen."
				)

			return

		var burst_damage: int = roundi(
			actual_damage * remaining_ticks
		)

		if print_debug_messages:
			print(
				"[Enemy] Burn expiration burst! ",
				"Remaining ticks: ",
				remaining_ticks,
				" | Total burst damage: ",
				burst_damage
			)

		if (
			burst_damage > 0
			and is_instance_valid(enemy)
			and enemy.has_method("take_damage")
		):

			enemy.take_damage(
				burst_damage
			)

			burn_tick.emit()

	if print_debug_messages:
		print("[Enemy] Burn ended.")


# ==================================================
# APPLY BURN TICK DAMAGE
# ==================================================

func _apply_burn_damage(
	damage: float,
	this_token: int,
	description: String
) -> void:

	if not _effect_is_valid():
		return

	if this_token != burn_token:
		return

	var amount: int = maxi(
		roundi(damage),
		0
	)

	if amount <= 0:
		return

	if enemy.has_method("take_damage"):

		enemy.take_damage(amount)

		if print_debug_messages:
			print(
				"[Enemy] Burn ",
				description,
				": ",
				amount,
				" damage."
			)

		burn_tick.emit()


# ==================================================
# EFFECT VALIDATION
# ==================================================

func _can_apply_effect() -> bool:

	return (
		is_instance_valid(enemy)
		and not enemy.is_queued_for_deletion()
		and not bool(enemy.get("is_dead"))
	)


func _effect_is_valid() -> bool:
	return _can_apply_effect()


# ==================================================
# CLEAR ALL EFFECTS
# ==================================================

func clear_effects() -> void:

	freeze_token += 1
	stun_token += 1
	burn_token += 1

	is_frozen = false
	is_stunned = false
