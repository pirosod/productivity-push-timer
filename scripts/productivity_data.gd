extends Node

signal productivity_day_changed(new_day_key: String)

const DATA_FOLDER_NAME := "Productivity data"
const DATA_FILE_NAME := "productivity.json"
const VERSION := 3
const DEFAULT_WINDOW_WIDTH := 1110
const DEFAULT_WINDOW_HEIGHT := 1450
const LEGACY_WINDOW_WIDTH := 950
const LEGACY_WINDOW_HEIGHT := 1250

var low_goal_hours: float = 2.0
var medium_goal_hours: float = 4.0
var high_goal_hours: float = 7.0
var low_goal_color: Color = Color(0.45, 0.75, 1.0, 0.35)
var medium_goal_color: Color = Color(0.55, 0.9, 0.55, 0.35)
var high_goal_color: Color = Color(1.0, 0.75, 0.35, 0.35)

var _daily_totals: Dictionary = {}
var _sessions: Dictionary = {}
var _session_start_unix: int = -1
var _dirty := false
var _last_productivity_day_key: String = ""
var _day_check_seconds: float = 0.0

const DAY_CHECK_INTERVAL_SECONDS := 30.0
const ARCHIVE_FOLDER_NAME := "Archive"


func _ready() -> void:
	_remove_legacy_user_data()
	_ensure_data_dir()
	load_data()
	if not FileAccess.file_exists(_data_file_path()):
		_mark_dirty()
		save_data()
	_check_and_archive_new_day()
	set_process(true)
	call_deferred("_connect_window_close")


func _process(delta: float) -> void:
	_day_check_seconds += delta
	if _day_check_seconds >= DAY_CHECK_INTERVAL_SECONDS:
		_day_check_seconds = 0.0
		_check_and_archive_new_day()


func _connect_window_close() -> void:
	var root: Window = get_tree().root
	if not root.close_requested.is_connected(_on_window_close_requested):
		root.close_requested.connect(_on_window_close_requested)


func _on_window_close_requested() -> void:
	save_data()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_data()


func _ensure_data_dir() -> void:
	var dir_path := _data_dir_path()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)


func _data_dir_path() -> String:
	return _game_root_path() + DATA_FOLDER_NAME + "/"


func _data_file_path() -> String:
	return _data_dir_path() + DATA_FILE_NAME


func _game_root_path() -> String:
	var root: String
	if OS.has_feature("editor"):
		root = ProjectSettings.globalize_path("res://")
	else:
		root = OS.get_executable_path().get_base_dir()
	root = root.replace("\\", "/")
	if not root.ends_with("/"):
		root += "/"
	return root


func _remove_legacy_user_data() -> void:
	var legacy_dir := OS.get_user_data_dir().replace("\\", "/")
	if not legacy_dir.ends_with("/"):
		legacy_dir += "/"
	legacy_dir += "Productivity Data/"
	var legacy_file := legacy_dir + DATA_FILE_NAME
	if FileAccess.file_exists(legacy_file):
		DirAccess.remove_absolute(legacy_file)
	if DirAccess.dir_exists_absolute(legacy_dir):
		DirAccess.remove_absolute(legacy_dir)


func _archive_dir_path() -> String:
	return _data_dir_path() + ARCHIVE_FOLDER_NAME + "/"


func _ensure_archive_dir() -> void:
	var dir_path := _archive_dir_path()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)


func _check_and_archive_new_day() -> void:
	var today_key: String = TimeUtils.get_productivity_day_key_now()
	if _last_productivity_day_key.is_empty():
		_set_last_productivity_day_key(today_key)
		return
	if today_key == _last_productivity_day_key:
		return
	_commit_active_session_before_day(today_key)
	_archive_current_data()
	_set_last_productivity_day_key(today_key)
	productivity_day_changed.emit(today_key)


func _commit_active_session_before_day(new_day_key: String) -> void:
	if not is_session_active():
		return
	var boundary_unix := TimeUtils.day_key_to_unix(new_day_key)
	if _session_start_unix >= boundary_unix:
		return
	var segments: Array = TimeUtils.split_session_at_day_boundaries(
		_session_start_unix, boundary_unix
	)
	for segment in segments:
		_add_session_segment(segment)
	_session_start_unix = boundary_unix
	_mark_dirty()
	save_data()


func _set_last_productivity_day_key(day_key: String) -> void:
	_last_productivity_day_key = day_key
	_settings_set("last_productivity_day_key", day_key)
	_mark_dirty()
	save_data()


func _archive_current_data() -> void:
	_archive_named_backup("")


func _archive_named_backup(label: String) -> void:
	if _dirty:
		save_data()
	var source_path := _data_file_path()
	if not FileAccess.file_exists(source_path):
		return
	_ensure_archive_dir()
	var now_unix: int = int(Time.get_unix_time_from_system())
	var dt: Dictionary = TimeUtils.unix_to_adelaide(now_unix)
	var stamp := "%04d-%02d-%02d_%02d-%02d-%02d" % [
		dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second
	]
	var suffix := ("_%s" % label) if not label.is_empty() else ""
	var archive_path := _archive_dir_path() + "productivity%s_%s.json" % [suffix, stamp]
	var content: String = FileAccess.get_file_as_string(source_path)
	var file := FileAccess.open(archive_path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to archive productivity data to: " + archive_path)
		return
	file.store_string(content)
	file.close()


func is_session_active() -> bool:
	return _session_start_unix >= 0


func get_session_start_unix() -> int:
	return _session_start_unix


func start_session() -> void:
	if is_session_active():
		return
	_session_start_unix = int(Time.get_unix_time_from_system())


func end_session() -> void:
	if not is_session_active():
		return
	var end_unix := int(Time.get_unix_time_from_system())
	var segments: Array = TimeUtils.split_session_at_day_boundaries(_session_start_unix, end_unix)
	_session_start_unix = -1
	for segment in segments:
		_add_session_segment(segment)
	_mark_dirty()
	save_data()


func get_live_session_minutes() -> int:
	if not is_session_active():
		return 0
	var now := int(Time.get_unix_time_from_system())
	return int((now - _session_start_unix) / 60.0)


func get_live_minutes_for_day(day_key: String) -> int:
	var total := get_day_total_minutes(day_key)
	if is_session_active():
		var now := int(Time.get_unix_time_from_system())
		var segments: Array = TimeUtils.split_session_at_day_boundaries(_session_start_unix, now)
		for segment in segments:
			if segment.get("day_key", "") == day_key:
				total += int(segment.get("minutes", 0))
	return total


func get_day_total_minutes(day_key: String) -> int:
	return int(_daily_totals.get(day_key, 0))


func get_sessions_for_day(day_key: String) -> Array:
	var stored: Array = _sessions.get(day_key, [])
	return stored.duplicate(true)


func get_session_minutes_list_for_day(day_key: String, include_live: bool) -> Array:
	var minutes_list: Array = []
	for session in get_sessions_for_day(day_key):
		minutes_list.append(int(session.get("minutes", 0)))
	if include_live and is_session_active():
		var now := int(Time.get_unix_time_from_system())
		var segments: Array = TimeUtils.split_session_at_day_boundaries(_session_start_unix, now)
		for segment in segments:
			if str(segment.get("day_key", "")) == day_key:
				minutes_list.append(float(segment.get("minutes", 0)))
	return minutes_list


func get_session_cumulative_list_for_day(day_key: String, include_live: bool) -> Array:
	var cumulative_list: Array = []
	for session in get_sessions_for_day(day_key):
		cumulative_list.append(int(session.get("cumulative_minutes", 0)))
	if include_live and is_session_active():
		var live_for_day := get_live_minutes_for_day(day_key)
		if live_for_day > 0:
			cumulative_list.append(live_for_day)
	return cumulative_list


func get_average_session_minutes_from_list(minutes_list: Array) -> float:
	if minutes_list.is_empty():
		return 0.0
	var total := 0
	for value in minutes_list:
		total += int(value)
	return float(total) / float(minutes_list.size())


func get_today_average_session_minutes(day_key: String, include_live: bool) -> float:
	return get_average_session_minutes_from_list(
		get_session_minutes_list_for_day(day_key, include_live)
	)


func get_week_session_minutes_list() -> Array:
	var day_keys: Array = TimeUtils.get_last_n_productivity_days(7)
	var today_key := TimeUtils.get_productivity_day_key_now()
	var all_minutes: Array = []
	for day_key in day_keys:
		var include_live: bool = is_session_active() and str(day_key) == today_key
		for minutes in get_session_minutes_list_for_day(str(day_key), include_live):
			all_minutes.append(minutes)
	return all_minutes


func get_overall_session_minutes_list() -> Array:
	var all_minutes: Array = []
	for day_key in _sessions.keys():
		for session in _sessions[day_key]:
			all_minutes.append(int(session.get("minutes", 0)))
	if is_session_active():
		all_minutes.append(get_live_session_minutes())
	return all_minutes


func delete_session(day_key: String, session_index: int) -> bool:
	if not _sessions.has(day_key):
		return false
	var day_sessions: Array = _sessions[day_key]
	if session_index < 0 or session_index >= day_sessions.size():
		return false
	day_sessions.remove_at(session_index)
	if day_sessions.is_empty():
		_sessions.erase(day_key)
		_daily_totals.erase(day_key)
	else:
		_sessions[day_key] = day_sessions
		_recompute_day_totals(day_key)
	_mark_dirty()
	save_data()
	return true


## Insert above a finished session.
## Start min = previous end (or 00:00 for the first row).
## End max = one minute before this row's start (never touches the next entry).
func get_insert_gap_above_session(day_key: String, session_index: int) -> Dictionary:
	if is_session_active():
		return {"ok": false}
	var day_sessions: Array = get_sessions_for_day(day_key)
	if session_index < 0 or session_index >= day_sessions.size():
		return {"ok": false}
	var current_start := _floor_unix_to_minute(
		TimeUtils.unix_from_iso(str(day_sessions[session_index].get("start", "")))
	)
	var gap_end := current_start - 60
	var gap_start: int
	if session_index == 0:
		gap_start = TimeUtils.day_key_to_unix(day_key)
	else:
		gap_start = _ceil_unix_to_minute(
			TimeUtils.unix_from_iso(str(day_sessions[session_index - 1].get("end", "")))
		)
	if gap_end - gap_start < 60:
		return {"ok": false}
	return {
		"ok": true,
		"start_unix": gap_start,
		"end_unix": gap_end,
		"tracks_now": false,
		"lock_start": false,
	}


## Append after the last finished session of the day.
## Start is fixed at that session's end (rounded up to the next free minute);
## end may run up to 23:59 the same day.
func get_insert_gap_after_session(day_key: String, session_index: int) -> Dictionary:
	if is_session_active():
		return {"ok": false}
	var day_sessions: Array = get_sessions_for_day(day_key)
	if session_index < 0 or session_index != day_sessions.size() - 1:
		return {"ok": false}
	var raw_end := TimeUtils.unix_from_iso(str(day_sessions[session_index].get("end", "")))
	# Push ends mid-minute; start after the real end so we never overlap on save.
	var gap_start := _ceil_unix_to_minute(raw_end)
	var gap_end := TimeUtils.clock_on_productivity_day(day_key, 23, 59)
	var next_midnight := TimeUtils.day_key_to_unix(TimeUtils.next_day_key(day_key))
	if gap_start >= next_midnight or gap_start > gap_end:
		return {"ok": false}
	if gap_end - gap_start < 60:
		return {"ok": false}
	return {
		"ok": true,
		"start_unix": gap_start,
		"end_unix": gap_end,
		"tracks_now": false,
		"lock_start": true,
	}


func insert_manual_session(day_key: String, start_unix: int, end_unix: int) -> bool:
	if is_session_active():
		return false
	start_unix = _floor_unix_to_minute(start_unix)
	end_unix = _floor_unix_to_minute(end_unix)
	if end_unix - start_unix < 60:
		return false
	var segments: Array = TimeUtils.split_session_at_day_boundaries(start_unix, end_unix)
	if segments.is_empty():
		return false
	# First segment should belong to the day being edited (insert above / append after).
	if str(segments[0].get("day_key", "")) != day_key:
		return false
	for segment in segments:
		var seg_day := str(segment.get("day_key", ""))
		var seg_start := int(segment.get("start_unix", 0))
		var seg_end := int(segment.get("end_unix", 0))
		for session in get_sessions_for_day(seg_day):
			var existing_start := TimeUtils.unix_from_iso(str(session.get("start", "")))
			var existing_end := TimeUtils.unix_from_iso(str(session.get("end", "")))
			# Treat stored sessions as [start, end); new block must not intersect.
			if seg_start < existing_end and seg_end > existing_start:
				return false
	var touched: Dictionary = {}
	for segment in segments:
		segment["edited"] = true
		_add_session_segment(segment)
		touched[str(segment.get("day_key", ""))] = true
	for touched_key in touched.keys():
		_sort_day_sessions(str(touched_key))
		_recompute_day_totals(str(touched_key))
	_mark_dirty()
	save_data()
	return true


## Bounds for editing a finished session.
## Start min = previous end (or 00:00). End max = next start − 1 min (or 23:59).
## Never overlaps neighbors; a lost edge minute is intentional.
func get_edit_bounds(day_key: String, session_index: int) -> Dictionary:
	if is_session_active():
		return {"ok": false}
	var day_sessions: Array = get_sessions_for_day(day_key)
	if session_index < 0 or session_index >= day_sessions.size():
		return {"ok": false}
	var session: Dictionary = day_sessions[session_index]
	var original_start := _floor_unix_to_minute(
		TimeUtils.unix_from_iso(str(session.get("start", "")))
	)
	var original_end := _floor_unix_to_minute(
		TimeUtils.unix_from_iso(str(session.get("end", "")))
	)
	if original_end <= original_start:
		return {"ok": false}
	var min_start: int
	if session_index == 0:
		min_start = TimeUtils.day_key_to_unix(day_key)
	else:
		min_start = _ceil_unix_to_minute(
			TimeUtils.unix_from_iso(str(day_sessions[session_index - 1].get("end", "")))
		)
	var max_end: int
	if session_index < day_sessions.size() - 1:
		var next_start := _floor_unix_to_minute(
			TimeUtils.unix_from_iso(str(day_sessions[session_index + 1].get("start", "")))
		)
		max_end = next_start - 60
	else:
		max_end = TimeUtils.clock_on_productivity_day(day_key, 23, 59)
	if max_end - min_start < 60:
		return {"ok": false}
	return {
		"ok": true,
		"min_start": min_start,
		"max_end": max_end,
		"original_start": original_start,
		"original_end": original_end,
		"tracks_now": false,
	}


func update_manual_session(
	day_key: String, session_index: int, start_unix: int, end_unix: int
) -> bool:
	if is_session_active():
		return false
	var bounds := get_edit_bounds(day_key, session_index)
	if not bool(bounds.get("ok", false)):
		return false
	var min_start := int(bounds.get("min_start", 0))
	var max_end := int(bounds.get("max_end", 0))
	start_unix = clampi(start_unix, min_start, maxi(max_end - 60, min_start))
	end_unix = clampi(end_unix, mini(start_unix + 60, max_end), max_end)
	if end_unix - start_unix < 60:
		return false
	var segments: Array = TimeUtils.split_session_at_day_boundaries(start_unix, end_unix)
	if segments.is_empty():
		return false
	if not delete_session(day_key, session_index):
		return false
	var touched: Dictionary = {}
	for segment in segments:
		segment["edited"] = true
		_add_session_segment(segment)
		touched[str(segment.get("day_key", ""))] = true
	for touched_key in touched.keys():
		_sort_day_sessions(str(touched_key))
		_recompute_day_totals(str(touched_key))
	_mark_dirty()
	save_data()
	return true


func _floor_unix_to_minute(unix: int) -> int:
	return unix - (unix % 60)


## Next minute boundary at or after unix (unchanged if already on a minute).
func _ceil_unix_to_minute(unix: int) -> int:
	if unix % 60 == 0:
		return unix
	return unix - (unix % 60) + 60


func _sort_day_sessions(day_key: String) -> void:
	if not _sessions.has(day_key):
		return
	var day_sessions: Array = _sessions[day_key]
	day_sessions.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return TimeUtils.unix_from_iso(str(a.get("start", ""))) < TimeUtils.unix_from_iso(str(b.get("start", "")))
	)
	_sessions[day_key] = day_sessions


func _recompute_day_totals(day_key: String) -> void:
	if not _sessions.has(day_key):
		_daily_totals.erase(day_key)
		return
	var cumulative := 0
	var day_sessions: Array = _sessions[day_key]
	for session in day_sessions:
		cumulative += int(session.get("minutes", 0))
		session["cumulative_minutes"] = cumulative
	_daily_totals[day_key] = cumulative
	_sessions[day_key] = day_sessions


func get_all_day_keys_sorted() -> Array:
	var keys: Array = []
	for key in _sessions.keys():
		keys.append(key)
	for key in _daily_totals.keys():
		if not keys.has(key):
			keys.append(key)
	keys.sort()
	return keys


func get_window_settings() -> Dictionary:
	return {
		"x": int(_settings_get("window_x", 100)),
		"y": int(_settings_get("window_y", 100)),
		"width": int(_settings_get("window_width", DEFAULT_WINDOW_WIDTH)),
		"height": int(_settings_get("window_height", DEFAULT_WINDOW_HEIGHT)),
	}


func set_window_settings(x: int, y: int, width: int, height: int) -> void:
	_settings_set("window_x", x)
	_settings_set("window_y", y)
	_settings_set("window_width", width)
	_settings_set("window_height", height)
	_mark_dirty()


func load_data() -> void:
	_daily_totals = {}
	_sessions = {}
	if not FileAccess.file_exists(_data_file_path()):
		return
	var file := FileAccess.open(_data_file_path(), FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	_apply_loaded_data(parsed)
	_migrate_datetime_year_bug()
	_migrate_to_midnight_day_boundary()


func save_data() -> void:
	if not _dirty:
		return
	_ensure_data_dir()
	var payload := _build_save_payload()
	var file := FileAccess.open(_data_file_path(), FileAccess.WRITE)
	if file == null:
		push_error("Failed to write productivity data.")
		return
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	_dirty = false


func _apply_loaded_data(data: Dictionary) -> void:
	_daily_totals = data.get("daily_totals", {})
	_sessions = data.get("sessions", {})
	var settings: Dictionary = data.get("settings", {})
	low_goal_hours = float(settings.get("low_goal_hours", 2.0))
	medium_goal_hours = float(settings.get("medium_goal_hours", 4.0))
	high_goal_hours = float(settings.get("high_goal_hours", 7.0))
	low_goal_color = _color_from_string(
		str(settings.get("low_goal_color", "")), low_goal_color
	)
	medium_goal_color = _color_from_string(
		str(settings.get("medium_goal_color", "")), medium_goal_color
	)
	high_goal_color = _color_from_string(
		str(settings.get("high_goal_color", "")), high_goal_color
	)
	_store_settings_cache(settings)
	_last_productivity_day_key = str(_settings_get("last_productivity_day_key", ""))


func _build_save_payload() -> Dictionary:
	return {
		"version": VERSION,
		"daily_totals": _daily_totals.duplicate(),
		"settings": _build_settings_dict(),
		"sessions": _sessions.duplicate(true),
	}


func _build_settings_dict() -> Dictionary:
	var settings := _settings_cache.duplicate()
	settings["low_goal_hours"] = low_goal_hours
	settings["medium_goal_hours"] = medium_goal_hours
	settings["high_goal_hours"] = high_goal_hours
	settings["low_goal_color"] = low_goal_color.to_html(true)
	settings["medium_goal_color"] = medium_goal_color.to_html(true)
	settings["high_goal_color"] = high_goal_color.to_html(true)
	return settings


var _settings_cache: Dictionary = {}


func _settings_get(key: String, default: Variant) -> Variant:
	if _settings_cache.has(key):
		return _settings_cache[key]
	return default


func _settings_set(key: String, value: Variant) -> void:
	_settings_cache[key] = value


func _store_settings_cache(settings: Dictionary) -> void:
	_settings_cache = settings.duplicate()
	for key in ["window_x", "window_y", "window_width", "window_height"]:
		if settings.has(key):
			_settings_cache[key] = settings[key]


func _mark_dirty() -> void:
	_dirty = true


func _migrate_datetime_year_bug() -> void:
	if bool(_settings_get("datetime_year_bug_fixed", false)):
		return
	var migrated_sessions: Dictionary = {}
	for day_key in _sessions.keys():
		var corrected_key := TimeUtils.correct_day_key_year_offset(str(day_key))
		if not migrated_sessions.has(corrected_key):
			migrated_sessions[corrected_key] = []
		for session in _sessions[day_key]:
			var fixed_session: Dictionary = (session as Dictionary).duplicate()
			fixed_session["start"] = TimeUtils.correct_iso_year_offset(str(session.get("start", "")))
			fixed_session["end"] = TimeUtils.correct_iso_year_offset(str(session.get("end", "")))
			migrated_sessions[corrected_key].append(fixed_session)
	_sessions = migrated_sessions
	_daily_totals.clear()
	for day_key in _sessions.keys():
		var day_sessions: Array = _sessions[day_key]
		day_sessions.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return TimeUtils.unix_from_iso(str(a.get("start", ""))) < TimeUtils.unix_from_iso(
				str(b.get("start", ""))
			)
		)
		_sessions[day_key] = day_sessions
		_recompute_day_totals(str(day_key))
	if not _last_productivity_day_key.is_empty():
		_last_productivity_day_key = TimeUtils.correct_day_key_year_offset(_last_productivity_day_key)
	_last_productivity_day_key = TimeUtils.get_productivity_day_key_now()
	_settings_set("last_productivity_day_key", _last_productivity_day_key)
	_settings_set("datetime_year_bug_fixed", true)
	_mark_dirty()
	save_data()


func _migrate_to_midnight_day_boundary() -> void:
	if bool(_settings_get("midnight_day_boundary_migrated", false)):
		return
	_archive_named_backup("pre_midnight_boundary")
	var raw_sessions: Array = []
	for day_key in _sessions.keys():
		for session in _sessions[day_key]:
			var start_unix := TimeUtils.unix_from_iso(str(session.get("start", "")))
			var end_unix := TimeUtils.unix_from_iso(str(session.get("end", "")))
			if end_unix <= start_unix:
				continue
			raw_sessions.append({
				"start_unix": start_unix,
				"end_unix": end_unix,
				"edited": bool(session.get("edited", false)),
			})
	_sessions.clear()
	_daily_totals.clear()
	for item in raw_sessions:
		var segments: Array = TimeUtils.split_session_at_day_boundaries(
			int(item["start_unix"]), int(item["end_unix"])
		)
		for segment in segments:
			if bool(item["edited"]):
				segment["edited"] = true
			_add_session_segment(segment)
	for day_key in _sessions.keys():
		_sort_day_sessions(str(day_key))
		_recompute_day_totals(str(day_key))
	_last_productivity_day_key = TimeUtils.get_productivity_day_key_now()
	_settings_set("last_productivity_day_key", _last_productivity_day_key)
	# Live Push: commit anything before the new midnight boundary, then continue.
	if is_session_active():
		_commit_active_session_before_day(_last_productivity_day_key)
	_settings_set("midnight_day_boundary_migrated", true)
	_mark_dirty()
	save_data()


func _add_session_segment(segment: Dictionary) -> void:
	var day_key: String = segment.get("day_key", "")
	if day_key.is_empty():
		return
	var segment_minutes: int = int(segment.get("minutes", 0))
	var start_unix: int = int(segment.get("start_unix", 0))
	var end_unix: int = int(segment.get("end_unix", 0))
	if not _sessions.has(day_key):
		_sessions[day_key] = []
	var day_sessions: Array = _sessions[day_key]
	var cumulative := get_day_total_minutes(day_key)
	cumulative += segment_minutes
	day_sessions.append({
		"start": TimeUtils.iso_from_unix(start_unix),
		"end": TimeUtils.iso_from_unix(end_unix),
		"minutes": segment_minutes,
		"cumulative_minutes": cumulative,
	})
	if bool(segment.get("edited", false)):
		day_sessions[day_sessions.size() - 1]["edited"] = true
	_daily_totals[day_key] = cumulative
	_sessions[day_key] = day_sessions


func _color_from_string(value: String, fallback: Color) -> Color:
	if value.is_empty():
		return fallback
	var parsed := Color.from_string(value, fallback)
	return parsed


func update_goal_color(which: String, color: Color) -> void:
	match which:
		"low":
			low_goal_color = color
		"medium":
			medium_goal_color = color
		"high":
			high_goal_color = color
	_mark_dirty()
	save_data()
