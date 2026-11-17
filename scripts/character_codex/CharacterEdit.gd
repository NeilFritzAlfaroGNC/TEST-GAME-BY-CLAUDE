extends Panel

const EQUIPMENT := preload("res://scripts/character_codex/character_equipment.gd")

@export_file("*.tscn") var return_scene_path: String
@onready var preview: AnimatedSprite2D = $Preview

var _entries: Array[CodexTokenEntry] = []
var _character := -1
var _equipped: StringName
var _picker: PopupPanel
var _picker_list: ItemList


func _ready() -> void:
	_entries = EQUIPMENT.unlocked_characters()
	_equipped = EQUIPMENT.load_id()
	for i in range(_entries.size()):
		if _entries[i].id == _equipped:
			_character = i
			break
	if _character == -1:
		_equipped = &""
	$Previous.pressed.connect(_move_character.bind(-1))
	$Next.pressed.connect(_move_character.bind(1))
	$Select.pressed.connect(_open_picker)
	$Back.pressed.connect(_go_back)
	_show_character()


func _move_character(direction: int) -> void:
	if not _entries.is_empty():
		_character = posmod(_character + 1 + direction, _entries.size() + 1) - 1
		_show_character()


func _show_character() -> void:
	preview.stop()
	var entry: CodexTokenEntry = _entries[_character] if _character >= 0 else null
	preview.visible = entry != null and EQUIPMENT.apply_preview(preview, entry, Vector2(48, 72))
	$Question.visible = not preview.visible
	$Name.text = entry.display_name if entry != null else "No character equipped"
	$Previous.disabled = _entries.is_empty()
	$Next.disabled = _entries.is_empty()
	$Select.text = "Equip / Unequip"
	var selected_id: StringName = entry.id if entry != null else &""
	if entry == null:
		$Status.text = "Unlock an Info token" if _entries.is_empty() else ""
	else:
		$Status.text = "Equipped" if selected_id == _equipped else ""


func _open_picker() -> void:
	if _picker == null:
		_picker = PopupPanel.new()
		_picker.title = "Equip Character"
		add_child(_picker)
		var layout := VBoxContainer.new()
		layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_picker.add_child(layout)
		var heading := Label.new()
		heading.text = "Equip Character"
		heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		layout.add_child(heading)
		_picker_list = ItemList.new()
		_picker_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_picker_list.fixed_icon_size = Vector2i(34, 34)
		_picker_list.item_selected.connect(_equip_picker_item)
		layout.add_child(_picker_list)
		var close := Button.new()
		close.text = "Close"
		close.pressed.connect(_picker.hide)
		layout.add_child(close)
	_picker_list.clear()
	_picker_list.add_item("Unequip" if _equipped != &"" else "No character equipped")
	_picker_list.set_item_disabled(0, _equipped == &"")
	for entry in _entries:
		var index := _picker_list.add_item(entry.display_name, entry.icon)
		if entry.id == _equipped:
			_picker_list.select(index)
	_picker.popup_centered(Vector2i(360, 300))


func _equip_picker_item(index: int) -> void:
	var id: StringName = _entries[index - 1].id if index > 0 else &""
	if EQUIPMENT.save_id(id) != OK:
		$Status.text = "Could not save selection."
		return
	_character = index - 1
	_equipped = id
	_picker.hide()
	_show_character()


func _go_back() -> void:
	var result := get_tree().change_scene_to_file(return_scene_path)
	if result != OK:
		$Status.text = "Could not open the level map."


