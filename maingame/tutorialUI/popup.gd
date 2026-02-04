extends Control

signal tutorial_finished

@export var auto_start := true

var state := "start"

var _moved_left := false
var _moved_right := false

@onready var _animation_tree: AnimationTree = $statemachine


func _ready() -> void:
	#pass
	_ensure_input()
	#_animation_tree.active = true
	#_animation_player.animation_finished.connect(_on_animation_finished)
	if auto_start:
		start_tutorial()


func _process(_delta: float) -> void:
	if state != "start":
		return

	if Input.is_action_just_pressed("move_left"):
		_moved_left = true
	if Input.is_action_just_pressed("move_right"):
		_moved_right = true

	if _moved_left and _moved_right:
		_complete_tutorial()


func start_tutorial() -> void:
	state = "start"
	_moved_left = false
	_moved_right = false
	show()



func _complete_tutorial() -> void:
	state = "hide"


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == &"Hide" and state == "end":
		hide()
		tutorial_finished.emit()


func _ensure_input() -> void:
	_add_action("move_left", [KEY_A, KEY_LEFT])
	_add_action("move_right", [KEY_D, KEY_RIGHT])


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
