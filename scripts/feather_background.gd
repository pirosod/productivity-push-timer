extends ColorRect

var is_dark_mode := false


func _draw() -> void:
	var base := Color.BLACK if is_dark_mode else Color.WHITE
	draw_rect(Rect2(Vector2.ZERO, size), base)
	var bands := 28
	for i in bands:
		var t := float(i) / float(bands)
		var alpha := (1.0 - t) * 0.11
		var margin := t * minf(size.x, size.y) * 0.5
		var thickness := UiScale.scale(2.0)
		var top := Rect2(0, margin, size.x, thickness)
		var bottom := Rect2(0, size.y - margin - thickness, size.x, thickness)
		var left := Rect2(margin, 0, thickness, size.y)
		var right := Rect2(size.x - margin - thickness, 0, thickness, size.y)
		var shade := Color(0, 0, 0, alpha)
		draw_rect(top, shade)
		draw_rect(bottom, shade)
		draw_rect(left, shade)
		draw_rect(right, shade)
