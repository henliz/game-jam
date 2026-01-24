extends Area3D

@onready var connect_portal: Area3D = get_node("/root/World/Floor4/portal")
@onready var connect_portal3: Node = get_node("/root/World/Floor3/portal")

@onready var game_state = get_node("/root/GameState")

# TODO
# Cutscene sequence =>
# Determine which floor the player should be going to.
# That tells us which sequence video and title to display
# 
func _on_body_entered(body: Node3D) -> void:
	if body.name == "Player" :
		if game_state.is_floor_unlocked(4):
			# GameStateManager.cutsceneExternal(body, "Floor 4 - The Lantern")
			var destination = connect_portal.global_transform.origin
			body.global_transform.origin = destination
		if game_state.is_floor_unlocked(3):
			# GameStateManager.cutsceneExternal(body, "Floor 3 - The Laboratory")
			var destination = connect_portal.global_transform.origin
			body.global_transform.origin = destination
		elif game_state.is_floor_unlocked(2):
			# GameStateManager.cutsceneExternal(body. "Floor 2 - The Library")
			var destination = connect_portal3.global_transform.origin
			body.global_transform.origin = destination
		else:
			return
		
