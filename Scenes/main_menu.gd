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
@onready var start_button: TextureRect = $MenuButtons/Start
@onready var quit_button: TextureRect = $MenuButtons/Quit

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
	
	# Connect click events
	start_button.gui_input.connect(_on_start_input)
	quit_button.gui_input.connect(_on_quit_input)
	
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _process(delta: float) -> void:
	var mouse_pos = get_viewport().get_mouse_position()
	var offset_from_center = (mouse_pos - viewport_center) / viewport_center
	
	var tower_target = tower_base_pos - offset_from_center * tower_max_offset
	var fg_target = fg_base_pos - offset_from_center * foreground_max_offset
	var bg_target = bg_base_pos + offset_from_center * background_max_offset
	
	tower_layer.position = tower_layer.position.lerp(tower_target, delta * parallax_smoothing)
	fg_layer.position = fg_layer.position.lerp(fg_target, delta * parallax_smoothing)
	bg_layer.position = bg_layer.position.lerp(bg_target, delta * parallax_smoothing)

func _on_start_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_start_pressed()

func _on_quit_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_quit_pressed()

func _on_start_pressed() -> void:
	# Debug: Hold Shift to skip intro sequence entirely
	if Input.is_key_pressed(KEY_SHIFT):
		print("MainMenu: Shift held - skipping intro sequence")
		if world:
			world.visible = true
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		queue_free()
		PauseManager.enable_pause()
		return
	
	if world:
		world.visible = true
	_start_intro_sequence()
	queue_free()
	PauseManager.enable_pause()

func _start_intro_sequence() -> void:
	intro_instance = IntroSequence.instantiate()
	get_tree().root.add_child(intro_instance)
	intro_instance.start_sequence()

func _on_quit_pressed() -> void:
	get_tree().quit()
