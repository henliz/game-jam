class_name JournalUI
extends CanvasLayer

@onready var game_state = get_node("/root/GameState")
signal journal_opened
signal journal_closed
signal page_changed(spread_index: int)

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
var spreads: Array[Control] = []

@onready var background: ColorRect = $Background
@onready var journal_container: Control = $JournalContainer
@onready var audio_player: AudioStreamPlayer = $AudioPlayer


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS 
	visible = false
	background.modulate.a = 0.0
	journal_container.modulate.a = 0.0

	_collect_spreads()
	_setup_audio()
	_show_spread(current_spread)
	game_state.state_changed.connect(_on_game_state_changed)


func _collect_spreads() -> void:
	spreads.clear()
	for child in journal_container.get_children():
		if child.name.begins_with("Spread"):
			spreads.append(child)


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
		if not is_open and _is_player_inspecting():
			return
		toggle_journal()
		get_viewport().set_input_as_handled()
		return

	if not is_open:
		return

	if event.is_action_pressed("left") or (event is InputEventKey and event.pressed and event.keycode == KEY_LEFT):
		turn_page_left()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("right") or (event is InputEventKey and event.pressed and event.keycode == KEY_RIGHT):
		turn_page_right()
		get_viewport().set_input_as_handled()

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
	if current_spread < spreads.size() - 1:
		current_spread += 1
		_animate_page_turn(1)
		_play_random_page_sound()
		page_changed.emit(current_spread)


func go_to_spread(index: int) -> void:
	if index >= 0 and index < spreads.size() and index != current_spread:
		var direction = 1 if index > current_spread else -1
		current_spread = index
		_animate_page_turn(direction)
		_play_random_page_sound()
		page_changed.emit(current_spread)


func _animate_page_turn(_direction: int) -> void:
	var tween = create_tween()
	tween.tween_property(journal_container, "modulate:a", 0.0, fade_duration * 0.5)
	tween.tween_callback(func(): _show_spread(current_spread))
	tween.tween_property(journal_container, "modulate:a", 1.0, fade_duration * 0.5)


func _show_spread(index: int) -> void:
	for i in range(spreads.size()):
		spreads[i].visible = (i == index)


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


func is_journal_open() -> bool:
	return is_open


func get_current_spread() -> int:
	return current_spread

func _on_game_state_changed(key: String, _value: Variant) -> void:
	if key == "triggered_dialogues":
		_update_page_visibility()

func _update_page_visibility() -> void:
	print("UPDATE PAGE VISIBILITY")
	var diary_to_page = {
		"F1Diary01": {"spread": 1, "side": "left"},
		"F1Diary02": {"spread": 1, "side": "right"},
		"F1Diary03": {"spread": 2, "side": "left"},
	}
	
	# Check which diary entries are unlocked and update ONLY those pages
	for diary_id in diary_to_page:
		var page_info = diary_to_page[diary_id]
		var spread_index = page_info.spread
		
		# Make sure the spread exists
		if spread_index >= spreads.size():
			continue
			
		var spread = spreads[spread_index]
		var is_unlocked = game_state.has_dialogue_triggered(diary_id)
		
		if page_info.side == "left":
			var left_locked = spread.get_node_or_null("LeftPage_Locked")
			var left_unlocked = spread.get_node_or_null("LeftPage_Unlocked")
			if left_locked and left_unlocked:
				left_locked.visible = not is_unlocked
				left_unlocked.visible = is_unlocked
				
		elif page_info.side == "right":
			var right_locked = spread.get_node_or_null("RightPage_Locked")
			var right_unlocked = spread.get_node_or_null("RightPage_Unlocked")
			if right_locked and right_unlocked:
				right_locked.visible = not is_unlocked
				right_unlocked.visible = is_unlocked
