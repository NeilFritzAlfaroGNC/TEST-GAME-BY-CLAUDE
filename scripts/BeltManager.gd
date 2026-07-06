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

const FOOD_SPAWN_INTERVAL := 1.0
const MAX_FOODS := 6
const BELT_H := 96.0
const BELT_STRIPE_SPEED := 130.0
const STACK_FRONT_X := 1040.0    # foods stack against here (right side), piling left
const STACK_SPACING := 185.0     # distance between stacked food centers

var active: bool = false

var _food_scene: PackedScene
var _foods: Node2D       # Main's $Foods container (holds the Food nodes)
var _needed: Callable    # -> Array of groups the belt must keep available
var _timer: Timer
var _stripes: Array = []

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
	# Scroll the conveyor stripes (left -> right, wrapping) for a moving-belt look.
	for stripe in _stripes:
		stripe.position.x += BELT_STRIPE_SPEED * delta
		if stripe.position.x > GameData.DESIGN_SIZE.x + 8.0:
			stripe.position.x -= 1300.0
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
	_foods.add_child(f)
	f.set_food(group)
	return f

# Timed batches keep the belt varied: 1 or 2 random foods, capped at MAX_FOODS
# (needed groups are handled — cap-free — by _ensure_needed, not here).
func _on_spawn_tick() -> void:
	if not active:
		return
	var count := randi() % 2 + 1   # 1 or 2 foods this batch
	for i in range(count):
		if _foods.get_child_count() >= MAX_FOODS:
			return
		var f = _make_food(GameData.random_group())
		if i > 0:
			# Offset the extra food further left so the batch enters spaced out.
			f.position = Vector2(f.position.x - i * STACK_SPACING, f.position.y)

# Seed a few foods starting from the MIDDLE of the screen (not pre-stacked on
# the right); the belt then slides them into the stack.
func _seed() -> void:
	var x := GameData.DESIGN_SIZE.x / 2.0
	for i in range(3):
		var f = _make_food(_choose_group())
		f.position.x = x
		f.target_x = x
		x -= STACK_SPACING

# Position belt foods into a right-anchored stack: the front-most (largest x)
# holds STACK_FRONT_X and the rest pack in behind it, so they queue up instead
# of sliding off the right. Foods being dragged are left alone.
func _layout() -> void:
	var items: Array = []
	for f in _foods.get_children():
		if is_instance_valid(f) and not f.dragging:
			items.append(f)
	items.sort_custom(func(a, b): return a.position.x > b.position.x)
	var target := STACK_FRONT_X
	for f in items:
		f.target_x = target
		target -= STACK_SPACING

# === Gray-box visuals (art phase: swap for Sprite2D/TextureRect, keep names) ===
func _build_visuals() -> void:
	var belt := ColorRect.new()
	belt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	belt.position = Vector2(0, GameData.BELT_TOP)
	belt.size = Vector2(GameData.DESIGN_SIZE.x, BELT_H)
	belt.color = Color(0.26, 0.26, 0.30)
	belt.z_index = -4
	add_child(belt)
	var edge := ColorRect.new()
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edge.position = Vector2(0, GameData.BELT_TOP - 4.0)
	edge.size = Vector2(GameData.DESIGN_SIZE.x, 5)
	edge.color = Color(0.5, 0.5, 0.55)
	edge.z_index = -3
	add_child(edge)
	# Scrolling chevron stripes that sell the "conveyor" motion.
	for i in range(11):
		var st := ColorRect.new()
		st.mouse_filter = Control.MOUSE_FILTER_IGNORE
		st.position = Vector2(-40.0 + i * 130.0, GameData.BELT_TOP + 12.0)
		st.size = Vector2(30, BELT_H - 24.0)
		st.color = Color(0.33, 0.33, 0.38)
		st.z_index = -4
		add_child(st)
		_stripes.append(st)
