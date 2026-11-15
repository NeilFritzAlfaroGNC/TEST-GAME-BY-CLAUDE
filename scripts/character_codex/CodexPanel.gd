extends Panel

const SLOT := preload("res://scenes/codex/CodexEntrySlot.tscn")
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


func _ready() -> void:
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
	_build_slots(TOKEN_SLOT if CATEGORIES[_category] == &"junk_enemies" else SLOT)
	_refresh_page()


func _build_slots(scene: PackedScene) -> void:
	for slot in _slots:
		$Grid.remove_child(slot)
		slot.queue_free()
	_slots.clear()
	var group := ButtonGroup.new()
	for i in range(PAGE_SIZE):
		var slot := scene.instantiate() as CodexEntrySlot
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
	if CATEGORIES[_category] == &"junk_enemies":
		var config := TOKEN_UNLOCKS.load_unlocks()
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
		details.text = "Collect a blank token and win the battle to reveal it." if token != null else "Undiscovered entry"
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
			button.tooltip_text = "%s · Collect its token and win" % animation.display_name
		elif not has_frames:
			button.tooltip_text = "%s · Animation unavailable" % animation.display_name
		else:
			button.tooltip_text = animation.display_name
		icon.modulate.a = 0.4 if button.disabled else 1.0
		button.pressed.connect(_play_animation.bind(animation, entry.display_title()))
		row.add_child(button)


func _play_animation(animation: CodexAnimationData, enemy_name: String) -> void:
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
		animation_title.text = "%s %s" % [enemy_name, animation.display_name]
		animation_title.show()
	scroll.scroll_vertical = 0
