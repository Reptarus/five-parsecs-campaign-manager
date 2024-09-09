# MainMenu.gd
extends Control

@onready var new_campaign_button = $MarginContainer/VBoxContainer/NewCampaignButton
@onready var load_campaign_button = $MarginContainer/VBoxContainer/LoadCampaignButton
@onready var settings_button = $MarginContainer/VBoxContainer/SettingsButton
@onready var rules_reference_button = $MarginContainer/VBoxContainer/RulesReferenceButton
@onready var credits_button = $MarginContainer/VBoxContainer/CreditsButton

func _ready():
	new_campaign_button.connect("pressed", Callable(self, "_on_new_campaign_pressed"))
	load_campaign_button.connect("pressed", Callable(self, "_on_load_campaign_pressed"))
	settings_button.connect("pressed", Callable(self, "_on_settings_pressed"))
	rules_reference_button.connect("pressed", Callable(self, "_on_rules_reference_pressed"))
	credits_button.connect("pressed", Callable(self, "_on_credits_pressed"))

func _on_new_campaign_pressed():
	transition_to_scene("res://Resources/CrewSetup.tscn")

func _on_load_campaign_pressed():
	# TODO: Implement campaign loading
	print("Load campaign not implemented yet")
	# Temporary feedback for unimplemented feature
	_show_not_implemented_message("Load Campaign")

func _on_settings_pressed():
	transition_to_scene("open_settings")

func _on_rules_reference_pressed():
	transition_to_scene("res://Scenes/Scene Container/RulesReference.tscn")

func _on_credits_pressed():
	transition_to_scene("open_credits")

func _show_not_implemented_message(feature: String):
	var dialog = AcceptDialog.new()
	dialog.dialog_text = feature + " is not implemented yet."
	add_child(dialog)
	dialog.popup_centered()

func transition_to_scene(scene_method: String):
	# Create a ColorRect for the transition
	var transition = ColorRect.new()
	transition.color = Color(0, 0, 0, 0)  # Start fully transparent
	transition.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(transition)

	# Animate the ColorRect to fade in
	var tween = create_tween()
	tween.tween_property(transition, "color", Color(0, 0, 0, 1), 0.5)
	await tween.finished

	# Call the appropriate method on the Main node
	get_node("/root/Main").call(scene_method)

	# Remove the transition node
	transition.queue_free()
