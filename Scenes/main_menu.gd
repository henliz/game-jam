extends Node2D

@export_group("Parallax Settings")
@export var tower_max_offset: float = 18.0
@export var foreground_max_offset: float = 60.0
@export var background_max_offset: float = 40.0
@export var parallax_smoothing: float = 5.0

@onready var bg_layer: TextureRect = $ParallaxLayers/BackgroundLayer
@onready var tower_layer: TextureRect = $ParallaxLayers/TowerLayer
@onready var fg_layer: TextureRect = $ParallaxLayers/ForegroundLayer
@onready var new_game_button: Button = $MenuContainer/NewGameButton
@onready var quit_button: Button = $MenuContainer/QuitButton

var viewport_center: Vector2
var bg_base_pos: Vector2
var tower_base_pos: Vector2
var fg_base_pos: Vector2

func _ready() -> void:
	viewport_center = get_viewport().get_visible_rect().size / 2.0

	bg_base_pos = bg_layer.position
	tower_base_pos = tower_layer.position
	fg_base_pos = fg_layer.position

	_update_menu_text()

	new_game_button.pressed.connect(_on_new_game_pressed)
	quit_button.pressed.connect(_on_quit_pressed)


func _process(delta: float) -> void:
	var mouse_pos = get_viewport().get_mouse_position()
	var offset_from_center = (mouse_pos - viewport_center) / viewport_center

	var tower_target = tower_base_pos - offset_from_center * tower_max_offset
	var fg_target = fg_base_pos - offset_from_center * foreground_max_offset
	var bg_target = bg_base_pos + offset_from_center * background_max_offset

	tower_layer.position = tower_layer.position.lerp(tower_target, delta * parallax_smoothing)
	fg_layer.position = fg_layer.position.lerp(fg_target, delta * parallax_smoothing)
	bg_layer.position = bg_layer.position.lerp(bg_target, delta * parallax_smoothing)


func _update_menu_text() -> void:
	if GameState.has_save_file():
		new_game_button.text = "Resume"
	else:
		new_game_button.text = "New Game"


func _on_new_game_pressed() -> void:
	if GameState.has_save_file():
		GameState.load_game()
	get_tree().change_scene_to_file("res://Scenes/world.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()
