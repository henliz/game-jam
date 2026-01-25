extends Node

signal state_changed(key: String, value: Variant)
signal game_loaded
signal unlock_blueprint

const SAVE_PATH := "user://savegame.json"

# Debug: Set to true to start with floor 2 unlocked and 3 puzzles complete
const DEBUG_START_FLOOR_2 := false
# Debug: Set to true to start with floor 3 unlocked and 6 puzzles complete
const DEBUG_START_FLOOR_3 := false

# Items that require BOTH repair AND clean to count as one complete puzzle
# These items only emit 1 blueprint when both conditions are met
const REPAIR_REQUIRED_ITEMS := ["Wizard Bust", "Celestial Globe", "AlchemyContainer"]

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

	# Repaired items (item_name -> true for items that have been repaired/solved)
	"repaired_items": {},

	# Dialogue triggers that have already fired (trigger_id -> true)
	"triggered_dialogues": {},

	# Blueprint progression count (0-9)
	"blueprint_count": 0,
}

func _ready() -> void:
	reset_to_default()


func reset_to_default() -> void:
	state = _default_state.duplicate(true)
	if DEBUG_START_FLOOR_3:
		_apply_debug_floor3_state()
	elif DEBUG_START_FLOOR_2:
		_apply_debug_floor2_state()


func _apply_debug_floor2_state() -> void:
	# Unlock floors 2 and 4 for playtesting
	state.unlocked_floors = [1, 2]
	# Mark first 3 puzzles as complete (floor 1 items cleaned)
	state.cleaned_items = {
		"Antique Tea Kettle": true,
		"Magic Billy Bass": true,
		"Wizard Bust": true,
	}
	# Mark Wizard Bust as repaired (required for floor 1 completion)
	state.repaired_items = {
		"Wizard Bust": true,
	}
	# Mark floor 1 diary dialogues as triggered
	state.triggered_dialogues = {
		"F1JournalPickup": true,
		"F1PickupInteractableFirst": true,
		"F1Diary01": true,
		"F1Diary02": true,
		"F1Diary03": true,
	}
	# Unlock puzzles (normally done by picking up journal)
	state.flags["puzzles_unlocked"] = true
	# Set blueprint count to match completed puzzles
	state.blueprint_count = 3
	print("DEBUG: Applied floor 2 test state - Floor 2 unlocked, 3 puzzles complete, puzzles unlocked")


func _apply_debug_floor3_state() -> void:
	# Unlock floors 1-3 (and 4 for testing forward)
	state.unlocked_floors = [1, 2, 3]

	# Mark all floor 1 and floor 2 items as cleaned
	state.cleaned_items = {
		# Floor 1
		"Antique Tea Kettle": true,
		"Magic Billy Bass": true,
		"Wizard Bust": true,
		# Floor 2
		"Crystal Ball": true,
		"Strange Lantern": true,
		"Celestial Globe": true,
	}

	# Mark repair-required items as repaired
	state.repaired_items = {
		"Wizard Bust": true,
		"Celestial Globe": true,
	}

	# Mark all dialogues from floors 1 and 2 as triggered
	state.triggered_dialogues = {
		# Floor 1 progression
		"F1JournalPickup": true,
		"F1PickupInteractableFirst": true,
		"F1SeeInteractableFirst": true,
		"F1FirstTimeCleaningDimension": true,
		"F1FirstItemCleaned": true,
		"F1FixBust": true,
		"F1AllItemsComplete": true,
		# Floor 1 diary pages
		"F1Diary01": true,
		"F1Diary02": true,
		"F1Diary03": true,
		# Floor 2 progression
		"F2Entry": true,
		"F2WindGust": true,
		"F2FixGlobe": true,
		"F2AllItemsComplete": true,
		# Floor 2 diary pages
		"F2Diary04": true,
		"F2Diary05": true,
		"F2Diary06": true,
	}

	# Unlock puzzles (normally done by picking up journal)
	state.flags["puzzles_unlocked"] = true
	# Set blueprint count to match completed puzzles
	state.blueprint_count = 6
	print("DEBUG: Applied floor 3 test state - Floor 3 unlocked, 6 puzzles complete")



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

	# Floor 1 puzzles - Teakettle and Billy Bass need cleaning only
	# Wizard Bust needs both cleaning AND repair
	var floor1_clean_only = ["Antique Tea Kettle", "Magic Billy Bass"]
	var floor1_repair_item = "Wizard Bust"
	var floor1_clean_complete = _count_floor_items_complete(floor1_clean_only, false)
	var floor1_bust_complete = is_item_cleaned(floor1_repair_item) and is_item_repaired(floor1_repair_item)
	var floor1_complete = floor1_clean_complete + (1 if floor1_bust_complete else 0)

	# Floor 2 puzzles - Crystal Ball and Strange Lantern need cleaning only
	# Celestial Globe needs both cleaning AND repair
	var floor2_clean_only = ["Crystal Ball", "Strange Lantern"]
	var floor2_repair_item = "Celestial Globe"
	var floor2_clean_complete = _count_floor_items_complete(floor2_clean_only, false)
	var floor2_globe_complete = is_item_cleaned(floor2_repair_item) and is_item_repaired(floor2_repair_item)
	var floor2_complete = floor2_clean_complete + (1 if floor2_globe_complete else 0)

	print("Floor 1 complete: ", floor1_complete, "/3")
	print("Floor 2 complete: ", floor2_complete, "/3")

	# Unlock floors based on completion
	if 2 not in state.unlocked_floors and floor1_complete >= 3:
		unlock_floor(2)
	if 3 not in state.unlocked_floors and floor2_complete >= 3:
		unlock_floor(3)

	# Queue diary dialogues based on puzzle completion
	var journal_ui = get_tree().get_first_node_in_group("journal_ui") as JournalUI
	print("  journal_ui found: ", journal_ui != null)
	print("  Wizard Bust - cleaned: ", is_item_cleaned("Wizard Bust"), ", repaired: ", is_item_repaired("Wizard Bust"))

	# Floor 1 diary pages
	var floor1_diary_pages = ["F1Diary01", "F1Diary02", "F1Diary03"]
	for i in range(floor1_complete):
		if i >= floor1_diary_pages.size():
			break
		var diary_id = floor1_diary_pages[i]
		var already_triggered = has_dialogue_triggered(diary_id)
		print("  Checking ", diary_id, " - already triggered: ", already_triggered)
		if not already_triggered:
			print("QUEUEING F1: ", diary_id)
			if journal_ui:
				journal_ui.queue_diary_dialogue(diary_id)
			else:
				print("  ERROR: journal_ui is null, cannot queue diary!")

	# Floor 2 diary pages (numbering continues from F1: 04, 05, 06)
	var floor2_diary_pages = ["F2Diary04", "F2Diary05", "F2Diary06"]
	for i in range(floor2_complete):
		if i >= floor2_diary_pages.size():
			break
		var diary_id = floor2_diary_pages[i]
		if not has_dialogue_triggered(diary_id):
			print("QUEUEING F2: ", diary_id)
			if journal_ui:
				journal_ui.queue_diary_dialogue(diary_id)


func _count_floor_items_complete(items: Array, require_repair: bool) -> int:
	var count = 0
	for item_name in items:
		if is_item_cleaned(item_name):
			if require_repair:
				if is_item_repaired(item_name):
					count += 1
			else:
				count += 1
	return count

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

	# Blueprint logic: repair+clean items only get 1 blueprint when BOTH are done
	if cleaned:
		if item_id in REPAIR_REQUIRED_ITEMS:
			# Only increment if both repaired AND cleaned
			if is_item_repaired(item_id):
				increment_blueprint_count()
				print("GameState: Blueprint unlocked for ", item_id, " (repair+clean complete)")
		else:
			# Clean-only items get blueprint on clean
			increment_blueprint_count()
			print("GameState: Blueprint unlocked for ", item_id, " (clean complete)")
	if state.cleaned_items.size()>=9:
		unlock_floor(4)
	_check_floor_progress()


# --- Repaired Items ---

func is_item_repaired(item_id: String) -> bool:
	return state.repaired_items.get(item_id, false)

func set_item_repaired(item_id: String, repaired: bool = true) -> void:
	state.repaired_items[item_id] = repaired
	state_changed.emit("repaired_items", state.repaired_items)

	# Blueprint logic: repair+clean items only get 1 blueprint when BOTH are done
	if repaired:
		if item_id in REPAIR_REQUIRED_ITEMS:
			# Only increment if both repaired AND cleaned
			if is_item_cleaned(item_id):
				increment_blueprint_count()
				print("GameState: Blueprint unlocked for ", item_id, " (repair+clean complete)")
		# Note: no else branch - repair-only items don't exist currently

	_check_floor_progress()


# --- Dialogue Triggers ---

func has_dialogue_triggered(trigger_id: String) -> bool:
	return state.triggered_dialogues.get(trigger_id, false)


func mark_dialogue_triggered(trigger_id: String) -> void:
	state.triggered_dialogues[trigger_id] = true
	state_changed.emit("triggered_dialogues", state.triggered_dialogues)


# --- Blueprint Count ---

func get_blueprint_count() -> int:
	return state.get("blueprint_count", 0)


func increment_blueprint_count() -> void:
	state.blueprint_count = state.get("blueprint_count", 0) + 1
	state_changed.emit("blueprint_count", state.blueprint_count)
	unlock_blueprint.emit()


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
