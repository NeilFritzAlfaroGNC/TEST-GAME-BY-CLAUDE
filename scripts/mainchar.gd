extends CharacterBody2D


const SPEED = 300.0
const JUMP_VELOCITY = -400.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

# Foods the main character throws at enemies, by food name.
@export var throwables: Dictionary = {
	"bread": preload("res://scene/bread_animation.tscn"),
	"corn": preload("res://scene/corn_animation.tscn"),
	"mango": preload("res://scene/mango_animation.tscn"),
	"potato": preload("res://scene/potato_animation.tscn"),
	"rice": preload("res://scene/rice_animation.tscn"),
	"oats": preload("res://scene/oats_animation.tscn"),
}
@export var throw_delay: float = 0.5 #Seconds into the attack animation before the food leaves the hand
@export var throw_scale: float = 0.4 #Size of the thrown food
@export var hand_offset: Vector2 = Vector2(-20, -30) #Where the food is released, relative to the character
@export var throw_speed: float = 500.0 #Used to choose the flight time from the distance


func _ready() -> void:
	sprite.animation_finished.connect(_on_animation_finished)


# Called when food is dropped on the main character: play the attack once.
func play_attack() -> void:
	sprite.play("attack")


# Called by food_item.gd. Every food plays the attack; throwable foods
# (the mango) are also tossed at the nearest enemy.
func receive_food(food_name: String) -> void:
	play_attack()
	if throwables.has(food_name):
		await get_tree().create_timer(throw_delay).timeout
		if is_inside_tree():
			toss(throwables[food_name])


# Throw a projectile scene in an arc at the nearest enemy (or straight ahead if none).
func toss(projectile_scene: PackedScene) -> void:
	var start: Vector2 = global_position + hand_offset
	var target: Vector2 = start + Vector2(-300, 60)
	var enemy: Node2D = _nearest_enemy()
	var time: float = 0.8
	if enemy:
		time = clampf(start.distance_to(enemy.global_position) / throw_speed, 0.5, 1.2)
		# Lead the target: aim where the enemy will be when the food arrives.
		var enemy_velocity: Vector2 = enemy.velocity if enemy is CharacterBody2D else Vector2.ZERO
		target = enemy.global_position + Vector2(enemy_velocity.x * time, 0.0)
	var projectile: Node2D = projectile_scene.instantiate()
	get_parent().add_child(projectile)
	projectile.global_position = start
	projectile.scale = Vector2(throw_scale, throw_scale)
	projectile.launch(target, time)


func _nearest_enemy() -> Node2D:
	var nearest: Node2D = null
	for enemy: Node2D in get_tree().get_nodes_in_group("enemies"):
		if nearest == null or global_position.distance_to(enemy.global_position) < global_position.distance_to(nearest.global_position):
			nearest = enemy
	return nearest


# Go back to idle after the attack finishes.
func _on_animation_finished() -> void:
	if sprite.animation == "attack":
		sprite.play("idle")


func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
