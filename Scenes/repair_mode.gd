extends Node3D


@onready var camera_3d: Camera3D = %Camera3D

var draggingCollider
var mousePosition
var dragging = false

func _input(event):
	var intersect
	
	if event is InputEventMouse:
		intersect = get_mouse_intersect(event.position)
		if intersect: mousePosition = intersect.position 
		#snap on collider
		#if intersect: mousePosition = intersect.collider.global_position
		
	if event is InputEventMouseButton:
		var leftButtonPressed = event.button_index == MOUSE_BUTTON_LEFT && event.pressed
		var leftButtonReleased = event.button_index == MOUSE_BUTTON_LEFT && !event.pressed
		
		if leftButtonReleased:
			dragging = false
			drag_and_drop(intersect)
		elif leftButtonPressed:
			dragging = true
			drag_and_drop(intersect)


func _process(_delta):
	if draggingCollider:
		print(draggingCollider)
		draggingCollider.global_position = mousePosition

func drag_and_drop(intersect):
	var canMove = intersect.collider in get_tree().get_nodes_in_group("moveable")
	if !draggingCollider && dragging && canMove:
		draggingCollider = intersect.collider
	elif draggingCollider:
		draggingCollider = null

func get_mouse_intersect(mouseEventPosition):
	var params = PhysicsRayQueryParameters3D.new()
	params.from = camera_3d.project_ray_origin(mouseEventPosition)
	params.to = camera_3d.project_position(mouseEventPosition,10)
	
	var world = get_world_3d().direct_space_state
	var result = world.intersect_ray(params)
	
	return result
