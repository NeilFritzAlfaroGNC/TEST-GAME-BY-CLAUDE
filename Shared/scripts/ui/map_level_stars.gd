@tool
extends Control

@export_group("Level Settings")
@export_enum("cafeteria_level_1", "canteen_level_2", "Tanjangco Hall") var level_id: String = "cafeteria_level_1"
@export_enum("Current", "Easy", "Normal", "Hard") var difficulty: String = "Current"

var show_current_run := false

@export_group("Star Appearance")
@export var filled_star_texture: Texture2D:
	set(value):
		filled_star_texture = value
		_update_sprites()

@export var empty_star_texture: Texture2D:
	set(value):
		empty_star_texture = value
		_update_sprites()

@export_range(4.0, 64.0, 1.0, "suffix:px") var star_width: float = 18.0:
	set(value):
		star_width = value
		_update_sprites()

@export_range(4.0, 64.0, 1.0, "suffix:px") var star_height: float = 18.0:
	set(value):
		star_height = value
		_update_sprites()

@export_group("Star Layout")
@export_range(0.0, 40.0, 1.0, "suffix:px") var star_spacing: float = 8.0:
	set(value):
		star_spacing = value
		_update_sprites()

@export var horizontal_offset: float = 0.0:
	set(value):
		horizontal_offset = value
		_update_sprites()

@export var vertical_offset: float = 0.0:
	set(value):
		vertical_offset = value
		_update_sprites()

@export_group("Star Progress")
@export_range(0, 3, 1) var earned_stars: int = 0:
	set(value):
		earned_stars = value
		_update_sprites()

var _earned_stars := 0
@onready var _sprites: Array[Sprite2D] = [$Star1, $Star2, $Star3]


func _ready() -> void:
	if Engine.is_editor_hint():
		_update_sprites()
	else:
		refresh_stars()


func refresh_stars() -> void:
	if Engine.is_editor_hint():
		return
	var rating_difficulty: String = ProgressManager.current_difficulty if difficulty == "Current" else difficulty.to_lower()
	var save_id := "scene3_level_3" if level_id == "Tanjangco Hall" else level_id
	set_earned_stars(ProgressManager.get_level_stars(rating_difficulty, save_id))


func set_earned_stars(amount: int) -> void:
	_earned_stars = clampi(amount, 0, 3)
	_update_sprites()


func _update_sprites() -> void:
	if not is_node_ready():
		return

	var visible_rating := earned_stars if Engine.is_editor_hint() else _earned_stars
	var step := star_width + star_spacing
	for i in range(_sprites.size()):
		var sprite := _sprites[i]
		sprite.position = Vector2(horizontal_offset + (i - 1) * step, vertical_offset)
		sprite.texture = filled_star_texture if i < visible_rating else empty_star_texture
		if sprite.texture != null:
			sprite.scale = Vector2(star_width, star_height) / sprite.texture.get_size()
