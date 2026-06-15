extends Node
class_name MarkerControl

static var instance: MarkerControl

signal sizes_changed

@export_group("Average Markers")
@export var marker_line_thickness: float = 2.0
@export var label_font_size: int = 12
@export var minutes_font_size: int = 14


func _ready() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		sizes_changed.emit()


static func get_instance() -> MarkerControl:
	return instance


func line_thickness() -> float:
	return UiScale.scale(marker_line_thickness)


func label_size() -> int:
	return UiScale.scale_i(label_font_size)


func minutes_size() -> int:
	return UiScale.scale_i(minutes_font_size)
