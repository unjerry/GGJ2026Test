class_name Enemy
extends CharacterBody2D


var default_gravity := ProjectSettings.get("physics/2d/default_gravity") * 4 as float


@onready var graphics: Node2D = $Graphics
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var state_machine: StateMachine = $StateMachine
@onready var stats: Stats = $Stats
