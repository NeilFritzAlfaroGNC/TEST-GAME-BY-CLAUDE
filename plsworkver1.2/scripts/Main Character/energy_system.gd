
extends Node
class_name EnergySystem

signal energy_changed(current_energy: float, maximum_energy: float)
signal energy_depleted

@export_group("Energy Settings")
@export var maximum_energy: float = 100.0
@export var starting_energy: float = 100.0

@export_group("Passive Regeneration")
@export var passive_regeneration_rate: float = 1.0

var current_energy: float = 100.0

# Each entry stores its own restoration rate and remaining duration.
var active_energy_effects: Array[Dictionary] = []

# Each entry stores its own regeneration bonus and remaining duration.
var active_regeneration_boosts: Array[Dictionary] = []

# Each entry stores its own discount percentage and remaining duration.
var active_energy_discounts: Array[Dictionary] = []

# Number of GLOW attacks protected from energy consumption.
var energy_protection_charges: int = 0


func _ready() -> void:
	maximum_energy = maxf(maximum_energy, 1.0)
	passive_regeneration_rate = maxf(passive_regeneration_rate, 0.0)
	current_energy = clampf(starting_energy, 0.0, maximum_energy)
	energy_changed.emit(current_energy, maximum_energy)


func _process(delta: float) -> void:
	_process_energy_over_time(delta)
	_process_regeneration_boosts(delta)
	_process_energy_discounts(delta)

	var total_regeneration: float = get_total_regeneration_rate()

	if current_energy < maximum_energy and total_regeneration > 0.0:
		restore_energy(total_regeneration * delta)


# ==================================================
# ENERGY OVER TIME
# ==================================================

func add_energy_over_time(energy_per_second: float, duration: float) -> void:
	if energy_per_second <= 0.0 or duration <= 0.0:
		return

	active_energy_effects.append({
		"rate": energy_per_second,
		"remaining": duration
	})

	print(
		"[Energy Over Time] Started: ",
		energy_per_second,
		" energy/sec for ",
		duration,
		" seconds."
	)


func _process_energy_over_time(delta: float) -> void:
	for i in range(active_energy_effects.size() - 1, -1, -1):
		var effect: Dictionary = active_energy_effects[i]
		var rate: float = float(effect["rate"])
		var remaining: float = float(effect["remaining"])

		var active_time: float = minf(delta, remaining)

		restore_energy(rate * active_time)

		remaining -= active_time

		if remaining <= 0.0:
			active_energy_effects.remove_at(i)
			print("[Energy Over Time] Effect expired.")
		else:
			effect["remaining"] = remaining
			active_energy_effects[i] = effect


# ==================================================
# REGENERATION BOOST
# ==================================================

func add_regeneration_boost(
	bonus_per_second: float,
	duration: float
) -> void:
	if bonus_per_second <= 0.0 or duration <= 0.0:
		return

	active_regeneration_boosts.append({
		"bonus": bonus_per_second,
		"remaining": duration
	})

	print(
		"[Regeneration Boost] Started: +",
		bonus_per_second,
		" energy/sec for ",
		duration,
		" seconds."
	)


func _process_regeneration_boosts(delta: float) -> void:
	for i in range(active_regeneration_boosts.size() - 1, -1, -1):
		var effect: Dictionary = active_regeneration_boosts[i]
		var remaining: float = float(effect["remaining"])

		remaining -= delta

		if remaining <= 0.0:
			active_regeneration_boosts.remove_at(i)
			print("[Regeneration Boost] Effect expired.")
		else:
			effect["remaining"] = remaining
			active_regeneration_boosts[i] = effect


func get_total_regeneration_rate() -> float:
	var total: float = passive_regeneration_rate

	for effect in active_regeneration_boosts:
		total += float(effect["bonus"])

	return total


# ==================================================
# ENERGY DISCOUNT
# ==================================================

func add_energy_discount(
	discount_percent: float,
	duration: float
) -> void:
	if discount_percent <= 0.0 or duration <= 0.0:
		return

	var safe_discount: float = clampf(discount_percent, 0.0, 100.0)

	active_energy_discounts.append({
		"percent": safe_discount,
		"remaining": duration
	})

	print(
		"[Energy Discount] Started: ",
		safe_discount,
		"% discount for ",
		duration,
		" seconds."
	)

	print(
		"[Energy Discount] Total active discount: ",
		get_total_energy_discount(),
		"%"
	)


func _process_energy_discounts(delta: float) -> void:
	for i in range(active_energy_discounts.size() - 1, -1, -1):
		var effect: Dictionary = active_energy_discounts[i]
		var remaining: float = float(effect["remaining"])

		remaining -= delta

		if remaining <= 0.0:
			active_energy_discounts.remove_at(i)
			print("[Energy Discount] Effect expired.")
		else:
			effect["remaining"] = remaining
			active_energy_discounts[i] = effect


func get_total_energy_discount() -> float:
	var total_discount: float = 0.0

	for effect in active_energy_discounts:
		total_discount += float(effect["percent"])

	return clampf(total_discount, 0.0, 100.0)


func get_discounted_energy_cost(original_cost: float) -> float:
	var safe_cost: float = maxf(original_cost, 0.0)
	var discount: float = get_total_energy_discount()

	return safe_cost * (1.0 - discount / 100.0)


# ==================================================
# ENERGY PROTECTION
# ==================================================

func add_energy_protection(charges: int) -> void:
	if charges <= 0:
		return

	energy_protection_charges += charges

	print(
		"[Energy Protection] Added ",
		charges,
		" charge(s). Total charges: ",
		energy_protection_charges
	)


func has_energy_protection() -> bool:
	return energy_protection_charges > 0


func consume_energy_protection() -> bool:
	if energy_protection_charges <= 0:
		return false

	energy_protection_charges -= 1

	print(
		"[Energy Protection] Charge used. Remaining: ",
		energy_protection_charges
	)

	return true


# ==================================================
# ENERGY MANAGEMENT
# ==================================================

func restore_energy(amount: float) -> void:
	if amount <= 0.0:
		return

	var previous_energy: float = current_energy

	current_energy = minf(current_energy + amount, maximum_energy)

	if current_energy != previous_energy:
		energy_changed.emit(current_energy, maximum_energy)


func use_energy(amount: float) -> bool:
	if amount <= 0.0:
		return true

	if current_energy < amount:
		return false

	current_energy -= amount

	energy_changed.emit(current_energy, maximum_energy)

	if current_energy <= 0.0:
		energy_depleted.emit()

	return true


func has_enough_energy(amount: float) -> bool:
	return current_energy >= maxf(amount, 0.0)


func refill_energy() -> void:
	current_energy = maximum_energy
	energy_changed.emit(current_energy, maximum_energy)


func get_energy_percentage() -> float:
	if maximum_energy <= 0.0:
		return 0.0

	return current_energy / maximum_energy * 100.0


# ==================================================
# TEMPORARY TEST INPUTS
# ==================================================

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		use_energy(10.0)
		print("Energy: ", current_energy)

	if event.is_action_pressed("ui_cancel"):
		restore_energy(10.0)
		print("Energy: ", current_energy)
