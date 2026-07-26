extends Control

## Soft outer shadow that hugs the Today box's rounded top or bottom edge.
## Uses an outside SDF so the arc matches the panel border (not a mirrored cut).

const MAX_HEIGHT_PX := 20.0
const SAMPLE_STEP := 1.0

## When true, shade the bottom edge (fade downward). Otherwise the top edge.
@export var bottom_edge := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 10


func _draw() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return
	if bottom_edge:
		_draw_bottom_edge()
	else:
		_draw_top_edge()


func _draw_top_edge() -> void:
	var radius := float(TodayChartStyle.panel_corner_radius())
	var panel_top := MAX_HEIGHT_PX
	var panel_rect := Rect2(0.0, panel_top, size.x, 4000.0)
	var max_dist := MAX_HEIGHT_PX
	var y := 0.0
	while y < panel_top:
		var dist := panel_top - y
		if dist <= max_dist:
			var t := clampf(dist / max_dist, 0.0, 1.0)
			var alpha := lerpf(0.28, 0.0, pow(t, 0.65))
			if alpha > 0.001:
				var flat_x := radius
				var flat_w := size.x - radius * 2.0
				if flat_w > 0.0:
					draw_rect(
						Rect2(flat_x, y, flat_w, SAMPLE_STEP + 0.5),
						Color(0.0, 0.0, 0.0, alpha)
					)
		y += SAMPLE_STEP
	_draw_corner_band(true, panel_rect, radius, max_dist, true)
	_draw_corner_band(false, panel_rect, radius, max_dist, true)


func _draw_bottom_edge() -> void:
	var radius := float(TodayChartStyle.panel_corner_radius())
	var panel_bottom := size.y - MAX_HEIGHT_PX
	# Tall panel above the bottom edge so only the bottom matter for the SDF.
	var panel_rect := Rect2(0.0, panel_bottom - 4000.0, size.x, 4000.0)
	var max_dist := MAX_HEIGHT_PX
	var y := panel_bottom
	while y < size.y:
		var dist := y - panel_bottom
		if dist <= max_dist:
			var t := clampf(dist / max_dist, 0.0, 1.0)
			var alpha := lerpf(0.28, 0.0, pow(t, 0.65))
			if alpha > 0.001:
				var flat_x := radius
				var flat_w := size.x - radius * 2.0
				if flat_w > 0.0:
					draw_rect(
						Rect2(flat_x, y, flat_w, SAMPLE_STEP + 0.5),
						Color(0.0, 0.0, 0.0, alpha)
					)
		y += SAMPLE_STEP
	_draw_corner_band(true, panel_rect, radius, max_dist, false)
	_draw_corner_band(false, panel_rect, radius, max_dist, false)


func _draw_corner_band(
	left: bool, panel_rect: Rect2, radius: float, max_dist: float, top_edge: bool
) -> void:
	var band_w := radius + max_dist + 1.0
	var x0 := 0.0 if left else maxf(size.x - band_w, 0.0)
	var x1 := minf(band_w, size.x) if left else size.x
	var y := 0.0
	while y < size.y:
		var x := x0
		while x < x1:
			var dist := _sd_rounded_rect(Vector2(x + 0.5, y + 0.5), panel_rect, radius)
			if dist > 0.0 and dist <= max_dist:
				var on_flat := false
				if top_edge:
					on_flat = (
						y < MAX_HEIGHT_PX
						and x + 0.5 >= radius
						and x + 0.5 <= size.x - radius
					)
				else:
					on_flat = (
						y > size.y - MAX_HEIGHT_PX
						and x + 0.5 >= radius
						and x + 0.5 <= size.x - radius
					)
				if not on_flat:
					var t := clampf(dist / max_dist, 0.0, 1.0)
					var alpha := lerpf(0.28, 0.0, pow(t, 0.65))
					if alpha > 0.001:
						draw_rect(
							Rect2(x, y, SAMPLE_STEP + 0.5, SAMPLE_STEP + 0.5),
							Color(0.0, 0.0, 0.0, alpha)
						)
			x += SAMPLE_STEP
		y += SAMPLE_STEP


## Signed distance to a rounded rectangle. Positive = outside.
func _sd_rounded_rect(point: Vector2, rect: Rect2, radius: float) -> float:
	var half := rect.size * 0.5
	var center := rect.position + half
	var local := point - center
	var r := minf(radius, minf(half.x, half.y))
	var q := Vector2(absf(local.x), absf(local.y)) - half + Vector2(r, r)
	var outside := Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length()
	return outside + minf(maxf(q.x, q.y), 0.0) - r
