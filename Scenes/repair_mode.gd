extends Node3D


@onready var camera_3d: Camera3D = %Camera3D

@onready var player: CharacterBody3D = $".."

@onready var base: Node3D = $"../../WizardBust/wizard_bust_fractured/base"
@onready var face: StaticBody3D = $"../../WizardBust/wizard_bust_fractured/face"
@onready var shoulder: StaticBody3D = $"../../WizardBust/wizard_bust_fractured/shoulder"
@onready var hat_point: StaticBody3D = $"../../WizardBust/wizard_bust_fractured/hat_point"
@onready var head_side: StaticBody3D = $"../../WizardBust/wizard_bust_fractured/head_side"


@onready var bust_click: AudioStreamPlayer3D = $"../../bust_click"

var draggingCollider
var mousePosition
var dragging = false


var correctPositions = {}
var correctCount = 0


func _ready() -> void:
	correctPositions = {face:Vector2(0,0.455),shoulder:Vector2(0.139,0.255),hat_point:Vector2(0,0.696),head_side:Vector2(-0.1,0.506)}

func _input(event):
	if !player.inspecting: return
	var intersect
	
	if event is InputEventMouse:
		intersect = get_mouse_intersect(event.position)
		if intersect: mousePosition = intersect.position
		
	if event is InputEventMouseButton:
		var leftButtonPressed = event.button_index == MOUSE_BUTTON_LEFT && event.pressed
		var leftButtonReleased = event.button_index == MOUSE_BUTTON_LEFT && !event.pressed
		
		if leftButtonReleased:
			dragging = false
			drag_and_drop(intersect,true)
		elif leftButtonPressed:
			dragging = true
			drag_and_drop(intersect,false)


func _process(_delta):
	if !player.inspecting: return
	if draggingCollider:
		draggingCollider.global_position.x = mousePosition.x
		draggingCollider.global_position.y = mousePosition.y
		draggingCollider.position.z = 0

func drag_and_drop(intersect,isDropped):
	if !intersect: return
	print(intersect.collider)
	var canMove = intersect.collider in get_tree().get_nodes_in_group("moveable")
	if !draggingCollider && dragging && canMove:
		draggingCollider = intersect.collider
	elif draggingCollider:
		draggingCollider = null
	if isDropped && correctPositions.get(intersect.collider):
		if Vector2(intersect.collider.position.x,intersect.collider.position.y).distance_to(correctPositions.get(intersect.collider))<0.1:
			intersect.collider.find_child("CollisionShape3D",false,false).disabled = true
			intersect.collider.remove_from_group("moveable")
			intersect.collider.position.x = correctPositions.get(intersect.collider).x
			intersect.collider.position.y = correctPositions.get(intersect.collider).y
			intersect.collider.position.z = 0
			correctCount = correctCount+1
			bust_click.play()

func get_mouse_intersect(mouseEventPosition):
	var params = PhysicsRayQueryParameters3D.new()
	params.from = camera_3d.project_ray_origin(mouseEventPosition)
	params.to = camera_3d.project_position(mouseEventPosition,10)
	
	var world = get_world_3d().direct_space_state
	var result = world.intersect_ray(params)
	
	return result
