extends PanelContainer

const VISIBLE_DATA_ROWS := 5
const BORDER_COLOR := Color(0.25, 0.25, 0.25)
const BORDER_WIDTH_BASE := 3.0
const MAX_OVERSCROLL_BASE := 50.0
const WHEEL_STEP_BASE := 22.0
const SNAP_DELAY_SECONDS := 0.18
const SNAP_DURATION_SECONDS := 0.32

signal session_delete_requested(day_key: String, session_index: int)

@onready var _header_row: HBoxContainer = $Margin/VBox/HeaderRow
@onready var _scroll: ScrollContainer = $Margin/VBox/TableScroll
@onready var _scroll_content: Control = $Margin/VBox/TableScroll/ScrollContent
@onready var _chart: TodaySessionChart = $Margin/VBox/TableScroll/ScrollContent/TodaySessionChart
@onready var _table: SessionTable = $Margin/VBox/TableScroll/ScrollContent/TodayTable
@onready var _vertex_front: TodayVertexFront = $Margin/VBox/TableScroll/TodayVertexFront

var _rubber_offset: float = 0.0
var _snap_timer: float = 0.0
var _snap_tween: Tween
var _current_day_key: String = ""
var _include_live: bool = false
var _scroll_to_latest_pending: bool = false


func _ready() -> void:
	_apply_border_style()
	clip_contents = true
	_scroll.custom_minimum_size.y = _visible_body_height()
	_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	_scroll.gui_input.connect(_on_scroll_gui_input)
	_scroll_content.gui_input.connect(_on_scroll_gui_input)
	_table.session_delete_requested.connect(_forward_delete_request)
	_scroll.get_v_scroll_bar().value_changed.connect(_on_scroll_value_changed)
	_scroll.resized.connect(_sync_layer_sizes)
	_scroll.clip_contents = true
	_scroll_content.clip_contents = true
	_table.z_index = 1
	_table.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_table.add_theme_constant_override("separation", 0)


func _input(event: InputEvent) -> void:
	if not _scroll.get_global_rect().has_point(get_global_mouse_position()):
		return
	var direction := _get_scroll_direction(event)
	if direction == 0:
		return
	_apply_wheel_scroll(direction)
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_sync_scroll_content_position()
	if _snap_timer > 0.0:
		_snap_timer -= delta
		if _snap_timer <= 0.0:
			_start_snap_back()


func get_session_table() -> SessionTable:
	return _table


func build_for_day(day_key: String, include_active: bool = false, scroll_to_latest: bool = false) -> void:
	_current_day_key = day_key
	_include_live = include_active
	_scroll_to_latest_pending = scroll_to_latest
	_reset_rubber()
	_table.build_header_row(_header_row)
	_table.build_today_body(day_key, include_active)
	call_deferred("_finish_build_layout")


func _finish_build_layout() -> void:
	_sync_layer_sizes()
	if _scroll_to_latest_pending:
		_scroll_to_latest_pending = false
		call_deferred("_scroll_to_latest")


func _scroll_to_latest() -> void:
	var bar := _scroll.get_v_scroll_bar()
	_scroll.scroll_vertical = int(bar.max_value)
	_rubber_offset = 0.0
	_sync_scroll_content_position()


func refresh_appearance() -> void:
	_apply_border_style()
	var text_color := UiScale.text_color()
	var text_control := TextControl.get_instance()
	var header_font_size: int = (
		text_control.session_table_font_size() if text_control else UiScale.font_size()
	)
	for child in _header_row.get_children():
		if child is Label:
			child.add_theme_color_override("font_color", text_color)
			child.add_theme_font_size_override("font_size", header_font_size)
	for row in _table.get_children():
		if row is SessionRow:
			row.queue_redraw()
	var row_centers := _get_row_centers_y()
	_chart.configure(_current_day_key, _include_live, row_centers)
	_vertex_front.configure(_current_day_key, _include_live, row_centers)
	_chart.queue_redraw()
	_sync_vertex_overlay(_scroll_content.size)


func _apply_border_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = TodayChartStyle.panel_grey()
	style.border_color = BORDER_COLOR
	var width := UiScale.scale(BORDER_WIDTH_BASE)
	style.border_width_left = int(width)
	style.border_width_top = int(width)
	style.border_width_right = int(width)
	style.border_width_bottom = int(width)
	add_theme_stylebox_override("panel", style)


func _visible_body_height() -> int:
	return TodayChartStyle.row_height() * VISIBLE_DATA_ROWS


func _max_overscroll() -> float:
	return UiScale.scale(MAX_OVERSCROLL_BASE)


func _wheel_step() -> float:
	return UiScale.scale(WHEEL_STEP_BASE)


func _sync_layer_sizes() -> void:
	var content_height := _table.get_combined_minimum_size().y
	if content_height <= 0:
		content_height = _table.size.y
	_scroll_content.custom_minimum_size = Vector2(0, content_height)
	var width := maxf(_scroll.size.x, 1.0)
	var layer_size := Vector2(width, float(content_height))
	_scroll_content.size = layer_size
	_chart.size = layer_size
	_table.size = layer_size
	var row_centers := _get_row_centers_y()
	_chart.configure(_current_day_key, _include_live, row_centers)
	_vertex_front.configure(_current_day_key, _include_live, row_centers)
	_sync_vertex_overlay(layer_size)


func _get_row_centers_y() -> Array:
	var centers: Array = []
	if not is_instance_valid(_chart) or not is_instance_valid(_table):
		return centers
	var chart_origin_y := _chart.global_position.y
	for child in _table.get_children():
		if child is SessionRow:
			centers.append(child.global_position.y + child.size.y * 0.5 - chart_origin_y)
	return centers


func _sync_vertex_overlay(content_size: Vector2) -> void:
	var viewport_size := Vector2(maxf(_scroll.size.x, 1.0), maxf(_scroll.size.y, 1.0))
	_vertex_front.position = Vector2.ZERO
	var scroll_offset := float(_scroll.scroll_vertical) - _rubber_offset
	_vertex_front.set_view(scroll_offset, viewport_size, content_size)


func _on_scroll_gui_input(event: InputEvent) -> void:
	var direction := _get_scroll_direction(event)
	if direction == 0:
		return
	_apply_wheel_scroll(direction)
	if _wheel_event_handled(direction):
		if event is InputEventMouseButton:
			_scroll.accept_event()


func _wheel_event_handled(direction: int) -> bool:
	var bar := _scroll.get_v_scroll_bar()
	var at_top := bar.max_value <= 0.0 or bar.value <= bar.min_value + 0.5
	var at_bottom := bar.max_value <= 0.0 or bar.value >= bar.max_value - 0.5
	var on_rubber := absf(_rubber_offset) > 0.01
	var on_edge := (direction > 0 and at_bottom) or (direction < 0 and at_top)
	return on_rubber or on_edge


func _apply_wheel_scroll(direction: int) -> void:
	var bar := _scroll.get_v_scroll_bar()
	var at_top := bar.max_value <= 0.0 or bar.value <= bar.min_value + 0.5
	var at_bottom := bar.max_value <= 0.0 or bar.value >= bar.max_value - 0.5
	var on_edge := (direction > 0 and at_bottom) or (direction < 0 and at_top)

	if absf(_rubber_offset) > 0.01 or on_edge:
		_handle_scroll_direction(direction)
		return

	if bar.max_value <= 0.0:
		return
	var step := _wheel_step()
	_scroll.scroll_vertical = int(
		clampf(float(_scroll.scroll_vertical) + step * float(direction), 0.0, bar.max_value)
	)
	_sync_scroll_content_position()


func _get_scroll_direction(event: InputEvent) -> int:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			return -1
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			return 1
	if event is InputEventPanGesture:
		if absf(event.delta.y) < 0.01:
			return 0
		return 1 if event.delta.y < 0 else -1
	return 0


func _handle_scroll_direction(direction: int) -> void:
	var bar := _scroll.get_v_scroll_bar()
	var at_top := bar.max_value <= 0.0 or bar.value <= bar.min_value + 0.5
	var at_bottom := bar.max_value <= 0.0 or bar.value >= bar.max_value - 0.5
	var max_pull := _max_overscroll()
	var step := _wheel_step() * float(direction)

	if absf(_rubber_offset) > 0.01:
		_kill_snap_tween()
		_rubber_offset = clampf(_rubber_offset - step, -max_pull, max_pull)
		_schedule_snap_back()
		return

	if direction > 0 and at_bottom:
		_rubber_offset = clampf(_rubber_offset - step, -max_pull, 0.0)
		_schedule_snap_back()
	elif direction < 0 and at_top:
		_rubber_offset = clampf(_rubber_offset - step, 0.0, max_pull)
		_schedule_snap_back()


func _on_scroll_value_changed(_value: float) -> void:
	if absf(_rubber_offset) < 0.01:
		_sync_scroll_content_position()


func _sync_scroll_content_position() -> void:
	_scroll_content.position.y = -float(_scroll.scroll_vertical) + _rubber_offset
	_sync_vertex_overlay(_scroll_content.size)


func _schedule_snap_back() -> void:
	_snap_timer = SNAP_DELAY_SECONDS


func _start_snap_back() -> void:
	if absf(_rubber_offset) < 0.5:
		_rubber_offset = 0.0
		_sync_scroll_content_position()
		return
	_kill_snap_tween()
	var start := _rubber_offset
	_snap_tween = create_tween()
	_snap_tween.set_trans(Tween.TRANS_BACK)
	_snap_tween.set_ease(Tween.EASE_OUT)
	_snap_tween.tween_method(_set_rubber_offset, start, 0.0, SNAP_DURATION_SECONDS)


func _set_rubber_offset(value: float) -> void:
	_rubber_offset = value
	_sync_scroll_content_position()


func _reset_rubber() -> void:
	_kill_snap_tween()
	_snap_timer = 0.0
	_rubber_offset = 0.0
	_sync_scroll_content_position()


func _kill_snap_tween() -> void:
	if _snap_tween:
		_snap_tween.kill()
		_snap_tween = null


func _forward_delete_request(day_key: String, session_index: int) -> void:
	session_delete_requested.emit(day_key, session_index)
