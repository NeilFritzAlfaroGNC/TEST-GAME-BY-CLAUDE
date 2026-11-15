
extends Node
class_name FoodConsumption


signal consumption_started(food: FoodData)
signal consumption_finished(food: FoodData)


var is_consuming: bool = false


func can_consume(food: FoodData) -> bool:
	if is_consuming:
		return false

	if not is_instance_valid(food):
		return false

	if food.food_name.is_empty():
		push_warning("[FoodConsumption] Food has no food_name.")
		return false

	return true


func begin_consumption(food: FoodData) -> bool:
	if not can_consume(food):
		return false

	is_consuming = true
	consumption_started.emit(food)

	print(
		"[FoodConsumption] Started consuming: ",
		food.food_name,
		" | Categories: ",
		", ".join(food.get_selected_category_names())
	)

	return true


func finish_consumption(food: FoodData) -> void:
	if not is_consuming:
		return

	is_consuming = false
	consumption_finished.emit(food)

	if is_instance_valid(food):
		print("[FoodConsumption] Finished: ", food.food_name)
