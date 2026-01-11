extends Resource
class_name Item

@export var name: String = "Item"
@export_multiline var description: String = "Generic Item"
@export var stackable: bool = false
@export_range(1,9) var quantity: int = 1
@export var icon: Texture2D = preload("res://icon.svg")
@export var mesh_scene: PackedScene
