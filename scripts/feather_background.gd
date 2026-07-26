extends ColorRect

var is_dark_mode := false
var is_history_mode := false


func _draw() -> void:
	# Match FixedHeader / Push–Snooze fill. Box interiors keep their own feather bg.
	draw_rect(Rect2(Vector2.ZERO, size), TodayChartStyle.panel_grey_opaque())
