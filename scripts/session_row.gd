extends Control
class_name SessionRow

signal delete_line_clicked

const LINE_THICKNESS_BASE := 5.0
const CLICK_ZONE_BASE := 10.0

var _content: HBoxContainer
var _hovered := false
var _deletable := true
var _stripe_index := 0


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


func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func set_deletable(enabled: bool) -> void:
	_deletable = enabled
	if not enabled:
		_hovered = false
		queue_redraw()


func set_stripe_index(index: int) -> void:
	_stripe_index = index
	queue_redraw()


func set_columns(values: Array) -> void:
	for child in _content.get_children():
		child.queue_free()
	for value in values:
		var label := Label.new()
		label.text = str(value)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_style_label(label)
		_content.add_child(label)


func _style_label(label: Label) -> void:
	var control := TextControl.get_instance()
	var font_size: int = control.session_table_font_size() if control else UiScale.font_size()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", UiScale.text_color())


func _on_mouse_entered() -> void:
	if not _deletable:
		return
	_hovered = true
	queue_redraw()


func _on_mouse_exited() -> void:
	_hovered = false
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not _deletable or not _hovered:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var click_zone := UiScale.scale(CLICK_ZONE_BASE)
		if event.position.y >= size.y - click_zone:
			delete_line_clicked.emit()


func _draw() -> void:
	var stripe := TodayChartStyle.zebra_color(_stripe_index)
	if stripe.a > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), stripe)
	if not _hovered or not _deletable:
		return
	var thickness := UiScale.scale(LINE_THICKNESS_BASE)
	var y := size.y - thickness * 0.5
	draw_line(Vector2(0, y), Vector2(size.x, y), Color.RED, thickness)
