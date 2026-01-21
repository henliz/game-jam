extends Node3D


@onready var plate_1: StaticBody3D = $Plate1
@onready var plate_2: StaticBody3D = $Plate2
@onready var plate_3: StaticBody3D = $Plate3

@onready var door: CSGBox3D = $"../Map/Cabin/Door"

var plate_rotation_values = {}
var is_rotating = false

func _ready() -> void:
	plate_rotation_values = {plate_1:135,plate_2:-90,plate_3:45}

func _on_player_rotate(direction: String, plate: StaticBody3D) -> void:
	if is_rotating: return
	if(direction == "left"):
		var tween = get_tree().create_tween()
		is_rotating=true
		plate_rotation_values.set(plate,plate_rotation_values.get(plate)-45.0)
		if plate_rotation_values.get(plate) == 360.0 or plate_rotation_values.get(plate) == -360.0: plate_rotation_values.set(plate,0)
		tween.tween_property(plate,"rotation_degrees:y",plate_rotation_values.get(plate),1)
		await tween.finished
		is_rotating=false
		if _check_solution():
			door.visible=true
	if(direction == "right"):
		var tween = get_tree().create_tween()
		is_rotating=true
		plate_rotation_values.set(plate,plate_rotation_values.get(plate)+45.0)
		if plate_rotation_values.get(plate) == 360.0 or plate_rotation_values.get(plate) == -360.0: plate_rotation_values.set(plate,0)
		tween.tween_property(plate,"rotation_degrees:y",plate_rotation_values.get(plate),1)
		await tween.finished
		is_rotating=false
		if _check_solution():
			door.visible=true

func _check_solution():
	var values = plate_rotation_values.values()
	print(values)
	for r in values:
		if r !=0:
			return false
	return true
