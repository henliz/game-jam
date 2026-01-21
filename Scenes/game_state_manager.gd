extends Node

signal state_changed(key: String, value: Variant)
signal game_loaded

const SAVE_PATH := "user://savegame.json"

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


# --- Getters with convenient shortcuts ---

func get_value(key: String, default: Variant = null) -> Variant:
	return state.get(key, default)


func get_puzzle(puzzle_id: String) -> Dictionary:
	return state.puzzles.get(puzzle_id, {"cleaned": false, "repaired": false})


func is_puzzle_cleaned(puzzle_id: String) -> bool:
	return get_puzzle(puzzle_id).get("cleaned", false)


func is_puzzle_repaired(puzzle_id: String) -> bool:
	return get_puzzle(puzzle_id).get("repaired", false)


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


func set_puzzle_cleaned(puzzle_id: String, cleaned: bool = true) -> void:
	if puzzle_id not in state.puzzles:
		state.puzzles[puzzle_id] = {"cleaned": false, "repaired": false}
	state.puzzles[puzzle_id].cleaned = cleaned
	state_changed.emit("puzzles", state.puzzles)


func set_puzzle_repaired(puzzle_id: String, repaired: bool = true) -> void:
	if puzzle_id not in state.puzzles:
		state.puzzles[puzzle_id] = {"cleaned": false, "repaired": false}
	state.puzzles[puzzle_id].repaired = repaired
	state_changed.emit("puzzles", state.puzzles)


func unlock_floor(floor_num: int) -> void:
	if floor_num not in state.unlocked_floors:
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
