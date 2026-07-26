extends HBoxContainer
class_name TimeDigitPicker

signal time_changed(unix_time: int)

var _day_key: String = ""
var _min_unix: int = 0
var _max_unix: int = 0
var _hour_tens: DigitWheel
var _hour_units: DigitWheel
var _min_tens: DigitWheel
var _min_units: DigitWheel
var _colon: Label
var _updating := false
var _unix: int = 0
var _logged_start_unix: int = -1
var _logged_end_unix: int = -1


func _ready() -> void:
	add_theme_constant_override("separation", UiScale.scale_i(4))
	alignment = BoxContainer.ALIGNMENT_CENTER

	_hour_tens = DigitWheel.new()
	_hour_tens.value_changed.connect(_on_digit_changed)
	add_child(_hour_tens)

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
	_refresh_logged_digits()


func set_logged_time_range(start_unix: int, end_unix: int) -> void:
	_logged_start_unix = mini(start_unix, end_unix)
	_logged_end_unix = maxi(start_unix, end_unix)
	_refresh_logged_digits()


func clear_logged_time_range() -> void:
	_logged_start_unix = -1
	_logged_end_unix = -1
	_refresh_logged_digits()


func get_unix() -> int:
	return _unix


func set_bounds(min_unix: int, max_unix: int) -> void:
	_min_unix = min_unix
	_max_unix = maxi(max_unix, min_unix)
	_unix = clampi(_unix, _min_unix, _max_unix)
	_apply_unix_to_wheels(true)
	_refresh_allowed()
	_refresh_logged_digits()


func _style_label(label: Label) -> void:
	label.add_theme_font_size_override("font_size", UiScale.font_size(16))
	label.add_theme_color_override("font_color", UiScale.text_color())


func _on_digit_changed(_value: int) -> void:
	if _updating:
		return
	_unix = _resolve_unix_from_wheels()
	_apply_unix_to_wheels(true)
	_refresh_allowed()
	_refresh_logged_digits()
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


func _pick_closest_unix(candidates: Array, prefer: int) -> int:
	var best := int(candidates[0])
	var best_dist := absi(best - prefer)
	for unix in candidates:
		var dist := absi(int(unix) - prefer)
		if dist < best_dist:
			best_dist = dist
			best = int(unix)
	return best


func _wheel_hour() -> int:
	return clampi(_hour_tens.get_digit() * 10 + _hour_units.get_digit(), 0, 23)


func _wheel_minute() -> int:
	return clampi(_min_tens.get_digit() * 10 + _min_units.get_digit(), 0, 59)


## All in-range unix times for a given Adelaide clock hour.
func _valid_unix_for_hour(hour: int) -> Array:
	var results: Array = []
	if hour < 0 or hour > 23:
		return results
	for minute in range(60):
		for unix in _unix_candidates_for_clock(hour, minute):
			results.append(unix)
	return results


func _hour_has_any_valid(hour: int) -> bool:
	return not _valid_unix_for_hour(hour).is_empty()


## After a wheel nudge: keep exact time if valid; else snap minutes to :00,
## or to the clamp edge when :00 is not available in that hour.
func _resolve_unix_from_wheels() -> int:
	var hour := _wheel_hour()
	var minute := _wheel_minute()
	var exact := _unix_candidates_for_clock(hour, minute)
	if not exact.is_empty():
		return _pick_closest_unix(exact, _unix)

	var hour_candidates := _valid_unix_for_hour(hour)
	if hour_candidates.is_empty():
		return clampi(_unix, _min_unix, _max_unix)

	var zero := _unix_candidates_for_clock(hour, 0)
	if not zero.is_empty():
		return _pick_closest_unix(zero, _unix)

	var c_min := int(hour_candidates[0])
	var c_max := c_min
	for unix in hour_candidates:
		var u := int(unix)
		c_min = mini(c_min, u)
		c_max = maxi(c_max, u)

	var hour_start := TimeUtils.clock_on_productivity_day(_day_key, hour, 0)
	var hour_end := TimeUtils.clock_on_productivity_day(_day_key, hour, 59)
	# Clipped by the early bound (e.g. jump to 01:xx when min is 01:45) → 01:45.
	if c_min > hour_start or c_min == _min_unix:
		return c_min
	# Clipped by the late bound (e.g. jump to 09:xx when max is 09:09) → 09:09.
	if c_max < hour_end or c_max == _max_unix:
		return c_max
	return _pick_closest_unix(hour_candidates, _unix)


func _apply_unix_to_wheels(animate: bool) -> void:
	_updating = true
	var dt := TimeUtils.unix_to_adelaide(_unix)
	var hour: int = int(dt.hour)
	var minute: int = int(dt.minute)
	_hour_tens.set_digit(hour / 10, animate)
	_hour_units.set_digit(hour % 10, animate)
	_min_tens.set_digit(minute / 10, animate)
	_min_units.set_digit(minute % 10, animate)
	_style_label(_colon)
	_updating = false


func _refresh_logged_digits() -> void:
	if _logged_start_unix < 0 or _logged_end_unix < 0:
		_hour_tens.clear_logged_digits()
		_hour_units.clear_logged_digits()
		_min_tens.clear_logged_digits()
		_min_units.clear_logged_digits()
		return
	_hour_tens.set_logged_digits(_digits_in_logged_range(0))
	_hour_units.set_logged_digits(_digits_in_logged_range(1))
	_min_tens.set_logged_digits(_digits_in_logged_range(2))
	_min_units.set_logged_digits(_digits_in_logged_range(3))


func _digits_in_logged_range(slot: int) -> Array:
	var found: Dictionary = {}
	var dt_now := TimeUtils.unix_to_adelaide(_unix)
	var cur_hour_tens: int = int(dt_now.hour) / 10
	var cur_hour: int = int(dt_now.hour)
	var cur_min_tens: int = int(dt_now.minute) / 10
	var cursor := _logged_start_unix - (_logged_start_unix % 60)
	var end_floor := _logged_end_unix - (_logged_end_unix % 60)
	while cursor <= end_floor:
		var dt := TimeUtils.unix_to_adelaide(cursor)
		var hour: int = int(dt.hour)
		var minute: int = int(dt.minute)
		match slot:
			0:
				found[hour / 10] = true
			1:
				if hour / 10 == cur_hour_tens:
					found[hour % 10] = true
			2:
				if hour == cur_hour:
					found[minute / 10] = true
			3:
				if hour == cur_hour and minute / 10 == cur_min_tens:
					found[minute % 10] = true
		cursor += 60
	return found.keys()


func _refresh_allowed() -> void:
	_hour_tens.set_allowed_digits(_allowed_for_slot(0))
	_hour_units.set_allowed_digits(_allowed_for_slot(1))
	_min_tens.set_allowed_digits(_allowed_for_slot(2))
	_min_units.set_allowed_digits(_allowed_for_slot(3))


## A digit is allowed if any completion of the smaller places can land in-range.
## Slots: 0=hour tens, 1=hour units, 2=min tens, 3=min units.
func _allowed_for_slot(slot: int) -> Array:
	var allowed: Array = []
	var dt := TimeUtils.unix_to_adelaide(_unix)
	var hour_tens: int = int(dt.hour) / 10
	var hour_units: int = int(dt.hour) % 10
	var min_tens: int = int(dt.minute) / 10
	for digit in range(10):
		match slot:
			0:
				# Any hour-units + minutes that make this tens digit valid.
				var found := false
				for hu in range(10):
					var hour := digit * 10 + hu
					if hour > 23:
						continue
					if _hour_has_any_valid(hour):
						found = true
						break
				if found:
					allowed.append(digit)
			1:
				var hour := hour_tens * 10 + digit
				if hour <= 23 and _hour_has_any_valid(hour):
					allowed.append(digit)
			2:
				var hour := hour_tens * 10 + hour_units
				if hour > 23:
					continue
				var decade_ok := false
				for u in range(10):
					var minute := digit * 10 + u
					if minute > 59:
						continue
					if not _unix_candidates_for_clock(hour, minute).is_empty():
						decade_ok = true
						break
				if decade_ok:
					allowed.append(digit)
			3:
				var hour := hour_tens * 10 + hour_units
				var minute := min_tens * 10 + digit
				if hour <= 23 and minute <= 59:
					if not _unix_candidates_for_clock(hour, minute).is_empty():
						allowed.append(digit)
	if allowed.is_empty():
		match slot:
			0:
				allowed.append(hour_tens)
			1:
				allowed.append(hour_units)
			2:
				allowed.append(min_tens)
			3:
				allowed.append(int(dt.minute) % 10)
	return allowed
