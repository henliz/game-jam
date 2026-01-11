extends Node

signal item_pickup
signal change_slot(slot_index: int)

const HOTBAR_SIZE := 6
var hotbar: Array[Item]
var selected_index: int = 0

@onready var hotbar_container: HBoxContainer = $CanvasLayer/HotBar
@onready var fade_timer: Timer = $HotBarFadeTimer

func _init():
	for i in HOTBAR_SIZE:
		hotbar.append(null)
	
func _ready():
	fade_timer.timeout.connect(func():
		create_tween().tween_property(hotbar_container,"modulate:a",0,1.0)
	)

func add_item(item: Item) -> bool:
	hotbar_container.modulate.a = 1.0
	fade_timer.start()
	for i in HOTBAR_SIZE:
		if hotbar[i] == null:
			hotbar[i] = item
			item_pickup.emit()
			change_slot.emit(i)
			return true
	return false
	
func select_slot(index: int):
	hotbar_container.modulate.a = 1.0
	fade_timer.start()
	print(index)
	selected_index = clamp(index, 0, HOTBAR_SIZE-1)
	change_slot.emit(selected_index)
