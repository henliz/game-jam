extends Node3D


@onready var plate_1: StaticBody3D = $Plate1
@onready var plate_2: StaticBody3D = $Plate2
@onready var plate_3: StaticBody3D = $Plate3
@onready var globe_sphere: MeshInstance3D = $GlobeSphere

@onready var solved_sphere: Interactable = $SolvedSphere

@onready var ring_success: AudioStreamPlayer3D = $"../AudioStreamPlayers/RingSuccess"
@onready var ring_turning: AudioStreamPlayer3D = $"../AudioStreamPlayers/RingTurning"

var plate_rotation_values = {}
var is_rotating = false

func _ready() -> void:
	plate_rotation_values = {plate_1:135.0,plate_2:-90.0,plate_3:45.0}

func _on_player_rotate_plate(direction: Variant, plate: Variant) -> void:
	if is_rotating: return
	if(direction == "left"):
		_rotate(plate,-45.0)
	if(direction == "right"):
		_rotate(plate,45.0)
			
func _rotate(plate: StaticBody3D, increment: float):
	var tween = get_tree().create_tween()
	is_rotating=true
	if ring_turning.playing: ring_turning.stop()
	ring_turning.play()
	plate_rotation_values.set(plate,plate_rotation_values.get(plate)+increment)
	tween.tween_property(plate,"rotation_degrees:y",plate_rotation_values.get(plate),1)
	await tween.finished
	is_rotating=false
	if _check_solution():
		_on_puzzle_solved()

func _check_solution():
	var values = plate_rotation_values.values()
	for r in values:
		if fmod(r,360.0) != 0.0:
			return false
	
	return true
	
func _on_puzzle_solved():
	ring_success.play()
	plate_1.queue_free()
	plate_2.queue_free()
	plate_3.queue_free()
	globe_sphere.queue_free()
	solved_sphere.visible=true
