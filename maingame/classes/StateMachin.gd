# 文件名: state_machine.gd (状态机脚本)
# 说明：通用状态机实现，管理状态转换和更新

class_name StateMachine  # 定义类名
extends Node

# 当前状态（使用属性观察者模式，状态变化时触发owner的方法）
var current_state: int = -1:
	set(v):
		# 状态变化时通知所有者进行状态转换处理
		owner.transition_state(current_state, v)
		current_state = v  # 更新当前状态

func _ready() -> void:
	# 等待所有者节点完全就绪
	await owner.ready
	# 初始化当前状态为0（默认状态）
	current_state = 0

func _physics_process(delta: float) -> void:
	# 状态转换循环：持续检查直到状态稳定
	while true:
		# 从所有者获取下一个状态
		var next := owner.get_next_state(current_state) as int
		
		# 如果状态不再变化，退出循环
		if current_state == next:
			break
			
		# 更新当前状态（会触发transition_state）
		current_state = next
	
	# 执行当前状态的物理更新
	owner.tick_physics(current_state, delta)
