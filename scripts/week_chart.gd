extends Control

const CHART_MAX_HOURS := 16.0
const BOX_GAP := 15.0
const LABEL_HEIGHT := 55.0
const DOT_RADIUS := 10.0
const CHART_MIN_HEIGHT := 450

signal day_selected(day_key: String)

var _day_keys: Array = []
var _selected_day_key: String = ""
var _label_buttons: Array[Button] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(0, CHART_MIN_HEIGHT)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_rebuild_label_buttons()


func refresh() -> void:
	_day_keys = TimeUtils.get_last_n_productivity_days(7)
	if _selected_day_key.is_empty() and not _day_keys.is_empty():
		_selected_day_key = _day_keys[-1]
	_rebuild_label_buttons()
	queue_redraw()


func set_selected_day(day_key: String) -> void:
	_selected_day_key = day_key
	queue_redraw()


func _rebuild_label_buttons() -> void:
	for button in _label_buttons:
		button.queue_free()
	_label_buttons.clear()
	if _day_keys.is_empty():
		return
	var chart_rect := _get_chart_rect()
	var box_width := _get_box_width(chart_rect)
	for i in _day_keys.size():
		var day_key: String = _day_keys[i]
		var button := Button.new()
		button.text = TimeUtils.format_day_label(day_key)
		button.flat = true
		button.focus_mode = Control.FOCUS_NONE
		button.position = Vector2(
			chart_rect.position.x + i * (box_width + BOX_GAP),
			0
		)
		button.size = Vector2(box_width, LABEL_HEIGHT)
		button.add_theme_font_size_override("font_size", _day_label_font_size())
		button.pressed.connect(_on_day_pressed.bind(day_key))
		add_child(button)
		_label_buttons.append(button)
	apply_label_theme()


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


func _get_box_width(chart_rect: Rect2) -> float:
	if _day_keys.is_empty():
		return 0.0
	var total_gap := BOX_GAP * (_day_keys.size() - 1)
	return (chart_rect.size.x - total_gap) / _day_keys.size()


func _draw() -> void:
	if _day_keys.is_empty():
		return
	var is_dark := ProductivityData.is_session_active()
	var chart_rect := _get_chart_rect()
	var box_width := _get_box_width(chart_rect)
	var line_color := Color(1, 1, 1, 0.12) if is_dark else Color(0, 0, 0, 0.12)
	var dot_color := Color.WHITE if is_dark else Color.BLACK
	var connector_color := dot_color
	connector_color.a = 0.75

	var dot_centers: Array[Vector2] = []

	for i in _day_keys.size():
		var day_key: String = _day_keys[i]
		var box_rect := Rect2(
			chart_rect.position.x + i * (box_width + BOX_GAP),
			chart_rect.position.y,
			box_width,
			chart_rect.size.y
		)
		_draw_goal_bands(box_rect)
		_draw_hour_lines(box_rect, line_color)
		var minutes := ProductivityData.get_live_minutes_for_day(day_key)
		var dot_y := _minutes_to_y(minutes, box_rect)
		var dot_center := Vector2(box_rect.position.x + box_rect.size.x * 0.5, dot_y)
		dot_centers.append(dot_center)
		if day_key == _selected_day_key:
			var highlight := Color(1, 0.6, 0.2, 0.35)
			draw_rect(box_rect, highlight, false, 5.0)

	for i in dot_centers.size() - 1:
		draw_line(dot_centers[i], dot_centers[i + 1], connector_color, 5.0)

	for center in dot_centers:
		draw_circle(center, DOT_RADIUS, dot_color)


func _draw_goal_bands(box_rect: Rect2) -> void:
	var low_end := _hours_to_y(ProductivityData.low_goal_hours, box_rect)
	var medium_end := _hours_to_y(ProductivityData.medium_goal_hours, box_rect)
	var high_end := _hours_to_y(ProductivityData.high_goal_hours, box_rect)
	var bottom := box_rect.position.y + box_rect.size.y
	draw_rect(
		Rect2(box_rect.position.x, low_end, box_rect.size.x, bottom - low_end),
		ProductivityData.low_goal_color
	)
	draw_rect(
		Rect2(box_rect.position.x, medium_end, box_rect.size.x, low_end - medium_end),
		ProductivityData.medium_goal_color
	)
	draw_rect(
		Rect2(box_rect.position.x, high_end, box_rect.size.x, medium_end - high_end),
		ProductivityData.high_goal_color
	)


func _draw_hour_lines(box_rect: Rect2, line_color: Color) -> void:
	for hour in int(CHART_MAX_HOURS) + 1:
		var y := _hours_to_y(float(hour), box_rect)
		draw_line(
			Vector2(box_rect.position.x, y),
			Vector2(box_rect.position.x + box_rect.size.x, y),
			line_color,
			2.5
		)


func _hours_to_y(hours: float, box_rect: Rect2) -> float:
	var ratio := clampf(hours / CHART_MAX_HOURS, 0.0, 1.0)
	return box_rect.position.y + box_rect.size.y * (1.0 - ratio)


func _minutes_to_y(minutes: int, box_rect: Rect2) -> float:
	var hours := float(minutes) / 60.0
	return _hours_to_y(hours, box_rect)


func _day_label_font_size() -> int:
	var control := TextControl.get_instance()
	if control:
		return control.week_chart_day_label_font_size()
	return UiScale.scale_i(11)
