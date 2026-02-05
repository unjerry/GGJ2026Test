extends Enemy

enum State {
	SOLID,
	HOLLOW,
}


func tick_physics(state: State, delta: float) -> void:
	match state:
		State.SOLID:
			move(0.0, delta)
		
		State.HOLLOW:
			move(0.0, delta)


func get_next_state(state: State) -> State:
	match state:
		State.SOLID:
			pass
		
		State.HOLLOW:
			pass
	
	return state
	

func transition_state(from: State, to: State) -> void:
	# 状态转换时的处理逻辑
	match to:
		State.SOLID:
			# 进入闲置状态（暂无特殊处理）
			pass
		
		State.HOLLOW:
			pass
