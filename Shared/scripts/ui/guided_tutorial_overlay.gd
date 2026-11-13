extends CanvasLayer
class_name GuidedTutorialOverlay
## Presentation only. The level controller owns tutorial progression and pausing.
signal next_requested
signal skip_requested

@export_range(0.0,1.0,0.01) var explanation_opacity: float = 0.72
@export var dialogue_position: Vector2 = Vector2(16,104)
@export_range(240.0,640.0,1.0) var dialogue_width: float = 288.0
var root_control: Control
var shade: ColorRect
var panel: PanelContainer
var heading: Label
var message: Label
var next_button: Button
var skip_button: Button
var _material: ShaderMaterial

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 1000
	_build()
	root_control.hide()

func show_message(title: String, body: String, show_next: bool, show_skip: bool, interactive: bool, next_caption: String = "Next") -> void:
	heading.text = title
	message.text = body
	next_button.text = next_caption
	next_button.visible = show_next
	skip_button.visible = show_skip
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE if interactive else Control.MOUSE_FILTER_STOP
	_material.set_shader_parameter("dim_amount",0.10 if interactive else explanation_opacity)
	root_control.show()
	_fit_layout()
	if show_next:
		next_button.grab_focus()
	else:
		get_viewport().gui_release_focus()

func set_visual_style(opacity: float, border_color: Color) -> void:
	explanation_opacity = clampf(opacity,0.0,1.0)
	_material.set_shader_parameter("highlight_color",border_color)
	_material.set_shader_parameter("use_custom_highlight",true)

func hide_overlay() -> void:
	root_control.hide()

func update_highlights(rects: Array[Rect2]) -> void:
	var view_size := get_viewport().get_visible_rect().size
	if view_size.x<=0 or view_size.y<=0:
		return
	for slot in range(4):
		var value := Vector4(-2,-2,0,0)
		if slot < rects.size():
			var bounds := rects[slot].intersection(Rect2(Vector2.ZERO,view_size))
			if bounds.has_area():
				value = Vector4(bounds.position.x/view_size.x,bounds.position.y/view_size.y,bounds.size.x/view_size.x,bounds.size.y/view_size.y)
		_material.set_shader_parameter(["spot_one","spot_two","spot_three","spot_four"][slot],value)
	_material.set_shader_parameter("viewport_pixels",view_size)
	_fit_layout()

func _fit_layout() -> void:
	var view_size := get_viewport().get_visible_rect().size
	panel.size = Vector2(minf(dialogue_width,maxf(1,view_size.x-32)),0)
	panel.position = dialogue_position
	panel.position.x = clampf(panel.position.x,0,maxf(0,view_size.x-panel.size.x))
	panel.position.y = clampf(panel.position.y,0,maxf(0,view_size.y-panel.get_combined_minimum_size().y))

func _build() -> void:
	root_control = Control.new()
	root_control.name = "TutorialOverlay"
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)
	shade = ColorRect.new()
	shade.name = "Spotlight"
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.add_child(shade)
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform vec4 spot_one=vec4(-2.0,-2.0,0.0,0.0);
uniform vec4 spot_two=vec4(-2.0,-2.0,0.0,0.0);
uniform vec4 spot_three=vec4(-2.0,-2.0,0.0,0.0);
uniform vec4 spot_four=vec4(-2.0,-2.0,0.0,0.0);
uniform vec2 viewport_pixels=vec2(956.0,440.0);
uniform float dim_amount=0.72;
uniform vec4 highlight_color : source_color = vec4(1.0,0.82,0.32,1.0);
uniform bool use_custom_highlight=false;
float inside_box(vec2 p,vec4 b) {
 return step(b.x,p.x)*step(b.y,p.y)*step(p.x,b.x+b.z)*step(p.y,b.y+b.w)*step(0.0001,b.z)*step(0.0001,b.w);
}
void fragment() {
 vec2 pad=vec2(3.0)/viewport_pixels;
 float inner=max(max(inside_box(UV,spot_one),inside_box(UV,spot_two)),max(inside_box(UV,spot_three),inside_box(UV,spot_four)));
 float outer=max(max(inside_box(UV,vec4(spot_one.xy-pad,spot_one.zw+pad*2.0)),inside_box(UV,vec4(spot_two.xy-pad,spot_two.zw+pad*2.0))),max(inside_box(UV,vec4(spot_three.xy-pad,spot_three.zw+pad*2.0)),inside_box(UV,vec4(spot_four.xy-pad,spot_four.zw+pad*2.0))));
 vec4 border_color=use_custom_highlight?highlight_color:vec4(1.0,0.82,0.32,1.0);
 COLOR=vec4(mix(vec3(0.0),border_color.rgb,outer-inner),mix(dim_amount,0.0,inner));
 if(outer-inner>0.5){COLOR.a=border_color.a;}
}"""
	_material = ShaderMaterial.new()
	_material.shader = shader
	shade.material = _material
	panel = PanelContainer.new()
	panel.name = "TutorialDialogue"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color("14252c")
	style.border_color = Color("f5ca64")
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left=16
	style.content_margin_right=16
	style.content_margin_top=12
	style.content_margin_bottom=12
	panel.add_theme_stylebox_override("panel",style)
	root_control.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",8)
	panel.add_child(column)
	heading = Label.new()
	heading.add_theme_color_override("font_color",Color("f5ca64"))
	heading.add_theme_font_size_override("font_size",13)
	column.add_child(heading)
	message = Label.new()
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.custom_minimum_size = Vector2(0,56)
	message.add_theme_font_size_override("font_size",17)
	column.add_child(message)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation",10)
	column.add_child(buttons)
	skip_button = Button.new()
	skip_button.name = "SkipTutorial"
	skip_button.text = "Skip Tutorial"
	skip_button.pressed.connect(func():skip_requested.emit())
	buttons.add_child(skip_button)
	next_button = Button.new()
	next_button.name = "Next"
	next_button.text = "Next"
	next_button.custom_minimum_size = Vector2(72,32)
	next_button.pressed.connect(func():next_requested.emit())
	buttons.add_child(next_button)
