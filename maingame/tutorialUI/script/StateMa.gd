## 通用有限状态机 (FSM)
##
## 通过 JSON 配置文件定义状态和转换规则，支持：
## - 状态生命周期回调 (enter/update/exit)
## - 事件驱动的状态转换
## - 全局转换 (from: "*")
## - 信号自动绑定到事件
##
## 使用方法：
## 1. 继承此类并实现状态回调方法
## 2. 设置 config_path 指向 JSON 配置文件
## 3. 调用 start() 启动状态机
class_name StateMa
extends Node

## JSON 配置文件路径
@export_file("*.json") var config_path := "res://tutorialUI/tutorial_fsm.json"

var _running := false # 状态机是否正在运行
var _current_state: StringName = &"" # 当前状态名
var _initial_state: StringName = &"" # 初始状态名
var _states: Dictionary = {} # 状态配置 { state_name: { enter, update, exit } }
var _transitions: Dictionary = {} # 状态转换表 { from_state: { event: to_state } }
var _global_transitions: Dictionary = {} # 全局转换表 { event: to_state }
var _event_queue: Array[StringName] = [] # 待处理事件队列


func _ready() -> void:
	set_process(false)


#region 公共接口

## 启动状态机，可指定初始状态覆盖配置
func start(initial_override: StringName = &"") -> void:
	stop()
	if not _load_config():
		return

	var init_state := initial_override if initial_override != &"" else _initial_state
	if not _states.has(init_state):
		push_error("StateMa: 初始状态 '%s' 不存在" % String(init_state))
		return

	_running = true
	set_process(true)
	_change_state(init_state)


## 停止状态机
func stop() -> void:
	if not _running and _current_state == &"":
		return

	_running = false
	set_process(false)
	_event_queue.clear()
	if _current_state != &"":
		_invoke_state_exit(_current_state)
	_current_state = &""


## 发送事件，触发状态转换
func emit_event(event_name: StringName) -> void:
	if event_name == &"":
		push_warning("StateMa: 事件名为空，已忽略")
		return
	if not _running:
		push_warning("StateMa: 状态机未运行，已忽略事件")
		return
	_event_queue.append(event_name)


## 直接跳转到指定状态
func go_to(state_name: StringName) -> bool:
	if state_name == &"":
		push_warning("StateMa: 状态名为空，已忽略")
		return false
	if not _running:
		push_warning("StateMa: 状态机未运行，已忽略跳转")
		return false
	return _change_state(state_name)


## 获取当前状态名
func get_current_state() -> StringName:
	return _current_state


## 将对象的信号绑定到事件，信号触发时自动发送事件
func bind_signal_event(emitter: Object, signal_name: StringName, event_name: StringName) -> void:
	if emitter == null:
		push_warning("StateMa: emitter 为空")
		return
	if event_name == &"":
		push_warning("StateMa: 事件名为空")
		return
	if not emitter.has_signal(signal_name):
		push_warning("StateMa: 信号 '%s' 不存在" % String(signal_name))
		return

	# 使用可变参数代理，移除固定参数数量限制
	var err := emitter.connect(signal_name, _on_bound_signal.bind(event_name))
	if err != OK:
		push_warning("StateMa: 绑定信号失败，错误码 %d" % err)

#endregion


#region 生命周期回调 (子类可重写)

## 状态进入时调用
func _on_state_enter(_state: StringName) -> void:
	pass


## 状态更新时每帧调用
func _on_state_update(_state: StringName, _delta: float) -> void:
	pass


## 状态退出时调用
func _on_state_exit(_state: StringName) -> void:
	pass

#endregion


#region 内部逻辑

func _process(delta: float) -> void:
	if not _running or _current_state == &"":
		return

	_invoke_state_update(_current_state, delta)

	# 处理事件队列
	while _running and _current_state != &"" and not _event_queue.is_empty():
		_consume_event(_event_queue.pop_front())


## 消费单个事件
func _consume_event(event_name: StringName) -> void:
	var to_state := _find_transition(_current_state, event_name)
	if to_state == &"":
		push_warning("StateMa: 事件 '%s' 在状态 '%s' 无转换规则" % [String(event_name), String(_current_state)])
		return
	_change_state(to_state)


## 查找转换目标状态
func _find_transition(from_state: StringName, event_name: StringName) -> StringName:
	# 优先查找状态特定转换
	if _transitions.has(from_state):
		var state_map: Dictionary = _transitions[from_state]
		if state_map.has(event_name):
			return state_map[event_name]
	# 再查找全局转换
	return _global_transitions.get(event_name, &"")


## 切换状态
func _change_state(next_state: StringName) -> bool:
	if next_state == _current_state:
		return true
	if not _states.has(next_state):
		push_error("StateMa: 目标状态 '%s' 不存在" % String(next_state))
		return false

	if _current_state != &"":
		_invoke_state_exit(_current_state)

	_current_state = next_state
	_invoke_state_enter(_current_state)
	return true


## 调用状态 enter 回调
func _invoke_state_enter(state: StringName) -> void:
	_on_state_enter(state)
	_call_state_method(state, &"enter")


## 调用状态 update 回调
func _invoke_state_update(state: StringName, delta: float) -> void:
	_on_state_update(state, delta)
	_call_state_method(state, &"update", delta)


## 调用状态 exit 回调
func _invoke_state_exit(state: StringName) -> void:
	_on_state_exit(state)
	_call_state_method(state, &"exit")


## 调用配置中指定的状态方法
func _call_state_method(state: StringName, phase: StringName, delta: float = 0.0) -> void:
	var state_cfg: Dictionary = _states.get(state, {})
	var method_name := _to_sname(state_cfg.get(phase, ""))
	if method_name == &"" or not has_method(method_name):
		return

	var arg_count := _get_method_arg_count(method_name)
	if phase == &"update":
		# update 方法可接受 0~2 个参数: (), (delta), (state, delta)
		match arg_count:
			0: call(method_name)
			1: call(method_name, delta)
			_: call(method_name, state, delta)
	else:
		# enter/exit 方法可接受 0~1 个参数: (), (state)
		if arg_count == 0:
			call(method_name)
		else:
			call(method_name, state)

#endregion


#region 配置加载

## 加载 JSON 配置
func _load_config() -> bool:
	_reset_config()

	if config_path.is_empty():
		push_error("StateMa: config_path 为空")
		return false
	if not FileAccess.file_exists(config_path):
		push_error("StateMa: 配置文件不存在 '%s'" % config_path)
		return false

	var file := FileAccess.open(config_path, FileAccess.READ)
	if file == null:
		push_error("StateMa: 无法打开配置文件，错误码 %d" % FileAccess.get_open_error())
		return false

	var parser := JSON.new()
	var err := parser.parse(file.get_as_text())
	file.close()

	if err != OK:
		push_error("StateMa: JSON 解析失败 - %s (行 %d)" % [parser.get_error_message(), parser.get_error_line()])
		return false
	if not (parser.data is Dictionary):
		push_error("StateMa: 配置根节点必须是对象")
		return false

	return _apply_config(parser.data)


## 应用配置
func _apply_config(config: Dictionary) -> bool:
	# 解析初始状态
	var initial := _to_sname(config.get("initial_state", ""))
	if initial == &"":
		push_error("StateMa: 缺少 initial_state")
		return false

	# 解析状态定义
	var states_cfg: Variant = config.get("states")
	if not (states_cfg is Dictionary) or states_cfg.is_empty():
		push_error("StateMa: states 必须是非空对象")
		return false

	for key in states_cfg.keys():
		var sname := _to_sname(key)
		var sdef: Variant = states_cfg[key]
		if sname == &"" or not (sdef is Dictionary):
			push_error("StateMa: 状态定义无效")
			return false
		if not sdef.has("enter") or not sdef.has("update") or not sdef.has("exit"):
			push_error("StateMa: 状态 '%s' 缺少 enter/update/exit" % String(sname))
			return false
		_states[sname] = {
			"enter": _to_sname(sdef["enter"]),
			"update": _to_sname(sdef["update"]),
			"exit": _to_sname(sdef["exit"])
		}

	if not _states.has(initial):
		push_error("StateMa: 初始状态 '%s' 未定义" % String(initial))
		return false
	_initial_state = initial

	# 解析转换规则
	var trans_cfg: Variant = config.get("transitions")
	if not (trans_cfg is Array):
		push_error("StateMa: transitions 必须是数组")
		return false

	for i in range(trans_cfg.size()):
		var item: Variant = trans_cfg[i]
		if not (item is Dictionary):
			push_error("StateMa: transitions[%d] 必须是对象" % i)
			return false

		var from := _to_sname(item.get("from", ""))
		var event := _to_sname(item.get("event", ""))
		var to := _to_sname(item.get("to", ""))

		if from == &"" or event == &"" or to == &"":
			push_error("StateMa: transitions[%d] 缺少 from/event/to" % i)
			return false
		if from != &"*" and not _states.has(from):
			push_error("StateMa: transitions[%d] from 状态 '%s' 未定义" % [i, String(from)])
			return false
		if not _states.has(to):
			push_error("StateMa: transitions[%d] to 状态 '%s' 未定义" % [i, String(to)])
			return false

		_register_transition(from, event, to)

	return true


## 注册转换规则
func _register_transition(from: StringName, event: StringName, to: StringName) -> void:
	if from == &"*":
		_global_transitions[event] = to
	else:
		if not _transitions.has(from):
			_transitions[from] = {}
		_transitions[from][event] = to


## 重置配置
func _reset_config() -> void:
	_initial_state = &""
	_states.clear()
	_transitions.clear()
	_global_transitions.clear()
	_event_queue.clear()

#endregion


#region 工具方法

## 转换为 StringName
func _to_sname(value: Variant) -> StringName:
	if value is StringName:
		return value
	if value is String and not value.is_empty():
		return StringName(value)
	return &""


## 获取方法参数数量
func _get_method_arg_count(method_name: StringName) -> int:
	for info in get_method_list():
		if _to_sname(info.get("name", "")) == method_name:
			return (info.get("args", []) as Array).size()
	return 0


## 统一的信号代理方法 (Godot 4.5+ 可变参数)
func _on_bound_signal(...args) -> void:
	if args.is_empty():
		return
	emit_event(_to_sname(args[args.size() - 1]))

#endregion
