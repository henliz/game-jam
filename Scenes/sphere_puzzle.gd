extends Node3D


@onready var plate_1: StaticBody3D = $Plate1
@onready var plate_2: StaticBody3D = $Plate2
@onready var plate_3: StaticBody3D = $Plate3
@onready var plate_4: StaticBody3D = $Plate4
@onready var plate_5: StaticBody3D = $Plate5

@onready var door: CSGBox3D = $"../Map/Cabin/Door"

var plate_values_dict = {}
var solution: Array = [3,2,1,2,3]
var solved = false
var is_rotating = false

func _ready() -> void:
	plate_values_dict = {plate_1:1,plate_2:1,plate_3:1,plate_4:1,plate_5:1}

func _on_player_rotate(direction: String, plate: StaticBody3D) -> void:
	if is_rotating: return
	var plate_value = plate_values_dict.get(plate)
	if(direction == "left"):
		if plate_value>=3: return
		var tween = get_tree().create_tween()
		is_rotating=true
		tween.tween_property(plate,"rotation_degrees:y",-45.0*plate_value,1)
		await tween.finished
		plate_values_dict.set(plate,plate_value+1)
		is_rotating=false
		if _check_solution():
			door.visible=true
	if(direction == "right"):
		if plate_value<=1: return
		var tween = get_tree().create_tween()
		is_rotating=true
		tween.tween_property(plate,"rotation_degrees:y",-45.0*(plate_value-2),1)
		await tween.finished
		plate_values_dict.set(plate,plate_value-1)
		is_rotating=false
		if _check_solution():
			door.visible=true

func _check_solution():
	var is_correct = true
	var values = plate_values_dict.values()
	for i in range(values.size()):
		if values[i] != solution[i]:
			return !is_correct
	return is_correct
