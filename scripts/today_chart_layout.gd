extends RefCounted
class_name TodayChartLayout


static func build(
	day_key: String,
	include_live: bool,
	chart_size: Vector2,
	row_centers_y: Array = []
) -> Dictionary:
	var row_height := TodayChartStyle.row_height()
	var axis_width := TodayChartStyle.axis_width()
	# Match Today table display order: live (if any), then newest → oldest.
	var lists := _display_ordered_lists(day_key, include_live)
	var logged_list: Array = lists["logged"]
	var color_minutes_list: Array = lists["color"]
	var max_minutes := TodayChartStyle.scale_max_minutes(logged_list)
	var plot_rect := TodayChartStyle.plot_rect_for_today_table(chart_size)
	var row_centers: Array = []
	var points: Array = []
	var colors: Array = []
	for i in logged_list.size():
		var logged_minutes := float(logged_list[i])
		var color_minutes := float(color_minutes_list[i]) if i < color_minutes_list.size() else logged_minutes
		var center_y := _row_center_y(i, row_height, row_centers_y)
		row_centers.append(center_y)
		var x := TodayChartStyle.minutes_to_x(logged_minutes, plot_rect, max_minutes)
		points.append(Vector2(x, center_y))
		colors.append(TodayChartStyle.vertex_color_for_minutes(color_minutes))
	return {
		"logged_list": logged_list,
		"color_minutes_list": color_minutes_list,
		"max_minutes": max_minutes,
		"plot_rect": plot_rect,
		"row_centers_y": row_centers,
		"points": points,
		"colors": colors,
		"row_height": row_height,
		"axis_width": axis_width,
	}


static func _display_ordered_lists(day_key: String, include_live: bool) -> Dictionary:
	var logged: Array = []
	var color: Array = []
	var sessions: Array = ProductivityData.get_sessions_for_day(day_key)
	var live_logged := 0
	var live_cumulative := 0
	var has_live := false
	if include_live and ProductivityData.is_session_active():
		var start_unix := ProductivityData.get_session_start_unix()
		live_cumulative = ProductivityData.get_live_minutes_for_day(day_key)
		if live_cumulative > 0 or TimeUtils.get_productivity_day_key(start_unix) == day_key:
			live_logged = live_cumulative - ProductivityData.get_day_total_minutes(day_key)
			has_live = true
	if has_live:
		logged.append(maxi(live_logged, 0))
		color.append(live_cumulative)
	for display_i in sessions.size():
		var i := sessions.size() - 1 - display_i
		var session: Dictionary = sessions[i]
		logged.append(int(session.get("minutes", 0)))
		color.append(int(session.get("cumulative_minutes", 0)))
	return {"logged": logged, "color": color}


static func _row_center_y(index: int, row_height: int, row_centers_y: Array) -> float:
	if index < row_centers_y.size():
		return float(row_centers_y[index])
	return float(index) * float(row_height) + float(row_height) * 0.5
