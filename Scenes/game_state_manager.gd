extends Node

signal state_changed(key: String, value: Variant)
signal game_loaded
signal unlock_blueprint

const SAVE_PATH := "user://savegame.json"

# Debug: Set to true to start with floor 2 unlocked and 3 puzzles complete
const DEBUG_START_FLOOR_2 := true

var state: Dictionary = {}

var _default_state: Dictionary = {
	# Puzzle states (9 puzzles)
	"puzzles": {
		"puzzle_1": {"cleaned": false, "repaired": false},
		"puzzle_2": {"cleaned": false, "repaired": false},
		"puzzle_3": {"cleaned": false, "repaired": false},
		"puzzle_4": {"cleaned": false, "repaired": false},
		"puzzle_5": {"cleaned": false, "repaired": false},
		"puzzle_6": {"cleaned": false, "repaired": false},
		"puzzle_7": {"cleaned": false, "repaired": false},
		"puzzle_8": {"cleaned": false, "repaired": false},
		"puzzle_9": {"cleaned": false, "repaired": false},
	},

	# Floor/area progression
	"unlocked_floors": [1],  # starts with floor 1 unlocked

	# First-time flags for dialogue triggers
	"first_time": {
		"journal_opened": false,
		"alchemy_set_seen": false,
		"intro_complete": false,
	},

	# Player inventory (item IDs)
	#"inventory": [],

	# Misc flags you can add to as needed
	"flags": {},

	# Cleanable items (store in puzzles above or here you can add keys by item_name, such as "Wizard's Tome")
	 "cleaned_items": {},

	# Dialogue triggers that have already fired (trigger_id -> true)
	"triggered_dialogues": {},
}

func _ready() -> void:
	reset_to_default()


func reset_to_default() -> void:
	state = _default_state.duplicate(true)
	if DEBUG_START_FLOOR_2:
		_apply_debug_floor2_state()


func _apply_debug_floor2_state() -> void:
	# Unlock floors 2 and 4 for playtesting
	state.unlocked_floors = [1, 2, 4]
	# Mark first 3 puzzles as complete (floor 1 items cleaned)
	state.cleaned_items = {
		"Teakettle": true,
		"MagicBillyBass": true,
		"WizardBust": true,
	}
	# Mark floor 1 diary dialogues as triggered
	state.triggered_dialogues = {
		"F1JournalPickup": true,
		"F1PickupInteractableFirst": true,
		"F1Diary01": true,
		"F1Diary02": true,
		"F1Diary03": true,
	}
	print("DEBUG: Applied floor 2 test state - Floors 2 & 4 unlocked, 3 puzzles complete")


# --- Getters with convenient shortcuts ---

func get_value(key: String, default: Variant = null) -> Variant:
	return state.get(key, default)


func is_floor_unlocked(floor_num: int) -> bool:
	return floor_num in state.unlocked_floors


func is_first_time(event: String) -> bool:
	return not state.first_time.get(event, false)


func get_flag(flag_name: String, default: Variant = false) -> Variant:
	return state.flags.get(flag_name, default)


# --- Setters ---

func set_value(key: String, value: Variant) -> void:
	state[key] = value
	state_changed.emit(key, value)

func _check_floor_progress() -> void:
	print("=== CHECK FLOOR PROGRESS ===")

	# Count how many items are cleaned
	var items_cleaned = state.cleaned_items.size()
	print("Total items cleaned: ", items_cleaned)
	if 2 not in state.unlocked_floors and items_cleaned>=3: unlock_floor(2)
	if 3 not in state.unlocked_floors and items_cleaned>=6: unlock_floor(3)
	if 4 not in state.unlocked_floors and items_cleaned>=9: unlock_floor(4)
	# Unlock diary pages in order - queue them through journal UI
	var diary_pages = ["F1Diary01", "F1Diary02", "F1Diary03"]
	var journal_ui = get_tree().get_first_node_in_group("journal_ui") as JournalUI

	for i in range(items_cleaned):
		if i >= diary_pages.size():
			break
		var diary_id = diary_pages[i]
		print("Checking diary ", diary_id)
		if not has_dialogue_triggered(diary_id):
			print("QUEUEING: ", diary_id)
			if journal_ui:
				journal_ui.queue_diary_dialogue(diary_id)
			else:
				push_warning("GameState: No journal_ui found to queue diary dialogue")

func unlock_floor(floor_num: int) -> void:
	state.unlocked_floors.append(floor_num)
	state_changed.emit("unlocked_floors", state.unlocked_floors)


func mark_first_time_done(event: String) -> void:
	state.first_time[event] = true
	state_changed.emit("first_time", state.first_time)


func set_flag(flag_name: String, value: Variant = true) -> void:
	state.flags[flag_name] = value
	state_changed.emit("flags", state.flags)


# --- Cleanable Items ---

func is_item_cleaned(item_id: String) -> bool:
	return state.cleaned_items.get(item_id, false)

func set_item_cleaned(item_id: String, cleaned: bool = true) -> void:
	state.cleaned_items[item_id] = cleaned
	state_changed.emit("cleaned_items", state.cleaned_items)
	if cleaned: unlock_blueprint.emit()
	
	# Check if we should unlock a diary page
	_check_floor_progress()


# --- Dialogue Triggers ---

func has_dialogue_triggered(trigger_id: String) -> bool:
	return state.triggered_dialogues.get(trigger_id, false)


func mark_dialogue_triggered(trigger_id: String) -> void:
	state.triggered_dialogues[trigger_id] = true
	state_changed.emit("triggered_dialogues", state.triggered_dialogues)


# --- Save/Load ---

func save_game() -> bool:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open save file: %s" % FileAccess.get_open_error())
		return false

	var json_string := JSON.stringify(state, "\t")
	file.store_string(json_string)
	file.close()

	# For WebGL: sync filesystem to IndexedDB
	if OS.has_feature("web"):
		JavaScriptBridge.eval("FS.syncfs(false, function(err) { if(err) console.error('Save sync failed:', err); });", true)

	print("Game saved to: ", SAVE_PATH)
	return true


func load_game() -> bool:
	# For WebGL: ensure IndexedDB is synced before reading
	if OS.has_feature("web"):
		# This is synchronous in practice for reading
		JavaScriptBridge.eval("FS.syncfs(true, function(err) { if(err) console.error('Load sync failed:', err); });", true)

	if not FileAccess.file_exists(SAVE_PATH):
		print("No save file found, using defaults")
		return false

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("Failed to open save file: %s" % FileAccess.get_open_error())
		return false

	var json_string := file.get_as_text()
	file.close()

	var json := JSON.new()
	var error := json.parse(json_string)
	if error != OK:
		push_error("Failed to parse save file: %s" % json.get_error_message())
		return false

	var loaded_data: Dictionary = json.get_data()
	_merge_with_defaults(loaded_data)
	state = loaded_data

	game_loaded.emit()
	print("Game loaded from: ", SAVE_PATH)
	return true


func _merge_with_defaults(loaded: Dictionary) -> void:
	# Ensures new keys added in updates don't break old saves
	for key in _default_state:
		if key not in loaded:
			loaded[key] = _default_state[key].duplicate(true) if _default_state[key] is Dictionary or _default_state[key] is Array else _default_state[key]
		elif _default_state[key] is Dictionary and loaded[key] is Dictionary:
			for subkey in _default_state[key]:
				if subkey not in loaded[key]:
					loaded[key][subkey] = _default_state[key][subkey]


func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func delete_save() -> void:
	if has_save_file():
		DirAccess.remove_absolute(SAVE_PATH)
		print("Save file deleted")
	reset_to_default()
