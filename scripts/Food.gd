extends Area2D
## A conveyor-belt food. Main spawns these on the left; they ride the belt to
## the right. Drag one onto the Hero to feed him. Once visible it lasts LIFETIME
## seconds if left untouched, then blinks and disappears. Picking it up PAUSES
## the clock and the blink; releasing it resumes the countdown.

const LIFETIME := 3.0        # max seconds a food stays on the belt if untouched
const BLINK_AT := 2.0        # start blinking this many seconds in (warns it's leaving)
const BELT_SPEED := 130.0    # left -> right belt speed (px/s)
const SPAWN_X := -90.0       # just off the left edge
const RETURN_TIME := 0.22    # seconds to glide back to the grab slot after a non-feeding drop
# The belt lane Y comes from Layout.m["belt_y"] (safe-area aware: it clears the
# OS gesture bar / home indicator on notched devices) -- see _belt_y() below.

@export var food_group: String = "Go"

var dragging: bool = false
var returning: bool = false     # gliding back to its grab slot (belt-ride + layout skip it)
var age: float = 0.0            # lifetime clock; runs while visible on the belt, PAUSED while held
var _activated: bool = false    # true once the food first reached an on-screen slot
var target_x: float = SPAWN_X   # stack slot assigned by Main; the food slides toward it
var _return_tween: Tween
var _sprite: Sprite2D           # optional food art (assets/food/<name>.png); hidden if none

# Cache of loaded food textures (misses stored as null) keyed by name slug, so
# foods spawning every second don't re-hit the disk. Shared across all foods.
static var _tex_cache: Dictionary = {}

@onready var rect: ColorRect = $ColorRect
@onready var label: Label = $Label

func _ready() -> void:
	input_pickable = true
	input_event.connect(_on_input_event)
	position = Vector2(SPAWN_X, _belt_y())
	# Art layer over the gray box: shows a sprite when art exists, else stays hidden.
	_sprite = Sprite2D.new()
	_sprite.z_index = 1
	_sprite.visible = false
	add_child(_sprite)
	label.z_index = 2   # keep the food name readable above any sprite

# Layout owns the belt lane's Y; read fresh each time rather than caching, since
# Layout.m can be refreshed on a resize.
func _belt_y() -> float:
	return Layout.m["belt_y"]

# Assign this food a group, a random real name, and -- only on Easy -- the
# group colour. Medium and Hard render neutral so the player must read the name
# instead of matching a swatch. This is the single change that stops the game
# being winnable without reading.
const NEUTRAL := Color(0.86, 0.84, 0.78)

func set_food(group: String, coloured: bool) -> void:
	food_group = group
	var food_name: String = GameData.random_food(group)
	label.text = food_name
	rect.color = GameData.group_color(group) if coloured else NEUTRAL
	_apply_sprite(food_name)

# Show assets/food/<name>.png over the colored box if that art exists; otherwise
# leave the gray box as-is. A missing or wrong-type file is ignored (never a
# crash) — the safe hook for dropping in food sprites during the art phase.
func _apply_sprite(food_name: String) -> void:
	if _sprite == null:
		return
	var tex = _load_food_texture(food_name.to_lower().replace(" ", "_"))
	if tex != null:
		_sprite.texture = tex
		var sz: Vector2 = tex.get_size()
		if sz.x > 0.0 and sz.y > 0.0:
			_sprite.scale = Vector2(130.0 / sz.x, 70.0 / sz.y)   # fit inside the 150x90 box
		_sprite.visible = true
	else:
		_sprite.texture = null
		_sprite.visible = false

# Load + cache assets/food/<slug>.png. Returns a Texture2D, or null if the file
# is missing or isn't a texture. Misses are cached too, so we only check once.
static func _load_food_texture(slug: String):
	if _tex_cache.has(slug):
		return _tex_cache[slug]
	var tex = null
	var path := "res://assets/food/%s.png" % slug
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is Texture2D:
			tex = res
	_tex_cache[slug] = tex
	return tex

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# One food at a time: if another food is already held (foods can briefly
		# overlap on the belt), ignore this click so a single press can't pick up
		# a whole stack at once.
		for sib in get_parent().get_children():
			if sib != self and is_instance_valid(sib) and sib.dragging:
				return
		# Re-grabbed mid-return: cancel the glide-back and follow the mouse.
		_cancel_return()
		dragging = true
		z_index = 10          # draw above other foods while dragging
		modulate.a = 1.0      # cancel any mid-blink transparency

func _process(delta: float) -> void:
	if dragging:
		# Held: the lifetime clock AND the blink pause — a held food never expires
		# in the player's hand. Just follow the mouse (or finger on Android).
		global_position = get_global_mouse_position()
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_drop()
		return
	# Not held — run the lifetime clock once it has started. This also ticks while
	# a released food glides back to its slot, so the countdown resumes the moment
	# you let go.
	if _activated:
		age += delta
		if age >= LIFETIME:
			queue_free()
			return
		_apply_blink()
	if returning:
		# A tween is gliding it back to its grab slot; leave its position to it.
		return
	# Slide toward the stack slot Main assigned; stop once we reach it so foods
	# pile up instead of running off the right of the screen.
	var step := BELT_SPEED * delta
	if position.x < target_x:
		position.x = min(position.x + step, target_x)
	elif position.x > target_x:
		position.x = max(position.x - step, target_x)
	# Start the clock once the food has ARRIVED at an on-screen slot, so the whole
	# countdown + blink + disappearance happen where the player can see them (foods
	# enter from off the left edge and slide in first).
	if not _activated and position.x >= 0.0 and is_equal_approx(position.x, target_x):
		_activated = true

# Blink during the final stretch (age >= BLINK_AT) so the player sees it leaving.
func _apply_blink() -> void:
	if age >= BLINK_AT:
		modulate.a = 1.0 if (int(age * 8.0) % 2 == 0) else 0.25
	else:
		modulate.a = 1.0

# Return a held food to the belt WITHOUT the drop check (used when the game
# pauses mid-drag: a mouse release during the pause would otherwise complete
# the drop — and could feed the Hero — the moment the game resumes).
func cancel_drag() -> void:
	if not dragging:
		return
	dragging = false
	z_index = 0
	modulate.a = 1.0
	position.y = _belt_y()

func _drop() -> void:
	dragging = false
	z_index = 0
	modulate.a = 1.0
	var main = get_tree().current_scene
	if main == null:
		queue_free()
		return
	var hero = main.get_node_or_null("Hero")
	# If dropped on the Hero and it was actually used, it's consumed (removed).
	if hero != null and overlaps_area(hero):
		if main.food_dropped_on_hero(self):
			queue_free()
			return
	# Not consumed — either dropped away from the Hero, OR a WRONG food the Hero
	# rejected (food_dropped_on_hero returned false). Either way it glides smoothly
	# back to the exact slot it was grabbed from (never the start/back of the belt).
	# The slot stayed reserved while the food was held — BeltManager._layout ranks
	# it by target_x — so it drops right back into place with no reshuffle.
	returning = true
	_return_tween = create_tween()
	_return_tween.tween_property(self, "position", Vector2(target_x, _belt_y()), RETURN_TIME)
	_return_tween.tween_callback(func(): returning = false)

# Stop an in-progress glide-back (e.g. the food was grabbed again mid-return).
func _cancel_return() -> void:
	if _return_tween != null and _return_tween.is_valid():
		_return_tween.kill()
	returning = false
