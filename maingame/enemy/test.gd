extends Enemy

enum State {
	IDLE,
	HURT,
	DYING
}

const DOT_TEXTURE := preload("res://assets/Pictures/ball.png")
const RING_TEXTURE := preload("res://assets/Pictures/circle.png")

var solid := true
var knockback_direction := Vector2.ZERO
var hurt := false
var dying := false
var panding_damage: Damage

@onready var ball: Sprite2D = $Graphics/Ball
@onready var hurt_timer: Timer = $HurtTimer
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D
@onready var hitbox: CollisionShape2D = $Graphics/Hitbox/Hitbox
@onready var hurtbox: CollisionShape2D = $Graphics/Hurtbox/Hurtbox


func tick_physics(state: State, delta: float) -> void:
	pass


func get_next_state(state: State) -> State:
	# 状态优先级：DYING > HURT > 其他
	if dying:
		return State.DYING
	
	# 如果hurt_timer还在运行，保持HURT状态
	if panding_damage:
		return State.HURT
	
	match state:
		State.HURT:
			if not hurt_timer.time_left > 0.0:
				return State.IDLE
		State.IDLE:
			# 可以添加其他转换条件
			pass
		State.DYING:
			# 死亡状态处理
			pass
	
	return state


func transition_state(from: State, to: State) -> void:
	# 状态转换时的处理逻辑
	match to:
		State.IDLE:
			# 进入闲置状态（暂无特殊处理）
			pass
			
		State.HURT:
			pass

		State.DYING:
			# 死亡状态：可以播放死亡动画
			queue_free()
			pass


func _on_hurtbox_hurt(hitbox: Hitbox) -> void:
	panding_damage = Damage.new()
	panding_damage.source = hitbox.owner
	
	if dying:
		return
	
	if solid:
		solid = false
		hurt = true
		hurt_timer.start()  # 0.3秒受击硬直
	else:
		dying = true
	print(solid)
	_update_form_visual()


func _update_form_visual() -> void:
	ball.texture = DOT_TEXTURE if solid else RING_TEXTURE
	
	# 更新碰撞掩码
	if solid:
		# 实心时：只与第1层碰撞
		collision_mask = 1  # 二进制 001
	else:
		# 空心时：只与第2层碰撞
		collision_mask = 2  # 二进制 010


# 当敌人的攻击盒击中玩家时调用
func _on_hitbox_hit(hurtbox: Hurtbox) -> void:
	solid = true
	_update_form_visual()
