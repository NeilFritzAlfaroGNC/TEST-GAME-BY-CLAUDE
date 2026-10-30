extends Node2D
class_name ClawAttack
## The enemy's claw scratch. attack() plays the claw animation; while the claw
## is visible, its Hitbox (traced from the claw art) hurts the main character
## once per swing by calling take_hit() on any body it overlaps.

signal hit_landed(target: Node2D)

@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var hitbox: Area2D = $Hitbox

var _swing_hit: bool = false #Already hurt someone during this swing

# Start one claw swing.
func attack() -> void:
	_swing_hit = false
	animation_player.stop()
	animation_player.play("attack")

func _physics_process(_delta: float) -> void:
	# The claw only hurts while it is showing (the "attack" animation toggles visibility).
	if _swing_hit or not sprite.visible or not animation_player.is_playing():
		return
	for body: Node2D in hitbox.get_overlapping_bodies():
		if body.has_method("take_hit"):
			_swing_hit = true
			body.take_hit()
			hit_landed.emit(body)
			return
