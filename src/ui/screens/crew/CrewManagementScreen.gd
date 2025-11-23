# Crew Management Screen - Post-Campaign Crew Roster Management
# Allows viewing and managing crew members after campaign creation
class_name CrewManagementScreen
extends Control

# UI Node References
# UI Node References - using %NodeName for maintainability
@onready var crew_list: VBoxContainer = %CrewList
@onready var crew_count_label: Label = %CrewCountLabel
@onready var add_button: Button = %AddButton
@onready var save_button: Button = %SaveButton
@onready var back_button: Button = %BackButton

# State
var current_campaign = null
var character_cards: Array = []

func _ready() -> void:
	print("CrewManagementScreen: Initializing...")

	# Connect button signals
	if add_button:
		add_button.pressed.connect(_on_add_member_pressed)
	if save_button:
		save_button.pressed.connect(_on_save_pressed)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)

	# Load crew data
	load_crew_data()

	print("CrewManagementScreen: Ready")

func load_crew_data() -> void:
	"""Load crew members from current campaign"""
	if not GameStateManager:
		push_error("CrewManagementScreen: GameStateManager not available")
		return

	# Get current campaign
	var game_state = GameStateManager.game_state
	if not game_state or not "current_campaign" in game_state:
		push_error("CrewManagementScreen: No active campaign found")
		return

	current_campaign = game_state.current_campaign
	if not current_campaign:
		push_error("CrewManagementScreen: Current campaign is null")
		return

	print("CrewManagementScreen: Loading crew from campaign...")

	# Clear existing crew cards
	clear_crew_list()

	# Get crew members
	if "crew_members" in current_campaign and current_campaign.crew_members:
		var crew_members = current_campaign.crew_members
		print("CrewManagementScreen: Found %d crew members" % crew_members.size())

		for character in crew_members:
			create_crew_card(character)
	else:
		print("CrewManagementScreen: No crew members found")

	# Update crew count display
	update_crew_count()

func clear_crew_list() -> void:
	"""Remove all crew cards from UI"""
	if not crew_list:
		return

	for child in crew_list.get_children():
		child.queue_free()

	character_cards.clear()

func create_crew_card(character) -> void:
	"""Create a crew member card with character info"""
	if not crew_list:
		return

	# Create card container (expanded height for 3-line layout)
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 80)  # Increased from 60 to accommodate Background/Motivation/Class line

	# Create responsive inner layout
	var responsive_script = preload("res://src/ui/components/ResponsiveContainer.gd")
	var card_container = Container.new()
	card_container.set_script(responsive_script)
	card_container.min_width_for_horizontal = 500  # Lower breakpoint for cards
	card_container.horizontal_spacing = 10
	card_container.vertical_spacing = 5
	card.add_child(card_container)

	# Character info section (left/top panel)
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_container.add_child(info_vbox)

	# Name label
	var name_label = Label.new()
	name_label.text = character.name if "name" in character else "Unknown"
	name_label.add_theme_font_size_override("font_size", 16)
	info_vbox.add_child(name_label)

	# Stats label
	var stats_label = Label.new()
	var combat = character.combat if "combat" in character else 0
	var toughness = character.toughness if "toughness" in character else 0
	var savvy = character.savvy if "savvy" in character else 0
	stats_label.text = "Combat: %d | Toughness: %d | Savvy: %d" % [combat, toughness, savvy]
	stats_label.add_theme_font_size_override("font_size", 12)
	stats_label.modulate = Color(0.8, 0.8, 0.8)
	info_vbox.add_child(stats_label)

	# Character creation info label (Background/Motivation/Class)
	var creation_info_label = Label.new()
	var background = character.background if "background" in character else "Unknown"
	var motivation = character.motivation if "motivation" in character else "Unknown"
	var char_class = character.character_class if "character_class" in character else "Unknown"
	var origin = character.origin if "origin" in character else "HUMAN"
	creation_info_label.text = "%s | %s/%s/%s" % [origin, background, motivation, char_class]
	creation_info_label.add_theme_font_size_override("font_size", 11)
	creation_info_label.modulate = Color(0.7, 0.9, 1.0)  # Light blue to distinguish from stats
	info_vbox.add_child(creation_info_label)

	# Actions section (right/bottom panel) - will stack vertically on narrow screens
	var actions_vbox = VBoxContainer.new()
	card_container.add_child(actions_vbox)

	# Status icon
	var status_label = Label.new()
	status_label.text = "✅"  # Default to active
	status_label.add_theme_font_size_override("font_size", 24)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	actions_vbox.add_child(status_label)

	# Buttons container
	var button_box = HBoxContainer.new()
	button_box.alignment = BoxContainer.ALIGNMENT_CENTER
	actions_vbox.add_child(button_box)

	# View Details button
	var details_btn = Button.new()
	details_btn.text = "View Details"
	details_btn.custom_minimum_size = Vector2(120, 0)
	details_btn.pressed.connect(_on_view_character.bind(character))
	button_box.add_child(details_btn)

	# Remove button
	var remove_btn = Button.new()
	remove_btn.text = "Remove"
	remove_btn.custom_minimum_size = Vector2(80, 0)
	remove_btn.pressed.connect(_on_remove_character.bind(character))
	button_box.add_child(remove_btn)

	# Add to crew list
	crew_list.add_child(card)
	character_cards.append(card)

func update_crew_count() -> void:
	"""Update the crew count label"""
	if not crew_count_label:
		return

	var crew_size = character_cards.size()
	crew_count_label.text = "%d Active" % crew_size

func _on_view_character(character) -> void:
	"""Navigate to character details screen"""
	print("CrewManagementScreen: Viewing character - ", character.name if "name" in character else "Unknown")

	# Store character reference for CharacterDetailsScreen to access
	if GameStateManager:
		GameStateManager.set_temp_data(GameStateManager.TEMP_KEY_SELECTED_CHARACTER, character)

	# Navigate to character details screen using standardized navigation
	GameStateManager.navigate_to_screen("character_details")

func _on_remove_character(character) -> void:
	"""Remove a character from the crew (with confirmation)"""
	var char_name = character.name if "name" in character else "Unknown"
	print("CrewManagementScreen: Remove character requested - ", char_name)

	# Create confirmation dialog
	var dialog = ConfirmationDialog.new()
	dialog.title = "Remove Crew Member"
	dialog.dialog_text = "Remove %s from crew?\nThis cannot be undone." % char_name
	dialog.ok_button_text = "Remove"
	dialog.cancel_button_text = "Cancel"
	add_child(dialog)

	# Connect and show
	dialog.confirmed.connect(func():
		_actually_remove_character(character)
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.popup_centered()

func _actually_remove_character(character) -> void:
	"""Actually remove the character after confirmation"""
	if current_campaign and "crew_members" in current_campaign:
		var index = current_campaign.crew_members.find(character)
		if index >= 0:
			current_campaign.crew_members.remove_at(index)
			print("CrewManagementScreen: Removed character at index %d" % index)

			# Mark campaign as modified
			if GameStateManager:
				GameStateManager.mark_campaign_modified()

			# Reload crew display
			load_crew_data()

func _on_add_member_pressed() -> void:
	"""Add a new crew member"""
	print("CrewManagementScreen: Add member requested")

	# Store return context for character creation
	if GameStateManager:
		GameStateManager.set_temp_data(GameStateManager.TEMP_KEY_CREW_ADD_MODE, true)
		GameStateManager.set_temp_data(GameStateManager.TEMP_KEY_RETURN_SCREEN, "crew_management")

	# Navigate to character creation using standardized navigation
	GameStateManager.navigate_to_scene_path("res://src/ui/screens/crew/InitialCrewCreation.tscn")

func _on_save_pressed() -> void:
	"""Save campaign changes"""
	print("CrewManagementScreen: Saving campaign changes...")

	if GameState and GameState.has_method("save_game"):
		var success = GameState.save_game("current_campaign", true)
		if success:
			print("CrewManagementScreen: Campaign saved successfully")
		else:
			push_warning("CrewManagementScreen: Save may be queued")

func _on_back_pressed() -> void:
	"""Return to campaign dashboard"""
	print("CrewManagementScreen: Returning to dashboard...")

	# Clear temp data
	if GameStateManager and GameStateManager.has_temp_data(GameStateManager.TEMP_KEY_SELECTED_CHARACTER):
		GameStateManager.clear_temp_data(GameStateManager.TEMP_KEY_SELECTED_CHARACTER)

	# Navigate back to dashboard using standardized navigation
	GameStateManager.navigate_to_screen("campaign_dashboard")
