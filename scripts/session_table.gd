extends VBoxContainer
class_name SessionTable

signal session_delete_requested(day_key: String, session_index: int)
signal session_insert_requested(day_key: String, session_index: int)
signal session_append_requested(day_key: String, session_index: int)
signal session_edit_requested(day_key: String, session_index: int)

const COLUMN_HEADERS := ["Start", "End", "Logged", "Total"]


func _ready() -> void:
	custom_minimum_size.x = 0
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clip_contents = true


## Keep table width from being driven by cell text (parent column owns width).
## (Cannot call super._get_minimum_size — native VBoxContainer has no GDScript impl.)
func _get_minimum_size() -> Vector2:
	var height := 0.0
	var visible := 0
	for child in get_children():
		if child is Control and child.visible:
			height += child.get_combined_minimum_size().y
			visible += 1
	if visible > 1:
		height += float(get_theme_constant("separation")) * float(visible - 1)
	return Vector2(0.0, height)


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
	var allow_edit := not ProductivityData.is_session_active()
	var last_index := sessions.size() - 1
	for i in sessions.size():
		var session: Dictionary = sessions[i]
		var cumulative := int(session.get("cumulative_minutes", 0))
		_add_session_row_from_columns(
			day_key,
			i,
			[
				TimeUtils.format_time(TimeUtils.unix_from_iso(str(session.get("start", "")))),
				TimeUtils.format_time(TimeUtils.unix_from_iso(str(session.get("end", "")))),
				TimeUtils.format_minutes_hm(int(session.get("minutes", 0))),
				TimeUtils.format_minutes_hm(cumulative),
			],
			true,
			allow_edit,
			i,
			cumulative,
			bool(session.get("edited", false)),
			allow_edit and i == last_index
		)
	var added_live := false
	if include_active and ProductivityData.is_session_active():
		var start_unix := ProductivityData.get_session_start_unix()
		var live_for_day := ProductivityData.get_live_minutes_for_day(day_key)
		if live_for_day > 0 or TimeUtils.get_productivity_day_key(start_unix) == day_key:
			var show_start := start_unix
			if TimeUtils.get_productivity_day_key(start_unix) != day_key:
				show_start = TimeUtils.day_key_to_unix(day_key)
			var live_logged := live_for_day - ProductivityData.get_day_total_minutes(day_key)
			_add_session_row_from_columns(
				day_key,
				-1,
				[
					TimeUtils.format_time(show_start),
					"...",
					TimeUtils.format_minutes_hm(maxi(live_logged, 0)),
					TimeUtils.format_minutes_hm(live_for_day),
				],
				false,
				false,
				sessions.size(),
				live_for_day,
				false,
				false
			)
			added_live = true
	if sessions.is_empty() and not added_live:
		_add_no_data_placeholder()


func _add_no_data_placeholder() -> void:
	var row := Control.new()
	row.name = "NoDataPlaceholder"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.custom_minimum_size = Vector2(0, TodayChartStyle.row_height())
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.text = "no data"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_label(label)
	var muted := UiScale.text_color()
	muted.a = 0.45
	label.add_theme_color_override("font_color", muted)
	row.add_child(label)
	add_child(row)


func _clear_rows() -> void:
	for child in get_children():
		remove_child(child)
		child.free()


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
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.clip_contents = true
	row.custom_minimum_size.x = 0
	for header in COLUMN_HEADERS:
		_add_header_label(row, header)


func _add_header_label(row: HBoxContainer, header: String) -> void:
	var label := Label.new()
	label.text = header
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.custom_minimum_size.x = 0
	_style_label(label)
	row.add_child(label)


func _add_session_row_from_columns(
	day_key: String,
	session_index: int,
	columns: Array,
	deletable: bool,
	editable: bool,
	stripe_index: int = 0,
	tint_minutes: int = -1,
	edited: bool = false,
	appendable: bool = false
) -> void:
	var row := SessionRow.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.custom_minimum_size.x = 0
	row.set_stripe_index(stripe_index)
	if tint_minutes >= 0:
		row.set_tint_minutes(float(tint_minutes))
	row.set_columns(columns)
	row.set_edited(edited)
	row.set_deletable(deletable)
	var can_mutate := editable and deletable and session_index >= 0
	row.set_insertable(can_mutate)
	row.set_editable(can_mutate)
	row.set_appendable(can_mutate and appendable)
	if deletable and session_index >= 0:
		row.delete_line_clicked.connect(_on_row_delete_line_clicked.bind(day_key, session_index))
	if can_mutate:
		row.insert_line_clicked.connect(_on_row_insert_line_clicked.bind(day_key, session_index))
		row.edit_line_clicked.connect(_on_row_edit_line_clicked.bind(day_key, session_index))
	if can_mutate and appendable:
		row.append_line_clicked.connect(_on_row_append_line_clicked.bind(day_key, session_index))
	add_child(row)


func _on_row_delete_line_clicked(day_key: String, session_index: int) -> void:
	session_delete_requested.emit(day_key, session_index)


func _on_row_insert_line_clicked(day_key: String, session_index: int) -> void:
	session_insert_requested.emit(day_key, session_index)


func _on_row_append_line_clicked(day_key: String, session_index: int) -> void:
	session_append_requested.emit(day_key, session_index)


func _on_row_edit_line_clicked(day_key: String, session_index: int) -> void:
	session_edit_requested.emit(day_key, session_index)


func _style_label(label: Label) -> void:
	var control := TextControl.get_instance()
	var font_size: int = control.session_table_font_size() if control else UiScale.font_size()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", UiScale.text_color())
