extends HBoxContainer
class_name TodayMarkerLegend

var _day_key: String = ""
var _include_live: bool = false


func _ready() -> void:
	add_theme_constant_override("separation", UiScale.scale_i(20))
	alignment = BoxContainer.ALIGNMENT_CENTER


func configure(day_key: String, include_live: bool) -> void:
	_day_key = day_key
	_include_live = include_live
	_rebuild()


func refresh() -> void:
	_rebuild()


func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	if _day_key.is_empty():
		return
	for marker in _marker_entries():
		var avg_minutes := float(marker["minutes"])
		if avg_minutes <= 0.0:
			continue
		add_child(_build_marker_item(str(marker["label"]), avg_minutes, marker["color"]))


func _marker_entries() -> Array:
	return [
		{
			"label": "Today",
			"minutes": ProductivityData.get_today_average_session_minutes(_day_key, _include_live),
			"color": TodayChartStyle.marker_color(0),
		},
		{
			"label": "Week",
			"minutes": ProductivityData.get_average_session_minutes_from_list(
				ProductivityData.get_week_session_minutes_list()
			),
			"color": TodayChartStyle.marker_color(1),
		},
		{
			"label": "Total",
			"minutes": ProductivityData.get_average_session_minutes_from_list(
				ProductivityData.get_overall_session_minutes_list()
			),
			"color": TodayChartStyle.marker_color(2),
		},
	]


func _build_marker_item(label_text: String, avg_minutes: float, swatch_color: Color) -> HBoxContainer:
	var item := HBoxContainer.new()
	item.add_theme_constant_override("separation", UiScale.scale_i(6))
	item.alignment = BoxContainer.ALIGNMENT_CENTER
	var picker := ColorPickerButton.new()
	picker.color = swatch_color
	picker.custom_minimum_size = Vector2(UiScale.scale_i(28), UiScale.scale_i(20))
	picker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picker.focus_mode = Control.FOCUS_NONE
	item.add_child(picker)
	var label := Label.new()
	label.text = "%s %s" % [label_text, TimeUtils.format_minutes_hm(int(round(avg_minutes)))]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(label)
	item.add_child(label)
	return item


func _style_label(label: Label) -> void:
	var marker_control := MarkerControl.get_instance()
	var label_size: int = marker_control.label_size() if marker_control else UiScale.scale_i(12)
	label.add_theme_font_size_override("font_size", label_size)
	label.add_theme_color_override("font_color", UiScale.text_color())
