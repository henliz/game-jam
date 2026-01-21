extends Node3D

signal repair_complete

@export_range(0.01, 0.5, 0.01) var snap_distance: float = 0.1  ## How close a piece must be to snap into place

@onready var camera_3d: Camera3D = %Camera3D

@onready var player: CharacterBody3D = $".."

@onready var base: Node3D = $"../../WizardBust/wizard_bust_fractured/base"
@onready var face: StaticBody3D = $"../../WizardBust/wizard_bust_fractured/face"
@onready var shoulder: StaticBody3D = $"../../WizardBust/wizard_bust_fractured/shoulder"
@onready var hat_point: StaticBody3D = $"../../WizardBust/wizard_bust_fractured/hat_point"
@onready var head_side: StaticBody3D = $"../../WizardBust/wizard_bust_fractured/head_side"
@onready var head_back: StaticBody3D = $"../../WizardBust/wizard_bust_fractured/head_back"
@onready var hat_front: StaticBody3D = $"../../WizardBust/wizard_bust_fractured/hat_front"

@onready var complete_bust: MeshInstance3D = $"../../WizardBust/complete_bust"

@onready var wizard_bust_fractured: Node3D = $"../../WizardBust/wizard_bust_fractured"

@onready var bust_click: AudioStreamPlayer3D = $"../../BustClick"

@onready var item_inspector: ItemInspector = $"../ItemInspector"

var draggingCollider
var mousePosition
var dragging = false

var correctPositions = {}
var initialPositions = {}  # Store starting positions for reset
var correctCount = 0
var is_complete: bool = false


var repair_ui_shown: bool = false

func _ready() -> void:
	correctPositions = {face:Vector2(0,0.455),shoulder:Vector2(0.139,0.255),hat_point:Vector2(0,0.696),head_side:Vector2(-0.1,0.506),head_back:Vector2(0.048,0.439),hat_front:Vector2(0.249,0.494)}
	_store_initial_positions()

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

	# R key to reset incomplete pieces
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		reset_incomplete_pieces()


func _process(_delta):
	# Track inspect state to show/hide repair UI
	if player.inspecting and not is_complete:
		if not repair_ui_shown and item_inspector:
			item_inspector.show_repair_ui()
			repair_ui_shown = true
	else:
		if repair_ui_shown and item_inspector:
			item_inspector.hide_repair_ui()
			repair_ui_shown = false

	if !player.inspecting: return
	if draggingCollider:
		var pos = draggingCollider.global_position
		pos.x = mousePosition.x
		pos.y = mousePosition.y
		draggingCollider.global_position = pos
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
		if Vector2(intersect.collider.position.x,intersect.collider.position.y).distance_to(correctPositions.get(intersect.collider)) < snap_distance:
			intersect.collider.find_child("CollisionShape3D",false,false).disabled = true
			intersect.collider.remove_from_group("moveable")
			intersect.collider.position.x = correctPositions.get(intersect.collider).x
			intersect.collider.position.y = correctPositions.get(intersect.collider).y
			intersect.collider.position.z = 0
			correctCount = correctCount+1
			bust_click.play()
			_check_repair_complete()


func _check_repair_complete() -> void:
	if is_complete:
		return
	if correctCount >= correctPositions.size():
		is_complete = true

		# Hide repair UI now that repair is complete
		if item_inspector:
			item_inspector.hide_repair_ui()
			repair_ui_shown = false

		for node in wizard_bust_fractured.get_children():
			node.queue_free()
		complete_bust.reparent(wizard_bust_fractured)
		complete_bust.visible = true
		repair_complete.emit()
		print("RepairMode: Repair complete!")

		# Transition to cleaning mode
		_start_cleaning_mode()

func get_mouse_intersect(mouseEventPosition):
	var params = PhysicsRayQueryParameters3D.new()
	params.from = camera_3d.project_ray_origin(mouseEventPosition)
	params.to = camera_3d.project_position(mouseEventPosition,10)

	var world = get_world_3d().direct_space_state
	var result = world.intersect_ray(params)

	return result


func _store_initial_positions() -> void:
	# Store starting positions of all moveable pieces
	var pieces = [face, shoulder, hat_point, head_side, head_back, hat_front]
	for piece in pieces:
		if piece:
			initialPositions[piece] = piece.position


func reset_incomplete_pieces() -> void:
	if is_complete:
		return

	# Drop any piece being dragged
	draggingCollider = null
	dragging = false

	# Reset only pieces that are still in the "moveable" group (not yet correctly placed)
	for piece in initialPositions.keys():
		if piece and is_instance_valid(piece) and piece.is_in_group("moveable"):
			piece.position = initialPositions[piece]
			print("RepairMode: Reset piece '%s' to initial position" % piece.name)


func _start_cleaning_mode() -> void:
	# Find the Cleanable component on the complete bust
	var bust_cleanable = _find_cleanable(complete_bust)
	if bust_cleanable and item_inspector:
		# Small delay to let the visual swap complete
		await get_tree().create_timer(0.3).timeout
		item_inspector.switch_to_cleanable(bust_cleanable)
		print("RepairMode: Switched to cleaning mode for complete bust")
	else:
		if not bust_cleanable:
			print("RepairMode: No Cleanable found on complete_bust")
		if not item_inspector:
			print("RepairMode: ItemInspector not found")


func _find_cleanable(node: Node) -> Cleanable:
	if node is Cleanable:
		return node
	for child in node.get_children():
		var result = _find_cleanable(child)
		if result:
			return result
	return null
