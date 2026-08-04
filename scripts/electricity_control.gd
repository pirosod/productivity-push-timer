extends Node
class_name ElectricityControl

## Inspector knobs for yellow-band lightning (Today / week chart / week-by-week).

static var instance: ElectricityControl

signal settings_changed

@export_group("Master")
@export var enabled: bool = true:
	set(value):
		enabled = value
		settings_changed.emit()

@export_group("Look")
@export var core_color: Color = Color(1.0, 1.0, 0.92, 0.95):
	set(value):
		core_color = value
		settings_changed.emit()
@export var glow_color: Color = Color(1.0, 0.82, 0.2, 0.75):
	set(value):
		glow_color = value
		settings_changed.emit()
@export_range(0.0, 3.0, 0.05) var intensity: float = 1.0:
	set(value):
		intensity = value
		settings_changed.emit()
@export_range(0.0, 3.0, 0.05) var bloom: float = 1.0:
	set(value):
		bloom = value
		settings_changed.emit()

@export_group("Strands")
@export_range(1, 8, 1) var strand_count: int = 3:
	set(value):
		strand_count = value
		settings_changed.emit()
@export_range(0.2, 4.0, 0.05) var min_speed: float = 0.55:
	set(value):
		min_speed = value
		settings_changed.emit()
@export_range(0.2, 6.0, 0.05) var max_speed: float = 2.4:
	set(value):
		max_speed = value
		settings_changed.emit()
@export_range(0.05, 3.0, 0.05) var ease_in_seconds: float = 0.9:
	set(value):
		ease_in_seconds = value
		settings_changed.emit()
@export_range(0.5, 8.0, 0.1) var jag_amplitude: float = 3.5:
	set(value):
		jag_amplitude = value
		settings_changed.emit()


func _ready() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		settings_changed.emit()


static func get_instance() -> ElectricityControl:
	return instance


func is_on() -> bool:
	return enabled and intensity > 0.01
