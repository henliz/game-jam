class_name Cleanable
extends Node

signal cleaning_progress_changed(progress: float)
signal cleaning_complete

@export var mask_resolution: int = 512
@export var brush_size: float = 32.0
@export var brush_softness: float = 0.5
@export var dirt_shader: Shader
@export var dirt_texture: Texture2D
@export var dirt_tint: Color = Color(0.4, 0.35, 0.3, 1.0)

var mask_image: Image
var dirt_mask_texture: ImageTexture
var overlay_material: ShaderMaterial
var mesh_instance: MeshInstance3D
var dirt_mesh: MeshInstance3D

var total_pixels: int = 0
var clean_pixels: int = 0
var is_complete: bool = false
var item_id: String = ""

const FIRST_CLEAN_DIALOGUE_ID := "F1FirstItemCleaned"

func _ready() -> void:

	_resolve_item_id()

	# Check if already cleaned in GameState
	if item_id and GameState.is_item_cleaned(item_id):
		is_complete = true
		print("Cleanable: ", item_id, " already cleaned, skipping dirt setup")
		return

	# Search from parent to find sibling MeshInstance3D nodes
	var search_root = get_parent() if get_parent() else self
	mesh_instance = _find_mesh_instance(search_root)
	if not mesh_instance:
		push_error("Cleanable: No MeshInstance3D found in parent or siblings")
		return

	print("Cleanable: Found mesh instance: ", mesh_instance.name)
	_setup_dirt_overlay()
	_calculate_initial_state()

func _setup_dirt_overlay() -> void:
	mask_image = Image.create(mask_resolution, mask_resolution, false, Image.FORMAT_L8)
	mask_image.fill(Color.WHITE)

	dirt_mask_texture = ImageTexture.create_from_image(mask_image)

	overlay_material = ShaderMaterial.new()
	if dirt_shader:
		overlay_material.shader = dirt_shader
	else:
		overlay_material.shader = load("res://resource/dirt_overlay_3d.gdshader")

	overlay_material.set_shader_parameter("dirt_mask", dirt_mask_texture)
	overlay_material.set_shader_parameter("dirt_strength", 0.8)
	overlay_material.set_shader_parameter("dirt_tint", dirt_tint)

	# Create a duplicate mesh for the dirt layer
	dirt_mesh = MeshInstance3D.new()
	dirt_mesh.mesh = mesh_instance.mesh
	dirt_mesh.name = "DirtOverlay"

	# Apply dirt material to all surfaces
	var surface_count = dirt_mesh.mesh.get_surface_count() if dirt_mesh.mesh else 0
	for i in range(surface_count):
		dirt_mesh.set_surface_override_material(i, overlay_material)

	# Add as sibling, copy transform
	mesh_instance.add_sibling(dirt_mesh)
	dirt_mesh.transform = mesh_instance.transform

	print("Cleanable: Created dirt overlay mesh with ", surface_count, " surfaces")

func _calculate_initial_state() -> void:
	total_pixels = mask_resolution * mask_resolution
	clean_pixels = 0
	_build_uv_coverage_mask()

var uv_coverage_mask: Image

func _build_uv_coverage_mask() -> void:
	# Create a mask of which pixels are actually covered by UV2
	uv_coverage_mask = Image.create(mask_resolution, mask_resolution, false, Image.FORMAT_L8)
	uv_coverage_mask.fill(Color.BLACK)

	if not mesh_instance or not mesh_instance.mesh:
		uv_coverage_mask.fill(Color.WHITE)
		return

	var mesh: Mesh = mesh_instance.mesh
	for surface_idx in range(mesh.get_surface_count()):
		var arrays = mesh.surface_get_arrays(surface_idx)
		if arrays.is_empty():
			continue

		var indices = arrays[Mesh.ARRAY_INDEX]
		var uv2_array: PackedVector2Array
		if arrays.size() > Mesh.ARRAY_TEX_UV2 and arrays[Mesh.ARRAY_TEX_UV2] != null:
			uv2_array = arrays[Mesh.ARRAY_TEX_UV2]
		if uv2_array.is_empty() and arrays.size() > Mesh.ARRAY_TEX_UV and arrays[Mesh.ARRAY_TEX_UV] != null:
			uv2_array = arrays[Mesh.ARRAY_TEX_UV]
		if uv2_array.is_empty():
			continue

		# Rasterize each triangle into the coverage mask
		var tri_count = indices.size() / 3 if indices.size() > 0 else uv2_array.size() / 3
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

			var uv0 = uv2_array[i0]
			var uv1 = uv2_array[i1]
			var uv2 = uv2_array[i2]
			_rasterize_triangle(uv0, uv1, uv2)

	# Count covered pixels
	var covered = 0
	for y in range(mask_resolution):
		for x in range(mask_resolution):
			if uv_coverage_mask.get_pixel(x, y).r > 0.5:
				covered += 1
	print("Cleanable: UV coverage ", covered, "/", total_pixels, " pixels (", float(covered) / float(total_pixels) * 100, "%)")

func _rasterize_triangle(uv0: Vector2, uv1: Vector2, uv2: Vector2) -> void:
	# Convert UV to pixel coords
	var p0 = Vector2(uv0.x * mask_resolution, uv0.y * mask_resolution)
	var p1 = Vector2(uv1.x * mask_resolution, uv1.y * mask_resolution)
	var p2 = Vector2(uv2.x * mask_resolution, uv2.y * mask_resolution)

	# Get bounding box
	var min_x = int(max(0, min(p0.x, min(p1.x, p2.x))))
	var max_x = int(min(mask_resolution - 1, max(p0.x, max(p1.x, p2.x))))
	var min_y = int(max(0, min(p0.y, min(p1.y, p2.y))))
	var max_y = int(min(mask_resolution - 1, max(p0.y, max(p1.y, p2.y))))

	# Rasterize with edge function
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var p = Vector2(x + 0.5, y + 0.5)
			if _point_in_triangle(p, p0, p1, p2):
				uv_coverage_mask.set_pixel(x, y, Color.WHITE)

func clean_at_uv(uv: Vector2) -> void:
	if is_complete:
		return

	var px = int(uv.x * mask_resolution)
	var py = int(uv.y * mask_resolution)
	var brush_radius = int(brush_size / 2.0)

	for x in range(-brush_radius, brush_radius + 1):
		for y in range(-brush_radius, brush_radius + 1):
			var dx = px + x
			var dy = py + y

			if dx < 0 or dx >= mask_resolution or dy < 0 or dy >= mask_resolution:
				continue

			var dist = sqrt(float(x * x + y * y)) / float(brush_radius)
			if dist > 1.0:
				continue

			var current = mask_image.get_pixel(dx, dy).r
			if current < 0.01:
				continue

			# Soft brush falloff
			var falloff = 1.0 - (dist * brush_softness)
			var clean_amount = clamp(falloff, 0.0, 1.0)
			var new_value = max(current - clean_amount, 0.0)

			mask_image.set_pixel(dx, dy, Color(new_value, new_value, new_value))

	dirt_mask_texture.update(mask_image)

	# Calculate actual progress by measuring remaining dirt
	var progress = _calculate_clean_progress()
	cleaning_progress_changed.emit(progress)

	if progress >= 0.95 and not is_complete:
		is_complete = true
		cleaning_complete.emit()
		dirt_mesh.queue_free()
		DialogueManager.try_trigger_dialogue("item_first_clean", FIRST_CLEAN_DIALOGUE_ID)

func _point_in_triangle(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var d1 = _sign(p, a, b)
	var d2 = _sign(p, b, c)
	var d3 = _sign(p, c, a)
	var has_neg = (d1 < 0) or (d2 < 0) or (d3 < 0)
	var has_pos = (d1 > 0) or (d2 > 0) or (d3 > 0)
	return not (has_neg and has_pos)

func _sign(p1: Vector2, p2: Vector2, p3: Vector2) -> float:
	return (p1.x - p3.x) * (p2.y - p3.y) - (p2.x - p3.x) * (p1.y - p3.y)

func _calculate_clean_progress() -> float:
	var total_dirt: float = 0.0
	var covered_pixels: int = 0
	for y in range(mask_resolution):
		for x in range(mask_resolution):
			if uv_coverage_mask and uv_coverage_mask.get_pixel(x, y).r > 0.5:
				covered_pixels += 1
				total_dirt += mask_image.get_pixel(x, y).r
	if covered_pixels == 0:
		return 0.0
	return 1.0 - (total_dirt / float(covered_pixels))

func get_cleaning_progress() -> float:
	return _calculate_clean_progress()

func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var result = _find_mesh_instance(child)
		if result:
			return result
	return null

func set_dirt_texture(texture: Texture2D) -> void:
	if overlay_material:
		overlay_material.set_shader_parameter("dirt_texture", texture)

func set_dirt_tint(color: Color) -> void:
	if overlay_material:
		overlay_material.set_shader_parameter("dirt_tint", color)


func _resolve_item_id() -> void:
	var parent = get_parent()
	if parent and parent is Interactable:
		item_id = parent.item_name
	elif parent:
		item_id = parent.name
	print("Cleanable: Resolved item_id = ", item_id)


func mark_cleaned_in_save() -> void:
	if item_id:
		GameState.set_item_cleaned(item_id, true)
		GameState.save_game()
