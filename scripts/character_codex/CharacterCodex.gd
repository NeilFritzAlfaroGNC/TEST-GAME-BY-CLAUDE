extends Control

const SLOT := preload("res://scenes/codex/CodexEntrySlot.tscn")
const CATEGORIES := [&"healthy_foods", &"junk_enemies", &"sick_child"]
const TOKEN_SLOT := preload("res://scenes/codex/TokenSlot.tscn")
const TOKEN_UNLOCKS := preload("res://scripts/codex/codex_token_unlocks.gd")
const ENEMY_TOKENS := [
	preload("res://data/tokens/soda_enemy_token.tres"),
	preload("res://data/tokens/donut_enemy_token.tres"),
]
const PAGE_SIZE := 12
const SAVE_PATH := "user://character_codex.cfg"

@export_file("*.tscn") var return_scene_path: String
@export var character_animations: Array[SpriteFrames]
@export var database: CodexDatabase

@onready var preview: AnimatedSprite2D = $Hero/Preview
@onready var details: Label = $Codex/Details/Scroll/Text
@onready var art: TextureRect = $Codex/Details/Art
var _character := 0
var _saved := -1
var _category := 0
var _page := 0
var _slots: Array[CodexEntrySlot] = []


func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		_saved = int(config.get_value("character", "index", -1))
	_character = clampi(_saved, 0, maxi(0, character_animations.size() - 1))
	for child in $Codex/Tabs.get_children():
		var tab := child as Button
		tab.pressed.connect(_set_category.bind(tab.get_index()))
	$Hero/Previous.pressed.connect(_move_character.bind(-1))
	$Hero/Next.pressed.connect(_move_character.bind(1))
	$Hero/Select.pressed.connect(_save_character)
	$Hero/Back.pressed.connect(_go_back)
	$Codex/Previous.pressed.connect(_move_page.bind(-1))
	$Codex/Next.pressed.connect(_move_page.bind(1))
	_show_character()
	_set_category(0)


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
	$Hero/Name.text = "Character %d" % (_character + 1) if frames != null else "No character assigned"
	$Hero/Previous.disabled = character_animations.size() < 2
	$Hero/Next.disabled = character_animations.size() < 2
	$Hero/Select.disabled = frames == null or _character == _saved
	$Hero/Status.text = "Selected" if frames != null and _character == _saved else ""


func _save_character() -> void:
	var config := ConfigFile.new()
	config.set_value("character", "index", _character)
	if config.save(SAVE_PATH) == OK:
		_saved = _character
		_show_character()
	else:
		$Hero/Status.text = "Could not save selection."


func _go_back() -> void:
	var result := get_tree().change_scene_to_file(return_scene_path)
	if result != OK:
		$Hero/Status.text = "Could not open the level map."


func _set_category(index: int) -> void:
	_category = index
	_page = 0
	for child in $Codex/Tabs.get_children():
		var tab := child as Button
		tab.set_pressed_no_signal(tab.get_index() == index)
	_build_slots(TOKEN_SLOT if CATEGORIES[_category] == &"junk_enemies" else SLOT)
	_refresh_page()


func _build_slots(scene: PackedScene) -> void:
	for slot in _slots:
		$Codex/Grid.remove_child(slot)
		slot.queue_free()
	_slots.clear()
	var group := ButtonGroup.new()
	for i in range(PAGE_SIZE):
		var slot := scene.instantiate() as CodexEntrySlot
		slot.button_group = group
		$Codex/Grid.add_child(slot)
		slot.slot_selected.connect(_show_entry)
		_slots.append(slot)


func _move_page(direction: int) -> void:
	_page += direction
	_refresh_page()


func _refresh_page() -> void:
	var entries: Array[CodexEntryData] = []
	if database != null:
		entries = database.entries_in_category(CATEGORIES[_category])
	if CATEGORIES[_category] == &"junk_enemies":
		var config := TOKEN_UNLOCKS.load_unlocks()
		for token: CodexEntryData in ENEMY_TOKENS:
			var entry := token.duplicate() as CodexEntryData
			entry.unlocked = config.get_value(TOKEN_UNLOCKS.SECTION, entry.id, false)
			entries.append(entry)
	var last := maxi(0, ceili(float(entries.size()) / PAGE_SIZE) - 1)
	_page = clampi(_page, 0, last)
	$Codex/Previous.disabled = _page == 0
	$Codex/Next.disabled = _page == last
	$Codex/Page.text = "%d / %d" % [_page + 1, last + 1]
	for i in range(PAGE_SIZE):
		var index := _page * PAGE_SIZE + i
		var slot := _slots[i]
		slot.set_pressed_no_signal(false)
		if index < entries.size():
			slot.set_entry(entries[index])
		else:
			slot.set_empty()
	art.texture = null
	details.text = "No entries in this category yet." if entries.is_empty() else "Select an entry."


func _show_entry(slot: CodexEntrySlot) -> void:
	var entry := slot.entry
	if entry == null:
		return
	art.texture = entry.large_image if entry.unlocked else null
	var lines := PackedStringArray([entry.display_title()])
	if entry.unlocked:
		lines.append(entry.display_description())
		if not entry.ability_description.is_empty():
			lines.append("Ability — " + entry.ability_description)
		for stat: Dictionary in entry.visible_stat_rows():
			lines.append("%s  %s" % [stat["label"], stat["value"]])
	else:
		lines.append("Collect a blank token and win the battle to reveal it." if TOKEN_UNLOCKS.NAMES.has(entry.id) else "Undiscovered entry")
	details.text = "\n\n".join(lines)
