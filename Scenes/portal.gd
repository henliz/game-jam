extends Area3D
@export var current_floor: int = 1  # Which floor this portal is on
@onready var game_state = get_node("/root/GameState")
@onready var transition_canvas = get_node("/root/TransitionCanvas")  # CHANGED - removed /World/
@onready var video_player: VideoStreamPlayer = transition_canvas.get_node("VideoStreamPlayer")
@onready var title_label: Label = transition_canvas.get_node("Title")
var is_transitioning := false
# Floor name lookup
var floor_names := {
	2: "Floor 2 - The Library",
	3: "Floor 3 - The Laboratory",
	4: "Floor 4 - The Lantern"
}
func _on_body_entered(body: Node3D) -> void:
	if body.name != "Player" or is_transitioning:
		return
	
	is_transitioning = true
	
	# Find the next unlocked floor with an arrival marker
	for next_floor in range(current_floor + 1, 5):
		if not game_state.is_floor_unlocked(next_floor):
			continue
		
		var arrival_path = "/root/World/Floor%d/arrival" % next_floor
		var arrival_marker = get_node_or_null(arrival_path)
		
		if arrival_marker:
			print("Portal: Traveling from floor ", current_floor, " to floor ", next_floor)
			await _play_transition(next_floor, body, arrival_marker.global_transform.origin)
			is_transitioning = false
			return
	
	print("Portal: No unlocked floor with arrival marker found above floor ", current_floor)
	is_transitioning = false
func _play_transition(next_floor: int, player: Node3D, destination: Vector3) -> void:
	var floor_name = floor_names.get(next_floor, "Floor %d" % next_floor)
	var video_path: String
	
	# Choose video based on floor
	if next_floor == 4:
		video_path = "res://Video/TransitionExternal.ogv"
	else:
		video_path = "res://Video/TransitionInternal.ogv"
	
	# Show transition canvas
	transition_canvas.show()
	
	# Set up and play video
	video_player.stream = load(video_path)
	video_player.play()
	
	# Set title but keep invisible
	title_label.text = floor_name
	title_label.modulate.a = 0.0
	
	# Teleport player immediately (happens behind the video)
	player.global_transform.origin = destination
	
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
	
	# Hide canvas
	transition_canvas.hide()
