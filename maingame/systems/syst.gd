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
const _TRANSITION_DURATION := 1.0
const _TRANSITION_VIDEO_CANDIDATES := [
	"res://assets/tansphase.ogv",
	"res://assets/tansphase.webm",
	"res://assets/tansphase.mp4",
]

var _mode: Mode = Mode.START
var _game_instance: Node = null
var _menu_instance: Control = null
var _transition_player: VideoStreamPlayer = null
var _transition_timer: Timer = null
var _transition_stream_ready := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_transition_player()
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
	_play_transition()


func _show_restart() -> void:
	_mode = Mode.RESTART
	get_tree().paused = true
	_clear_menu()
	_menu_instance = _spawn_menu(restart)
	_play_transition()


func _start_game(restart_game: bool) -> void:
	_mode = Mode.GAME
	get_tree().paused = false
	_clear_menu()
	if restart_game or _game_instance == null:
		_free_game()
		_game_instance = _spawn_game(game)
	_play_transition()


func _show_pause() -> void:
	if _mode != Mode.GAME:
		return
	_mode = Mode.PAUSE
	get_tree().paused = true
	_menu_instance = _spawn_menu(pause)
	_play_transition()


func _resume_game() -> void:
	if _mode != Mode.PAUSE:
		return
	_mode = Mode.GAME
	get_tree().paused = false
	_clear_menu()
	_play_transition()


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


func _setup_transition_player() -> void:
	_transition_player = VideoStreamPlayer.new()
	_transition_player.name = &"TransitionVideo"
	_transition_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_transition_player.set_anchors_preset(Control.PRESET_FULL_RECT)
	_transition_player.offset_left = 0.0
	_transition_player.offset_top = 0.0
	_transition_player.offset_right = 0.0
	_transition_player.offset_bottom = 0.0
	_transition_player.mouse_filter = Control.MOUSE_FILTER_STOP
	_transition_player.visible = false
	_transition_player.z_index = 1000
	add_child(_transition_player)
	if not _transition_player.finished.is_connected(_on_transition_finished):
		_transition_player.finished.connect(_on_transition_finished)

	_transition_timer = Timer.new()
	_transition_timer.name = &"TransitionTimer"
	_transition_timer.one_shot = true
	_transition_timer.wait_time = _TRANSITION_DURATION
	_transition_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_transition_timer)
	if not _transition_timer.timeout.is_connected(_on_transition_timeout):
		_transition_timer.timeout.connect(_on_transition_timeout)

	for candidate_path in _TRANSITION_VIDEO_CANDIDATES:
		var stream := load(candidate_path) as VideoStream
		if stream == null:
			continue
		_transition_player.stream = stream
		_transition_stream_ready = true
		return

	push_warning("Syst: transition video missing or unsupported. Tried: %s" % ", ".join(_TRANSITION_VIDEO_CANDIDATES))


func _play_transition() -> void:
	if _transition_player == null or not _transition_stream_ready:
		return
	move_child(_transition_player, -1)
	_transition_player.visible = true
	_transition_player.stop()
	_transition_player.play()
	if _transition_timer != null:
		_transition_timer.start(_TRANSITION_DURATION)


func _on_transition_finished() -> void:
	_hide_transition()


func _on_transition_timeout() -> void:
	_hide_transition()


func _hide_transition() -> void:
	if _transition_player == null:
		return
	_transition_player.stop()
	_transition_player.visible = false
	if _transition_timer != null and _transition_timer.time_left > 0.0:
		_transition_timer.stop()


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
