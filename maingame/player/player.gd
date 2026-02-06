# 文件名: player.gd (玩家角色脚本)
# 说明：玩家角色控制，包含移动、跳跃、状态管理等功能

extends CharacterBody2D

# 状态枚举定义
enum State {
	IDLE, # 闲置状态
	RUNNING, # 奔跑状态
	JUMP, # 跳跃状态
	DASH, # 冲刺状态
	BACHDASH, # 反向冲刺状态
	HURT, # 受击状态
}

# 地面状态数组（用于判断是否在地面状态）
const GROUND_STATES := [State.IDLE, State.RUNNING]

# 角色属性常量
const RUN_SPEED := 1000.0 # 奔跑速度
const JUMP_VELOCITY := -1500.0 # 跳跃初速度（负值表示向上）
const FLOOR_ACCELERATION := RUN_SPEED / 0.1 # 地面加速度
const AIR_ACCELERATION := RUN_SPEED / 0.05 # 空中加速度
const DASH_ACCELERATION := 5 # 冲刺加速度
const DASH_VELOCITY := 3000.0 # 冲刺速度
const HURT_DURATION := 0.4 # 受击硬直时间（与Cut动画长度一致）
const DOT_TEXTURE := preload("res://assets/Pictures/ball.png")
const RING_TEXTURE := preload("res://assets/Pictures/circle.png")
const DASH_DURATION := 0.1
const DASH_FULL_SPEED_RATIO := 0.2 # 70%时间全速，30%时间减速

# 角色变量
var gravity := ProjectSettings.get("physics/2d/default_gravity") * 5 as float # 从项目设置获取重力值
var solid := true # 空心与实心状态的标记
var is_first_tick := false
var dash_direction := Vector2.RIGHT
var dash_requested := false
var has_dash := false
var backdash_requested := false
var has_backdash := false
var hurt_requested := false
var is_dead := false
var keep_cut_visible := false
var mouse_global_pos := get_global_mouse_position()

# 节点引用
@onready var jump_request_timer: Timer = $JumpRequestTimer # 跳跃输入缓冲计时器
@onready var dash_timer: Timer = $DashTimer
@onready var ball: Sprite2D = $Ball
@onready var circle: Sprite2D = $Circle
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var state_machine: StateMachine = $StateMachine


func _ready() -> void:
	dash_timer.one_shot = true
	if not animation_player.animation_finished.is_connected(_on_animation_finished):
		animation_player.animation_finished.connect(_on_animation_finished)
	_update_form_visual()


func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		return

	if event.is_action_pressed("dash"):
		if state_machine.current_state != State.DASH and not has_dash:
			if not dash_requested:
				dash_direction = calculate_dash_direction()
			has_dash = true
			dash_requested = true
	
	if event.is_action_pressed("backdash"):
		if state_machine.current_state != State.BACHDASH and not has_backdash:
			if not backdash_requested:
				dash_direction = -1 * calculate_dash_direction()
			has_backdash = true
			backdash_requested = true
		
	# 只有空心形态（solid=false）才处理跳跃输入
	if not solid:
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
			dash_move() # 冲刺状态下的移动
		
		State.BACHDASH:
			dash_move() # 冲刺状态下的移动

		State.HURT:
			hurt_move(delta) # 受击状态下的移动


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


func dash_move() -> void:
	var time_left = dash_timer.time_left
	
	# 计算全速阶段和减速阶段的分界点
	var full_speed_time = DASH_DURATION * DASH_FULL_SPEED_RATIO
	
	if time_left > DASH_DURATION - full_speed_time:
		# 全速阶段：刚开始的20%时间
		velocity = dash_direction * DASH_VELOCITY
	else:
		# 减速阶段：最后的80%时间
		var decel_duration = DASH_DURATION * (1.0 - DASH_FULL_SPEED_RATIO)
		var time_in_decel = decel_duration - time_left
		
		# 计算减速进度（0到1）
		var decel_progress = clamp(time_in_decel / decel_duration, 0.0, 1.0)
		
		# 使用缓动函数让减速更自然
		# easeOutCubic: 1 - (1 - t)^3
		var eased_progress = 1.0 - pow(1.0 - decel_progress, 3.0)
		
		# 计算当前速度
		var current_speed = DASH_VELOCITY * (1.0 - eased_progress)
		velocity = dash_direction * current_speed
	
	move_and_slide()


func hurt_move(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, FLOOR_ACCELERATION * delta)
	velocity.y += gravity * delta
	move_and_slide()


func get_next_state(state: State) -> State:
	if is_on_floor():
		has_dash = false
		has_backdash = false
	
	if is_dead:
		return State.HURT

	if hurt_requested and state != State.HURT:
		return State.HURT

	if state == State.HURT:
		hurt_requested = false
		if state_machine.state_time < HURT_DURATION:
			return State.HURT

	if state == State.DASH:
		if dash_timer.time_left > 0.0:
			return State.DASH
		# 防止冲刺中再次点按导致请求残留，避免状态卡在 DASH。
		dash_requested = false
	
	if state == State.BACHDASH:
		if dash_timer.time_left > 0.0:
			return State.BACHDASH
		# 防止冲刺中再次点按导致请求残留，避免状态卡在 DASH。
		backdash_requested = false

	if dash_requested:
		return State.DASH

	if backdash_requested:
		return State.BACHDASH

	# 判断是否可以跳跃：在地面且跳跃计时器正在运行
	var can_jump := not solid and is_on_floor() and jump_request_timer.time_left > 0
	
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
			if is_still:
				return State.IDLE  
			else:
				velocity.x = RUN_SPEED * direction
				return State.RUNNING

		State.BACHDASH:
			return State.IDLE if is_still else State.RUNNING
			
		State.HURT:
			if is_on_floor():
				return State.IDLE if is_still else State.RUNNING
			return State.JUMP
	
	# 默认保持当前状态
	return state


func transition_state(from: State, to: State) -> void:
	if from == State.HURT and to != State.HURT:
		keep_cut_visible = false

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
			jump_request_timer.stop()
			velocity.y = JUMP_VELOCITY
			
		State.DASH:
			jump_request_timer.stop()
			dash_timer.start()
						
		State.BACHDASH:
			jump_request_timer.stop()
			dash_timer.start()

		State.HURT:
			hurt_requested = false
			jump_request_timer.stop()
			dash_timer.stop()
			if solid:
				solid = false
				keep_cut_visible = true
				animation_player.play(&"Cut")
				_update_form_visual()
			else:
				is_dead = true
				call_deferred("queue_free")


func hurt() -> void:
	if is_dead:
		return
	hurt_requested = true


func attack() -> void:
	if is_dead:
		return
	if state_machine.current_state == State.HURT:
		return
	keep_cut_visible = false
	animation_player.play(&"Cut")


func _on_animation_finished(anim_name: StringName) -> void:
	pass

func calculate_dash_direction() -> Vector2:
	var mouse_pos = get_global_mouse_position()
	var to_mouse = mouse_pos - global_position
	
	if solid:  # 实心点：水平方向
		var x_direction = sign(to_mouse.x)
		# 如果x为0，使用默认方向
		if x_direction == 0:
			x_direction = 1 if velocity.x >= 0 else -1
		return Vector2(x_direction, 0)
	else:  # 空心环：向鼠标方向
		if to_mouse.length_squared() > 0.001:  # 避免除零
			return to_mouse.normalized()
		return Vector2.RIGHT  # 默认方向


func _update_form_visual() -> void:
	ball.texture = DOT_TEXTURE if solid else RING_TEXTURE
