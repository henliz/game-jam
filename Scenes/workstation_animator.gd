class_name WorkstationAnimator
extends Node

signal animation_started
signal animation_completed
signal level_fade_started
signal level_fade_completed

@export var walls_node: Node3D
@export var rug_node: Node3D
@export var table_node: Node3D
@export var props: Array[Node3D] = []
@export var item_placement: Node3D

@export_group("Animation Settings")
@export var walls_drop_height: float = 4.0
@export var rug_slide_distance: float = 3.0
@export var table_drop_height: float = 3.0
@export var props_drop_height: float = 2.0

@export var walls_duration: float = 0.8
@export var rug_duration: float = 0.6
@export var table_duration: float = 0.5
@export var props_duration: float = 0.4

@export var stagger_delay: float = 0.15

@export_group("Level Fade")
@export var level_fade_duration: float = 1.0

@export_group("Audio")
@export var fall_sounds: Array[AudioStream] = []
@export var rise_sounds: Array[AudioStream] = []

var is_animated_in: bool = false
var target_positions: Dictionary = {}  # Stores local positions
var audio_player: AudioStreamPlayer
var current_sound_index: int = -1
var level_nodes: Array[Node3D] = []
var level_original_visibility: Dictionary = {}  # node -> bool
var fade_overlay: ColorRect = null
var fade_canvas: CanvasLayer = null

func _ready() -> void:
	_setup_audio()
	_setup_fade_overlay()
	_store_target_positions()
	_hide_elements()


func _setup_fade_overlay() -> void:
	fade_canvas = CanvasLayer.new()
	fade_canvas.layer = 50  # Above most UI but below item inspector
	add_child(fade_canvas)

	fade_overlay = ColorRect.new()
	fade_overlay.color = Color(0, 0, 0, 0)  # Start transparent
	fade_overlay.anchors_preset = Control.PRESET_FULL_RECT
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_canvas.add_child(fade_overlay)


func _setup_audio() -> void:
	audio_player = AudioStreamPlayer.new()
	audio_player.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
	add_child(audio_player)


func _store_target_positions() -> void:
	# Store local positions so animations work correctly when parented to Player
	if walls_node:
		for wall in walls_node.get_children():
			if wall is Node3D:
				target_positions[wall] = wall.position

	if rug_node:
		target_positions[rug_node] = rug_node.position

	if table_node:
		target_positions[table_node] = table_node.position

	for prop in props:
		if prop:
			target_positions[prop] = prop.position

	if item_placement:
		target_positions[item_placement] = item_placement.position


func _hide_elements() -> void:
	# Use local positions for animation offsets
	if walls_node:
		walls_node.visible = false
		for wall in walls_node.get_children():
			if wall is Node3D:
				var pos = wall.position
				pos.y += walls_drop_height
				wall.position = pos
				wall.visible = false

	if rug_node:
		var pos = rug_node.position
		pos.z -= rug_slide_distance  # Slide along local Z (forward/back)
		rug_node.position = pos
		rug_node.visible = false

	if table_node:
		var pos = table_node.position
		pos.y += table_drop_height
		table_node.position = pos
		table_node.visible = false

	for prop in props:
		if prop:
			var pos = prop.position
			pos.y += props_drop_height
			prop.position = pos
			prop.visible = false


func add_level_node(node: Node3D) -> void:
	if node and not level_nodes.has(node):
		level_nodes.append(node)


func animate_in_with_fade() -> void:
	if is_animated_in:
		return

	level_fade_started.emit()

	if level_nodes.size() > 0:
		_fade_level_out()
		await get_tree().create_timer(level_fade_duration).timeout
		level_fade_completed.emit()

	animate_in()


func _fade_level_out() -> void:
	if level_nodes.is_empty():
		return

	# Store original visibility and hide all level nodes after fade
	for node in level_nodes:
		level_original_visibility[node] = node.visible

	# Fade to black using overlay, then hide all level nodes
	var tween = create_tween()
	tween.tween_property(fade_overlay, "color:a", 1.0, level_fade_duration)
	tween.tween_callback(_hide_level_nodes)


func _hide_level_nodes() -> void:
	for node in level_nodes:
		node.visible = false


func _fade_level_in() -> void:
	if level_nodes.is_empty():
		return

	# Show all level nodes first, then fade overlay out
	for node in level_nodes:
		node.visible = level_original_visibility.get(node, true)

	var tween = create_tween()
	tween.tween_property(fade_overlay, "color:a", 0.0, level_fade_duration)


func animate_in() -> void:
	if is_animated_in:
		return

	is_animated_in = true
	animation_started.emit()

	# Show the parent workbench node (may be hidden in editor)
	var workbench_root = get_parent()
	if workbench_root is Node3D:
		workbench_root.visible = true

	_play_sound_forward()

	var total_time: float = 0.0

	# Phase 1: Walls drop down
	if walls_node:
		walls_node.visible = true
		var wall_index := 0
		for wall in walls_node.get_children():
			if wall is Node3D:
				wall.visible = true
				var delay := wall_index * stagger_delay
				_tween_drop(wall, target_positions[wall], walls_duration, delay)
				wall_index += 1
		total_time = walls_duration + (wall_index * stagger_delay)

	# Phase 2: Rug slides in (starts after walls begin)
	if rug_node:
		var rug_delay := walls_duration * 0.3
		rug_node.visible = true
		_tween_slide(rug_node, target_positions[rug_node], rug_duration, rug_delay)
		total_time = max(total_time, rug_delay + rug_duration)

	# Phase 3: Table drops (starts after rug begins)
	if table_node:
		var table_delay := walls_duration * 0.5
		table_node.visible = true
		_tween_drop(table_node, target_positions[table_node], table_duration, table_delay)
		total_time = max(total_time, table_delay + table_duration)

	# Phase 4: Props drop onto table (after table lands)
	if props.size() > 0:
		var props_delay := walls_duration * 0.5 + table_duration * 0.7
		var prop_index := 0
		for prop in props:
			if prop:
				prop.visible = true
				var delay := props_delay + (prop_index * stagger_delay * 0.5)
				_tween_drop(prop, target_positions[prop], props_duration, delay)
				prop_index += 1
		total_time = max(total_time, props_delay + props_duration + (prop_index * stagger_delay * 0.5))

	# Signal completion
	get_tree().create_timer(total_time).timeout.connect(func(): animation_completed.emit())


func _tween_drop(node: Node3D, target_pos: Vector3, duration: float, delay: float) -> void:
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BOUNCE)

	tween.tween_interval(delay)
	tween.tween_property(node, "position", target_pos, duration)


func _tween_slide(node: Node3D, target_pos: Vector3, duration: float, delay: float) -> void:
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)

	tween.tween_interval(delay)
	tween.tween_property(node, "position", target_pos, duration)


func animate_out() -> void:
	if not is_animated_in:
		return

	_play_sound_rise()

	var total_time: float = 0.0

	# Reverse order: props first, then table, then rug, then walls

	# Phase 1: Props rise up
	if props.size() > 0:
		var prop_index := 0
		for prop in props:
			if prop:
				var end_pos = target_positions[prop] + Vector3(0, props_drop_height, 0)
				var delay := prop_index * stagger_delay * 0.5
				_tween_rise(prop, end_pos, props_duration * 0.7, delay)
				prop_index += 1
		total_time = props_duration * 0.7 + (prop_index * stagger_delay * 0.5)

	# Phase 2: Table rises
	if table_node:
		var table_delay := total_time * 0.3
		var end_pos = target_positions[table_node] + Vector3(0, table_drop_height, 0)
		_tween_rise(table_node, end_pos, table_duration * 0.7, table_delay)

	# Phase 3: Rug slides out (along local Z)
	if rug_node:
		var rug_delay := total_time * 0.5
		var end_pos = target_positions[rug_node] + Vector3(0, 0, -rug_slide_distance)
		_tween_slide_out(rug_node, end_pos, rug_duration * 0.7, rug_delay)

	# Phase 4: Walls rise up
	if walls_node:
		var walls_delay := total_time * 0.6
		var wall_index := 0
		for wall in walls_node.get_children():
			if wall is Node3D:
				var end_pos = target_positions[wall] + Vector3(0, walls_drop_height, 0)
				var delay := walls_delay + (wall_index * stagger_delay)
				_tween_rise(wall, end_pos, walls_duration * 0.7, delay)
				wall_index += 1

	# Calculate total animation time and hide elements at end
	var final_time := walls_duration + total_time + 0.5
	get_tree().create_timer(final_time).timeout.connect(_on_animate_out_complete)


func _tween_rise(node: Node3D, target_pos: Vector3, duration: float, delay: float) -> void:
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_QUAD)

	tween.tween_interval(delay)
	tween.tween_property(node, "position", target_pos, duration)


func _tween_slide_out(node: Node3D, target_pos: Vector3, duration: float, delay: float) -> void:
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_QUAD)

	tween.tween_interval(delay)
	tween.tween_property(node, "position", target_pos, duration)


func _on_animate_out_complete() -> void:
	_hide_elements()
	is_animated_in = false

	# Hide the parent workbench node again
	var workbench_root = get_parent()
	if workbench_root is Node3D:
		workbench_root.visible = false

	# Fade the level back in
	if level_nodes.size() > 0:
		_fade_level_in()


func reset() -> void:
	is_animated_in = false
	_hide_elements()


func get_item_placement_transform() -> Transform3D:
	if item_placement:
		return item_placement.global_transform
	return Transform3D.IDENTITY


func get_item_placement_node() -> Node3D:
	return item_placement


func _play_sound_forward() -> void:
	if fall_sounds.is_empty():
		return

	current_sound_index = randi() % fall_sounds.size()
	var sound = fall_sounds[current_sound_index]

	audio_player.stream = sound
	audio_player.pitch_scale = 1.0
	audio_player.play()


func _play_sound_rise() -> void:
	if rise_sounds.is_empty() or current_sound_index < 0:
		return

	# Use the matching rise sound for the fall sound that was played
	if current_sound_index < rise_sounds.size():
		var sound = rise_sounds[current_sound_index]
		audio_player.stream = sound
		audio_player.pitch_scale = 1.0
		audio_player.play()
