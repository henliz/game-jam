extends MeshInstance3D

var mask_image: Image
var dirt_mask: ImageTexture

@onready var camera_3d: Camera3D = $"../Player/Head/Camera3D"

var brush_radius = Vector2(5, 5)

@export var size_of_dirt_mask : int = 2048

var mesh_position
var mesh_end
var mesh_height
var mesh_width

var dragging: bool = false

func _ready() -> void:
	mesh_position = self.mesh.get_aabb().position
	mesh_end = self.mesh.get_aabb().end
	mesh_height = abs(mesh_position.x) + abs(mesh_end.x)
	mesh_width = abs(mesh_position.z) + abs(mesh_end.z)

	brush_radius.x = 8.0
	brush_radius.y = 8.0
	
	mask_image = Image.new()  
	mask_image = Image.create(size_of_dirt_mask, size_of_dirt_mask, false, Image.FORMAT_L8)  
	mask_image.fill(Color(1, 1, 1)) 

	dirt_mask = ImageTexture.new()
	dirt_mask = ImageTexture.create_from_image(mask_image)
	
	var override_material: ShaderMaterial = get_surface_override_material(0)
	override_material.set_shader_parameter('dirt_mask', dirt_mask)
	

func _process(_delta: float) -> void:
	if dragging:
		var raycast_hit = raycast_from_mouse(get_viewport().get_mouse_position(), 1)
		if raycast_hit != {} and raycast_hit.collider is StaticBody3D:
			clean_surface(raycast_hit.position)


func clean_surface(brush_position):
	var local_position: Vector3 = to_local(brush_position)
	
	local_position.x = size_of_dirt_mask * (((local_position.x + mesh_height / 2 )/ mesh_height))
	local_position.z = size_of_dirt_mask * (((local_position.z + mesh_width / 2 )/ mesh_width))
	
	for x in range(-brush_radius.x, brush_radius.x):
		for y in range(-brush_radius.y, brush_radius.y):
			
			var dx = x + local_position.x
			var dy = y + local_position.z

			if dx >= 0 and dx < mask_image.get_width() and dy >= 0 and dy < mask_image.get_height():
				mask_image.set_pixel(dx, dy, Color(0, 0, 0))  # Black for cleaned areas
	
	dirt_mask = ImageTexture.create_from_image(mask_image)
	
	var override_material: ShaderMaterial = get_surface_override_material(0)
	override_material.set_shader_parameter('dirt_mask', dirt_mask)


func _unhandled_input(event: InputEvent) -> void:

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.is_pressed():
				dragging = true
				get_viewport().set_input_as_handled()
			elif event.is_released():
				dragging = false
				get_viewport().set_input_as_handled()

func raycast_from_mouse(m_pos, collision_mask):
	var ray_length = 10
	var ray_start = camera_3d.project_ray_origin(m_pos)
	var ray_end = ray_start + camera_3d.project_ray_normal(m_pos) * ray_length
	var world3d : World3D = get_world_3d()
	var space_state = world3d.direct_space_state
	
	if space_state == null:
		return
	
	var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end, collision_mask)
	query.collide_with_areas = true
	
	return space_state.intersect_ray(query)
