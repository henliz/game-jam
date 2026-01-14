extends TextureRect

var open = false
var lerp_speed = 0.1

var opened_position = 500.0
var closed_position = 1200.0
var target_position = closed_position

const DIARY = preload("uid://ddw6so5jr38ps")
const BLUEPRINT = preload("uid://da253rmeoaxdx")

var current_tab = "diary"

func _process(_delta: float) -> void:
	position.y = lerp(position.y,target_position,lerp_speed)
	if Input.is_action_just_pressed("journal"):
		if open:
			target_position = closed_position
		else:
			target_position = opened_position
		open = !open
		
	if open and Input.is_action_just_pressed("switch_tab"):
		if current_tab == "diary":
			texture = BLUEPRINT
			current_tab = "blueprint"
		else:
			texture = DIARY
			current_tab = "diary"
