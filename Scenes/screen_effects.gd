extends CanvasLayer
class_name ScreenEffectsClass

signal effect_changed(intensity: float)
signal effect_lifted

@onready var cold_overlay: ColorRect = $ColdOverlay

var current_intensity: float = 0.0
var target_intensity: float = 0.0
var transition_speed: float = 1.0
var is_transitioning: bool = false


func _ready() -> void:
	layer = 100
	cold_overlay.material.set_shader_parameter("intensity", 0.0)


func _process(delta: float) -> void:
	if not is_transitioning:
		return

	current_intensity = move_toward(current_intensity, target_intensity, delta * transition_speed)
	cold_overlay.material.set_shader_parameter("intensity", current_intensity)
	effect_changed.emit(current_intensity)

	if is_equal_approx(current_intensity, target_intensity):
		is_transitioning = false
		if current_intensity == 0.0:
			effect_lifted.emit()


func apply_cold_effect(intensity: float = 1.0, duration: float = 1.0) -> void:
	target_intensity = clamp(intensity, 0.0, 1.0)
	transition_speed = 1.0 / max(duration, 0.01)
	is_transitioning = true


func lift_cold_effect(duration: float = 1.5) -> void:
	target_intensity = 0.0
	transition_speed = 1.0 / max(duration, 0.01)
	is_transitioning = true


func set_cold_effect_immediate(intensity: float) -> void:
	current_intensity = clamp(intensity, 0.0, 1.0)
	target_intensity = current_intensity
	cold_overlay.material.set_shader_parameter("intensity", current_intensity)
	is_transitioning = false
	effect_changed.emit(current_intensity)


func set_saturation(value: float) -> void:
	cold_overlay.material.set_shader_parameter("saturation", clamp(value, 0.0, 1.0))


func set_cold_tint(color: Color) -> void:
	cold_overlay.material.set_shader_parameter("cold_tint", Vector3(color.r, color.g, color.b))


func set_tint_strength(value: float) -> void:
	cold_overlay.material.set_shader_parameter("tint_strength", clamp(value, 0.0, 1.0))


func set_brightness(value: float) -> void:
	cold_overlay.material.set_shader_parameter("brightness", clamp(value, 0.5, 1.5))
