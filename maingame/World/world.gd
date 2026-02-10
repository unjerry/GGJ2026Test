# 文件名: world.gd (世界场景主脚本)
# 说明：管理世界场景、相机控制和玩家移动权限

extends Node2D

# 节点引用
@onready var camera_2d: Camera2D = $Player/Camera2D
@onready var player: CharacterBody2D = $Player
@onready var death_boundary: Area2D = $DeathBoundary  # 添加死亡边界引用

func _ready() -> void:
	# 重置相机平滑效果，确保相机立即定位到正确位置
	
	# 连接死亡边界的信号
	if death_boundary and death_boundary.body_entered.is_connected(_on_death_boundary_body_entered):
		death_boundary.body_entered.disconnect(_on_death_boundary_body_entered)
	death_boundary.body_entered.connect(_on_death_boundary_body_entered)

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	if not is_instance_valid(camera_2d):
		return

# 死亡边界检测函数
func _on_death_boundary_body_entered(body: Node) -> void:
	# 确保只有玩家会触发
	if body == player:
		player.die()
