extends Control
class_name StoryScene

signal story_completed

const MAIN_SCENE_PATH: String = "res://scenes/Main.tscn"

@export var story_data: StoryCollection
## Characters revealed each second. Set to 0 to show each entry instantly.
@export_range(0.0, 120.0, 1.0) var typewriter_characters_per_second: float = 36.0

@onready var background: TextureRect = $Background
@onready var dialogue_label: Label = $DialoguePanel/Margin/Content/Dialogue
@onready var continue_label: Label = $DialoguePanel/Margin/Content/ContinuePrompt

var dialogue_text: String:
	get:
		return dialogue_label.text

var sequence_index: int = 0
var dialogue_index: int = 0
var _input_ready: bool = false
var _finished: bool = false
var _direct_test: bool = false
var _launch_gameplay_on_finish: bool = true
var _full_dialogue_text: String = ""
var _visible_character_count: int = 0
var _typewriter_progress: float = 0.0

func _ready() -> void:
	# Directly running the scene in-editor should preview the story only.
	_launch_gameplay_on_finish = get_tree().current_scene == self and get_tree().root.has_node("GameData")
	# A fresh scene prevents the level-select click from advancing dialogue.
	_input_ready = false
	call_deferred("_enable_story_input")
	if story_data == null or story_data.sequences.is_empty():
		push_error("StoryScene: assign a StoryCollection with at least one sequence.")
		return
	_show_current_entry()

func _process(delta: float) -> void:
	if _finished or _full_dialogue_text.is_empty():
		return
	if _visible_character_count >= _full_dialogue_text.length():
		return
	if typewriter_characters_per_second <= 0.0:
		return
	_typewriter_progress += typewriter_characters_per_second * delta
	var characters_to_add: int = int(_typewriter_progress)
	if characters_to_add <= 0:
		return
	_typewriter_progress -= characters_to_add
	_visible_character_count = mini(
			_visible_character_count + characters_to_add,
			_full_dialogue_text.length()
	)
	dialogue_label.visible_characters = _visible_character_count
	if _visible_character_count >= _full_dialogue_text.length():
		continue_label.text = "CLICK OR PRESS ENTER TO CONTINUE  ›"

func _enable_story_input() -> void:
	await get_tree().process_frame
	if is_inside_tree():
		_input_ready = true

func _input(event: InputEvent) -> void:
	if not _input_ready or _finished:
		return
	var advance: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	advance = advance or (event.is_action_pressed("ui_accept") and not event.is_echo())
	if not advance:
		return
	get_viewport().set_input_as_handled()
	# The first input only reveals a line. A later input advances to the next one.
	if _visible_character_count < _full_dialogue_text.length():
		_reveal_dialogue()
		return
	_advance_dialogue()

func _reveal_dialogue() -> void:
	_visible_character_count = _full_dialogue_text.length()
	_typewriter_progress = 0.0
	dialogue_label.visible_characters = _visible_character_count
	continue_label.text = "CLICK OR PRESS ENTER TO CONTINUE  ›"

func _show_current_entry() -> void:
	if story_data == null or sequence_index >= story_data.sequences.size():
		_finish_story()
		return
	var sequence: StorySequence = story_data.sequences[sequence_index]
	if sequence == null or sequence.dialogue_entries.is_empty():
		sequence_index += 1
		dialogue_index = 0
		_show_current_entry()
		return
	background.texture = sequence.background
	dialogue_index = clampi(dialogue_index, 0, sequence.dialogue_entries.size() - 1)
	_full_dialogue_text = sequence.dialogue_entries[dialogue_index]
	dialogue_label.text = _full_dialogue_text
	_visible_character_count = 0
	_typewriter_progress = 0.0
	dialogue_label.visible_characters = 0
	continue_label.text = "CLICK TO REVEAL TEXT"
	if typewriter_characters_per_second <= 0.0:
		_reveal_dialogue()

func _advance_dialogue() -> void:
	if _finished or story_data == null or sequence_index >= story_data.sequences.size():
		return
	var sequence: StorySequence = story_data.sequences[sequence_index]
	if dialogue_index + 1 < sequence.dialogue_entries.size():
		dialogue_index += 1
		_show_current_entry()
		return
	sequence_index += 1
	dialogue_index = 0
	if sequence_index < story_data.sequences.size():
		_show_current_entry()
	else:
		_finish_story()

func _finish_story() -> void:
	if _finished:
		return
	_finished = true
	_input_ready = false
	story_completed.emit()
	if _direct_test or not _launch_gameplay_on_finish:
		return
	# The title flow chooses Level 1 before opening this reusable presentation.
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)

func start_direct_test(sequence_data: StoryCollection) -> void:
	story_data = sequence_data
	_direct_test = true
	_launch_gameplay_on_finish = false
	sequence_index = 0
	dialogue_index = 0
	_finished = false
	_show_current_entry()
