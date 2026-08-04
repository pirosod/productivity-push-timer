extends Control

const CHART_MAX_HOURS := 16.0
const BOX_GAP := 15.0
const LABEL_HEIGHT := 55.0
const DOT_RADIUS := 6.0
const LABEL_GAP_BASE := 3.0
const CHART_MIN_HEIGHT := 450
const HOVER_OUTLINE := Color(1.0, 0.88, 0.2, 0.55)
const SELECTED_OUTLINE := Color(1.0, 0.6, 0.2, 0.85)
const TODAY_HOVER_OUTLINE := Color(0.35, 0.85, 0.45, 0.49)
const TODAY_SELECTED_OUTLINE := Color(0.2, 0.72, 0.32, 0.56)
const PREV_WEEK_SEPIA := Color(0.52, 0.4, 0.26, 0.14)
const WEEK_BOUNDARY_COLOR := Color(1.0, 0.5, 0.08, 0.95)
const LOCKED_FILL := Color(0.45, 0.45, 0.45, 0.18)
const LOCKED_DOT := Color(0.55, 0.55, 0.55, 0.45)

signal day_selected(day_key: String)

var _day_keys: Array = []
var _selected_day_key: String = ""
var _hovered_day_key: String = ""
var _label_buttons: Array[Button] = []
var _last_live_minute: int = -1
var _label_layout_signature: String = ""
## Empty = rolling last-7-days mode. Set = Mon–Sun calendar week.
var _calendar_monday_key: String = ""
## Days strictly before this key are greyscale / non-interactive (first partial week).
var _locked_before_key: String = ""
var _fx := YellowElectricityFx.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	custom_minimum_size = Vector2(0, CHART_MIN_HEIGHT)
	set_process(true)


func _process(delta: float) -> void:
	var ctrl := ElectricityControl.get_instance()
	var need_redraw := false
	if ProductivityData.is_session_active():
		var live_minute := ProductivityData.get_live_session_minutes()
		if live_minute != _last_live_minute:
			_last_live_minute = live_minute
			need_redraw = true
	if ctrl != null and ctrl.is_on() and not _day_keys.is_empty():
		_sync_electricity_targets()
		_fx.process(delta, ctrl)
		need_redraw = true
	elif not _fx.has_activity():
		_fx.clear()
		need_redraw = true
	if need_redraw:
		queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_rebuild_label_buttons()
	elif what == NOTIFICATION_MOUSE_EXIT:
		if not _hovered_day_key.is_empty():
			_hovered_day_key = ""
			queue_redraw()


func is_calendar_week_mode() -> bool:
	return not _calendar_monday_key.is_empty()


func set_rolling_mode() -> void:
	_calendar_monday_key = ""
	_locked_before_key = ""
	refresh()


func set_calendar_week(monday_key: String, locked_before_key: String = "") -> void:
	_calendar_monday_key = monday_key
	_locked_before_key = locked_before_key
	refresh()


func refresh() -> void:
	var new_day_keys: Array
	if _calendar_monday_key.is_empty():
		new_day_keys = TimeUtils.get_last_n_productivity_days(7)
	else:
		new_day_keys = TimeUtils.week_day_keys(_calendar_monday_key)
	if new_day_keys != _day_keys:
		_label_layout_signature = ""
	_day_keys = new_day_keys
	if _selected_day_key.is_empty() and not _day_keys.is_empty():
		_selected_day_key = _day_keys[-1]
	_last_live_minute = -1
	_rebuild_label_buttons()
	queue_redraw()


func set_selected_day(day_key: String) -> void:
	_selected_day_key = day_key
	queue_redraw()


func _is_day_locked(day_key: String) -> bool:
	return not _locked_before_key.is_empty() and day_key < _locked_before_key


func _is_idle_today_context() -> bool:
	if not _calendar_monday_key.is_empty():
		return false
	var today := TimeUtils.get_productivity_day_key_now()
	return _selected_day_key == today


func _rebuild_label_buttons() -> void:
	if _day_keys.is_empty() or size.x <= 1.0:
		_clear_label_buttons()
		return
	var chart_rect := _get_chart_rect()
	var plot_rect := _get_plot_rect(chart_rect)
	var box_width := _get_box_width(plot_rect)
	var signature := _build_label_layout_signature(plot_rect, box_width)
	if signature == _label_layout_signature and not _label_buttons.is_empty():
		_apply_label_button_layout(plot_rect, box_width)
		apply_label_theme()
		return
	_label_layout_signature = signature
	_clear_label_buttons()
	for i in _day_keys.size():
		var day_key: String = _day_keys[i]
		var locked := _is_day_locked(day_key)
		var button := Button.new()
		button.text = TimeUtils.format_day_label(day_key)
		button.flat = true
		button.focus_mode = Control.FOCUS_NONE
		button.disabled = locked
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE if locked else Control.MOUSE_FILTER_STOP
		button.mouse_default_cursor_shape = (
			Control.CURSOR_ARROW if locked else Control.CURSOR_POINTING_HAND
		)
		button.position = Vector2(
			plot_rect.position.x + i * (box_width + BOX_GAP),
			0
		)
		button.size = Vector2(box_width, LABEL_HEIGHT)
		if not locked:
			button.pressed.connect(_on_day_pressed.bind(day_key))
			button.mouse_entered.connect(_set_hovered_day.bind(day_key))
			button.mouse_exited.connect(_on_label_mouse_exited.bind(day_key))
		add_child(button)
		_label_buttons.append(button)
	_apply_label_button_layout(plot_rect, box_width)
	apply_label_theme()


func _build_label_layout_signature(plot_rect: Rect2, box_width: float) -> String:
	return "%s|%s|%s|%s|%.2f|%.2f" % [
		"|".join(_day_keys),
		_selected_day_key,
		_calendar_monday_key,
		_locked_before_key,
		plot_rect.position.x,
		box_width,
	]


func _apply_label_button_layout(plot_rect: Rect2, box_width: float) -> void:
	for i in _label_buttons.size():
		if i >= _day_keys.size():
			break
		var button: Button = _label_buttons[i]
		button.position = Vector2(
			plot_rect.position.x + i * (box_width + BOX_GAP),
			0
		)
		button.size = Vector2(box_width, LABEL_HEIGHT)


func _clear_label_buttons() -> void:
	for button in _label_buttons:
		if is_instance_valid(button):
			remove_child(button)
			button.free()
	_label_buttons.clear()


func apply_label_theme() -> void:
	var text_color := UiScale.text_color()
	var font_size := _day_label_font_size()
	var bold_font := _day_label_font()
	for i in _label_buttons.size():
		var button: Button = _label_buttons[i]
		if not is_instance_valid(button):
			continue
		var locked := i < _day_keys.size() and _is_day_locked(str(_day_keys[i]))
		var color := text_color
		if locked:
			color = Color(text_color.r, text_color.g, text_color.b, 0.35)
		button.add_theme_color_override("font_color", color)
		button.add_theme_color_override("font_hover_color", color)
		button.add_theme_color_override("font_pressed_color", color)
		button.add_theme_color_override("font_focus_color", color)
		button.add_theme_color_override("font_disabled_color", color)
		button.add_theme_font_size_override("font_size", font_size)
		if bold_font != null:
			button.add_theme_font_override("font", bold_font)


func _on_day_pressed(day_key: String) -> void:
	if _is_day_locked(day_key):
		return
	_selected_day_key = day_key
	queue_redraw()
	day_selected.emit(day_key)


func _set_hovered_day(day_key: String) -> void:
	if _is_day_locked(day_key):
		return
	if _hovered_day_key == day_key:
		return
	_hovered_day_key = day_key
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	queue_redraw()


func _on_label_mouse_exited(day_key: String) -> void:
	if _hovered_day_key != day_key:
		return
	var local := get_local_mouse_position()
	var under := _day_key_at_position(local)
	if under.is_empty():
		_hovered_day_key = ""
		mouse_default_cursor_shape = Control.CURSOR_ARROW
	else:
		_hovered_day_key = under
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var day_key := _day_key_at_position(event.position)
		if day_key.is_empty():
			if not _hovered_day_key.is_empty():
				_hovered_day_key = ""
				mouse_default_cursor_shape = Control.CURSOR_ARROW
				queue_redraw()
		else:
			_set_hovered_day(day_key)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var day_key := _day_key_at_position(event.position)
		if not day_key.is_empty():
			_on_day_pressed(day_key)
			accept_event()


func _day_key_at_position(local_pos: Vector2) -> String:
	if _day_keys.is_empty():
		return ""
	var chart_rect := _get_chart_rect()
	var plot_rect := _get_plot_rect(chart_rect)
	var box_width := _get_box_width(plot_rect)
	for i in _day_keys.size():
		var column := _column_rect(i, plot_rect, box_width)
		if column.has_point(local_pos):
			var day_key := str(_day_keys[i])
			if _is_day_locked(day_key):
				return ""
			return day_key
	return ""


func _column_rect(index: int, plot_rect: Rect2, box_width: float) -> Rect2:
	var x := plot_rect.position.x + float(index) * (box_width + BOX_GAP)
	var bottom := plot_rect.position.y + plot_rect.size.y
	return Rect2(x, 0.0, box_width, bottom)


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


## Index of the first day that belongs to the newest calendar week in rolling mode.
func _current_week_start_index() -> int:
	if _day_keys.is_empty() or not _calendar_monday_key.is_empty():
		return -1
	var latest := str(_day_keys[_day_keys.size() - 1])
	var current_monday := TimeUtils.monday_key_for_day(latest)
	for i in _day_keys.size():
		if str(_day_keys[i]) >= current_monday:
			return i
	return -1


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
	var week_split := _current_week_start_index()
	var idle_today := _is_idle_today_context()
	var today_key := TimeUtils.get_productivity_day_key_now()

	for i in _day_keys.size():
		var day_key: String = _day_keys[i]
		var locked := _is_day_locked(day_key)
		var box_rect := Rect2(
			plot_rect.position.x + i * (box_width + BOX_GAP),
			plot_rect.position.y,
			box_width,
			plot_rect.size.y
		)
		var column_rect := _column_rect(i, plot_rect, box_width)
		# Light sepia on rolling-mode days that belong to the previous calendar week.
		if week_split > 0 and i < week_split:
			draw_rect(column_rect, PREV_WEEK_SEPIA, true)
		if locked:
			draw_rect(column_rect, LOCKED_FILL, true)
		_draw_goal_bands(box_rect)
		_draw_hour_lines(box_rect, line_color)
		var minutes := 0 if locked else ProductivityData.get_live_minutes_for_day(day_key)
		var dot_y := _minutes_to_y(minutes, box_rect)
		var dot_center := Vector2(box_rect.position.x + box_rect.size.x * 0.5, dot_y)
		var dot_color := LOCKED_DOT if locked else TodayChartStyle.vertex_color_for_minutes(float(minutes))
		if locked:
			dot_color.a = minf(dot_color.a, 0.4)
		dots.append({
			"center": dot_center,
			"minutes": minutes,
			"color": dot_color,
			"box_rect": box_rect,
			"locked": locked,
		})
		if not locked and day_key == _hovered_day_key and day_key != _selected_day_key:
			var hover: Color = TODAY_HOVER_OUTLINE if (idle_today and day_key == today_key) else HOVER_OUTLINE
			draw_rect(box_rect, hover, false, UiScale.scale(4.0))
		if not locked and day_key == _selected_day_key:
			var selected: Color = (
				TODAY_SELECTED_OUTLINE if (idle_today and day_key == today_key) else SELECTED_OUTLINE
			)
			draw_rect(box_rect, selected, false, UiScale.scale(5.0))

	if week_split > 0:
		_draw_week_boundary_bar(week_split, plot_rect, box_width, chart_rect)

	_draw_hour_axis_labels(chart_rect, plot_rect)

	for i in dots.size() - 1:
		if bool(dots[i]["locked"]) or bool(dots[i + 1]["locked"]):
			continue
		var a: Vector2 = dots[i]["center"]
		var b: Vector2 = dots[i + 1]["center"]
		draw_line(a, b, connector_color, UiScale.scale(2.5))

	for dot in dots:
		if not bool(dot["locked"]):
			_draw_vertex_time_label(dot)
		draw_circle(dot["center"], radius, dot["color"])

	var ctrl := ElectricityControl.get_instance()
	if ctrl != null and ctrl.is_on():
		_fx.draw(self, ctrl)


func _sync_electricity_targets() -> void:
	var entries: Array = []
	var view := Rect2(Vector2.ZERO, size).grow(UiScale.scale(4.0))
	var chart_rect := _get_chart_rect()
	var plot_rect := _get_plot_rect(chart_rect)
	var box_width := _get_box_width(plot_rect)
	var radius := UiScale.scale(DOT_RADIUS)
	var yellow_dots: Array = []

	for i in _day_keys.size():
		var day_key: String = _day_keys[i]
		if _is_day_locked(day_key):
			continue
		var minutes := ProductivityData.get_live_minutes_for_day(day_key)
		if not TodayChartStyle.is_yellow_band(float(minutes)):
			continue
		var box_rect := Rect2(
			plot_rect.position.x + i * (box_width + BOX_GAP),
			plot_rect.position.y,
			box_width,
			plot_rect.size.y
		)
		var band := _yellow_band_rect(box_rect)
		var center := Vector2(box_rect.position.x + box_rect.size.x * 0.5, _minutes_to_y(minutes, box_rect))
		var band_visible := view.intersects(band)
		var dot_visible := view.has_point(center) or band_visible
		entries.append({
			"id": "band_%s" % day_key,
			"kind": "band",
			"rect": band,
			"visible": band_visible,
			"weight": 0.65,
		})
		entries.append({
			"id": "dot_%s" % day_key,
			"kind": "dot",
			"center": center,
			"radius": radius * 2.6,
			"visible": dot_visible,
			"weight": 1.5,
		})
		yellow_dots.append({"key": day_key, "i": i, "center": center, "visible": dot_visible})

	for n in yellow_dots.size() - 1:
		var a: Dictionary = yellow_dots[n]
		var b: Dictionary = yellow_dots[n + 1]
		if int(a["i"]) + 1 != int(b["i"]):
			continue
		entries.append({
			"id": "path_%s_%s" % [str(a["key"]), str(b["key"])],
			"kind": "path",
			"points": PackedVector2Array([a["center"], b["center"]]),
			"visible": bool(a["visible"]) or bool(b["visible"]),
			"weight": 0.8,
		})
	_fx.sync_targets(entries)


func _yellow_band_rect(box_rect: Rect2) -> Rect2:
	var y_top := _hours_to_y(ProductivityData.high_goal_hours, box_rect)
	var y_bottom := _hours_to_y(ProductivityData.medium_goal_hours, box_rect)
	return Rect2(
		box_rect.position.x,
		y_top,
		box_rect.size.x,
		maxf(y_bottom - y_top, 1.0)
	)


func _draw_week_boundary_bar(
	split_index: int, plot_rect: Rect2, box_width: float, chart_rect: Rect2
) -> void:
	if split_index <= 0 or split_index >= _day_keys.size():
		return
	var left_col := _column_rect(split_index - 1, plot_rect, box_width)
	var right_col := _column_rect(split_index, plot_rect, box_width)
	var gap_left := left_col.position.x + left_col.size.x
	var gap_right := right_col.position.x
	var bar_w := maxf(UiScale.scale(4.0), (gap_right - gap_left) * 0.45)
	var bar_x := (gap_left + gap_right) * 0.5 - bar_w * 0.5
	var bar_top := 0.0
	var bar_bottom := chart_rect.position.y + chart_rect.size.y
	draw_rect(Rect2(bar_x, bar_top, bar_w, bar_bottom - bar_top), WEEK_BOUNDARY_COLOR, true)


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


func _day_label_font() -> Font:
	var variation := FontVariation.new()
	variation.base_font = ThemeDB.fallback_font
	variation.variation_embolden = 0.7
	return variation
