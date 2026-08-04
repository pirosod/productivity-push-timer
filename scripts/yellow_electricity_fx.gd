extends RefCounted
class_name YellowElectricityFx

## Procedural yellow lightning: row borders, dots, connectors, and soft band glow.
## Visibility-gated with ease-in emission so scrolling away stops strands cleanly.

var _rng := RandomNumberGenerator.new()
var _time := 0.0
## id -> { ease, visible, kind, data... }
var _targets: Dictionary = {}
## Active bolts.
var _strands: Array = []


func _init() -> void:
	_rng.randomize()


func clear() -> void:
	_targets.clear()
	_strands.clear()


func has_activity() -> bool:
	return not _strands.is_empty() or not _targets.is_empty()


## Replace target set for this frame. Each entry:
## { "id": String, "kind": "rect"|"dot"|"path"|"band", "visible": bool, ... }
## rect: "rect" Rect2
## dot: "center" Vector2, "radius" float
## path: "points" PackedVector2Array
## band: "rect" Rect2 (soft fill + perimeter)
func sync_targets(entries: Array) -> void:
	var seen: Dictionary = {}
	for entry in entries:
		var id := str(entry.get("id", ""))
		if id.is_empty():
			continue
		seen[id] = true
		var visible := bool(entry.get("visible", false))
		if not _targets.has(id):
			_targets[id] = {"ease": 0.0, "pulse": _rng.randf() * TAU}
		var t: Dictionary = _targets[id]
		t["visible"] = visible
		t["kind"] = str(entry.get("kind", "rect"))
		t["rect"] = entry.get("rect", Rect2())
		t["center"] = entry.get("center", Vector2.ZERO)
		t["radius"] = float(entry.get("radius", 6.0))
		t["points"] = entry.get("points", PackedVector2Array())
		t["weight"] = float(entry.get("weight", 1.0))
		_targets[id] = t
	var drop: Array = []
	for id in _targets.keys():
		if not seen.has(id):
			drop.append(id)
	for id in drop:
		_targets.erase(id)
	_strands = _strands.filter(func(s: Dictionary) -> bool: return seen.has(str(s.get("target_id", ""))))


func process(delta: float, ctrl: ElectricityControl) -> void:
	if ctrl == null or not ctrl.is_on():
		_strands.clear()
		for id in _targets.keys():
			_targets[id]["ease"] = 0.0
		return
	_time += delta
	var ease_in := maxf(ctrl.ease_in_seconds, 0.05)
	for id in _targets.keys():
		var t: Dictionary = _targets[id]
		if bool(t.get("visible", false)):
			t["ease"] = minf(1.0, float(t.get("ease", 0.0)) + delta / ease_in)
		else:
			t["ease"] = 0.0
		_targets[id] = t

	_strands = _strands.filter(func(s: Dictionary) -> bool:
		var tid := str(s.get("target_id", ""))
		if not _targets.has(tid):
			return false
		if float(_targets[tid].get("ease", 0.0)) <= 0.001:
			return false
		s["life"] = float(s.get("life", 0.0)) - delta
		s["progress"] = float(s.get("progress", 0.0)) + float(s.get("speed", 1.0)) * delta
		return float(s.get("life", 0.0)) > 0.0
	)

	var desired := maxi(1, ctrl.strand_count)
	for id in _targets.keys():
		var t: Dictionary = _targets[id]
		var ease := float(t.get("ease", 0.0))
		if ease <= 0.001 or not bool(t.get("visible", false)):
			continue
		var pulse := 0.55 + 0.45 * sin(_time * (1.6 + float(t.get("pulse", 0.0)) * 0.2) + float(t.get("pulse", 0.0)))
		var speed_wobble := 0.7 + 0.6 * _rng.randf()
		var want := int(round(float(desired) * ease * pulse * float(t.get("weight", 1.0)) * speed_wobble))
		want = clampi(want, 0, desired + 2)
		var have := 0
		for s in _strands:
			if str(s.get("target_id", "")) == id:
				have += 1
		while have < want:
			_spawn_strand(id, t, ctrl)
			have += 1


func draw(ci: CanvasItem, ctrl: ElectricityControl) -> void:
	if ctrl == null or not ctrl.is_on():
		return
	var intensity := ctrl.intensity
	var bloom := ctrl.bloom
	# Soft band fills first.
	for id in _targets.keys():
		var t: Dictionary = _targets[id]
		var ease := float(t.get("ease", 0.0))
		if ease <= 0.001:
			continue
		if str(t.get("kind", "")) != "band":
			continue
		var rect: Rect2 = t.get("rect", Rect2())
		if rect.size.x <= 1.0 or rect.size.y <= 1.0:
			continue
		var glow := ctrl.glow_color
		glow.a *= 0.18 * ease * intensity * bloom
		ci.draw_rect(rect, glow, true)
		var edge := ctrl.glow_color
		edge.a *= 0.35 * ease * intensity
		ci.draw_rect(rect, edge, false, maxf(1.0, UiScale.scale(1.5)))

	for s in _strands:
		var pts: PackedVector2Array = s.get("points", PackedVector2Array())
		if pts.size() < 2:
			continue
		var life_fade := clampf(float(s.get("life", 0.0)) / maxf(float(s.get("life_max", 0.4)), 0.05), 0.0, 1.0)
		var tid := str(s.get("target_id", ""))
		var ease := 1.0
		if _targets.has(tid):
			ease = float(_targets[tid].get("ease", 1.0))
		var w := float(s.get("weight", 1.0))
		var core_w := maxf(1.0, UiScale.scale(1.2) * intensity * w)
		var glow_w := core_w * (2.2 + bloom * 1.4)
		var glow := ctrl.glow_color
		glow.a *= 0.45 * life_fade * ease * intensity
		var core := ctrl.core_color
		core.a *= 0.9 * life_fade * ease * intensity
		_draw_polyline(ci, pts, glow, glow_w)
		_draw_polyline(ci, pts, core, core_w)


func _draw_polyline(ci: CanvasItem, pts: PackedVector2Array, color: Color, width: float) -> void:
	for i in pts.size() - 1:
		ci.draw_line(pts[i], pts[i + 1], color, width, true)


func _spawn_strand(target_id: String, t: Dictionary, ctrl: ElectricityControl) -> void:
	var kind := str(t.get("kind", "rect"))
	var base := _base_path(t, kind)
	if base.size() < 2:
		return
	var amp := UiScale.scale(ctrl.jag_amplitude) * float(t.get("weight", 1.0))
	var jagged := _jagged_path(base, amp)
	var life := _rng.randf_range(0.18, 0.55)
	var speed := _rng.randf_range(ctrl.min_speed, maxf(ctrl.min_speed, ctrl.max_speed))
	# Advance a window along the path for a traveling feel.
	var start_frac := _rng.randf()
	var window := _rng.randf_range(0.18, 0.42)
	var sliced := _slice_path(jagged, start_frac, window)
	if sliced.size() < 2:
		sliced = jagged
	_strands.append({
		"target_id": target_id,
		"points": sliced,
		"life": life,
		"life_max": life,
		"speed": speed,
		"progress": start_frac,
		"weight": float(t.get("weight", 1.0)),
	})


func _base_path(t: Dictionary, kind: String) -> PackedVector2Array:
	match kind:
		"dot":
			return _circle_path(t.get("center", Vector2.ZERO), float(t.get("radius", 6.0)) * 1.35, 14)
		"path":
			var pts: PackedVector2Array = t.get("points", PackedVector2Array())
			return pts
		"band", "rect":
			return _rect_path(t.get("rect", Rect2()))
		_:
			return PackedVector2Array()


func _rect_path(rect: Rect2) -> PackedVector2Array:
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return PackedVector2Array()
	var p := PackedVector2Array()
	var tl := rect.position
	var tr := rect.position + Vector2(rect.size.x, 0)
	var br := rect.position + rect.size
	var bl := rect.position + Vector2(0, rect.size.y)
	# Sample each edge so jag has room to work.
	_append_edge(p, tl, tr, 4)
	_append_edge(p, tr, br, 3)
	_append_edge(p, br, bl, 4)
	_append_edge(p, bl, tl, 3)
	return p


func _append_edge(out: PackedVector2Array, a: Vector2, b: Vector2, segs: int) -> void:
	for i in segs:
		var t := float(i) / float(segs)
		out.append(a.lerp(b, t))
	out.append(b)


func _circle_path(center: Vector2, radius: float, segs: int) -> PackedVector2Array:
	var p := PackedVector2Array()
	if radius <= 0.5:
		return p
	for i in segs + 1:
		var a := TAU * float(i) / float(segs)
		p.append(center + Vector2(cos(a), sin(a)) * radius)
	return p


func _jagged_path(base: PackedVector2Array, amplitude: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	if base.size() < 2:
		return out
	for i in base.size():
		var p: Vector2 = base[i]
		if i == 0 or i == base.size() - 1:
			out.append(p)
			continue
		var prev: Vector2 = base[i - 1]
		var next: Vector2 = base[mini(i + 1, base.size() - 1)]
		var tangent := (next - prev).normalized()
		var normal := Vector2(-tangent.y, tangent.x)
		out.append(p + normal * _rng.randf_range(-amplitude, amplitude))
	return out


func _slice_path(path: PackedVector2Array, start_frac: float, window: float) -> PackedVector2Array:
	if path.size() < 2:
		return path
	var total := 0.0
	var lengths: Array = [0.0]
	for i in path.size() - 1:
		total += path[i].distance_to(path[i + 1])
		lengths.append(total)
	if total <= 0.001:
		return path
	var start_d := fposmod(start_frac, 1.0) * total
	var end_d := start_d + clampf(window, 0.05, 1.0) * total
	var out := PackedVector2Array()
	var d := start_d
	while d <= end_d + 0.001:
		out.append(_point_at_distance(path, lengths, fposmod(d, total), total))
		d += maxf(total / 24.0, 2.0)
	return out


func _point_at_distance(path: PackedVector2Array, lengths: Array, dist: float, total: float) -> Vector2:
	dist = clampf(dist, 0.0, total)
	for i in path.size() - 1:
		var a := float(lengths[i])
		var b := float(lengths[i + 1])
		if dist <= b or i == path.size() - 2:
			var span := maxf(b - a, 0.0001)
			var t := (dist - a) / span
			return path[i].lerp(path[i + 1], t)
	return path[path.size() - 1]
