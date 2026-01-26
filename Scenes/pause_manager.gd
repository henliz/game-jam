extends CanvasLayer

const MainMenu = preload("res://Scenes/MainMenu.tscn")

var can_pause: bool = false

@onready var background: TextureRect = $Background
@onready var resume_button: TextureRect = $ResumeButton
@onready var return_button: TextureRect = $ReturnButton
@onready var quit_button: TextureRect = $QuitButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100  # Render on top of everything (higher = on top)
	
	# Make sure all UI elements can process when paused
	background.process_mode = Node.PROCESS_MODE_ALWAYS
	resume_button.process_mode = Node.PROCESS_MODE_ALWAYS
	return_button.process_mode = Node.PROCESS_MODE_ALWAYS
	quit_button.process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Make background block all mouse input to UI below
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Connect gui_input for TextureRect buttons
	resume_button.gui_input.connect(_on_resume_input)
	return_button.gui_input.connect(_on_return_input)
	quit_button.gui_input.connect(_on_quit_input)

func enable_pause() -> void:
	can_pause = true

func disable_pause() -> void:
	can_pause = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if not can_pause:
			print("Pause is disabled (probably on main menu)")
			return
		
		print("ESC pressed!")
		toggle_pause()
		get_viewport().set_input_as_handled()

func toggle_pause() -> void:
	get_tree().paused = !get_tree().paused
	
	background.visible = get_tree().paused
	resume_button.visible = get_tree().paused
	return_button.visible = get_tree().paused
	quit_button.visible = get_tree().paused
	
	if get_tree().paused:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_resume_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_resume_pressed()

func _on_return_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_title_pressed()

func _on_quit_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_exit_pressed()

func _on_resume_pressed() -> void:
	toggle_pause()

func _on_title_pressed() -> void:
	GameState.save_game()
	get_tree().paused = false
	background.visible = false
	resume_button.visible = false
	return_button.visible = false
	quit_button.visible = false
	can_pause = false
	get_tree().change_scene_to_packed(MainMenu)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_exit_pressed() -> void:
	GameState.save_game()
	get_tree().quit()
