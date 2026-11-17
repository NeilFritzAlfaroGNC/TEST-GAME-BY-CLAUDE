
extends Node

signal buff_activated(
	damage_bonus: float,
	uses: int,
	duration: float
)

signal buff_use_consumed(remaining_uses: int)
signal buff_expired
signal buffs_changed

enum GrowEffect {
	DAMAGE,
	ENLARGE,
	KNOCKBACK,
	STUN,
	FLOPPING
}

var active_buffs: Array[Dictionary] = []
var next_buff_id: int = 0

# Legacy compatibility.
var damage_bonus: float = 0.0
var uses_remaining: int = 0
var is_active: bool = false
var buff_token: int = 0


# ==================================================
# ACTIVATE BUFF
# ==================================================

func activate_buff(
	bonus: float,
	duration: float,
	uses: int
) -> void:

	activate_effect(
		GrowEffect.DAMAGE,
		bonus,
		duration,
		uses
	)


# ==================================================
# ACTIVATE AN INDIVIDUAL GROW EFFECT
# ==================================================

func activate_effect(
	effect_type: GrowEffect,
	value: float,
	duration: float,
	uses: int,
	settings: Dictionary = {}
) -> void:

	next_buff_id += 1

	var effect_id: int = next_buff_id

	var new_buff: Dictionary = {
		"id": effect_id,
		"type": effect_type,
		"value": maxf(value, 0.0),
		"duration": duration,
		"uses": maxi(uses, 1),
		"settings": settings.duplicate(true)
	}

	active_buffs.append(new_buff)

	_update_legacy_properties()

	print(
		"[GROW] Activated: ",
		GrowEffect.keys()[effect_type],
		" | Value: ",
		value,
		" | Uses: ",
		uses,
		" | Duration: ",
		duration
	)

	buffs_changed.emit()

	if effect_type == GrowEffect.DAMAGE:
		buff_activated.emit(
			get_damage_bonus(),
			uses,
			duration
		)

	if duration > 0.0:
		_expire_effect(
			duration,
			effect_id
		)


# ==================================================
# EXPIRE ONE INDIVIDUAL EFFECT
# ==================================================

func _expire_effect(
	duration: float,
	effect_id: int
) -> void:

	await get_tree().create_timer(
		duration
	).timeout

	for i in range(
		active_buffs.size() - 1,
		-1,
		-1
	):

		if int(
			active_buffs[i]["id"]
		) == effect_id:

			active_buffs.remove_at(i)

			_update_legacy_properties()

			buffs_changed.emit()
			buff_expired.emit()

			print(
				"[GROW] Effect expired: ",
				effect_id
			)

			return


# ==================================================
# ACTIVE BUFF CHECKS
# ==================================================

func has_active_buff() -> bool:
	return not active_buffs.is_empty()


func has_effect(
	effect_type: GrowEffect
) -> bool:

	for buff in active_buffs:

		if int(
			buff["type"]
		) == effect_type:

			return true

	return false


# ==================================================
# DAMAGE — ADDITIVE
# ==================================================

func get_damage_bonus() -> float:

	var total: float = 0.0

	for buff in active_buffs:

		if int(
			buff["type"]
		) == GrowEffect.DAMAGE:

			total += float(
				buff["value"]
			)

	return total


# ==================================================
# ENLARGE — ADDITIVE
# ==================================================

func get_size_multiplier() -> float:

	var total: float = 0.0
	var found_enlarge: bool = false

	for buff in active_buffs:

		if int(
			buff["type"]
		) == GrowEffect.ENLARGE:

			total += float(
				buff["value"]
			)

			found_enlarge = true

	# Normal-size projectile.
	if not found_enlarge:
		return 1.0

	# Example:
	# 2.5 + 2.5 = 5.0
	# 5.0 + 5.0 = 10.0
	return maxf(
		total,
		1.0
	)


# ==================================================
# KNOCKBACK — ADDITIVE
# ==================================================

func get_knockback_strength() -> float:

	var total: float = 0.0

	for buff in active_buffs:

		if int(
			buff["type"]
		) == GrowEffect.KNOCKBACK:

			total += float(
				buff["value"]
			)

	return total


# ==================================================
# STUN — ADDITIVE
# ==================================================

func get_stun_duration() -> float:

	var total: float = 0.0

	for buff in active_buffs:

		if int(
			buff["type"]
		) == GrowEffect.STUN:

			total += float(
				buff["value"]
			)

	return total


# ==================================================
# FLOPPING — ADDITIVE UNIQUE HIT LIMIT
# ==================================================

func get_flopping_settings() -> Dictionary:

	var result: Dictionary = {
		"enabled": false,
		"max_hits": 0,
		"bounce_range": 250.0,
		"bounce_duration": 0.3,
		"bounce_height": 65.0,
		"random_fallback": true
	}

	var total_hits: int = 0
	var flopping_count: int = 0

	for buff in active_buffs:

		if int(
			buff["type"]
		) != GrowEffect.FLOPPING:

			continue

		var settings: Dictionary = (
			buff.get("settings", {})
		)

		total_hits += maxi(
			int(buff["value"]),
			1
		)

		# The first Flopping effect determines
		# the movement duration and fallback.
		# Later effects contribute their hit limits.
		if flopping_count == 0:

			result["bounce_duration"] = maxf(
				float(
					settings.get(
						"bounce_duration",
						0.3
					)
				),
				0.05
			)

			result["random_fallback"] = bool(
				settings.get(
					"random_fallback",
					true
				)
			)

		# Use the largest bounce range and arc
		# height among the combined effects.
		result["bounce_range"] = maxf(
			float(result["bounce_range"]),
			float(
				settings.get(
					"bounce_range",
					250.0
				)
			)
		)

		result["bounce_height"] = maxf(
			float(result["bounce_height"]),
			float(
				settings.get(
					"bounce_height",
					65.0
				)
			)
		)

		flopping_count += 1

	if flopping_count > 0:

		result["enabled"] = true
		result["max_hits"] = total_hits

	return result


# ==================================================
# SNAPSHOT OF ALL EFFECTS
# ==================================================

func get_effect_snapshot() -> Dictionary:

	return {
		"damage_bonus": get_damage_bonus(),
		"size_multiplier": get_size_multiplier(),
		"knockback_strength": get_knockback_strength(),
		"stun_duration": get_stun_duration(),
		"flopping": get_flopping_settings()
	}


# ==================================================
# RETURN ALL ORIGINAL EFFECTS
# ==================================================

func get_active_effects() -> Array[Dictionary]:

	return active_buffs.duplicate(true)


# ==================================================
# CONSUME ONE USE PER ACTIVE EFFECT
# ==================================================

func consume_buff_use() -> void:

	if active_buffs.is_empty():
		return

	for i in range(
		active_buffs.size() - 1,
		-1,
		-1
	):

		active_buffs[i]["uses"] = (
			int(
				active_buffs[i]["uses"]
			) - 1
		)

		if int(
			active_buffs[i]["uses"]
		) <= 0:

			print(
				"[GROW] Effect consumed: ",
				active_buffs[i]["id"]
			)

			active_buffs.remove_at(i)

	_update_legacy_properties()

	buff_use_consumed.emit(
		uses_remaining
	)

	buffs_changed.emit()


# ==================================================
# CLEAR ALL EFFECTS
# ==================================================

func clear_buff() -> void:

	buff_token += 1

	active_buffs.clear()

	_update_legacy_properties()

	buffs_changed.emit()


# ==================================================
# LEGACY STATUS PROPERTIES
# ==================================================

func _update_legacy_properties() -> void:

	is_active = not active_buffs.is_empty()

	damage_bonus = get_damage_bonus()

	uses_remaining = 0

	for buff in active_buffs:

		uses_remaining = maxi(
			uses_remaining,
			int(
				buff["uses"]
			)
		)
