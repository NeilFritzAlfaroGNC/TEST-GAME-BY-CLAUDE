@tool
extends Control
class_name StarIcon
## A five-pointed star drawn in code (no image needed). Gold when `filled`,
## dark when empty. Used for the battle star rating.

@export var filled: bool = true:
	set(value):
		filled = value
		queue_redraw()
@export var fill_color: Color = Color(1, 0.82, 0.2)
@export var empty_color: Color = Color(0.2, 0.22, 0.28)
@export var outline_color: Color = Color(0.1, 0.06, 0.02)

func _draw() -> void:
	var center: Vector2 = size / 2.0
	var outer: float = minf(size.x, size.y) / 2.0 - 2.0
	var inner: float = outer * 0.45
	var points := PackedVector2Array()
	for i in 10:
		var radius: float = outer if i % 2 == 0 else inner
		var angle: float = -PI / 2.0 + i * PI / 5.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, fill_color if filled else empty_color)
	points.append(points[0])
	draw_polyline(points, outline_color, 2.0, true)
