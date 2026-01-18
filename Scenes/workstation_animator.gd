class_name WorkstationAnimator
extends Node

signal animation_started
signal animation_completed

@export var walls_node: Node
@export var rug_node: Node3D
@export var table_node: Node3D
@export var props: Array[Node3D] = []

@export_group("Animation Settings")
@export var walls_drop_height: float = 8.0
@export var rug_slide_distance: float = 6.0
@export var table_drop_height: float = 5.0
@export var props_drop_height: float = 3.0

@export var walls_duration: float = 0.8
@export var rug_duration: float = 0.6
@export var table_duration: float = 0.5
@export var props_duration: float = 0.4

@export var stagger_delay: float = 0.15

@export_group("Audio")
@export var fall_sounds: Array[AudioStream] = []
@export var rise_sounds: Array[AudioStream] = []

var is_animated_in: bool = false
var target_positions: Dictionary = {}
var audio_player: AudioStreamPlayer
var current_sound_index: int = -1

func _ready() -> void:
	_setup_audio()
	_store_target_positions()
	_hide_elements()


func _setup_audio() -> void:
	audio_player = AudioStreamPlayer.new()
	audio_player.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
	add_child(audio_player)


func _store_target_positions() -> void:
	if walls_node:
		for wall in walls_node.get_children():
			if wall is Node3D:
				target_positions[wall] = wall.global_position

	if rug_node:
		target_positions[rug_node] = rug_node.global_position

	if table_node:
		target_positions[table_node] = table_node.global_position

	for prop in props:
		if prop:
			target_positions[prop] = prop.global_position


func _hide_elements() -> void:
	if walls_node:
		for wall in walls_node.get_children():
			if wall is Node3D:
				var pos = wall.global_position
				pos.y += walls_drop_height
				wall.global_position = pos
				wall.visible = false

	if rug_node:
		var pos = rug_node.global_position
		pos.x -= rug_slide_distance
		rug_node.global_position = pos
		rug_node.visible = false

	if table_node:
		var pos = table_node.global_position
		pos.y += table_drop_height
		table_node.global_position = pos
		table_node.visible = false

	for prop in props:
		if prop:
			var pos = prop.global_position
			pos.y += props_drop_height
			prop.global_position = pos
			prop.visible = false


func animate_in() -> void:
	if is_animated_in:
		return

	is_animated_in = true
	animation_started.emit()

	_play_sound_forward()

	var total_time: float = 0.0

	# Phase 1: Walls drop down
	if walls_node:
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
	tween.tween_property(node, "global_position", target_pos, duration)


func _tween_slide(node: Node3D, target_pos: Vector3, duration: float, delay: float) -> void:
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)

	tween.tween_interval(delay)
	tween.tween_property(node, "global_position", target_pos, duration)


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
				var start_pos = prop.global_position
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

	# Phase 3: Rug slides out
	if rug_node:
		var rug_delay := total_time * 0.5
		var end_pos = target_positions[rug_node] + Vector3(-rug_slide_distance, 0, 0)
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
	tween.tween_property(node, "global_position", target_pos, duration)


func _tween_slide_out(node: Node3D, target_pos: Vector3, duration: float, delay: float) -> void:
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_QUAD)

	tween.tween_interval(delay)
	tween.tween_property(node, "global_position", target_pos, duration)


func _on_animate_out_complete() -> void:
	_hide_elements()
	is_animated_in = false


func reset() -> void:
	is_animated_in = false
	_hide_elements()


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
