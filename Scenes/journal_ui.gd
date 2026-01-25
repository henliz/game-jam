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

@export_group("Puzzle Completion Sequence")
@export var blueprint_view_duration: float = 3.0  # Time to view blueprint before auto-turning
@export var unlock_fade_duration: float = 1.0  # Crossfade duration for diary unlock

@export_group("Notification")
@export var notification_icon_texture: Texture2D

@export_group("Blueprints")
@export var blueprints_1 : Resource
@export var blueprints_2 : Resource
@export var blueprints_3 : Resource
@export var blueprints_4 : Resource
@export var blueprints_5 : Resource
@export var blueprints_6 : Resource
@export var blueprints_7 : Resource
@export var blueprints_8 : Resource
@export var blueprints_9 : Resource

@onready var blueprints: TextureRect = $JournalContainer/Spread1_Blueprint/Blueprints
var curr_blueprint : int = 0
var blueprint_list = []

var is_open: bool = false
var was_first_pickup: bool = false  # Track if this open was the first journal pickup
var current_spread: int = 0
var spreads: Array[Control] = []
var notification_icon: TextureRect  # Journal notification icon
var notification_layer: CanvasLayer  # Separate layer so notification stays visible when journal is closed

# Puzzle completion sequence state
var input_locked: bool = false  # Lock J key and page turning during sequence
var deferred_diary_id: String = ""  # Diary dialogue to play after journal closes
var pending_unlock_spread: int = -1  # Spread to show unlock animation on

# Direct mapping from puzzle completion index (0-8) to page location
# Diary entries unlock in ORDER of completion, not tied to specific items
# Spread indices: 0=Blueprint, 1=Diary1, 2=Diary2, 3=Diary3, 4=Diary4, 5=Diary5
const PUZZLE_COMPLETION_PAGES := [
	# Floor 1 (puzzles 1-3)
	{"spread": 1, "side": "left", "diary_id": "F1Diary01"},     # 1st puzzle completed
	{"spread": 1, "side": "right", "diary_id": "F1Diary02"},    # 2nd puzzle completed
	{"spread": 2, "side": "left", "diary_id": "F1Diary03"},     # 3rd puzzle completed
	# Floor 2 (puzzles 4-6)
	{"spread": 2, "side": "right", "diary_id": "F2Diary04"},    # 4th puzzle completed
	{"spread": 3, "side": "left", "diary_id": "F2Diary05"},     # 5th puzzle completed
	{"spread": 3, "side": "right", "diary_id": "F2Diary06"},    # 6th puzzle completed
	# Floor 3 (puzzles 7-9)
	{"spread": 4, "side": "left", "diary_id": "F3Diary07"},     # 7th puzzle completed
	{"spread": 4, "side": "right", "diary_id": "F3Diary08"},    # 8th puzzle completed
	{"spread": 5, "side": "left", "diary_id": "F3Diary09"},     # 9th puzzle completed
]

@onready var background: ColorRect = $Background
@onready var journal_container: Control = $JournalContainer
@onready var audio_player: AudioStreamPlayer = $AudioPlayer


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	background.modulate.a = 0.0
	journal_container.modulate.a = 0.0
	blueprint_list = [blueprints_1,blueprints_2,blueprints_3,blueprints_4,blueprints_5,blueprints_6,blueprints_7,blueprints_8,blueprints_9]

	# Initialize blueprint display from persisted game state
	curr_blueprint = game_state.get_blueprint_count()
	if curr_blueprint > 0:
		blueprints.texture = blueprint_list[curr_blueprint - 1]

	add_to_group("journal_ui")
	_collect_spreads()
	_setup_audio()
	_setup_notification_icon()
	_show_spread(current_spread)
	_update_page_visibility()  # Set initial page states
	game_state.state_changed.connect(_on_game_state_changed)
	game_state.unlock_blueprint.connect(_increment_blueprint_page)


func _increment_blueprint_page():
	if curr_blueprint>=9: return
	print("increment blueprint")
	blueprints.texture = blueprint_list[curr_blueprint]
	curr_blueprint = curr_blueprint+1

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


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("journal"):
		if not is_open and _is_player_inspecting():
			return
		# Block closing when input is locked during puzzle completion sequence
		if is_open and input_locked:
			get_viewport().set_input_as_handled()
			return
		toggle_journal()
		get_viewport().set_input_as_handled()
		return

	if not is_open:
		return

	# Block all navigation when input is locked
	if input_locked:
		get_viewport().set_input_as_handled()
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

	# Play deferred diary dialogue after journal closes (from puzzle completion sequence)
	if not deferred_diary_id.is_empty():
		var diary_to_play = deferred_diary_id
		deferred_diary_id = ""
		get_tree().create_timer(0.3).timeout.connect(
			func(): _play_deferred_dialogue(diary_to_play), CONNECT_ONE_SHOT
		)

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
			glow.set_interaction_range(10.0)


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
	# Uses the shared PUZZLE_COMPLETION_PAGES constant for all 9 diary entries

	# Check which diary entries are unlocked and update ONLY those pages
	for page_info in PUZZLE_COMPLETION_PAGES:
		var diary_id = page_info.diary_id
		var spread_index = page_info.spread

		# Make sure the spread exists
		if spread_index >= spreads.size():
			continue

		var spread = spreads[spread_index]
		var is_unlocked = game_state.has_dialogue_triggered(diary_id)

		# Handle custom node names (for spreads with different naming conventions)
		var side = page_info.get("side", "")
		if page_info.has("locked"):
			var locked_node = spread.get_node_or_null(page_info.locked)
			if locked_node:
				locked_node.visible = not is_unlocked
			# Unlocked node is optional - some spreads only have locked overlay
			if page_info.has("unlocked"):
				var unlocked_node = spread.get_node_or_null(page_info.unlocked)
				if unlocked_node:
					unlocked_node.visible = is_unlocked
		elif side == "left":
			var left_locked = spread.get_node_or_null("LeftPage_Locked")
			var left_unlocked = spread.get_node_or_null("LeftPage_Unlocked")
			if left_locked and left_unlocked:
				left_locked.visible = not is_unlocked
				left_unlocked.visible = is_unlocked
		elif side == "right":
			var right_locked = spread.get_node_or_null("RightPage_Locked")
			var right_unlocked = spread.get_node_or_null("RightPage_Unlocked")
			if right_locked and right_unlocked:
				right_locked.visible = not is_unlocked
				right_unlocked.visible = is_unlocked


# --- Puzzle Completion Sequence ---
# Called when a cleaning puzzle is complete - auto-opens journal to blueprint,
# then turns to diary page and plays unlock animation

func start_puzzle_completion_sequence(item_id: String) -> void:
	print("JournalUI: Starting puzzle completion sequence for: ", item_id)

	# Get puzzle index from blueprint count (count was already incremented)
	var puzzle_index = GameState.get_blueprint_count() - 1
	if puzzle_index < 0 or puzzle_index >= PUZZLE_COMPLETION_PAGES.size():
		print("JournalUI: Invalid puzzle index: ", puzzle_index)
		return

	var page_info = PUZZLE_COMPLETION_PAGES[puzzle_index]
	var diary_id = page_info.diary_id

	print("JournalUI: Puzzle ", puzzle_index + 1, " -> diary ", diary_id, " -> spread ", page_info.spread)

	deferred_diary_id = diary_id
	pending_unlock_spread = page_info.spread

	# Open to blueprint page (spread 0) with input locked
	_open_journal_for_sequence(0)

	# After viewing blueprint, turn to diary page
	get_tree().create_timer(blueprint_view_duration).timeout.connect(
		_on_blueprint_view_complete, CONNECT_ONE_SHOT
	)


func _open_journal_for_sequence(spread_index: int) -> void:
	if is_open:
		return

	is_open = true
	visible = true
	input_locked = true  # Lock input during sequence

	hide_notification()
	current_spread = spread_index
	_show_spread(current_spread)
	_play_sound(open_sound)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(background, "modulate:a", 0.7, fade_duration)
	tween.tween_property(journal_container, "modulate:a", 1.0, fade_duration)

	_set_player_enabled(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	journal_opened.emit()


func _on_blueprint_view_complete() -> void:
	if pending_unlock_spread < 0:
		input_locked = false
		return

	print("JournalUI: Blueprint view complete, turning to spread ", pending_unlock_spread)

	# Turn to diary spread
	go_to_spread(pending_unlock_spread)

	# After page turn animation completes, do unlock transition
	get_tree().create_timer(fade_duration + 0.1).timeout.connect(
		_animate_diary_unlock, CONNECT_ONE_SHOT
	)


func _animate_diary_unlock() -> void:
	if deferred_diary_id.is_empty():
		input_locked = false
		pending_unlock_spread = -1
		return

	# Find the page info for this diary entry
	var page_info = {}
	for entry in PUZZLE_COMPLETION_PAGES:
		if entry.diary_id == deferred_diary_id:
			page_info = entry
			break

	if page_info.is_empty() or pending_unlock_spread >= spreads.size():
		input_locked = false
		pending_unlock_spread = -1
		return

	var spread = spreads[pending_unlock_spread]
	var side = page_info.get("side", "")

	# Handle custom node names (for spreads with different naming)
	var locked_node: Control = null
	var unlocked_node: Control = null

	if page_info.has("locked"):
		locked_node = spread.get_node_or_null(page_info.locked)
		if page_info.has("unlocked"):
			unlocked_node = spread.get_node_or_null(page_info.unlocked)
	elif side == "left":
		locked_node = spread.get_node_or_null("LeftPage_Locked")
		unlocked_node = spread.get_node_or_null("LeftPage_Unlocked")
	elif side == "right":
		locked_node = spread.get_node_or_null("RightPage_Locked")
		unlocked_node = spread.get_node_or_null("RightPage_Unlocked")

	print("JournalUI: Animating unlock - locked: ", locked_node, ", unlocked: ", unlocked_node)

	if locked_node and unlocked_node:
		# Crossfade from locked to unlocked
		unlocked_node.modulate.a = 0.0
		unlocked_node.visible = true

		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(locked_node, "modulate:a", 0.0, unlock_fade_duration)
		tween.tween_property(unlocked_node, "modulate:a", 1.0, unlock_fade_duration)
		tween.set_parallel(false)
		tween.tween_callback(func():
			locked_node.visible = false
			locked_node.modulate.a = 1.0  # Reset for next time
			input_locked = false
			pending_unlock_spread = -1
			print("JournalUI: Unlock animation complete, input unlocked")
		)
	elif locked_node:
		# Only locked node exists (overlay style) - just fade it out
		var tween = create_tween()
		tween.tween_property(locked_node, "modulate:a", 0.0, unlock_fade_duration)
		tween.tween_callback(func():
			locked_node.visible = false
			locked_node.modulate.a = 1.0
			input_locked = false
			pending_unlock_spread = -1
		)
	else:
		# No animation needed
		input_locked = false
		pending_unlock_spread = -1


func _play_deferred_dialogue(diary_id: String) -> void:
	if GameState.has_dialogue_triggered(diary_id):
		print("JournalUI: Deferred dialogue already triggered: ", diary_id)
		return

	print("JournalUI: Playing deferred diary dialogue: ", diary_id)
	if DialogueManager.play(diary_id):
		GameState.mark_dialogue_triggered(diary_id)
		GameState.save_game()

		# Check if this is the 3rd diary on a floor - play floor completion dialogue after
		var floor_completion_id = _get_floor_completion_dialogue(diary_id)
		if not floor_completion_id.is_empty():
			DialogueManager.dialogue_finished.connect(
				func(_entry): _play_floor_completion(floor_completion_id),
				CONNECT_ONE_SHOT
			)


func _get_floor_completion_dialogue(diary_id: String) -> String:
	# 3rd diary on each floor triggers floor completion dialogue
	match diary_id:
		"F1Diary03": return "F1AllItemsComplete"
		"F2Diary06": return "F2AllItemsComplete"
		"F3Diary09": return "F3AllItemsComplete"
	return ""


func _play_floor_completion(dialogue_id: String) -> void:
	if GameState.has_dialogue_triggered(dialogue_id):
		return
	print("JournalUI: Playing floor completion dialogue: ", dialogue_id)
	if DialogueManager.play(dialogue_id):
		GameState.mark_dialogue_triggered(dialogue_id)
		GameState.save_game()
