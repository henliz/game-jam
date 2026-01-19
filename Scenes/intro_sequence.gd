extends CanvasLayer

signal intro_complete

const INTRO_SECTIONS := [
	"Your story begins, as some stories do, in the winter.\nThough this is no ordinary winter - and yours is no ordinary task.",
	"You play as an adventurer, hired by the people of a cursed land to investigate their local wizard's tower.\nThe isolated spire normally cuts through the cold with it's bright light, bringing forth spring.\nBut the beacon has not shone for some time now, it's keeper nowhere to be seen. The world is locked into a seemingly limitless whiteout.",
	"Cold and afraid, the local populace has hired you to investigate, lest they succumb to the elements.\nTired from a string of unfortunate misadadventures, you arrive at the doorstep..."
]

const SECTION_FADE_TIMES := [0.0, 12.0, 28.0]
const SECTION_FADE_DURATION := 2.0
const TEXT_HIDE_TIME := 45.0
const SCENE_FADE_IN_TIME := 55.0
const MOVEMENT_ENABLE_TIME := 65.0  # Return movement first
const CAMERA_ENABLE_TIME := 65.0    # Return camera at same time as movement
const CLEANUP_TIME := 72.0  # Time to actually destroy the sequence (after captions finish)
const SKIP_HOLD_TIME := 2.5

# these are here because the Level 1 Entry voiceover is now contained inside the intro sequence audio, so instead of utilizing a normal dialogue trigger, I've opted
# to simply hardcode the caption timings here. 
const INTRO_CAPTIONS := [
	{"time": 50.0, "text": "That was NOT a short walk. I thought I was going to lose a finger out there."},
	{"time": 55.0, "text": "At least this place is hard to miss."},
	{"time": 60.0, "text": "The energy here feels… strange... Hello? Anyone home? Of course not."},
	{"time": 69.0, "text": ""}  # Empty text signals hide caption
]

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
var camera_returned := false
var movement_returned := false
var cleanup_done := false
var player: CharacterBody3D = null
var skip_hold_progress := 0.0
var skip_stage := 0  # 0 = skip to text hide, 1 = skip to end
var skip_cooldown := 0.0
const SKIP_STAGE_DELAY := 3.0
var current_caption_index := 0
var current_section_index := 0
var section_labels: Array[Label] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	black_overlay.modulate.a = 0.0
	intro_text.modulate.a = 0.0
	intro_text.text = ""
	_setup_section_labels()


func _setup_section_labels() -> void:
	# Create a label for each intro section, stacked vertically
	for i in INTRO_SECTIONS.size():
		var label = Label.new()
		label.text = INTRO_SECTIONS[i]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		label.modulate.a = 0.0

		label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 1))
		label.add_theme_font_size_override("font_size", 24)

		section_labels.append(label)

	# Use VBoxContainer to stack sections vertically
	var container = VBoxContainer.new()
	container.name = "SectionContainer"
	container.anchors_preset = Control.PRESET_CENTER
	container.anchor_left = 0.5
	container.anchor_top = 0.5
	container.anchor_right = 0.5
	container.anchor_bottom = 0.5
	container.offset_left = -600
	container.offset_top = -300
	container.offset_right = 600
	container.offset_bottom = 300
	container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	container.grow_vertical = Control.GROW_DIRECTION_BOTH
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_theme_constant_override("separation", 30)

	for label in section_labels:
		container.add_child(label)

	black_overlay.add_child(container)
	intro_text.visible = false  # Hide original label


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
		player.inspecting = true  # Disable camera look during intro

	intro_audio.play()
	text_visible = true
	# First section fades in immediately, start tracking from section 1
	_fade_in_section(0)
	current_section_index = 1


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
	elif not cleanup_done:
		# Audio finished - ensure all events trigger by setting time past all thresholds
		elapsed_time = CLEANUP_TIME + 1.0

	# Handle sequential section fade-in
	_update_text_sections()

	# Hide all text at TEXT_HIDE_TIME
	if text_visible and elapsed_time >= TEXT_HIDE_TIME:
		_hide_all_sections()
		text_visible = false

	# Handle skip cooldown between stages
	if skip_cooldown > 0:
		skip_cooldown -= delta
		if skip_cooldown <= 0 and skip_stage == 1 and not movement_returned:
			skip_container.visible = true

	# Handle timed captions
	_update_captions()

	if not scene_revealed and elapsed_time >= SCENE_FADE_IN_TIME:
		print("[INTRO] %.1fs - Scene fade in started" % elapsed_time)
		scene_revealed = true
		var reveal_tween = create_tween()
		reveal_tween.tween_property(black_overlay, "modulate:a", 0.0, 2.0)

	# Return camera control after scene fades in
	if not camera_returned and elapsed_time >= CAMERA_ENABLE_TIME:
		print("[INTRO] %.1fs - CAMERA RETURNED (inspecting=false, mouse captured)" % elapsed_time)
		camera_returned = true
		if player:
			player.inspecting = false  # Re-enable camera look
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			print("[INTRO] WARNING: player is null when returning camera!")

	# Enable movement but don't destroy the sequence yet
	if not movement_returned and elapsed_time >= MOVEMENT_ENABLE_TIME:
		print("[INTRO] %.1fs - MOVEMENT RETURNED" % elapsed_time)
		movement_returned = true
		if player:
			player.movement_enabled = true
		else:
			print("[INTRO] WARNING: player is null when returning movement!")

	# Cleanup after captions finish (separate from movement enabling)
	if not cleanup_done and elapsed_time >= CLEANUP_TIME:
		print("[INTRO] %.1fs - CLEANUP triggered" % elapsed_time)
		cleanup_done = true
		_mark_intro_complete()
		_cleanup_sequence()


func _fade_in_section(index: int) -> void:
	if index < 0 or index >= section_labels.size():
		return
	var tween = create_tween()
	tween.tween_property(section_labels[index], "modulate:a", 1.0, SECTION_FADE_DURATION)


func _update_text_sections() -> void:
	# Check if we need to fade in the next section
	if current_section_index >= SECTION_FADE_TIMES.size():
		return

	if elapsed_time >= SECTION_FADE_TIMES[current_section_index]:
		_fade_in_section(current_section_index)
		current_section_index += 1


func _hide_all_sections() -> void:
	for label in section_labels:
		label.modulate.a = 0.0


func _cleanup_sequence() -> void:
	print("[INTRO] _cleanup_sequence called - camera_returned=%s, movement_returned=%s" % [camera_returned, movement_returned])
	# Ensure caption is hidden before cleanup
	DialogueManager.caption_ui.hide_caption()

	# Safety: ensure player has full control restored
	if player:
		if not camera_returned:
			print("[INTRO] SAFETY: Restoring camera control in cleanup!")
			player.inspecting = false
		if not movement_returned:
			print("[INTRO] SAFETY: Restoring movement in cleanup!")
			player.movement_enabled = true
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		print("[INTRO] WARNING: player is null in cleanup!")

	print("[INTRO] Sequence complete, calling queue_free()")
	queue_free()


func _update_captions() -> void:
	if current_caption_index >= INTRO_CAPTIONS.size():
		return

	var caption = INTRO_CAPTIONS[current_caption_index]
	if elapsed_time >= caption["time"]:
		var caption_text: String = caption["text"]
		if caption_text.is_empty():
			print("[INTRO] %.1fs - Caption %d: HIDE" % [elapsed_time, current_caption_index])
			DialogueManager.caption_ui.hide_caption()
		else:
			print("[INTRO] %.1fs - Caption %d: '%s'" % [elapsed_time, current_caption_index, caption_text.substr(0, 30)])
			DialogueManager.caption_ui.show_caption("", caption_text)
		current_caption_index += 1


func _handle_skip_input(delta: float) -> void:
	# Don't process skip input during cooldown
	if skip_cooldown > 0:
		return

	if Input.is_action_pressed("jump"):
		skip_hold_progress += delta / SKIP_HOLD_TIME
		skip_gauge.set_value(skip_hold_progress)

		if skip_hold_progress >= 1.0:
			_skip_intro()
	else:
		skip_hold_progress = maxf(0.0, skip_hold_progress - delta * 2.0)
		skip_gauge.set_value(skip_hold_progress)


func _skip_intro() -> void:
	skip_hold_progress = 0.0
	skip_gauge.set_value(0.0)

	if skip_stage == 0:
		# Stage 0: Skip to first caption (50s) - skip past exposition text
		intro_audio.seek(INTRO_CAPTIONS[0]["time"])
		_hide_all_sections()
		text_visible = false
		current_section_index = SECTION_FADE_TIMES.size()  # Prevent more sections from fading in
		skip_container.visible = false
		skip_stage = 1
		skip_cooldown = SKIP_STAGE_DELAY
	else:
		# Stage 1: Skip to end
		intro_audio.stop()
		skip_container.visible = false
		DialogueManager.caption_ui.hide_caption()
		current_caption_index = INTRO_CAPTIONS.size()

		if not scene_revealed:
			scene_revealed = true
			black_overlay.modulate.a = 0.0

		camera_returned = true
		movement_returned = true
		if player:
			player.inspecting = false
			player.movement_enabled = true
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		_mark_intro_complete()
		cleanup_done = true
		_cleanup_sequence()


func _mark_intro_complete() -> void:
	GameState.mark_dialogue_triggered("VO_F1_ENTRY")
	sequence_running = false
	intro_complete.emit()
	# Note: queue_free() is now called separately via _cleanup_sequence() at CLEANUP_TIME
