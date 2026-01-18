extends Node3D
class_name GlowOutline

@export var glow_color: Color = Color(0.4, 0.6, 1.0, 1.0)
@export var glow_width: float = 8.0
@export var interaction_range: float = 1.0
@export var use_shader: bool = true  # Toggle between shader and StandardMaterial3D

var glow_overlay: MeshInstance3D
var glow_material: ShaderMaterial
var is_glowing: bool = false
var mesh_instance: MeshInstance3D


func _ready() -> void:
	# Find the mesh - search self and children
	# Note: Script extends Node3D but may be attached to a MeshInstance3D
	mesh_instance = _find_mesh_instance(self)

	if not mesh_instance:
		push_error("GlowOutline: No MeshInstance3D found in node or children")
		return

	print("GlowOutline: Found mesh '", mesh_instance.name, "' on node '", name, "'")
	_setup_glow_overlay()
	_setup_interaction_area()


func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var result = _find_mesh_instance(child)
		if result:
			return result
	return null


func _setup_glow_overlay() -> void:
	glow_overlay = MeshInstance3D.new()
	glow_overlay.mesh = mesh_instance.mesh
	glow_overlay.visible = false
	glow_overlay.name = "GlowOverlay"

	if use_shader:
		# Pixel-perfect outline shader approach
		var shader = load("res://resource/Shaders/outline_glow.gdshader")
		glow_material = ShaderMaterial.new()
		glow_material.shader = shader
		glow_material.set_shader_parameter("outline_color", glow_color)
		glow_material.set_shader_parameter("outline_width", glow_width)
		glow_overlay.material_override = glow_material
	else:
		# StandardMaterial3D fallback with grow/emission
		var material = StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = glow_color
		material.emission_enabled = true
		material.emission = glow_color
		material.emission_energy_multiplier = 2.0
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color.a = 0.6
		material.grow = true
		material.grow_amount = 0.02
		material.cull_mode = BaseMaterial3D.CULL_FRONT
		glow_overlay.material_override = material
		glow_material = null

	mesh_instance.add_child(glow_overlay)
	glow_overlay.transform = Transform3D.IDENTITY


func _setup_interaction_area() -> void:
	var area = Area3D.new()
	var collision = CollisionShape3D.new()
	var sphere = SphereShape3D.new()

	sphere.radius = interaction_range
	collision.shape = sphere
	area.add_child(collision)
	add_child(area)

	# Set collision mask to detect layer 1 (default layer where player typically is)
	area.collision_layer = 0  # Area doesn't need to be detected by others
	area.collision_mask = 1   # Detect objects on layer 1 (player)

	# Connect signals
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

	print("GlowOutline: Interaction area setup - radius: ", interaction_range)

func _on_body_entered(body: Node3D) -> void:
	print("GlowOutline: Body entered - ", body.name, " groups: ", body.get_groups())
	if body.is_in_group("player"):
		print("GlowOutline: Player detected! Enabling glow.")
		enable_glow()

func _on_body_exited(body: Node3D) -> void:
	print("GlowOutline: Body exited - ", body.name)
	if body.is_in_group("player"):
		disable_glow()

func enable_glow() -> void:
	is_glowing = true
	glow_overlay.visible = true

func disable_glow() -> void:
	is_glowing = false
	glow_overlay.visible = false
