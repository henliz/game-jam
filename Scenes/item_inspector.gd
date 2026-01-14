class_name ItemInspector
extends CanvasLayer

signal closed
signal cleaning_progress_updated(progress: float)
signal item_cleaned

@onready var background: ColorRect = $Background
@onready var cleaning_ui: Control = $CleaningUI
@onready var progress_bar: ProgressBar = $CleaningUI/ProgressContainer/ProgressBar
@onready var progress_label: Label = $CleaningUI/ProgressContainer/Label

var inspected_node: Node3D
var original_parent: Node
var original_transform: Transform3D
var camera: Camera3D
var cleanable: Cleanable

var is_active: bool = false
var is_dragging: bool = false
var is_cleaning: bool = false
var rotation_sensitivity: float = 0.005

var target_transform: Transform3D
var slide_duration: float = 0.4
var slide_progress: float = 0.0
var animating_in: bool = false
var animating_out: bool = false

func _ready():
	visible = false
	cleaning_ui.visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

func open(item: Node3D, cam: Camera3D, scale_factor: float = 1.0):
	camera = cam
	inspected_node = item
	original_parent = item.get_parent()
	original_transform = item.global_transform

	cleanable = _find_cleanable(item)
	if cleanable:
		cleanable.cleaning_progress_changed.connect(_on_cleaning_progress)
		cleanable.cleaning_complete.connect(_on_cleaning_complete)
		cleaning_ui.visible = true
		progress_bar.value = cleanable.get_cleaning_progress()
		_update_progress_label(cleanable.get_cleaning_progress())
	else:
		cleaning_ui.visible = false

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
	is_cleaning = false
	animating_out = true
	animating_in = false
	slide_progress = 0.0

	if cleanable:
		if cleanable.cleaning_progress_changed.is_connected(_on_cleaning_progress):
			cleanable.cleaning_progress_changed.disconnect(_on_cleaning_progress)
		if cleanable.cleaning_complete.is_connected(_on_cleaning_complete):
			cleanable.cleaning_complete.disconnect(_on_cleaning_complete)
		cleanable = null

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
		if event.button_index == MOUSE_BUTTON_RIGHT:
			is_dragging = event.pressed
		elif event.button_index == MOUSE_BUTTON_LEFT:
			is_cleaning = event.pressed
			if is_cleaning and cleanable:
				_try_clean_at_mouse()

	if event is InputEventMouseMotion:
		if is_dragging:
			inspected_node.rotate_y(event.relative.x * rotation_sensitivity)
			inspected_node.rotate_x(event.relative.y * rotation_sensitivity)
		elif is_cleaning and cleanable:
			_try_clean_at_mouse()

	if event.is_action_pressed("interact"):
		close()

func _try_clean_at_mouse() -> void:
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_dir = camera.project_ray_normal(mouse_pos)
	var ray_end = ray_origin + ray_dir * 10.0

	var space_state = camera.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collide_with_bodies = true

	var result = space_state.intersect_ray(query)
	if result.is_empty():
		return

	if result.collider != inspected_node:
		return

	# Get UV from raycast - requires mesh to have collision shape matching mesh
	var uv = _get_uv_at_point(result.position, result.normal)
	if uv != Vector2(-1, -1):
		cleanable.clean_at_uv(uv)

func _get_uv_at_point(point: Vector3, _normal: Vector3) -> Vector2:
	var mesh_instance = cleanable.mesh_instance
	if not mesh_instance or not mesh_instance.mesh:
		print("UV lookup: No mesh instance")
		return Vector2(-1, -1)

	var local_point = mesh_instance.to_local(point)
	var mesh: Mesh = mesh_instance.mesh

	var best_uv = Vector2(-1, -1)
	var best_dist = 999999.0

	# Search through all surfaces for the closest triangle
	for surface_idx in range(mesh.get_surface_count()):
		var arrays = mesh.surface_get_arrays(surface_idx)
		if arrays.is_empty():
			continue

		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices = arrays[Mesh.ARRAY_INDEX]

		# Check if UV2 exists in arrays
		var uv2_array: PackedVector2Array
		if arrays.size() > Mesh.ARRAY_TEX_UV2 and arrays[Mesh.ARRAY_TEX_UV2] != null:
			uv2_array = arrays[Mesh.ARRAY_TEX_UV2]

		# Fall back to UV1 if no UV2
		if uv2_array.is_empty():
			if arrays.size() > Mesh.ARRAY_TEX_UV and arrays[Mesh.ARRAY_TEX_UV] != null:
				uv2_array = arrays[Mesh.ARRAY_TEX_UV]
				print("UV lookup: Using UV1 fallback for surface ", surface_idx)

		if vertices.is_empty() or uv2_array.is_empty():
			print("UV lookup: Surface ", surface_idx, " missing data - verts:", vertices.size(), " uvs:", uv2_array.size())
			continue

		# Check each triangle - find the closest one
		var tri_count = indices.size() / 3 if indices.size() > 0 else vertices.size() / 3
		for tri in range(tri_count):
			var i0: int
			var i1: int
			var i2: int
			if indices.size() > 0:
				i0 = indices[tri * 3]
				i1 = indices[tri * 3 + 1]
				i2 = indices[tri * 3 + 2]
			else:
				i0 = tri * 3
				i1 = tri * 3 + 1
				i2 = tri * 3 + 2

			var v0 = vertices[i0]
			var v1 = vertices[i1]
			var v2 = vertices[i2]

			# Calculate distance to triangle center
			var tri_center = (v0 + v1 + v2) / 3.0
			var dist = local_point.distance_to(tri_center)

			if dist < best_dist:
				var bary = _get_barycentric(local_point, v0, v1, v2)
				# More lenient check - just needs to be roughly on the triangle
				if bary.x >= -0.5 and bary.y >= -0.5 and bary.z >= -0.5 and bary.x + bary.y + bary.z > 0.5:
					best_dist = dist
					var uv0 = uv2_array[i0]
					var uv1 = uv2_array[i1]
					var uv2_coord = uv2_array[i2]
					best_uv = uv0 * bary.x + uv1 * bary.y + uv2_coord * bary.z
					best_uv = best_uv.clamp(Vector2.ZERO, Vector2.ONE)

	if best_uv != Vector2(-1, -1):
		print("UV lookup: Found UV ", best_uv, " at dist ", best_dist)
	return best_uv

func _get_barycentric(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var v0 = b - a
	var v1 = c - a
	var v2 = p - a

	var d00 = v0.dot(v0)
	var d01 = v0.dot(v1)
	var d11 = v1.dot(v1)
	var d20 = v2.dot(v0)
	var d21 = v2.dot(v1)

	var denom = d00 * d11 - d01 * d01
	if abs(denom) < 0.0001:
		return Vector3(-1, -1, -1)

	var v = (d11 * d20 - d01 * d21) / denom
	var w = (d00 * d21 - d01 * d20) / denom
	var u = 1.0 - v - w

	return Vector3(u, v, w)

func _find_cleanable(node: Node) -> Cleanable:
	if node is Cleanable:
		return node
	for child in node.get_children():
		var result = _find_cleanable(child)
		if result:
			return result
	return null

func _on_cleaning_progress(progress: float) -> void:
	progress_bar.value = progress
	_update_progress_label(progress)
	cleaning_progress_updated.emit(progress)

func _on_cleaning_complete() -> void:
	progress_label.text = "Cleaned!"
	item_cleaned.emit()

func _update_progress_label(progress: float) -> void:
	var percent = int(progress * 100)
	progress_label.text = "Cleaning: %d%%" % percent
