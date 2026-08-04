extends Control
class_name TodayVertexFront

const SMALL_DOT_RADIUS_BASE := 3.0

var _day_key: String = ""
var _include_live: bool = false
var _scroll_offset_y: float = 0.0
var _content_size: Vector2 = Vector2.ZERO
var _row_centers_y: Array = []
var _table: SessionTable
var _fx := YellowElectricityFx.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 10
	z_as_relative = true
	clip_contents = true
	set_process(true)


func configure(day_key: String, include_live: bool, row_centers_y: Array = []) -> void:
	_day_key = day_key
	_include_live = include_live
	_row_centers_y = row_centers_y
	queue_redraw()


func set_session_table(table: SessionTable) -> void:
	_table = table


func set_view(scroll_offset_y: float, viewport_size: Vector2, content_size: Vector2) -> void:
	_scroll_offset_y = scroll_offset_y
	_content_size = content_size
	size = viewport_size
	queue_redraw()


func _process(delta: float) -> void:
	var ctrl := ElectricityControl.get_instance()
	if ctrl == null or not ctrl.is_on() or _day_key.is_empty():
		_fx.clear()
		return
	_sync_electricity_targets()
	_fx.process(delta, ctrl)
	queue_redraw()


func _draw() -> void:
	if _day_key.is_empty() or size.x <= 1.0 or size.y <= 1.0 or _content_size.y <= 1.0:
		return
	var layout := TodayChartLayout.build(_day_key, _include_live, _content_size, _row_centers_y)
	var points: Array = layout["points"]
	var colors: Array = layout["colors"]
	var row_height := float(layout["row_height"])
	var radius := UiScale.scale(SMALL_DOT_RADIUS_BASE)
	for i in points.size():
		var point: Vector2 = points[i]
		var screen_y := point.y - _scroll_offset_y
		if screen_y < -row_height or screen_y > size.y + row_height:
			continue
		var color: Color = colors[i] if i < colors.size() else TodayChartStyle.vertex_color_for_minutes(0.0)
		draw_circle(Vector2(point.x, screen_y), radius, color)
	var ctrl := ElectricityControl.get_instance()
	if ctrl != null and ctrl.is_on():
		_fx.draw(self, ctrl)


func _sync_electricity_targets() -> void:
	var entries: Array = []
	var view := Rect2(Vector2.ZERO, size).grow(UiScale.scale(8.0))
	var layout := TodayChartLayout.build(_day_key, _include_live, _content_size, _row_centers_y)
	var points: Array = layout["points"]
	var color_minutes: Array = layout["color_minutes_list"]
	var row_height := float(layout["row_height"])
	var radius := UiScale.scale(SMALL_DOT_RADIUS_BASE)
	var yellow_screen_points: Array = []

	for i in points.size():
		var minutes := float(color_minutes[i]) if i < color_minutes.size() else 0.0
		if not TodayChartStyle.is_yellow_band(minutes):
			continue
		var point: Vector2 = points[i]
		var screen := Vector2(point.x, point.y - _scroll_offset_y)
		var visible := view.has_point(screen) or absf(screen.y - size.y * 0.5) < size.y
		visible = screen.y >= -row_height and screen.y <= size.y + row_height
		yellow_screen_points.append({"i": i, "screen": screen, "visible": visible})
		entries.append({
			"id": "dot_%d" % i,
			"kind": "dot",
			"center": screen,
			"radius": radius * 2.2,
			"visible": visible,
			"weight": 1.35,
		})

	# Connectors between consecutive yellow dots that are both in play.
	for n in yellow_screen_points.size() - 1:
		var a: Dictionary = yellow_screen_points[n]
		var b: Dictionary = yellow_screen_points[n + 1]
		if int(a["i"]) + 1 != int(b["i"]):
			continue
		var pa: Vector2 = a["screen"]
		var pb: Vector2 = b["screen"]
		var path := PackedVector2Array([pa, pb])
		var visible := bool(a["visible"]) or bool(b["visible"])
		entries.append({
			"id": "path_%d_%d" % [int(a["i"]), int(b["i"])],
			"kind": "path",
			"points": path,
			"visible": visible,
			"weight": 0.85,
		})

	# Yellow session row borders (table space → this overlay).
	if is_instance_valid(_table):
		var origin := global_position
		var row_i := 0
		for child in _table.get_children():
			if not (child is SessionRow):
				continue
			var row := child as SessionRow
			# Tint minutes stored indirectly via stripe; use layout color list by display order.
			var minutes := float(color_minutes[row_i]) if row_i < color_minutes.size() else -1.0
			row_i += 1
			if minutes < 0.0 or not TodayChartStyle.is_yellow_band(minutes):
				continue
			var gr := row.get_global_rect()
			var local := Rect2(gr.position - origin, gr.size)
			var visible := view.intersects(local)
			entries.append({
				"id": "row_%d" % row_i,
				"kind": "rect",
				"rect": local.grow(-UiScale.scale(1.0)),
				"visible": visible,
				"weight": 1.0,
			})

	_fx.sync_targets(entries)
