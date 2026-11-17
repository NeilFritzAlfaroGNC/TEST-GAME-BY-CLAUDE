extends Control

signal round_started
signal answer_classified(is_correct: bool)
signal round_finished

const CATEGORIES: Array[FoodData.FoodCategory] = [
	FoodData.FoodCategory.GO, FoodData.FoodCategory.GLOW, FoodData.FoodCategory.GROW,
]
const CATEGORY_NAMES := ["GO", "GLOW", "GROW"]
const FEEDBACK_SECONDS := 1.1
const LEVEL_ID := "canteen_level_2"
const LEVEL_MAP := "res://scenes/Level Map/level_map.tscn"

@export var food_scenes: Array[PackedScene] = []
@export var canteen_background: Texture2D
@export var save_progress_on_pass: bool = false

@export_group("Easy")
@export_range(1, 100) var easy_questions: int = 10
@export_range(1, 100) var easy_minimum_correct: int = 6
@export_range(1, 100) var easy_two_stars: int = 8
@export_range(1, 100) var easy_three_stars: int = 9
@export_range(1.0, 3600.0) var easy_time_limit: float = 180.0

@export_group("Normal")
@export_range(1, 100) var normal_questions: int = 15
@export_range(1, 100) var normal_minimum_correct: int = 11
@export_range(1, 100) var normal_two_stars: int = 13
@export_range(1, 100) var normal_three_stars: int = 14
@export_range(1.0, 3600.0) var normal_time_limit: float = 240.0

@export_group("Hard")
@export_range(1, 100) var hard_questions: int = 20
@export_range(1, 100) var hard_minimum_correct: int = 16
@export_range(1, 100) var hard_two_stars: int = 18
@export_range(1, 100) var hard_three_stars: int = 19
@export_range(1.0, 3600.0) var hard_time_limit: float = 300.0

@onready var background: TextureRect = %Background
@onready var status: Label = %Status
@onready var card: PanelContainer = %FoodCard
@onready var food_display: Node2D = %FoodDisplay
@onready var feedback: Label = %Feedback
@onready var result: VBoxContainer = %Result
@onready var result_text: Label = %ResultText
@onready var baskets: HBoxContainer = %Baskets
@onready var feedback_timer: Timer = %FeedbackTimer

var difficulty := "easy"
var question_limit: int
var minimum_correct: int
var two_star_minimum: int
var three_star_minimum: int
var time_left: float
var answered := 0
var correct := 0
var stars := 0
var running := false
var accepting_answer := false

var available_foods: Array[PackedScene] = []
var deck: Array[PackedScene] = []
var previous_scene: PackedScene
var current_food: FoodData
var current_categories: Array[int] = []


func _ready() -> void:
	background.texture = canteen_background
	card.set_drag_forwarding(_get_food_drag, Callable(), Callable())
	for i in range(CATEGORIES.size()):
		var basket := baskets.get_child(i) as PanelContainer
		basket.set_drag_forwarding(Callable(), _can_drop_food.bind(i), _drop_food.bind(i))
	card.resized.connect(_center_food)
	feedback_timer.timeout.connect(_next_question)
	%Retry.pressed.connect(_start_round)
	%BackToMap.visible = ResourceLoader.exists(LEVEL_MAP)
	%BackToMap.pressed.connect(_return_to_map)
	_start_round()


func _start_round() -> void:
	var progress := get_node_or_null("/root/ProgressManager")
	difficulty = str(progress.get("current_difficulty")).to_lower() if progress else "easy"
	match difficulty:
		"hard":
			_configure(hard_questions, hard_minimum_correct, hard_two_stars, hard_three_stars, hard_time_limit)
		"normal":
			_configure(normal_questions, normal_minimum_correct, normal_two_stars, normal_three_stars, normal_time_limit)
		_:
			difficulty = "easy"
			_configure(easy_questions, easy_minimum_correct, easy_two_stars, easy_three_stars, easy_time_limit)

	feedback_timer.stop()
	answered = 0
	correct = 0
	stars = 0
	previous_scene = null
	deck.clear()
	available_foods.clear()
	for scene in food_scenes:
		if scene == null or available_foods.has(scene):
			continue
		var instance := scene.instantiate()
		var food := instance as FoodData
		if food and not food.get_level1_categories().is_empty() and _food_texture(food):
			available_foods.append(scene)
		instance.free()

	result.hide()
	baskets.show()
	running = not available_foods.is_empty()
	if running:
		_next_question()
	else:
		accepting_answer = false
		feedback.text = "Assign GO, GLOW, or GROW food scenes in the Inspector."
	_refresh_status()
	round_started.emit()


func _configure(questions: int, passing: int, two_stars: int, three_stars: int, seconds: float) -> void:
	question_limit = maxi(questions, 1)
	minimum_correct = clampi(passing, 1, question_limit)
	two_star_minimum = clampi(two_stars, minimum_correct, question_limit)
	three_star_minimum = clampi(three_stars, two_star_minimum, question_limit)
	time_left = maxf(seconds, 1.0)


func _process(delta: float) -> void:
	if not running:
		return
	time_left = maxf(time_left - delta, 0.0)
	if time_left <= 0.0:
		_finish(true)
	else:
		_refresh_status()


func _next_question() -> void:
	if not running:
		return
	_remove_food()
	if deck.is_empty():
		deck.assign(available_foods)
		deck.shuffle()
		if deck.size() > 1 and deck.back() == previous_scene:
			var repeated: PackedScene = deck.pop_back()
			deck.push_front(repeated)

	previous_scene = deck.pop_back()
	current_food = previous_scene.instantiate() as FoodData
	current_categories = current_food.get_level1_categories()
	current_food.stop()
	# Keep the original art. Scale the instance to fit the question card.
	var texture := _food_texture(current_food)
	var longest_edge := maxf(texture.get_width(), texture.get_height())
	current_food.scale = Vector2.ONE * (154.0 / longest_edge)
	current_food.offset = Vector2.ZERO
	current_food.centered = true
	food_display.add_child(current_food)
	_center_food()
	accepting_answer = true
	feedback.text = "Drag the food into the correct basket."
	_refresh_status()


func _food_texture(food: FoodData) -> Texture2D:
	if food.sprite_frames == null or not food.sprite_frames.has_animation(food.animation):
		return null
	if food.sprite_frames.get_frame_count(food.animation) == 0:
		return null
	return food.sprite_frames.get_frame_texture(food.animation, 0)


func _center_food() -> void:
	food_display.position = card.size * 0.5


func _get_food_drag(_position: Vector2) -> Variant:
	if not accepting_answer or not is_instance_valid(current_food):
		return null

	var preview := TextureRect.new()
	preview.texture = _food_texture(current_food)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.size = Vector2(144, 144)
	preview.position = -preview.size * 0.5
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var preview_root := Control.new()
	preview_root.add_child(preview)
	card.set_drag_preview(preview_root)
	current_food.hide()
	return current_food.get_instance_id()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and accepting_answer and is_instance_valid(current_food):
		current_food.show()


func _can_drop_food(_position: Vector2, data: Variant, _basket: int) -> bool:
	return (
		running and accepting_answer and is_instance_valid(current_food)
		and data is int and data == current_food.get_instance_id()
	)


func _drop_food(drop_position: Vector2, data: Variant, basket: int) -> void:
	if not _can_drop_food(drop_position, data, basket):
		return
	accepting_answer = false
	answered += 1
	var name_text := current_food.food_name.capitalize()
	var answer_is_correct: bool = current_categories.has(CATEGORIES[basket])
	if answer_is_correct:
		correct += 1
		feedback.text = "Correct! %s belongs in %s." % [name_text, CATEGORY_NAMES[basket]]
	else:
		var valid_names: PackedStringArray = []
		for category in current_categories:
			valid_names.append(CATEGORY_NAMES[CATEGORIES.find(category)])
		feedback.text = "Incorrect. %s belongs in %s." % [name_text, " or ".join(valid_names)]
	_remove_food()
	_refresh_status()
	if answered >= question_limit:
		_finish(false)
	else:
		feedback_timer.start(FEEDBACK_SECONDS)
	answer_classified.emit(answer_is_correct)


func _remove_food() -> void:
	if is_instance_valid(current_food):
		current_food.hide()
		current_food.queue_free()
	current_food = null


func _finish(timed_out: bool) -> void:
	running = false
	accepting_answer = false
	feedback_timer.stop()
	_remove_food()
	if correct >= minimum_correct:
		stars = 1
		if correct >= three_star_minimum:
			stars = 3
		elif correct >= two_star_minimum:
			stars = 2

	var progress := get_node_or_null("/root/ProgressManager")
	if stars > 0 and save_progress_on_pass and progress and progress.has_method("save_level_stars"):
		progress.set("current_run_stars", stars)
		progress.call("save_level_stars", difficulty, LEVEL_ID, stars)

	if timed_out:
		feedback.text = "Time’s up!"
	var outcome := "Canteen cleared!" if stars > 0 else "Keep practicing"
	result_text.text = "%s\n%d correct out of %d  •  %d %s" % [
		outcome, correct, question_limit, stars, "star" if stars == 1 else "stars"
	]
	result.show()
	baskets.hide()
	_refresh_status()
	round_finished.emit()


func _return_to_map() -> void:
	var error := get_tree().change_scene_to_file(LEVEL_MAP)
	if error != OK:
		feedback.text = "Could not open the Level Map."


func _refresh_status() -> void:
	var seconds := ceili(time_left)
	var text := "%s   •   Answered %d / %d   •   Correct %d / %d to pass   •   %02d:%02d" % [
		difficulty.capitalize(), answered, question_limit, correct, minimum_correct,
		floori(seconds / 60.0), seconds % 60
	]
	if status.text != text:
		status.text = text
