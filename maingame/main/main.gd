extends Node2D

@onready var tutorial_popup: Tut = $UI/TutorialPopup

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	tutorial_popup.start_tutorial()
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
