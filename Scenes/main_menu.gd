extends Node2D

const IntroSequence = preload("res://Scenes/intro_sequence.tscn")
@onready var world: Node3D = $"../World"

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
var new_game_button: Button
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
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

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

	new_game_button = Button.new()
	new_game_button.text = "New Game"
	new_game_button.flat = true
	new_game_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	new_game_button.add_theme_font_size_override("font_size", 48)
	new_game_button.pressed.connect(_on_new_game_pressed)
	menu_container.add_child(new_game_button)
	menu_container.move_child(new_game_button, 1 if has_save else 0)


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
	world.visible=true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	queue_free()


func _on_new_game_pressed() -> void:
	GameState.delete_save()

	#Debug: Hold Shift to skip intro sequence entirely
	if Input.is_key_pressed(KEY_SHIFT):
		print("MainMenu: Shift held - skipping intro sequence")
		world.visible=true
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		queue_free()
		return
	world.visible=true
	_start_intro_sequence()
	queue_free()


func _start_intro_sequence() -> void:
	intro_instance = IntroSequence.instantiate()
	get_tree().root.add_child(intro_instance)
	intro_instance.start_sequence()


func _on_quit_pressed() -> void:
	get_tree().quit()
