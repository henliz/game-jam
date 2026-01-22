extends Area3D

@onready var connect_portal: Area3D = get_node("/root/World/Floor4/portal")
@onready var game_state = get_node("/root/GameState")

func _on_body_entered(body: Node3D) -> void:
	if body.name == "Player" and game_state.is_floor_unlocked(2):
		var destination = connect_portal.global_transform.origin
		body.global_transform.origin = destination
