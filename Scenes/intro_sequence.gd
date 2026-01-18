extends CanvasLayer

signal intro_complete

const INTRO_TEXT := """Your story begins, as some stories do, in the winter.
Though this is no ordinary winter - and yours is no ordinary task.

You play as an adventurer, hired by the people of a cursed land to investigate their local wizard's tower.
The isolated spire normally cuts through the cold with it’s bright light, bringing forth spring.
But the beacon has not shone for some time now, it's keeper nowhere to be seen. The world is locked into a seemingly limitless whiteout.

Cold and afraid, the local populace has hired you to investigate, lest they succumb to the elements.
Tired from a string of unfortunate misadadventures, you arrive at the doorstep..."""



const TEXT_FADE_IN_TIME := 0.0
const TEXT_HIDE_TIME := 45.0
const SCENE_FADE_IN_TIME := 55.0
const MOVEMENT_ENABLE_TIME := 65.0
const INTRO_END_TIME := 83.0
const SKIP_HOLD_TIME := 4.0

@onready var black_overlay: ColorRect = $BlackOverlay
@onready var intro_text: Label = $BlackOverlay/IntroText
@onready var click_sound: AudioStreamPlayer = $ClickSound
@onready var intro_audio: AudioStreamPlayer = $IntroAudio
@onready var skip_container: HBoxContainer = $BlackOverlay/SkipContainer
@onready var skip_gauge: Control = $BlackOverlay/SkipContainer/SkipGauge

var sequence_running := false
var elapsed_time := 0.0
var text_visible := false
var scene_revealed := false
var movement_returned := false
var player: CharacterBody3D = null
var skip_hold_progress := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	black_overlay.modulate.a = 0.0
	intro_text.modulate.a = 0.0
	intro_text.text = INTRO_TEXT


func start_sequence() -> void:
	visible = true
	sequence_running = true
	elapsed_time = 0.0
	text_visible = false
	scene_revealed = false
	movement_returned = false

	click_sound.play()
	black_overlay.modulate.a = 1.0
	call_deferred("_on_fade_to_black_complete")


func _on_fade_to_black_complete() -> void:
	get_tree().change_scene_to_file("res://Scenes/world.tscn")
	_waiting_for_scene = true


func _try_find_player() -> bool:
	# Try to find player - returns true if found
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


var _waiting_for_scene := false

func _on_scene_loaded() -> void:
	_waiting_for_scene = false

	if player:
		player.movement_enabled = false

	intro_audio.play()

	var text_tween = create_tween()
	text_tween.tween_property(intro_text, "modulate:a", 1.0, 2.0)
	text_visible = true


func _process(delta: float) -> void:
	# If waiting for scene to load, check each frame
	if _waiting_for_scene:
		if _try_find_player():
			_on_scene_loaded()
		return

	if not sequence_running:
		return

	# Handle skip input
	_handle_skip_input(delta)

	if intro_audio.playing:
		elapsed_time = intro_audio.get_playback_position()
	else:
		# Audio finished - ensure all events trigger
		elapsed_time = INTRO_END_TIME

	if text_visible and elapsed_time >= TEXT_HIDE_TIME and intro_text.modulate.a > 0:
		intro_text.modulate.a = 0.0
		text_visible = false

	if not scene_revealed and elapsed_time >= SCENE_FADE_IN_TIME:
		scene_revealed = true
		var reveal_tween = create_tween()
		reveal_tween.tween_property(black_overlay, "modulate:a", 0.0, 2.0)

	if not movement_returned and elapsed_time >= MOVEMENT_ENABLE_TIME:
		movement_returned = true
		if player:
			player.movement_enabled = true
		_mark_intro_complete()


func _handle_skip_input(delta: float) -> void:
	if Input.is_action_pressed("jump"):
		skip_hold_progress += delta / SKIP_HOLD_TIME
		skip_gauge.set_value(skip_hold_progress)

		if skip_hold_progress >= 1.0:
			_skip_intro()
	else:
		skip_hold_progress = maxf(0.0, skip_hold_progress - delta * 2.0)
		skip_gauge.set_value(skip_hold_progress)


func _skip_intro() -> void:
	intro_audio.stop()
	intro_text.modulate.a = 0.0
	text_visible = false
	skip_container.visible = false

	if not scene_revealed:
		scene_revealed = true
		black_overlay.modulate.a = 0.0

	movement_returned = true
	if player:
		player.movement_enabled = true
	_mark_intro_complete()


func _mark_intro_complete() -> void:
	GameState.mark_dialogue_triggered("VO_F1_ENTRY")
	sequence_running = false
	intro_complete.emit()
	queue_free()
