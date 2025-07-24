extends Control

signal campaign_creation_requested(campaign_data: Dictionary)

@onready var config_summary: RichTextLabel = get_node_or_null("Content/ScrollContainer/ReviewContent/ConfigSummary")
@onready var crew_summary: RichTextLabel = get_node_or_null("Content/ScrollContainer/ReviewContent/CrewSummary")
@onready var create_button: Button = get_node_or_null("Content/ButtonContainer/CreateCampaignButton")

var campaign_data: Dictionary = {}

func _ready() -> void:
	if create_button:
		create_button.pressed.connect(_on_create_campaign_pressed)

func set_campaign_data(data: Dictionary) -> void:
	campaign_data = data
	_update_display()

func _update_display() -> void:
	if config_summary:
		var config_text = "[b]Campaign Configuration:[/b]\n"
		config_text += "Name: %s\n" % campaign_data.get("name", "Unknown")
		config_text += "Difficulty: %s\n" % campaign_data.get("difficulty", "Normal")
		config_summary.text = config_text
	
	if crew_summary:
		var crew_text = "[b]Crew Summary:[/b]\n"
		var crew = campaign_data.get("crew", {})
		crew_text += "Members: %d\n" % crew.get("size", 0)
		crew_text += "Captain: %s\n" % ("Assigned" if crew.get("has_captain", false) else "Not Assigned")
		crew_summary.text = crew_text

func _on_create_campaign_pressed() -> void:
	campaign_creation_requested.emit(campaign_data)

func get_data() -> Dictionary:
	return campaign_data

func is_valid() -> bool:
	return not campaign_data.is_empty()