class_name Stats
extends Node

@export var solid := true

@onready var current_solid:= solid


func to_dict() -> Dictionary:
	return {
		solid = solid,
		current_solid = current_solid,
	}


func from_dict(dict: Dictionary) -> void:
	solid = dict.solid
	current_solid = dict.current_solid
