class_name CodexEntrySlot
extends Button
## One square button in the Codex grid. Codex.gd supplies an entry (or empty state)
## and listens to slot_selected to update the detail page.
##
## Three states, all driven by set_entry() / set_empty():
##   empty    - nothing assigned yet; disabled, neutral "?" placeholder
##   locked   - an entry exists but is not unlocked; shows "?" and hides its name
##   unlocked - shows the entry's icon (or "?" when it has no art yet) and name
##
## Selection: the slot is a toggle button sharing a ButtonGroup created by
## Codex.gd, so the "pressed" stylebox in this scene is the selected look and
## exactly one slot stays highlighted at a time.

## Emitted when the player activates this slot (mouse, touch or controller).
signal slot_selected(slot: CodexEntrySlot)

const UNKNOWN_TEXT := "?"
const HOVER_POP_TIME := 0.08

@onready var _icon: TextureRect = $Icon
@onready var _mark: Label = $LockedMark
@onready var _name_label: Label = $NameLabel

## The entry this slot shows, or null for an empty slot.
@export var show_entry_name := true
var entry: CodexEntryData = null

func _ready() -> void:
	pressed.connect(_on_pressed)
	mouse_entered.connect(_pop.bind(1.05))
	mouse_exited.connect(_pop.bind(1.0))
	button_down.connect(_pop.bind(0.96))
	button_up.connect(_pop.bind(1.05))
	resized.connect(_recenter_pivot)
	_recenter_pivot()
	_refresh()

## Show a real (locked or unlocked) entry.
func set_entry(new_entry: CodexEntryData) -> void:
	entry = new_entry
	disabled = entry == null
	_refresh()

## Show the neutral "nothing here yet" placeholder.
func set_empty() -> void:
	entry = null
	disabled = true
	_refresh()

func _refresh() -> void:
	# set_entry()/set_empty() can run before this node is ready (the grid builds
	# slots and configures them within the same frame), in which case the
	# @onready children below are still null. _ready() refreshes again.
	if _icon == null:
		return
	var unlocked := entry != null and entry.unlocked
	var icon_texture: Texture2D = entry.icon if unlocked else null
	_icon.texture = icon_texture
	_icon.visible = icon_texture != null
	# No art yet (or still locked) falls back to the neutral mark.
	_mark.visible = icon_texture == null
	_mark.text = UNKNOWN_TEXT
	var entry_name := entry.display_name if unlocked else ""
	_name_label.text = entry_name
	_name_label.visible = show_entry_name and not entry_name.is_empty()
	tooltip_text = entry_name if show_entry_name else ""

func _on_pressed() -> void:
	slot_selected.emit(self)

## Small scale pop used for hover / press feedback.
func _pop(target: float) -> void:
	if disabled:
		return
	_recenter_pivot()
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(target, target), HOVER_POP_TIME)

func _recenter_pivot() -> void:
	pivot_offset = size * 0.5
