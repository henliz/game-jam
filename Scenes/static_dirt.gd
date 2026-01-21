class_name StaticDirt
extends Node

## Applies a static (non-interactive) dirt visual overlay to all MeshInstance3D
## descendants. Used for visual consistency on items that aren't being cleaned yet.

@export var dirt_strength: float = 0.4
@export var dirt_tint: Color = Color(0.4, 0.35, 0.3, 1.0)

var _dirt_meshes: Array[MeshInstance3D] = []

func _ready() -> void:
	# Delay to ensure scene tree is ready
	call_deferred("_apply_dirt_to_all")


func _apply_dirt_to_all() -> void:
	var parent = get_parent()
	if not parent:
		push_error("StaticDirt: No parent node found")
		return

	# First, collect all target meshes (before we add any dirt meshes)
	var target_meshes: Array[MeshInstance3D] = []
	_collect_meshes(parent, target_meshes)

	# Now apply dirt to each collected mesh
	for mesh_instance in target_meshes:
		_apply_dirt_to_mesh(mesh_instance)

	print("StaticDirt: Applied to ", _dirt_meshes.size(), " meshes")


func _collect_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and node.mesh:
		result.append(node)

	for child in node.get_children():
		_collect_meshes(child, result)


func _apply_dirt_to_mesh(mesh_instance: MeshInstance3D) -> void:
	var dirt_material = ShaderMaterial.new()
	dirt_material.shader = load("res://resource/Shaders/dirt_overlay_3d.gdshader")

	# Create a simple white mask (fully dirty)
	var mask_image = Image.create(64, 64, false, Image.FORMAT_L8)
	mask_image.fill(Color.WHITE)
	var mask_texture = ImageTexture.create_from_image(mask_image)

	dirt_material.set_shader_parameter("dirt_mask", mask_texture)
	dirt_material.set_shader_parameter("dirt_strength", dirt_strength)
	dirt_material.set_shader_parameter("dirt_tint", dirt_tint)
	dirt_material.render_priority = 1

	# Create dirt overlay mesh
	var dirt_mesh = MeshInstance3D.new()
	dirt_mesh.mesh = mesh_instance.mesh
	dirt_mesh.name = "StaticDirtOverlay"

	var surface_count = dirt_mesh.mesh.get_surface_count() if dirt_mesh.mesh else 0
	for i in range(surface_count):
		dirt_mesh.set_surface_override_material(i, dirt_material)

	mesh_instance.add_child(dirt_mesh)
	dirt_mesh.transform = Transform3D.IDENTITY
	_dirt_meshes.append(dirt_mesh)


func clear_dirt() -> void:
	for dirt_mesh in _dirt_meshes:
		if is_instance_valid(dirt_mesh):
			dirt_mesh.queue_free()
	_dirt_meshes.clear()
