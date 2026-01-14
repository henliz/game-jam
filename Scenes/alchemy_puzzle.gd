extends Node3D

@onready var pipe_1: StaticBody3D = $Pipe1
@onready var pipe_2: StaticBody3D = $Pipe2
@onready var pipe_3: StaticBody3D = $Pipe3
@onready var pipe_4: StaticBody3D = $Pipe4
@onready var pipe_5: StaticBody3D = $Pipe5

@onready var portal: Area3D = $"../Map/portal"

var pipe_values_dict = {}
var solution: Array = [2,2,2,2,2]
var solved = false
var is_rotating = false

func _ready() -> void:
	pipe_values_dict = {pipe_1:1,pipe_2:2,pipe_3:1,pipe_4:1,pipe_5:2}

func _on_player_rotate(direction: String, pipe: StaticBody3D) -> void:
	if is_rotating: return
	var pipe_value = pipe_values_dict.get(pipe)
	if(direction == "left"):
		if pipe_value<=1: pipe_value=4
		var tween = get_tree().create_tween()
		is_rotating=true
		tween.tween_property(pipe,"rotation_degrees:z",90.0*pipe_value,1)
		await tween.finished
		pipe_values_dict.set(pipe,pipe_value-1)
		is_rotating=false
		if _check_solution():
			portal.visible=false
	if(direction == "right"):
		if pipe_value>=4: pipe_value=1
		var tween = get_tree().create_tween()
		is_rotating=true
		tween.tween_property(pipe,"rotation_degrees:z",90.0*pipe_value,1)
		await tween.finished
		pipe_values_dict.set(pipe,pipe_value+1)
		is_rotating=false
		if _check_solution():
			portal.visible=false

func _check_solution():
	var is_correct = true
	var values = pipe_values_dict.values()
	for i in range(values.size()):
		if values[i] != solution[i]:
			return !is_correct
	return is_correct
