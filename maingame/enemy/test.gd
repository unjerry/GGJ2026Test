extends Enemy

enum State {
	IDLE,
}


func tick_physics(state: State, delta: float) -> void:
	match state:
		State.IDLE:
			move(0.0, delta)


func get_next_state(state: State) -> State:
	match state:
		State.IDLE:
			pass
	
	return state
	

func transition_state(from: State, to: State) -> void:
	# 状态转换时的处理逻辑
	match to:
		State.IDLE:
			# 进入闲置状态（暂无特殊处理）
			pass
