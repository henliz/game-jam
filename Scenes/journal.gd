extends TextureRect

var open = false
var lerp_speed = 0.2

var opened_position = 500.0
var closed_position = 1200.0
var target_position = closed_position


func _process(_delta: float) -> void:
	position.y = lerp(position.y,target_position,lerp_speed)
	if Input.is_action_just_pressed("journal"):
		if open:
			target_position = closed_position
		else:
			target_position = opened_position
		open = !open
