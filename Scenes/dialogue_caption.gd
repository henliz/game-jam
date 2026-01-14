extends CanvasLayer
class_name DialogueCaption

@onready var container: PanelContainer = $CaptionContainer
@onready var speaker_label: Label = $CaptionContainer/VBox/SpeakerLabel
@onready var text_label: Label = $CaptionContainer/VBox/TextLabel

var tween: Tween
var is_visible: bool = false


func _ready() -> void:
	container.modulate.a = 0.0
	container.visible = false


func show_caption(speaker: String, text: String) -> void:
	if speaker.is_empty():
		speaker_label.visible = false
	else:
		speaker_label.visible = true
		speaker_label.text = speaker

	text_label.text = text
	container.visible = true

	if tween:
		tween.kill()

	tween = create_tween()
	tween.tween_property(container, "modulate:a", 1.0, 0.2)
	is_visible = true


func hide_caption() -> void:
	if tween:
		tween.kill()

	tween = create_tween()
	tween.tween_property(container, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): container.visible = false)
	is_visible = false
