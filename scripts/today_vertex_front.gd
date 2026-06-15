extends Control
class_name TodayVertexFront

const SMALL_DOT_RADIUS_BASE := 3.0

var _day_key: String = ""
var _include_live: bool = false
var _scroll_offset_y: float = 0.0
var _content_size: Vector2 = Vector2.ZERO
var _row_centers_y: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 10
	z_as_relative = true
	clip_contents = true


func configure(day_key: String, include_live: bool, row_centers_y: Array = []) -> void:
	_day_key = day_key
	_include_live = include_live
	_row_centers_y = row_centers_y
	queue_redraw()


func set_view(scroll_offset_y: float, viewport_size: Vector2, content_size: Vector2) -> void:
	_scroll_offset_y = scroll_offset_y
	_content_size = content_size
	size = viewport_size
	queue_redraw()


func _draw() -> void:
	if _day_key.is_empty() or size.x <= 1.0 or size.y <= 1.0 or _content_size.y <= 1.0:
		return
	var layout := TodayChartLayout.build(_day_key, _include_live, _content_size, _row_centers_y)
	var points: Array = layout["points"]
	var colors: Array = layout["colors"]
	var row_height := float(layout["row_height"])
	var radius := UiScale.scale(SMALL_DOT_RADIUS_BASE)
	for i in points.size():
		var point: Vector2 = points[i]
		var screen_y := point.y - _scroll_offset_y
		if screen_y < -row_height or screen_y > size.y + row_height:
			continue
		var color: Color = colors[i] if i < colors.size() else TodayChartStyle.vertex_color_for_minutes(0.0)
		draw_circle(Vector2(point.x, screen_y), radius, color)
