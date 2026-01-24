extends Node2D

const IntroSequence = preload("res://Scenes/intro_sequence.tscn")

# Define where the actual button is in the texture (adjust these values!)
const NEW_GAME_BUTTON_RECT = Rect2(65, 585, 195, 55)

func _on_new_game_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var local_pos = new_game_button.get_local_mouse_position()
			if NEW_GAME_BUTTON_RECT.has_point(local_pos):
				_on_new_game_pressed()

@export_group("Parallax Settings")
@export var tower_max_offset: float = 18.0
@export var foreground_max_offset: float = 60.0
@export var background_max_offset: float = 40.0
@export var parallax_smoothing: float = 5.0

@onready var bg_layer: TextureRect = $ParallaxLayers/BackgroundLayer
@onready var tower_layer: TextureRect = $ParallaxLayers/TowerLayer
@onready var fg_layer: TextureRect = $ParallaxLayers/ForegroundLayer
@onready var menu_container: VBoxContainer = $MenuContainer
@onready var quit_button: Button = $MenuContainer/QuitButton

var resume_button: Button
var new_game_button: TextureRect
var intro_instance: CanvasLayer = null

var viewport_center: Vector2
var bg_base_pos: Vector2
var tower_base_pos: Vector2
var fg_base_pos: Vector2

func _ready() -> void:
	viewport_center = get_viewport().get_visible_rect().size / 2.0

	bg_base_pos = bg_layer.position
	tower_base_pos = tower_layer.position
	fg_base_pos = fg_layer.position

	_setup_menu_buttons()
	quit_button.pressed.connect(_on_quit_pressed)


func _setup_menu_buttons() -> void:
	var has_save = GameState.has_save_file()
	
	if has_save:
		resume_button = Button.new()
		resume_button.text = "Resume"
		resume_button.flat = true
		resume_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		resume_button.add_theme_font_size_override("font_size", 48)
		resume_button.pressed.connect(_on_resume_pressed)
		menu_container.add_child(resume_button)
		menu_container.move_child(resume_button, 0)
	
	# Create TextureRect for New Game instead of Button
	var new_game_texture = TextureRect.new()
	new_game_texture.name = "NewGameButton"  # Add this line
	new_game_texture.texture = preload("res://resource/UI/ART_UI_MAIN_Title_Screen_Start.png")
	new_game_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	new_game_texture.mouse_filter = Control.MOUSE_FILTER_STOP  # Allow mouse events
	new_game_texture.gui_input.connect(_on_new_game_input)
	
	menu_container.add_child(new_game_texture)
	menu_container.move_child(new_game_texture, 1 if has_save else 0)
	
	new_game_button = new_game_texture  # Keep reference


func _process(delta: float) -> void:
	var mouse_pos = get_viewport().get_mouse_position()
	var offset_from_center = (mouse_pos - viewport_center) / viewport_center

	var tower_target = tower_base_pos - offset_from_center * tower_max_offset
	var fg_target = fg_base_pos - offset_from_center * foreground_max_offset
	var bg_target = bg_base_pos + offset_from_center * background_max_offset

	tower_layer.position = tower_layer.position.lerp(tower_target, delta * parallax_smoothing)
	fg_layer.position = fg_layer.position.lerp(fg_target, delta * parallax_smoothing)
	bg_layer.position = bg_layer.position.lerp(bg_target, delta * parallax_smoothing)


func _on_resume_pressed() -> void:
	GameState.load_game()
	get_tree().change_scene_to_file("res://Scenes/world.tscn")


func _on_new_game_pressed() -> void:
	GameState.delete_save()

	# Debug: Hold Shift to skip intro sequence entirely
	if Input.is_key_pressed(KEY_SHIFT):
		print("MainMenu: Shift held - skipping intro sequence")
		get_tree().change_scene_to_file("res://Scenes/world.tscn")
		return

	_start_intro_sequence()


func _start_intro_sequence() -> void:
	intro_instance = IntroSequence.instantiate()
	get_tree().root.add_child(intro_instance)
	intro_instance.start_sequence()


func _on_quit_pressed() -> void:
	get_tree().quit()
