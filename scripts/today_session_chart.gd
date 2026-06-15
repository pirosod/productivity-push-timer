extends Control
class_name TodaySessionChart

const BAND_MAX_MINUTES := 960
const LARGE_DOT_RADIUS_BASE := 7.0
const MARKER_OVERLAP_OFFSET_BASE := 2.0

var _day_key: String = ""
var _include_live: bool = false
var _row_centers_y: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 0
	set_process(true)


func configure(day_key: String, include_live: bool, row_centers_y: Array = []) -> void:
	_day_key = day_key
	_include_live = include_live
	_row_centers_y = row_centers_y
	queue_redraw()


func _process(_delta: float) -> void:
	if _include_live and ProductivityData.is_session_active():
		queue_redraw()


func _draw() -> void:
	if _day_key.is_empty() or size.x <= 1.0 or size.y <= 1.0:
		return
	var layout := TodayChartLayout.build(_day_key, _include_live, size, _row_centers_y)
	var plot_rect: Rect2 = layout["plot_rect"]
	var max_minutes: int = layout["max_minutes"]
	var points: Array = layout["points"]
	_draw_goal_bands(plot_rect, max_minutes)
	_draw_hour_grid(plot_rect, max_minutes)
	_draw_area_fill(plot_rect, points)
	_draw_connectors(points)
	_draw_large_dots(points, layout["colors"])
	_draw_average_markers(plot_rect, max_minutes)
	_draw_y_axis(plot_rect, max_minutes)


func _draw_goal_bands(plot_rect: Rect2, max_minutes: int) -> void:
	for band in TodayChartStyle.goal_bands():
		var start_minutes := float(band["start_h"]) * 60.0
		var end_minutes := minf(float(band["end_h"]) * 60.0, float(BAND_MAX_MINUTES))
		if end_minutes <= start_minutes:
			continue
		var y_top := TodayChartStyle.minutes_to_y(start_minutes, plot_rect, max_minutes)
		var y_bottom := TodayChartStyle.minutes_to_y(end_minutes, plot_rect, max_minutes)
		var rect := Rect2(
			plot_rect.position.x,
			y_top,
			plot_rect.size.x,
			y_bottom - y_top
		)
		draw_rect(rect, TodayChartStyle.band_color(band["color"]))


func _draw_hour_grid(plot_rect: Rect2, max_minutes: int) -> void:
	var grid_color := TodayChartStyle.grid_color()
	var max_hour := int(ceil(float(max_minutes) / 60.0))
	for hour in max_hour + 1:
		var y := TodayChartStyle.minutes_to_y(float(hour * 60), plot_rect, max_minutes)
		draw_line(
			Vector2(plot_rect.position.x, y),
			Vector2(plot_rect.position.x + plot_rect.size.x, y),
			grid_color,
			1.0
		)


func _draw_y_axis(plot_rect: Rect2, max_minutes: int) -> void:
	var font := ThemeDB.fallback_font
	var font_size := UiScale.scale_i(11)
	var color := TodayChartStyle.axis_text_color()
	var labels: Array = TodayChartStyle.hour_labels(max_minutes)
	for hour in labels.size():
		var y := TodayChartStyle.minutes_to_y(float(hour * 60), plot_rect, max_minutes)
		var label := str(labels[hour])
		var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		draw_string(
			font,
			Vector2(plot_rect.position.x - text_size.x - UiScale.scale(4.0), y + text_size.y * 0.35),
			label,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size,
			color
		)


func _draw_area_fill(plot_rect: Rect2, points: Array) -> void:
	if points.is_empty():
		return
	var fill_color := TodayChartStyle.area_fill_color()
	var polygon: PackedVector2Array = PackedVector2Array()
	polygon.append(Vector2(plot_rect.position.x, plot_rect.position.y + plot_rect.size.y))
	for point in points:
		polygon.append(point)
	var last: Vector2 = points[points.size() - 1]
	polygon.append(Vector2(last.x, plot_rect.position.y + plot_rect.size.y))
	draw_colored_polygon(polygon, fill_color)


func _draw_connectors(points: Array) -> void:
	if points.size() < 2:
		return
	var color := TodayChartStyle.connector_color()
	for i in points.size() - 1:
		draw_line(points[i], points[i + 1], color, 1.5)


func _draw_large_dots(points: Array, colors: Array) -> void:
	var radius := UiScale.scale(LARGE_DOT_RADIUS_BASE)
	for i in points.size():
		var color: Color = colors[i] if i < colors.size() else TodayChartStyle.vertex_color_for_minutes(0.0)
		draw_circle(points[i], radius, color)


func _draw_average_markers(plot_rect: Rect2, max_minutes: int) -> void:
	var marker_control := MarkerControl.get_instance()
	var line_width := marker_control.line_thickness() if marker_control else UiScale.scale(2.0)
	var markers: Array = [
		{
			"minutes": ProductivityData.get_today_average_session_minutes(_day_key, _include_live),
			"color": TodayChartStyle.marker_color(0),
		},
		{
			"minutes": ProductivityData.get_average_session_minutes_from_list(
				ProductivityData.get_week_session_minutes_list()
			),
			"color": TodayChartStyle.marker_color(1),
		},
		{
			"minutes": ProductivityData.get_average_session_minutes_from_list(
				ProductivityData.get_overall_session_minutes_list()
			),
			"color": TodayChartStyle.marker_color(2),
		},
	]
	var top_y := plot_rect.position.y
	var bottom_y := plot_rect.position.y + plot_rect.size.y
	var marker_lines: Array = []
	for marker in markers:
		var avg_minutes := float(marker["minutes"])
		if avg_minutes <= 0.0:
			continue
		marker_lines.append({
			"x": TodayChartStyle.minutes_to_x(avg_minutes, plot_rect, max_minutes),
			"color": marker["color"],
		})
	_apply_marker_overlap_offsets(marker_lines)
	for line in marker_lines:
		var x: float = line["x"]
		var line_color: Color = line["color"]
		draw_line(Vector2(x, top_y), Vector2(x, bottom_y), line_color, line_width)


func _apply_marker_overlap_offsets(marker_lines: Array) -> void:
	if marker_lines.size() < 2:
		return
	var offset := UiScale.scale(MARKER_OVERLAP_OFFSET_BASE)
	marker_lines.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["x"]) < float(b["x"])
	)
	for i in range(1, marker_lines.size()):
		var prev_x := float(marker_lines[i - 1]["x"])
		var x := float(marker_lines[i]["x"])
		if x - prev_x < offset:
			marker_lines[i]["x"] = prev_x + offset
