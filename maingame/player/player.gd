# 文件名: player.gd (玩家角色脚本)
# 说明：玩家角色控制，包含移动、跳跃、状态管理等功能

extends CharacterBody2D

# 状态枚举定义
enum State {
	IDLE, # 闲置状态
	RUNNING, # 奔跑状态
	JUMP, # 跳跃状态
	DASH, # 冲刺状态
}

# 地面状态数组（用于判断是否在地面状态）
const GROUND_STATES := [State.IDLE, State.RUNNING]

# 角色属性常量
const RUN_SPEED := 200.0 # 奔跑速度
const JUMP_VELOCITY := -300.0 # 跳跃初速度（负值表示向上）
const FLOOR_ACCELERATION := RUN_SPEED / 0.1 # 地面加速度
const AIR_ACCELERATION := RUN_SPEED / 0.05 # 空中加速度
const DASH_VELOCITY := 200 # 冲刺速度

# 角色变量
var gravity := ProjectSettings.get("physics/2d/default_gravity") as float # 从项目设置获取重力值
var solid := true # 空心与实心状态的标记
var is_first_tick := false

# 节点引用
@onready var jump_request_timer: Timer = $JumpRequestTimer # 跳跃输入缓冲计时器


func _unhandled_input(event: InputEvent) -> void:
	# 只有在solid为true时才处理输入
	if solid:
		# 按下跳跃键时启动跳跃缓冲计时器
		if event.is_action_pressed("jump"):
			jump_request_timer.start()
			
		# 松开跳跃键时，如果上升速度小于一半跳跃速度，则减少垂直速度
		if event.is_action_released("jump") and velocity.y < JUMP_VELOCITY / 2:
			velocity.y = JUMP_VELOCITY / 2 # 实现跳跃高度控制


func tick_physics(state: State, delta: float) -> void:
	# 根据当前状态执行相应的物理更新
	match state:
		State.IDLE:
			move(delta) # 闲置状态下的移动
			
		State.RUNNING:
			move(delta) # 奔跑状态下的移动
			
		State.JUMP:
			move(delta) # 跳跃状态下的移动
			
		State.DASH:
			move(delta) # 冲刺状态下的移动


func move(delta: float) -> void:
	# 获取水平输入方向（-1:左, 0:无输入, 1:右）
	var direction := Input.get_axis("move_left", "move_right")
	
	# 根据是否在地面选择加速度
	var acceleration := FLOOR_ACCELERATION if is_on_floor() else AIR_ACCELERATION
	
	# 水平速度插值（平滑加速/减速）
	velocity.x = move_toward(velocity.x, direction * RUN_SPEED, acceleration * delta)
	
	# 应用重力（垂直加速度）
	velocity.y += gravity * delta
	
	# 执行移动和碰撞检测
	move_and_slide()


func get_next_state(state: State) -> State:
	# 判断是否可以跳跃：在地面且跳跃计时器正在运行
	var can_jump := is_on_floor() and jump_request_timer.time_left > 0
	
	# 如果可以跳跃，优先转换为跳跃状态
	if can_jump:
		return State.JUMP
	
	# 获取水平输入方向
	var direction := Input.get_axis("move_left", "move_right")
	# 判断是否静止：无输入且水平速度接近零
	var is_still := is_zero_approx(direction) and is_zero_approx(velocity.x)
	
	# 根据当前状态判断下一个状态
	match state:
		State.IDLE:
			# 闲置时如果有移动输入，转换为奔跑状态
			if not is_still:
				return State.RUNNING
			
		State.RUNNING:
			# 奔跑时如果静止，转换为闲置状态
			if is_still:
				return State.IDLE
			
		State.JUMP:
			# 跳跃时如果落地，转换为闲置状态
			if is_on_floor():
				return State.IDLE
		
		State.DASH:
			# 冲刺状态逻辑（待实现）
			pass
	
	# 默认保持当前状态
	return state


func transition_state(from: State, to: State) -> void:
	# 状态转换时的处理逻辑
	match to:
		State.IDLE:
			# 进入闲置状态（暂无特殊处理）
			pass
		
		State.RUNNING:
			# 进入奔跑状态（暂无特殊处理）
			pass
		
		State.JUMP:
			# 进入跳跃状态：设置跳跃速度并停止计时器
			velocity.y = JUMP_VELOCITY
			jump_request_timer.stop()
			
		State.DASH:
			# 进入冲刺状态（待实现）
			pass
