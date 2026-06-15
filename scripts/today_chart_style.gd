extends RefCounted
class_name TodayChartStyle

const VHIGH_COLOR := Color(0.85, 0.28, 0.28, 0.32)
const EXTREME_COLOR := Color(0.58, 0.28, 0.82, 0.32)
const VHIGH_HOURS := 11.0
const EXTREME_HOURS := 16.0
const GRADIENT_MAX_MINUTES := 960


static func goal_bands() -> Array:
	return [
		{
			"start_h": 0.0,
			"end_h": ProductivityData.low_goal_hours,
			"color": ProductivityData.low_goal_color,
		},
		{
			"start_h": ProductivityData.low_goal_hours,
			"end_h": ProductivityData.medium_goal_hours,
			"color": ProductivityData.medium_goal_color,
		},
		{
			"start_h": ProductivityData.medium_goal_hours,
			"end_h": ProductivityData.high_goal_hours,
			"color": ProductivityData.high_goal_color,
		},
		{
			"start_h": ProductivityData.high_goal_hours,
			"end_h": VHIGH_HOURS,
			"color": VHIGH_COLOR,
		},
		{
			"start_h": VHIGH_HOURS,
			"end_h": EXTREME_HOURS,
			"color": EXTREME_COLOR,
		},
	]


static func row_height() -> int:
	return UiScale.scale_i(28)


static func axis_width() -> int:
	return UiScale.scale_i(56)


static func plot_right_gutter() -> int:
	return axis_width()


static func plot_nudge_x() -> float:
	return UiScale.scale(14.0)


static func plot_rect_for_size(chart_size: Vector2) -> Rect2:
	var axis := float(axis_width())
	var right := float(plot_right_gutter())
	var nudge := plot_nudge_x()
	return Rect2(
		axis + nudge,
		0.0,
		maxf(chart_size.x - axis - right - nudge, 1.0),
		chart_size.y
	)


static func marker_color(index: int) -> Color:
	match index:
		0:
			return Color(0.35, 0.85, 0.4, 0.95)
		1:
			return Color(1.0, 0.82, 0.2, 0.95)
		_:
			return Color(0.65, 0.35, 0.9, 0.95)


static func is_dark_mode() -> bool:
	return ProductivityData.is_session_active()


static func band_color(color: Color) -> Color:
	var faded := color
	faded.a = clampf(color.a * 0.45, 0.0, 1.0)
	return faded


static func panel_grey() -> Color:
	return Color(0.12, 0.12, 0.12, 0.28) if is_dark_mode() else Color(0.88, 0.88, 0.88, 0.4)


static func zebra_color(row_index: int) -> Color:
	if row_index % 2 == 0:
		return Color(0, 0, 0, 0.0)
	var alpha := 0.14 if is_dark_mode() else 0.1
	return Color(0.5, 0.5, 0.5, alpha)


static func grid_color() -> Color:
	return Color(1, 1, 1, 0.16) if is_dark_mode() else Color(0, 0, 0, 0.14)


static func connector_color() -> Color:
	return Color(1, 1, 1, 0.28) if is_dark_mode() else Color(0, 0, 0, 0.22)


static func area_fill_color() -> Color:
	return Color(1, 1, 1, 0.04) if is_dark_mode() else Color(0, 0, 0, 0.035)


static func axis_text_color() -> Color:
	return UiScale.text_color()


static func vertex_color_for_minutes(minutes: float) -> Color:
	var hours := minutes / 60.0
	if hours <= ProductivityData.low_goal_hours:
		return Color(0.35, 0.65, 1.0, 1.0)
	if hours <= ProductivityData.medium_goal_hours:
		return Color(0.35, 0.85, 0.4, 1.0)
	if hours <= ProductivityData.high_goal_hours:
		return Color(1.0, 0.82, 0.2, 1.0)
	if hours <= VHIGH_HOURS:
		return Color(0.95, 0.3, 0.3, 1.0)
	return Color(0.65, 0.35, 0.9, 1.0)


static func vertex_color_for_chart_x(x: float, plot_rect: Rect2, max_minutes: int) -> Color:
	var ratio := clampf((x - plot_rect.position.x) / maxf(plot_rect.size.x, 1.0), 0.0, 1.0)
	var minutes := ratio * float(maxi(max_minutes, 1))
	return vertex_color_for_minutes(minutes)


static func minutes_to_x(minutes: float, plot_rect: Rect2, max_minutes: int) -> float:
	var ratio := clampf(minutes / float(maxi(max_minutes, 1)), 0.0, 1.0)
	return plot_rect.position.x + plot_rect.size.x * ratio


static func scale_max_minutes(session_minutes: Array) -> int:
	var peak := 60
	for value in session_minutes:
		peak = maxi(peak, int(ceil(float(value))))
	return peak + 60


static func minutes_to_y(minutes: float, plot_rect: Rect2, max_minutes: int) -> float:
	var ratio := clampf(minutes / float(maxi(max_minutes, 1)), 0.0, 1.0)
	return plot_rect.position.y + plot_rect.size.y * (1.0 - ratio)


static func hour_labels(max_minutes: int) -> Array:
	var labels: Array = []
	var max_hour := int(ceil(float(max_minutes) / 60.0))
	for hour in max_hour + 1:
		labels.append("%dH" % hour)
	return labels
