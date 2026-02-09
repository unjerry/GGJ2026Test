extends Node

signal camera_should_shake(amount: float)

func change_scene(path: String) -> void:
	var tree := get_tree()
	
	tree.change_scene_to_file(path)
	await tree.process_frame


func new_game() -> void:
	change_scene("res://World/world.tscn")


func shake_camera(amount: float) -> void:
	camera_should_shake.emit(amount)
