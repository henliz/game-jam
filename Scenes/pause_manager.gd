extends CanvasLayer

const MainMenu = preload("res://Scenes/MainMenu.tscn")

@onready var background: TextureRect = $Background
@onready var resume_button: TextureRect = $ResumeButton
@onready var return_button: TextureRect = $ReturnButton
@onready var quit_button: TextureRect = $QuitButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	print("PauseManager ready!")
	print("Background: ", background)
	print("ResumeButton: ", resume_button)
	print("ReturnButton: ", return_button)
	print("QuitButton: ", quit_button)
	
	# Make sure all UI elements can process when paused
	background.process_mode = Node.PROCESS_MODE_ALWAYS
	resume_button.process_mode = Node.PROCESS_MODE_ALWAYS
	return_button.process_mode = Node.PROCESS_MODE_ALWAYS
	quit_button.process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Connect gui_input for TextureRect buttons
	resume_button.gui_input.connect(_on_resume_input)
	return_button.gui_input.connect(_on_return_input)
	quit_button.gui_input.connect(_on_quit_input)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		print("ESC pressed!")
		toggle_pause()
		get_viewport().set_input_as_handled()

func toggle_pause() -> void:
	print("Toggle pause called! Current paused state: ", get_tree().paused)
	get_tree().paused = !get_tree().paused
	print("New paused state: ", get_tree().paused)
	
	background.visible = get_tree().paused
	resume_button.visible = get_tree().paused
	return_button.visible = get_tree().paused
	quit_button.visible = get_tree().paused
	
	print("Background visible: ", background.visible)
	
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
	get_tree().change_scene_to_packed(MainMenu)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_exit_pressed() -> void:
	GameState.save_game()
	get_tree().quit()
