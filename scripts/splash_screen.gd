extends Control
## Standalone splash transition; configure the destination scene in the Inspector.

@export_file("*.tscn") var next_scene_path: String = "res://scene/main_menu.tscn"
const DISPLAY_DURATION: float = 0.5
const FADE_DURATION: float = 0.18

@onready var splash_texture: TextureRect = $SplashTexture

var transition_started: bool = false

func _ready() -> void:
	_fit_logo_to_viewport()
	get_viewport().size_changed.connect(_fit_logo_to_viewport)
	modulate.a = 0.0
	splash_texture.modulate.a = 1.0
	var fade_in: Tween = create_tween()
	fade_in.tween_property(self, "modulate:a", 1.0, FADE_DURATION)
	fade_in.tween_interval(DISPLAY_DURATION)
	fade_in.tween_property(self, "modulate:a", 0.0, FADE_DURATION)
	fade_in.finished.connect(_on_splash_finished)

func _fit_logo_to_viewport() -> void:
	if splash_texture.texture == null:
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	var image_size: Vector2 = splash_texture.texture.get_size()
	var fit_scale: float = minf(viewport_size.x / image_size.x, viewport_size.y / image_size.y)
	var fitted_size: Vector2 = image_size * fit_scale
	splash_texture.offset_left = -fitted_size.x * 0.25
	splash_texture.offset_top = -fitted_size.y * 0.25
	splash_texture.offset_right = fitted_size.x * 0.25
	splash_texture.offset_bottom = fitted_size.y * 0.25

func _on_splash_finished() -> void:
	if transition_started:
		return
	transition_started = true
	get_tree().change_scene_to_file(next_scene_path)
