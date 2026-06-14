extends Node
class_name TextControl

signal sizes_changed

@export_group("Timer & Header")
@export var timer_size: int = 22
@export var push_button_size: int = 16
@export var snooze_button_size: int = 16

@export_group("Today")
@export var today_header_size: int = 16
@export var session_table_size: int = 16

@export_group("History")
@export var history_tab_size: int = 16
@export var history_day_header_size: int = 16

@export_group("Week Chart")
@export var week_chart_day_label_size: int = 11

@export_group("Selected Day")
@export var selected_day_label_size: int = 16

@export_group("Goals")
@export var goal_label_size: int = 16

@export_group("Popup")
@export var popup_message_size: int = 16
@export var popup_button_size: int = 16

static var instance: TextControl


func _ready() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		sizes_changed.emit()


static func get_instance() -> TextControl:
	return instance


func apply_text_sizes() -> void:
	sizes_changed.emit()


func sized(base: int) -> int:
	return UiScale.scale_i(base)


func timer_font_size() -> int:
	return sized(timer_size)


func push_button_font_size() -> int:
	return sized(push_button_size)


func snooze_button_font_size() -> int:
	return sized(snooze_button_size)


func today_header_font_size() -> int:
	return sized(today_header_size)


func session_table_font_size() -> int:
	return sized(session_table_size)


func history_tab_font_size() -> int:
	return sized(history_tab_size)


func history_day_header_font_size() -> int:
	return sized(history_day_header_size)


func week_chart_day_label_font_size() -> int:
	return sized(week_chart_day_label_size)


func selected_day_label_font_size() -> int:
	return sized(selected_day_label_size)


func goal_label_font_size() -> int:
	return sized(goal_label_size)


func popup_message_font_size() -> int:
	return sized(popup_message_size)


func popup_button_font_size() -> int:
	return sized(popup_button_size)
