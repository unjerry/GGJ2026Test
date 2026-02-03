extends CharacterBody2D

enum State {
	IDLE,
	RUNNING,
	JUMP,
	DASH,
}


const GROUND_STATES := [State.IDLE, State.RUNNING]
const RUN_SPEED := 200.0
const JUMP_VELOCITY := -300.0
const FLOOR_ACCELERATION := RUN_SPEED / 0.1
const AIR_ACCELERATION := RUN_SPEED / 0.05
const DASH_VELOCITY := 200


var gravity := ProjectSettings.get("physics/2d/default_gravity") as float
var solid := true

@onready var jump_request_timer: Timer = $JumpRequestTimer


func _unhandled_input(event: InputEvent) -> void:
	if solid:
		if event.is_action_pressed("jump"):
			jump_request_timer.start()
			
		if event.is_action_released("jump") and velocity.y < JUMP_VELOCITY / 2:
			velocity.y = JUMP_VELOCITY / 2


func tick_physics(state: State, delta: float) -> void:
	match  state:
		State.IDLE:
			move(delta)
			
		State.RUNNING:
			move(delta)
			
		State.JUMP:
			move(delta)
			
		State.DASH:
			move(delta)


func move(delta: float) -> void:
	var direction := Input.get_axis("move_left","move_right")
	var acceleration := FLOOR_ACCELERATION if is_on_floor() else AIR_ACCELERATION
	velocity.x = move_toward(velocity.x, direction * RUN_SPEED, acceleration * delta)
	velocity.y += gravity * delta
	
	move_and_slide()


func get_next_state(state: State) -> State:
	var can_jump := is_on_floor() and jump_request_timer.time_left > 0
	if can_jump:
		return State.JUMP
	
	var direction := Input.get_axis("move_left","move_right")
	var is_still := is_zero_approx(direction) and is_zero_approx(velocity.x)
	
	match state:
		State.IDLE:
			if not is_still:
				return State.RUNNING
			
		State.RUNNING:
			if is_still:
				return State.IDLE
			
		State.JUMP:
			if is_on_floor():
				return State.IDLE
		
		State.DASH:
			pass
	
	return state


func transition_state(from: State, to: State) -> void:
	match to:
		State.IDLE:
			pass
		
		State.RUNNING:
			pass
		
		State.JUMP:
			velocity.y = JUMP_VELOCITY
			jump_request_timer.stop()
			
		State.DASH:
			pass
