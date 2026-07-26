extends Control
class_name DigitWheel

signal value_changed(value: int)

const DIGIT_COUNT := 10
const ROW_HEIGHT_BASE := 22.0
const PEEK_FRACTION := 0.38
const SNAP_SECONDS := 0.14
const BOUNCE_SECONDS := 0.18
const ORIGINAL_YELLOW := Color(0.95, 0.82, 0.12, 0.85)
const VALID_GREEN := Color(0.28, 0.82, 0.38, 0.75)
const INVALID_RED := Color(0.92, 0.22, 0.22, 0.72)
const SELECTION_OUTLINE := Color(0.08, 0.08, 0.08, 0.35)

var value: int = 0
var _scroll: float = 0.0
var _allowed: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
var _original_digit: int = -1
var _tween: Tween
var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	custom_minimum_size = Vector2(UiScale.scale(34), UiScale.scale(56))
	_font = ThemeDB.fallback_font
	_scroll = float(value)


func set_digit(digit: int, animate: bool = false) -> void:
	digit = clampi(digit, 0, 9)
	value = digit
	if animate:
		_animate_scroll_to(float(digit), SNAP_SECONDS)
	else:
		_kill_tween()
		_scroll = float(digit)
		queue_redraw()


func set_allowed_digits(digits: Array) -> void:
	_allowed.clear()
	for item in digits:
		var digit := int(item)
		if digit >= 0 and digit <= 9 and not _allowed.has(digit):
			_allowed.append(digit)
	if _allowed.is_empty():
		_allowed = [value]
	if not _allowed.has(value):
		set_digit(_nearest_allowed(value), true)
	queue_redraw()


func set_original_digit(digit: int) -> void:
	_original_digit = clampi(digit, -1, 9)
	queue_redraw()


func clear_original_digit() -> void:
	_original_digit = -1
	queue_redraw()


func get_digit() -> int:
	return value


func _row_height() -> float:
	return UiScale.scale(ROW_HEIGHT_BASE)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_nudge(-1)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_nudge(1)
			accept_event()


func _nudge(direction: int) -> void:
	var target := clampi(value + direction, 0, 9)
	if target == value:
		return
	if _is_allowed(target):
		value = target
		_animate_scroll_to(float(target), SNAP_SECONDS)
		value_changed.emit(value)
	else:
		_peek_and_bounce(target)


func _peek_and_bounce(toward: int) -> void:
	var peek := lerpf(float(value), float(toward), PEEK_FRACTION)
	_kill_tween()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_set_scroll, _scroll, peek, BOUNCE_SECONDS * 0.45)
	_tween.tween_method(_set_scroll, peek, float(value), BOUNCE_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _animate_scroll_to(target: float, duration: float) -> void:
	_kill_tween()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_set_scroll, _scroll, target, duration)


func _set_scroll(amount: float) -> void:
	_scroll = amount
	queue_redraw()


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


func _is_allowed(digit: int) -> bool:
	return _allowed.has(digit)


func _nearest_allowed(digit: int) -> int:
	var best: int = _allowed[0]
	var best_dist: int = absi(best - digit)
	for allowed in _allowed:
		var dist: int = absi(allowed - digit)
		if dist < best_dist:
			best = allowed
			best_dist = dist
	return best


func _digit_bg_color(digit: int) -> Color:
	if _original_digit < 0:
		if _is_allowed(digit):
			return Color(0.72, 0.72, 0.72, 1.0)
		return INVALID_RED
	if digit == _original_digit:
		return ORIGINAL_YELLOW
	if _is_allowed(digit):
		return VALID_GREEN
	return INVALID_RED


func _draw() -> void:
	var row_h := _row_height()
	var center_y := size.y * 0.5
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.55, 0.55, 0.55, 1.0))
	if _original_digit < 0:
		draw_rect(
			Rect2(0.0, center_y - row_h * 0.5, size.x, row_h),
			Color(0.35, 0.85, 0.45, 0.35)
		)
	if _font == null:
		return
	var font_size := UiScale.font_size(14)
	for digit in range(DIGIT_COUNT):
		var offset := (float(digit) - _scroll) * row_h
		var y := center_y + offset
		if y < -row_h or y > size.y + row_h:
			continue
		if _original_digit >= 0:
			draw_rect(Rect2(0.0, y - row_h * 0.5, size.x, row_h), _digit_bg_color(digit))
		elif not _is_allowed(digit):
			draw_rect(Rect2(0.0, y - row_h * 0.5, size.x, row_h), INVALID_RED)
		var dist := absf(offset) / row_h
		var alpha := clampf(1.0 - dist * 0.55, 0.25, 1.0)
		var color := Color(0.08, 0.08, 0.08, alpha)
		if _original_digit < 0 and not _is_allowed(digit):
			color = color.lerp(Color(0.95, 0.2, 0.2, 1.0), 0.45)
			color.a = alpha * 0.85
		var text := str(digit)
		var text_size := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var pos := Vector2((size.x - text_size.x) * 0.5, y + text_size.y * 0.35)
		draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	if _original_digit >= 0:
		draw_rect(
			Rect2(1.0, center_y - row_h * 0.5, size.x - 2.0, row_h),
			SELECTION_OUTLINE,
			false,
			UiScale.scale(2.0)
		)
	else:
		_draw_invalid_gradients(row_h, center_y)
	var fade_h := size.y * 0.28
	draw_rect(Rect2(0.0, 0.0, size.x, fade_h), Color(0.35, 0.35, 0.35, 0.4))
	draw_rect(Rect2(0.0, size.y - fade_h, size.x, fade_h), Color(0.35, 0.35, 0.35, 0.4))


func _draw_invalid_gradients(row_h: float, center_y: float) -> void:
	var above := value - 1
	var below := value + 1
	if above >= 0 and not _is_allowed(above):
		var top := center_y - row_h * 1.15
		var height := row_h * 0.9
		_draw_vertical_fade(Rect2(0.0, top, size.x, height), false)
	if below <= 9 and not _is_allowed(below):
		var top := center_y + row_h * 0.25
		var height := row_h * 0.9
		_draw_vertical_fade(Rect2(0.0, top, size.x, height), true)


func _draw_vertical_fade(rect: Rect2, fade_down: bool) -> void:
	var steps := 8
	for i in steps:
		var t := float(i) / float(steps - 1)
		var alpha := lerpf(0.0, 0.30, t)
		var y: float
		var h := rect.size.y / float(steps)
		if fade_down:
			y = rect.position.y + t * rect.size.y
		else:
			y = rect.position.y + (1.0 - t) * rect.size.y - h
		draw_rect(Rect2(rect.position.x, y, rect.size.x, h + 0.5), Color(0.95, 0.15, 0.15, alpha))
