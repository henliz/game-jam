extends Node
class_name DialogueManagerClass

signal dialogue_started(entry: Dictionary)
signal dialogue_finished(entry: Dictionary)

const DIALOGUE_DATA_PATH := "res://Data/dialogue.json"

var dialogue_data: Dictionary = {}
var entries_by_id: Dictionary = {}
var entries_by_type: Dictionary = {}

var audio_player: AudioStreamPlayer
var current_entry: Dictionary = {}
var is_playing: bool = false

var caption_ui: DialogueCaption


func _ready() -> void:
	_setup_audio_player()
	_load_dialogue_data()
	_setup_caption_ui()


func _setup_audio_player() -> void:
	audio_player = AudioStreamPlayer.new()
	audio_player.bus = "Dialogue"
	audio_player.finished.connect(_on_audio_finished)
	add_child(audio_player)


func _load_dialogue_data() -> void:
	if not FileAccess.file_exists(DIALOGUE_DATA_PATH):
		push_error("DialogueManager: Dialogue data file not found at %s" % DIALOGUE_DATA_PATH)
		return

	var file := FileAccess.open(DIALOGUE_DATA_PATH, FileAccess.READ)
	var json_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_result := json.parse(json_text)
	if parse_result != OK:
		push_error("DialogueManager: Failed to parse dialogue JSON: %s" % json.get_error_message())
		return

	dialogue_data = json.data
	_index_entries()


func _index_entries() -> void:
	entries_by_id.clear()
	entries_by_type.clear()

	if not dialogue_data.has("entries"):
		push_warning("DialogueManager: No 'entries' array in dialogue data")
		return

	for entry in dialogue_data["entries"]:
		var id: String = entry.get("id", "")
		if id.is_empty():
			continue

		entries_by_id[id] = entry

		var type: String = entry.get("type", "dialogue")
		var subtype = entry.get("subtype")

		if not entries_by_type.has(type):
			entries_by_type[type] = {}

		var subtype_key: String = str(subtype) if subtype != null else "_none"
		if not entries_by_type[type].has(subtype_key):
			entries_by_type[type][subtype_key] = []

		entries_by_type[type][subtype_key].append(entry)

	print("DialogueManager: Loaded %d dialogue entries" % entries_by_id.size())


func _setup_caption_ui() -> void:
	var caption_scene := preload("res://Scenes/dialogue_caption.tscn")
	caption_ui = caption_scene.instantiate()
	add_child(caption_ui)


func play(id: String) -> bool:
	if not entries_by_id.has(id):
		push_warning("DialogueManager: No dialogue entry with id '%s'" % id)
		return false

	var entry: Dictionary = entries_by_id[id]
	return _play_entry(entry)


func play_random_by_type(type: String, subtype: String = "") -> bool:
	if not entries_by_type.has(type):
		push_warning("DialogueManager: No entries of type '%s'" % type)
		return false

	var subtype_key: String = subtype if not subtype.is_empty() else "_none"
	if not entries_by_type[type].has(subtype_key):
		push_warning("DialogueManager: No entries of type '%s' with subtype '%s'" % [type, subtype])
		return false

	var candidates: Array = entries_by_type[type][subtype_key]
	if candidates.is_empty():
		return false

	var random_entry: Dictionary = candidates[randi() % candidates.size()]
	return _play_entry(random_entry)


func _play_entry(entry: Dictionary) -> bool:
	if is_playing:
		stop()

	current_entry = entry
	is_playing = true

	dialogue_started.emit(entry)

	var audio_path: String = entry.get("audio_path", "")
	if not audio_path.is_empty() and ResourceLoader.exists(audio_path):
		var audio_stream := load(audio_path) as AudioStream
		if audio_stream:
			audio_player.stream = audio_stream
			audio_player.play()
	else:
		# no audio file, use text display duration
		_start_text_timer(entry)

	_show_caption(entry)
	return true


func _start_text_timer(entry: Dictionary) -> void:
	var text: String = entry.get("text", "")
	var duration: float = max(2.0, text.length() * 0.05)
	get_tree().create_timer(duration).timeout.connect(_on_audio_finished)


func _show_caption(entry: Dictionary) -> void:
	if caption_ui and caption_ui.has_method("show_caption"):
		var speaker: String = entry.get("speaker", "")
		var text: String = entry.get("text", "")
		caption_ui.show_caption(speaker, text)


func _hide_caption() -> void:
	if caption_ui and caption_ui.has_method("hide_caption"):
		caption_ui.hide_caption()


func stop() -> void:
	if audio_player.playing:
		audio_player.stop()
	_hide_caption()
	is_playing = false
	if not current_entry.is_empty():
		dialogue_finished.emit(current_entry)
		current_entry = {}


func _on_audio_finished() -> void:
	_hide_caption()
	is_playing = false
	dialogue_finished.emit(current_entry)
	current_entry = {}


func get_entry(id: String) -> Dictionary:
	return entries_by_id.get(id, {})


func get_all_subtypes(type: String) -> Array:
	if not entries_by_type.has(type):
		return []
	var subtypes: Array = entries_by_type[type].keys()
	subtypes.erase("_none")
	return subtypes


func reload_dialogue_data() -> void:
	_load_dialogue_data()
