extends Area3D
@export var current_floor: int = 1  # Which floor this portal is on
@onready var game_state = get_node("/root/GameState")
@onready var snow: GPUParticles3D = $"../../snow"

@onready var world_environment: WorldEnvironment = $"../../WorldEnvironment"
const WORLD_ENVIRONMENT_FLOOR_4_SKYBOX = preload("uid://c8nsgy46ehweg")


var transition_canvas: CanvasLayer
var video_player: VideoStreamPlayer
var title_label: Label

var is_transitioning := false
var gust_sequence_started := false
var gust_audio_player: AudioStreamPlayer
# Floor name lookup
var floor_names := {
	2: "Floor 2 - The Library",
	3: "Floor 3 - The Laboratory",
	4: "Floor 4 - The Lantern"
}

func _ready() -> void:
	transition_canvas = get_node_or_null("/root/TransitionCanvas")
	if transition_canvas:
		video_player = transition_canvas.get_node_or_null("VideoStreamPlayer")
		title_label = transition_canvas.get_node_or_null("Title")
	else:
		push_warning("Portal: TransitionCanvas autoload not found")

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

	# No unlocked floor found - play blocked dialogue based on current floor
	print("Portal: Stairs blocked on floor ", current_floor)
	_play_blocked_dialogue()
	is_transitioning = false


func _play_blocked_dialogue() -> void:
	var dialogue_id: String
	match current_floor:
		1: dialogue_id = "F1StairsBlocked"
		2: dialogue_id = "F2StairsBlocked"
		3: dialogue_id = "F3StairsBlocked"
		_: dialogue_id = "F1StairsBlocked"

	DialogueManager.play(dialogue_id)
	
func _play_transition(next_floor: int, player: Node3D, destination: Vector3) -> void:
	# If no transition canvas, just teleport
	if not transition_canvas or not video_player:
		player.global_transform.origin = destination
		_play_floor_entry_dialogue(next_floor)
		return

	var floor_name = floor_names.get(next_floor, "Floor %d" % next_floor)
	var video_path: String

	# Choose video based on floor
	if next_floor == 4:
		video_path = "res://Video/TransitionExternal.ogv"
		snow.visible = true
		world_environment.set_environment(WORLD_ENVIRONMENT_FLOOR_4_SKYBOX)
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

	# Play floor entry dialogue (first time only)
	_play_floor_entry_dialogue(next_floor)


func _play_floor_entry_dialogue(floor_num: int) -> void:
	var dialogue_id: String
	match floor_num:
		2: dialogue_id = "F2Entry"
		3: dialogue_id = "F3Entry"
		4: dialogue_id = "F4Entry"
		_: return

	# Floor 2 has a special sequence after F2Entry
	if floor_num == 2 and not GameState.has_dialogue_triggered("F2Entry"):
		_play_floor2_entry_sequence()
	else:
		DialogueManager.try_trigger_dialogue(dialogue_id, dialogue_id)


func _play_floor2_entry_sequence() -> void:
	# Play F2Entry dialogue
	if not DialogueManager.play("F2Entry"):
		return

	GameState.mark_dialogue_triggered("F2Entry")

	# Wait for F2Entry to finish, then trigger gust sequence
	var on_finished: Callable
	on_finished = func(entry: Dictionary):
		if entry.get("id", "") == "F2Entry":
			DialogueManager.dialogue_finished.disconnect(on_finished)
			_start_floor2_gust_sequence()

	DialogueManager.dialogue_finished.connect(on_finished)


func _start_floor2_gust_sequence() -> void:
	# Guard against being called multiple times
	if gust_sequence_started:
		return
	gust_sequence_started = true

	# Wait 5 seconds after F2Entry completes
	await get_tree().create_timer(5.0).timeout

	# Create audio player for gust sound if needed
	if not gust_audio_player:
		gust_audio_player = AudioStreamPlayer.new()
		gust_audio_player.bus = "SFX"
		add_child(gust_audio_player)

	# Play the gust sound
	var gust_sound = load("res://Audio/SFX/Floor2/Gust-FINAL.ogg")
	if gust_sound:
		gust_audio_player.stream = gust_sound
		gust_audio_player.play()

	# 10 seconds after gust starts, play F2WindGust dialogue
	await get_tree().create_timer(10.0).timeout

	DialogueManager.try_trigger_dialogue("F2WindGust", "F2WindGust")
