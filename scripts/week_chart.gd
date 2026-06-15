extends Control

const CHART_MAX_HOURS := 16.0
const BOX_GAP := 15.0
const LABEL_HEIGHT := 55.0
const DOT_RADIUS := 6.0
const LABEL_GAP_BASE := 3.0
const CHART_MIN_HEIGHT := 450

signal day_selected(day_key: String)

var _day_keys: Array = []
var _selected_day_key: String = ""
var _label_buttons: Array[Button] = []
var _last_live_minute: int = -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(0, CHART_MIN_HEIGHT)
	set_process(true)


func _process(_delta: float) -> void:
	if not ProductivityData.is_session_active():
		return
	var live_minute := ProductivityData.get_live_session_minutes()
	if live_minute != _last_live_minute:
		_last_live_minute = live_minute
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_rebuild_label_buttons()


func refresh() -> void:
	_day_keys = TimeUtils.get_last_n_productivity_days(7)
	if _selected_day_key.is_empty() and not _day_keys.is_empty():
		_selected_day_key = _day_keys[-1]
	_last_live_minute = -1
	_rebuild_label_buttons()
	queue_redraw()


func set_selected_day(day_key: String) -> void:
	_selected_day_key = day_key
	queue_redraw()


func _rebuild_label_buttons() -> void:
	_clear_label_buttons()
	if _day_keys.is_empty() or size.x <= 1.0:
		return
	var chart_rect := _get_chart_rect()
	var plot_rect := _get_plot_rect(chart_rect)
	var box_width := _get_box_width(plot_rect)
	for i in _day_keys.size():
		var day_key: String = _day_keys[i]
		var button := Button.new()
		button.text = TimeUtils.format_day_label(day_key)
		button.flat = true
		button.focus_mode = Control.FOCUS_NONE
		button.position = Vector2(
			plot_rect.position.x + i * (box_width + BOX_GAP),
			0
		)
		button.size = Vector2(box_width, LABEL_HEIGHT)
		button.add_theme_font_size_override("font_size", _day_label_font_size())
		button.pressed.connect(_on_day_pressed.bind(day_key))
		add_child(button)
		_label_buttons.append(button)
	apply_label_theme()


func _clear_label_buttons() -> void:
	for button in _label_buttons:
		if is_instance_valid(button):
			button.queue_free()
	_label_buttons.clear()
	for child in get_children():
		if child is Button:
			child.queue_free()


func apply_label_theme() -> void:
	var text_color := UiScale.text_color()
	var font_size := _day_label_font_size()
	for button in _label_buttons:
		button.add_theme_color_override("font_color", text_color)
		button.add_theme_color_override("font_hover_color", text_color)
		button.add_theme_color_override("font_pressed_color", text_color)
		button.add_theme_color_override("font_focus_color", text_color)
		button.add_theme_font_size_override("font_size", font_size)


func _on_day_pressed(day_key: String) -> void:
	_selected_day_key = day_key
	queue_redraw()
	day_selected.emit(day_key)


func _get_chart_rect() -> Rect2:
	return Rect2(
		Vector2(0, LABEL_HEIGHT + 10.0),
		Vector2(size.x, maxf(size.y - LABEL_HEIGHT - 10.0, 100.0))
	)


func _get_plot_rect(chart_rect: Rect2) -> Rect2:
	var local_plot := TodayChartStyle.plot_rect_for_size(chart_rect.size)
	return Rect2(chart_rect.position + local_plot.position, local_plot.size)


func _get_box_width(plot_rect: Rect2) -> float:
	if _day_keys.is_empty():
		return 0.0
	var total_gap := BOX_GAP * (_day_keys.size() - 1)
	return (plot_rect.size.x - total_gap) / _day_keys.size()


func _draw() -> void:
	if _day_keys.is_empty():
		return
	var chart_rect := _get_chart_rect()
	var plot_rect := _get_plot_rect(chart_rect)
	var box_width := _get_box_width(plot_rect)
	var line_color := TodayChartStyle.grid_color()
	var connector_color := TodayChartStyle.connector_color()
	var radius := UiScale.scale(DOT_RADIUS)
	var dots: Array = []

	for i in _day_keys.size():
		var day_key: String = _day_keys[i]
		var box_rect := Rect2(
			plot_rect.position.x + i * (box_width + BOX_GAP),
			plot_rect.position.y,
			box_width,
			plot_rect.size.y
		)
		_draw_goal_bands(box_rect)
		_draw_hour_lines(box_rect, line_color)
		var minutes := ProductivityData.get_live_minutes_for_day(day_key)
		var dot_y := _minutes_to_y(minutes, box_rect)
		var dot_center := Vector2(box_rect.position.x + box_rect.size.x * 0.5, dot_y)
		dots.append({
			"center": dot_center,
			"minutes": minutes,
			"color": TodayChartStyle.vertex_color_for_minutes(float(minutes)),
			"box_rect": box_rect,
		})
		if day_key == _selected_day_key:
			var highlight := Color(1, 0.6, 0.2, 0.35)
			draw_rect(box_rect, highlight, false, UiScale.scale(5.0))

	_draw_hour_axis_labels(chart_rect, plot_rect)

	for i in dots.size() - 1:
		var a: Vector2 = dots[i]["center"]
		var b: Vector2 = dots[i + 1]["center"]
		draw_line(a, b, connector_color, UiScale.scale(2.5))

	for dot in dots:
		_draw_vertex_time_label(dot)
		draw_circle(dot["center"], radius, dot["color"])


func _draw_goal_bands(box_rect: Rect2) -> void:
	for band in TodayChartStyle.goal_bands():
		var start_minutes := float(band["start_h"]) * 60.0
		var end_minutes := minf(float(band["end_h"]) * 60.0, CHART_MAX_HOURS * 60.0)
		if end_minutes <= start_minutes:
			continue
		var y_top := _minutes_to_y(int(start_minutes), box_rect)
		var y_bottom := _minutes_to_y(int(end_minutes), box_rect)
		draw_rect(
			Rect2(box_rect.position.x, y_top, box_rect.size.x, y_bottom - y_top),
			TodayChartStyle.band_color(band["color"])
		)


func _draw_hour_axis_labels(chart_rect: Rect2, plot_rect: Rect2) -> void:
	var font := ThemeDB.fallback_font
	var font_size := UiScale.scale_i(11)
	var color := TodayChartStyle.axis_text_color()
	var axis_x := chart_rect.position.x
	for hour in int(CHART_MAX_HOURS) + 1:
		var y := _hours_to_y(float(hour), plot_rect)
		var label := "%dH" % hour
		var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		draw_string(
			font,
			Vector2(axis_x + float(TodayChartStyle.axis_width()) - text_size.x - UiScale.scale(4.0), y + text_size.y * 0.35),
			label,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size,
			color
		)


func _draw_hour_lines(box_rect: Rect2, line_color: Color) -> void:
	for hour in int(CHART_MAX_HOURS) + 1:
		var y := _hours_to_y(float(hour), box_rect)
		draw_line(
			Vector2(box_rect.position.x, y),
			Vector2(box_rect.position.x + box_rect.size.x, y),
			line_color,
			1.0
		)


func _hours_to_y(hours: float, box_rect: Rect2) -> float:
	var ratio := clampf(hours / CHART_MAX_HOURS, 0.0, 1.0)
	return box_rect.position.y + box_rect.size.y * (1.0 - ratio)


func _minutes_to_y(minutes: int, box_rect: Rect2) -> float:
	var hours := float(minutes) / 60.0
	return _hours_to_y(hours, box_rect)


func _draw_vertex_time_label(dot: Dictionary) -> void:
	var center: Vector2 = dot["center"]
	var minutes: int = dot["minutes"]
	var box_rect: Rect2 = dot["box_rect"]
	var radius := UiScale.scale(DOT_RADIUS)
	var label_gap := UiScale.scale(LABEL_GAP_BASE)
	var font := ThemeDB.fallback_font
	var font_size := _vertex_label_font_size()
	var text_color := TodayChartStyle.axis_text_color()
	var label := TimeUtils.format_minutes_hm_compact(float(minutes))
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var label_x := center.x - text_size.x * 0.5
	var desired_baseline := center.y - radius - label_gap
	var min_baseline := box_rect.position.y + label_gap + text_size.y
	var baseline_y := maxf(desired_baseline, min_baseline)
	_draw_outlined_string(font, label, Vector2(label_x, baseline_y), font_size, text_color)


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


func _vertex_label_font_size() -> int:
	var control := TextControl.get_instance()
	if control:
		return maxi(control.week_chart_day_label_font_size() + UiScale.scale_i(1), UiScale.scale_i(10))
	return UiScale.scale_i(11)


func _day_label_font_size() -> int:
	var control := TextControl.get_instance()
	if control:
		return control.week_chart_day_label_font_size()
	return UiScale.scale_i(11)
