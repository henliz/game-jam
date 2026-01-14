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

func _ready() -> void:
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

func clean_at_uv(uv: Vector2) -> void:
	if is_complete:
		return

	var px = int(uv.x * mask_resolution)
	var py = int(uv.y * mask_resolution)
	var brush_radius = int(brush_size / 2.0)
	var pixels_cleaned = 0

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

			if current > 0.01 and new_value < 0.01:
				pixels_cleaned += 1

			mask_image.set_pixel(dx, dy, Color(new_value, new_value, new_value))

	clean_pixels += pixels_cleaned
	dirt_mask_texture.update(mask_image)

	var progress = float(clean_pixels) / float(total_pixels)
	cleaning_progress_changed.emit(progress)

	if progress >= 0.95 and not is_complete:
		is_complete = true
		cleaning_complete.emit()

func get_cleaning_progress() -> float:
	return float(clean_pixels) / float(total_pixels)

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
