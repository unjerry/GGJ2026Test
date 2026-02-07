# 文件名: state_machine.gd (状态机脚本)
# 说明：通用状态机实现，管理状态转换和更新

class_name StateMachine # 定义类名
extends Node

# 宿主节点（通常是父节点，如 Player/Enemy）
var actor: Node

# 当前状态（使用属性观察者模式，状态变化时触发宿主的方法）
var current_state: int = -1:
	set(v):
		# 状态变化时通知宿主进行状态转换处理
		if actor != null and current_state != v:
			actor.transition_state(current_state, v)
			state_time = 0.0
		current_state = v # 更新当前状态
		
var state_time: float = 0.0


func _ready() -> void:
	actor = get_parent()
	if actor == null:
		push_error("StateMachine requires a parent actor node.")
		set_physics_process(false)
		return

	var required_methods := ["transition_state", "get_next_state", "tick_physics"]
	for method_name in required_methods:
		if not actor.has_method(method_name):
			push_error("StateMachine parent is missing method: %s" % method_name)
			set_physics_process(false)
			return

	# 等待宿主节点完全就绪
	await actor.ready
	# 初始化当前状态为0（默认状态）
	current_state = 0

func _physics_process(delta: float) -> void:
	# 状态转换循环：持续检查直到状态稳定
	while true:
		#print(current_state)
		# 从宿主获取下一个状态
		var next := actor.get_next_state(current_state) as int
		
		# 如果状态不再变化，退出循环
		if current_state == next:
			break
			
		# 更新当前状态（会触发transition_state）
		current_state = next
	
	# 执行当前状态的物理更新
	actor.tick_physics(current_state, delta)
	state_time += delta
