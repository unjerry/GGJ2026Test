extends Interactable  # 继承自你的交互区域基类

# 重写父类的进入响应方法
func _on_body_entered(player: Player) -> void:
	# 先调用父类方法（注册交互等，根据你的需求可选）
	super._on_body_entered(player)
	print("inter")
	# 调用玩家死亡方法，传入参数 3
	player.die(3)
