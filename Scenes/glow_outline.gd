extends Node3D
class_name GlowOutline

@export var glow_color: Color = Color(0.4, 0.6, 1.0, 1.0)
@export var glow_amount: float = 0.02
@export var interaction_range: float = 1.0
@export var target_node: Node3D  ## Assign the GLB root node - will find MeshInstance3D inside
@export var requires_unlock: bool = false  ## If true, requires puzzles_unlocked flag

var glow_overlay: MeshInstance3D
var is_glowing: bool = false
var mesh_instance: MeshInstance3D
var player_in_range: bool = false
var interaction_sphere: SphereShape3D


func _ready() -> void:
	# Use explicitly assigned node if provided, otherwise auto-detect
	if target_node:
		mesh_instance = _find_mesh_instance(target_node)
		print("[GlowOutline] %s: Using target_node '%s', found mesh '%s'" % [get_parent().name if get_parent() else name, target_node.name, mesh_instance.name if mesh_instance else "NONE"])
	else:
		# Search for mesh in self, children, then parent's tree (for sibling nodes)
		mesh_instance = _find_mesh_instance(self)
		if not mesh_instance and get_parent():
			mesh_instance = _find_mesh_instance(get_parent())
		print("[GlowOutline] %s: Auto-detect found mesh '%s'" % [get_parent().name if get_parent() else name, mesh_instance.name if mesh_instance else "NONE"])

	if not mesh_instance:
		push_error("GlowOutline: No MeshInstance3D found in node tree")
		return

	print("[GlowOutline] %s: Mesh resource path = %s" % [get_parent().name if get_parent() else name, mesh_instance.mesh.resource_path if mesh_instance.mesh else "NO MESH"])
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
	print("[GlowOutline] %s: glow_overlay.mesh = %s (id: %s)" % [get_parent().name if get_parent() else name, glow_overlay.mesh.resource_path if glow_overlay.mesh else "NULL", glow_overlay.mesh.get_instance_id() if glow_overlay.mesh else "N/A"])

	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = glow_color
	material.emission_enabled = true
	material.emission = glow_color
	material.emission_energy_multiplier = 2.0
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color.a = 0.6
	material.grow = true
	material.grow_amount = glow_amount
	material.cull_mode = BaseMaterial3D.CULL_FRONT
	glow_overlay.material_override = material

	mesh_instance.add_child(glow_overlay)
	glow_overlay.transform = Transform3D.IDENTITY
	print("[GlowOutline] %s: Added glow_overlay to parent '%s' (path: %s)" % [get_parent().name if get_parent() else name, mesh_instance.name, mesh_instance.get_path()])


func _setup_interaction_area() -> void:
	var area = Area3D.new()
	var collision = CollisionShape3D.new()
	interaction_sphere = SphereShape3D.new()

	interaction_sphere.radius = interaction_range
	collision.shape = interaction_sphere
	area.add_child(collision)
	add_child(area)

	# Set collision mask to detect layer 1 (default layer where player typically is)
	area.collision_layer = 0  # Area doesn't need to be detected by others
	area.collision_mask = 1   # Detect objects on layer 1 (player)

	# Connect signals
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		_update_glow_visibility()

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		_update_glow_visibility()

func _process(_delta: float) -> void:
	if player_in_range:
		_update_glow_visibility()

func _update_glow_visibility() -> void:
	if not glow_overlay:
		return

	var should_glow = player_in_range and not _is_player_inspecting() and _is_unlocked()

	if should_glow != is_glowing:
		is_glowing = should_glow
		glow_overlay.visible = is_glowing


func _is_unlocked() -> bool:
	if not requires_unlock:
		return true
	return GameState.get_flag("puzzles_unlocked", false)

func _is_player_inspecting() -> bool:
	var player = get_tree().get_first_node_in_group("player")
	if player and "inspecting" in player:
		return player.inspecting
	return false

func enable_glow() -> void:
	player_in_range = true
	_update_glow_visibility()

func disable_glow() -> void:
	player_in_range = false
	_update_glow_visibility()


func set_interaction_range(new_range: float) -> void:
	interaction_range = new_range
	if interaction_sphere:
		interaction_sphere.radius = new_range
