extends Control

## Wraps a PanelContainer with top/bottom edge shades (Today / Week / Week-by-week).
## A feather underlay sits behind the translucent panel so the grid pattern stays
## inside the boxes while the app chrome matches the header grey.

const SHADE_HEIGHT := 20.0
const INTERIOR_BG_SCRIPT := preload("res://scripts/box_interior_background.gd")

var _frame: Control
var _top_shade: Control
var _bottom_shade: Control
var _interior_bg: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_to_group("box_interior_hosts")
	_resolve_children()
	_ensure_interior_bg()
	if is_instance_valid(_frame):
		_frame.custom_minimum_size.x = 0
		_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_configure_shade(_top_shade, false)
	_configure_shade(_bottom_shade, true)
	resized.connect(_layout_children)
	call_deferred("_layout_children")


func refresh_interior_bg() -> void:
	if is_instance_valid(_interior_bg):
		_interior_bg.queue_redraw()


func _ensure_interior_bg() -> void:
	if is_instance_valid(_interior_bg):
		return
	_interior_bg = Control.new()
	_interior_bg.name = "BoxInteriorBg"
	_interior_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_interior_bg.set_script(INTERIOR_BG_SCRIPT)
	add_child(_interior_bg)
	move_child(_interior_bg, 0)


func _resolve_children() -> void:
	_frame = null
	_top_shade = null
	_bottom_shade = null
	for child in get_children():
		if child.name == "BoxInteriorBg":
			_interior_bg = child
			continue
		if child is PanelContainer and _frame == null:
			_frame = child
		elif String(child.name).ends_with("BottomShade"):
			_bottom_shade = child
		elif String(child.name).ends_with("TopShade"):
			_top_shade = child


func _configure_shade(shade: Control, bottom: bool) -> void:
	if not is_instance_valid(shade):
		return
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set("bottom_edge", bottom)


func _get_minimum_size() -> Vector2:
	var frame_min_y := 0.0
	if is_instance_valid(_frame):
		frame_min_y = _frame.get_combined_minimum_size().y
	# Width always comes from the main column; never from Today content.
	return Vector2(0, SHADE_HEIGHT * 2.0 + frame_min_y)


func _layout_children() -> void:
	if not is_instance_valid(_frame):
		_resolve_children()
	if not is_instance_valid(_frame):
		return
	_ensure_interior_bg()
	var width := maxf(size.x, 1.0)
	var frame_min := _frame.get_combined_minimum_size()
	var frame_h := maxf(size.y - SHADE_HEIGHT * 2.0, frame_min.y)
	_frame.custom_minimum_size = Vector2(0, frame_min.y)
	_frame.position = Vector2(0.0, SHADE_HEIGHT)
	_frame.size = Vector2(width, frame_h)
	if is_instance_valid(_interior_bg):
		_interior_bg.position = _frame.position
		_interior_bg.size = _frame.size
		move_child(_interior_bg, 0)
		_interior_bg.queue_redraw()
	custom_minimum_size = Vector2(0, SHADE_HEIGHT * 2.0 + frame_min.y)
	var radius := float(TodayChartStyle.panel_corner_radius())
	var shade_h := SHADE_HEIGHT + radius
	if is_instance_valid(_top_shade):
		_top_shade.position = Vector2(0.0, 0.0)
		_top_shade.size = Vector2(width, shade_h)
		_top_shade.queue_redraw()
	if is_instance_valid(_bottom_shade):
		_bottom_shade.position = Vector2(0.0, SHADE_HEIGHT + frame_h - radius)
		_bottom_shade.size = Vector2(width, shade_h)
		_bottom_shade.queue_redraw()
	_raise_shades()


func _raise_shades() -> void:
	if is_instance_valid(_top_shade):
		move_child(_top_shade, get_child_count() - 1)
	if is_instance_valid(_bottom_shade):
		move_child(_bottom_shade, get_child_count() - 1)
