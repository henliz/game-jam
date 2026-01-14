extends Node3D


func _ready() -> void:
	get_tree().create_timer(3.0).timeout.connect(_play_intro)


func _play_intro() -> void:
	DialogueManager.play("intro_welcome")
	ScreenEffects.apply_cold_effect(1.0, 0.5)  # full intensity, 0.5s fade-in
