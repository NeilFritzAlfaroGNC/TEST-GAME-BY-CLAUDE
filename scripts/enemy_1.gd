extends CharacterBody2D

#This deals with movements
################################################################################
# Horizontal movement speed in pixels per second.
@export var move_speed: float = 60.0 #Movement Speed
# Direction 1.0 for right -1.0 for left
var direction: float = 1.0 #Movement Direction
#Physics
func _physics_process(delta: float) -> void:
	# Apply gravity so the enemy stays grounded by its physics.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Stop horizontal movement and keep the attack animation while attacking.
	if is_attacking:
		velocity.x = 0.0
	else:
		# Play the walk animation while moving.
		velocity.x = direction * move_speed
		if velocity.x != 0.0 and sprite.animation != "walk":
			sprite.play("walk")

	# Apply movement and collision handling.
	move_and_slide()
################################################################################


################################################################################
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $DetectionArea
@onready var claw: ClawAttack = $ImpactEffect #Claw effect; its hitbox hurts the MainChar
const MAIN_CHAR_SCRIPT: Script = preload("res://scripts/mainchar.gd")
var main_char_detected: bool = false
var is_attacking: bool = false #Attack Animation Status
################################################################################


#This deals with detecting MainChar and playing the attack animation
################################################################################
	# Connect signals to detect when a body enters or leaves the detection area.
func _ready() -> void:
	add_to_group("enemies") #Lets the main character find targets to toss food at
	detection_area.body_entered.connect(_on_body_entered)
	detection_area.body_exited.connect(_on_body_exited)
	sprite.sprite_frames.set_animation_loop("attack", false)
	sprite.animation_finished.connect(_on_animation_finished)

func _on_animation_finished() -> void:
	if sprite.animation == "attack":
		if main_char_detected:
			is_attacking = true
			sprite.play("attack")
			_strike()
		else:
			is_attacking = false
			sprite.play("walk")

#dito ineedit yung gusto mong gawin pag na detect na nya
func _on_body_entered(body: Node2D) -> void:
	# Check if the detected body uses the MainChar script.
	if body.get_script() == MAIN_CHAR_SCRIPT and not is_attacking:
		main_char_detected = true #MainChar Detected
		is_attacking = true
		# Play the enemy's attack animation.
		sprite.play("attack")
		_strike()

# Each attack: swing the claw. The enemy itself does no damage; the claw
# hurts the MainChar only if its hitbox actually touches them (claw_attack.gd).
func _strike() -> void:
	claw.attack()

# Called when a thrown food (e.g. the mango) hits this enemy: remove it from the game.
func hit_by_food() -> void:
	if is_queued_for_deletion():
		return #Already defeated (e.g. hit by the food and its splash in the same frame)
	get_tree().call_group("battle", "on_enemy_defeated") #Counted on the battle end panel
	queue_free()

#Not needed but just in case
func _on_body_exited(body: Node2D) -> void:
	if body.get_script() == MAIN_CHAR_SCRIPT:
		main_char_detected = false
		if not is_attacking:
			sprite.play("walk")
################################################################################
		
