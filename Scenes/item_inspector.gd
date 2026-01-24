class_name ItemInspector
extends CanvasLayer

signal opened(item: Node3D)
signal closed
signal cleaning_progress_updated(progress: float)
signal item_cleaned(cleaned_item: Cleanable)

const FIRST_INTERACT_DIALOGUE_ID := "F1FirstTimeCleaningDimension"

@export_group("Cursor Settings")
@export var cloth_cursor_texture: Texture2D = preload("res://resource/UI/cloth_cursor.png")
@export var grab_cursor_texture: Texture2D = preload("res://resource/UI/grab_cursor.png")
@export var cloth_cursor_scale: float = 0.33 # 35% of original asset size
@export var grab_cursor_scale: float = 0.15 # 15% of original asset size
@export var cleaning_rotation_degrees: float = 345.0
@export var cloth_cursor_offset: Vector2 = Vector2(-45, -20)

@export_group("Audio")
@export var cleaning_complete_sound: AudioStream = preload("res://Audio/SFX/Puzzles/ESM_PG_cinematic_fx_magic_collect_shimmer_reveal_particles_swell_01.wav")

var success_audio_player: AudioStreamPlayer

@onready var background: ColorRect = $Background
@onready var cleaning_ui: Control = $CleaningUI
@onready var fill_frame: TextureRect = $CleaningUI/ProgressContainer/FillFrame
@onready var fill_clip: Control = $CleaningUI/ProgressContainer/FillClip  # Has clip_children enabled
@onready var fill_texture: TextureRect = $CleaningUI/ProgressContainer/FillClip/FillTexture
@onready var progress_label: Label = $CleaningUI/ProgressContainer/Label
@onready var repair_ui: Control = $RepairUI

# Fill gauge dimensions (based on your 1920x1080 assets)
var fill_gauge_width: float = 378.0  # Width of the fillable area

var cursor_sprite: TextureRect
var current_cursor_mode: int = 0  # 0=cloth, 1=cleaning, 2=grab

var inspected_node: Node3D
var original_parent: Node
var original_transform: Transform3D
var camera: Camera3D
var cleanable: Cleanable
var placement_node: Node3D  # Workbench item placement position

var is_active: bool = false
var is_dragging: bool = false
var is_cleaning: bool = false
var rotation_enabled: bool = true  # Can be disabled during repair minigames
var rotation_sensitivity: float = 0.005

var target_transform: Transform3D
var slide_duration: float = 0.4
var slide_progress: float = 0.0
var animating_in: bool = false
var animating_out: bool = false

func _ready():
	visible = false
	cleaning_ui.visible = false
	repair_ui.visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_cursor()
	_setup_audio()


func _setup_cursor() -> void:
	cursor_sprite = TextureRect.new()
	cursor_sprite.texture = cloth_cursor_texture
	cursor_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cursor_sprite.stretch_mode = TextureRect.STRETCH_SCALE
	cursor_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cursor_sprite.visible = false
	add_child(cursor_sprite)
	_apply_cursor_scale()


func _setup_audio() -> void:
	success_audio_player = AudioStreamPlayer.new()
	success_audio_player.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
	success_audio_player.stream = cleaning_complete_sound
	add_child(success_audio_player)


func _apply_cursor_scale() -> void:
	if not cursor_sprite or not cursor_sprite.texture:
		return
	var tex_size = cursor_sprite.texture.get_size()
	var cursor_scale = grab_cursor_scale if current_cursor_mode == 2 else cloth_cursor_scale
	cursor_sprite.size = tex_size * cursor_scale
	cursor_sprite.pivot_offset = Vector2.ZERO  # Origin at top-left


func _update_cursor_position() -> void:
	if not cursor_sprite or not cursor_sprite.visible:
		return
	var mouse_pos = get_viewport().get_mouse_position()
	if current_cursor_mode == 2:
		# Center the grab cursor on the mouse
		cursor_sprite.position = mouse_pos - cursor_sprite.size / 2.0
	else:
		# Cloth cursor: offset so the tip aligns with the cursor
		cursor_sprite.position = mouse_pos + cloth_cursor_offset * cloth_cursor_scale


func _set_cursor_mode(mode: int) -> void:
	if current_cursor_mode == mode:
		return
	current_cursor_mode = mode

	match mode:
		0:  # Cloth (idle)
			cursor_sprite.texture = cloth_cursor_texture
			cursor_sprite.rotation = 0
		1:  # Cleaning (rotated cloth)
			cursor_sprite.texture = cloth_cursor_texture
			cursor_sprite.rotation = deg_to_rad(cleaning_rotation_degrees)
		2:  # Grab
			cursor_sprite.texture = grab_cursor_texture
			cursor_sprite.rotation = 0

	_apply_cursor_scale()


func _show_custom_cursor() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	cursor_sprite.visible = true
	_update_cursor_from_state()


func _hide_custom_cursor() -> void:
	cursor_sprite.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _update_cursor_from_state() -> void:
	var is_actively_cleanable = cleanable != null and not cleanable.is_complete

	if is_dragging:
		# Always show grab cursor when rotating
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
		cursor_sprite.visible = true
		_set_cursor_mode(2)  # Grab
	elif is_actively_cleanable:
		# Item needs cleaning - use cloth cursors
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
		cursor_sprite.visible = true
		if is_cleaning:
			_set_cursor_mode(1)  # Cleaning (rotated cloth)
		else:
			_set_cursor_mode(0)  # Cloth (idle)
	else:
		# Item doesn't need cleaning (repaired, already clean, or non-cleanable) - use system cursor
		cursor_sprite.visible = false
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func open(item: Node3D, cam: Camera3D, scale_factor: float = 1.0, placement: Node3D = null):
	camera = cam
	inspected_node = item
	original_parent = item.get_parent()
	original_transform = item.global_transform
	placement_node = placement

	# Disable collision shape to prevent physics interactions during inspection
	_set_collision_enabled(item, false)

	opened.emit(item)

	# Delay dialogue to let workbench animation complete
	get_tree().create_timer(1.5).timeout.connect(
		func(): DialogueManager.try_trigger_dialogue("item_first_interact", FIRST_INTERACT_DIALOGUE_ID)
	)

	# Restore teakettle glow range if it was increased for visibility
	_restore_teakettle_glow_range(item)

	cleanable = _find_cleanable(item)
	if cleanable and not cleanable.is_complete:
		cleanable.cleaning_progress_changed.connect(_on_cleaning_progress)
		cleanable.cleaning_complete.connect(_on_cleaning_complete)
		cleaning_ui.visible = true
		_update_fill_texture(cleanable.get_cleaning_progress())
		_update_progress_label(cleanable.get_cleaning_progress())
	else:
		cleaning_ui.visible = false

	original_parent.remove_child(item)

	# Use workbench placement if provided, otherwise fall back to camera
	if placement_node:
		placement_node.add_child(item)
		# Preserve item's Y rotation relative to camera so it faces the player as it was in the world
		var item_local = placement_node.global_transform.inverse() * original_transform
		item.transform = item_local

		# Extract the item's current Y rotation in placement space and preserve it
		var current_y_rotation = item_local.basis.get_euler().y
		var target_basis = Basis.from_euler(Vector3(0, current_y_rotation, 0)).scaled(Vector3.ONE * scale_factor)

		# Apply inspect_offset if the item is an Interactable
		var offset = Vector3.ZERO
		if item is Interactable:
			offset = item.inspect_offset
		target_transform = Transform3D(target_basis, offset)
	else:
		camera.add_child(item)
		var inspect_distance = 0.6
		target_transform = Transform3D(Basis().scaled(Vector3.ONE * scale_factor), Vector3(0, 0, -inspect_distance))
		item.transform = camera.global_transform.inverse() * original_transform

	visible = true
	is_active = true
	animating_in = true
	animating_out = false
	slide_progress = 0.0
	_show_custom_cursor()

func close():
	if not is_active:
		return

	# Re-enable collision shape when closing
	if inspected_node:
		_set_collision_enabled(inspected_node, true)
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

	_hide_custom_cursor()

func _process(delta):
	if not visible:
		return

	_update_cursor_position()

	if animating_in:
		slide_progress += delta / slide_duration
		slide_progress = min(slide_progress, 1.0)
		var t = ease(slide_progress, -2.0)

		var parent_node = placement_node if placement_node else camera
		var start_local = parent_node.global_transform.inverse() * original_transform
		inspected_node.transform = start_local.interpolate_with(target_transform, t)

		if slide_progress >= 1.0:
			animating_in = false

	elif animating_out:
		slide_progress += delta / slide_duration
		slide_progress = min(slide_progress, 1.0)
		var t = ease(slide_progress, -2.0)

		var parent_node = placement_node if placement_node else camera
		var end_local = parent_node.global_transform.inverse() * original_transform
		inspected_node.transform = target_transform.interpolate_with(end_local, t)

		if slide_progress >= 1.0:
			animating_out = false
			visible = false
			_return_item()
			closed.emit()

func _return_item():
	if inspected_node and is_instance_valid(inspected_node):
		var current_parent = placement_node if placement_node else camera
		current_parent.remove_child(inspected_node)
		original_parent.add_child(inspected_node)
		inspected_node.global_transform = original_transform
		inspected_node = null
	placement_node = null

func _input(event):
	if not is_active or animating_in or animating_out:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			is_dragging = event.pressed
			_update_cursor_from_state()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			is_cleaning = event.pressed
			_update_cursor_from_state()
			if is_cleaning and cleanable and not cleanable.is_complete:
				_try_clean_at_mouse()

	if event is InputEventMouseMotion:
		if is_dragging and rotation_enabled:
			# Rotate around camera axes instead of local axes
			# This ensures drag-up always tilts away from camera regardless of item orientation
			var cam_right = camera.global_transform.basis.x
			var world_up = Vector3.UP

			# Horizontal drag rotates around world Y (up) - spin like a turntable
			inspected_node.global_rotate(world_up, event.relative.x * rotation_sensitivity)
			# Vertical drag rotates around camera's right axis - tilt toward/away from player
			inspected_node.global_rotate(cam_right, event.relative.y * rotation_sensitivity)
		elif is_cleaning and cleanable and not cleanable.is_complete:
			_try_clean_at_mouse()

	if event.is_action_pressed("interact"):
		close()

func _try_clean_at_mouse() -> void:
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_dir = camera.project_ray_normal(mouse_pos)

	# Try direct mesh ray intersection first (more accurate for thin geometry)
	var uv = _raycast_mesh_for_uv(ray_origin, ray_dir)
	if uv != Vector2(-1, -1):
		cleanable.clean_at_uv(uv)

func _raycast_mesh_for_uv(ray_origin: Vector3, ray_dir: Vector3) -> Vector2:
	var mesh_instance = cleanable.mesh_instance
	if not mesh_instance or not mesh_instance.mesh:
		return Vector2(-1, -1)

	# Transform ray to mesh local space
	var inv_transform = mesh_instance.global_transform.affine_inverse()
	var local_origin = inv_transform * ray_origin
	var local_dir = (inv_transform.basis * ray_dir).normalized()

	var mesh: Mesh = mesh_instance.mesh
	var best_uv = Vector2(-1, -1)
	var best_t = 999999.0

	for surface_idx in range(mesh.get_surface_count()):
		var arrays = mesh.surface_get_arrays(surface_idx)
		if arrays.is_empty():
			continue

		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices = arrays[Mesh.ARRAY_INDEX]

		# Use UV1 (primary texture coordinates) to match the dirt shader
		var uv_array: PackedVector2Array
		if arrays.size() > Mesh.ARRAY_TEX_UV and arrays[Mesh.ARRAY_TEX_UV] != null:
			uv_array = arrays[Mesh.ARRAY_TEX_UV]

		if vertices.is_empty() or uv_array.is_empty():
			continue

		var tri_count = indices.size() / 3.0 if indices.size() > 0 else vertices.size() / 3.0
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

			# Ray-triangle intersection (Möller–Trumbore)
			var result = _ray_triangle_intersect(local_origin, local_dir, v0, v1, v2)
			if result.x >= 0.0 and result.x < best_t:
				best_t = result.x
				# result.y and result.z are barycentric u,v coords
				var u = result.y
				var v = result.z
				var w = 1.0 - u - v
				var uv0 = uv_array[i0]
				var uv1 = uv_array[i1]
				var uv2_coord = uv_array[i2]
				best_uv = uv0 * w + uv1 * u + uv2_coord * v
				best_uv = best_uv.clamp(Vector2.ZERO, Vector2.ONE)

	return best_uv

func _ray_triangle_intersect(ray_origin: Vector3, ray_dir: Vector3, v0: Vector3, v1: Vector3, v2: Vector3) -> Vector3:
	# Returns Vector3(t, u, v) where t is distance along ray, u/v are barycentric coords
	# Returns Vector3(-1, 0, 0) if no intersection
	var edge1 = v1 - v0
	var edge2 = v2 - v0
	var h = ray_dir.cross(edge2)
	var a = edge1.dot(h)

	# Check if ray is parallel to triangle (use small epsilon for thin triangles)
	if abs(a) < 0.0000001:
		return Vector3(-1, 0, 0)

	var f = 1.0 / a
	var s = ray_origin - v0
	var u = f * s.dot(h)

	if u < 0.0 or u > 1.0:
		return Vector3(-1, 0, 0)

	var q = s.cross(edge1)
	var v = f * ray_dir.dot(q)

	if v < 0.0 or u + v > 1.0:
		return Vector3(-1, 0, 0)

	var t = f * edge2.dot(q)

	if t > 0.0001:  # Ray intersection (not behind origin)
		return Vector3(t, u, v)

	return Vector3(-1, 0, 0)

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

		# Use UV1 (primary texture coordinates) to match the dirt shader
		var uv_array: PackedVector2Array
		if arrays.size() > Mesh.ARRAY_TEX_UV and arrays[Mesh.ARRAY_TEX_UV] != null:
			uv_array = arrays[Mesh.ARRAY_TEX_UV]

		if vertices.is_empty() or uv_array.is_empty():
			print("UV lookup: Surface ", surface_idx, " missing data - verts:", vertices.size(), " uvs:", uv_array.size())
			continue

		# Check each triangle - find the closest one by actual distance to triangle
		var tri_count = indices.size() / 3.0 if indices.size() > 0 else vertices.size() / 3.0
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

			# Get closest point on triangle and distance
			var closest = _closest_point_on_triangle(local_point, v0, v1, v2)
			var dist = local_point.distance_to(closest)

			if dist < best_dist:
				best_dist = dist
				# Calculate barycentric coords for the closest point to interpolate UVs
				var bary = _get_barycentric(closest, v0, v1, v2)
				var uv0 = uv_array[i0]
				var uv1 = uv_array[i1]
				var uv2_coord = uv_array[i2]
				best_uv = uv0 * bary.x + uv1 * bary.y + uv2_coord * bary.z
				best_uv = best_uv.clamp(Vector2.ZERO, Vector2.ONE)

	if best_uv != Vector2(-1, -1):
		print("UV lookup: Found UV ", best_uv, " at dist ", best_dist)
	return best_uv

func _closest_point_on_triangle(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	# Edge vectors
	var ab = b - a
	var ac = c - a
	var ap = p - a

	# Check if P is in vertex region outside A
	var d1 = ab.dot(ap)
	var d2 = ac.dot(ap)
	if d1 <= 0.0 and d2 <= 0.0:
		return a  # Barycentric coordinates (1,0,0)

	# Check if P is in vertex region outside B
	var bp = p - b
	var d3 = ab.dot(bp)
	var d4 = ac.dot(bp)
	if d3 >= 0.0 and d4 <= d3:
		return b  # Barycentric coordinates (0,1,0)

	# Check if P is in edge region of AB
	var vc = d1 * d4 - d3 * d2
	if vc <= 0.0 and d1 >= 0.0 and d3 <= 0.0:
		var v = d1 / (d1 - d3)
		return a + ab * v  # Barycentric coordinates (1-v,v,0)

	# Check if P is in vertex region outside C
	var cp = p - c
	var d5 = ab.dot(cp)
	var d6 = ac.dot(cp)
	if d6 >= 0.0 and d5 <= d6:
		return c  # Barycentric coordinates (0,0,1)

	# Check if P is in edge region of AC
	var vb = d5 * d2 - d1 * d6
	if vb <= 0.0 and d2 >= 0.0 and d6 <= 0.0:
		var w = d2 / (d2 - d6)
		return a + ac * w  # Barycentric coordinates (1-w,0,w)

	# Check if P is in edge region of BC
	var va = d3 * d6 - d5 * d4
	if va <= 0.0 and (d4 - d3) >= 0.0 and (d5 - d6) >= 0.0:
		var w = (d4 - d3) / ((d4 - d3) + (d5 - d6))
		return b + (c - b) * w  # Barycentric coordinates (0,1-w,w)

	# P is inside face region - project onto triangle plane
	var denom = 1.0 / (va + vb + vc)
	var v_coord = vb * denom
	var w_coord = vc * denom
	return a + ab * v_coord + ac * w_coord

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
		# Skip Cleanables on hidden meshes (e.g., complete_bust before repair)
		var parent = node.get_parent()
		if parent is Node3D and not parent.visible:
			return null
		return node
	for child in node.get_children():
		var result = _find_cleanable(child)
		if result:
			return result
	return null


func switch_to_cleanable(new_cleanable: Cleanable) -> void:
	# Disconnect from old cleanable if connected
	if cleanable:
		if cleanable.cleaning_progress_changed.is_connected(_on_cleaning_progress):
			cleanable.cleaning_progress_changed.disconnect(_on_cleaning_progress)
		if cleanable.cleaning_complete.is_connected(_on_cleaning_complete):
			cleanable.cleaning_complete.disconnect(_on_cleaning_complete)

	# Hide repair UI when switching to cleaning
	repair_ui.visible = false

	cleanable = new_cleanable
	if cleanable and not cleanable.is_complete:
		cleanable.cleaning_progress_changed.connect(_on_cleaning_progress)
		cleanable.cleaning_complete.connect(_on_cleaning_complete)
		cleaning_ui.visible = true
		_update_fill_texture(cleanable.get_cleaning_progress())
		_update_progress_label(cleanable.get_cleaning_progress())
		_update_cursor_from_state()
		print("ItemInspector: Switched to new Cleanable")
	else:
		cleaning_ui.visible = false
		_update_cursor_from_state()


func show_repair_ui() -> void:
	repair_ui.visible = true
	cleaning_ui.visible = false  # Hide cleaning UI when showing repair UI


func hide_repair_ui() -> void:
	repair_ui.visible = false


func _set_collision_enabled(node: Node, enabled: bool) -> void:
	var collision_shape = node.find_child("CollisionShape3D", false, false)
	if collision_shape:
		collision_shape.disabled = not enabled

func _on_cleaning_progress(progress: float) -> void:
	_update_fill_texture(progress)
	_update_progress_label(progress)
	cleaning_progress_updated.emit(progress)

func _on_cleaning_complete() -> void:
	cleaning_ui.visible = false
	if success_audio_player:
		success_audio_player.play()
	if cleanable:
		cleanable.mark_cleaned_in_save()
	item_cleaned.emit(cleanable)
	_update_cursor_from_state()

func _update_progress_label(progress: float) -> void:
	var percent = int(progress * 100)
	progress_label.text = "Cleaning: %d%%" % percent

func _update_fill_texture(progress: float) -> void:
	# Resize the clip container to reveal more of the fill texture
	# The clip container has clip_children=true, so resizing it clips the fill texture
	if fill_clip:
		fill_clip.size.x = fill_gauge_width * progress

func _restore_teakettle_glow_range(item: Node3D) -> void:
	# Check if this item is the teakettle (in the teakettle group)
	if not item.is_in_group("teakettle"):
		return

	var glow = item.get_node_or_null("GlowOutline") as GlowOutline
	if glow and glow.interaction_range == 10.0:
		# Restore to default after player interacts (was boosted to 10.0 by journal to draw attention)
		glow.set_interaction_range(3.0)
		print("ItemInspector: Restored teakettle glow range to 3.0")
