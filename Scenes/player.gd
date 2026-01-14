extends CharacterBody3D

var speed
const WALK_SPEED = 5.0
const SPRINT_SPEED = 8.0
const JUMP_VELOCITY = 5.0
const SENSITIVITY = 0.003

const BOB_FREQ = 2.4
const BOB_AMP = 0.04
var t_bob = 0.0

const BASE_FOV = 75.0
const FOV_CHANGE = 1.5

var jumping = false
var last_floor : bool
var vl : Vector3

@onready var head = $Head
@onready var camera = $Head/Camera3D
@onready var interact_ray: RayCast3D = $Head/Camera3D/InteractRay
@onready var item_inspector: ItemInspector = $ItemInspector
@onready var interact_prompt: Label = $UI/InteractPrompt
@onready var rotate_prompt: Label = $UI/RotatePrompt

var inspecting: bool = false
var current_interactable: Interactable = null
var current_rotatable: StaticBody3D = null

signal rotate(direction,plate)

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	last_floor = is_on_floor()
	item_inspector.closed.connect(_on_inspection_closed)

func _unhandled_input(event):
	if inspecting:
		return
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * SENSITIVITY)
		camera.rotate_x(-event.relative.y * SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-70), deg_to_rad(75))
		
func _physics_process(delta: float) -> void:
	_check_interactable()
	_handle_interaction()

	if inspecting:
		velocity = Vector3.ZERO
		return

	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		jumping = true
	if is_on_floor() and not last_floor:
		jumping = false
	last_floor = is_on_floor()
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
	camera.transform.origin = _headbob(t_bob)

	var velocity_clamped = clamp(velocity.length(), 0.5, SPRINT_SPEED * 2)
	var target_fov = BASE_FOV + FOV_CHANGE * velocity_clamped
	camera.fov = lerp(camera.fov, target_fov, delta * 8.0)

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
			current_interactable = collider
			interact_prompt.visible = not inspecting
			return
		if collider.is_in_group("puzzleplate"):
			current_rotatable = collider
			rotate_prompt.visible = true
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
	if Input.is_action_just_pressed("rotate_left") and current_rotatable:
		rotate.emit("left",current_rotatable)
	if Input.is_action_just_pressed("rotate_right") and current_rotatable:
		rotate.emit("right",current_rotatable)
		
func _start_inspection(item: Interactable):
	inspecting = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	item_inspector.open(item, camera, item.inspect_scale)

func _on_inspection_closed():
	inspecting = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
