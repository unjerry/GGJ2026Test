## 教程控制器
## 继承 StateMa，管理教程流程并与 AnimationTree 交互
class_name Tut
extends StateMa

signal tutorial_finished

@export var auto_start := false

# 节点引用
@onready var _anim_player: AnimationPlayer = $AnimationPlayer
@onready var _anim_tree_ad: AnimationTree = $AnimTree_AD
@onready var _anim_tree_space: AnimationTree = $AnimTree_Space
@onready var _panel_ad: PanelContainer = $panel_AD
@onready var _panel_space: PanelContainer = $panel_Space

# AD/Space 输入动作名
var _actions_ad: Array[StringName] = [&"move_left", &"move_right"]
var _actions_space: Array[StringName] = [&"jump"]


func _ready() -> void:
	super._ready()
	_ensure_input_actions()
	_setup_anim_connections()
	if auto_start:
		start_tutorial()


## 开始教程
func start_tutorial() -> void:
	start()
	emit_event(&"start_tutorial")


## 设置动画信号连接
func _setup_anim_connections() -> void:
	if _anim_player:
		_anim_player.animation_finished.connect(_on_animation_finished)


#region 状态回调

func _enter_show_ad() -> void:
	_panel_ad.visible = true
	_panel_ad.modulate.a = 0
	_panel_ad.position.y = 200
	_play_anim(_anim_tree_ad, "show")


func _update_wait_ad(_delta: float) -> void:
	if _check_any_action(_actions_ad):
		emit_event(&"action_done")


func _enter_hide_ad() -> void:
	_play_anim(_anim_tree_ad, "hide")


func _enter_show_space() -> void:
	_panel_space.visible = true
	_panel_space.modulate.a = 0
	_panel_space.position.y = 200
	_play_anim(_anim_tree_space, "show")


func _update_wait_space(_delta: float) -> void:
	if _check_any_action(_actions_space):
		emit_event(&"action_done")


func _enter_hide_space() -> void:
	_play_anim(_anim_tree_space, "hide")


func _enter_end() -> void:
	_panel_ad.visible = false
	_panel_space.visible = false
	tutorial_finished.emit()
	stop()

#endregion


#region 动画控制

## 播放动画状态机
func _play_anim(anim_tree: AnimationTree, state_name: String) -> void:
	if anim_tree == null:
		call_deferred("emit_event", &"anim_done")
		return
	anim_tree.set("parameters/state", state_name)
	anim_tree.active = true


## 动画完成回调
func _on_animation_finished(anim_name: StringName) -> void:
	var current := get_current_state()
	match anim_name:
		&"AD":
			if current == &"show_ad":
				emit_event(&"anim_done")
		&"Hide":
			if current == &"hide_ad":
				emit_event(&"anim_done")
		&"Space":
			if current == &"show_space":
				emit_event(&"anim_done")
		&"Hide_Space":
			if current == &"hide_space":
				emit_event(&"anim_done")

#endregion


#region 输入检测

## 检查是否按下了任意指定动作
func _check_any_action(actions: Array[StringName]) -> bool:
	for action in actions:
		if Input.is_action_just_pressed(action):
			return true
	return false


## 确保输入动作已注册
func _ensure_input_actions() -> void:
	_add_action(&"move_left", [KEY_A, KEY_LEFT])
	_add_action(&"move_right", [KEY_D, KEY_RIGHT])
	_add_action(&"jump", [KEY_SPACE])


func _add_action(action_name: StringName, keycodes: Array) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	var existing := InputMap.action_get_events(action_name)
	for keycode in keycodes:
		var has_key := false
		for ev in existing:
			if ev is InputEventKey and (ev.keycode == keycode or ev.physical_keycode == keycode):
				has_key = true
				break
		if has_key:
			continue

		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		InputMap.action_add_event(action_name, event)

#endregion
