class_name ItemInspector
extends CanvasLayer

signal closed

@onready var background: ColorRect = $Background

var inspected_node: Node3D
var original_parent: Node
var original_transform: Transform3D
var camera: Camera3D

var is_active: bool = false
var is_dragging: bool = false
var rotation_sensitivity: float = 0.005

var target_transform: Transform3D
var slide_duration: float = 0.4
var slide_progress: float = 0.0
var animating_in: bool = false
var animating_out: bool = false

func _ready():
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

func open(item: Node3D, cam: Camera3D, scale_factor: float = 1.0):
	camera = cam
	inspected_node = item
	original_parent = item.get_parent()
	original_transform = item.global_transform

	original_parent.remove_child(item)
	camera.add_child(item)

	var inspect_distance = 0.6
	target_transform = Transform3D(Basis().scaled(Vector3.ONE * scale_factor), Vector3(0, 0, -inspect_distance))

	item.transform = camera.global_transform.inverse() * original_transform

	visible = true
	is_active = true
	animating_in = true
	animating_out = false
	slide_progress = 0.0

func close():
	if not is_active:
		return
	is_active = false
	is_dragging = false
	animating_out = true
	animating_in = false
	slide_progress = 0.0

func _process(delta):
	if not visible:
		return

	if animating_in:
		slide_progress += delta / slide_duration
		slide_progress = min(slide_progress, 1.0)
		var t = ease(slide_progress, -2.0)

		var start_local = camera.global_transform.inverse() * original_transform
		inspected_node.transform = start_local.interpolate_with(target_transform, t)

		if slide_progress >= 1.0:
			animating_in = false

	elif animating_out:
		slide_progress += delta / slide_duration
		slide_progress = min(slide_progress, 1.0)
		var t = ease(slide_progress, -2.0)

		var end_local = camera.global_transform.inverse() * original_transform
		inspected_node.transform = target_transform.interpolate_with(end_local, t)

		if slide_progress >= 1.0:
			animating_out = false
			visible = false
			_return_item()
			closed.emit()

func _return_item():
	if inspected_node and is_instance_valid(inspected_node):
		camera.remove_child(inspected_node)
		original_parent.add_child(inspected_node)
		inspected_node.global_transform = original_transform
		inspected_node = null

func _input(event):
	if not is_active or animating_in or animating_out:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_dragging = event.pressed

	if event is InputEventMouseMotion and is_dragging:
		inspected_node.rotate_y(event.relative.x * rotation_sensitivity)
		inspected_node.rotate_x(event.relative.y * rotation_sensitivity)

	if event.is_action_pressed("interact"):
		close()
