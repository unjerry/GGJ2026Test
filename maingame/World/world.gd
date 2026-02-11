# 文件名: world.gd (世界场景主脚本)
# 说明：管理世界场景、相机控制和玩家移动权限
class_name World
extends Node2D

# 节点引用
@onready var camera_2d: Camera2D = $Player/Camera2D
@onready var player: CharacterBody2D = $Player
@onready var death_boundary: Area2D = $DeathBoundary  # 添加死亡边界引用
@onready var full_line: Node2D = $FullLine
@onready var dotted_line: Node2D = $DottedLine

func _ready() -> void:
	# 连接死亡边界的信号
	if death_boundary and death_boundary.body_entered.is_connected(_on_death_boundary_body_entered):
		death_boundary.body_entered.disconnect(_on_death_boundary_body_entered)
	death_boundary.body_entered.connect(_on_death_boundary_body_entered)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		Game.back_to_title()
	if event.is_action_pressed("save"):
		Game.save_game()
	if event.is_action_pressed("load"):
		Game.load_game()


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	if not is_instance_valid(camera_2d):
		return


func update_player(pos: Vector2) -> void:
	player.global_position = pos
	camera_2d.reset_smoothing()
	camera_2d.force_update_scroll()


# 死亡边界检测函数
func _on_death_boundary_body_entered(body: Node) -> void:
	# 确保只有玩家会触发
	if body == player:
		player.die()
	else:
		body.queue_free()


func to_dict() -> Dictionary:
	var enemies_alive := []
	var enemies_data := []
	for node in get_tree().get_nodes_in_group("enemies"):
		var path := get_path_to(node) as String
		enemies_alive.append(path)
		
		# 记录敌人状态（目前只需要solid，可扩展其他属性）
		enemies_data.append({
			"path": path,
			"solid": node.solid if "solid" in node else true
		})
	
	return {
		"enemies_alive": enemies_alive,   # 用于删除已死亡敌人（兼容旧存档）
		"enemies_data": enemies_data      # 用于恢复状态
	}


func from_dict(dict: Dictionary) -> void:
	# ---------- 1. 删除不再存活的敌人（兼容旧存档） ----------
	if dict.has("enemies_alive"):
		var alive_paths = dict.enemies_alive
		for node in get_tree().get_nodes_in_group("enemies"):
			var path := get_path_to(node) as String
			if path not in alive_paths:
				node.queue_free()
	
	# ---------- 2. 恢复敌人的详细状态（新存档） ----------
	if dict.has("enemies_data"):
		# 建立路径 → 节点映射，提高查找效率
		var node_map = {}
		for node in get_tree().get_nodes_in_group("enemies"):
			node_map[get_path_to(node) as String] = node
		
		# 遍历存档数据，恢复属性
		for entry in dict.enemies_data:
			var path = entry.get("path", "")
			if path in node_map:
				var enemy = node_map[path]
				
				# 恢复 solid 属性
				if entry.has("solid"):
					enemy.solid = entry.solid
					
					# 刷新视觉表现（纹理、碰撞掩码等）
					if enemy.has_method("_update_form_visual"):
						enemy._update_form_visual()
					
					# 同步更新 Stats 节点（如果存在）
					if enemy.has_node("Stats"):
						enemy.stats.solid = entry.solid
						enemy.stats.current_solid = entry.solid
