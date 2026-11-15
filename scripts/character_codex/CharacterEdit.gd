extends Panel

const SAVE_PATH := "user://character_codex.cfg"
@export_file("*.tscn") var return_scene_path: String
@export var character_animations: Array[SpriteFrames]
@onready var preview: AnimatedSprite2D = $Preview
var _character := 0
var _saved := -1


func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		_saved = int(config.get_value("character", "index", -1))
	_character = clampi(_saved, 0, maxi(0, character_animations.size() - 1))
	$Previous.pressed.connect(_move_character.bind(-1))
	$Next.pressed.connect(_move_character.bind(1))
	$Select.pressed.connect(_save_character)
	$Back.pressed.connect(_go_back)
	_show_character()


func _move_character(direction: int) -> void:
	if character_animations.size() > 1:
		_character = posmod(_character + direction, character_animations.size())
		_show_character()


func _show_character() -> void:
	var frames: SpriteFrames
	if not character_animations.is_empty():
		frames = character_animations[_character]
	preview.stop()
	preview.sprite_frames = frames
	preview.visible = frames != null
	if frames != null:
		var names := frames.get_animation_names()
		if frames.has_animation(&"idle"):
			preview.play(&"idle")
		elif not names.is_empty():
			preview.play(StringName(names[0]))
	$Name.text = "Character %d" % (_character + 1) if frames != null else "No character assigned"
	$Previous.disabled = character_animations.size() < 2
	$Next.disabled = character_animations.size() < 2
	$Select.disabled = frames == null or _character == _saved
	$Status.text = "Selected" if frames != null and _character == _saved else ""


func _save_character() -> void:
	var config := ConfigFile.new()
	config.set_value("character", "index", _character)
	if config.save(SAVE_PATH) == OK:
		_saved = _character
		_show_character()
	else:
		$Status.text = "Could not save selection."


func _go_back() -> void:
	var result := get_tree().change_scene_to_file(return_scene_path)
	if result != OK:
		$Status.text = "Could not open the level map."


