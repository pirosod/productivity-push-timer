extends VBoxContainer
class_name SessionTable

const COLUMN_HEADERS := ["Start", "End", "Logged", "Total"]


func build_for_day(day_key: String, include_active: bool = false) -> void:
	_clear_rows()
	_add_header_row()
	var sessions := ProductivityData.get_sessions_for_day(day_key)
	for session in sessions:
		_add_session_row(
			TimeUtils.format_time(TimeUtils.unix_from_iso(str(session.get("start", "")))),
			TimeUtils.format_time(TimeUtils.unix_from_iso(str(session.get("end", "")))),
			TimeUtils.format_minutes_hm(int(session.get("minutes", 0))),
			TimeUtils.format_minutes_hm(int(session.get("cumulative_minutes", 0)))
		)
	if include_active and ProductivityData.is_session_active():
		var start_unix := ProductivityData.get_session_start_unix()
		var now := int(Time.get_unix_time_from_system())
		var live_minutes := int((now - start_unix) / 60.0)
		var cumulative := ProductivityData.get_live_minutes_for_day(day_key)
		_add_session_row(
			TimeUtils.format_time(start_unix),
			"...",
			TimeUtils.format_minutes_hm(live_minutes),
			TimeUtils.format_minutes_hm(cumulative)
		)


func build_history() -> void:
	_clear_rows()
	var today_key := TimeUtils.get_productivity_day_key_now()
	var day_keys := ProductivityData.get_all_day_keys_sorted()
	for day_key in day_keys:
		if day_key == today_key:
			continue
		_add_day_separator(day_key)
		_add_header_row()
		var sessions := ProductivityData.get_sessions_for_day(day_key)
		for session in sessions:
			_add_session_row(
				TimeUtils.format_time(TimeUtils.unix_from_iso(str(session.get("start", "")))),
				TimeUtils.format_time(TimeUtils.unix_from_iso(str(session.get("end", "")))),
				TimeUtils.format_minutes_hm(int(session.get("minutes", 0))),
				TimeUtils.format_minutes_hm(int(session.get("cumulative_minutes", 0)))
			)


func _clear_rows() -> void:
	for child in get_children():
		child.queue_free()


func _add_day_separator(day_key: String) -> void:
	var label := Label.new()
	label.text = TimeUtils.format_day_label(day_key)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(label)
	add_child(label)


func _add_header_row() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiScale.scale_i(4))
	for header in COLUMN_HEADERS:
		var label := Label.new()
		label.text = header
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_style_label(label)
		row.add_child(label)
	add_child(row)


func _add_session_row(
	start_text: String,
	end_text: String,
	logged_text: String,
	total_text: String
) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiScale.scale_i(4))
	for value in [start_text, end_text, logged_text, total_text]:
		var label := Label.new()
		label.text = value
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_style_label(label)
		row.add_child(label)
	add_child(row)


func _style_label(label: Label) -> void:
	var control := TextControl.get_instance()
	var font_size: int = control.session_table_font_size() if control else UiScale.font_size()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", UiScale.text_color())
