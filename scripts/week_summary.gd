extends VBoxContainer
class_name WeekSummaryTable

const COLUMN_HEADERS := ["Week", "Daily Avg", "Week Total"]


func refresh() -> void:
	_clear_rows()
	_add_header_row()
	_add_current_week_row()


func _add_current_week_row() -> void:
	var day_keys: Array = TimeUtils.get_last_n_productivity_days(7)
	var total_minutes := 0
	for day_key in day_keys:
		total_minutes += ProductivityData.get_live_minutes_for_day(str(day_key))
	var daily_avg_minutes := int(round(float(total_minutes) / 7.0))
	_add_data_row(
		_format_week_range(day_keys),
		TimeUtils.format_minutes_hm(daily_avg_minutes),
		TimeUtils.format_minutes_hm(total_minutes)
	)


func _format_week_range(day_keys: Array) -> String:
	if day_keys.is_empty():
		return "This week"
	var first: Dictionary = TimeUtils.parse_day_key(str(day_keys[0]))
	var last: Dictionary = TimeUtils.parse_day_key(str(day_keys[-1]))
	return "%d/%d - %d/%d" % [first.day, first.month, last.day, last.month]


func _clear_rows() -> void:
	for child in get_children():
		remove_child(child)
		child.free()


func _add_header_row() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiScale.scale_i(4))
	for header in COLUMN_HEADERS:
		_add_cell(row, header, true)
	add_child(row)


func _add_data_row(week_label: String, daily_avg: String, week_total: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiScale.scale_i(4))
	_add_cell(row, week_label, false)
	_add_cell(row, daily_avg, false)
	_add_cell(row, week_total, false)
	add_child(row)


func _add_cell(row: HBoxContainer, text: String, is_header: bool) -> void:
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(label, is_header)
	row.add_child(label)


func _style_label(label: Label, is_header: bool) -> void:
	var control := TextControl.get_instance()
	var font_size: int = control.session_table_font_size() if control else UiScale.font_size()
	if is_header:
		font_size = maxi(font_size, UiScale.scale_i(12))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", UiScale.text_color())
