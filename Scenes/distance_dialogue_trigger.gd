class_name DistanceDialogueTrigger
extends Node3D

@export var trigger_id: String = ""
@export var dialogue_id: String = ""
@export var trigger_distance: float = 3.0
@export var player_path: NodePath

var player: Node3D
var has_triggered: bool = false


func _ready() -> void:
	if trigger_id.is_empty():
		trigger_id = name

	if not player_path.is_empty():
		player = get_node_or_null(player_path)

	if GameState.has_dialogue_triggered(trigger_id):
		has_triggered = true


func _process(_delta: float) -> void:
	if has_triggered:
		set_process(false)
		return

	if not player:
		_try_find_player()
		return

	var distance := global_position.distance_to(player.global_position)
	if distance <= trigger_distance:
		_trigger()


func _try_find_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0] as Node3D


func _trigger() -> void:
	has_triggered = true
	set_process(false)
	DialogueManager.try_trigger_dialogue(trigger_id, dialogue_id)
