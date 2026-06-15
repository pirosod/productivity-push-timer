extends Control

const IDLE_INTERVAL_SECONDS := 20.0 * 60.0
const SNOOZE_SECONDS := 60.0 * 60.0

@onready var _background: ColorRect = $FeatherBackground
@onready var _main_scroll: ScrollContainer = $MainScroll
@onready var _content: VBoxContainer = $MainScroll/Content
@onready var _push_button: Button = $MainScroll/Content/Header/PushButton
@onready var _timer_label: Label = $MainScroll/Content/Header/TimerLabel
@onready var _snooze_button: Button = $MainScroll/Content/Header/SnoozeButton
@onready var _history_past: VBoxContainer = $MainScroll/Content/HistoryPast
@onready var _today_table_frame = $MainScroll/Content/TodaySection/TodayTableFrame
@onready var _today_marker_legend: TodayMarkerLegend = (
	$MainScroll/Content/TodaySection/MarkerRow/TodayMarkerLegend
)
@onready var _history_tab: Button = $MainScroll/Content/HistoryTab
@onready var _week_chart: Control = $MainScroll/Content/WeekChart
@onready var _goal_row: HBoxContainer = $MainScroll/Content/GoalRow
@onready var _selected_day_label: Label = $MainScroll/Content/SelectedDayLabel
@onready var _selected_day_table: VBoxContainer = $MainScroll/Content/SelectedDayTable
@onready var _popup_layer: CanvasLayer = $PopupLayer
@onready var _popup_panel: PanelContainer = $PopupLayer/PopupPanel
@onready var _popup_close: Button = $PopupLayer/PopupPanel/Margin/VBox/CloseButton
@onready var _boink: Node = $BoinkSound
@onready var _text_control: TextControl = $"AppControls/Text control"
@onready var _marker_control: MarkerControl = $"AppControls/Marker control"
@onready var _today_header: Label = $MainScroll/Content/TodaySection/TodayHeader
@onready var _popup_message: Label = $PopupLayer/PopupPanel/Margin/VBox/Message
@onready var _delete_popup_panel: PanelContainer = $PopupLayer/DeletePopupPanel
@onready var _delete_popup_message: Label = $PopupLayer/DeletePopupPanel/Margin/VBox/Message
@onready var _delete_yes_button: Button = $PopupLayer/DeletePopupPanel/Margin/VBox/Buttons/YesButton
@onready var _delete_no_button: Button = $PopupLayer/DeletePopupPanel/Margin/VBox/Buttons/NoButton

var _history_enabled := false
var _idle_seconds_left := IDLE_INTERVAL_SECONDS
var _idle_paused := false
var _snooze_until_unix := 0
var _popup_visible := false
var _delete_popup_visible := false
var _selected_chart_day := ""
var _closing := false
var _pending_delete_day_key := ""
var _pending_delete_index := -1


func _ready() -> void:
	_apply_window_settings()
	_push_button.pressed.connect(_on_push_pressed)
	_snooze_button.pressed.connect(_on_snooze_pressed)
	_history_tab.pressed.connect(_on_history_tab_pressed)
	_popup_close.pressed.connect(_hide_popup)
	_delete_yes_button.pressed.connect(_on_delete_yes_pressed)
	_delete_no_button.pressed.connect(_on_delete_no_pressed)
	_today_table_frame.session_delete_requested.connect(_on_session_delete_requested)
	_selected_day_table.session_delete_requested.connect(_on_session_delete_requested)
	_week_chart.day_selected.connect(_on_chart_day_selected)
	_text_control.sizes_changed.connect(_on_text_sizes_changed)
	_marker_control.sizes_changed.connect(_on_marker_sizes_changed)
	_setup_goal_pickers()
	_timer_label.add_theme_font_size_override("font_size", _text_control.timer_font_size())
	_popup_layer.visible = false
	_popup_panel.visible = false
	_delete_popup_panel.visible = false
	_history_past.visible = false
	_connect_window_close()
	_refresh_ui()
	call_deferred("_scroll_to_today")


func _connect_window_close() -> void:
	var window: Window = get_window()
	if not window.close_requested.is_connected(_on_window_close_requested):
		window.close_requested.connect(_on_window_close_requested)


func _on_window_close_requested() -> void:
	if _closing:
		return
	_closing = true
	_save_window_settings()
	ProductivityData.save_data()
	get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_on_window_close_requested()


func _process(_delta: float) -> void:
	if ProductivityData.is_session_active():
		_update_timer_label()
		_refresh_today_table()
		_refresh_selected_day_table()
		_week_chart.queue_redraw()
	elif _idle_paused:
		pass
	else:
		_update_idle_timer(_delta)


func _apply_window_settings() -> void:
	var settings := ProductivityData.get_window_settings()
	var window := get_window()
	var saved_width: int = int(settings.get("width", ProductivityData.DEFAULT_WINDOW_WIDTH))
	var saved_height: int = int(settings.get("height", ProductivityData.DEFAULT_WINDOW_HEIGHT))
	var width: int = saved_width
	var height: int = saved_height
	if width == ProductivityData.LEGACY_WINDOW_WIDTH:
		width = ProductivityData.DEFAULT_WINDOW_WIDTH
	if height == ProductivityData.LEGACY_WINDOW_HEIGHT:
		height = ProductivityData.DEFAULT_WINDOW_HEIGHT
	if width < 600 and height < 700:
		width = ProductivityData.DEFAULT_WINDOW_WIDTH
		height = ProductivityData.DEFAULT_WINDOW_HEIGHT
	elif height <= UiScale.scale_i(420):
		height = ProductivityData.DEFAULT_WINDOW_HEIGHT
	window.size = Vector2i(width, height)
	window.position = Vector2i(int(settings.get("x", 100)), int(settings.get("y", 100)))
	if width != saved_width or height != saved_height:
		ProductivityData.set_window_settings(window.position.x, window.position.y, width, height)


func _save_window_settings() -> void:
	var window := get_window()
	ProductivityData.set_window_settings(
		window.position.x,
		window.position.y,
		window.size.x,
		window.size.y
	)
	ProductivityData.save_data()


func _setup_goal_pickers() -> void:
	_add_goal_picker("Low", ProductivityData.low_goal_color, "low")
	_add_goal_picker("Med", ProductivityData.medium_goal_color, "medium")
	_add_goal_picker("High", ProductivityData.high_goal_color, "high")
	_add_goal_display("V High", TodayChartStyle.VHIGH_COLOR)
	_add_goal_display("Extreme", TodayChartStyle.EXTREME_COLOR)


func _add_goal_display(label_text: String, color: Color) -> void:
	var box := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", _text_control.goal_label_font_size())
	label.add_theme_color_override("font_color", UiScale.text_color())
	box.add_child(label)
	var picker := ColorPickerButton.new()
	picker.color = color
	picker.custom_minimum_size = Vector2(UiScale.scale_i(28), UiScale.scale_i(20))
	picker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picker.focus_mode = Control.FOCUS_NONE
	box.add_child(picker)
	_goal_row.add_child(box)


func _add_goal_picker(label_text: String, color: Color, which: String) -> void:
	var box := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", _text_control.goal_label_font_size())
	label.add_theme_color_override("font_color", UiScale.text_color())
	box.add_child(label)
	var picker := ColorPickerButton.new()
	picker.color = color
	picker.custom_minimum_size = Vector2(UiScale.scale_i(28), UiScale.scale_i(20))
	picker.color_changed.connect(func(new_color: Color) -> void:
		ProductivityData.update_goal_color(which, new_color)
		_week_chart.queue_redraw()
		_today_table_frame.refresh_appearance()
	)
	box.add_child(picker)
	_goal_row.add_child(box)


func _on_push_pressed() -> void:
	if ProductivityData.is_session_active():
		ProductivityData.end_session()
		_idle_paused = false
		_idle_seconds_left = IDLE_INTERVAL_SECONDS
	else:
		ProductivityData.start_session()
		_idle_paused = true
		_hide_popup()
	_refresh_ui()


func _on_snooze_pressed() -> void:
	if ProductivityData.is_session_active():
		return
	_snooze_until_unix = int(Time.get_unix_time_from_system()) + int(SNOOZE_SECONDS)
	_hide_popup()


func _on_history_tab_pressed() -> void:
	_history_enabled = not _history_enabled
	_history_past.visible = _history_enabled
	_history_tab.text = "Hide History" if _history_enabled else "Show History"
	if _history_enabled:
		_build_history_past()
		call_deferred("_scroll_to_today")


func _on_text_sizes_changed() -> void:
	_refresh_ui()


func _on_marker_sizes_changed() -> void:
	_today_table_frame.refresh_appearance()


func _on_chart_day_selected(day_key: String) -> void:
	_selected_chart_day = day_key
	_refresh_selected_day_table()


func _update_idle_timer(delta: float) -> void:
	var now := int(Time.get_unix_time_from_system())
	if now < _snooze_until_unix:
		return
	_idle_seconds_left -= delta
	if _idle_seconds_left <= 0.0:
		_trigger_idle_alert()
		_idle_seconds_left = IDLE_INTERVAL_SECONDS


func _trigger_idle_alert() -> void:
	_boink.play_boink()
	DisplayServer.window_request_attention()
	_show_popup()


func _show_popup() -> void:
	_delete_popup_panel.visible = false
	_delete_popup_visible = false
	_popup_layer.visible = true
	_popup_visible = true
	_popup_panel.visible = true


func _hide_popup() -> void:
	_popup_visible = false
	_popup_panel.visible = false
	if not _delete_popup_visible:
		_popup_layer.visible = false


func _show_delete_popup(day_key: String, session_index: int) -> void:
	_pending_delete_day_key = day_key
	_pending_delete_index = session_index
	_popup_panel.visible = false
	_popup_visible = false
	_popup_layer.visible = true
	_delete_popup_panel.visible = true
	_delete_popup_visible = true


func _hide_delete_popup() -> void:
	_delete_popup_visible = false
	_delete_popup_panel.visible = false
	_pending_delete_day_key = ""
	_pending_delete_index = -1
	if not _popup_visible:
		_popup_layer.visible = false


func _on_session_delete_requested(day_key: String, session_index: int) -> void:
	_show_delete_popup(day_key, session_index)


func _on_delete_yes_pressed() -> void:
	if not _pending_delete_day_key.is_empty() and _pending_delete_index >= 0:
		ProductivityData.delete_session(_pending_delete_day_key, _pending_delete_index)
		_refresh_ui()
	_hide_delete_popup()


func _on_delete_no_pressed() -> void:
	_hide_delete_popup()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_P:
			_trigger_idle_alert()
			return
	if _delete_popup_visible:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if not _delete_popup_panel.get_global_rect().has_point(event.global_position):
				_hide_delete_popup()
		return
	if not _popup_visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not _popup_panel.get_global_rect().has_point(event.global_position):
			_hide_popup()


func _refresh_ui() -> void:
	_update_timer_label()
	_refresh_today_table()
	_build_history_past_if_needed()
	_week_chart.refresh()
	if _selected_chart_day.is_empty():
		_selected_chart_day = TimeUtils.get_productivity_day_key_now()
	_week_chart.set_selected_day(_selected_chart_day)
	_refresh_selected_day_table()
	_apply_theme_mode()


func _apply_theme_mode() -> void:
	var is_dark := ProductivityData.is_session_active()
	_background.is_dark_mode = is_dark
	_background.queue_redraw()
	var text_color := UiScale.text_color()
	_apply_button_theme(_push_button, text_color, _text_control.push_button_font_size())
	_apply_button_theme(_snooze_button, text_color, _text_control.snooze_button_font_size())
	_apply_button_theme(_popup_close, text_color, _text_control.popup_button_font_size())
	_apply_button_theme(_delete_yes_button, text_color, _text_control.popup_button_font_size())
	_apply_button_theme(_delete_no_button, text_color, _text_control.popup_button_font_size())
	_apply_button_theme(_history_tab, text_color, _text_control.history_tab_font_size())
	_timer_label.add_theme_color_override("font_color", text_color)
	_timer_label.add_theme_font_size_override("font_size", _text_control.timer_font_size())
	_today_header.add_theme_color_override("font_color", text_color)
	_today_header.add_theme_font_size_override("font_size", _text_control.today_header_font_size())
	_selected_day_label.add_theme_color_override("font_color", text_color)
	_selected_day_label.add_theme_font_size_override(
		"font_size", _text_control.selected_day_label_font_size()
	)
	_popup_message.add_theme_color_override("font_color", text_color)
	_popup_message.add_theme_font_size_override("font_size", _text_control.popup_message_font_size())
	_delete_popup_message.add_theme_color_override("font_color", text_color)
	_delete_popup_message.add_theme_font_size_override("font_size", _text_control.popup_message_font_size())
	_apply_history_header_fonts(text_color)
	_apply_goal_label_fonts(text_color)
	_week_chart.apply_label_theme()
	_today_table_frame.refresh_appearance()
	_today_marker_legend.refresh()
	_push_button.button_pressed = is_dark
	_snooze_button.disabled = is_dark


func _apply_button_theme(button: Button, text_color: Color, font_size: int) -> void:
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color)
	button.add_theme_color_override("font_pressed_color", text_color)
	button.add_theme_color_override("font_focus_color", text_color)
	button.add_theme_color_override("font_disabled_color", text_color)
	button.add_theme_font_size_override("font_size", font_size)


func _apply_goal_label_fonts(text_color: Color) -> void:
	for box in _goal_row.get_children():
		if box is HBoxContainer:
			for child in box.get_children():
				if child is Label:
					child.add_theme_color_override("font_color", text_color)
					child.add_theme_font_size_override("font_size", _text_control.goal_label_font_size())


func _apply_history_header_fonts(text_color: Color) -> void:
	for section in _history_past.get_children():
		for child in section.get_children():
			if child is Label:
				child.add_theme_color_override("font_color", text_color)
				child.add_theme_font_size_override(
					"font_size", _text_control.history_day_header_font_size()
				)


func _update_timer_label() -> void:
	if ProductivityData.is_session_active():
		var minutes := ProductivityData.get_live_session_minutes()
		_timer_label.text = TimeUtils.format_minutes_hm(minutes)
	else:
		_timer_label.text = "00:00"


func _refresh_today_table() -> void:
	var today_key := TimeUtils.get_productivity_day_key_now()
	_today_table_frame.build_for_day(today_key, true)
	_today_marker_legend.configure(today_key, true)


func _refresh_selected_day_table() -> void:
	if _selected_chart_day.is_empty():
		_selected_chart_day = TimeUtils.get_productivity_day_key_now()
	_selected_day_label.text = TimeUtils.format_day_label(_selected_chart_day)
	var is_today := _selected_chart_day == TimeUtils.get_productivity_day_key_now()
	_selected_day_table.build_for_day(_selected_chart_day, is_today)


func _build_history_past_if_needed() -> void:
	if _history_enabled:
		_build_history_past()


func _build_history_past() -> void:
	for child in _history_past.get_children():
		child.queue_free()
	var today_key := TimeUtils.get_productivity_day_key_now()
	var day_keys := ProductivityData.get_all_day_keys_sorted()
	for day_key in day_keys:
		if day_key == today_key:
			continue
		var section := VBoxContainer.new()
		var header := Label.new()
		header.text = TimeUtils.format_day_label(day_key)
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		section.add_child(header)
		var table := SessionTable.new()
		table.session_delete_requested.connect(_on_session_delete_requested)
		table.build_for_day(day_key, false)
		section.add_child(table)
		_history_past.add_child(section)
	_apply_theme_to_history_past()


func _apply_theme_to_history_past() -> void:
	var text_color := UiScale.text_color()
	_apply_history_header_fonts(text_color)


func _scroll_to_today() -> void:
	await get_tree().process_frame
	var scroll_max := _main_scroll.get_v_scroll_bar().max_value
	_main_scroll.scroll_vertical = int(scroll_max)
