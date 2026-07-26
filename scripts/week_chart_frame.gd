extends PanelContainer


func _ready() -> void:
	_apply_border_style()
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func refresh_appearance() -> void:
	_apply_border_style()


func _apply_border_style() -> void:
	TodayChartStyle.apply_panel_box(self)
