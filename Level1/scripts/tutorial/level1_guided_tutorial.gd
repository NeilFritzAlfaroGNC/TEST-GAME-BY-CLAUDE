extends CanvasLayer
## Guided Level 1 onboarding. Observes existing gameplay; owns no combat or scoring state.
signal step_changed(step_index: int)
signal tutorial_completed(skipped: bool)

const SAVE_PATH := "user://food_heroes_tutorials.cfg"
const SAVE_KEY := "level1_cafeteria_v1"
enum Phase { WAIT_STUDENT, EXPLANATION, WAIT_TRANSFORMATION, PRACTICE, FINISHED }

@export_group("Tutorial")
@export var enable_tutorial: bool = true
@export var show_only_once: bool = true
@export var pause_during_explanation: bool = true
@export var highlight_tutorial_target: bool = true
@export var require_first_successful_rescue: bool = true
@export var allow_skip_tutorial: bool = true
@export_group("Tutorial Text")
@export_multiline var student_appears_text: String = "These students are buying junk food from the school cafeteria. Let's see what happens when they eat too much!"
@export_multiline var transformation_text: String = "Oh no! The student has turned into a monster after eating too much junk food!"
@export_multiline var objective_text: String = "Feed the monster healthy foods to rescue the student!"
@export_multiline var conveyor_text: String = "Look at the conveyor belt! It carries healthy foods that you can use to rescue the students."
@export_multiline var dragging_text: String = "Drag a healthy food from the conveyor belt and drop it onto the monster to rescue the student!"
@export_multiline var rescue_complete_text: String = "Great job! You've rescued a student! Keep feeding healthy foods to the monsters to save more students."

var phase: Phase = Phase.WAIT_STUDENT
var current_step: int = -1
var target: Level1EnemyRoaming
var _owns_pause: bool = false
var _previously_fed: Dictionary = {}
var _completion_recorded: bool = false
var battle: Node
var enemies: Node
var food_items: Node
var conveyor: AnimatedSprite2D
var ui_root: Control
var shade: ColorRect
var panel: PanelContainer
var message_label: Label
var step_label: Label
var next_button: Button
var skip_button: Button
var _texture_bounds: Dictionary = {}
var _material: ShaderMaterial

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 1000
	battle = get_parent().get_node_or_null("Level1BattleController")
	enemies = get_parent().get_node_or_null("Level1Enemies")
	food_items = get_parent().get_node_or_null("FoodItems")
	conveyor = get_parent().get_node_or_null("Conveyer Belt") as AnimatedSprite2D
	if not enable_tutorial or (show_only_once and has_completed_tutorial()):
		phase = Phase.FINISHED
		set_process(false)
		return
	if battle == null or enemies == null:
		push_warning("[Level1 Tutorial] Gameplay nodes are missing; continuing without tutorial.")
		phase = Phase.FINISHED
		set_process(false)
		return
	for actor in enemies.get_children():
		_watch_rescue(actor)
	enemies.child_entered_tree.connect(_watch_rescue)
	_build_overlay()
	ui_root.hide()

func has_completed_tutorial() -> bool:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return false
	return bool(config.get_value("completed",SAVE_KEY,false))

func _process(_delta: float) -> void:
	if phase == Phase.FINISHED:
		return
	if not is_instance_valid(battle) or battle.battle_finished or battle.game_over_triggered:
		_cancel_for_scene_end()
		return
	match phase:
		Phase.WAIT_STUDENT:
			for node in enemies.get_children():
				var student := node as Level1EnemyRoaming
				if student != null and student.character_state == Level1EnemyRoaming.CharacterState.STUDENT:
					target = student
					_show_step(0)
					break
		Phase.WAIT_TRANSFORMATION:
			if not is_instance_valid(target) or target.is_queued_for_deletion():
				# If the original target disappears, watch another actor without blocking gameplay.
				for node in enemies.get_children():
					if node is Level1EnemyRoaming and node.character_state in [Level1EnemyRoaming.CharacterState.STUDENT,Level1EnemyRoaming.CharacterState.MONSTER]:
						target = node
						break
			if is_instance_valid(target) and target.character_state == Level1EnemyRoaming.CharacterState.MONSTER:
				_show_step(1)
		Phase.PRACTICE:
			pass # Completion comes from rescue_finished after the poof, not a student state.
	if is_instance_valid(ui_root) and ui_root.visible:
		_update_highlights()

func _watch_rescue(node: Node) -> void:
	var actor := node as Level1EnemyRoaming
	if actor != null and not actor.rescue_finished.is_connected(_on_rescue_finished):
		actor.rescue_finished.connect(_on_rescue_finished)

func _on_rescue_finished(actor: Level1EnemyRoaming) -> void:
	if not is_instance_valid(battle) or battle.battle_finished or battle.game_over_triggered:
		return
	if phase != Phase.PRACTICE or not is_instance_valid(actor):
		return
	if _previously_fed.has(actor.get_instance_id()):
		return
	# The actor has vanished; the final message must not highlight a stale body.
	target = null
	_show_step(5)

func _show_step(index: int) -> void:
	current_step = index
	phase = Phase.PRACTICE if index == 4 else Phase.EXPLANATION
	var texts := [student_appears_text,transformation_text,objective_text,conveyor_text,dragging_text,rescue_complete_text]
	message_label.text = texts[index]
	step_label.text = "LEVEL 1 · TUTORIAL    %d / 6" % (index+1)
	next_button.text = "Continue" if index in [4,5] else "Next"
	next_button.visible = index != 4 or not require_first_successful_rescue
	skip_button.visible = allow_skip_tutorial
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE if index == 4 else Control.MOUSE_FILTER_STOP
	_material.set_shader_parameter("dim_amount",0.12 if index == 4 else 0.72)
	if index == 4:
		_previously_fed.clear()
		for node in enemies.get_children():
			if node is Level1EnemyRoaming and (node.get_meta("level1_being_consumed",false) or node.character_state in [Level1EnemyRoaming.CharacterState.DEFEAT_POOF,Level1EnemyRoaming.CharacterState.RETURNED_STUDENT]):
				_previously_fed[node.get_instance_id()] = true
		_release_pause()
	else:
		_request_pause()
	ui_root.show()
	_update_highlights()
	if next_button.visible:
		next_button.grab_focus()
	else:
		get_viewport().gui_release_focus()
	step_changed.emit(index)

func _on_next() -> void:
	if phase == Phase.FINISHED:
		return
	match current_step:
		0:
			phase = Phase.WAIT_TRANSFORMATION
			ui_root.hide()
			_release_pause()
		1,2,3:
			_show_step(current_step+1)
		4:
			if not require_first_successful_rescue:
				_finish(false)
		5:
			_finish(false)

func _on_skip() -> void:
	if allow_skip_tutorial and phase != Phase.FINISHED:
		_finish(true)

func _request_pause() -> void:
	if pause_during_explanation and not get_tree().paused:
		get_tree().paused = true
		_owns_pause = true

func _release_pause() -> void:
	if _owns_pause and is_inside_tree():
		get_tree().paused = false
	_owns_pause = false

func _finish(skipped: bool) -> void:
	if phase == Phase.FINISHED:
		return
	phase = Phase.FINISHED
	_release_pause()
	ui_root.hide()
	set_process(false)
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	config.set_value("completed",SAVE_KEY,true)
	var error := config.save(SAVE_PATH)
	_completion_recorded = error == OK
	if error != OK:
		push_warning("[Level1 Tutorial] Could not save completion: %s" % error)
	tutorial_completed.emit(skipped)

func _cancel_for_scene_end() -> void:
	phase = Phase.FINISHED
	_release_pause()
	if is_instance_valid(ui_root):
		ui_root.hide()
	set_process(false)

func _exit_tree() -> void:
	_release_pause()

func _sprite_bounds(sprite: AnimatedSprite2D) -> Rect2:
	if not is_instance_valid(sprite) or not sprite.is_visible_in_tree() or sprite.sprite_frames == null:
		return Rect2()
	if not sprite.sprite_frames.has_animation(sprite.animation) or sprite.sprite_frames.get_frame_count(sprite.animation) <= sprite.frame:
		return Rect2()
	var texture := sprite.sprite_frames.get_frame_texture(sprite.animation,sprite.frame)
	if texture == null:
		return Rect2()
	var dimensions := texture.get_size()
	var corner := sprite.offset - (dimensions*0.5 if sprite.centered else Vector2.ZERO)
	var texture_id := texture.get_instance_id()
	if not _texture_bounds.has(texture_id):
		var image := texture.get_image()
		_texture_bounds[texture_id] = Rect2(image.get_used_rect()) if image != null else Rect2(Vector2.ZERO,dimensions)
	var used: Rect2 = _texture_bounds[texture_id]
	corner += used.position
	dimensions = used.size
	if sprite.flip_h:
		corner.x = -(corner.x+dimensions.x)
	if sprite.flip_v:
		corner.y = -(corner.y+dimensions.y)
	return sprite.get_global_transform_with_canvas()*Rect2(corner,dimensions)

func _target_bounds() -> Rect2:
	if not is_instance_valid(target):
		return Rect2()
	for sprite_node_name in ["StudentSprite","AnimatedSprite2D"]:
		var bounds := _sprite_bounds(target.get_node_or_null(sprite_node_name) as AnimatedSprite2D)
		if bounds.has_area():
			return bounds.grow(12)
	return Rect2(target.get_global_transform_with_canvas().origin-Vector2(32,48),Vector2(64,96))

func _belt_bounds() -> Rect2:
	var bounds := _sprite_bounds(conveyor)
	if is_instance_valid(food_items):
		for node in food_items.get_children():
			var food_bounds := _sprite_bounds(node as AnimatedSprite2D)
			if food_bounds.has_area():
				bounds = bounds.merge(food_bounds) if bounds.has_area() else food_bounds
	return bounds.grow(8) if bounds.has_area() else Rect2()

func _update_highlights() -> void:
	var size := get_viewport().get_visible_rect().size
	if size.x <= 0 or size.y <= 0:
		return
	var actor_rect := _target_bounds()
	var belt_rect := _belt_bounds()
	var first := belt_rect if current_step == 3 else actor_rect
	var second := belt_rect if current_step == 4 else Rect2()
	for pair in [["spot_one",first],["spot_two",second]]:
		var rect: Rect2 = pair[1]
		var value := Vector4(-2,-2,0,0)
		if highlight_tutorial_target and rect.has_area():
			rect = rect.intersection(Rect2(Vector2.ZERO,size))
			value = Vector4(rect.position.x/size.x,rect.position.y/size.y,rect.size.x/size.x,rect.size.y/size.y)
		_material.set_shader_parameter(pair[0],value)
	_material.set_shader_parameter("viewport_pixels",size)
	# Put dialogue on the opposite side from its target, leaving the belt unobstructed.
	var width := minf(440,size.x-32)
	panel.size = Vector2(width,0)
	panel.position = Vector2(16.0 if first.get_center().x > size.x*0.5 else maxf(16.0,size.x-width-16.0),64.0)
	if current_step == 4:
		panel.position.y = 16

func _build_overlay() -> void:
	ui_root = Control.new()
	ui_root.name = "TutorialOverlay"
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui_root)
	shade = ColorRect.new()
	shade.name = "Spotlight"
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(shade)
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform vec4 spot_one = vec4(-2.0,-2.0,0.0,0.0);
uniform vec4 spot_two = vec4(-2.0,-2.0,0.0,0.0);
uniform vec2 viewport_pixels = vec2(956.0,440.0);
uniform float dim_amount = 0.72;
float inside_box(vec2 p, vec4 box) {
 return step(box.x,p.x)*step(box.y,p.y)*step(p.x,box.x+box.z)*step(p.y,box.y+box.w)*step(0.0001,box.z)*step(0.0001,box.w);
}
void fragment() {
 float inner = max(inside_box(UV,spot_one),inside_box(UV,spot_two));
 vec2 pad = vec2(3.0)/viewport_pixels;
 float outer = max(inside_box(UV,vec4(spot_one.xy-pad,spot_one.zw+pad*2.0)),inside_box(UV,vec4(spot_two.xy-pad,spot_two.zw+pad*2.0)));
 COLOR = vec4(mix(vec3(0.0),vec3(1.0,0.82,0.32),outer-inner),mix(dim_amount,0.0,inner));
 if (outer-inner > 0.5) { COLOR.a = 1.0; }
}"""
	_material = ShaderMaterial.new()
	_material.shader = shader
	shade.material = _material
	panel = PanelContainer.new()
	panel.name = "TutorialDialogue"
	panel.custom_minimum_size = Vector2(400,0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color("14252c")
	style.border_color = Color("f5ca64")
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel",style)
	ui_root.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",8)
	panel.add_child(column)
	step_label = Label.new()
	step_label.add_theme_color_override("font_color",Color("f5ca64"))
	step_label.add_theme_font_size_override("font_size",13)
	column.add_child(step_label)
	message_label = Label.new()
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.custom_minimum_size = Vector2(0,56)
	message_label.add_theme_font_size_override("font_size",17)
	column.add_child(message_label)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation",10)
	column.add_child(buttons)
	skip_button = Button.new()
	skip_button.name = "SkipTutorial"
	skip_button.text = "Skip Tutorial"
	skip_button.pressed.connect(_on_skip)
	buttons.add_child(skip_button)
	next_button = Button.new()
	next_button.name = "Next"
	next_button.text = "Next"
	next_button.custom_minimum_size = Vector2(92,32)
	next_button.pressed.connect(_on_next)
	buttons.add_child(next_button)
