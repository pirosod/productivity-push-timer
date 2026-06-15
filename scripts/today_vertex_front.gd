extends Control
class_name TodayVertexFront

const SMALL_DOT_RADIUS_BASE := 3.0
const LABEL_GAP_BASE := 3.0

var _day_key: String = ""
var _include_live: bool = false
var _last_live_minute: int = -1
var _scroll_offset_y: float = 0.0
var _content_size: Vector2 = Vector2.ZERO
var _row_centers_y: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 10
	z_as_relative = true
	clip_contents = true
	set_process(true)


func configure(day_key: String, include_live: bool, row_centers_y: Array = []) -> void:
	_day_key = day_key
	_include_live = include_live
	_row_centers_y = row_centers_y
	_last_live_minute = -1
	queue_redraw()


func set_view(scroll_offset_y: float, viewport_size: Vector2, content_size: Vector2) -> void:
	_scroll_offset_y = scroll_offset_y
	_content_size = content_size
	size = viewport_size
	queue_redraw()


func _process(_delta: float) -> void:
	if not _include_live or not ProductivityData.is_session_active():
		return
	var live_minute := ProductivityData.get_live_session_minutes()
	if live_minute != _last_live_minute:
		_last_live_minute = live_minute
		queue_redraw()


func _draw() -> void:
	if _day_key.is_empty() or size.x <= 1.0 or size.y <= 1.0 or _content_size.y <= 1.0:
		return
	var layout := TodayChartLayout.build(_day_key, _include_live, _content_size, _row_centers_y)
	var points: Array = layout["points"]
	var colors: Array = layout["colors"]
	var logged_list: Array = layout["logged_list"]
	var row_height := float(layout["row_height"])
	var radius := UiScale.scale(SMALL_DOT_RADIUS_BASE)
	var font := ThemeDB.fallback_font
	var font_size := _label_font_size()
	var text_color := TodayChartStyle.axis_text_color()
	var label_gap := UiScale.scale(LABEL_GAP_BASE)
	for i in points.size():
		var point: Vector2 = points[i]
		var screen_y := point.y - _scroll_offset_y
		if screen_y < -row_height or screen_y > size.y + row_height:
			continue
		var screen_point := Vector2(point.x, screen_y)
		var color: Color = colors[i] if i < colors.size() else TodayChartStyle.vertex_color_for_minutes(0.0)
		var logged_minutes := float(logged_list[i]) if i < logged_list.size() else 0.0
		var label := TimeUtils.format_minutes_hm_compact(logged_minutes)
		var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var row_top := screen_y - row_height * 0.5
		var label_x := screen_point.x - text_size.x * 0.5
		var desired_baseline := screen_point.y - radius - label_gap
		var min_baseline := row_top + label_gap + text_size.y
		var max_baseline := row_top + row_height - label_gap
		var baseline_y := clampf(desired_baseline, min_baseline, max_baseline)
		_draw_outlined_string(font, label, Vector2(label_x, baseline_y), font_size, text_color)
		draw_circle(screen_point, radius, color)


func _draw_outlined_string(
	font: Font,
	text: String,
	position: Vector2,
	font_size: int,
	color: Color
) -> void:
	var outline := Color(0, 0, 0, 0.6) if color.get_luminance() > 0.45 else Color(1, 1, 1, 0.6)
	for offset in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		draw_string(
			font,
			position + offset,
			text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size,
			outline
		)
	draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _label_font_size() -> int:
	var control := TextControl.get_instance()
	if control:
		return maxi(control.session_table_font_size() - UiScale.scale_i(1), UiScale.scale_i(11))
	return UiScale.scale_i(12)
