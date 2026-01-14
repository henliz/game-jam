extends Node3D


func _ready() -> void:
	get_tree().create_timer(3.0).timeout.connect(_play_intro)


func _play_intro() -> void:
	DialogueManager.play("intro_welcome")
