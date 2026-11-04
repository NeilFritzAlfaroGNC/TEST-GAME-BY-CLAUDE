
extends Node2D
class_name ClawAttack

signal hit_landed(target: Node2D)

@export_range(1, 999, 1) var attack_damage: int = 1

@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var hitbox: Area2D = $HitBox

var _swing_hit: bool = false


func attack() -> void:
	_swing_hit = false
	animation_player.stop()
	animation_player.play("attack")


func _physics_process(_delta: float) -> void:
	if _swing_hit or not sprite.visible or not animation_player.is_playing():
		return

	for body: Node2D in hitbox.get_overlapping_bodies():
		if body.has_method("take_hit"):
			_swing_hit = true
			body.take_hit(attack_damage)
			hit_landed.emit(body)
			return
