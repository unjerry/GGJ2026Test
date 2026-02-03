class_name Enemy
extends CharacterBody2D


var default_gravity := ProjectSettings.get("physics/2d/default_gravity") as float


@onready var dot: Sprite2D = $Dot
@onready var ring: Sprite2D = $Ring
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var state_machine: StateMachine = $StateMachine


func move(speed: float, delta: float) -> void:
	velocity.y += default_gravity * delta
