extends HBoxContainer
class_name TimeDigitPicker

signal time_changed(unix_time: int)

var _day_key: String = ""
var _min_unix: int = 0
var _max_unix: int = 0
var _hour_tens_label: Label
var _hour_units: DigitWheel
var _min_tens: DigitWheel
var _min_units: DigitWheel
var _colon: Label
var _updating := false
var _unix: int = 0
var _original_unix: int = -1


func _ready() -> void:
	add_theme_constant_override("separation", UiScale.scale_i(4))
	alignment = BoxContainer.ALIGNMENT_CENTER
	_hour_tens_label = Label.new()
	_hour_tens_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hour_tens_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hour_tens_label.custom_minimum_size = Vector2(UiScale.scale(18), UiScale.scale(56))
	_style_label(_hour_tens_label)
	add_child(_hour_tens_label)

	_hour_units = DigitWheel.new()
	_hour_units.value_changed.connect(_on_digit_changed)
	add_child(_hour_units)

	_colon = Label.new()
	_colon.text = ":"
	_colon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_colon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_style_label(_colon)
	add_child(_colon)

	_min_tens = DigitWheel.new()
	_min_tens.value_changed.connect(_on_digit_changed)
	add_child(_min_tens)

	_min_units = DigitWheel.new()
	_min_units.value_changed.connect(_on_digit_changed)
	add_child(_min_units)


func configure(day_key: String, unix_time: int, min_unix: int, max_unix: int) -> void:
	_day_key = day_key
	_min_unix = min_unix
	_max_unix = maxi(max_unix, min_unix)
	_unix = clampi(unix_time, _min_unix, _max_unix)
	_apply_unix_to_wheels(false)
	_refresh_allowed()
	_refresh_original_digits()


func set_original_unix(unix_time: int) -> void:
	_original_unix = unix_time
	_refresh_original_digits()


func clear_original_unix() -> void:
	_original_unix = -1
	_refresh_original_digits()


func get_unix() -> int:
	return _unix


func set_bounds(min_unix: int, max_unix: int) -> void:
	_min_unix = min_unix
	_max_unix = maxi(max_unix, min_unix)
	_unix = clampi(_unix, _min_unix, _max_unix)
	_apply_unix_to_wheels(true)
	_refresh_allowed()


func _style_label(label: Label) -> void:
	label.add_theme_font_size_override("font_size", UiScale.font_size(16))
	label.add_theme_color_override("font_color", UiScale.text_color())


func _on_digit_changed(_value: int) -> void:
	if _updating:
		return
	var composed := _compose_from_wheels()
	var clamped := clampi(composed, _min_unix, _max_unix)
	_unix = clamped
	_apply_unix_to_wheels(true)
	_refresh_allowed()
	time_changed.emit(_unix)


func _candidate_day_keys() -> Array:
	return [
		TimeUtils.previous_day_key(_day_key),
		_day_key,
		TimeUtils.next_day_key(_day_key),
	]


func _unix_candidates_for_clock(hour: int, minute: int) -> Array:
	var results: Array = []
	for key in _candidate_day_keys():
		var unix := TimeUtils.clock_on_productivity_day(str(key), hour, minute)
		if unix >= _min_unix and unix <= _max_unix:
			results.append(unix)
	return results


func _compose_from_wheels() -> int:
	var preferred_tens := int(_hour_tens_label.text) if not _hour_tens_label.text.is_empty() else 0
	var hour_units := _hour_units.get_digit()
	var minute := _min_tens.get_digit() * 10 + _min_units.get_digit()
	minute = clampi(minute, 0, 59)
	var best_unix := _unix
	var best_dist := 1 << 30
	var found := false
	for tens in range(3):
		var hour := tens * 10 + hour_units
		if hour > 23:
			continue
		for unix in _unix_candidates_for_clock(hour, minute):
			var dist := absi(int(unix) - _unix) + (0 if tens == preferred_tens else 30)
			if not found or dist < best_dist:
				found = true
				best_dist = dist
				best_unix = int(unix)
	if found:
		return best_unix
	var hour := clampi(preferred_tens * 10 + hour_units, 0, 23)
	return TimeUtils.clock_on_productivity_day(_day_key, hour, minute)


func _apply_unix_to_wheels(animate: bool) -> void:
	_updating = true
	var dt := TimeUtils.unix_to_adelaide(_unix)
	var hour: int = int(dt.hour)
	var minute: int = int(dt.minute)
	_hour_tens_label.text = str(hour / 10)
	_hour_units.set_digit(hour % 10, animate)
	_min_tens.set_digit(minute / 10, animate)
	_min_units.set_digit(minute % 10, animate)
	_style_label(_hour_tens_label)
	_style_label(_colon)
	_updating = false


func _refresh_original_digits() -> void:
	if _original_unix < 0:
		_hour_units.clear_original_digit()
		_min_tens.clear_original_digit()
		_min_units.clear_original_digit()
		return
	var dt := TimeUtils.unix_to_adelaide(_original_unix)
	var hour: int = int(dt.hour)
	var minute: int = int(dt.minute)
	_hour_units.set_original_digit(hour % 10)
	_min_tens.set_original_digit(minute / 10)
	_min_units.set_original_digit(minute % 10)


func _refresh_allowed() -> void:
	_hour_units.set_allowed_digits(_allowed_for_slot(0))
	_min_tens.set_allowed_digits(_allowed_for_slot(1))
	_min_units.set_allowed_digits(_allowed_for_slot(2))


func _allowed_for_slot(slot: int) -> Array:
	var allowed: Array = []
	var dt := TimeUtils.unix_to_adelaide(_unix)
	var hour_tens: int = int(dt.hour) / 10
	var hour_units: int = int(dt.hour) % 10
	var min_tens: int = int(dt.minute) / 10
	var min_units: int = int(dt.minute) % 10
	for digit in range(10):
		if slot == 0:
			var digit_ok := false
			for tens in range(3):
				var hour := tens * 10 + digit
				if hour > 23:
					continue
				var minute := min_tens * 10 + min_units
				if minute > 59:
					continue
				if not _unix_candidates_for_clock(hour, minute).is_empty():
					digit_ok = true
					break
			if digit_ok:
				allowed.append(digit)
			continue
		var test_hour_tens := hour_tens
		var test_hour_units := hour_units
		var test_min_tens := min_tens
		var test_min_units := min_units
		match slot:
			1:
				test_min_tens = digit
			2:
				test_min_units = digit
		var hour := test_hour_tens * 10 + test_hour_units
		var minute := test_min_tens * 10 + test_min_units
		if hour > 23 or minute > 59:
			continue
		if not _unix_candidates_for_clock(hour, minute).is_empty():
			allowed.append(digit)
	if allowed.is_empty():
		match slot:
			0:
				allowed.append(hour_units)
			1:
				allowed.append(min_tens)
			2:
				allowed.append(min_units)
	return allowed
