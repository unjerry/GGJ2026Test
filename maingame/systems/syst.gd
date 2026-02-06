extends Control

@export var game: PackedScene
@export var pause: PackedScene
@export var start: PackedScene
@export var restart: PackedScene

enum Mode {
	START,
	GAME,
	PAUSE,
	RESTART,
}

const _BTN_START := ^"Panel/Button"
const _BTN_SETTING := ^"Panel/Button2"
const _BTN_EXIT := ^"Panel/Button3"

var _mode: Mode = Mode.START
var _game_instance: Node = null
var _menu_instance: Control = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_show_start()


func _unhandled_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	if key_event.keycode != KEY_ESCAPE:
		return

	match _mode:
		Mode.GAME:
			_show_pause()
			get_viewport().set_input_as_handled()
		Mode.PAUSE:
			_resume_game()
			get_viewport().set_input_as_handled()


func _show_start() -> void:
	_mode = Mode.START
	get_tree().paused = false
	_clear_menu()
	_free_game()
	_menu_instance = _spawn_menu(start)


func _show_restart() -> void:
	_mode = Mode.RESTART
	get_tree().paused = true
	_clear_menu()
	_menu_instance = _spawn_menu(restart)


func _start_game(restart_game: bool) -> void:
	_mode = Mode.GAME
	get_tree().paused = false
	_clear_menu()
	if restart_game or _game_instance == null:
		_free_game()
		_game_instance = _spawn_game(game)


func _show_pause() -> void:
	if _mode != Mode.GAME:
		return
	_mode = Mode.PAUSE
	get_tree().paused = true
	_menu_instance = _spawn_menu(pause)


func _resume_game() -> void:
	if _mode != Mode.PAUSE:
		return
	_mode = Mode.GAME
	get_tree().paused = false
	_clear_menu()


func _spawn_game(scene: PackedScene) -> Node:
	if scene == null:
		push_error("Syst: game scene missing.")
		return null

	var instance := scene.instantiate()
	instance.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(instance)
	move_child(instance, 0)
	_try_connect_game_signals(instance)
	return instance


func _spawn_menu(scene: PackedScene) -> Control:
	if scene == null:
		push_error("Syst: menu scene missing.")
		return null

	var instance := scene.instantiate()
	var control := instance as Control
	if control == null:
		push_error("Syst: menu scene root is not Control.")
		instance.queue_free()
		return null

	control.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(control)
	_connect_menu_buttons(control)
	_apply_menu_labels(control)
	return control


func _connect_menu_buttons(menu_root: Control) -> void:
	if menu_root == null:
		return

	var start_btn := menu_root.get_node_or_null(_BTN_START) as Button
	if start_btn != null and not start_btn.pressed.is_connected(_on_menu_start_pressed):
		start_btn.pressed.connect(_on_menu_start_pressed)

	var setting_btn := menu_root.get_node_or_null(_BTN_SETTING) as Button
	if setting_btn != null and not setting_btn.pressed.is_connected(_on_menu_setting_pressed):
		setting_btn.pressed.connect(_on_menu_setting_pressed)

	var exit_btn := menu_root.get_node_or_null(_BTN_EXIT) as Button
	if exit_btn != null and not exit_btn.pressed.is_connected(_on_menu_exit_pressed):
		exit_btn.pressed.connect(_on_menu_exit_pressed)


func _clear_menu() -> void:
	if _menu_instance != null and is_instance_valid(_menu_instance):
		_menu_instance.queue_free()
	_menu_instance = null


func _free_game() -> void:
	if _game_instance != null and is_instance_valid(_game_instance):
		_game_instance.queue_free()
	_game_instance = null


func _try_connect_game_signals(game_root: Node) -> void:
	var player := game_root.get_node_or_null("Player")
	if player != null and player.has_signal("died"):
		if not player.died.is_connected(_on_player_died):
			player.died.connect(_on_player_died)


func _on_menu_start_pressed() -> void:
	match _mode:
		Mode.START:
			_start_game(false)
		Mode.PAUSE:
			_resume_game()
		Mode.RESTART:
			_start_game(true)


func _on_menu_setting_pressed() -> void:
	print("Syst: settings not implemented yet.")


func _on_menu_exit_pressed() -> void:
	if _mode == Mode.PAUSE or _mode == Mode.RESTART:
		_show_start()
		return
	get_tree().quit()


func _on_player_died() -> void:
	if _mode != Mode.GAME:
		return
	_show_restart()


func _apply_menu_labels(menu_root: Control) -> void:
	if menu_root == null:
		return

	var start_btn := menu_root.get_node_or_null(_BTN_START) as Button
	var setting_btn := menu_root.get_node_or_null(_BTN_SETTING) as Button
	var exit_btn := menu_root.get_node_or_null(_BTN_EXIT) as Button

	match _mode:
		Mode.START:
			if start_btn != null:
				start_btn.text = tr("SYS.start")
			if setting_btn != null:
				setting_btn.text = tr("SYS.setting")
			if exit_btn != null:
				exit_btn.text = tr("SYS.exit")
		Mode.PAUSE:
			if start_btn != null:
				start_btn.text = tr("SYS.continue")
			if setting_btn != null:
				setting_btn.text = tr("SYS.setting")
			if exit_btn != null:
				exit_btn.text = tr("SYS.back")
		Mode.RESTART:
			if start_btn != null:
				start_btn.text = tr("SYS.restart")
			if setting_btn != null:
				setting_btn.text = tr("SYS.setting")
			if exit_btn != null:
				exit_btn.text = tr("SYS.back")
