extends Node

const DATA_FOLDER_NAME := "Productivity data"
const DATA_FILE_NAME := "productivity.json"
const VERSION := 1

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
	_archive_current_data()
	_set_last_productivity_day_key(today_key)


func _set_last_productivity_day_key(day_key: String) -> void:
	_last_productivity_day_key = day_key
	_settings_set("last_productivity_day_key", day_key)
	_mark_dirty()
	save_data()


func _archive_current_data() -> void:
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
	var archive_path := _archive_dir_path() + "productivity_%s.json" % stamp
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
	var segments := TimeUtils.split_session_at_day_boundaries(_session_start_unix, end_unix)
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
		var segments := TimeUtils.split_session_at_day_boundaries(_session_start_unix, now)
		for segment in segments:
			if segment.get("day_key", "") == day_key:
				total += int(segment.get("minutes", 0))
	return total


func get_day_total_minutes(day_key: String) -> int:
	return int(_daily_totals.get(day_key, 0))


func get_sessions_for_day(day_key: String) -> Array:
	var stored: Array = _sessions.get(day_key, [])
	return stored.duplicate(true)


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
		"width": int(_settings_get("window_width", UiScale.scale_i(380))),
		"height": int(_settings_get("window_height", UiScale.scale_i(420))),
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
