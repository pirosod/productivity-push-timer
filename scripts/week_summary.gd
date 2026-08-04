extends VBoxContainer
class_name WeekSummaryTable

const COLUMN_HEADERS := ["Week", "Daily Avg", "Week Total"]
const INCOMPLETE_OUTLINE := Color(1.0, 0.55, 0.15, 1.0)
const HOVER_OUTLINE := Color(1.0, 0.88, 0.2, 0.85)
const SELECTED_OUTLINE := Color(1.0, 0.45, 0.05, 1.0)
const ROW_TINT_ALPHA := 0.28
const AVG_BADGE := "Avg"

signal week_selected(week: Dictionary)

var _selected_monday_key: String = ""
var _hovered_monday_key: String = ""
var _row_panels: Dictionary = {}  # monday_key -> PanelContainer
var _week_by_monday: Dictionary = {}  # monday_key -> week dict
var _row_fx: Dictionary = {}  # monday_key -> ElectricityRowOverlay


func refresh() -> void:
	_hovered_monday_key = ""
	_row_panels.clear()
	_week_by_monday.clear()
	_row_fx.clear()
	_clear_rows()
	_add_header_row()
	for week in _build_weeks_newest_first():
		_add_data_row(week)
	_apply_all_row_styles()
	_refresh_row_electricity()


func set_selected_monday(monday_key: String) -> void:
	_selected_monday_key = monday_key
	_apply_all_row_styles()


func clear_week_selection() -> void:
	_selected_monday_key = ""
	_hovered_monday_key = ""
	_apply_all_row_styles()


func get_selected_monday() -> String:
	return _selected_monday_key


func get_week_for_monday(monday_key: String) -> Dictionary:
	return _week_by_monday.get(monday_key, {})


func _refresh_row_electricity() -> void:
	for monday_key in _row_fx.keys():
		var week: Dictionary = _week_by_monday.get(monday_key, {})
		var overlay: ElectricityRowOverlay = _row_fx[monday_key]
		if not is_instance_valid(overlay):
			continue
		var yellow := (
			not week.is_empty()
			and TodayChartStyle.is_yellow_band(float(week.get("daily_avg_minutes", 0)))
		)
		overlay.set_active(yellow)

func _build_weeks_newest_first() -> Array:
	var today_key := TimeUtils.get_productivity_day_key_now()
	var all_keys: Array = ProductivityData.get_all_day_keys_sorted()
	var first_data_key := today_key
	if not all_keys.is_empty():
		first_data_key = str(all_keys[0])
		if today_key < first_data_key:
			first_data_key = today_key
	var first_monday := TimeUtils.monday_key_for_day(first_data_key)
	var current_monday := TimeUtils.monday_key_for_day(today_key)
	var weeks: Array = []
	var monday := first_monday
	var week_number := 1
	while monday <= current_monday:
		weeks.append(_make_week_entry(week_number, monday, first_data_key, today_key, current_monday))
		week_number += 1
		monday = TimeUtils.add_days_to_day_key(monday, 7)
	weeks.reverse()
	return weeks


func _make_week_entry(
	week_number: int,
	monday_key: String,
	first_data_key: String,
	today_key: String,
	current_monday: String
) -> Dictionary:
	var sunday_key := TimeUtils.add_days_to_day_key(monday_key, 6)
	var is_first_partial := monday_key == TimeUtils.monday_key_for_day(first_data_key) and first_data_key != monday_key
	var is_current := monday_key == current_monday
	var is_incomplete := is_first_partial or is_current
	var range_start := monday_key
	var range_end := sunday_key
	if is_first_partial:
		range_start = first_data_key
	if is_current:
		range_end = today_key
	if range_end < range_start:
		range_end = range_start
	var total_minutes := 0
	var day_count := 0
	var cursor := range_start
	while cursor <= range_end:
		total_minutes += ProductivityData.get_live_minutes_for_day(cursor)
		day_count += 1
		cursor = TimeUtils.next_day_key(cursor)
	var daily_avg_minutes: int
	var week_total_minutes: int
	var is_extrapolated := false
	if is_incomplete:
		day_count = maxi(day_count, 1)
		daily_avg_minutes = int(round(float(total_minutes) / float(day_count)))
		week_total_minutes = int(round(float(daily_avg_minutes) * 7.0))
		is_extrapolated = true
	else:
		total_minutes = 0
		for day_key in TimeUtils.week_day_keys(monday_key):
			total_minutes += ProductivityData.get_live_minutes_for_day(str(day_key))
		daily_avg_minutes = int(round(float(total_minutes) / 7.0))
		week_total_minutes = total_minutes
	return {
		"week_number": week_number,
		"monday_key": monday_key,
		"sunday_key": sunday_key,
		"first_data_key": first_data_key,
		"daily_avg_minutes": daily_avg_minutes,
		"week_total_minutes": week_total_minutes,
		"is_incomplete": is_incomplete,
		"is_extrapolated": is_extrapolated,
		"is_current": is_current,
		"is_first_partial": is_first_partial,
	}


func _clear_rows() -> void:
	for child in get_children():
		remove_child(child)
		child.free()


func _add_header_row() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiScale.scale_i(4))
	row.custom_minimum_size.y = TodayChartStyle.row_height()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for header in COLUMN_HEADERS:
		_add_plain_cell(row, header, true)
	add_child(row)


func _add_data_row(week: Dictionary) -> void:
	var monday_key := str(week["monday_key"])
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.set_meta("monday_key", monday_key)
	panel.gui_input.connect(_on_row_gui_input.bind(monday_key))
	panel.mouse_entered.connect(_on_row_mouse_entered.bind(monday_key))
	panel.mouse_exited.connect(_on_row_mouse_exited.bind(monday_key))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", UiScale.scale_i(4))
	row.custom_minimum_size.y = TodayChartStyle.row_height()
	_add_week_cell(row, week)
	_add_plain_cell(row, TimeUtils.format_minutes_hm(int(week["daily_avg_minutes"])), false)
	_add_total_cell(
		row,
		TimeUtils.format_minutes_hm(int(week["week_total_minutes"])),
		bool(week["is_extrapolated"])
	)
	var stack := Control.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.custom_minimum_size.y = TodayChartStyle.row_height()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.add_child(row)
	var overlay := ElectricityRowOverlay.new()
	stack.add_child(overlay)
	panel.add_child(stack)
	_row_fx[monday_key] = overlay
	add_child(panel)
	_row_panels[monday_key] = panel
	_week_by_monday[monday_key] = week
	panel.add_theme_stylebox_override("panel", _make_row_style(week, false, false))


func _on_row_mouse_entered(monday_key: String) -> void:
	_hovered_monday_key = monday_key
	_apply_all_row_styles()


func _on_row_mouse_exited(monday_key: String) -> void:
	if _hovered_monday_key == monday_key:
		_hovered_monday_key = ""
		_apply_all_row_styles()


func _on_row_gui_input(event: InputEvent, monday_key: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var week: Dictionary = _week_by_monday.get(monday_key, {})
		if week.is_empty():
			return
		# Defer so the clicked row isn't freed mid-input when the table refreshes.
		call_deferred("_emit_week_selected", week.duplicate())


func _emit_week_selected(week: Dictionary) -> void:
	week_selected.emit(week)


func _apply_all_row_styles() -> void:
	for monday_key in _row_panels.keys():
		var key := str(monday_key)
		var panel = _row_panels[monday_key]
		if not is_instance_valid(panel):
			continue
		var week: Dictionary = _week_by_monday.get(monday_key, {})
		if week.is_empty():
			continue
		var selected: bool = key == _selected_monday_key
		var hovered: bool = key == _hovered_monday_key and not selected
		panel.add_theme_stylebox_override("panel", _make_row_style(week, hovered, selected))


func _add_week_cell(row: HBoxContainer, week: Dictionary) -> void:
	var cell := HBoxContainer.new()
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.add_theme_constant_override("separation", UiScale.scale_i(6))
	cell.alignment = BoxContainer.ALIGNMENT_CENTER
	var number := Label.new()
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	number.text = "%d" % int(week["week_number"])
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	number.custom_minimum_size.x = UiScale.scale(28)
	_style_label(number, false)
	cell.add_child(number)
	var dates := Label.new()
	dates.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var start := TimeUtils.parse_day_key(str(week["monday_key"]))
	var end := TimeUtils.parse_day_key(str(week["sunday_key"]))
	dates.text = "%02d/%02d - %02d/%02d" % [
		int(start.day),
		int(start.month),
		int(end.day),
		int(end.month),
	]
	dates.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	dates.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_style_label(dates, false)
	cell.add_child(dates)
	row.add_child(cell)


func _make_row_style(week: Dictionary, hovered: bool, selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var tint := TodayChartStyle.vertex_color_for_minutes(float(week["daily_avg_minutes"]))
	tint.a = ROW_TINT_ALPHA
	style.bg_color = tint
	var border := UiScale.scale_i(2)
	if selected:
		border = UiScale.scale_i(4)
		style.border_color = SELECTED_OUTLINE
		style.border_width_left = border
		style.border_width_top = border
		style.border_width_right = border
		style.border_width_bottom = border
	elif hovered:
		border = UiScale.scale_i(3)
		style.border_color = HOVER_OUTLINE
		style.border_width_left = border
		style.border_width_top = border
		style.border_width_right = border
		style.border_width_bottom = border
	elif bool(week["is_incomplete"]):
		style.border_color = INCOMPLETE_OUTLINE
		style.border_width_left = border
		style.border_width_top = border
		style.border_width_right = border
		style.border_width_bottom = border
	else:
		style.border_color = Color(0, 0, 0, 0)
		style.border_width_left = 0
		style.border_width_top = 0
		style.border_width_right = 0
		style.border_width_bottom = 0
	style.set_corner_radius_all(UiScale.scale_i(3))
	var pad := UiScale.scale_i(2)
	style.content_margin_left = pad
	style.content_margin_top = pad
	style.content_margin_right = pad
	style.content_margin_bottom = pad
	return style


func _add_plain_cell(row: HBoxContainer, text: String, is_header: bool) -> void:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_style_label(label, is_header)
	row.add_child(label)


func _add_total_cell(row: HBoxContainer, text: String, show_avg_badge: bool) -> void:
	var cell := Control.new()
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.custom_minimum_size.y = TodayChartStyle.row_height()
	var value := Label.new()
	value.text = text
	value.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_label(value, false)
	cell.add_child(value)
	if show_avg_badge:
		var badge := Label.new()
		badge.text = AVG_BADGE
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		badge.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		badge.grow_vertical = Control.GROW_DIRECTION_BEGIN
		badge.offset_left = UiScale.scale(-28)
		badge.offset_top = UiScale.scale(-14)
		badge.offset_right = UiScale.scale(-2)
		badge.offset_bottom = UiScale.scale(-1)
		_style_avg_badge(badge)
		cell.add_child(badge)
	row.add_child(cell)


func _style_label(label: Label, is_header: bool) -> void:
	var control := TextControl.get_instance()
	var font_size: int = control.session_table_font_size() if control else UiScale.font_size()
	if is_header:
		font_size = maxi(font_size, UiScale.scale_i(12))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", UiScale.text_color())


func _style_avg_badge(label: Label) -> void:
	var font_size := UiScale.scale_i(9)
	label.add_theme_font_size_override("font_size", font_size)
	var badge_color := UiScale.text_color()
	badge_color.a = 0.7
	label.add_theme_color_override("font_color", badge_color)
