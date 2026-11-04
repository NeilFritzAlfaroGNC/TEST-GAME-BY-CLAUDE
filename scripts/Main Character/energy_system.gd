
extends Node
class_name EnergySystem

signal energy_changed(current_energy: float, maximum_energy: float)
signal energy_depleted


@export_group("Energy Settings")
@export var maximum_energy: float = 100.0

@export var starting_energy: float = 100.0


var current_energy: float = 100.0


func _ready() -> void:
	maximum_energy = maxf(maximum_energy, 1.0)
	current_energy = clampf(starting_energy, 0.0, maximum_energy)
	energy_changed.emit(current_energy, maximum_energy)


func restore_energy(amount: float) -> void:
	if amount <= 0.0:
		return

	var previous_energy := current_energy

	current_energy = minf(
		current_energy + amount,
		maximum_energy
	)

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

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		use_energy(10.0)
		print("Energy: ", current_energy)

	if event.is_action_pressed("ui_cancel"):
		restore_energy(10.0)
		print("Energy: ", current_energy)
