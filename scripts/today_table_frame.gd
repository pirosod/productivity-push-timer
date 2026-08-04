extends PanelContainer

const VISIBLE_DATA_ROWS := 5
const MAX_OVERSCROLL_BASE := 50.0
const WHEEL_STEP_BASE := 22.0
const SNAP_DELAY_SECONDS := 0.18
const SNAP_DURATION_SECONDS := 0.32

signal session_delete_requested(day_key: String, session_index: int)
signal session_insert_requested(day_key: String, session_index: int)
signal session_append_requested(day_key: String, session_index: int)
signal session_edit_requested(day_key: String, session_index: int)

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
var _pin_to_bottom_pending: bool = false
var _pin_to_top_pending: bool = false
var _preserved_scroll: int = 0


func _ready() -> void:
	_apply_border_style()
	clip_contents = true
	custom_minimum_size.x = 0
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var margin: MarginContainer = $Margin
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.clip_contents = true
	var vbox: VBoxContainer = $Margin/VBox
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.clip_contents = true
	_header_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_row.clip_contents = true
	_header_row.custom_minimum_size.x = 0
	var marker_row: Control = $Margin/VBox/MarkerRow
	marker_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	marker_row.clip_contents = true
	marker_row.custom_minimum_size.x = 0
	_scroll.custom_minimum_size.y = _visible_body_height()
	_scroll.custom_minimum_size.x = 0
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	_scroll.gui_input.connect(_on_scroll_gui_input)
	_scroll_content.gui_input.connect(_on_scroll_gui_input)
	_scroll_content.custom_minimum_size.x = 0
	_scroll_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_table.session_delete_requested.connect(_forward_delete_request)
	_table.session_insert_requested.connect(_forward_insert_request)
	_table.session_append_requested.connect(_forward_append_request)
	_table.session_edit_requested.connect(_forward_edit_request)
	_vertex_front.set_session_table(_table)
	_scroll.get_v_scroll_bar().value_changed.connect(_on_scroll_value_changed)
	_scroll.resized.connect(_sync_layer_sizes)
	_scroll.clip_contents = true
	_scroll_content.clip_contents = true
	_table.z_index = 1
	_table.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_table.custom_minimum_size.x = 0
	_table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_table.clip_contents = true
	_table.add_theme_constant_override("separation", 0)
	_chart.custom_minimum_size.x = 0


## Width is owned by the parent column — never by label text inside.
## (Cannot call super._get_minimum_size — native PanelContainer has no GDScript impl.)
func _get_minimum_size() -> Vector2:
	var height := 0.0
	for child in get_children():
		if child is Control and child.visible:
			height = maxf(height, child.get_combined_minimum_size().y)
	var style := get_theme_stylebox("panel")
	if style != null:
		height += style.get_margin(SIDE_TOP) + style.get_margin(SIDE_BOTTOM)
	return Vector2(0.0, height)


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


func build_for_day(
	day_key: String,
	include_active: bool = false,
	pin_to_bottom: bool = false,
	pin_to_top: bool = false
) -> void:
	_current_day_key = day_key
	_include_live = include_active
	_pin_to_bottom_pending = pin_to_bottom
	_pin_to_top_pending = pin_to_top and not pin_to_bottom
	_preserved_scroll = _scroll.scroll_vertical if is_instance_valid(_scroll) else 0
	_reset_rubber()
	_table.build_header_row(_header_row)
	_table.build_today_body(day_key, include_active)
	call_deferred("_finish_build_layout")


func _finish_build_layout() -> void:
	_ensure_scroll_viewport_height()
	_sync_layer_sizes()
	if _pin_to_bottom_pending:
		call_deferred("_scroll_to_bottom")
	elif _pin_to_top_pending:
		_scroll.scroll_vertical = 0
		_rubber_offset = 0.0
		_sync_scroll_content_position()
		_pin_to_top_pending = false
	else:
		# Live refresh: keep the user's place in the list.
		var bar := _scroll.get_v_scroll_bar()
		_scroll.scroll_vertical = int(clampf(float(_preserved_scroll), bar.min_value, bar.max_value))
		_sync_scroll_content_position()


func _scroll_to_bottom() -> void:
	_ensure_scroll_viewport_height()
	_sync_layer_sizes()
	var bar := _scroll.get_v_scroll_bar()
	if not _has_scrollable_overflow():
		_scroll.scroll_vertical = 0
		_pin_to_bottom_pending = false
	else:
		_scroll.scroll_vertical = int(bar.max_value)
		# Scrollbar max can lag one frame behind content size — retry once.
		if bar.max_value <= 0.5:
			call_deferred("_scroll_to_bottom_finalize")
			return
		_pin_to_bottom_pending = false
	_rubber_offset = 0.0
	_sync_scroll_content_position()


func _scroll_to_bottom_finalize() -> void:
	_sync_layer_sizes()
	var bar := _scroll.get_v_scroll_bar()
	_scroll.scroll_vertical = int(bar.max_value) if _has_scrollable_overflow() else 0
	_rubber_offset = 0.0
	_pin_to_bottom_pending = false
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
	TodayChartStyle.apply_panel_box(self)


func _visible_body_height() -> int:
	return TodayChartStyle.row_height() * VISIBLE_DATA_ROWS


func _ensure_scroll_viewport_height() -> void:
	var h := float(_visible_body_height())
	_scroll.custom_minimum_size.y = h
	# Keep the today box body height stable even with 0–few rows.
	if _scroll.size.y < h - 0.5:
		_scroll.size.y = h


## Height from current rows only — ignores leftover custom_minimum_size from taller days.
func _content_height() -> float:
	var row_h := float(TodayChartStyle.row_height())
	var count := 0
	for child in _table.get_children():
		if child is Control and child.visible:
			count += 1
	if count <= 0:
		return 0.0
	var sep := 0.0
	if count > 1:
		sep = float(_table.get_theme_constant("separation")) * float(count - 1)
	return float(count) * row_h + sep


func _has_scrollable_overflow() -> bool:
	return _content_height() > maxf(_scroll.size.y, float(_visible_body_height())) + 0.5


func _max_overscroll() -> float:
	return UiScale.scale(MAX_OVERSCROLL_BASE)


func _wheel_step() -> float:
	return UiScale.scale(WHEEL_STEP_BASE)


func _sync_layer_sizes() -> void:
	_ensure_scroll_viewport_height()
	# Drop inflated mins/sizes left over from a previously taller day.
	_table.custom_minimum_size = Vector2(0, 0)
	_scroll_content.custom_minimum_size = Vector2(0, 0)
	_chart.custom_minimum_size = Vector2(0, 0)

	var content_height := _content_height()
	var width := maxf(_scroll.size.x, 1.0)
	var layer_size := Vector2(width, content_height)

	_scroll_content.custom_minimum_size = Vector2(0, content_height)
	_scroll_content.size = layer_size
	_chart.custom_minimum_size = Vector2(0, 0)
	_chart.size = layer_size
	_table.custom_minimum_size = Vector2(0, content_height)
	_table.size = layer_size
	_table.size.x = width

	# Keep short days pinned to the top (newest-first list starts here).
	if not _pin_to_bottom_pending and not _has_scrollable_overflow():
		_scroll.scroll_vertical = 0
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
	if not _has_scrollable_overflow():
		return true
	var bar := _scroll.get_v_scroll_bar()
	var at_top := bar.value <= bar.min_value + 0.5
	var at_bottom := bar.value >= bar.max_value - 0.5
	var on_rubber := absf(_rubber_offset) > 0.01
	var on_edge := (direction > 0 and at_bottom) or (direction < 0 and at_top)
	return on_rubber or on_edge


func _apply_wheel_scroll(direction: int) -> void:
	# Not enough rows to scroll: stay pinned to top, rubberband both ways.
	if not _has_scrollable_overflow():
		_scroll.scroll_vertical = 0
		_handle_scroll_direction(direction)
		return

	var bar := _scroll.get_v_scroll_bar()
	var at_top := bar.value <= bar.min_value + 0.5
	var at_bottom := bar.value >= bar.max_value - 0.5
	var on_edge := (direction > 0 and at_bottom) or (direction < 0 and at_top)

	if absf(_rubber_offset) > 0.01 or on_edge:
		_handle_scroll_direction(direction)
		return

	_scroll.scroll_vertical = int(
		clampf(
			float(_scroll.scroll_vertical) + float(direction) * _wheel_step(),
			bar.min_value,
			bar.max_value
		)
	)
	_sync_scroll_content_position()


func _handle_scroll_direction(direction: int) -> void:
	_kill_snap_tween()
	_rubber_offset = clampf(
		_rubber_offset - float(direction) * _wheel_step() * 0.45,
		-_max_overscroll(),
		_max_overscroll()
	)
	_snap_timer = SNAP_DELAY_SECONDS
	_sync_scroll_content_position()


func _get_scroll_direction(event: InputEvent) -> int:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			return -1
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			return 1
	return 0


func _sync_scroll_content_position() -> void:
	if not is_instance_valid(_scroll_content):
		return
	_scroll_content.position.y = -float(_scroll.scroll_vertical) + _rubber_offset
	_sync_vertex_overlay(_scroll_content.size)


func _on_scroll_value_changed(_value: float) -> void:
	_sync_scroll_content_position()


func _reset_rubber() -> void:
	_kill_snap_tween()
	_rubber_offset = 0.0
	_snap_timer = 0.0
	_sync_scroll_content_position()


func _start_snap_back() -> void:
	if absf(_rubber_offset) < 0.01:
		_rubber_offset = 0.0
		_sync_scroll_content_position()
		return
	_kill_snap_tween()
	_snap_tween = create_tween()
	_snap_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_snap_tween.tween_method(_set_rubber_offset, _rubber_offset, 0.0, SNAP_DURATION_SECONDS)


func _set_rubber_offset(value: float) -> void:
	_rubber_offset = value
	_sync_scroll_content_position()


func _kill_snap_tween() -> void:
	if _snap_tween:
		_snap_tween.kill()
		_snap_tween = null


func _forward_delete_request(day_key: String, session_index: int) -> void:
	session_delete_requested.emit(day_key, session_index)


func _forward_insert_request(day_key: String, session_index: int) -> void:
	session_insert_requested.emit(day_key, session_index)


func _forward_append_request(day_key: String, session_index: int) -> void:
	session_append_requested.emit(day_key, session_index)


func _forward_edit_request(day_key: String, session_index: int) -> void:
	session_edit_requested.emit(day_key, session_index)
