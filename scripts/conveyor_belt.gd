extends Node2D
class_name ConveyorBelt
## Animated conveyor belt. Spawns a random food at the right end every
## min..max seconds; foods ride the belt right -> left inside FoodSlot.
## Foods can be dragged off the belt (see food_item.gd).

# Emitted when a food reaches the left end of the belt (it is removed after).
signal food_reached_end(food: FoodItem)
# Emitted when a food is dropped on the main character.
signal food_fed(food: FoodItem, target: Node2D)

const FOOD_SCENE: PackedScene = preload("res://scene/food_item.tscn")

@export var food_speed: float = 60.0 #Pixels per second, right -> left
@export var min_spawn_interval: float = 1.0 #Seconds
@export var max_spawn_interval: float = 5.0 #Seconds
# Food sheets to pick from at random (256x256, whole food in the top-left cell).
@export var food_textures: Array[Texture2D] = [
	preload("res://assets/Foods/bread sprite.png"),
	preload("res://assets/Foods/corn sprite.png"),
	preload("res://assets/Foods/mango sprite.png"),
	preload("res://assets/Foods/Potato sprite.png"),
	preload("res://assets/Foods/Rice sprite.png"),
	preload("res://assets/Foods/oats sprite.png"),
]

@onready var belt_sprite: AnimatedSprite2D = $BeltSprite
@onready var food_slot: Node2D = $FoodSlot #Spawned foods live here
@onready var start_point: Marker2D = $StartPoint #Right end, where food enters
@onready var end_point: Marker2D = $EndPoint #Left end, where food leaves

var running: bool = true
var _random: RandomNumberGenerator = RandomNumberGenerator.new()
var _spawn_timer: Timer = Timer.new()

func _ready() -> void:
	_random.randomize()
	belt_sprite.play("run")
	_spawn_timer.one_shot = true
	_spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(_spawn_timer)
	_start_spawn_timer()

func _process(delta: float) -> void:
	if not running:
		return
	for food: FoodItem in food_slot.get_children():
		if food.dragging:
			continue
		# Food dropped to the right of the belt goes back onto it.
		food.position.x = minf(food.position.x, start_point.position.x)
		food.position.x -= food_speed * delta
		if food.position.x <= end_point.position.x:
			food_reached_end.emit(food)
			food.queue_free()

func _start_spawn_timer() -> void:
	_spawn_timer.start(_random.randf_range(min_spawn_interval, max_spawn_interval))

func _on_spawn_timer_timeout() -> void:
	if running:
		spawn_food()
	_start_spawn_timer()

# Put one random food at the right end of the belt.
func spawn_food() -> FoodItem:
	var sheet: Texture2D = food_textures[_random.randi_range(0, food_textures.size() - 1)]
	var food: FoodItem = FOOD_SCENE.instantiate()
	food_slot.add_child(food)
	food.set_food_texture(sheet)
	food.food_name = sheet.resource_path.get_file().get_basename().trim_suffix(" sprite").to_lower()
	food.position = start_point.position
	food.belt_y = start_point.position.y
	food.fed.connect(func(f: FoodItem, target: Node2D) -> void: food_fed.emit(f, target))
	return food

# Stop / restart the belt animation, food movement and spawning.
func stop_belt() -> void:
	running = false
	belt_sprite.pause()

func start_belt() -> void:
	running = true
	belt_sprite.play("run")
