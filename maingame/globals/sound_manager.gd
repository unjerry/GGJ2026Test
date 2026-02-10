extends Node

@onready var sfx: Node = $SFX
@onready var bgm: AudioStreamPlayer = $BGM


func play_sfx(name: String) -> void:
	var player := sfx.get_node(name) as AudioStreamPlayer
	if not player:
		return
	player.play()
	

func play_bgm(stream: AudioStream) -> void:
	if bgm.stream == stream and bgm.playing:
		return
	bgm.stream = stream
	bgm.play()


func stop_bgm() -> void:
	bgm.stop()
