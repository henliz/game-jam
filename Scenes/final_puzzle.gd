extends Node3D

var is_active = false
@export var puzzle_camera: Camera3D
signal finalpuzzle_closed

var draggingCollider
var mousePosition
var dragging = false
var is_rotating = false

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
var dragged_inscription_name : String = ""

@onready var inscription_slot_1: StaticBody3D = $Outer/InscriptionSlot1
@onready var inscription_slot_2: StaticBody3D = $Outer/InscriptionSlot2
@onready var inscription_slot_3: StaticBody3D = $Outer/InscriptionSlot3
@onready var inscription_slot_4: StaticBody3D = $Mid/InscriptionSlot4
@onready var inscription_slot_5: StaticBody3D = $Mid/InscriptionSlot5
@onready var inscription_slot_6: StaticBody3D = $Mid/InscriptionSlot6
@onready var inscription_slot_7: StaticBody3D = $Inner/InscriptionSlot7
@onready var inscription_slot_8: StaticBody3D = $Inner/InscriptionSlot8
@onready var inscription_slot_9: StaticBody3D = $Inner/InscriptionSlot9

var slotted_piece = {}

@onready var mid: StaticBody3D = $Mid
@onready var outer: StaticBody3D = $Outer

var ring_rotation = {}
var completed_rings = {}
var hovered_ring : StaticBody3D = null

var initial_inscription_position = {}

func _ready() -> void:
	ring_rotation = {mid:0,outer:0}
	initial_inscription_position = {
		inscription_button:inscription_button.global_position,
		inscription_button_2:inscription_button_2.global_position,
		inscription_button_3:inscription_button_3.global_position,
		inscription_button_4:inscription_button_4.global_position,
		inscription_button_5:inscription_button_5.global_position,
		inscription_button_6:inscription_button_6.global_position,
		inscription_button_7:inscription_button_7.global_position,
		inscription_button_8:inscription_button_8.global_position,
		inscription_button_9:inscription_button_9.global_position
	}
	inscription_button.pressed.connect(_on_inscription_pressed.bind("OuterFallPiece",inscription_button))
	inscription_button_2.pressed.connect(_on_inscription_pressed.bind("OuterSummerPiece",inscription_button_2))
	inscription_button_3.pressed.connect(_on_inscription_pressed.bind("OuterSpringPiece",inscription_button_3))
	inscription_button_4.pressed.connect(_on_inscription_pressed.bind("MidFallPiece",inscription_button_4))
	inscription_button_5.pressed.connect(_on_inscription_pressed.bind("MidSummerPiece",inscription_button_5))
	inscription_button_6.pressed.connect(_on_inscription_pressed.bind("MidSpringPiece",inscription_button_6))
	inscription_button_7.pressed.connect(_on_inscription_pressed.bind("InnerFallPiece",inscription_button_7))
	inscription_button_8.pressed.connect(_on_inscription_pressed.bind("InnerSummerPiece",inscription_button_8))
	inscription_button_9.pressed.connect(_on_inscription_pressed.bind("InnerSpringPiece",inscription_button_9))
	slotted_piece = {
		inscription_slot_1:null,
		inscription_slot_2:null,
		inscription_slot_3:null,
		inscription_slot_4:null,
		inscription_slot_5:null,
		inscription_slot_6:null,
		inscription_slot_7:null,
		inscription_slot_8:null,
		inscription_slot_9:null
	}

func _on_inscription_pressed(inscription_name: String,button : TextureButton) -> void:
	dragged_inscription_name = inscription_name
	if dragged_inscription: _reset_inscription()
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
	if dragged_inscription and Input.is_action_just_pressed("release"):
		_reset_inscription()

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
		if leftButtonPressed:
			_drop_piece(intersect)

	if intersect and intersect.collider and intersect.collider.is_in_group("finalpuzzle"):
		if intersect.collider.is_in_group("inscriptionslot"): 
			hovered_ring = intersect.collider.get_parent()
		else:
			hovered_ring = intersect.collider

func _reset_inscription():
	dragged_inscription.set_global_position(initial_inscription_position.get(dragged_inscription))
	dragged_inscription = null

func _drop_piece(intersect):
	if !intersect or !dragged_inscription: return
	print(intersect.collider)
	if intersect.collider and intersect.collider.is_in_group("inscriptionslot"):
		var ring_piece = get_node(dragged_inscription_name)
		ring_piece.reparent(intersect.collider.get_parent(),false)
		slotted_piece.set(intersect.collider,ring_piece)
		ring_piece.visible=true
		
		dragged_inscription = null
		dragged_inscription_name = ""
			
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
