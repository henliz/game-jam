extends Area3D
@export var current_floor: int
@onready var game_state = get_node("/root/GameState")
@onready var snow: GPUParticles3D = $"../../snow"

@onready var world_environment: WorldEnvironment = $"../../WorldEnvironment"
const WORLD_ENVIRONMENT_FLOOR_4_SKYBOX = preload("uid://c8nsgy46ehweg")

@onready var portal_visual: Node3D = $PortalVisual
@onready var music_player: AudioStreamPlayer = get_node_or_null("/root/Main/World/AudioStreamPlayers/MusicStreamPlayer")

const FLOOR_MUSIC := {
	1: "res://Audio/Music/Floor01_OST.mp3",
	2: "res://Audio/Music/Floor2_OST.mp3",
	3: "res://Audio/Music/Floor3_OST.mp3",
	4: "res://Audio/Music/Floor4_OST.mp3",
}

var transition_canvas: CanvasLayer
var video_player: VideoStreamPlayer
var title_label: Label

var is_transitioning := false
var gust_sequence_started := false
var gust_audio_player: AudioStreamPlayer

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

func _process(_delta: float) -> void:
	if portal_visual.visible and game_state.is_floor_unlocked(current_floor+1):
		portal_visual.visible=false

func _on_body_entered(body: Node3D) -> void:
	if body.name != "Player" or is_transitioning:
		return

	is_transitioning = true
	print(current_floor)
	# Find the next unlocked floor with an arrival marker
	for next_floor in range(current_floor + 1, 5):
		if not game_state.is_floor_unlocked(next_floor):
			continue
		var arrival_path = "/root/Main/World/Floor%d/arrival" % next_floor
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

	# Disable player input during transition
	_set_player_input_enabled(player, false)

	var floor_name = floor_names.get(next_floor, "Floor %d" % next_floor)
	var video_path: String

	# Choose video based on floor
	if next_floor == 4:
		video_path = "res://Video/TransitionExternal.ogv"
		snow.visible = true
		world_environment.set_environment(WORLD_ENVIRONMENT_FLOOR_4_SKYBOX)
	else:
		video_path = "res://Video/TransitionInternal.ogv"

	# Switch to the new floor's music
	_switch_floor_music(next_floor)

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

	# Re-enable player input after transition
	_set_player_input_enabled(player, true)

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

	# Start the building sway effect (runs concurrently)
	_animate_floor2_sway()

	# 10 seconds after gust starts, play F2WindGust dialogue
	await get_tree().create_timer(10.0).timeout

	DialogueManager.try_trigger_dialogue("F2WindGust", "F2WindGust")


func _animate_floor2_sway() -> void:
	var floor2 = get_node_or_null("/root/Main/World/Floor2")
	var floor2_interactables = get_node_or_null("/root/Main/World/Floor2Interactables")
	var sphere_puzzle = get_node_or_null("/root/Main/World/SpherePuzzle")

	if not floor2 and not floor2_interactables:
		return

	# Store original transforms
	var floor2_orig_pos = floor2.position if floor2 else Vector3.ZERO
	var floor2_orig_rot = floor2.rotation if floor2 else Vector3.ZERO
	var interactables_orig_pos = floor2_interactables.position if floor2_interactables else Vector3.ZERO
	var sphere_puzzle_orig_pos = sphere_puzzle.position if sphere_puzzle else Vector3.ZERO

	# Sway parameters
	var sway_duration := 9.0  # 3s to 12s = 9 seconds of movement
	var start_time := 3.0
	var peak_time := 7.5  # Peak intensity

	# Wait for the effect to start (3 seconds into the sound)
	await get_tree().create_timer(start_time).timeout

	var elapsed := 0.0
	var max_pos_offset := 0.04  # Max position sway
	var max_rot_offset := 0.008  # Max rotation sway (radians)

	while elapsed < sway_duration:
		var delta = get_process_delta_time()
		elapsed += delta

		# Calculate intensity envelope: ramp up, peak, ramp down
		var progress = elapsed / sway_duration
		var intensity: float
		var peak_progress = (peak_time - start_time) / sway_duration

		if progress < peak_progress:
			# Ramp up to peak
			intensity = progress / peak_progress
		else:
			# Ramp down from peak
			intensity = 1.0 - ((progress - peak_progress) / (1.0 - peak_progress))

		intensity = clamp(intensity, 0.0, 1.0)
		intensity = intensity * intensity  # Ease in/out

		# Create organic sway using multiple sine waves
		var time = elapsed * 2.5
		var sway_x = sin(time * 1.3) * 0.6 + sin(time * 2.7) * 0.4
		var sway_z = cos(time * 1.1) * 0.5 + cos(time * 2.3) * 0.5
		var rot_x = sin(time * 1.5) * 0.7 + sin(time * 3.1) * 0.3
		var rot_z = cos(time * 1.7) * 0.6 + cos(time * 2.9) * 0.4

		var pos_offset = Vector3(sway_x, 0, sway_z) * max_pos_offset * intensity
		var rot_offset = Vector3(rot_x, 0, rot_z) * max_rot_offset * intensity

		if floor2:
			floor2.position = floor2_orig_pos + pos_offset
			floor2.rotation = floor2_orig_rot + rot_offset

		if floor2_interactables:
			floor2_interactables.position = interactables_orig_pos + pos_offset * 1.2

		if sphere_puzzle:
			sphere_puzzle.position = sphere_puzzle_orig_pos + pos_offset * 1.2

		await get_tree().process_frame

	# Restore original transforms
	if floor2:
		floor2.position = floor2_orig_pos
		floor2.rotation = floor2_orig_rot
	if floor2_interactables:
		floor2_interactables.position = interactables_orig_pos
	if sphere_puzzle:
		sphere_puzzle.position = sphere_puzzle_orig_pos


func _switch_floor_music(floor_num: int) -> void:
	if not music_player:
		return

	var music_path = FLOOR_MUSIC.get(floor_num, "")
	if music_path.is_empty():
		return

	var new_music = load(music_path)
	if not new_music:
		return

	# Crossfade to new music
	var original_volume = music_player.volume_db
	var fade_tween = create_tween()
	fade_tween.tween_property(music_player, "volume_db", -40.0, 1.0)
	await fade_tween.finished

	music_player.stream = new_music
	music_player.play()

	var fade_in = create_tween()
	fade_in.tween_property(music_player, "volume_db", original_volume, 1.5)


func _set_player_input_enabled(player: Node3D, enabled: bool) -> void:
	if not player:
		return
	# Disable/enable movement
	if "movement_enabled" in player:
		player.movement_enabled = enabled
	# Disable/enable camera look by setting inspecting (inspecting=true blocks camera input)
	if "inspecting" in player:
		player.inspecting = not enabled
