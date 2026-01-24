extends Node3D

var is_active = false
@export var puzzle_camera: Camera3D
signal finalpuzzle_closed

var draggingCollider
var mousePosition
var dragging = false
var is_rotating = false

@onready var panel: Panel = $CanvasLayer/Panel

@onready var outer_fall_piece: TextureButton = $CanvasLayer/Panel/OuterFallPiece
@onready var outer_summer_piece: TextureButton = $CanvasLayer/Panel/OuterSummerPiece
@onready var outer_spring_piece: TextureButton = $CanvasLayer/Panel/OuterSpringPiece
@onready var mid_fall_piece: TextureButton = $CanvasLayer/Panel/MidFallPiece
@onready var mid_summer_piece: TextureButton = $CanvasLayer/Panel/MidSummerPiece
@onready var mid_spring_piece: TextureButton = $CanvasLayer/Panel/MidSpringPiece
@onready var inner_fall_piece: TextureButton = $CanvasLayer/Panel/InnerFallPiece
@onready var inner_summer_piece: TextureButton = $CanvasLayer/Panel/InnerSummerPiece
@onready var inner_spring_piece: TextureButton = $CanvasLayer/Panel/InnerSpringPiece

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
@onready var inner: StaticBody3D = $Inner

var ring_rotation = {}
var completed_rings = {}
var hovered_ring : StaticBody3D = null

var initial_inscription_position = {}

@onready var ring_insert: AudioStreamPlayer3D = $"../AudioStreamPlayers/RingInsert"
@onready var ring_pick_up: AudioStreamPlayer3D = $"../AudioStreamPlayers/RingPickUp"
@onready var ring_put_down: AudioStreamPlayer3D = $"../AudioStreamPlayers/RingPutDown"
@onready var ring_success: AudioStreamPlayer3D = $"../AudioStreamPlayers/RingSuccess"
@onready var ring_turning: AudioStreamPlayer3D = $"../AudioStreamPlayers/RingTurning"


func _ready() -> void:
	ring_rotation = {inner:0,mid:-150.0,outer:90.0}
	completed_rings = {inner:false,mid:false,outer:false}
	initial_inscription_position = {
		outer_fall_piece:outer_fall_piece.global_position,
		outer_summer_piece:outer_summer_piece.global_position,
		outer_spring_piece:outer_spring_piece.global_position,
		mid_fall_piece:mid_fall_piece.global_position,
		mid_summer_piece:mid_summer_piece.global_position,
		mid_spring_piece:mid_spring_piece.global_position,
		inner_fall_piece:inner_fall_piece.global_position,
		inner_summer_piece:inner_summer_piece.global_position,
		inner_spring_piece:inner_spring_piece.global_position
	}
	outer_fall_piece.pressed.connect(_on_inscription_pressed.bind("OuterFallPiece",outer_fall_piece))
	outer_summer_piece.pressed.connect(_on_inscription_pressed.bind("OuterSummerPiece",outer_summer_piece))
	outer_spring_piece.pressed.connect(_on_inscription_pressed.bind("OuterSpringPiece",outer_spring_piece))
	mid_fall_piece.pressed.connect(_on_inscription_pressed.bind("MidFallPiece",mid_fall_piece))
	mid_summer_piece.pressed.connect(_on_inscription_pressed.bind("MidSummerPiece",mid_summer_piece))
	mid_spring_piece.pressed.connect(_on_inscription_pressed.bind("MidSpringPiece",mid_spring_piece))
	inner_fall_piece.pressed.connect(_on_inscription_pressed.bind("InnerFallPiece",inner_fall_piece))
	inner_summer_piece.pressed.connect(_on_inscription_pressed.bind("InnerSummerPiece",inner_summer_piece))
	inner_spring_piece.pressed.connect(_on_inscription_pressed.bind("InnerSpringPiece",inner_spring_piece))
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
	if dragged_inscription: _reset_inscription(true)
	dragged_inscription = button
	ring_pick_up.play()

func _process(_delta: float) -> void:
	if !is_active: return
	if Input.is_action_just_pressed("close"):
		finalpuzzle_closed.emit()
		is_active = false
		panel.visible = false
		hovered_ring = null
	if !is_rotating and hovered_ring and hovered_ring!=inner and Input.is_action_just_pressed("rotate_right"):
		if completed_rings.get(hovered_ring):
			is_rotating=true
			if ring_turning.playing: ring_turning.stop()
			ring_turning.play()
			var tween = get_tree().create_tween()
			ring_rotation.set(hovered_ring,ring_rotation.get(hovered_ring)-30.0)
			tween.tween_property(hovered_ring,"rotation_degrees:y",ring_rotation.get(hovered_ring),1)
			await tween.finished
			is_rotating=false
			check_puzzle_complete()
			print(hovered_ring.rotation_degrees.y)
		else:
			print("ring not complete")
	if !is_rotating and hovered_ring and hovered_ring!=inner and Input.is_action_just_pressed("rotate_left"):
		if completed_rings.get(hovered_ring):	
			is_rotating=true
			if ring_turning.playing: ring_turning.stop()
			ring_turning.play()
			var tween = get_tree().create_tween()
			ring_rotation.set(hovered_ring,ring_rotation.get(hovered_ring)+30.0)
			tween.tween_property(hovered_ring,"rotation_degrees:y",ring_rotation.get(hovered_ring),1)
			await tween.finished
			is_rotating=false
			check_puzzle_complete()
			print(hovered_ring.rotation_degrees.y)
		else:
			print("ring not complete")
	if dragged_inscription and Input.is_action_just_pressed("release"):
		_reset_inscription(true)
		ring_put_down.play()

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

func _reset_inscription(stay_visible: bool):
	dragged_inscription.set_global_position(initial_inscription_position.get(dragged_inscription))
	dragged_inscription.visible = stay_visible
	dragged_inscription = null

func _drop_piece(intersect):
	if !intersect or !hovered_ring: return
	if intersect.collider and intersect.collider.is_in_group("inscriptionslot"):
		if dragged_inscription and !slotted_piece.get(intersect.collider) and dragged_inscription_name.begins_with(hovered_ring.name):
			var ring_piece = intersect.collider.get_node(dragged_inscription_name)
			ring_piece.visible=true
			slotted_piece.set(intersect.collider,ring_piece)
			_reset_inscription(false)
			ring_insert.play()
			dragged_inscription_name = ""
			check_completed_rings()
			check_puzzle_complete()
			return
		if !dragged_inscription and slotted_piece.get(intersect.collider):
			var ring_piece = slotted_piece.get(intersect.collider)
			ring_piece.visible=false
			slotted_piece.set(intersect.collider,null)
			dragged_inscription = panel.get_node(NodePath(ring_piece.name))
			dragged_inscription_name = ring_piece.name
			var currentMousePos = get_viewport().get_mouse_position()
			var offsetVector = Vector2(30.0, 10.0)
			var finalTexturePos = currentMousePos + offsetVector
			dragged_inscription.set_global_position(finalTexturePos)
			dragged_inscription.visible = true
			ring_pick_up.play()
			return

func get_mouse_intersect(mouseEventPosition):
	var params = PhysicsRayQueryParameters3D.new()
	params.from = puzzle_camera.project_ray_origin(mouseEventPosition)
	params.to = puzzle_camera.project_position(mouseEventPosition,10)
	
	var world = get_world_3d().direct_space_state
	var result = world.intersect_ray(params)
	
	return result
	
func check_completed_rings():
	if slotted_piece.get(inscription_slot_1) and slotted_piece.get(inscription_slot_2) and slotted_piece.get(inscription_slot_3):
		completed_rings.set(outer,slotted_piece.get(inscription_slot_1).name == "OuterFallPiece" and slotted_piece.get(inscription_slot_2).name == "OuterSummerPiece" and slotted_piece.get(inscription_slot_3).name == "OuterSpringPiece")
	if slotted_piece.get(inscription_slot_4) and slotted_piece.get(inscription_slot_5) and slotted_piece.get(inscription_slot_6):
		completed_rings.set(mid,slotted_piece.get(inscription_slot_4).name == "MidFallPiece" and slotted_piece.get(inscription_slot_5).name == "MidSummerPiece" and slotted_piece.get(inscription_slot_6).name == "MidSpringPiece")
	if slotted_piece.get(inscription_slot_7) and slotted_piece.get(inscription_slot_8) and slotted_piece.get(inscription_slot_9):
		completed_rings.set(inner,slotted_piece.get(inscription_slot_7).name == "InnerFallPiece" and slotted_piece.get(inscription_slot_8).name == "InnerSummerPiece" and slotted_piece.get(inscription_slot_9).name == "InnerSpringPiece")
	print(completed_rings)
	
func check_puzzle_complete():
	for ring in completed_rings.keys():
		if !completed_rings.get(ring): return false
	for r in ring_rotation.values():
		if fmod(r,360.0) != 0.0: return false
	ring_success.play()
	print("final puzzle is complete")
	return true
			
func _on_player_finalpuzzle_camera_trigger() -> void:
	puzzle_camera.current=true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	is_active = true
	panel.visible = true
	hovered_ring = null
