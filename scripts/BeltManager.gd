extends Node2D
## Conveyor-belt manager — child "Belt" of Main, created in code by Main._ready
## (no scene node needed; the belt was always drawn procedurally).
##
## Owns everything belt-side: the drawn belt + scrolling stripes, the timed
## random food batches, the right-anchored stacking layout, and the
## SOLVABILITY INVARIANT: `_ensure_needed()` runs every frame and instantly
## spawns a food of any needed group missing from the belt, so a level or
## boss fight can never become unwinnable. Never remove that guarantee.
##
## Food nodes themselves stay in Main's `$Foods` container (`_foods`) — other
## scripts (PauseMenu) iterate `main.foods_container`, so ownership must not
## move here.
##
## ADAPTIVE LAYOUT: the belt is fixed to the viewport bottom and food card centers
## compress within safe side insets when the viewport is too narrow for full spacing.
## Every position is measured from GameData.view_world_rect()
## (the slice of world space the camera is actually showing) instead of from the
## old fixed 1152-wide screen, so the belt spans the full width and sits flush
## with the bottom edge on any phone size/aspect ratio.
## Main calls setup(), then start()/stop(); the Callable supplied by Main tells
## this manager which categories must remain available for the current level.

const FOOD_SPAWN_INTERVAL := 1.0
const MAX_FOODS := 6
const BELT_STRIPE_SPEED := 130.0
const BELT_STRIPE_SPACING := 130.0
const STACK_SPACING := 145.0      # distance between stacked food centres
const STACK_RIGHT_INSET := 85.0   # front food centre, measured from the right edge
const ENTRY_INSET := 110.0        # a new food enters this far past the left edge
const FOOD_ROW_INSET := 72.0      # horizontal stack center inset from the belt edge
const MIN_SLOT_SPACING := 132.0   # slightly wider than the 130px food card
var active: bool = false

var _food_scene: PackedScene
var _foods: Node2D       # Main's $Foods container (holds the Food nodes)
var _needed: Callable    # -> Array of groups the belt must keep available
var _timer: Timer
var _stripes: Array = []
var _belt: ColorRect
var _edge: ColorRect

func _ready() -> void:
	_build_visuals()
	_timer = Timer.new()
	_timer.wait_time = FOOD_SPAWN_INTERVAL
	_timer.timeout.connect(_on_spawn_tick)
	add_child(_timer)

# Wire the belt to its Main-owned dependencies (called right after add_child).
func setup(food_scene: PackedScene, foods_container: Node2D, needed_groups: Callable) -> void:
	_food_scene = food_scene
	_foods = foods_container
	_needed = needed_groups

func start() -> void:
	active = true
	_timer.start()
	_seed()

func stop() -> void:
	active = false
	_timer.stop()

func clear_foods() -> void:
	for f in _foods.get_children():
		f.queue_free()

func _process(delta: float) -> void:
	# Re-fit the drawn belt to the visible area (cheap, and it self-corrects
	# after a resize or a viewport change on a different aspect ratio).
	_update_geometry()
	# Scroll the conveyor stripes (left -> right, wrapping) for a moving-belt look.
	# The wrap distance (10 x the stripe spacing) keeps the comb evenly spaced at
	# any width; the threshold tracks the right edge of the visible area.
	var right_edge: float = GameData.view_world_rect().end.x
	for stripe in _stripes:
		stripe.position.x += BELT_STRIPE_SPEED * delta
		if stripe.position.x > right_edge + 8.0:
			stripe.position.x -= BELT_STRIPE_SPACING * 10.0
	_layout()
	if active:
		_ensure_needed()

# === Solvability invariant ===
func has_group(g: String) -> bool:
	for f in _foods.get_children():
		if is_instance_valid(f) and not f.is_queued_for_deletion() and f.food_group == g:
			return true
	return false

# Instantly refill any needed group missing from the belt (just consumed,
# expired, or newly required by a wave/boss transition). Runs every frame and
# bypasses MAX_FOODS on purpose — a needed food must never be missing.
func _ensure_needed() -> void:
	for g in _needed.call():
		if not has_group(g):
			_make_food(g)

# A missing needed group first, otherwise random (used when seeding).
func _choose_group() -> String:
	for g in _needed.call():
		if not has_group(g):
			return g
	return GameData.random_group()

func _make_food(group: String):
	var f = _food_scene.instantiate()
	var x := _entry_x()   # spaced behind the current foods, computed before f is added
	_foods.add_child(f)
	f.set_food(group)
	f.position = Vector2(x, GameData.belt_y())
	f.target_x = x
	return f

# X for a food just entering the belt: off the left edge of the visible area, and
# always at least one slot-spacing behind the current left-most riding food, so an
# entering food never overlaps the ones already on the belt while they slide in.
func _entry_x() -> float:
	var x: float = GameData.view_world_rect().position.x - ENTRY_INSET
	for f in _foods.get_children():
		if is_instance_valid(f) and not f.dragging and not f.returning:
			x = min(x, f.position.x - STACK_SPACING)
	return x

# Timed batches keep the belt varied: 1 or 2 random foods, capped at MAX_FOODS
# (needed groups are handled — cap-free — by _ensure_needed, not here). Each food
# enters spaced behind the last via _entry_x, so batches never overlap.
# On a narrow portrait screen MAX_FOODS exceeds the number of visible slots, which
# is fine: _layout parks the surplus behind the left edge and each food slides in
# as the ones ahead of it leave (a food's lifetime only starts once it reaches a
# slot the player can actually see — see Food.gd).
func _on_spawn_tick() -> void:
	if not active:
		return
	var count := randi() % 2 + 1   # 1 or 2 foods this batch
	for i in range(count):
		if _foods.get_child_count() >= MAX_FOODS:
			return
		_make_food(GameData.random_group())

# Seed a few foods starting from the MIDDLE of the screen (not pre-stacked on
# the right); the belt then slides them into the stack.
func _seed() -> void:
	var x: float = GameData.design_center().x
	for i in range(3):
		var f = _make_food(_choose_group())
		f.position.x = x
		f.target_x = x
		x -= STACK_SPACING

# Position belt foods into a right-anchored stack: the front-most (largest x)
# holds the right-hand slot and the rest pack in behind it, so they queue up
# instead of sliding off the right. A dragged or gliding-back food still HOLDS
# its slot (ranked by its reserved target_x, not its live position), so the gap
# stays open and the other foods don't slide into it — the held food then returns
# to the exact same spot. Its own target_x is left untouched while held.
func _layout() -> void:
	var items: Array = []
	for f in _foods.get_children():
		if is_instance_valid(f):
			items.append(f)
	items.sort_custom(func(a, b): return _rank_x(a) > _rank_x(b))
	var view: Rect2 = GameData.view_world_rect()
	var item_count: int = items.size()
	var usable_width: float = maxf(0.0, view.size.x - FOOD_ROW_INSET * 2.0)
	var slot_spacing: float = minf(MIN_SLOT_SPACING, usable_width / maxf(1.0, float(item_count - 1))) if item_count > 1 else 0.0
	var leftmost_center: float = view.position.x + FOOD_ROW_INSET
	for i in range(item_count):
		var f: Node = items[i]
		var target: float = view.end.x - FOOD_ROW_INSET - slot_spacing * float(i)
		if not f.dragging and not f.returning:
			f.target_x = maxf(leftmost_center, target)
		elif f.dragging:
			f.z_index = 10

# Right-hand end of the food stack, anchored to the visible right edge so the
# stack hugs the right of any screen width instead of a fixed 1040 px.
func _stack_front_x() -> float:
	var view: Rect2 = GameData.view_world_rect()
	return view.end.x - FOOD_ROW_INSET

# Ordering key for the stack: a dragged/returning food keeps its reserved slot
# (target_x); a food riding the belt orders by its live position.
func _rank_x(f) -> float:
	return f.target_x if (f.dragging or f.returning) else f.position.x

# === Gray-box visuals (art phase: swap for Sprite2D/TextureRect, keep names) ===
func _build_visuals() -> void:
	_belt = ColorRect.new()
	_belt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_belt.color = Color(0.26, 0.26, 0.30)
	_belt.z_index = -4
	add_child(_belt)
	_edge = ColorRect.new()
	_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_edge.color = Color(0.5, 0.5, 0.55)
	_edge.z_index = -3
	add_child(_edge)
	# Scrolling chevron stripes that sell the "conveyor" motion.
	var left: float = GameData.view_world_rect().position.x
	for i in range(11):
		var st := ColorRect.new()
		st.mouse_filter = Control.MOUSE_FILTER_IGNORE
		st.position = Vector2(left - 40.0 + i * BELT_STRIPE_SPACING, 0.0)
		st.size = Vector2(30, 30)
		st.color = Color(0.33, 0.33, 0.38)
		st.z_index = -4
		add_child(st)
		_stripes.append(st)
	_update_geometry()

# Lay the belt, its lip and the stripes onto the current visible area: full
# viewport width, flush with the bottom edge, so the belt fills any screen size
# and aspect ratio instead of the fixed 440x956 reference rect.
func _update_geometry() -> void:
	var view: Rect2 = GameData.view_world_rect()
	var top: float = GameData.belt_top()
	# This full-width belt is laid against the bottom of the visible world rect.
	_belt.position = Vector2(view.position.x, top)
	_belt.size = Vector2(view.size.x, GameData.BELT_H)
	_edge.position = Vector2(view.position.x, top - 4.0)
	_edge.size = Vector2(view.size.x, 5.0)
	for st in _stripes:
		st.position.y = top + 12.0
		st.size = Vector2(30, GameData.BELT_H - 24.0)
