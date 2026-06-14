extends Node

const DAY_START_HOUR := 3
const SECONDS_PER_DAY := 86400
const OFFSET_STD := 9 * 3600 + 30 * 60
const OFFSET_DST := 10 * 3600 + 30 * 60
const TIMEZONE_NAME := "Adelaide, South Australia"


static func get_productivity_day_key(unix: int) -> String:
	var dt := unix_to_adelaide(unix)
	if dt.hour < DAY_START_HOUR:
		return previous_day_key(date_key(dt.year, dt.month, dt.day))
	return date_key(dt.year, dt.month, dt.day)


static func get_productivity_day_key_now() -> String:
	return get_productivity_day_key(int(Time.get_unix_time_from_system()))


static func parse_day_key(day_key: String) -> Dictionary:
	var parts := day_key.split("-")
	return {
		"year": int(parts[0]),
		"month": int(parts[1]),
		"day": int(parts[2]),
		"hour": DAY_START_HOUR,
		"minute": 0,
		"second": 0,
	}


static func day_key_to_unix(day_key: String) -> int:
	return adelaide_to_unix(parse_day_key(day_key))


static func get_next_3am_unix(unix: int) -> int:
	var dt := unix_to_adelaide(unix)
	var boundary_unix := adelaide_to_unix({
		"year": dt.year,
		"month": dt.month,
		"day": dt.day,
		"hour": DAY_START_HOUR,
		"minute": 0,
		"second": 0,
	})
	if unix >= boundary_unix:
		var y: int = dt.year
		var m: int = dt.month
		var d: int = dt.day + 1
		if d > days_in_month(y, m):
			d = 1
			m += 1
			if m > 12:
				m = 1
				y += 1
		boundary_unix = adelaide_to_unix({
			"year": y,
			"month": m,
			"day": d,
			"hour": DAY_START_HOUR,
			"minute": 0,
			"second": 0,
		})
	return boundary_unix


static func split_session_at_day_boundaries(start_unix: int, end_unix: int) -> Array:
	var segments: Array = []
	var cursor := start_unix
	while cursor < end_unix:
		var segment_end := mini(get_next_3am_unix(cursor), end_unix)
		var minutes := int((segment_end - cursor) / 60.0)
		if minutes > 0:
			segments.append({
				"day_key": get_productivity_day_key(cursor),
				"start_unix": cursor,
				"end_unix": segment_end,
				"minutes": minutes,
			})
		cursor = segment_end
	return segments


static func format_minutes_hm(minutes: int) -> String:
	var hours := minutes / 60
	var mins := minutes % 60
	return "%02d:%02d" % [hours, mins]


static func format_time(unix: int) -> String:
	var dt := unix_to_adelaide(unix)
	return "%02d:%02d" % [dt.hour, dt.minute]


static func format_day_label(day_key: String) -> String:
	var dt := parse_day_key(day_key)
	var weekday: int = weekday_from_calendar_date(dt.year, dt.month, dt.day)
	var day_names: Array[String] = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
	var day_name: String = day_names[weekday]
	return "%s %d/%d" % [day_name, dt.day, dt.month]


static func get_last_n_productivity_days(count: int) -> Array:
	var keys: Array = []
	var cursor_key := get_productivity_day_key_now()
	for i in count:
		keys.append(cursor_key)
		cursor_key = previous_day_key(cursor_key)
	keys.reverse()
	return keys


static func iso_from_unix(unix: int) -> String:
	var dt := unix_to_adelaide(unix)
	return "%04d-%02d-%02dT%02d:%02d:%02d" % [
		dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second
	]


static func unix_from_iso(iso: String) -> int:
	var parts: PackedStringArray = iso.split("T", false)
	if parts.size() < 2:
		return 0
	var date_bits: PackedStringArray = parts[0].split("-", false)
	var time_bits: PackedStringArray = parts[1].split(":", false)
	if date_bits.size() < 3 or time_bits.size() < 3:
		return 0
	var dt := {
		"year": int(date_bits[0]),
		"month": int(date_bits[1]),
		"day": int(date_bits[2]),
		"hour": int(time_bits[0]),
		"minute": int(time_bits[1]),
		"second": int(time_bits[2]),
	}
	return adelaide_to_unix(dt)


static func unix_to_adelaide(unix: int) -> Dictionary:
	var offset: int = adelaide_offset_seconds(unix)
	return unix_to_datetime_dict(unix + offset)


static func adelaide_to_unix(dt: Dictionary) -> int:
	var naive_unix: int = datetime_to_unix_utc(dt)
	var unix_std: int = naive_unix - OFFSET_STD
	if adelaide_datetime_matches(unix_std, dt):
		return unix_std
	var unix_dst: int = naive_unix - OFFSET_DST
	if adelaide_datetime_matches(unix_dst, dt):
		return unix_dst
	return unix_std


static func adelaide_offset_seconds(unix: int) -> int:
	if is_adelaide_dst(unix):
		return OFFSET_DST
	return OFFSET_STD


static func is_adelaide_dst(unix: int) -> bool:
	var approx: Dictionary = unix_to_datetime_dict(unix + OFFSET_STD)
	var year: int = approx.year
	var month: int = approx.month
	if month >= 5 and month <= 9:
		return false
	if month >= 11 or month <= 3:
		return true
	if month == 10:
		return unix >= dst_start_unix(year)
	if month == 4:
		return unix < dst_end_unix(year)
	return false


static func dst_start_unix(year: int) -> int:
	var day: int = first_sunday_day(year, 10)
	return adelaide_to_unix({
		"year": year,
		"month": 10,
		"day": day,
		"hour": 2,
		"minute": 0,
		"second": 0,
	})


static func dst_end_unix(year: int) -> int:
	var day: int = first_sunday_day(year, 4)
	return adelaide_to_unix({
		"year": year,
		"month": 4,
		"day": day,
		"hour": 3,
		"minute": 0,
		"second": 0,
	})


static func first_sunday_day(year: int, month: int) -> int:
	var first_weekday: int = weekday_from_calendar_date(year, month, 1)
	return 1 + (7 - first_weekday) % 7


static func adelaide_datetime_matches(unix: int, dt: Dictionary) -> bool:
	var local: Dictionary = unix_to_adelaide(unix)
	return (
		local.year == dt.year
		and local.month == dt.month
		and local.day == dt.day
		and local.hour == dt.hour
		and local.minute == dt.minute
		and local.second == dt.second
	)


static func unix_to_datetime_dict(unix: int) -> Dictionary:
	var days: int = unix / 86400
	var rem: int = unix % 86400
	if rem < 0:
		rem += 86400
		days -= 1
	var z: int = days + 719468
	var era: int = z / 146097
	if z < 0:
		era = (z - 146096) / 146097
	var doe: int = z - era * 146097
	var yoe: int = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
	var y: int = yoe + era * 400
	var doy: int = doe - (365 * yoe + yoe / 4 - yoe / 100)
	var mp: int = (5 * doy + 2) / 153
	var d: int = doy - (153 * mp + 2) / 5 + 1
	var m: int = mp + 3 if mp < 10 else mp - 9
	if mp < 10:
		y += 1
	return {
		"year": y,
		"month": m,
		"day": d,
		"hour": rem / 3600,
		"minute": (rem % 3600) / 60,
		"second": rem % 60,
		"weekday": weekday_from_calendar_date(y, m, d),
	}


static func weekday_from_calendar_date(year: int, month: int, day: int) -> int:
	var noon_unix: int = datetime_to_unix_utc({
		"year": year,
		"month": month,
		"day": day,
		"hour": 12,
		"minute": 0,
		"second": 0,
	})
	return (noon_unix / 86400 + 4) % 7


static func datetime_to_unix_utc(dt: Dictionary) -> int:
	var month: int = dt.month
	var year: int = dt.year
	if month > 2:
		month -= 3
	else:
		month += 9
		year -= 1
	var era: int = year / 400
	var yoe: int = year - era * 400
	var doy: int = (153 * month + 2) / 5 + dt.day - 1
	var doe: int = yoe * 365 + yoe / 4 - yoe / 100 + doy
	var days: int = era * 146097 + doe - 719468
	return days * 86400 + dt.hour * 3600 + dt.minute * 60 + dt.second


static func date_key(year: int, month: int, day: int) -> String:
	return "%04d-%02d-%02d" % [year, month, day]


static func previous_day_key(day_key: String) -> String:
	var parts := day_key.split("-")
	var year: int = int(parts[0])
	var month: int = int(parts[1])
	var day: int = int(parts[2]) - 1
	if day < 1:
		month -= 1
		if month < 1:
			month = 12
			year -= 1
		day = days_in_month(year, month)
	return date_key(year, month, day)


static func days_in_month(year: int, month: int) -> int:
	if month == 2:
		if year % 4 == 0 and (year % 100 != 0 or year % 400 == 0):
			return 29
		return 28
	if month == 4 or month == 6 or month == 9 or month == 11:
		return 30
	return 31
