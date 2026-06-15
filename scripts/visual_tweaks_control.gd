extends Node
class_name VisualTweaksControl

signal tweaks_changed

@export_group("Scroll Layout")
@export var scroll_top_spacing: float = 16.0

static var instance: VisualTweaksControl


func _ready() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		tweaks_changed.emit()


static func get_instance() -> VisualTweaksControl:
	return instance


func scroll_top_spacing_px() -> float:
	return UiScale.scale(scroll_top_spacing)
