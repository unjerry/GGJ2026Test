extends Node2D

@onready var player: CharacterBody2D = $Node2D/Player
@onready var camera_2d: Camera2D = $Node2D/Player/Camera2D
@onready var right_wall: StaticBody2D = $Node2D/RightWall
@onready var left_wall: StaticBody2D = $Node2D/LeftWall


func _ready() -> void:
	camera_2d.reset_smoothing()


var can_move := true


func _physics_process(delta: float) -> void:
	if player.global_position.x > 250:
		camera_2d.limit_right = 500
		camera_2d.limit_left = 116
		right_wall.global_position.x = 116
		left_wall.global_position.x = 500
		
	if not can_move:
		if player and camera_2d:
			camera_2d.global_position.x = 193
	
