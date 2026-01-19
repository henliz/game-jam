extends Node3D

var is_active = false
@export var puzzle_camera: Camera3D
signal finalpuzzle_closed

@onready var canvas_layer: CanvasLayer = $CanvasLayer
@onready var inscription_button: TextureButton = $CanvasLayer/Panel/InscriptionButton
@onready var inscription_button_2: TextureButton = $CanvasLayer/Panel/InscriptionButton2
@onready var inscription_button_3: TextureButton = $CanvasLayer/Panel/InscriptionButton3
@onready var inscription_button_4: TextureButton = $CanvasLayer/Panel/InscriptionButton4
@onready var inscription_button_5: TextureButton = $CanvasLayer/Panel/InscriptionButton5
@onready var inscription_button_6: TextureButton = $CanvasLayer/Panel/InscriptionButton6
@onready var inscription_button_7: TextureButton = $CanvasLayer/Panel/InscriptionButton7
@onready var inscription_button_8: TextureButton = $CanvasLayer/Panel/InscriptionButton8
@onready var inscription_button_9: TextureButton = $CanvasLayer/Panel/InscriptionButton9

var dragged_inscription : TextureButton = null

var draggingCollider
var mousePosition
var dragging = false
var is_rotating = false

@onready var mid: StaticBody3D = $Mid
@onready var outer: StaticBody3D = $Outer

var ring_rotation = {}
var completed_rings = {}
var hovered_ring : StaticBody3D = null

var initial_inscription_position = {}

func _ready() -> void:
	ring_rotation = {mid:0,outer:0}
	initial_inscription_position = {
		inscription_button:inscription_button.position,
		inscription_button_2:inscription_button_2.position,
		inscription_button_3:inscription_button_3.position,
		inscription_button_4:inscription_button_4.position,
		inscription_button_5:inscription_button_5.position,
		inscription_button_6:inscription_button_6.position,
		inscription_button_7:inscription_button_7.position,
		inscription_button_8:inscription_button_8.position,
		inscription_button_9:inscription_button_9.position
	}
	inscription_button.pressed.connect(_on_inscription_pressed.bind(inscription_button))
	inscription_button_2.pressed.connect(_on_inscription_pressed.bind("2"))
	inscription_button_3.pressed.connect(_on_inscription_pressed.bind("3"))
	inscription_button_4.pressed.connect(_on_inscription_pressed.bind("4"))
	inscription_button_5.pressed.connect(_on_inscription_pressed.bind("5"))
	inscription_button_6.pressed.connect(_on_inscription_pressed.bind("6"))
	inscription_button_7.pressed.connect(_on_inscription_pressed.bind("7"))
	inscription_button_8.pressed.connect(_on_inscription_pressed.bind("8"))
	inscription_button_9.pressed.connect(_on_inscription_pressed.bind("9"))

func _on_inscription_pressed(button : TextureButton) -> void:
	print(button)
	dragged_inscription = button

func _process(_delta: float) -> void:
	if !is_active: return
	if Input.is_action_just_pressed("close"):
		finalpuzzle_closed.emit()
		is_active = false
		canvas_layer.visible = false
		hovered_ring = null
	if !is_rotating and hovered_ring and Input.is_action_just_pressed("rotate_right"):
			var tween = get_tree().create_tween()
			is_rotating=true
			ring_rotation.set(hovered_ring,ring_rotation.get(hovered_ring)-30.0)
			tween.tween_property(hovered_ring,"rotation_degrees:y",ring_rotation.get(hovered_ring),1)
			await tween.finished
			is_rotating=false
			print(hovered_ring.rotation_degrees.y)
	if !is_rotating and hovered_ring and Input.is_action_just_pressed("rotate_left"):
			var tween = get_tree().create_tween()
			is_rotating=true
			ring_rotation.set(hovered_ring,ring_rotation.get(hovered_ring)+30.0)
			tween.tween_property(hovered_ring,"rotation_degrees:y",ring_rotation.get(hovered_ring),1)
			await tween.finished
			is_rotating=false
			print(hovered_ring.rotation_degrees.y)

func _input(event):
	if !is_active: return
	
	if dragged_inscription:
		var currentMousePos = get_viewport().get_mouse_position()
		var offsetVector = Vector2(30.0, 10.0)
		var finalTexturePos = currentMousePos + offsetVector
		dragged_inscription.set_global_position(finalTexturePos)
		
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

	if intersect and intersect.collider and intersect.collider.is_in_group("finalpuzzle"):
		if intersect.collider.is_in_group("inscriptionslot"): 
			hovered_ring = intersect.collider.get_parent()
		else:
			hovered_ring = intersect.collider


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
	hovered_ring = null
