extends Control

# =====================================================
# SCENE SETTINGS
# =====================================================

const NEXT_SCENE := "res://scenes/Battle Scene/battle_scene_cafeteria.tscn"

# Each page contains one image and its own dialogue entries.
@export var story_pages: Array[StoryPage] = []

# Typewriter speed.
@export var characters_per_second: float = 35.0

# Background transition duration.
@export var fade_duration: float = 0.20


# =====================================================
# NODE REFERENCES
# =====================================================

@onready var background: TextureRect = $Background
@onready var dialogue_panel: Panel = $DialoguePanel
@onready var speaker_label: Label = $DialoguePanel/SpeakerName
@onready var dialogue_text: RichTextLabel = $DialoguePanel/DialogueText


# =====================================================
# STORY VARIABLES
# =====================================================

var current_page: int = 0
var current_dialogue: int = 0

var current_image_page: int = -1

var is_typing: bool = false
var is_transitioning: bool = false

var typing_progress: float = 0.0

var continue_label: Label
var page_tween: Tween


# =====================================================
# INITIALIZATION
# =====================================================

func _ready() -> void:
	print("CAFETERIA STORY SCRIPT IS RUNNING")

	if story_pages.is_empty():
		push_error("Cafeteria Story: No story pages assigned.")
		return

	# Validate every page and its dialogue entries.
	for page_index in range(story_pages.size()):
		var page := story_pages[page_index]

		if page == null:
			push_error("Story Page %d is empty." % (page_index + 1))
			return

		if page.story_image == null:
			push_error("Story Page %d has no image assigned." % (page_index + 1))
			return

		if page.dialogues.is_empty():
			push_error("Story Page %d has no dialogue entries." % (page_index + 1))
			return

		for dialogue_index in range(page.dialogues.size()):
			var entry := page.dialogues[dialogue_index]

			if entry == null:
				push_error(
					"Page %d, Dialogue %d is empty."
					% [page_index + 1, dialogue_index + 1]
				)
				return

			if entry.speaker_name.strip_edges().is_empty():
				push_error(
					"Missing speaker name on Page %d, Dialogue %d."
					% [page_index + 1, dialogue_index + 1]
				)
				return

			if entry.dialogue_line.strip_edges().is_empty():
				push_error(
					"Missing dialogue line on Page %d, Dialogue %d."
					% [page_index + 1, dialogue_index + 1]
				)
				return

	# Keep the dialogue panel visible.
	dialogue_panel.visible = true
	dialogue_panel.modulate = Color.WHITE

	background.modulate = Color.WHITE

	# Create continue indicator.
	continue_label = Label.new()
	continue_label.name = "ContinueIndicator"
	continue_label.text = "TAP TO CONTINUE"
	continue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	continue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	continue_label.visible = false
	continue_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	dialogue_panel.add_child(continue_label)

	continue_label.anchor_left = 1.0
	continue_label.anchor_right = 1.0
	continue_label.anchor_top = 1.0
	continue_label.anchor_bottom = 1.0

	continue_label.offset_left = -190.0
	continue_label.offset_right = -15.0
	continue_label.offset_top = -35.0
	continue_label.offset_bottom = -5.0

	# Start the story.
	show_dialogue(0, 0)


# =====================================================
# TYPEWRITER EFFECT
# =====================================================

func _process(delta: float) -> void:
	if not is_typing:
		return

	typing_progress += characters_per_second * delta

	dialogue_text.visible_characters = int(typing_progress)

	if dialogue_text.visible_characters >= dialogue_text.get_total_character_count():
		finish_typing()


# =====================================================
# MOUSE, TOUCH AND KEYBOARD INPUT
# =====================================================

func _input(event: InputEvent) -> void:
	if is_transitioning or story_pages.is_empty():
		return

	var advance_pressed := false

	# Mobile touchscreen.
	if OS.has_feature("mobile"):
		if event is InputEventScreenTouch and event.pressed:
			advance_pressed = true

	# Desktop mouse.
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			advance_pressed = true

	# Spacebar or Enter.
	if event.is_action_pressed("ui_accept"):
		advance_pressed = true

	if advance_pressed:
		advance_story()


# =====================================================
# SHOW DIALOGUE
# =====================================================

func show_dialogue(page_index: int, dialogue_index: int) -> void:
	if is_transitioning:
		return

	if page_index < 0 or page_index >= story_pages.size():
		return

	var page := story_pages[page_index]

	if dialogue_index < 0 or dialogue_index >= page.dialogues.size():
		return

	current_page = page_index
	current_dialogue = dialogue_index

	# Same page: only update the speaker and dialogue.
	# The background image stays unchanged.
	if current_image_page == page_index:
		_set_dialogue_content()
		_start_dialogue()
		return

	# A new page means a new background image.
	is_transitioning = true

	if continue_label != null:
		continue_label.visible = false

	if page_tween != null and page_tween.is_running():
		page_tween.kill()

	# First image: fade in without fading out first.
	if current_image_page == -1:
		background.texture = page.story_image
		current_image_page = page_index

		_set_dialogue_content()
		background.modulate.a = 0.0

		page_tween = create_tween()

		page_tween.tween_property(
			background,
			"modulate:a",
			1.0,
			fade_duration
		)

		page_tween.tween_callback(_start_dialogue)
		return

	# Fade out the previous image.
	page_tween = create_tween()

	page_tween.tween_property(
		background,
		"modulate:a",
		0.0,
		fade_duration
	)

	# Change the image and dialogue.
	page_tween.tween_callback(func():
		background.texture = page.story_image
		current_image_page = page_index
		_set_dialogue_content()
	)

	# Fade in the new image.
	page_tween.tween_property(
		background,
		"modulate:a",
		1.0,
		fade_duration
	)

	page_tween.tween_callback(_start_dialogue)


# =====================================================
# SET SPEAKER AND DIALOGUE CONTENT
# =====================================================

func _set_dialogue_content() -> void:
	var entry := story_pages[current_page].dialogues[current_dialogue]

	speaker_label.text = entry.speaker_name

	dialogue_text.clear()
	dialogue_text.append_text(entry.dialogue_line)

	dialogue_text.visible = true
	dialogue_text.modulate = Color.WHITE
	dialogue_text.visible_characters = 0

	speaker_label.visible = true
	speaker_label.modulate = Color.WHITE

	dialogue_panel.visible = true
	dialogue_panel.modulate = Color.WHITE

	typing_progress = 0.0


# =====================================================
# START DIALOGUE
# =====================================================

func _start_dialogue() -> void:
	is_typing = true
	is_transitioning = false

	print("Page: ", current_page + 1)
	print("Dialogue: ", current_dialogue + 1)
	print("Speaker: ", speaker_label.text)
	print("Dialogue: ", dialogue_text.get_parsed_text())


# =====================================================
# FINISH TYPING
# =====================================================

func finish_typing() -> void:
	dialogue_text.visible_characters = -1
	is_typing = false

	if continue_label != null:
		continue_label.visible = true


# =====================================================
# ADVANCE STORY
# =====================================================

func advance_story() -> void:
	if is_transitioning or story_pages.is_empty():
		return

	# First click: reveal the complete dialogue.
	if is_typing:
		finish_typing()
		return

	var page := story_pages[current_page]

	# Next dialogue on the same image.
	if current_dialogue < page.dialogues.size() - 1:
		show_dialogue(current_page, current_dialogue + 1)
		return

	# Last dialogue on this page.
	# Move to the first dialogue of the next page.
	if current_page < story_pages.size() - 1:
		show_dialogue(current_page + 1, 0)
		return

	# Last dialogue of the entire story.
	_finish_story()


# =====================================================
# FINISH STORY
# =====================================================

func _finish_story() -> void:
	if is_transitioning:
		return

	is_transitioning = true
	is_typing = false

	if continue_label != null:
		continue_label.visible = false

	if page_tween != null and page_tween.is_running():
		page_tween.kill()

	page_tween = create_tween()

	page_tween.tween_property(
		background,
		"modulate:a",
		0.0,
		fade_duration
	)

	page_tween.tween_callback(_load_battle_scene)


# =====================================================
# LOAD CAFETERIA BATTLE
# =====================================================

func _load_battle_scene() -> void:
	var error := get_tree().change_scene_to_file(NEXT_SCENE)

	if error != OK:
		is_transitioning = false

		push_error(
			"Could not load cafeteria battle scene. Error: %s" % error
		)
