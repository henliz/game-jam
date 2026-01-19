extends OmniLight3D

@export var min_energy: float = 0.25
@export var max_energy: float = 1.0
@export var flicker_speed: float = 8.0
@export var noise_scale: float = 0.15

var time: float = 0.0
var base_offset: float

func _ready() -> void:
	base_offset = randf() * 100.0

func _process(delta: float) -> void:
	time += delta * flicker_speed

	var noise_value = _multi_octave_noise(time + base_offset)
	light_energy = lerp(min_energy, max_energy, noise_value)

func _multi_octave_noise(t: float) -> float:
	var value = 0.0
	value += sin(t * 1.0) * 0.5
	value += sin(t * 2.3) * 0.25
	value += sin(t * 5.7) * 0.15
	value += sin(t * 11.0) * 0.1
	value = (value + 1.0) / 2.0
	return clamp(value, 0.0, 1.0)
