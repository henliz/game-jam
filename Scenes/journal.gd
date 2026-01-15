extends TextureRect

@export var first_open_dialogue_id: String = "journal_first_open"

var open = false
var lerp_speed = 0.1

var opened_position = 0.0
var closed_position = 1080.0
var target_position = closed_position

func _ready() -> void:
	_setup_journal()


func _setup_journal() -> void:
	# Reset any anchor/offset weirdness from the scene
	anchor_left = 0
	anchor_top = 0
	anchor_right = 0
	anchor_bottom = 0
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	rotation = 0
	scale = Vector2.ONE
	pivot_offset = Vector2.ZERO

	# Force the correct size (1440x1080)
	custom_minimum_size = Vector2(1440, 1080)
	size = Vector2(1440, 1080)
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE

	# Center horizontally
	var viewport_size = get_viewport().get_visible_rect().size
	position.x = (viewport_size.x - 1440) / 2.0
	position.y = closed_position

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
			_on_opened()
		open = !open
		
	if open and Input.is_action_just_pressed("switch_tab"):
		if current_tab == "diary":
			texture = BLUEPRINT
			current_tab = "blueprint"
		else:
			texture = DIARY
			current_tab = "diary"


func _on_opened() -> void:
	if first_open_dialogue_id:
		DialogueManager.try_trigger_dialogue("journal_first_open", first_open_dialogue_id)
