class_name Tut
extends StateMa

@export var auto_start := false


func _ready() -> void:
	super._ready()
	if auto_start:
		start()


func trigger(event_name: StringName) -> void:
	emit_event(event_name)


func register_check_signal(emitter: Object, signal_name: StringName, event_name: StringName) -> void:
	bind_signal_event(emitter, signal_name, event_name)
