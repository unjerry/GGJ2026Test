extends Control

signal tutorial_finished

@export var auto_start := true

var state := "start"

const _STEP_HINTS: Array[PackedScene] = [
	preload("res://tutorialUI/Hints/hint_ad.tscn"),
	preload("res://tutorialUI/Hints/hint_dash.tscn")
]

const _STEP_ACTIONS: Array[Array] = [
	[&"move_left", &"move_right"],
	[&"dash"]
]

var _step_index := -1
var _step_progress: Dictionary = {}

@onready var _animation_player: AnimationPlayer = $AnimationPlayer
@onready var _animation_tree: AnimationTree = $statemachine
@onready var _playback: AnimationNodeStateMachinePlayback = _animation_tree.get("parameters/playback")
@onready var _panel_hint: PanelContainer = $panel_Hint_AD
@onready var _hint_container: MarginContainer = $panel_Hint_AD/MarginContainer


func _ready() -> void:
	_ensure_input()
	_animation_tree.active = true
	_animation_player.animation_finished.connect(_on_animation_finished)
	if _STEP_HINTS.size() != _STEP_ACTIONS.size():
		push_error("Tutorial step config mismatch: hints and actions size differ.")
		return
	if auto_start:
		start_tutorial()


func _process(_delta: float) -> void:
	if state != "show":
		return
	_update_step_progress()


func start_tutorial() -> void:
	state = "start"
	_step_index = -1
	show()
	_go_to_next_step()


func _go_to_next_step() -> void:
	_step_index += 1
	if _step_index >= _STEP_HINTS.size():
		state = "end"
		hide()
		tutorial_finished.emit()
		return

	_replace_hint(_STEP_HINTS[_step_index])
	_step_progress.clear()
	_prepare_panel_for_enter()
	state = "show"
	_playback.start("Start")


func _update_step_progress() -> void:
	var required := _STEP_ACTIONS[_step_index]
	for action_name in required:
		if Input.is_action_just_pressed(action_name):
			_step_progress[action_name] = true

	if _step_progress.size() == required.size():
		state = "hide"


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == &"Hide" and state == "hide":
		_go_to_next_step()


func _replace_hint(hint_scene: PackedScene) -> void:
	for child in _hint_container.get_children():
		child.free()

	var instance := hint_scene.instantiate()
	_hint_container.add_child(instance)


func _prepare_panel_for_enter() -> void:
	_panel_hint.visible = true
	_panel_hint.position.y = 200.0
	_panel_hint.modulate = Color(1, 1, 1, 0)


func _ensure_input() -> void:
	_add_action("move_left", [KEY_A, KEY_LEFT])
	_add_action("move_right", [KEY_D, KEY_RIGHT])
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
