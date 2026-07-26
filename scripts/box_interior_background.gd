extends Control

## White/black (or history sepia) feather pattern shown through the translucent
## panel fill of Today / Week Summary / Week by Week boxes.

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var dark := TodayChartStyle.is_dark_mode()
	var history := TodayChartStyle.history_mode
	var base := Color.BLACK if dark else Color.WHITE
	if history and not dark:
		base = Color(0.93, 0.86, 0.72)
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
		var shade := Color(0.35, 0.22, 0.08, alpha) if history and not dark else Color(0, 0, 0, alpha)
		draw_rect(top, shade)
		draw_rect(bottom, shade)
		draw_rect(left, shade)
		draw_rect(right, shade)
	if history and not dark:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.55, 0.38, 0.18, 0.12))
