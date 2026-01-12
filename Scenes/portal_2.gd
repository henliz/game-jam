extends Area3D

@onready var door: CSGBox3D = $"../Cabin/Door"

func _on_body_entered(body: Node3D) -> void:
	if body.name == "Player":
		door.visible = false
