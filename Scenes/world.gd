extends Node3D

@onready var workstation_animator: WorkstationAnimator = $Workbench/WorkstationAnimator
@onready var player: CharacterBody3D = $Player
@onready var wizard_tome: Node3D = $WizardTome

var item_inspector: ItemInspector

func _ready() -> void:
	get_tree().create_timer(3.0).timeout.connect(_play_intro)

	# Connect to player's item inspector
	if player:
		item_inspector = player.get_node_or_null("ItemInspector")
		if item_inspector:
			item_inspector.opened.connect(_on_inspector_opened)
			item_inspector.closed.connect(_on_inspector_closed)


func _play_intro() -> void:
	return
	#DialogueManager.play("intro_welcome")
	#ScreenEffects.apply_cold_effect(1.0, 0.5)  # full intensity, 0.5s fade-in


func _on_inspector_opened(item: Node3D) -> void:
	# Check if this is the wizard tome being inspected
	if item != wizard_tome:
		return

	# Only animate in if the item isn't already cleaned
	var cleanable = item.get_node_or_null("Cleanable") as Cleanable
	if cleanable and cleanable.is_complete:
		return

	if workstation_animator and not workstation_animator.is_animated_in:
		workstation_animator.animate_in()


func _on_inspector_closed() -> void:
	# Check if the tome's cleanable is complete
	if not wizard_tome:
		return

	var cleanable = wizard_tome.get_node_or_null("Cleanable") as Cleanable
	if cleanable and not cleanable.is_complete:
		# Item isn't fully cleaned yet, animate workstation back out
		if workstation_animator and workstation_animator.is_animated_in:
			workstation_animator.animate_out()
