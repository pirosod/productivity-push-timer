extends Control

const IDLE_INTERVAL_SECONDS := 20.0 * 60.0
const SNOOZE_SECONDS := 60.0 * 60.0
const SCROLL_SIDE_MARGIN := 20.0
const SCROLL_BOTTOM_MARGIN := 20.0
# Match the taller history-mode header; idle uses this size too.
const HEADER_BUTTON_WIDTH := 180.0
const HEADER_BUTTON_HEIGHT := 126.0
const HEADER_MARGIN_V := 10
const HEADER_MARGIN_H := 16

@onready var _background: ColorRect = $FeatherBackground
@onready var _fixed_header: PanelContainer = $FixedHeader
@onready var _header_margin: MarginContainer = $FixedHeader/Margin
@onready var _header_center: VBoxContainer = $FixedHeader/Margin/Header/HeaderCenter
@onready var _main_scroll: ScrollContainer = $MainScroll
@onready var _content: VBoxContainer = $MainScroll/Content
@onready var _scroll_top_spacer: Control = $MainScroll/Content/ScrollTopSpacer
@onready var _push_button: Button = $FixedHeader/Margin/Header/PushButton
@onready var _timer_label: Label = $FixedHeader/Margin/Header/HeaderCenter/TimerLabel
@onready var _back_button: Button = $FixedHeader/Margin/Header/HeaderCenter/BackButton
@onready var _snooze_button: Button = $FixedHeader/Margin/Header/SnoozeButton
@onready var _today_table_frame = $MainScroll/Content/TodaySection/TodayBoxStack/TodayTableFrame
@onready var _today_marker_legend: TodayMarkerLegend = (
	$MainScroll/Content/TodaySection/TodayBoxStack/TodayTableFrame/Margin/VBox/MarkerRow/TodayMarkerLegend
)
@onready var _week_chart_frame = $MainScroll/Content/WeekChartStack/WeekChartFrame
@onready var _week_chart: Control = $MainScroll/Content/WeekChartStack/WeekChartFrame/Margin/VBox/WeekChart
@onready var _week_summary_header: Label = $MainScroll/Content/WeekChartStack/WeekChartFrame/Margin/VBox/WeekSummaryHeader
@onready var _week_summary_section = $MainScroll/Content/WeekByWeekStack/WeekSummarySection
@onready var _week_by_week_header: Label = (
	$MainScroll/Content/WeekByWeekStack/WeekSummarySection/Margin/VBox/WeekByWeekHeader
)
@onready var _week_summary_table: WeekSummaryTable = (
	$MainScroll/Content/WeekByWeekStack/WeekSummarySection/Margin/VBox/WeekSummaryTable
)
@onready var _goal_row: HBoxContainer = $MainScroll/Content/WeekChartStack/WeekChartFrame/Margin/VBox/GoalRow
@onready var _popup_layer: CanvasLayer = $PopupLayer
@onready var _popup_panel: PanelContainer = $PopupLayer/PopupPanel
@onready var _popup_close: Button = $PopupLayer/PopupPanel/Margin/VBox/CloseButton
@onready var _boink: Node = $BoinkSound
@onready var _text_control: TextControl = $"AppControls/Text control"
@onready var _marker_control: MarkerControl = $"AppControls/Marker control"
@onready var _visual_tweaks = $"AppControls/Visual tweaks"
@onready var _today_header: Label = (
	$MainScroll/Content/TodaySection/TodayBoxStack/TodayTableFrame/Margin/VBox/TodayHeader
)
@onready var _popup_message: Label = $PopupLayer/PopupPanel/Margin/VBox/Message
@onready var _delete_popup_panel: PanelContainer = $PopupLayer/DeletePopupPanel
@onready var _delete_popup_message: Label = $PopupLayer/DeletePopupPanel/Margin/VBox/Message
@onready var _delete_yes_button: Button = $PopupLayer/DeletePopupPanel/Margin/VBox/Buttons/YesButton
@onready var _delete_no_button: Button = $PopupLayer/DeletePopupPanel/Margin/VBox/Buttons/NoButton
@onready var _add_session_editor: AddSessionEditor = $PopupLayer/AddSessionEditor

enum ConfirmKind { NONE, DELETE, ADD, MODIFY, CLOSE_EDITOR }

var _idle_seconds_left := IDLE_INTERVAL_SECONDS
var _idle_paused := false
var _snooze_until_unix := 0
var _popup_visible := false
var _delete_popup_visible := false
var _selected_chart_day := ""
var _closing := false
var _pending_delete_day_key := ""
var _pending_delete_index := -1
var _confirm_kind: ConfirmKind = ConfirmKind.NONE
var _pending_insert_day_key := ""
var _pending_insert_index := -1
var _pending_insert_after := false
var _pending_edit_day_key := ""
var _pending_edit_index := -1
var _last_summary_refresh_minute := -1
var _main_layout_ready := false
var _history_label_hovered := false

const HISTORY_HOVER_OUTLINE := Color(1.0, 0.45, 0.05, 1.0)


func _ready() -> void:
	_apply_window_settings()
	_push_button.pressed.connect(_on_push_pressed)
	_snooze_button.pressed.connect(_on_snooze_pressed)
	_back_button.pressed.connect(_on_back_pressed)
	_popup_close.pressed.connect(_hide_popup)
	_delete_yes_button.pressed.connect(_on_confirm_yes_pressed)
	_delete_no_button.pressed.connect(_on_confirm_no_pressed)
	_today_table_frame.session_delete_requested.connect(_on_session_delete_requested)
	_today_table_frame.session_insert_requested.connect(_on_session_insert_requested)
	_today_table_frame.session_append_requested.connect(_on_session_append_requested)
	_today_table_frame.session_edit_requested.connect(_on_session_edit_requested)
	_add_session_editor.save_pressed.connect(_on_add_editor_save_pressed)
	_add_session_editor.cancelled.connect(_on_add_editor_cancelled)
	_add_session_editor.close_requested.connect(_on_add_editor_close_requested)
	_week_chart.day_selected.connect(_on_chart_day_selected)
	_week_summary_table.week_selected.connect(_on_week_row_selected)
	_text_control.sizes_changed.connect(_on_text_sizes_changed)
	_marker_control.sizes_changed.connect(_on_marker_sizes_changed)
	_visual_tweaks.tweaks_changed.connect(_sync_main_layout)
	_timer_label.mouse_entered.connect(_on_timer_label_mouse_entered)
	_timer_label.mouse_exited.connect(_on_timer_label_mouse_exited)
	_timer_label.gui_input.connect(_on_timer_label_gui_input)
	_timer_label.draw.connect(_on_timer_label_draw)
	_setup_goal_pickers()
	_apply_header_button_sizes()
	_timer_label.add_theme_font_size_override("font_size", _text_control.timer_font_size())
	_popup_layer.visible = false
	_popup_panel.visible = false
	_delete_popup_panel.visible = false
	_add_session_editor.visible = false
	_connect_window_close()
	_fixed_header.resized.connect(_sync_main_layout)
	TodayChartStyle.apply_header_box(_fixed_header)
	TodayChartStyle.apply_popup_box(_popup_panel)
	TodayChartStyle.apply_popup_box(_delete_popup_panel)
	_main_layout_ready = true
	_sync_main_layout()
	if not ProductivityData.productivity_day_changed.is_connected(_on_productivity_day_changed):
		ProductivityData.productivity_day_changed.connect(_on_productivity_day_changed)
	_refresh_ui()
	call_deferred("_scroll_to_top")


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_sync_main_layout()
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_on_window_close_requested()


func _sync_main_layout() -> void:
	if not _main_layout_ready:
		return
	if not is_instance_valid(_scroll_top_spacer) or not is_instance_valid(_fixed_header):
		return
	if not is_instance_valid(_main_scroll):
		return
	_scroll_top_spacer.custom_minimum_size.y = _scroll_top_spacing_px()
	_fixed_header.offset_left = 0.0
	_fixed_header.offset_top = 0.0
	_fixed_header.offset_right = 0.0
	# Keep the Push/Snooze bar at its normal height even when History + Back are shown.
	var header_height := _stable_header_height()
	_fixed_header.offset_bottom = header_height
	# Scroll content starts flush under the header — no white gap strip.
	_main_scroll.offset_left = SCROLL_SIDE_MARGIN
	_main_scroll.offset_top = header_height
	_main_scroll.offset_right = -SCROLL_SIDE_MARGIN
	_main_scroll.offset_bottom = -SCROLL_BOTTOM_MARGIN


func _stable_header_height() -> float:
	_apply_header_button_sizes()
	return HEADER_BUTTON_HEIGHT + float(HEADER_MARGIN_V) * 2.0


func _apply_header_button_sizes() -> void:
	var button_size := Vector2(HEADER_BUTTON_WIDTH, HEADER_BUTTON_HEIGHT)
	_push_button.custom_minimum_size = button_size
	_snooze_button.custom_minimum_size = button_size
	# Keep side buttons from stretching if the center column briefly reports taller.
	_push_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_snooze_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if is_instance_valid(_header_margin):
		_header_margin.add_theme_constant_override("margin_left", HEADER_MARGIN_H)
		_header_margin.add_theme_constant_override("margin_right", HEADER_MARGIN_H)
		_header_margin.add_theme_constant_override("margin_top", HEADER_MARGIN_V)
		_header_margin.add_theme_constant_override("margin_bottom", HEADER_MARGIN_V)


func _scroll_top_spacing_px() -> float:
	if is_instance_valid(_visual_tweaks):
		return _visual_tweaks.scroll_top_spacing_px()
	return UiScale.scale(16.0)


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


func _process(_delta: float) -> void:
	if ProductivityData.is_session_active():
		_update_timer_label()
		_refresh_today_table()
		var live_minute := ProductivityData.get_live_session_minutes()
		if live_minute != _last_summary_refresh_minute:
			_last_summary_refresh_minute = live_minute
			_refresh_week_summary()
		_week_chart.queue_redraw()
	elif _is_history_mode() or _idle_paused:
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
	box.add_theme_constant_override("separation", UiScale.scale_i(4))
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", _text_control.goal_label_font_size())
	label.add_theme_color_override("font_color", UiScale.text_color())
	box.add_child(label)
	var picker := ColorPickerButton.new()
	picker.color = color
	picker.custom_minimum_size = Vector2(UiScale.scale_i(18), UiScale.scale_i(14))
	picker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picker.focus_mode = Control.FOCUS_NONE
	box.add_child(picker)
	_goal_row.add_child(box)


func _add_goal_picker(label_text: String, color: Color, which: String) -> void:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", UiScale.scale_i(4))
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", _text_control.goal_label_font_size())
	label.add_theme_color_override("font_color", UiScale.text_color())
	box.add_child(label)
	var picker := ColorPickerButton.new()
	picker.color = color
	picker.custom_minimum_size = Vector2(UiScale.scale_i(18), UiScale.scale_i(14))
	picker.color_changed.connect(func(new_color: Color) -> void:
		ProductivityData.update_goal_color(which, new_color)
		_week_chart.queue_redraw()
		_today_table_frame.refresh_appearance()
		_refresh_week_summary()
	)
	box.add_child(picker)
	_goal_row.add_child(box)


func _on_push_pressed() -> void:
	if _is_history_mode():
		_select_today()
		if not ProductivityData.is_session_active():
			ProductivityData.start_session()
			_idle_paused = true
			_hide_popup()
			_hide_confirm_popup()
			_hide_add_session_editor()
			_clear_insert_pending()
		_refresh_ui()
		return
	if ProductivityData.is_session_active():
		ProductivityData.end_session()
		_idle_paused = false
		_idle_seconds_left = IDLE_INTERVAL_SECONDS
	else:
		ProductivityData.start_session()
		_idle_paused = true
		_hide_popup()
		_hide_confirm_popup()
		_hide_add_session_editor()
		_clear_insert_pending()
	_refresh_ui()


func _on_snooze_pressed() -> void:
	if ProductivityData.is_session_active():
		return
	_snooze_until_unix = int(Time.get_unix_time_from_system()) + int(SNOOZE_SECONDS)
	_hide_popup()


func _on_back_pressed() -> void:
	if not _is_history_mode() and _week_summary_table.get_selected_monday().is_empty():
		return
	_select_today()
	_refresh_ui()


func _on_text_sizes_changed() -> void:
	_sync_main_layout()
	_refresh_ui()


func _on_marker_sizes_changed() -> void:
	_today_table_frame.refresh_appearance()


func _on_chart_day_selected(day_key: String) -> void:
	_selected_chart_day = day_key
	_week_chart.set_selected_day(day_key)
	# Week-row orange selection is only set via week-by-week clicks, not day clicks.
	if _is_history_mode():
		_hide_popup()
	_refresh_ui()


func _on_week_row_selected(week: Dictionary) -> void:
	if bool(week.get("is_current", false)):
		_select_today()
		_refresh_ui()
		return
	var monday_key := str(week.get("monday_key", ""))
	var sunday_key := str(week.get("sunday_key", ""))
	var first_data_key := str(week.get("first_data_key", ""))
	var locked_before := ""
	if bool(week.get("is_first_partial", false)):
		locked_before = first_data_key
	_week_summary_table.set_selected_monday(monday_key)
	_selected_chart_day = sunday_key
	_week_chart.set_calendar_week(monday_key, locked_before)
	_week_chart.set_selected_day(sunday_key)
	_hide_popup()
	_refresh_ui()


func _is_history_mode() -> bool:
	if _selected_chart_day.is_empty():
		return false
	return _selected_chart_day != TimeUtils.get_productivity_day_key_now()


func _select_today() -> void:
	_selected_chart_day = TimeUtils.get_productivity_day_key_now()
	_week_summary_table.clear_week_selection()
	_week_chart.set_rolling_mode()
	_week_chart.set_selected_day(_selected_chart_day)


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
	_hide_add_session_editor()
	_delete_popup_panel.visible = false
	_delete_popup_visible = false
	_confirm_kind = ConfirmKind.NONE
	_popup_layer.visible = true
	_popup_visible = true
	_popup_panel.visible = true


func _hide_popup() -> void:
	_popup_visible = false
	_popup_panel.visible = false
	if not _delete_popup_visible and not _add_session_editor.visible:
		_popup_layer.visible = false


func _show_confirm_popup(kind: ConfirmKind, message: String) -> void:
	_confirm_kind = kind
	_delete_popup_message.text = message
	_popup_panel.visible = false
	_popup_visible = false
	_add_session_editor.visible = false
	_popup_layer.visible = true
	_delete_popup_panel.visible = true
	_delete_popup_visible = true
	_delete_popup_panel.move_to_front()


func _hide_confirm_popup() -> void:
	_delete_popup_visible = false
	_delete_popup_panel.visible = false
	_confirm_kind = ConfirmKind.NONE
	_pending_delete_day_key = ""
	_pending_delete_index = -1
	if not _popup_visible and not _add_session_editor.visible:
		_popup_layer.visible = false


func _show_delete_popup(day_key: String, session_index: int) -> void:
	_pending_delete_day_key = day_key
	_pending_delete_index = session_index
	_show_confirm_popup(ConfirmKind.DELETE, "Do you want to delete that entry?")


func _on_session_delete_requested(day_key: String, session_index: int) -> void:
	_show_delete_popup(day_key, session_index)


func _on_session_insert_requested(day_key: String, session_index: int) -> void:
	if ProductivityData.is_session_active():
		_boink.play_boink()
		return
	var gap: Dictionary = ProductivityData.get_insert_gap_above_session(day_key, session_index)
	if not bool(gap.get("ok", false)):
		_boink.play_boink()
		return
	_pending_insert_day_key = day_key
	_pending_insert_index = session_index
	_pending_insert_after = false
	_show_confirm_popup(ConfirmKind.ADD, "Would you like to add new data?")


func _on_session_append_requested(day_key: String, session_index: int) -> void:
	if ProductivityData.is_session_active():
		_boink.play_boink()
		return
	var gap: Dictionary = ProductivityData.get_insert_gap_after_session(day_key, session_index)
	if not bool(gap.get("ok", false)):
		_boink.play_boink()
		return
	_pending_insert_day_key = day_key
	_pending_insert_index = session_index
	_pending_insert_after = true
	_show_confirm_popup(ConfirmKind.ADD, "Would you like to add new data?")


func _on_session_edit_requested(day_key: String, session_index: int) -> void:
	if ProductivityData.is_session_active():
		_boink.play_boink()
		return
	var bounds: Dictionary = ProductivityData.get_edit_bounds(day_key, session_index)
	if not bool(bounds.get("ok", false)):
		_boink.play_boink()
		return
	_pending_edit_day_key = day_key
	_pending_edit_index = session_index
	_show_confirm_popup(ConfirmKind.MODIFY, "Modify entry?")


func _open_add_session_editor() -> void:
	var gap: Dictionary
	if _pending_insert_after:
		gap = ProductivityData.get_insert_gap_after_session(
			_pending_insert_day_key, _pending_insert_index
		)
	else:
		gap = ProductivityData.get_insert_gap_above_session(
			_pending_insert_day_key, _pending_insert_index
		)
	if not bool(gap.get("ok", false)):
		_boink.play_boink()
		_clear_insert_pending()
		return
	_delete_popup_visible = false
	_delete_popup_panel.visible = false
	_confirm_kind = ConfirmKind.NONE
	_popup_layer.visible = true
	_add_session_editor.open_for_gap(
		_pending_insert_day_key,
		int(gap.get("start_unix", 0)),
		int(gap.get("end_unix", 0)),
		bool(gap.get("tracks_now", false)),
		bool(gap.get("lock_start", false)),
		bool(gap.get("append_mode", false))
	)
	_add_session_editor.apply_theme()


func _open_edit_session_editor() -> void:
	var bounds: Dictionary = ProductivityData.get_edit_bounds(
		_pending_edit_day_key, _pending_edit_index
	)
	if not bool(bounds.get("ok", false)):
		_boink.play_boink()
		_clear_edit_pending()
		return
	_delete_popup_visible = false
	_delete_popup_panel.visible = false
	_confirm_kind = ConfirmKind.NONE
	_popup_layer.visible = true
	_add_session_editor.open_for_edit(
		_pending_edit_day_key,
		int(bounds.get("min_start", 0)),
		int(bounds.get("max_end", 0)),
		int(bounds.get("original_start", 0)),
		int(bounds.get("original_end", 0)),
		bool(bounds.get("tracks_now", false))
	)
	_add_session_editor.apply_theme()


func _hide_add_session_editor() -> void:
	_add_session_editor.visible = false
	if not _popup_visible and not _delete_popup_visible:
		_popup_layer.visible = false


func _clear_insert_pending() -> void:
	_pending_insert_day_key = ""
	_pending_insert_index = -1
	_pending_insert_after = false


func _clear_edit_pending() -> void:
	_pending_edit_day_key = ""
	_pending_edit_index = -1


func _on_add_editor_save_pressed(start_unix: int, end_unix: int) -> void:
	var editing := _add_session_editor.is_edit_mode()
	var day_key := _pending_edit_day_key if editing else _pending_insert_day_key
	var edit_index := _pending_edit_index
	_hide_add_session_editor()
	_clear_insert_pending()
	_clear_edit_pending()
	var ok := false
	if editing:
		ok = ProductivityData.update_manual_session(day_key, edit_index, start_unix, end_unix)
	else:
		ok = ProductivityData.insert_manual_session(day_key, start_unix, end_unix)
	if ok:
		_refresh_ui()
	else:
		_boink.play_boink()


func _on_add_editor_cancelled() -> void:
	_hide_add_session_editor()
	_clear_insert_pending()
	_clear_edit_pending()


func _on_add_editor_close_requested() -> void:
	_show_confirm_popup(ConfirmKind.CLOSE_EDITOR, "Would you like to close?")


func _restore_add_session_editor() -> void:
	_delete_popup_visible = false
	_delete_popup_panel.visible = false
	_confirm_kind = ConfirmKind.NONE
	_popup_layer.visible = true
	_add_session_editor.visible = true
	_add_session_editor.apply_theme()
	_add_session_editor.move_to_front()


func _on_confirm_yes_pressed() -> void:
	match _confirm_kind:
		ConfirmKind.DELETE:
			if not _pending_delete_day_key.is_empty() and _pending_delete_index >= 0:
				ProductivityData.delete_session(_pending_delete_day_key, _pending_delete_index)
				_refresh_ui()
			_hide_confirm_popup()
		ConfirmKind.ADD:
			_open_add_session_editor()
		ConfirmKind.MODIFY:
			_open_edit_session_editor()
		ConfirmKind.CLOSE_EDITOR:
			_hide_confirm_popup()
			_hide_add_session_editor()
			_clear_insert_pending()
			_clear_edit_pending()
		_:
			_hide_confirm_popup()


func _on_confirm_no_pressed() -> void:
	match _confirm_kind:
		ConfirmKind.ADD:
			_hide_confirm_popup()
			_clear_insert_pending()
		ConfirmKind.MODIFY:
			_hide_confirm_popup()
			_clear_edit_pending()
		ConfirmKind.CLOSE_EDITOR:
			_restore_add_session_editor()
		_:
			_hide_confirm_popup()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_P:
			_trigger_idle_alert()
			return
	if _delete_popup_visible:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if not _delete_popup_panel.get_global_rect().has_point(event.global_position):
				_on_confirm_no_pressed()
		return
	if _add_session_editor.visible:
		return
	if not _popup_visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not _popup_panel.get_global_rect().has_point(event.global_position):
			_hide_popup()


func _on_productivity_day_changed(new_day_key: String) -> void:
	_selected_chart_day = new_day_key
	_week_summary_table.clear_week_selection()
	_week_chart.set_rolling_mode()
	_last_summary_refresh_minute = -1
	_refresh_ui()


func _refresh_ui() -> void:
	_update_timer_label()
	_refresh_today_table(true)
	_week_chart.refresh()
	if _selected_chart_day.is_empty():
		_selected_chart_day = TimeUtils.get_productivity_day_key_now()
	_week_chart.set_selected_day(_selected_chart_day)
	_apply_theme_mode()
	_refresh_week_summary()
	_update_week_summary_title()


func _apply_theme_mode() -> void:
	var is_dark := ProductivityData.is_session_active()
	var history_mode := _is_history_mode()
	TodayChartStyle.history_mode = history_mode
	_background.is_dark_mode = is_dark
	_background.is_history_mode = history_mode
	_background.queue_redraw()
	get_tree().call_group("box_interior_hosts", "refresh_interior_bg")
	TodayChartStyle.apply_header_box(_fixed_header)
	TodayChartStyle.apply_popup_box(_popup_panel)
	TodayChartStyle.apply_popup_box(_delete_popup_panel)
	var text_color := UiScale.text_color()
	_apply_button_theme(_push_button, text_color, _text_control.push_button_font_size())
	_apply_button_theme(_snooze_button, text_color, _text_control.snooze_button_font_size())
	_apply_button_theme(_popup_close, text_color, _text_control.popup_button_font_size())
	_apply_button_theme(_delete_yes_button, text_color, _text_control.popup_button_font_size())
	_apply_button_theme(_delete_no_button, text_color, _text_control.popup_button_font_size())
	_add_session_editor.apply_theme()
	_timer_label.add_theme_color_override("font_color", text_color)
	_back_button.visible = history_mode
	_apply_header_center_mode(history_mode, text_color)
	_today_header.add_theme_color_override("font_color", text_color)
	_today_header.add_theme_font_size_override("font_size", _text_control.today_header_font_size())
	_update_week_summary_title()
	_week_summary_header.add_theme_color_override("font_color", text_color)
	_week_summary_header.add_theme_font_size_override("font_size", _text_control.today_header_font_size())
	_week_by_week_header.add_theme_color_override("font_color", text_color)
	_week_by_week_header.add_theme_font_size_override("font_size", _text_control.today_header_font_size())
	_popup_message.add_theme_color_override("font_color", text_color)
	_popup_message.add_theme_font_size_override("font_size", _text_control.popup_message_font_size())
	_delete_popup_message.add_theme_color_override("font_color", text_color)
	_delete_popup_message.add_theme_font_size_override("font_size", _text_control.popup_message_font_size())
	_apply_goal_label_fonts(text_color)
	_week_chart.apply_label_theme()
	_today_table_frame.refresh_appearance()
	if is_instance_valid(_week_chart_frame):
		_week_chart_frame.refresh_appearance()
	if is_instance_valid(_week_summary_section):
		_week_summary_section.refresh_appearance()
	_today_marker_legend.refresh()
	_push_button.button_pressed = is_dark
	_snooze_button.disabled = is_dark
	call_deferred("_sync_main_layout")


func _apply_header_center_mode(history_mode: bool, text_color: Color) -> void:
	_apply_header_button_sizes()
	var content_h := HEADER_BUTTON_HEIGHT
	if history_mode:
		# Smaller History title + Back button, padded inside the shared tall header.
		var pad := UiScale.scale(8.0)
		var sep := UiScale.scale_i(6)
		_header_center.add_theme_constant_override("separation", sep)
		_header_center.alignment = BoxContainer.ALIGNMENT_CENTER
		_header_center.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var history_font := maxi(UiScale.scale_i(14), int(round(float(_text_control.timer_font_size()) * 0.58)))
		_timer_label.add_theme_font_size_override("font_size", history_font)
		_timer_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_timer_label.mouse_filter = Control.MOUSE_FILTER_STOP
		_timer_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var back_font := maxi(UiScale.scale_i(12), int(round(float(_text_control.snooze_button_font_size()) * 0.72)))
		_apply_button_theme(_back_button, text_color, back_font)
		var label_h := float(history_font) * 1.25
		var back_h := clampf(
			content_h - pad * 2.0 - float(sep) - label_h,
			UiScale.scale(24.0),
			content_h * 0.42
		)
		_back_button.custom_minimum_size = Vector2(0, back_h)
		_back_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	else:
		_history_label_hovered = false
		_header_center.add_theme_constant_override("separation", 4)
		_header_center.alignment = BoxContainer.ALIGNMENT_CENTER
		_header_center.size_flags_vertical = Control.SIZE_FILL
		_timer_label.add_theme_font_size_override("font_size", _text_control.timer_font_size())
		_timer_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_timer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_timer_label.mouse_default_cursor_shape = Control.CURSOR_ARROW
		_back_button.custom_minimum_size = Vector2(0, UiScale.scale(28.0))
		_apply_button_theme(_back_button, text_color, _text_control.snooze_button_font_size())
	_timer_label.queue_redraw()


func _on_timer_label_mouse_entered() -> void:
	if not _is_history_mode():
		return
	_history_label_hovered = true
	_timer_label.queue_redraw()


func _on_timer_label_mouse_exited() -> void:
	_history_label_hovered = false
	_timer_label.queue_redraw()


func _on_timer_label_gui_input(event: InputEvent) -> void:
	if not _is_history_mode():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		ProductivityData.open_data_folder()
		_timer_label.accept_event()


func _on_timer_label_draw() -> void:
	# Draw inside the existing label rect only — never change min size / header layout.
	if not _history_label_hovered or not _is_history_mode():
		return
	var thickness := maxf(2.0, UiScale.scale(2.0))
	var half := thickness * 0.5
	var rect := Rect2(
		Vector2(half, half),
		_timer_label.size - Vector2(thickness, thickness)
	)
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	_timer_label.draw_rect(rect, HISTORY_HOVER_OUTLINE, false, thickness)


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


func _update_timer_label() -> void:
	if _is_history_mode():
		_timer_label.text = "History"
	elif ProductivityData.is_session_active():
		var minutes := ProductivityData.get_live_session_minutes()
		_timer_label.text = TimeUtils.format_minutes_hm(minutes)
	else:
		_timer_label.text = "00:00"


func _refresh_today_table(scroll_to_latest: bool = false) -> void:
	var today_key := TimeUtils.get_productivity_day_key_now()
	var day_key := _selected_chart_day if not _selected_chart_day.is_empty() else today_key
	var is_today := day_key == today_key
	var include_live := is_today and ProductivityData.is_session_active()
	# Today navigate/refresh → bottom; older days → top; live tick → keep position.
	var pin_to_bottom := is_today and scroll_to_latest
	var pin_to_top := not is_today
	_today_table_frame.build_for_day(day_key, include_live, pin_to_bottom, pin_to_top)
	_today_header.text = "Today" if is_today else TimeUtils.format_day_label(day_key)
	_today_marker_legend.configure(day_key, include_live)


func _refresh_week_summary() -> void:
	var selected_monday := _week_summary_table.get_selected_monday()
	_week_summary_table.refresh()
	if not selected_monday.is_empty():
		_week_summary_table.set_selected_monday(selected_monday)


func _update_week_summary_title() -> void:
	var monday_key := _week_summary_table.get_selected_monday()
	if monday_key.is_empty() or not _week_chart.is_calendar_week_mode():
		_week_summary_header.text = "Week Summary"
		return
	var week: Dictionary = _week_summary_table.get_week_for_monday(monday_key)
	var week_number := int(week.get("week_number", _week_number_for_monday(monday_key)))
	var sunday_key := str(week.get("sunday_key", TimeUtils.add_days_to_day_key(monday_key, 6)))
	var start := TimeUtils.parse_day_key(monday_key)
	var end := TimeUtils.parse_day_key(sunday_key)
	_week_summary_header.text = "Week %d  %02d/%02d - %02d/%02d" % [
		week_number,
		int(start.day),
		int(start.month),
		int(end.day),
		int(end.month),
	]


func _week_number_for_monday(monday_key: String) -> int:
	var today_key := TimeUtils.get_productivity_day_key_now()
	var all_keys: Array = ProductivityData.get_all_day_keys_sorted()
	var first_data_key := today_key
	if not all_keys.is_empty():
		first_data_key = str(all_keys[0])
		if today_key < first_data_key:
			first_data_key = today_key
	var first_monday := TimeUtils.monday_key_for_day(first_data_key)
	var week_number := 1
	var monday := first_monday
	while monday <= monday_key:
		if monday == monday_key:
			return week_number
		week_number += 1
		monday = TimeUtils.add_days_to_day_key(monday, 7)
	return week_number


func _scroll_to_top() -> void:
	await get_tree().process_frame
	_main_scroll.scroll_vertical = 0
