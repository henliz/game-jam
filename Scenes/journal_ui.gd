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
@export var journal_pickup_dialogue_id: String = "F1JournalPickup"
@export var after_pickup_dialogue_id: String = "F1PickupInteractableFirst"
@export var diary_dialogue_delay: float = 2.0  # Delay between diary dialogues

@export_group("Notification")
@export var notification_icon_texture: Texture2D

var is_open: bool = false
var was_first_pickup: bool = false  # Track if this open was the first journal pickup
var current_spread: int = 0
var spreads: Array[Control] = []
var pending_diary_dialogues: Array[String] = []  # Diary dialogues to play on next open
var notification_icon: TextureRect  # Journal notification icon
var notification_layer: CanvasLayer  # Separate layer so notification stays visible when journal is closed

@onready var background: ColorRect = $Background
@onready var journal_container: Control = $JournalContainer
@onready var audio_player: AudioStreamPlayer = $AudioPlayer


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	background.modulate.a = 0.0
	journal_container.modulate.a = 0.0

	add_to_group("journal_ui")
	_collect_spreads()
	_setup_audio()
	_setup_notification_icon()
	_show_spread(current_spread)
	_update_page_visibility()  # Set initial page states
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


func _setup_notification_icon() -> void:
	if not notification_icon_texture:
		notification_icon_texture = load("res://resource/UI/Journal/ART_UI_JOURNAL_ICON_PLACEHOLDER.png")

	if not notification_icon_texture:
		push_warning("JournalUI: No notification icon texture found")
		return

	# Check if notification layer already exists (persists across floor changes)
	var existing = get_tree().root.get_node_or_null("JournalNotificationLayer")
	if existing:
		notification_layer = existing
		notification_icon = notification_layer.get_node("NotificationContainer/NotificationIcon")
		return

	# Create separate CanvasLayer added to root viewport (persists across floors)
	notification_layer = CanvasLayer.new()
	notification_layer.layer = 50  # Above gameplay, below journal
	notification_layer.name = "JournalNotificationLayer"

	# Create a Control to hold the TextureRect (needed for anchors to work)
	var container = Control.new()
	container.name = "NotificationContainer"
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notification_layer.add_child(container)

	notification_icon = TextureRect.new()
	notification_icon.texture = notification_icon_texture
	notification_icon.name = "NotificationIcon"
	notification_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Position in bottom right, 40px from edges
	notification_icon.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	notification_icon.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	notification_icon.grow_vertical = Control.GROW_DIRECTION_BEGIN
	notification_icon.position = Vector2(-40 - notification_icon_texture.get_width(), -40 - notification_icon_texture.get_height())

	notification_icon.visible = false
	container.add_child(notification_icon)

	# Add to root viewport (not tied to any floor scene)
	get_tree().root.add_child(notification_layer)


func show_notification() -> void:
	if notification_icon:
		notification_icon.visible = true
		print("JournalUI: Showing notification icon")


func hide_notification() -> void:
	if notification_icon:
		notification_icon.visible = false
		print("JournalUI: Hiding notification icon")


func queue_diary_dialogue(dialogue_id: String) -> void:
	if dialogue_id not in pending_diary_dialogues:
		pending_diary_dialogues.append(dialogue_id)
		show_notification()
		print("JournalUI: Queued diary dialogue: ", dialogue_id)


func _play_pending_diary_dialogues() -> void:
	if pending_diary_dialogues.is_empty():
		return

	print("JournalUI: Playing ", pending_diary_dialogues.size(), " pending diary dialogues")

	# Copy and clear pending list
	var dialogues_to_play = pending_diary_dialogues.duplicate()
	pending_diary_dialogues.clear()

	# Start playing with a small initial delay
	_play_diary_dialogue_sequence(dialogues_to_play, 0)


func _play_diary_dialogue_sequence(dialogues: Array, index: int) -> void:
	if index >= dialogues.size():
		print("JournalUI: Finished playing all diary dialogues")
		return

	var dialogue_id = dialogues[index]
	print("JournalUI: Playing diary dialogue ", index + 1, "/", dialogues.size(), ": ", dialogue_id)

	# Play this dialogue
	if DialogueManager.play(dialogue_id):
		# Mark as triggered so page visibility updates
		GameState.mark_dialogue_triggered(dialogue_id)
		GameState.save_game()

		# Connect to dialogue_finished to play next one
		var on_finished: Callable
		on_finished = func(_entry: Dictionary):
			DialogueManager.dialogue_finished.disconnect(on_finished)
			# Wait diary_dialogue_delay seconds before playing next
			if index + 1 < dialogues.size():
				get_tree().create_timer(diary_dialogue_delay).timeout.connect(
					func(): _play_diary_dialogue_sequence(dialogues, index + 1)
				)
		DialogueManager.dialogue_finished.connect(on_finished)
	else:
		# If dialogue failed to play, try next one immediately
		_play_diary_dialogue_sequence(dialogues, index + 1)


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


func _set_player_enabled(enabled: bool) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player and "movement_enabled" in player:
		player.movement_enabled = enabled


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

	# Hide notification icon when journal opens
	hide_notification()

	# Check if we need to play the journal pickup dialogue (first pickup)
	var is_first_pickup = journal_pickup_dialogue_id and not GameState.has_dialogue_triggered(journal_pickup_dialogue_id)
	was_first_pickup = is_first_pickup  # Remember for when journal closes

	# Only play open sound if not first pickup (dialogue will play instead)
	if not is_first_pickup:
		_play_sound(open_sound)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(background, "modulate:a", 0.7, fade_duration)
	tween.tween_property(journal_container, "modulate:a", 1.0, fade_duration)

	# Disable player movement instead of pausing (keeps audio playing)
	_set_player_enabled(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	_on_first_open()

	# Play pending diary dialogues after a short delay (let other dialogues finish first)
	if not pending_diary_dialogues.is_empty() and not is_first_pickup:
		_play_pending_diary_dialogues()

	journal_opened.emit()


func _on_first_open() -> void:
	# Check if journal pickup dialogue needs to play (first time picking up journal)
	if journal_pickup_dialogue_id and not GameState.has_dialogue_triggered(journal_pickup_dialogue_id):
		DialogueManager.try_trigger_dialogue(journal_pickup_dialogue_id, journal_pickup_dialogue_id)
	elif first_open_dialogue_id:
		# Regular first open dialogue (subsequent opens)
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

	# Re-enable player movement
	_set_player_enabled(true)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# If this was the first pickup, trigger the "see interactable" dialogue and increase glow ranges
	if was_first_pickup:
		was_first_pickup = false
		_on_first_pickup_close()

	journal_closed.emit()


func _on_first_pickup_close() -> void:
	# Trigger the dialogue about seeing glowing interactables
	if after_pickup_dialogue_id:
		DialogueManager.try_trigger_dialogue(after_pickup_dialogue_id, after_pickup_dialogue_id)

	# Increase teakettle glow range to make it more noticeable
	_increase_interactable_glow_ranges()


func _increase_interactable_glow_ranges() -> void:
	# Find teakettle and increase its glow range
	var teakettle = get_tree().get_first_node_in_group("teakettle")
	if teakettle:
		var glow = teakettle.get_node_or_null("GlowOutline") as GlowOutline
		if glow:
			glow.set_interaction_range(5.0)
			print("JournalUI: Increased teakettle glow range to 5.0")


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
