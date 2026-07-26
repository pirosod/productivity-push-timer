extends Control
class_name SessionRow

signal delete_line_clicked
signal insert_line_clicked
signal edit_line_clicked
signal append_line_clicked

const LINE_THICKNESS_BASE := 5.0
const CLICK_ZONE_BASE := 10.0
const ROW_TINT_ALPHA := 0.28
const EDITED_BADGE := "Ed"
const EDIT_LINE_COLOR := Color(0.95, 0.82, 0.15, 1.0)
const INSERT_LINE_COLOR := Color(0.2, 0.85, 0.35, 1.0)

var _content: HBoxContainer
var _edited_badge: Label
var _hovered := false
var _deletable := true
var _insertable := false
var _editable := false
var _appendable := false
var _stripe_index := 0
var _tint_minutes: float = -1.0
var _show_edited_badge := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_content = HBoxContainer.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_theme_constant_override("separation", UiScale.scale_i(4))
	add_child(_content)
	custom_minimum_size.y = TodayChartStyle.row_height()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_content.size = size
		_layout_edited_badge()


func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func set_deletable(enabled: bool) -> void:
	_deletable = enabled
	if not _lines_enabled():
		_hovered = false
		queue_redraw()


func set_insertable(enabled: bool) -> void:
	_insertable = enabled
	if not _lines_enabled():
		_hovered = false
	queue_redraw()


func set_editable(enabled: bool) -> void:
	_editable = enabled
	if not _lines_enabled():
		_hovered = false
	queue_redraw()


func set_appendable(enabled: bool) -> void:
	_appendable = enabled
	if not _lines_enabled():
		_hovered = false
	queue_redraw()


func set_stripe_index(index: int) -> void:
	_stripe_index = index
	queue_redraw()


func set_tint_minutes(minutes: float) -> void:
	_tint_minutes = minutes
	queue_redraw()


func set_edited(edited: bool) -> void:
	_show_edited_badge = edited
	_ensure_edited_badge()
	queue_redraw()


func set_columns(values: Array) -> void:
	for child in _content.get_children():
		child.queue_free()
	for value in values:
		var label := Label.new()
		label.text = str(value)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.clip_text = false
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_style_label(label)
		_content.add_child(label)


func _ensure_edited_badge() -> void:
	if not _show_edited_badge:
		if is_instance_valid(_edited_badge):
			_edited_badge.visible = false
		return
	if not is_instance_valid(_edited_badge):
		_edited_badge = Label.new()
		_edited_badge.text = EDITED_BADGE
		_edited_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_edited_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_edited_badge.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		add_child(_edited_badge)
	_edited_badge.visible = true
	_style_edited_badge(_edited_badge)
	_layout_edited_badge()


func _layout_edited_badge() -> void:
	if not is_instance_valid(_edited_badge) or not _edited_badge.visible:
		return
	_edited_badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_edited_badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_edited_badge.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_edited_badge.offset_left = UiScale.scale(-24)
	_edited_badge.offset_top = UiScale.scale(-14)
	_edited_badge.offset_right = UiScale.scale(-2)
	_edited_badge.offset_bottom = UiScale.scale(-1)


func _style_label(label: Label) -> void:
	var control := TextControl.get_instance()
	var font_size: int = control.session_table_font_size() if control else UiScale.font_size()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", UiScale.text_color())


func _style_edited_badge(label: Label) -> void:
	var font_size := UiScale.scale_i(9)
	label.add_theme_font_size_override("font_size", font_size)
	var badge_color := UiScale.text_color()
	badge_color.a = 0.7
	label.add_theme_color_override("font_color", badge_color)


func _lines_enabled() -> bool:
	return _deletable or _insertable or _editable or _appendable


func _on_mouse_entered() -> void:
	if not _lines_enabled():
		return
	_hovered = true
	queue_redraw()


func _on_mouse_exited() -> void:
	_hovered = false
	queue_redraw()


func _line_thickness() -> float:
	var base := UiScale.scale(LINE_THICKNESS_BASE)
	if not _appendable:
		return base
	var count := _packed_line_kinds().size()
	if count <= 1:
		return base
	# Shrink so all lines fit inside the row without growing it.
	var max_thickness := size.y / float(count)
	return minf(base, max_thickness)


func _packed_line_kinds() -> Array[String]:
	var kinds: Array[String] = []
	if _insertable:
		kinds.append("insert")
	if _editable:
		kinds.append("edit")
	if _deletable:
		kinds.append("delete")
	if _appendable:
		kinds.append("append")
	return kinds


func _packed_line_ys() -> Array:
	var kinds := _packed_line_kinds()
	var ys: Array = []
	var count := kinds.size()
	if count == 0:
		return ys
	var thickness := _line_thickness()
	var top := thickness * 0.5
	var bottom := size.y - thickness * 0.5
	if count == 1:
		ys.append((top + bottom) * 0.5)
		return ys
	for i in count:
		var t := float(i) / float(count - 1)
		ys.append(lerpf(top, bottom, t))
	return ys


func _color_for_kind(kind: String) -> Color:
	match kind:
		"insert", "append":
			return INSERT_LINE_COLOR
		"edit":
			return EDIT_LINE_COLOR
		"delete":
			return Color.RED
		_:
			return Color.WHITE


func _emit_for_kind(kind: String) -> void:
	match kind:
		"insert":
			insert_line_clicked.emit()
		"edit":
			edit_line_clicked.emit()
		"delete":
			delete_line_clicked.emit()
		"append":
			append_line_clicked.emit()


func _gui_input(event: InputEvent) -> void:
	if not _hovered or not _lines_enabled():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _appendable:
			var kinds := _packed_line_kinds()
			var ys := _packed_line_ys()
			if kinds.is_empty():
				return
			var best_i := 0
			var best_dist := absf(event.position.y - float(ys[0]))
			for i in range(1, ys.size()):
				var dist := absf(event.position.y - float(ys[i]))
				if dist < best_dist:
					best_dist = dist
					best_i = i
			_emit_for_kind(kinds[best_i])
			accept_event()
			return
		var click_zone := UiScale.scale(CLICK_ZONE_BASE)
		if _insertable and event.position.y <= click_zone:
			insert_line_clicked.emit()
			accept_event()
		elif _deletable and event.position.y >= size.y - click_zone:
			delete_line_clicked.emit()
			accept_event()
		elif _editable:
			edit_line_clicked.emit()
			accept_event()


func _draw() -> void:
	if _tint_minutes >= 0.0:
		var tint := TodayChartStyle.vertex_color_for_minutes(_tint_minutes)
		tint.a = ROW_TINT_ALPHA
		draw_rect(Rect2(Vector2.ZERO, size), tint)
	else:
		var stripe := TodayChartStyle.zebra_color(_stripe_index)
		if stripe.a > 0.0:
			draw_rect(Rect2(Vector2.ZERO, size), stripe)
	if not _hovered or not _lines_enabled():
		return
	if _appendable:
		var kinds := _packed_line_kinds()
		var ys := _packed_line_ys()
		var thickness := _line_thickness()
		for i in kinds.size():
			var y := float(ys[i])
			draw_line(Vector2(0, y), Vector2(size.x, y), _color_for_kind(kinds[i]), thickness)
		return
	var thickness := _line_thickness()
	if _editable:
		draw_line(Vector2(0, size.y * 0.5), Vector2(size.x, size.y * 0.5), EDIT_LINE_COLOR, thickness)
	if _insertable:
		draw_line(Vector2(0, thickness * 0.5), Vector2(size.x, thickness * 0.5), INSERT_LINE_COLOR, thickness)
	if _deletable:
		draw_line(
			Vector2(0, size.y - thickness * 0.5),
			Vector2(size.x, size.y - thickness * 0.5),
			Color.RED,
			thickness
		)
