extends CanvasLayer

signal intro_complete

const INTRO_TEXT := """Your story begins, as some stories do, in the winter.
Though this is no ordinary winter - and yours is no ordinary task.

You play as an adventurer, hired by the people of a cursed land to investigate their local wizard's tower.
The isolated spire normally cuts through the cold with its bright light, bringing forth spring.
But the beacon has not shone for some time now, its keeper nowhere to be seen...

The world is locked into a seemingly limitless whiteout.

Cold and afraid, the local populace has hired you to investigate, lest they succumb to the elements.
Tired from a string of unfortunate misadventures, you arrive at the doorstep..."""

const CLICK_TO_CONTINUE_TEXT := "Click to continue..."
const SKIP_HOLD_TIME := 2.5

@onready var black_overlay: ColorRect = $BlackOverlay
@onready var intro_text: Label = $BlackOverlay/IntroText
@onready var click_to_continue: Label = $BlackOverlay/ClickToContinue
@onready var click_sound: AudioStreamPlayer = $ClickSound
@onready var video_player: VideoStreamPlayer = $OpeningCredits
@onready var skip_container: HBoxContainer = $SkipContainer
@onready var skip_gauge: Control = $SkipContainer/SkipGauge

var player: CharacterBody3D = null
var showing_text := true
var video_playing := false
var _waiting_for_scene := false
var skip_hold_progress := 0.0
var can_click := false  # Prevent immediate click-through
var music_player: AudioStreamPlayer = null
var music_fade_started := false
const MUSIC_FADE_START_TIME := 62.0  # 1:02 into video
const MUSIC_FADE_END_TIME := 68.0    # 1:08 into video
const MUSIC_DEFAULT_VOLUME := 0.0    # Default volume in dB

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	black_overlay.modulate.a = 1.0
	intro_text.modulate.a = 0.0
	click_to_continue.modulate.a = 0.0
	skip_container.visible = false
	can_click = false
	
	# Setup intro text label
	intro_text.text = INTRO_TEXT
	intro_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	intro_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	
	# Setup click to continue label
	click_to_continue.text = CLICK_TO_CONTINUE_TEXT
	click_to_continue.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Setup video player
	video_player.visible = false
	video_player.finished.connect(_on_video_finished)

func start_sequence() -> void:
	visible = true
	showing_text = true
	video_playing = false
	skip_hold_progress = 0.0
	can_click = false
	
	click_sound.play()
	black_overlay.modulate.a = 1.0
	call_deferred("_on_fade_to_black_complete")

func _on_fade_to_black_complete() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_waiting_for_scene = true

func _try_find_player() -> bool:
	player = get_tree().get_first_node_in_group("player")
	if player:
		return true
	
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
		return true
	
	var current = get_tree().current_scene
	if current:
		player = current.find_child("Player", true, false)
		if player:
			return true
	
	return false

func _on_scene_loaded() -> void:
	_waiting_for_scene = false

	if player:
		player.movement_enabled = false
		player.inspecting = true

	# Get reference to the music player
	music_player = get_node_or_null("/root/Main/World/AudioStreamPlayers/MusicStreamPlayer")

	# Fade in the intro text
	var fade_tween = create_tween()
	fade_tween.tween_property(intro_text, "modulate:a", 1.0, 1.0)
	fade_tween.tween_property(click_to_continue, "modulate:a", 1.0, 0.5)
	fade_tween.finished.connect(func(): can_click = true)  # Enable clicking after fade completes

func _process(delta: float) -> void:
	# Wait for scene to load
	if _waiting_for_scene:
		if _try_find_player():
			_on_scene_loaded()
		return
	
	# Handle click to continue (only when showing text AND clicking is enabled)
	if showing_text and can_click:
		if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_select"):
			_start_video()
		# Check for mouse click (but only once per click)
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			if not _mouse_was_pressed:
				_start_video()
			_mouse_was_pressed = true
		else:
			_mouse_was_pressed = false
	
	# Handle skip input during video
	if video_playing:
		_handle_skip_input(delta)
		_handle_music_fade()

var _mouse_was_pressed := false


func _handle_music_fade() -> void:
	if not music_player or music_fade_started:
		return

	var playback_time = video_player.stream_position
	if playback_time >= MUSIC_FADE_START_TIME:
		music_fade_started = true
		var fade_duration = MUSIC_FADE_END_TIME - MUSIC_FADE_START_TIME
		var tween = create_tween()
		tween.tween_property(music_player, "volume_db", MUSIC_DEFAULT_VOLUME, fade_duration)

func _start_video() -> void:
	if video_playing or not can_click:
		return

	showing_text = false
	video_playing = true
	can_click = false
	music_fade_started = false
	click_sound.play()

	# Mute the background music when video starts
	if music_player:
		music_player.volume_db = -80.0

	# Fade out text
	var fade_tween = create_tween()
	fade_tween.tween_property(intro_text, "modulate:a", 0.0, 0.5)
	fade_tween.tween_property(click_to_continue, "modulate:a", 0.0, 0.5)
	fade_tween.tween_callback(_play_video)

func _play_video() -> void:
	# Hide black overlay, show video and skip container
	black_overlay.visible = false
	video_player.visible = true
	skip_container.visible = true
	video_player.play()
	
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _handle_skip_input(delta: float) -> void:
	if Input.is_action_pressed("skip"):
		skip_hold_progress += delta / SKIP_HOLD_TIME
		skip_gauge.set_value(skip_hold_progress)
		
		if skip_hold_progress >= 1.0:
			_skip_video()
	else:
		skip_hold_progress = maxf(0.0, skip_hold_progress - delta * 2.0)
		skip_gauge.set_value(skip_hold_progress)

func _skip_video() -> void:
	skip_hold_progress = 0.0
	skip_gauge.set_value(0.0)
	video_player.stop()
	skip_container.visible = false
	_on_video_finished()

func _on_video_finished() -> void:
	skip_container.visible = false

	# Ensure music is restored to default volume (in case video was skipped)
	if music_player:
		music_player.volume_db = MUSIC_DEFAULT_VOLUME

	if player:
		player.inspecting = false
		player.movement_enabled = true

	GameState.mark_dialogue_triggered("VO_F1_ENTRY")
	intro_complete.emit()
	queue_free()
