extends Control
class_name ElectricityRowOverlay

## Full-rect overlay on a week-by-week (or similar) row for yellow lightning.

var _fx := YellowElectricityFx.new()
var _active := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	z_index = 5
	set_process(false)


func set_active(active: bool) -> void:
	_active = active
	set_process(active)
	if not active:
		_fx.clear()
		queue_redraw()


func _process(delta: float) -> void:
	var ctrl := ElectricityControl.get_instance()
	if not _active or ctrl == null or not ctrl.is_on():
		_fx.clear()
		queue_redraw()
		return
	var vp := get_viewport().get_visible_rect()
	var visible := vp.intersects(get_global_rect())
	_fx.sync_targets([{
		"id": "row",
		"kind": "rect",
		"rect": Rect2(Vector2.ZERO, size).grow(-UiScale.scale(1.0)),
		"visible": visible,
		"weight": 1.0,
	}])
	_fx.process(delta, ctrl)
	queue_redraw()


func _draw() -> void:
	var ctrl := ElectricityControl.get_instance()
	if ctrl != null and ctrl.is_on():
		_fx.draw(self, ctrl)
