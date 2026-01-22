class_name PickupItem
extends Node3D

## Script for items that can be picked up (disappear on interaction).
## Unlike Interactable items which go to the workbench, these just disappear
## and trigger events like dialogue or UI.

signal picked_up(item_name: String)

@export var item_name: String = "Item"
@export var pickup_sound: AudioStream
@export var dialogue_id: String = ""  ## Dialogue to trigger on pickup
@export var trigger_id: String = ""   ## Trigger ID for one-time dialogue
@export var open_journal_after: bool = false  ## Open journal UI after pickup
@export var unlock_puzzles: bool = false  ## Unlock puzzles after picking up

@export_group("Glow Settings")
@export var glow_color: Color = Color(0.4, 0.6, 1.0, 1.0)
@export var glow_amount: float = 0.02
@export var interaction_range: float = 2.0
@export var look_tolerance: float = 0.3  ## How close to center player must look to show prompt
@export var target_node: Node3D  ## Assign the GLB root node - will find MeshInstance3D inside

var glow_overlay: MeshInstance3D
var is_glowing: bool = false
var is_looking_at: bool = false
var mesh_instance: MeshInstance3D
var player_in_range: bool = false
var audio_player: AudioStreamPlayer3D
var is_picked_up: bool = false
var pickup_prompt: Label


func _ready() -> void:
	# Check if already picked up from save
	if trigger_id and GameState.has_dialogue_triggered(trigger_id):
		queue_free()
		return

	_find_mesh()
	if mesh_instance:
		_setup_glow_overlay()
	_setup_interaction_area()
	_setup_audio()
	_find_pickup_prompt()


func _find_mesh() -> void:
	if target_node:
		mesh_instance = _find_mesh_instance(target_node)
	else:
		mesh_instance = _find_mesh_instance(self)
		if not mesh_instance and get_parent():
			mesh_instance = _find_mesh_instance(get_parent())


func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var result = _find_mesh_instance(child)
		if result:
			return result
	return null


func _setup_glow_overlay() -> void:
	glow_overlay = MeshInstance3D.new()
	glow_overlay.mesh = mesh_instance.mesh
	glow_overlay.visible = false
	glow_overlay.name = "GlowOverlay"

	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = glow_color
	material.emission_enabled = true
	material.emission = glow_color
	material.emission_energy_multiplier = 2.0
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color.a = 0.6
	material.grow = true
	material.grow_amount = glow_amount
	material.cull_mode = BaseMaterial3D.CULL_FRONT
	glow_overlay.material_override = material

	mesh_instance.add_child(glow_overlay)
	glow_overlay.transform = Transform3D.IDENTITY


func _setup_interaction_area() -> void:
	var area = Area3D.new()
	var collision = CollisionShape3D.new()
	var sphere = SphereShape3D.new()

	sphere.radius = interaction_range
	collision.shape = sphere
	area.add_child(collision)
	add_child(area)

	area.collision_layer = 0
	area.collision_mask = 1

	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)


func _setup_audio() -> void:
	audio_player = AudioStreamPlayer3D.new()
	audio_player.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
	add_child(audio_player)


func _find_pickup_prompt() -> void:
	# Find the player's UI pickup prompt (reuse interact prompt structure)
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var ui = player.get_node_or_null("UI")
		if ui:
			# Create our own pickup prompt similar to InteractPrompt
			pickup_prompt = ui.get_node_or_null("PickupPrompt")
			if not pickup_prompt:
				var interact_prompt = ui.get_node_or_null("InteractPrompt") as Label
				if interact_prompt:
					pickup_prompt = interact_prompt.duplicate()
					pickup_prompt.name = "PickupPrompt"
					pickup_prompt.text = "Press E to pick up"
					pickup_prompt.visible = false
					ui.add_child(pickup_prompt)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		_update_glow_visibility()


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		if pickup_prompt:
			pickup_prompt.visible = false
		_update_glow_visibility()


func _process(_delta: float) -> void:
	if player_in_range:
		_update_glow_visibility()
		_update_prompt_visibility()


func _update_glow_visibility() -> void:
	if is_picked_up:
		return

	var should_glow = player_in_range and not _is_player_inspecting()

	if should_glow != is_glowing:
		is_glowing = should_glow
		if glow_overlay:
			glow_overlay.visible = is_glowing


func _update_prompt_visibility() -> void:
	if is_picked_up:
		if pickup_prompt:
			pickup_prompt.visible = false
		return

	if not player_in_range or _is_player_inspecting():
		if pickup_prompt:
			pickup_prompt.visible = false
		is_looking_at = false
		return

	# Check if player is looking at the item
	var looking = _is_player_looking_at_item()

	if looking != is_looking_at:
		is_looking_at = looking
		if pickup_prompt:
			pickup_prompt.visible = is_looking_at


func _is_player_looking_at_item() -> bool:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return false

	var camera = player.get_node_or_null("Head/Camera3D")
	if not camera:
		return false

	# Get camera forward direction and position
	var cam_pos: Vector3 = camera.global_position
	var cam_forward: Vector3 = -camera.global_transform.basis.z

	# Get direction to this item
	var item_pos: Vector3 = global_position
	var to_item: Vector3 = (item_pos - cam_pos).normalized()

	# Check dot product (1.0 = looking directly at, 0.0 = perpendicular)
	var dot: float = cam_forward.dot(to_item)

	# Also check if the cross product magnitude is within tolerance (distance from center line)
	var cross_dist: float = cam_forward.cross(to_item).length()

	return cross_dist <= look_tolerance and dot > 0.0


func _is_player_inspecting() -> bool:
	var player = get_tree().get_first_node_in_group("player")
	if player and "inspecting" in player:
		return player.inspecting
	return false


func _input(event: InputEvent) -> void:
	if is_picked_up:
		return

	if not player_in_range:
		return

	if _is_player_inspecting():
		return

	# Only allow pickup when looking at the item
	if not is_looking_at:
		return

	if event.is_action_pressed("interact"):
		pickup()
		get_viewport().set_input_as_handled()


func pickup() -> void:
	if is_picked_up:
		return

	is_picked_up = true

	# Hide pickup prompt
	if pickup_prompt:
		pickup_prompt.visible = false

	# Play pickup sound
	if pickup_sound and audio_player:
		audio_player.stream = pickup_sound
		audio_player.play()

	# Hide the item immediately
	if mesh_instance:
		mesh_instance.visible = false
	if glow_overlay:
		glow_overlay.visible = false

	# Unlock puzzles if specified
	if unlock_puzzles:
		GameState.set_flag("puzzles_unlocked", true)

	# Emit signal for other systems
	picked_up.emit(item_name)

	# Open journal after a brief delay (dialogue will be triggered by journal_ui on first open)
	if open_journal_after:
		get_tree().create_timer(0.3).timeout.connect(_open_journal)

	_schedule_cleanup()


func _schedule_cleanup() -> void:
	# Wait for audio to finish then remove
	if audio_player and audio_player.playing:
		audio_player.finished.connect(queue_free)
	else:
		# Give a small delay before cleanup
		get_tree().create_timer(0.5).timeout.connect(queue_free)


func _open_journal() -> void:
	var journal_ui = get_tree().get_first_node_in_group("journal_ui")
	if journal_ui and journal_ui.has_method("open_journal"):
		journal_ui.open_journal()
	else:
		# Try finding it by path in root
		var root = get_tree().root
		var ui_layer = root.get_node_or_null("World/UILayer")
		if ui_layer:
			var journal = ui_layer.get_node_or_null("JournalUI")
			if journal and journal.has_method("open_journal"):
				journal.open_journal()
