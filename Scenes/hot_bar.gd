extends HBoxContainer

var slots : Array

func _ready():
	slots = get_children()
	for slot : TextureButton in slots:
		slot.pressed.connect(Inventory.select_slot.bind(slot.get_index()))
	Inventory.item_pickup.connect(_update_hotbar)
	Inventory.change_slot.connect(_highlight_slot)
	_update_hotbar()

func _update_hotbar():
	for slot : TextureButton in slots:
		var item = Inventory.hotbar[slot.get_index()]
		if item: 
			slot.texture_normal = item.icon

func _highlight_slot(slot_index: int):
	for i in range(6):
		slots[i].modulate = Color(1,1,1)
	slots[slot_index].modulate = Color(1.75,1.75,1.75)
