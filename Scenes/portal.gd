extends Area3D
@onready var connect_portal: Area3D = get_node("/root/World/Floor4/portal")
@onready var connect_portal3: Node = get_node("/root/World/Floor3/portal")
@onready var game_state = get_node("/root/GameState")
@onready var transition_canvas = get_node("/root/World/transition_canvas")
@onready var video_player: VideoStreamPlayer = transition_canvas.get_node("VideoStreamPlayer")
@onready var title_label: Label = transition_canvas.get_node("Title")

var is_transitioning := false

func _on_body_entered(body: Node3D) -> void:
	if body.name == "Player" and not is_transitioning:
		is_transitioning = true
		
		var floor_name: String = ""
		var destination: Vector3
		var video_path: String
		
		# Determine floor, video, and destination
		if game_state.is_floor_unlocked(4):
			floor_name = "Floor 4 - The Lantern"
			video_path = "res://Video/TransitionExternal.ogv"
			destination = connect_portal.global_transform.origin
		elif game_state.is_floor_unlocked(3):
			floor_name = "Floor 3 - The Laboratory"
			video_path = "res://Video/TransitionInternal.ogv"
			destination = connect_portal.global_transform.origin
		elif game_state.is_floor_unlocked(2):
			floor_name = "Floor 2 - The Library"
			video_path = "res://Video/TransitionInternal.ogv"
			destination = connect_portal3.global_transform.origin
		else:
			is_transitioning = false
			return
		
		# Show transition canvas
		transition_canvas.show()
		
		# Set up and play video
		video_player.stream = load(video_path)
		video_player.play()
		
		# Set title but keep invisible
		title_label.text = floor_name
		title_label.modulate.a = 0.0
		
		# Wait 8 seconds then fade in title
		await get_tree().create_timer(8.0).timeout
		var fade_in = create_tween()
		fade_in.tween_property(title_label, "modulate:a", 1.0, 0.8)
		
		# Wait for video to finish
		await video_player.finished
		
		# Fade out title
		var fade_out = create_tween()
		fade_out.tween_property(title_label, "modulate:a", 0.0, 0.5)
		await fade_out.finished
		
		# Hide canvas and teleport player
		transition_canvas.hide()
		body.global_transform.origin = destination
		
		is_transitioning = false
