extends Node

@onready var ball: Sprite2D = $"../Graphics/Ball"
@onready var player: Player = $".."


var spriteArray : Array[Sprite2D]


func _ready() -> void:
	setupSpriteArray()


func setupSpriteArray():
	for i in 20:
		var newSprite : Sprite2D = ball.duplicate()
		newSprite.z_index = 0
		newSprite.modulate.a = 0
		get_tree().root.add_child.call_deferred(newSprite)
		spriteArray.append(newSprite)


func _process(delta: float) -> void:
	
	if player.velocity.x == 0:
		return
	
	if (get_tree().get_frame() % 3) == 0:
		if spriteArray.is_empty() == false:
			var sprite : Sprite2D = spriteArray.pop_front() as Sprite2D
			sprite.global_position = player.global_position
			sprite.scale = player.scale
			sprite.StartFading()
			
			await get_tree().create_timer(0.1).timeout
			spriteArray.append(sprite)
