extends VBoxContainer
class_name SessionTable

signal session_delete_requested(day_key: String, session_index: int)

const COLUMN_HEADERS := ["Start", "End", "Logged", "Total"]


func build_for_day(day_key: String, include_active: bool = false, body_only: bool = false) -> void:
	_clear_rows()
	if not body_only:
		_add_header_row()
	_build_day_rows(day_key, include_active)


func build_today_body(day_key: String, include_active: bool = false) -> void:
	_clear_rows()
	_build_day_rows(day_key, include_active)


func _build_day_rows(day_key: String, include_active: bool) -> void:
	var sessions := ProductivityData.get_sessions_for_day(day_key)
	for i in sessions.size():
		var session: Dictionary = sessions[i]
		_add_session_row_from_columns(
			day_key,
			i,
			[
				TimeUtils.format_time(TimeUtils.unix_from_iso(str(session.get("start", "")))),
				TimeUtils.format_time(TimeUtils.unix_from_iso(str(session.get("end", "")))),
				TimeUtils.format_minutes_hm(int(session.get("minutes", 0))),
				TimeUtils.format_minutes_hm(int(session.get("cumulative_minutes", 0))),
			],
			true,
			i
		)
	if include_active and ProductivityData.is_session_active():
		var start_unix := ProductivityData.get_session_start_unix()
		var now := int(Time.get_unix_time_from_system())
		var live_minutes := int((now - start_unix) / 60.0)
		var cumulative := ProductivityData.get_live_minutes_for_day(day_key)
		_add_session_row_from_columns(
			day_key,
			-1,
			[
				TimeUtils.format_time(start_unix),
				"...",
				TimeUtils.format_minutes_hm(live_minutes),
				TimeUtils.format_minutes_hm(cumulative),
			],
			false,
			sessions.size()
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
		for i in sessions.size():
			var session: Dictionary = sessions[i]
			_add_session_row_from_columns(
				day_key,
				i,
				[
					TimeUtils.format_time(TimeUtils.unix_from_iso(str(session.get("start", "")))),
					TimeUtils.format_time(TimeUtils.unix_from_iso(str(session.get("end", "")))),
					TimeUtils.format_minutes_hm(int(session.get("minutes", 0))),
					TimeUtils.format_minutes_hm(int(session.get("cumulative_minutes", 0))),
				],
				true,
				i
			)


func _clear_rows() -> void:
	for child in get_children():
		remove_child(child)
		child.free()


func _add_day_separator(day_key: String) -> void:
	var label := Label.new()
	label.text = TimeUtils.format_day_label(day_key)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(label)
	add_child(label)


func _add_header_row() -> void:
	var row := HBoxContainer.new()
	_populate_header_row(row)
	add_child(row)


func build_header_row(target: HBoxContainer) -> void:
	for child in target.get_children():
		child.queue_free()
	_populate_header_row(target)


func _populate_header_row(row: HBoxContainer) -> void:
	row.add_theme_constant_override("separation", UiScale.scale_i(4))
	for header in COLUMN_HEADERS:
		_add_header_label(row, header)


func _add_header_label(row: HBoxContainer, header: String) -> void:
	var label := Label.new()
	label.text = header
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(label)
	row.add_child(label)


func _add_session_row_from_columns(
	day_key: String,
	session_index: int,
	columns: Array,
	deletable: bool,
	stripe_index: int = 0
) -> void:
	var row := SessionRow.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.set_stripe_index(stripe_index)
	row.set_columns(columns)
	row.set_deletable(deletable)
	if deletable and session_index >= 0:
		row.delete_line_clicked.connect(_on_row_delete_line_clicked.bind(day_key, session_index))
	add_child(row)


func _on_row_delete_line_clicked(day_key: String, session_index: int) -> void:
	session_delete_requested.emit(day_key, session_index)


func _style_label(label: Label) -> void:
	var control := TextControl.get_instance()
	var font_size: int = control.session_table_font_size() if control else UiScale.font_size()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", UiScale.text_color())
