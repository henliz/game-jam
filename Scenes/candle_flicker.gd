extends OmniLight3D

@export var min_energy: float = 0.25
@export var max_energy: float = 1.0
@export var flicker_speed: float = 4.0
@export var pop_chance: float = 0.02  # Chance per frame of a sudden brightness pop
@export var gutter_chance: float = 0.005  # Chance per frame of a brief dim

var time: float = 0.0
var base_offset: float
var random_offsets: Array[float] = []
var pop_intensity: float = 0.0
var gutter_intensity: float = 0.0

func _ready() -> void:
	base_offset = randf() * 100.0
	# Random offsets for each octave
	for i in range(4):
		random_offsets.append(randf() * TAU)

func _process(delta: float) -> void:
	# Vary flicker speed slightly over time
	var speed_variance = 1.0 + sin(time * 0.3) * 0.15 + randf_range(-0.05, 0.05)
	time += delta * flicker_speed * speed_variance

	var noise_value = _multi_octave_noise(time + base_offset)

	# Random brightness pops (brief flare-ups)
	if randf() < pop_chance:
		pop_intensity = randf_range(0.2, 0.4)
	pop_intensity = move_toward(pop_intensity, 0.0, delta * 8.0)

	# Random guttering (brief dims)
	if randf() < gutter_chance:
		gutter_intensity = randf_range(0.3, 0.6)
	gutter_intensity = move_toward(gutter_intensity, 0.0, delta * 4.0)

	# Combine base noise with random events
	var final_value = noise_value + pop_intensity - gutter_intensity
	final_value = clamp(final_value, 0.0, 1.0)

	light_energy = lerp(min_energy, max_energy, final_value)

func _multi_octave_noise(t: float) -> float:
	var value = 0.0
	# Base wave with random phase offset
	value += sin(t * 1.0 + random_offsets[0]) * 0.4
	value += sin(t * 2.3 + random_offsets[1]) * 0.25
	value += sin(t * 5.7 + random_offsets[2]) * 0.2
	value += sin(t * 11.0 + random_offsets[3]) * 0.15
	# Add high-frequency jitter
	value += randf_range(-0.08, 0.08)
	value = (value + 1.0) / 2.0
	return clamp(value, 0.0, 1.0)
