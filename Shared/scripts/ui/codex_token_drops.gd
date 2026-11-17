extends CanvasLayer

const TOKENS := preload("res://scripts/codex/codex_token_unlocks.gd")
enum PickupMode { MANUAL, AUTOMATIC, ON_VICTORY }

@export var token_pickup_mode: PickupMode = PickupMode.AUTOMATIC
@export_range(0.0, 30.0, 0.1, "or_greater", "suffix:s") var automatic_pickup_delay := 1.0
@export_range(0.0, 1.0, 0.01) var drop_chance := 0.25

var _drops: Dictionary = {}
var _pending: Array[StringName] = []


func offer(id: StringName, at: Vector2) -> void:
	if id == &"" or randf() >= drop_chance:
		return
	var reserved: Array[StringName] = _pending.duplicate()
	for key: StringName in _drops.values():
		reserved.append(key)
	var reward := TOKENS.reserve_reward(id, reserved)
	if reward == &"":
		return
	var pickup := Button.new()
	pickup.text = "?"
	pickup.tooltip_text = "Collect token"
	pickup.custom_minimum_size = Vector2(32, 32)
	var rim := StyleBoxFlat.new()
	rim.bg_color = Color("#80634b")
	rim.border_color = Color("#ffe3a0")
	rim.set_border_width_all(2)
	rim.set_corner_radius_all(16)
	pickup.add_theme_stylebox_override("normal", rim)
	var hover := rim.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#ab8157")
	pickup.add_theme_stylebox_override("hover", hover)
	add_child(pickup)
	var bounds := get_viewport().get_visible_rect()
	pickup.position = (at - Vector2(16, 38)).clamp(bounds.position, bounds.end - Vector2(32, 32))
	_drops[pickup] = reward
	pickup.pressed.connect(_collect.bind(pickup))
	if token_pickup_mode == PickupMode.AUTOMATIC:
		var pickup_ref: WeakRef = weakref(pickup)
		get_tree().create_timer(automatic_pickup_delay, false).timeout.connect(func():
			var button := pickup_ref.get_ref() as Button
			if button != null:
				_collect(button)
		)


func _collect(pickup: Button) -> void:
	if not _drops.has(pickup):
		return
	_pending.append(_drops[pickup])
	_drops.erase(pickup)
	pickup.queue_free()


func discard() -> void:
	for pickup: Button in _drops:
		pickup.queue_free()
	_drops.clear()
	_pending.clear()


func finish_victory() -> PackedStringArray:
	if token_pickup_mode == PickupMode.ON_VICTORY:
		for reward: StringName in _drops.values():
			_pending.append(reward)
	else:
		var remaining := automatic_pickup_delay if token_pickup_mode == PickupMode.AUTOMATIC else 4.0
		while not _drops.is_empty() and remaining > 0.0:
			await get_tree().process_frame
			if not get_tree().paused:
				remaining -= get_process_delta_time()
		if token_pickup_mode == PickupMode.AUTOMATIC:
			for reward: StringName in _drops.values():
				_pending.append(reward)
	var rewards := TOKENS.commit_victory(_pending)
	discard()
	return rewards
