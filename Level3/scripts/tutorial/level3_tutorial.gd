extends Node
## Level3-only guide over the existing rescue system; gameplay configuration is never rewritten.
signal step_changed(step_index: int)
signal tutorial_completed(skipped: bool)
const OVERLAY_SCENE = preload("res://Shared/scenes/ui/guided_tutorial_overlay.tscn")
const SAVE_PATH := "user://food_heroes_tutorials.cfg"
const SAVE_KEY := "level3_nutrition_rescue_v1"
enum Phase { FINISHED, WAIT_MONSTER, EXPLANATION, PRACTICE, COMPLETE }

@export_group("Tutorial")
@export var enable_tutorial: bool = true
@export var show_only_once: bool = true
@export var pause_during_explanation: bool = true
@export var highlight_tutorial_targets: bool = true
@export var allow_skip_tutorial: bool = true
@export var require_first_successful_cure: bool = true
@export_group("Tutorial Appearance")
@export_range(0.0,100.0,1.0,"suffix:%") var tutorial_overlay_opacity: float = 60.0
@export var tutorial_highlight_color: Color = Color("#ffd54f")
@export_group("Tutorial Messages")
@export_multiline var monster_text: String = "Oh no! These monsters are suffering from poor nutrition. We need to help them become healthy again!"
@export_multiline var bars_text: String = "Every monster has three nutrition bars: GO, GLOW, and GROW. These show the nutrients each monster needs."
@export_multiline var depletion_text: String = "Watch out! The nutrition bars slowly decrease over time. Feed the monsters before they escape!"
@export_multiline var conveyor_text: String = "The conveyor belt carries foods that can restore the monsters' nutrition."
@export_multiline var feeding_text: String = "Drag food from the conveyor belt and drop it onto a monster. The food restores its matching GO, GLOW, or GROW nutrition."
@export_multiline var locks_text: String = "When a nutrition bar reaches 100%, it stays full! Fill all three bars to rescue the monster."
@export_multiline var escape_text: String = "Don't let the monsters reach the left side! Too many escapes will end the game."
@export_multiline var practice_text: String = "Now it's your turn! Feed the monster until all three nutrition bars are full."
@export_multiline var complete_text: String = "Excellent! You've rescued your first monster. Keep curing monsters to win the challenge!"

var battle: Node
var monster_container: Node
var overlay: GuidedTutorialOverlay
var target: Level3NutritionMonster
var current_step: int = -1
var phase: Phase = Phase.FINISHED
var _owns_pause: bool = false
var _escape_suspended: bool = false
var _saved_escape_enabled: bool = true
var _practice_succeeded: bool = false
var _texture_bounds: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	battle = get_parent()
	set_process(false)
	if not enable_tutorial or (show_only_once and has_completed_tutorial()):
		return
	monster_container = battle.get_node("MonsterContainer")
	for actor in monster_container.get_children():
		_watch_monster(actor)
	monster_container.child_entered_tree.connect(_watch_monster)
	call_deferred("_begin")

func has_completed_tutorial() -> bool:
	var config := ConfigFile.new()
	return config.load(SAVE_PATH)==OK and bool(config.get_value("completed",SAVE_KEY,false))

func _begin() -> void:
	if battle.battle_finished:
		return
	overlay = OVERLAY_SCENE.instantiate() as GuidedTutorialOverlay
	overlay.dialogue_position = Vector2(320,70)
	overlay.dialogue_width = 400
	add_child(overlay)
	overlay.next_requested.connect(_on_next)
	overlay.skip_requested.connect(_on_skip)
	phase = Phase.WAIT_MONSTER
	set_process(true)
	_follow_target()
	if _is_active(target):
		_show_step(0)

func _watch_monster(node: Node) -> void:
	var monster := node as Level3NutritionMonster
	if monster != null and not monster.cured.is_connected(_on_monster_cured):
		monster.cured.connect(_on_monster_cured)

func _is_active(monster: Variant) -> bool:
	return is_instance_valid(monster) and monster is Level3NutritionMonster and not monster.is_queued_for_deletion() and monster.is_active and not monster.is_cured

func _follow_target() -> void:
	# Let the player select any monster during practice; the real UI stays bound to it.
	if phase==Phase.PRACTICE and _is_active(battle.selected_monster):
		target = battle.selected_monster
	if not _is_active(target):
		target = null
		for actor in monster_container.get_children():
			if actor is Level3NutritionMonster and _is_active(actor):
				target = actor
				break
	if _is_active(target) and battle.selected_monster != target:
		battle._on_monster_selected(target)

func _process(_delta: float) -> void:
	if not is_instance_valid(battle) or battle.battle_finished:
		if _practice_succeeded:
			_finish(false)
		else:
			_cancel()
		return
	if phase!=Phase.COMPLETE:
		_follow_target()
	if phase==Phase.WAIT_MONSTER and _is_active(target):
		_show_step(0)
	if is_instance_valid(overlay) and phase not in [Phase.FINISHED,Phase.WAIT_MONSTER]:
		_update_highlights()

func _show_step(index: int) -> void:
	current_step=index
	phase=Phase.PRACTICE if index==7 else (Phase.COMPLETE if index==8 else Phase.EXPLANATION)
	var texts := [monster_text,bars_text,depletion_text,conveyor_text,feeding_text,locks_text,escape_text,practice_text,complete_text]
	overlay.set_visual_style(tutorial_overlay_opacity/100.0,tutorial_highlight_color)
	overlay.show_message("LEVEL 3 · TUTORIAL    %d / 9"%(index+1),texts[index],index!=7 or not require_first_successful_cure,allow_skip_tutorial,index==7,"Continue" if index>=7 else "Next")
	if index==7:
		_release_pause()
		_restore_escape_detection()
	else:
		_pause_explanation()
	_update_highlights()
	step_changed.emit(index)

func _on_next() -> void:
	if phase==Phase.EXPLANATION:
		_show_step(current_step+1)
	elif phase==Phase.COMPLETE or (phase==Phase.PRACTICE and not require_first_successful_cure):
		_finish(false)

func _on_monster_cured(monster: Level3NutritionMonster) -> void:
	if phase!=Phase.PRACTICE or not is_instance_valid(monster) or not monster.is_cured:
		return
	if battle.battle_finished and (battle.cured_count < battle.required_cures or battle.escaped_count >= battle.maximum_escapes):
		_cancel()
		return
	_practice_succeeded=true
	target=null
	# A one-cure victory is allowed to use the existing Victory transition immediately.
	if battle.battle_finished:
		_finish(false)
	else:
		_show_step(8)

func _pause_explanation() -> void:
	if not pause_during_explanation:
		return
	if not _escape_suspended:
		_saved_escape_enabled=battle.escape_zone.enable_escape_detection
		battle.escape_zone.enable_escape_detection=false
		_escape_suspended=true
	if not get_tree().paused:
		get_tree().paused=true
		_owns_pause=true

func _release_pause() -> void:
	if _owns_pause and is_inside_tree():
		get_tree().paused=false
	_owns_pause=false

func _restore_escape_detection() -> void:
	if not _escape_suspended:
		return
	_escape_suspended=false
	if is_instance_valid(battle) and is_instance_valid(battle.escape_zone):
		battle.escape_zone.enable_escape_detection=_saved_escape_enabled
		if _saved_escape_enabled and not battle.battle_finished and is_inside_tree():
			call_deferred("_flush_escape_overlaps")

func _flush_escape_overlaps() -> void:
	if not is_inside_tree() or get_tree().paused or not is_instance_valid(battle) or battle.battle_finished:
		return
	if not battle.escape_zone.enable_escape_detection:
		return
	for actor in battle.escape_zone.get_overlapping_bodies():
		battle.escape_zone._on_monster_body_entered(actor)

func _on_skip() -> void:
	if allow_skip_tutorial and phase!=Phase.FINISHED:
		_finish(true)

func _finish(skipped: bool) -> void:
	if phase==Phase.FINISHED:
		return
	_cancel()
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	config.set_value("completed",SAVE_KEY,true)
	var error := config.save(SAVE_PATH)
	if error!=OK:
		push_warning("[Level3 Tutorial] Could not save completion: %s"%error)
	tutorial_completed.emit(skipped)

func _cancel() -> void:
	phase=Phase.FINISHED
	_release_pause()
	_restore_escape_detection()
	if is_instance_valid(overlay):
		overlay.hide_overlay()
	set_process(false)

func _exit_tree() -> void:
	_release_pause()
	_restore_escape_detection()

func _sprite_bounds(sprite: AnimatedSprite2D) -> Rect2:
	if not is_instance_valid(sprite) or not sprite.is_visible_in_tree() or sprite.sprite_frames==null:
		return Rect2()
	if not sprite.sprite_frames.has_animation(sprite.animation) or sprite.sprite_frames.get_frame_count(sprite.animation)<=sprite.frame:
		return Rect2()
	var texture := sprite.sprite_frames.get_frame_texture(sprite.animation,sprite.frame)
	if texture==null:
		return Rect2()
	var dimensions := texture.get_size()
	var corner := sprite.offset-(dimensions*0.5 if sprite.centered else Vector2.ZERO)
	var texture_id := texture.get_instance_id()
	if not _texture_bounds.has(texture_id):
		var image := texture.get_image()
		_texture_bounds[texture_id]=Rect2(image.get_used_rect()) if image!=null else Rect2(Vector2.ZERO,dimensions)
	var used: Rect2 = _texture_bounds[texture_id]
	corner+=used.position
	dimensions=used.size
	if sprite.flip_h:corner.x=-(corner.x+dimensions.x)
	if sprite.flip_v:corner.y=-(corner.y+dimensions.y)
	return sprite.get_global_transform_with_canvas()*Rect2(corner,dimensions)

func _monster_bounds() -> Rect2:
	return _sprite_bounds(target.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D).grow(10) if _is_active(target) else Rect2()

func _bar_bounds() -> Rect2:
	if not battle.liquid_ui.root_control.visible:
		return Rect2()
	var row: Control = battle.liquid_ui.root_control.get_node("LiquidBars")
	return (row.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,row.size)).grow(8)

func _belt_bounds() -> Rect2:
	var bounds := _sprite_bounds(battle.conveyor as AnimatedSprite2D)
	for item in battle.food_items.get_children():
		var food_bounds := _sprite_bounds(item as AnimatedSprite2D)
		if food_bounds.has_area():bounds=bounds.merge(food_bounds) if bounds.has_area() else food_bounds
	return bounds.grow(6) if bounds.has_area() else Rect2()

func _escape_bounds() -> Rect2:
	var collision: CollisionShape2D = battle.escape_zone.get_node("CollisionShape2D")
	if collision.shape==null:return Rect2()
	return collision.get_global_transform_with_canvas()*collision.shape.get_rect()

func _update_highlights() -> void:
	var bounds: Array[Rect2]=[]
	if highlight_tutorial_targets:
		match current_step:
			0:bounds.append(_monster_bounds())
			1,2,5:bounds.append(_bar_bounds())
			3:bounds.append(_belt_bounds())
			4,7:bounds.append_array([_monster_bounds(),_belt_bounds(),_bar_bounds()])
			6:bounds.append(_escape_bounds())
	overlay.update_highlights(bounds)
