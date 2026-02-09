extends Control

@onready var begin: Button = $V/begin
@onready var quit: Button = $V/Quit
@onready var v: VBoxContainer = $V
@onready var animation_player: AnimationPlayer = $AnimationPlayer


var waiting_for_input: bool = true  # 标志位，表示正在等待玩家输入


func _ready() -> void:
	# 初始时隐藏按钮，等待按键
	begin.grab_focus()
	
	# 连接按钮信号
	for button: Button in v.get_children():
		button.mouse_entered.connect(button.grab_focus)


func _unhandled_input(event: InputEvent) -> void:
	# 检测键盘按键或鼠标点击
	var is_valid_key = event is InputEventKey and event.pressed and not event.is_echo()
	var is_mouse_click = event is InputEventMouseButton and event.pressed
	
	if waiting_for_input and (is_valid_key or is_mouse_click):
		# 接受事件，防止传递
		get_tree().root.set_input_as_handled()
		
		begin.disabled = true
		quit.disabled = true
		
		# 停止等待输入
		waiting_for_input = false
		
		# 播放开场动画
		animation_player.play("enter")
		
		# 等待动画结束
		await animation_player.animation_finished
		
		begin.disabled = false
		quit.disabled = false
		
		# 让"开始"按钮获取焦点
		begin.grab_focus()



func _on_begin_pressed() -> void:
	animation_player.play("begin")
	await animation_player.animation_finished
	Game.new_game()


func _on_quit_pressed() -> void:
	get_tree().quit()
