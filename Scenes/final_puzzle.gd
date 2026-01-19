extends Node3D

var is_active = false
@export var puzzle_camera: Camera3D
signal finalpuzzle_closed

@onready var canvas_layer: CanvasLayer = $CanvasLayer

var draggingCollider
var mousePosition
var dragging = false

func _ready() -> void:
	pass

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("close") && is_active:
		finalpuzzle_closed.emit()
		is_active = false
		canvas_layer.visible = false

func _input(event):
	if !is_active: return
	var intersect
	
	if event is InputEventMouse:
		intersect = get_mouse_intersect(event.position)
		if intersect: mousePosition = intersect.position
		
	if event is InputEventMouseButton:
		var leftButtonPressed = event.button_index == MOUSE_BUTTON_LEFT && event.pressed
		var leftButtonReleased = event.button_index == MOUSE_BUTTON_LEFT && !event.pressed
		
		if leftButtonReleased:
			dragging = false
			drag_and_drop(intersect)
		elif leftButtonPressed:
			dragging = true
			drag_and_drop(intersect)
			
func drag_and_drop(intersect):
	if !intersect: return
	print(intersect.collider)
	var canMove = intersect.collider in get_tree().get_nodes_in_group("inscription")
	if !draggingCollider && dragging && canMove:
		draggingCollider = intersect.collider
	elif draggingCollider:
		draggingCollider = null
			
func get_mouse_intersect(mouseEventPosition):
	var params = PhysicsRayQueryParameters3D.new()
	params.from = puzzle_camera.project_ray_origin(mouseEventPosition)
	params.to = puzzle_camera.project_position(mouseEventPosition,10)
	
	var world = get_world_3d().direct_space_state
	var result = world.intersect_ray(params)
	
	return result

func _on_player_finalpuzzle_camera_trigger() -> void:
	puzzle_camera.current=true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	is_active = true
	canvas_layer.visible = true
