extends Node

var world_states := {}

const SAVE_PATH := "user://data.sav"

@onready var player_stats: Stats = $PlayerStats

signal camera_should_shake(amount: float)

func change_scene(path: String, params := {}) -> void:
	var tree := get_tree()
	tree.paused = true
	
	for trail in get_tree().get_nodes_in_group("sprite_trails"):
		if trail.has_method("cleanup_all_trails"):
			trail.cleanup_all_trails()
	
	if tree.current_scene is World:
		var old_name := tree.current_scene.scene_file_path.get_file().get_basename()
		world_states[old_name] = tree.current_scene.to_dict()
	
	tree.change_scene_to_file(path)
	if "init" in params:
		params.init.call()
	
	await tree.tree_changed
	
	if tree.current_scene is World:
		var new_name := tree.current_scene.scene_file_path.get_file().get_basename()
		if new_name in world_states:
			tree.current_scene.from_dict(world_states[new_name])
			
		if "position" in params:
			tree.current_scene.update_player(params.position)
	
	tree.paused = false


func new_game() -> void:
	change_scene("res://World/world.tscn",{
		init = func ():
			world_states = {}
	})


func shake_camera(amount: float) -> void:
	camera_should_shake.emit(amount)


func save_game() -> void:
	if not player_stats.current_solid:
		print("cannot")
		return
	var scene := get_tree().current_scene
	var scene_name := scene.scene_file_path.get_file().get_basename()
	world_states[scene_name] = scene.to_dict()
	
	var data := {
		world_states = world_states,
		scene = scene.scene_file_path,
		player = {
			position = {
				x = scene.player.global_position.x,
				y = scene.player.global_position.y,
			},
		},
	}
	var json := JSON.stringify(data)
	var file:= FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		return
	file.store_string(json)


func load_game() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	
	var json := file.get_as_text()
	var data := JSON.parse_string(json) as Dictionary
	change_scene(data.scene,{
		position = Vector2(
			data.player.position.x,
			data.player.position.y
		),
		init = func ():
			world_states = data.world_states
	})


func back_to_title() -> void:
	change_scene("res://ui/title_screen.tscn")


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)
