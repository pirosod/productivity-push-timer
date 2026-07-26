extends Control
class_name AddSessionEditor

signal cancelled
signal save_pressed(start_unix: int, end_unix: int)
signal close_requested

enum Mode { ADD, EDIT }

var _mode: Mode = Mode.ADD
var _day_key: String = ""
var _gap_start: int = 0
var _gap_end: int = 0
var _tracks_now := false
var _lock_start := false
var _append_mode := false
var _last_bound_minute := -1
var _backdrop: ColorRect
var _panel: PanelContainer
var _title: Label
var _start_label: Label
var _end_label: Label
var _start_picker: TimeDigitPicker
var _end_picker: TimeDigitPicker
var _save_button: Button
var _cancel_button: Button
var _built := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_ensure_built()
	visible = false
	set_process(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not visible:
		set_process(false)


func _process(_delta: float) -> void:
	if not visible or not _tracks_now:
		set_process(false)
		return
	var now_unix := int(Time.get_unix_time_from_system())
	var minute := int(now_unix / 60)
	if minute == _last_bound_minute:
		return
	_last_bound_minute = minute
	_gap_end = now_unix - (now_unix % 60)
	_sync_dependent_bounds()


func _ensure_built() -> void:
	if _built:
		return
	_built = true

	_backdrop = ColorRect.new()
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(0.12, 0.12, 0.12, 0.72)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.gui_input.connect(_on_backdrop_gui_input)
	add_child(_backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.custom_minimum_size = Vector2(UiScale.scale(460), UiScale.scale(240))
	_apply_panel_style()
	center.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", UiScale.scale_i(28))
	margin.add_theme_constant_override("margin_top", UiScale.scale_i(22))
	margin.add_theme_constant_override("margin_right", UiScale.scale_i(28))
	margin.add_theme_constant_override("margin_bottom", UiScale.scale_i(22))
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UiScale.scale_i(18))
	margin.add_child(vbox)

	_title = Label.new()
	_title.text = "Add session entry"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(_title, 16)
	vbox.add_child(_title)

	var pickers_row := HBoxContainer.new()
	pickers_row.alignment = BoxContainer.ALIGNMENT_CENTER
	pickers_row.add_theme_constant_override("separation", UiScale.scale_i(36))
	vbox.add_child(pickers_row)

	var start_col := _make_picker_column("Start")
	_start_label = start_col["label"] as Label
	_start_picker = TimeDigitPicker.new()
	_start_picker.time_changed.connect(_on_start_changed)
	(start_col["box"] as VBoxContainer).add_child(_start_picker)
	pickers_row.add_child(start_col["box"])

	var end_col := _make_picker_column("End")
	_end_label = end_col["label"] as Label
	_end_picker = TimeDigitPicker.new()
	_end_picker.time_changed.connect(_on_end_changed)
	(end_col["box"] as VBoxContainer).add_child(_end_picker)
	pickers_row.add_child(end_col["box"])

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", UiScale.scale_i(20))
	vbox.add_child(buttons)

	_save_button = Button.new()
	_save_button.text = "Save"
	_save_button.pressed.connect(_on_save_pressed)
	buttons.add_child(_save_button)

	_cancel_button = Button.new()
	_cancel_button.text = "Cancel"
	_cancel_button.pressed.connect(_on_cancel_pressed)
	buttons.add_child(_cancel_button)


func open_for_gap(
	day_key: String,
	gap_start: int,
	gap_end: int,
	tracks_now: bool = false,
	lock_start: bool = false,
	append_mode: bool = false
) -> void:
	_ensure_built()
	_mode = Mode.ADD
	_day_key = day_key
	_gap_start = gap_start
	_gap_end = gap_end
	_tracks_now = tracks_now
	_lock_start = lock_start
	_append_mode = append_mode
	_title.text = "Add session entry"
	_start_picker.clear_logged_time_range()
	_end_picker.clear_logged_time_range()
	var default_start := gap_start
	# Unlocked start may go up to one minute before gap_end (e.g. 23:58 when end is 23:59).
	var start_max := gap_start if _lock_start else maxi(gap_end - 60, gap_start)
	var default_end: int
	if _lock_start or _append_mode:
		# Append after: end defaults to +1 minute (start may still scroll).
		default_end = mini(gap_start + 60, gap_end)
		if default_end <= default_start:
			default_end = gap_end
	else:
		# Insert above: start at prev end / 00:00; end at minute before current row.
		default_end = gap_end
	_start_picker.configure(day_key, default_start, gap_start, start_max)
	_end_picker.configure(
		day_key,
		default_end,
		mini(default_start + 60, gap_end),
		gap_end
	)
	_sync_dependent_bounds()
	apply_theme()
	visible = true
	move_to_front()
	if _tracks_now:
		_last_bound_minute = int(Time.get_unix_time_from_system() / 60)
		set_process(true)
	else:
		set_process(false)


func open_for_edit(
	day_key: String,
	min_start: int,
	max_end: int,
	original_start: int,
	original_end: int,
	tracks_now: bool = false
) -> void:
	_ensure_built()
	_mode = Mode.EDIT
	_day_key = day_key
	_gap_start = min_start
	_gap_end = max_end
	_tracks_now = tracks_now
	_lock_start = false
	_append_mode = false
	_title.text = "Modify entry"
	_start_picker.set_logged_time_range(original_start, original_end)
	_end_picker.set_logged_time_range(original_start, original_end)
	_start_picker.configure(
		day_key,
		original_start,
		min_start,
		maxi(max_end - 60, min_start)
	)
	_end_picker.configure(
		day_key,
		original_end,
		mini(original_start + 60, max_end),
		max_end
	)
	_sync_dependent_bounds()
	apply_theme()
	visible = true
	move_to_front()
	if _tracks_now:
		_last_bound_minute = int(Time.get_unix_time_from_system() / 60)
		set_process(true)
	else:
		set_process(false)


func is_edit_mode() -> bool:
	return _mode == Mode.EDIT


func apply_theme() -> void:
	_ensure_built()
	_apply_panel_style()
	_style_label(_title, 16)
	_style_label(_start_label, 14)
	_style_label(_end_label, 14)
	_style_button(_save_button)
	_style_button(_cancel_button)
	for child in get_children():
		_apply_theme_recursive(child, UiScale.text_color())


func get_start_unix() -> int:
	return _start_picker.get_unix()


func get_end_unix() -> int:
	return _end_picker.get_unix()


func _make_picker_column(caption: String) -> Dictionary:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UiScale.scale_i(8))
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var label := Label.new()
	label.text = caption
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(label, 14)
	box.add_child(label)
	return {"box": box, "label": label}


func _apply_panel_style() -> void:
	TodayChartStyle.apply_popup_box(_panel)
	_panel.custom_minimum_size = Vector2(UiScale.scale(460), UiScale.scale(240))


func _on_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close_requested.emit()
		accept_event()


func _on_start_changed(_unix: int) -> void:
	_sync_dependent_bounds()


func _on_end_changed(_unix: int) -> void:
	_sync_dependent_bounds()


func _sync_dependent_bounds() -> void:
	var start_unix := _start_picker.get_unix()
	var start_max := _gap_start if _lock_start else maxi(_gap_end - 60, _gap_start)
	_start_picker.set_bounds(_gap_start, start_max)
	start_unix = _start_picker.get_unix()
	var end_min := mini(start_unix + 60, _gap_end)
	_end_picker.set_bounds(end_min, _gap_end)
	var end_unix := _end_picker.get_unix()
	if end_unix <= start_unix:
		_end_picker.configure(_day_key, end_min, end_min, _gap_end)


func _on_save_pressed() -> void:
	_sync_dependent_bounds()
	var start_unix := _start_picker.get_unix()
	var end_unix := _end_picker.get_unix()
	if end_unix <= start_unix:
		return
	save_pressed.emit(start_unix, end_unix)


func _on_cancel_pressed() -> void:
	visible = false
	set_process(false)
	cancelled.emit()


func _style_label(label: Label, base_size: int) -> void:
	label.add_theme_font_size_override("font_size", UiScale.font_size(base_size))
	label.add_theme_color_override("font_color", UiScale.text_color())


func _style_button(button: Button) -> void:
	var text_color := UiScale.text_color()
	var font_size := UiScale.font_size(14)
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color)
	button.add_theme_color_override("font_pressed_color", text_color)
	button.add_theme_color_override("font_focus_color", text_color)
	button.add_theme_font_size_override("font_size", font_size)


func _apply_theme_recursive(node: Node, text_color: Color) -> void:
	if node is Label:
		(node as Label).add_theme_color_override("font_color", text_color)
	for child in node.get_children():
		_apply_theme_recursive(child, text_color)
