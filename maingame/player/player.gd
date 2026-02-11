# 文件名: player.gd (玩家角色脚本)
# 说明：玩家角色控制，包含移动、跳跃、状态管理等功能
class_name Player
extends CharacterBody2D

# 状态枚举定义
enum State {
	IDLE,      # 闲置状态
	RUNNING,   # 奔跑状态
	JUMP,      # 跳跃状态
	DASH,      # 冲刺状态
	BACHDASH,  # 反向冲刺状态
	HURT,      # 受击状态
	DYING     # 死亡状态
}

# 常量定义
const GROUND_STATES := [State.IDLE, State.RUNNING]  # 地面状态数组
const RUN_SPEED := 1000.0               # 奔跑速度
const JUMP_VELOCITY := -1500.0          # 跳跃初速度
const FLOOR_ACCELERATION := RUN_SPEED / 0.1   # 地面加速度
const AIR_ACCELERATION := RUN_SPEED / 0.05    # 空中加速度
const DASH_VELOCITY := 2000.0           # 冲刺速度
const HURT_DURATION := 0.4              # 受击硬直时间
const DOT_TEXTURE := preload("res://assets/Pictures/ball.png")
const RING_TEXTURE := preload("res://assets/Pictures/circle.png")
const DASH_FULL_SPEED_RATIO := 0.05     # 5%时间全速，95%时间减速
const KNOCKBACK_AMOUNT := 4000          # 击退力度
const INVINCIBLE_DURATION := 1        # 无敌时间（秒）
const HURT_ACCELERATION := 3500   		# 受击加速度
const DASH_COOLDOWN := 0.5              # 冲刺冷却时间（秒）
const MIN_VELOCITY := 5.0               # 最小速度阈值

# 导出变量
@export var solid := true               # 空心与实心状态的标记

# 变量声明
var gravity := ProjectSettings.get("physics/2d/default_gravity") * 4 as float
var dash_direction := Vector2.RIGHT
var dash_duration := 0.0
var pending_damage: Damage
var dash_requested := false
var backdash_requested := false
var hurt_requested := false
var has_dash := false
var has_backdash := false
var invincible := false  # 无敌状态标记
var hurt_direction := Vector2.RIGHT
var interacting_with : Interactable
var dash_on_cooldown := false           # 普通冲刺冷却中
var backdash_on_cooldown := false       # 反向冲刺冷却中
var mid := false

# 节点引用
@onready var jump_request_timer: Timer = $JumpRequestTimer  # 跳跃输入缓冲计时器
@onready var dash_timer: Timer = $DashTimer
@onready var ball: Sprite2D = $Graphics/Ball
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var state_machine: StateMachine = $StateMachine
@onready var hurtbox: CollisionShape2D = $Graphics/Hurtbox/Hurtbox
@onready var hitbox: CollisionShape2D = $Graphics/Hitbox/Hitbox
@onready var hurt_timer: Timer = $HurtTimer
@onready var sprite_trail: Node = $SpriteTrail
@onready var dash_cooldown_timer: Timer = $DashCooldownTimer  # 普通冲刺冷却计时器
@onready var backdash_cooldown_timer: Timer = $BackdashCooldownTimer  # 反向冲刺冷却计时器
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D
@onready var stats: Stats = Game.player_stats

# 初始化函数
func _ready() -> void:
	animation_player.animation_finished.connect(_on_animation_finished)
	dash_cooldown_timer.timeout.connect(_on_dash_cooldown_timeout)
	backdash_cooldown_timer.timeout.connect(_on_backdash_cooldown_timeout)
	_update_form_visual()

# 输入处理函数
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("dash") and not has_dash and not dash_on_cooldown:
		_handle_dash_input()
	elif event.is_action_pressed("backdash") and not has_backdash and not backdash_on_cooldown:
		_handle_backdash_input()
	elif not solid:  # 只有空心形态才能跳跃
		_handle_jump_input(event)

# 物理更新函数
func tick_physics(state: State, delta: float) -> void:
	match state:
		State.IDLE, State.RUNNING, State.JUMP:
			_move_with_input(delta)
		State.DASH, State.BACHDASH:
			_dash_movement()
		State.HURT:
			_hurt_movement()

# 状态机函数
func get_next_state(state: State) -> State:
	# 重置地面能力
	_reset_ground_abilities()
	
	# 状态优先级检查
	if hurt_requested and state != State.HURT:
		return State.HURT
	
	# 处理当前状态
	return _process_current_state(state)

func transition_state(from: State, to: State) -> void:
	_handle_animation_transition(to)
	
	match to:
		State.JUMP:
			SoundManager.play_sfx("jump")
			_start_jump()
		State.DASH, State.BACHDASH:
			SoundManager.play_sfx("dash")
			_start_dash()
		State.HURT:
			SoundManager.play_sfx("hurt")
			_start_hurt_state()
			_reset_dash_cooldowns()  # 进入受击状态时刷新冷却

# 移动函数
func _move_with_input(delta: float) -> void:
	var direction := Input.get_axis("move_left", "move_right")
	var acceleration := FLOOR_ACCELERATION if is_on_floor() else AIR_ACCELERATION
	
	velocity.x = move_toward(velocity.x, direction * RUN_SPEED, acceleration * delta)
	velocity.y += gravity * delta
	
	move_and_slide()

func _dash_movement() -> void:
	var time_left = dash_timer.time_left
	var full_speed_time = dash_duration * DASH_FULL_SPEED_RATIO
	
	if time_left > dash_duration - full_speed_time:
		velocity = dash_direction * DASH_VELOCITY
	else:
		var current_speed = _calculate_dash_deceleration(time_left)
		velocity = dash_direction * current_speed
	
	move_and_slide()

func _calculate_dash_deceleration(time_left: float) -> float:
	var decel_duration = dash_duration * (1.0 - DASH_FULL_SPEED_RATIO)
	var time_in_decel = decel_duration - time_left
	var decel_progress = clamp(time_in_decel / decel_duration, 0.0, 1.0)
	var eased_progress = 1.0 - pow(1.0 - decel_progress, 3.0)
	var speed_range = DASH_VELOCITY - RUN_SPEED
	var current_speed = DASH_VELOCITY - (speed_range * eased_progress)
	return max(current_speed, RUN_SPEED)

func _hurt_movement() -> void:
	# 应用击退效果
	if hurt_direction != Vector2.ZERO:
		velocity = hurt_direction.normalized() * KNOCKBACK_AMOUNT
	
	# 平滑减速
	velocity = velocity.move_toward(Vector2.ZERO, HURT_ACCELERATION)
	
	# 清空待处理伤害
	pending_damage = null
	
	# 当速度很小时直接归零，防止微小抖动
	if velocity.length_squared() < MIN_VELOCITY * MIN_VELOCITY:
		velocity = Vector2.ZERO
	
	move_and_slide()

# 工具函数
func calculate_dash_direction() -> Vector2:
	var mouse_dir = global_position.direction_to(get_global_mouse_position())
	
	if solid:  # 实心点：水平方向
		var horizontal_dir = mouse_dir.x
		if abs(horizontal_dir) < 0.001:
			horizontal_dir = sign(velocity.x) if abs(velocity.x) > 0.001 else 1
		return Vector2(sign(horizontal_dir), 0)
	else:  # 空心环：向鼠标方向
		return mouse_dir if mouse_dir.length_squared() > 0.001 else Vector2.RIGHT

func _update_form_visual() -> void:
	ball.texture = DOT_TEXTURE if solid else RING_TEXTURE
	_update_invincibility_visual()
	_update_collision_mask()

func _update_invincibility_visual() -> void:
	ball.modulate = Color(1, 1, 1, 0.5 if invincible else 1)

func _update_collision_mask() -> void:
	if solid:
		collision_mask = 1  # 二进制 001
	elif not solid and mid:
		collision_mask = 3  # 中间态
	else:
		collision_mask = 2  # 二进制 010

# 冲刺冷却管理
func _reset_dash_cooldowns() -> void:
	# 重置普通冲刺冷却
	dash_on_cooldown = false
	dash_cooldown_timer.stop()
	
	# 重置反向冲刺冷却
	backdash_on_cooldown = false
	backdash_cooldown_timer.stop()
	
	# 重置冲刺次数标志
	has_dash = false
	has_backdash = false
	dash_requested = false
	backdash_requested = false
	
	# 如果空中受击，更新视觉状态
	if not is_on_floor():
		mid = false
		_update_form_visual()

func _start_dash_cooldown(is_backdash: bool = false) -> void:
	if is_backdash:
		backdash_on_cooldown = true
		backdash_cooldown_timer.wait_time = DASH_COOLDOWN
		backdash_cooldown_timer.start()
	else:
		dash_on_cooldown = true
		dash_cooldown_timer.wait_time = DASH_COOLDOWN
		dash_cooldown_timer.start()

# 辅助函数
func _reset_ground_abilities() -> void:
	if is_on_floor() and state_machine.current_state != State.HURT:
		has_dash = false
		has_backdash = false
	elif not is_on_floor() and state_machine.current_state != State.HURT:
		mid = false
		_update_form_visual()

func _process_current_state(state: State) -> State:
	# 处理HURT状态
	if state == State.HURT:
		return _process_hurt_state()
	
	# 处理冲刺状态
	if _handle_dash_states(state):
		return state
	
	# 处理请求状态
	if dash_requested and not dash_on_cooldown:
		return State.DASH
	if backdash_requested and not backdash_on_cooldown:
		return State.BACHDASH
	
	# 处理跳跃
	if _can_jump():
		return State.JUMP
	
	# 处理其他状态转换
	return _determine_state_by_input_and_physics(state)

func _process_hurt_state() -> State:
	hurt_requested = false
	if hurt_timer.time_left > 0.0:
		return State.HURT
	
	invincible = false
	_update_form_visual()
	return State.IDLE

func _handle_dash_states(state: State) -> bool:
	if state in [State.DASH, State.BACHDASH] and dash_timer.time_left > 0.0:
		return true
	
	# 冲刺结束后的清理
	if state in [State.DASH, State.BACHDASH] and dash_timer.time_left <= 0.0:
		hurtbox.disabled = false
		hitbox.disabled = true
		dash_requested = false
		backdash_requested = false
		_start_dash_cooldown(state == State.BACHDASH)
	
	return false

func _can_jump() -> bool:
	return not solid and is_on_floor() and jump_request_timer.time_left > 0

func _determine_state_by_input_and_physics(state: State) -> State:
	var direction := Input.get_axis("move_left", "move_right")
	var is_still := is_zero_approx(direction) and is_zero_approx(velocity.x)
	
	match state:
		State.IDLE:
			return State.RUNNING if not is_still else State.IDLE
		State.RUNNING:
			return State.IDLE if is_still else State.RUNNING
		State.JUMP:
			return State.IDLE if is_on_floor() else State.JUMP
		State.DASH, State.BACHDASH:
			return State.IDLE if is_still else State.RUNNING
		State.HURT:
			return State.JUMP if not is_on_floor() else State.IDLE
	
	return state

func _handle_animation_transition(to: State) -> void:
	if mid:
		animation_player.play("mid")
	else:
		animation_player.play("RESET")

# 动作函数
func _start_jump() -> void:
	jump_request_timer.stop()
	velocity.y = JUMP_VELOCITY

func _start_dash() -> void:
	jump_request_timer.stop()
	hurtbox.disabled = true
	hitbox.disabled = false
	dash_timer.start()
	dash_duration = dash_timer.time_left

func _start_hurt_state() -> void:
	animation_player.play("hurt")
	hurt_requested = false
	jump_request_timer.stop()
	dash_timer.stop()
	
	# 空中受击时设置mid状态
	if not is_on_floor():
		mid = true
		_update_form_visual()

# 输入处理辅助函数
func _handle_dash_input() -> void:
	if not dash_requested:
		dash_direction = calculate_dash_direction()
	has_dash = true
	dash_requested = true

func _handle_backdash_input() -> void:
	if not backdash_requested:
		dash_direction = -calculate_dash_direction()
	has_backdash = true
	backdash_requested = true

func _handle_jump_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		jump_request_timer.start()
	elif event.is_action_released("jump") and velocity.y < JUMP_VELOCITY / 2:
		velocity.y = JUMP_VELOCITY / 2

# 信号处理函数
func _on_animation_finished(anim_name: StringName) -> void:
	pass

func _on_hurtbox_hurt(hitbox: Variant) -> void:
	stats.current_solid = false
	if invincible or hurt_requested:
		return
	
	# 创建伤害数据
	pending_damage = Damage.new()
	pending_damage.source = hitbox.owner
	
	if pending_damage.source == null:
		pending_damage = null
		return
	
	# 处理受击逻辑
	if solid:
		Game.shake_camera(6)
		mid = true
		solid = false
		hurt_requested = true
		invincible = true
		hurt_timer.start(HURT_DURATION)
		hurt_direction = pending_damage.source.global_position.direction_to(global_position)
		
		# 受击时刷新冲刺冷却
		_reset_dash_cooldowns()
	else:
		die(0)
	_update_form_visual()


func die(scene: int) -> void:
	if sprite_trail:
		sprite_trail.cleanup_all_trails()
	
	get_tree().paused = true
	animation_player.play("die")
	await animation_player.animation_finished
	get_tree().paused = false
	
	# 根据参数执行唯一动作
	match scene:
		1:
			Game.load_game()
		2:
			Game.change_scene("res://ui/title_screen.tscn")
		_:
			if Game.has_save():
				Game.load_game()
			else:
				Game.back_to_title()


func _on_hitbox_hit(hurtbox: Variant) -> void:
	SoundManager.play_sfx("hit")
	solid = true
	_update_form_visual()
	Game.shake_camera(3)
	
	# 慢动作效果
	Engine.time_scale = 0.01
	await get_tree().create_timer(0.1, true, false, true).timeout
	Engine.time_scale = 1
	stats.current_solid = true


# 冷却计时器回调
func _on_dash_cooldown_timeout() -> void:
	dash_on_cooldown = false

func _on_backdash_cooldown_timeout() -> void:
	backdash_on_cooldown = false


func play_reverse_death() -> void:
	get_tree().paused = true
	animation_player.play("play_reverse_death")
	await animation_player.animation_finished
	get_tree().paused = false
