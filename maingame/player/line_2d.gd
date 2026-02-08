extends Line2D

# 1. 要跟踪的节点
@export var target_node: Node2D

# 2. 控制参数
@export var max_points: int = 100  # 增加最大点数
@export var spawn_active: bool = true
@export var point_generation_interval: int = 2  # 每N帧添加一个点，降低密度
@export var trail_lifetime: float = 1.0  # 单个点存在时间（秒）

var frame_counter: int = 0
var point_creation_times: Array[float] = []  # 记录每个点的创建时间


func _physics_process(delta: float) -> void:
	# 关键：重置线条自身变换，确保点在正确位置绘制
	global_position = Vector2.ZERO
	global_rotation = 0
	scale = Vector2.ONE
	
	# 检查目标节点
	if not is_instance_valid(target_node):
		print("!")
		return
	
	if spawn_active:
		# 更新已有点的存在时间
		update_point_times(delta)
		# 按间隔生成新点
		frame_counter += 1
		if frame_counter % point_generation_interval == 0:
			add_trail_point()
		
		# 根据生命周期移除旧点
		remove_old_points()
	else:
		clear_points()
		point_creation_times.clear()

func add_trail_point() -> void:
	# 添加新点（目标节点的全局位置）
	add_point(target_node.global_position)
	# 记录当前点的创建时间
	point_creation_times.append(trail_lifetime)  # 初始化为完整生命周期

func update_point_times(delta: float) -> void:
	# 更新所有点的剩余时间
	for i in point_creation_times.size():
		point_creation_times[i] -= delta

func remove_old_points() -> void:
	# 移除生命周期结束的点（从头部开始移除）
	while point_creation_times.size() > 0 and point_creation_times[0] <= 0:
		remove_point(0)
		point_creation_times.pop_front()
	
	# 硬限制：确保不超过最大点数
	while get_point_count() > max_points:
		remove_point(0)
		if point_creation_times.size() > 0:
			point_creation_times.pop_front()

# 提供一个开关函数，方便外部控制
func toggle_trail(active: bool) -> void:
	spawn_active = active
	if not active:
		clear_points()
		point_creation_times.clear()
