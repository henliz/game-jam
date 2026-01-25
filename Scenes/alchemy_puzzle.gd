extends Node3D

@export var pipe_1: StaticBody3D
@export var pipe_2: StaticBody3D
@export var pipe_3: StaticBody3D

@export var alchemy_container_completed: Interactable 
@export var alchemy_container_uncomplete: MeshInstance3D
@onready var ring_success: AudioStreamPlayer3D = $"../AudioStreamPlayers/RingSuccess"

var pipe_values = {}
var pipe_rotations = {}
var solution: Array = [3,2,4]
var solved = false
var is_rotating = false

func _ready() -> void:
	pipe_values = {pipe_1:1,pipe_2:1,pipe_3:1}
	pipe_rotations = {pipe_1:30.0,pipe_2:30.0,pipe_3:30.0}

func _on_player_rotate(direction: String, pipe: StaticBody3D) -> void:
	if is_rotating: return
	var pipe_value = pipe_values.get(pipe)
	if(direction == "right"):
		if pipe_value<=1: pipe_value=4
		else: pipe_value = pipe_value-1
		pipe_rotations.set(pipe,pipe_rotations.get(pipe)-90.0)
		var tween = get_tree().create_tween()
		is_rotating=true
		tween.tween_property(pipe,"rotation_degrees:y",pipe_rotations.get(pipe),1)
		await tween.finished
		pipe_values.set(pipe,pipe_value)
		is_rotating=false
		if _check_solution():
			_on_puzzle_completion()
	if(direction == "left"):
		if pipe_value>=4: pipe_value=1
		else: pipe_value = pipe_value+1
		pipe_rotations.set(pipe,pipe_rotations.get(pipe)+90.0)
		var tween = get_tree().create_tween()
		is_rotating=true
		tween.tween_property(pipe,"rotation_degrees:y",pipe_rotations.get(pipe),1)
		await tween.finished
		pipe_values.set(pipe,pipe_value)
		is_rotating=false
		if _check_solution():
			_on_puzzle_completion()

func _check_solution():
	var values = pipe_values.values()
	print(values)
	for i in range(values.size()):
		if values[i] != solution[i]:
			return false
	return true
	
func _on_puzzle_completion():
	print("alchemy puzzle completed")
	alchemy_container_completed.visible = true
	alchemy_container_uncomplete.visible = false
	alchemy_container_completed.find_child("CollisionShape3D", false, false).disabled = false
	pipe_1.find_child("CollisionShape3D", false, false).disabled = true
	pipe_2.find_child("CollisionShape3D", false, false).disabled = true
	pipe_3.find_child("CollisionShape3D", false, false).disabled = true
	ring_success.play()
	GameState.set_item_repaired("AlchemyContainer")
