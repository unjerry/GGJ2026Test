# 文件名: world.gd (世界场景主脚本)
# 说明：管理世界场景、相机控制和玩家移动权限

extends Node2D



# 节点引用
@onready var right_wall: StaticBody2D = $RightWall
@onready var left_wall: StaticBody2D = $LeftWall
@onready var tutorial_popup: Tut = $UI/TutorialPopup
@onready var camera_2d: Camera2D = $Player/Camera2D
@onready var player: CharacterBody2D = $Player

func _ready() -> void:
	# 重置相机平滑效果，确保相机立即定位到正确位置
	camera_2d.reset_smoothing()
	tutorial_popup.start_tutorial()
	

# 控制玩家是否可移动的标志变量
var can_move := true


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	if not is_instance_valid(camera_2d):
		return

	# 当玩家位置超过250时，调整相机范围和墙壁位置
	if player.global_position.x > 1000:
		# 设置相机左右边界
		camera_2d.limit_right = 1960  # 相机右边界
		camera_2d.limit_left = 40   # 相机左边界
		
		# 交换墙壁位置（实现场景切换效果）
		left_wall.global_position.x = 1960   # 左侧墙壁移到右边
		right_wall.global_position.x = 40  # 右侧墙壁移到左边
		
	# 如果玩家不能移动，将相机固定在指定位置
	if not can_move:
		camera_2d.global_position.x = 193  # 固定相机X坐标为193
