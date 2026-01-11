class_name Interactable
extends StaticBody3D

@export var item_name: String = "Item"
@export var inspect_scale: float = 1.0

signal picked_up(item: Interactable)

func get_inspection_mesh() -> Mesh:
	var mesh_instance = _find_mesh_instance(self)
	if mesh_instance:
		return mesh_instance.mesh
	return null

func _find_mesh_instance(node: Node) -> MeshInstance3D:
	for child in node.get_children():
		if child is MeshInstance3D:
			return child
		var result = _find_mesh_instance(child)
		if result:
			return result
	return null

func interact():
	picked_up.emit(self)
