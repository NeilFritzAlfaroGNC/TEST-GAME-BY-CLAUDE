extends Panel

const TOKEN_SLOT := preload("res://Shared/scenes/character_codex/CodexTokenSlot.tscn")
const ANIMATION_SLOT := preload("res://Shared/scenes/character_codex/AnimationTokenSlot.tscn")
const TOKEN_UNLOCKS := preload("res://scripts/codex/codex_token_unlocks.gd")
const CATEGORIES := [&"healthy_foods", &"junk_enemies", &"sick_child"]
const PAGE_SIZE := 12

@export var database: CodexDatabase
@export var codex_entries: Array[CodexTokenEntry] = []

@onready var scroll: ScrollContainer = $Details/Scroll
@onready var title: Label = $Details/Scroll/Content/Name
@onready var animation_title: Label = $Details/Scroll/Content.get_node_or_null("AnimationTitle") as Label
@onready var art: TextureRect = $Details/Scroll/Content/Art
@onready var preview: AnimatedSprite2D = $Details/Scroll/Content/Art/Preview
@onready var stats: Label = $Details/Scroll/Content/Stats
@onready var details: Label = $Details/Scroll/Content/Text
@onready var animations: VBoxContainer = $Details/Scroll/Content/Animations
var _category := 0
var _page := 0
var _slots: Array[CodexEntrySlot] = []


var _animation_arrows: HBoxContainer
var _unlocked_animations: Array[CodexAnimationData] = []
var _unlocked_animation_buttons: Array[Button] = []
var _animation_index := -1
var _animation_entry_name := ""


func _build_animation_arrows() -> void:
	_animation_arrows = HBoxContainer.new()
	_animation_arrows.name = "AnimationArrows"
	_animation_arrows.alignment = BoxContainer.ALIGNMENT_CENTER
	_animation_arrows.add_theme_constant_override("separation", 16)
	art.get_parent().add_child(_animation_arrows)
	art.get_parent().move_child(_animation_arrows, art.get_index())
	_animation_arrows.hide()
	for direction in [-1, 1]:
		var button := Button.new()
		button.text = "‹" if direction < 0 else "›"
		button.custom_minimum_size = Vector2(36, 26)
		button.tooltip_text = "Previous animation" if direction < 0 else "Next animation"
		button.pressed.connect(_cycle_animation.bind(direction))
		_animation_arrows.add_child(button)


func _cycle_animation(direction: int) -> void:
	if _unlocked_animations.is_empty():
		return
	var index := _animation_index + direction
	if _animation_index < 0:
		index = 0 if direction > 0 else _unlocked_animations.size() - 1
	_select_animation(posmod(index, _unlocked_animations.size()))


func _select_animation(index: int) -> void:
	_animation_index = index
	_unlocked_animation_buttons[index].set_pressed_no_signal(true)
	_play_animation(_unlocked_animations[index], _animation_entry_name)


func _ready() -> void:
	_build_animation_arrows()
	for child in $Tabs.get_children():
		var tab := child as Button
		tab.pressed.connect(_set_category.bind(tab.get_index()))
	$Previous.pressed.connect(_move_page.bind(-1))
	$Next.pressed.connect(_move_page.bind(1))
	_set_category(0)


func _set_category(index: int) -> void:
	_category = index
	_page = 0
	for child in $Tabs.get_children():
		var tab := child as Button
		tab.set_pressed_no_signal(tab.get_index() == index)
	_build_slots()
	_refresh_page()


func _build_slots() -> void:
	for slot in _slots:
		$Grid.remove_child(slot)
		slot.queue_free()
	_slots.clear()
	var group := ButtonGroup.new()
	for i in range(PAGE_SIZE):
		var slot := TOKEN_SLOT.instantiate() as CodexEntrySlot
		slot.button_group = group
		$Grid.add_child(slot)
		slot.slot_selected.connect(_show_entry)
		_slots.append(slot)


func _move_page(direction: int) -> void:
	_page += direction
	_refresh_page()


func _refresh_page() -> void:
	var entries: Array[CodexEntryData] = []
	if database != null:
		entries = database.entries_in_category(CATEGORIES[_category])
	var config := TOKEN_UNLOCKS.load_unlocks()
	if CATEGORIES[_category] != &"junk_enemies":
		for i in range(entries.size()):
			if entries[i] is CodexTokenEntry:
				var entry := entries[i].duplicate() as CodexEntryData
				entry.unlocked = TOKEN_UNLOCKS.is_unlocked(config, entry.id, TOKEN_UNLOCKS.INFO)
				entries[i] = entry
	elif CATEGORIES[_category] == &"junk_enemies":
		for token: CodexTokenEntry in codex_entries:
			if token == null or token.category != CATEGORIES[_category]:
				continue
			var entry := token.duplicate() as CodexEntryData
			entry.unlocked = TOKEN_UNLOCKS.is_unlocked(config, entry.id, TOKEN_UNLOCKS.INFO)
			entries.append(entry)
	var last := maxi(0, ceili(float(entries.size()) / PAGE_SIZE) - 1)
	_page = clampi(_page, 0, last)
	$Previous.disabled = _page == 0
	$Next.disabled = _page == last
	$Page.text = "%d / %d" % [_page + 1, last + 1]
	for i in range(PAGE_SIZE):
		var index := _page * PAGE_SIZE + i
		var slot := _slots[i]
		slot.set_pressed_no_signal(false)
		if index < entries.size():
			slot.set_entry(entries[index])
		else:
			slot.set_empty()
	_reset_details()
	details.text = "No entries in this category yet." if entries.is_empty() else "Select an entry."



func _reset_details() -> void:
	_animation_arrows.hide()
	_unlocked_animations.clear()
	_unlocked_animation_buttons.clear()
	_animation_index = -1
	scroll.scroll_vertical = 0
	title.text = ""
	if animation_title != null:
		animation_title.hide()
	stats.text = ""
	stats.hide()
	art.texture = null
	art.hide()
	preview.stop()
	preview.hide()
	for button in animations.get_children():
		animations.remove_child(button)
		button.queue_free()


func _show_entry(slot: CodexEntrySlot) -> void:
	var entry := slot.entry
	if entry == null:
		return
	_reset_details()
	title.text = entry.display_title() if entry.unlocked else "Undiscovered"
	var token := entry as CodexTokenEntry
	if not entry.unlocked:
		details.text = "Collect a blank token and win the battle to reveal it." if token != null and entry.category == &"junk_enemies" else "Undiscovered entry"
		if token != null and entry.category == &"healthy_foods":
			details.text = "Sort this food correctly and clear Level 2 to unlock it."
		elif token != null and entry.category == &"sick_child":
			details.text = "Collect a blank token and clear Level 3 to unlock this child."
		return

	art.texture = entry.large_image if entry.large_image != null else entry.icon
	art.visible = art.texture != null
	details.text = entry.display_description()
	if not entry.ability_description.is_empty():
		details.text += "\n\nAbility — " + entry.ability_description
	var lines := PackedStringArray()
	for stat: Dictionary in entry.visible_stat_rows():
		lines.append("%s  %s" % [stat["label"], stat["value"]])
	if token != null:
		_add_animations(token, TOKEN_UNLOCKS.load_unlocks())
	stats.text = "   ·   ".join(lines)
	stats.visible = not lines.is_empty()


func _add_animations(entry: CodexTokenEntry, config: ConfigFile) -> void:
	if entry.animations.is_empty():
		return
	var heading := Label.new()
	_animation_entry_name = entry.display_title()
	heading.text = "Animation Tokens"
	animations.add_child(heading)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	animations.add_child(row)
	var group := ButtonGroup.new()
	for animation in entry.animations:
		if animation == null:
			continue
		var button := ANIMATION_SLOT.instantiate() as Button
		button.button_group = group
		var icon := button.get_node("Icon") as TextureRect
		icon.texture = animation.token_icon if animation.token_icon != null else entry.icon
		var unlocked := TOKEN_UNLOCKS.is_unlocked(config, entry.id, animation.animation_name)
		var has_frames := animation.sprite_frames != null and animation.sprite_frames.has_animation(animation.animation_name)
		button.disabled = not unlocked or not has_frames
		if not unlocked:
			button.tooltip_text = "Sort this food correctly and clear Level 2" if entry.category == &"healthy_foods" else "Collect its token and win"
		elif not has_frames:
			button.tooltip_text = "%s · Animation unavailable" % animation.display_name
		else:
			button.tooltip_text = animation.display_name
		icon.visible = unlocked and icon.texture != null
		button.text = "?" if not unlocked else ""
		if not button.disabled:
			button.pressed.connect(_select_animation.bind(_unlocked_animations.size()))
			_unlocked_animations.append(animation)
			_unlocked_animation_buttons.append(button)
		row.add_child(button)
	_animation_arrows.visible = not _unlocked_animations.is_empty()


func _play_animation(animation: CodexAnimationData, entry_name: String) -> void:
	if animation.sprite_frames.get_frame_count(animation.animation_name) == 0:
		return
	var frame := animation.sprite_frames.get_frame_texture(animation.animation_name, 0)
	if frame == null:
		return
	var scale_factor := minf(100.0 / maxf(frame.get_width(), frame.get_height()), 1.0)
	art.texture = null
	art.show()
	preview.scale = Vector2.ONE * scale_factor
	preview.sprite_frames = animation.sprite_frames
	preview.show()
	preview.play(animation.animation_name)
	if animation_title != null:
		animation_title.text = "%s %s" % [entry_name, animation.display_name]
		animation_title.show()
	scroll.scroll_vertical = 0
