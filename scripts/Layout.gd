extends Node
## Autoload singleton ("Layout").
## The single authority for every on-screen coordinate. Everything here is a
## pure function of the visible viewport and the safe area, so the whole layout
## is testable headlessly at any aspect without a device — see tools/smoke_test.gd.
##
## Landscape only. The design box is 1152x648 with stretch mode "canvas_items"
## and aspect "expand", so the design HEIGHT is fixed and the WIDTH grows on
## taller phones (16:9 -> 1152 units, 21:9 -> 1512 units).

const BASE := Vector2(1152, 648)

# Distances from a safe-area edge. Tune these, never the call sites.
const HERO_INSET_R := 232.0     # hero sits this far in from the right safe edge
const STACK_INSET_R := 112.0    # front of the food stack, right-anchored
const SPAWN_INSET_L := 80.0     # monsters enter this far off the left edge
const BELT_INSET_B := 88.0      # food lane, up from the bottom safe edge
const BELT_H := 96.0            # drawn height of the conveyor
const HUD_H := 106.0            # reserved strip at the top for the HUD
const LANE_MARGIN := 24.0       # gap between the monster lanes and HUD/belt
const MAX_FOODS := 6            # fixed on every device, on purpose
const SPACING_MIN := 185.0
const SPACING_MAX := 230.0

# The engine scales the design box by the SMALLER axis ratio and reveals the
# surplus on the other axis. In landscape that is always the height ratio.
static func design_scale(window_px: Vector2, base: Vector2) -> float:
	return minf(window_px.x / base.x, window_px.y / base.y)

static func visible_size(window_px: Vector2, base: Vector2) -> Vector2:
	return window_px / design_scale(window_px, base)

# DisplayServer reports the safe area in PHYSICAL pixels; convert to design units.
static func safe_in_design(safe_px: Rect2, window_px: Vector2, base: Vector2) -> Rect2:
	var s := design_scale(window_px, base)
	return Rect2(safe_px.position / s, safe_px.size / s)

static func compute(view: Vector2, safe: Rect2) -> Dictionary:
	var belt_y: float = safe.end.y - BELT_INSET_B
	var belt_top: float = belt_y - BELT_H * 0.5
	var stack_front_x: float = safe.end.x - STACK_INSET_R
	var spacing: float = clampf((stack_front_x - safe.position.x) / float(MAX_FOODS), SPACING_MIN, SPACING_MAX)
	return {
		"view": view,
		"safe": safe,
		"hero_x": safe.end.x - HERO_INSET_R,
		"hero_y": safe.position.y + (belt_top - safe.position.y) * 0.5,
		"stack_front_x": stack_front_x,
		"stack_spacing": spacing,
		"spawn_x": safe.position.x - SPAWN_INSET_L,
		"belt_y": belt_y,
		"belt_top": belt_top,
		"lane_top": safe.position.y + HUD_H + LANE_MARGIN,
		"lane_bottom": belt_top - LANE_MARGIN,
	}
