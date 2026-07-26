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
## Digits that appear in the logged session span (modify mode yellow).
var _logged_digits: Array[int] = []
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


## Yellow = digit appears in the logged session span; green = allowed outside it.
func set_logged_digits(digits: Array) -> void:
	_logged_digits.clear()
	for item in digits:
		var digit := int(item)
		if digit >= 0 and digit <= 9 and not _logged_digits.has(digit):
			_logged_digits.append(digit)
	queue_redraw()


func clear_logged_digits() -> void:
	_logged_digits.clear()
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
	var target := value + direction
	if target < 0 or target > 9:
		var peek := float(value) + float(direction) * PEEK_FRACTION
		_kill_tween()
		_tween = create_tween()
		_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_tween.tween_method(_set_scroll, _scroll, peek, BOUNCE_SECONDS * 0.45)
		_tween.tween_method(_set_scroll, peek, float(value), BOUNCE_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
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


func _is_logged(digit: int) -> bool:
	return _logged_digits.has(digit)


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
	if not _is_allowed(digit):
		return INVALID_RED
	if _is_logged(digit):
		return ORIGINAL_YELLOW
	return VALID_GREEN


func _draw() -> void:
	var row_h := _row_height()
	var center_y := size.y * 0.5
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.55, 0.55, 0.55, 1.0))
	if _font == null:
		return
	var font_size := UiScale.font_size(14)
	for digit in range(DIGIT_COUNT):
		var offset := (float(digit) - _scroll) * row_h
		var y := center_y + offset
		if y < -row_h or y > size.y + row_h:
			continue
		draw_rect(Rect2(0.0, y - row_h * 0.5, size.x, row_h), _digit_bg_color(digit))
		var dist := absf(offset) / row_h
		var alpha := clampf(1.0 - dist * 0.55, 0.25, 1.0)
		var color := Color(0.08, 0.08, 0.08, alpha)
		var text := str(digit)
		var text_size := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var pos := Vector2((size.x - text_size.x) * 0.5, y + text_size.y * 0.35)
		draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	draw_rect(
		Rect2(1.0, center_y - row_h * 0.5, size.x - 2.0, row_h),
		SELECTION_OUTLINE,
		false,
		UiScale.scale(2.0)
	)
	var fade_h := size.y * 0.28
	draw_rect(Rect2(0.0, 0.0, size.x, fade_h), Color(0.35, 0.35, 0.35, 0.4))
	draw_rect(Rect2(0.0, size.y - fade_h, size.x, fade_h), Color(0.35, 0.35, 0.35, 0.4))
