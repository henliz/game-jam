class_name JournalUI
extends CanvasLayer

signal journal_opened
signal journal_closed
signal page_changed(spread_index: int)

@export_group("Spreads")
@export var spread_textures: Array[Texture2D] = []

@export_group("Animation")
@export var fade_duration: float = 0.3

@export_group("Audio")
@export var open_sound: AudioStream
@export var close_sound: AudioStream
@export var page_turn_sounds: Array[AudioStream] = []

@export_group("Dialogue")
@export var first_open_dialogue_id: String = "journal_first_open"

var is_open: bool = false
var current_spread: int = 0
var total_spreads: int = 3

@onready var background: ColorRect = $Background
@onready var journal_container: Control = $JournalContainer
@onready var spread_display: TextureRect = $JournalContainer/SpreadDisplay
@onready var audio_player: AudioStreamPlayer = $AudioPlayer

# Page content containers (for future text overlays)
@onready var left_page_content: Control = $JournalContainer/SpreadDisplay/LeftPageContent
@onready var right_page_content: Control = $JournalContainer/SpreadDisplay/RightPageContent

# Tab buttons for quick navigation
@onready var tab_buttons: Control = $JournalContainer/SpreadDisplay/TabButtons


func _ready() -> void:
	layer = 100
	# Keep node processing but hide visually
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	background.modulate.a = 0.0
	journal_container.modulate.a = 0.0

	_setup_spread_textures()
	_setup_audio()
	_update_spread_display()


func _setup_spread_textures() -> void:
	if spread_textures.is_empty():
		# Load default textures if none assigned in editor
		var spread1 = load("res://resource/UI/Journal/ART_UI_JOURNAL_Spread_01_BlankPages_WIP_TEST.png")
		var spread2 = load("res://resource/UI/Journal/ART_UI_JOURNAL_Spread_02_BlankPages_WIP_TEST.png")
		var spread3 = load("res://resource/UI/Journal/ART_UI_JOURNAL_Spread_03_BlankPages_WIP_TEST.png")

		if spread1:
			spread_textures.append(spread1)
		if spread2:
			spread_textures.append(spread2)
		if spread3:
			spread_textures.append(spread3)

	total_spreads = spread_textures.size()


func _setup_audio() -> void:
	if not open_sound:
		open_sound = load("res://Audio/SFX/UI/JOURNAL_OPEN.wav")
	if not close_sound:
		close_sound = load("res://Audio/SFX/UI/JOURNAL_CLOSE.wav")
	if page_turn_sounds.is_empty():
		var page1 = load("res://Audio/SFX/UI/JOURNAL_PAGE_1.wav")
		if page1:
			page_turn_sounds.append(page1)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("journal"):
		# Don't open journal during item inspection
		if not is_open and _is_player_inspecting():
			return
		toggle_journal()
		get_viewport().set_input_as_handled()
		return

	if not is_open:
		return

	# Page navigation - A/Left for previous, D/Right for next
	if event.is_action_pressed("left") or (event is InputEventKey and event.pressed and event.keycode == KEY_LEFT):
		turn_page_left()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("right") or (event is InputEventKey and event.pressed and event.keycode == KEY_RIGHT):
		turn_page_right()
		get_viewport().set_input_as_handled()

	# ESC to close
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close_journal()
		get_viewport().set_input_as_handled()


func _is_player_inspecting() -> bool:
	var player = get_tree().get_first_node_in_group("player")
	if player and "inspecting" in player:
		return player.inspecting
	return false


func toggle_journal() -> void:
	if is_open:
		close_journal()
	else:
		open_journal()


func open_journal() -> void:
	if is_open:
		return

	is_open = true
	visible = true

	_play_sound(open_sound)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(background, "modulate:a", 0.7, fade_duration)
	tween.tween_property(journal_container, "modulate:a", 1.0, fade_duration)

	# Pause game and show cursor
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	_on_first_open()
	journal_opened.emit()


func _on_first_open() -> void:
	if first_open_dialogue_id:
		DialogueManager.try_trigger_dialogue("journal_first_open", first_open_dialogue_id)


func close_journal() -> void:
	if not is_open:
		return

	_play_sound(close_sound)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(background, "modulate:a", 0.0, fade_duration)
	tween.tween_property(journal_container, "modulate:a", 0.0, fade_duration)
	tween.set_parallel(false)
	tween.tween_callback(_on_close_complete)


func _on_close_complete() -> void:
	is_open = false
	visible = false

	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	journal_closed.emit()


func turn_page_left() -> void:
	if current_spread > 0:
		current_spread -= 1
		_animate_page_turn(-1)
		_play_random_page_sound()
		page_changed.emit(current_spread)


func turn_page_right() -> void:
	if current_spread < total_spreads - 1:
		current_spread += 1
		_animate_page_turn(1)
		_play_random_page_sound()
		page_changed.emit(current_spread)


func go_to_spread(index: int) -> void:
	if index >= 0 and index < total_spreads and index != current_spread:
		var direction = 1 if index > current_spread else -1
		current_spread = index
		_animate_page_turn(direction)
		_play_random_page_sound()
		page_changed.emit(current_spread)


func _animate_page_turn(_direction: int) -> void:
	var tween = create_tween()
	tween.tween_property(spread_display, "modulate:a", 0.0, fade_duration * 0.5)
	tween.tween_callback(_update_spread_display)
	tween.tween_property(spread_display, "modulate:a", 1.0, fade_duration * 0.5)


func _update_spread_display() -> void:
	if current_spread >= 0 and current_spread < spread_textures.size():
		spread_display.texture = spread_textures[current_spread]

	_update_page_content()


func _update_page_content() -> void:
	# Clear existing content
	for child in left_page_content.get_children():
		child.queue_free()
	for child in right_page_content.get_children():
		child.queue_free()

	# Content will be populated based on spread type and game progress
	match current_spread:
		0:
			_populate_blueprint_spread()
		_:
			_populate_diary_spread(current_spread)


func _populate_blueprint_spread() -> void:
	# Blueprint page - will show discovered inscriptions
	# This will be expanded when we add the inscription system
	pass


func _populate_diary_spread(_spread_index: int) -> void:
	# Diary pages - will show journal entries (locked/unlocked)
	# This will be expanded when we add the diary entry system
	pass


func _play_sound(sound: AudioStream) -> void:
	if sound and audio_player:
		audio_player.stream = sound
		audio_player.play()


func _play_random_page_sound() -> void:
	if page_turn_sounds.is_empty() or not audio_player:
		return
	var random_index = randi() % page_turn_sounds.size()
	audio_player.stream = page_turn_sounds[random_index]
	audio_player.play()


# Public API for other systems to add content
func add_inscription(_inscription_data: Dictionary) -> void:
	# Will be called when player discovers an inscription
	pass


func unlock_diary_entry(_entry_id: String) -> void:
	# Will be called when a diary entry should be translated
	pass


func is_journal_open() -> bool:
	return is_open


func get_current_spread() -> int:
	return current_spread
