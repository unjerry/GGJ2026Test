extends CharacterBody2D

enum Form { DOT, RING }

@export var form: Form = Form.DOT
@export var move_speed := 220.0
@export var jump_velocity := -320.0
@export var dash_speed := 520.0
@export var dash_duration := 0.12
@export var dash_cooldown := 0.4
@export var radius := 10.0
@export var ring_width := 2.0

var _gravity := ProjectSettings.get_setting("physics/2d/default_gravity") as float
var _dash_time_left := 0.0
var _dash_cooldown_left := 0.0
var _dash_dir := Vector2.ZERO
var _facing := 1.0


func _ready() -> void:
	_ensure_input()
	queue_redraw()


func _physics_process(delta: float) -> void:
	_update_dash_timers(delta)

	var input_dir := Input.get_axis("move_left", "move_right")
	if input_dir != 0.0:
		_facing = sign(input_dir)

	if _dash_time_left > 0.0:
		velocity = _dash_dir * dash_speed
	else:
		if not is_on_floor():
			velocity.y += _gravity * delta
		elif form == Form.RING and Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity

		velocity.x = input_dir * move_speed

	if Input.is_action_just_pressed("dash") and _dash_time_left <= 0.0 and _dash_cooldown_left <= 0.0:
		_start_dash()

	move_and_slide()


func _start_dash() -> void:
	_dash_cooldown_left = dash_cooldown
	_dash_time_left = dash_duration

	if form == Form.RING:
		var dir := get_global_mouse_position() - global_position
		if dir.length() < 0.001:
			dir = Vector2(_facing, 0.0)
		_dash_dir = dir.normalized()
	else:
		var dir_x := Input.get_axis("move_left", "move_right")
		if dir_x == 0.0:
			dir_x = _facing
		_dash_dir = Vector2(sign(dir_x), 0.0)


func _update_dash_timers(delta: float) -> void:
	if _dash_time_left > 0.0:
		_dash_time_left = max(0.0, _dash_time_left - delta)
	if _dash_cooldown_left > 0.0:
		_dash_cooldown_left = max(0.0, _dash_cooldown_left - delta)


func _draw() -> void:
	if form == Form.DOT:
		draw_circle(Vector2.ZERO, radius, Color.BLACK)
	else:
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color.BLACK, ring_width)


func _ensure_input() -> void:
	_add_action("move_left", [KEY_A, KEY_LEFT])
	_add_action("move_right", [KEY_D, KEY_RIGHT])
	_add_action("jump", [KEY_SPACE])
	_add_action("dash", [KEY_SHIFT])


func _add_action(action_name: String, keycodes: Array) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	var existing := InputMap.action_get_events(action_name)
	for keycode in keycodes:
		var already := false
		for ev in existing:
			if ev is InputEventKey and (ev.keycode == keycode or ev.physical_keycode == keycode):
				already = true
				break
		if already:
			continue

		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		InputMap.action_add_event(action_name, event)
		existing.append(event)
