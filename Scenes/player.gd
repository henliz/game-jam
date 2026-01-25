extends CharacterBody3D

var speed
const WALK_SPEED = 2.5
const SPRINT_SPEED = 4.0
const SENSITIVITY = 0.003

const BOB_FREQ = 2.4
const BOB_AMP = 0.04
var t_bob = 0.0

const BASE_FOV = 75.0
const FOV_CHANGE = 1.5

const WALK_STEP_INTERVAL = 0.5
const SPRINT_STEP_INTERVAL = 0.35

var vl : Vector3
var footstep_timer: float = 0.0
var camera_base_position: Vector3

@onready var head = $Head
@onready var camera = $Head/Camera3D
@onready var interact_ray: RayCast3D = $Head/Camera3D/InteractRay
@onready var item_inspector: ItemInspector = $ItemInspector
@onready var workbench: Node3D = %Workbench
@onready var workbench_animator: WorkstationAnimator = %Workbench/WorkstationAnimator
@onready var interact_prompt: Label = $UI/InteractPrompt
@onready var rotate_prompt: Label = $UI/RotatePrompt
@onready var footstep_player: AudioStreamPlayer3D = $FootstepPlayer

var inspecting: bool = false
var movement_enabled: bool = true
var current_interactable: Interactable = null
var current_rotatable: StaticBody3D = null
var level_map_node: Node3D = null
var current_cleanable: Cleanable = null

signal rotate_plate(direction,plate)
signal rotate_pipe(direction,pipe)

var finalpuzzle_is_active = false
signal finalpuzzle_camera_trigger
var collider_is_finalpuzzle = false
var pending_journal_sequence_item: String = ""

func _ready() -> void:
	camera_base_position = camera.position
	item_inspector.closed.connect(_on_inspection_closed)
	item_inspector.item_cleaned.connect(_on_item_cleaned_for_journal)
	workbench_animator.workbench_fully_exited.connect(_on_workbench_fully_exited)
	# Find the Map node in the world scene for workbench level fade
	call_deferred("_find_level_map")

func _unhandled_input(event):
	if inspecting or finalpuzzle_is_active:
		return
	if event is InputEventMouseMotion && Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * SENSITIVITY)
		camera.rotate_x(-event.relative.y * SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-70), deg_to_rad(75))

func _physics_process(delta: float) -> void:
	if finalpuzzle_is_active: return
	_check_interactable()
	_handle_interaction()

	if inspecting or not movement_enabled:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_pressed("sprint"):
		speed = SPRINT_SPEED
	else:
		speed = WALK_SPEED

	var input_dir := Input.get_vector("left", "right", "up", "down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if is_on_floor():
		velocity.x = lerp(velocity.x, direction.x * speed, delta * 7.0)
		velocity.z = lerp(velocity.z, direction.z * speed, delta * 7.0)
	else:
		velocity.x = lerp(velocity.x, direction.x * speed, delta * 3.0)
		velocity.z = lerp(velocity.z, direction.z * speed, delta * 3.0)

	t_bob += delta * velocity.length() * float(is_on_floor())
	camera.position = camera_base_position + _headbob(t_bob)

	var velocity_clamped = clamp(velocity.length(), 0.5, SPRINT_SPEED * 2)
	var target_fov = BASE_FOV + FOV_CHANGE * velocity_clamped
	camera.fov = lerp(camera.fov, target_fov, delta * 8.0)

	_handle_footsteps(delta)

	move_and_slide()
	
func _headbob(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	pos.x = cos(time * BOB_FREQ / 2) * BOB_AMP
	return pos

func _check_interactable():
	if interact_ray.is_colliding():
		var collider = interact_ray.get_collider()
		if collider is Interactable:
			# Check if this item requires unlock (has GlowOutline with requires_unlock)
			var glow = collider.get_node_or_null("GlowOutline") as GlowOutline
			if glow and glow.requires_unlock and not GameState.get_flag("puzzles_unlocked", false):
				current_interactable = null
				interact_prompt.visible = false
				return
			current_interactable = collider
			interact_prompt.visible = not inspecting
			return
		if collider and (collider.is_in_group("puzzleplate") or collider.is_in_group("puzzlepipe")):
			current_rotatable = collider
			rotate_prompt.visible = true
			return
		if collider and collider.is_in_group("finalpuzzle"):
			collider_is_finalpuzzle = true
			interact_prompt.visible = true
			return
	current_interactable = null
	interact_prompt.visible = false
	current_rotatable = null
	rotate_prompt.visible = false

func _handle_interaction():
	if inspecting:
		return
	if Input.is_action_just_pressed("interact") and current_interactable:
		_start_inspection(current_interactable)
	if current_rotatable:
		if current_rotatable.is_in_group("puzzleplate"):
			if Input.is_action_just_pressed("rotate_left"):
				rotate_plate.emit("left",current_rotatable)
			if Input.is_action_just_pressed("rotate_right"):
				rotate_plate.emit("right",current_rotatable)
		if current_rotatable.is_in_group("puzzlepipe"):
			if Input.is_action_just_pressed("rotate_left"):
				rotate_pipe.emit("left",current_rotatable)
			if Input.is_action_just_pressed("rotate_right"):
				rotate_pipe.emit("right",current_rotatable)
	if Input.is_action_just_pressed("interact") and collider_is_finalpuzzle:
		finalpuzzle_camera_trigger.emit()
		finalpuzzle_is_active = true
		interact_prompt.visible = false
		
func _start_inspection(item: Interactable):
	inspecting = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	workbench_animator.animate_in_with_fade()
	item_inspector.open(item, camera, item.inspect_scale, workbench_animator.get_item_placement_node())
	
	# Connect to cleaning complete signal if item has Cleanable component
	var cleanable = item.find_child("Cleanable", true, false) as Cleanable
	if cleanable:
		current_cleanable = cleanable
		cleanable.cleaning_complete.connect(_on_item_cleaned, CONNECT_ONE_SHOT)

func _on_item_cleaned() -> void:
	# Wait for the celebration animation in Cleanable (6.5 seconds total)
	await get_tree().create_timer(6.5).timeout  # Changed from 1.5 to 6.5
	
	# Auto-close inspection after cleaning completes
	if item_inspector:
		item_inspector.close()
	
	current_cleanable = null

func _on_inspection_closed():
	inspecting = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	workbench_animator.animate_out()


func _handle_footsteps(delta: float) -> void:
	if not is_on_floor():
		footstep_timer = 0.0
		return

	var horizontal_velocity = Vector2(velocity.x, velocity.z).length()
	if horizontal_velocity < 0.5:
		footstep_timer = 0.0
		return

	var step_interval = SPRINT_STEP_INTERVAL if speed == SPRINT_SPEED else WALK_STEP_INTERVAL
	footstep_timer += delta

	if footstep_timer >= step_interval:
		footstep_timer = 0.0
		footstep_player.play()


func _find_level_map() -> void:
	# Look for level geometry nodes in the world scene
	# With new hierarchy, World is a child of Main (current_scene)
	var root = get_tree().current_scene
	if not root:
		return

	# Find World node - could be current_scene itself or a child
	var world = root.get_node_or_null("World") if root.name != "World" else root
	if not world:
		world = root  # Fallback to current_scene if World not found

	# Find floor nodes to hide during workbench inspection
	var level_node_names = ["Floor1", "Floor2", "Floor3"]
	for node_name in level_node_names:
		var node = world.find_child(node_name, false, false) as Node3D
		if node:
			workbench_animator.add_level_node(node)

func _on_finalpuzzle_closed() -> void:
	camera.current=true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	finalpuzzle_is_active = false


func _on_item_cleaned_for_journal(_cleanable: Cleanable) -> void:
	pending_journal_sequence_item = item_inspector.last_cleaned_item_id


func _on_workbench_fully_exited() -> void:
	if pending_journal_sequence_item.is_empty():
		return
	var journal_ui = get_tree().get_first_node_in_group("journal_ui")
	if journal_ui:
		journal_ui.start_puzzle_completion_sequence(pending_journal_sequence_item)
	pending_journal_sequence_item = ""
