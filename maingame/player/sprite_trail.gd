extends Node

@onready var player: Player = $".."
@onready var dash_timer: Timer = $"../DashTimer"
@export var ball_sprite: Sprite2D

# 正常状态参数
@export var trail_count: int = 20
@export var spawn_rate: int = 3  # 每几帧生成一个残影
@export var fade_start_alpha: float = 0.2
@export var fade_end_alpha: float = 0.0
@export var fade_duration: float = 0.5
@export var return_delay: float = 0.1  # 残影返回池子的延迟
@export var normal_scale_multiplier: float = 1.0  # 正常状态大小倍数
@export var normal_end_scale_multiplier: float = 0.8  # 正常状态结束时大小倍数

# 冲刺状态参数
@export var dash_spawn_rate: int = 1  # 冲刺时每帧生成一个残影
@export var dash_fade_start_alpha: float = 0.3  # 冲刺时起始透明度
@export var dash_fade_end_alpha: float = 0.0  # 冲刺时结束透明度
@export var dash_fade_duration: float = 0.2  # 冲刺时淡出时间更短
@export var dash_return_delay: float = 0.05  # 冲刺时返回池子延迟更短
@export var dash_scale_multiplier: float = 1.2  # 冲刺时大小倍数
@export var dash_end_scale_multiplier: float = 0.9  # 冲刺状态结束时大小倍数

var sprite_pool: Array[Sprite2D] = []
var _frame_counter: int = 0
var active_trail_sprites: Array[Sprite2D] = []


func _ready() -> void:
	# 清理可能残留的旧残影
	cleanup_all_trails()
	setup_sprite_pool()


# 添加清理函数
func cleanup_all_trails() -> void:
	# 清理所有活跃的残影
	for sprite in active_trail_sprites:
		if is_instance_valid(sprite):
			sprite.queue_free()
	active_trail_sprites.clear()
	
	# 清理池中的残影
	for sprite in sprite_pool:
		if is_instance_valid(sprite):
			sprite.queue_free()
	sprite_pool.clear()


func setup_sprite_pool() -> void:
	for i in range(trail_count):
		var new_sprite = ball_sprite.duplicate()
		new_sprite.z_index = 0
		new_sprite.modulate.a = 0
		
		get_tree().root.add_child.call_deferred(new_sprite)
		sprite_pool.append(new_sprite)


func _process(delta: float) -> void:
	if player.velocity.x == 0:
		return
	
	_frame_counter += 1
	
	# 检查是否在冲刺期间
	var is_dashing = dash_timer.time_left > 0
	var current_spawn_rate = dash_spawn_rate if is_dashing else spawn_rate
	
	if _frame_counter % current_spawn_rate != 0:
		return
	
	if not sprite_pool.is_empty():
		var sprite: Sprite2D = sprite_pool.pop_front()
		sprite.global_position = player.global_position
		
		# 根据是否冲刺设置不同的大小
		var scale_multiplier = dash_scale_multiplier if is_dashing else normal_scale_multiplier
		sprite.scale = player.scale * scale_multiplier
		
		# 执行淡出动画，传递冲刺状态
		_start_sprite_fading(sprite, is_dashing)
		
		# 使用call_deferred避免在_process中await
		call_deferred("_return_sprite_to_pool", sprite, is_dashing)


func _return_sprite_to_pool(sprite: Sprite2D, is_dashing: bool) -> void:
	var delay = dash_return_delay if is_dashing else return_delay
	await get_tree().create_timer(delay).timeout
	sprite_pool.append(sprite)


func _start_sprite_fading(sprite: Sprite2D, is_dashing: bool) -> void:
	# 添加到活跃列表
	active_trail_sprites.append(sprite)
	
	var start_alpha = dash_fade_start_alpha if is_dashing else fade_start_alpha
	var end_alpha = dash_fade_end_alpha if is_dashing else fade_end_alpha
	var duration = dash_fade_duration if is_dashing else fade_duration
	
	# 设置起始缩放值
	var start_scale = sprite.scale
	# 计算结束缩放值
	var end_scale_multiplier = dash_end_scale_multiplier if is_dashing else normal_end_scale_multiplier
	var end_scale = player.scale * end_scale_multiplier
	
	# 设置起始透明度
	sprite.modulate.a = start_alpha
	
	# 创建并行动画：同时淡出和缩小
	var tween = get_tree().create_tween()
	
	# 透明度动画
	tween.parallel().tween_method(
		_update_sprite_alpha.bind(sprite), 
		start_alpha, 
		end_alpha, 
		duration
	)
	
	# 缩放动画 - 同时进行
	tween.parallel().tween_method(
		_update_sprite_scale.bind(sprite), 
		start_scale, 
		end_scale, 
		duration
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	
	tween.finished.connect(_on_trail_finished.bind(sprite))  # 添加完成回调


func _update_sprite_alpha(alpha_value: float, sprite: Sprite2D) -> void:
	sprite.modulate.a = alpha_value


func _update_sprite_scale(scale_value: Vector2, sprite: Sprite2D) -> void:
	sprite.scale = scale_value


func _on_trail_finished(sprite: Sprite2D) -> void:
	# 从活跃列表中移除
	if sprite in active_trail_sprites:
		active_trail_sprites.erase(sprite)
