extends Node
## Observe actual accepted classifications; preserve all existing round/scoring rules.
signal step_changed(step_index: int)
signal tutorial_completed(skipped: bool)
const OVERLAY_SCENE = preload("res://Shared/scenes/ui/guided_tutorial_overlay.tscn")
const SAVE_PATH := "user://food_heroes_tutorials.cfg"
const SAVE_KEY := "level2_canteen_v1"
enum Phase { FINISHED, EXPLANATION, PRACTICE, COMPLETE }

@export_group("Tutorial")
@export var enable_tutorial: bool = true
@export var show_only_once: bool = true
@export var pause_during_explanation: bool = true
@export var highlight_go_glow_grow: bool = true
@export var require_correct_sorting: bool = true
@export var allow_skip_tutorial: bool = true
@export_group("Tutorial Messages")
@export_multiline var welcome_text: String = "Welcome to the Canteen! Your task is to sort foods into the correct nutrition categories."
@export_multiline var go_text: String = "GO foods give our bodies energy for studying, playing, and everyday activities!"
@export_multiline var glow_text: String = "GLOW foods help keep our bodies healthy and support normal body functions!"
@export_multiline var grow_text: String = "GROW foods help our bodies grow and repair muscles and other tissues!"
@export_multiline var sorting_text: String = "Look at the food provided. Drag it into the correct GO, GLOW, or GROW basket!"
@export_multiline var practice_text: String = "Now it's your turn! Sort a food correctly to complete the tutorial."
@export_multiline var complete_text: String = "Great job! Keep sorting the foods correctly to complete the challenge!"

var battle: Node
var overlay: GuidedTutorialOverlay
var phase: Phase = Phase.FINISHED
var current_step: int = -1
var _owns_pause: bool = false
var _round_serial: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	battle = get_parent()
	battle.round_started.connect(_on_round_started)
	battle.answer_classified.connect(_on_answer_classified)
	battle.round_finished.connect(_on_round_finished)
	set_process(false)

func has_completed_tutorial() -> bool:
	var config := ConfigFile.new()
	return config.load(SAVE_PATH)==OK and bool(config.get_value("completed",SAVE_KEY,false))

func _on_round_started() -> void:
	_round_serial += 1
	call_deferred("_begin_round",_round_serial)

func _begin_round(serial: int) -> void:
	if serial != _round_serial or not is_inside_tree():
		return
	_cancel()
	if not enable_tutorial or (show_only_once and has_completed_tutorial()) or not battle.running:
		return
	if not is_instance_valid(overlay):
		overlay = OVERLAY_SCENE.instantiate() as GuidedTutorialOverlay
		add_child(overlay)
		overlay.next_requested.connect(_on_next)
		overlay.skip_requested.connect(_on_skip)
	set_process(true)
	_show_step(0)

func _show_step(index: int) -> void:
	current_step = index
	phase = Phase.PRACTICE if index==5 else (Phase.COMPLETE if index==6 else Phase.EXPLANATION)
	var texts := [welcome_text,go_text,glow_text,grow_text,sorting_text,practice_text,complete_text]
	var interactive := index==5
	overlay.show_message("LEVEL 2 · TUTORIAL    %d / 7"%(index+1),texts[index],not interactive or not require_correct_sorting,allow_skip_tutorial,interactive,"Continue" if index>=5 else "Next")
	if interactive:
		_release_pause()
	else:
		_request_pause()
	_update_highlights()
	step_changed.emit(index)

func _process(_delta: float) -> void:
	if phase != Phase.FINISHED and is_instance_valid(overlay):
		_update_highlights()

func _screen_rect(control: Control) -> Rect2:
	return control.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,control.size)

func _update_highlights() -> void:
	var rects: Array[Rect2] = []
	if highlight_go_glow_grow:
		if current_step in [1,2,3]:
			rects.append(_screen_rect(battle.baskets.get_child(current_step-1)).grow(6))
		elif current_step in [4,5]:
			rects.append(_screen_rect(battle.card).grow(6))
			for basket in battle.baskets.get_children():
				rects.append(_screen_rect(basket).grow(6))
	overlay.update_highlights(rects)

func _on_next() -> void:
	if phase == Phase.EXPLANATION:
		_show_step(current_step+1)
	elif phase == Phase.COMPLETE or (phase==Phase.PRACTICE and not require_correct_sorting):
		_finish(false)

func _on_answer_classified(is_correct: bool) -> void:
	if phase==Phase.PRACTICE and is_correct:
		_show_step(6)

func _on_round_finished() -> void:
	call_deferred("_check_round_end",_round_serial)

func _check_round_end(serial: int) -> void:
	if serial==_round_serial and phase!=Phase.COMPLETE and not battle.running:
		_cancel()

func _on_skip() -> void:
	if allow_skip_tutorial and phase != Phase.FINISHED:
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
		push_warning("[Level2 Tutorial] Could not save completion: %s"%error)
	tutorial_completed.emit(skipped)

func _request_pause() -> void:
	if pause_during_explanation and not get_tree().paused:
		get_tree().paused=true
		_owns_pause=true

func _release_pause() -> void:
	if _owns_pause and is_inside_tree():
		get_tree().paused=false
	_owns_pause=false

func _cancel() -> void:
	phase=Phase.FINISHED
	_release_pause()
	if is_instance_valid(overlay):
		overlay.hide_overlay()
	set_process(false)

func _exit_tree() -> void:
	_release_pause()
