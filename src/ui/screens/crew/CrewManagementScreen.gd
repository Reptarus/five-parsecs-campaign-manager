# Crew Management Screen - Post-Campaign Crew Roster Management
# Allows viewing and managing crew members after campaign creation
class_name CrewManagementScreen
extends CampaignScreenBase

const MAX_CREW_SIZE := 8
const CharacterCardScene := preload("res://src/ui/components/character/CharacterCard.tscn")

# ============ NODE REFERENCES ============
@onready var crew_grid: GridContainer = %CrewGrid
@onready var crew_count_label: Label = %CrewCountLabel
@onready var add_button: Button = %AddButton
@onready var save_button: Button = %SaveButton
@onready var back_button: Button = %BackButton

# ============ STATE ============
var current_campaign = null
var character_cards: Array[CharacterCard] = []
var current_columns: int = 1

func _setup_screen() -> void:
	# Setup responsive grid
	if crew_grid:
		crew_grid.columns = 1
		crew_grid.add_theme_constant_override("h_separation", SPACING_MD)
		crew_grid.add_theme_constant_override("v_separation", SPACING_MD)

	# Connect signals
	if add_button:
		add_button.pressed.connect(_on_add_member_pressed)
	if save_button:
		save_button.pressed.connect(_on_save_pressed)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)

	# Load crew data
	load_crew_data()

func load_crew_data() -> void:
	current_campaign = _get_campaign()
	if not current_campaign:
		push_error("CrewManagementScreen: No active campaign found")
		_update_crew_count()
		return

	_clear_crew_grid()

	# Get crew members — try multiple access patterns
	var members: Array = []
	if current_campaign.has_method("get_crew_members"):
		members = current_campaign.get_crew_members()
	elif current_campaign.has_method("get_active_crew_members"):
		members = current_campaign.get_active_crew_members()
	elif "crew_data" in current_campaign:
		members = current_campaign.crew_data.get("members", [])

	for character in members:
		_create_character_card_entry(character)

	_update_crew_count()

# ============ RESPONSIVE LAYOUT (via CampaignScreenBase) ============

func _apply_mobile_layout() -> void:
	_update_grid_columns_for_mode()

func _apply_tablet_layout() -> void:
	_update_grid_columns_for_mode()

func _apply_desktop_layout() -> void:
	_update_grid_columns_for_mode()

func _update_grid_columns_for_mode() -> void:
	if not crew_grid:
		return
	var new_columns := get_optimal_column_count()
	if _responsive_manager and _responsive_manager.has_method("get_crew_grid_columns"):
		new_columns = _responsive_manager.get_crew_grid_columns()
	var spacing := get_responsive_spacing(SPACING_MD)
	crew_grid.add_theme_constant_override("h_separation", spacing)
	crew_grid.add_theme_constant_override("v_separation", spacing)
	if new_columns != current_columns:
		crew_grid.columns = new_columns
		current_columns = new_columns

# ============ CHARACTER CARD MANAGEMENT ============

func _clear_crew_grid() -> void:
	if not crew_grid:
		return
	for card in character_cards:
		if is_instance_valid(card):
			card.queue_free()
	character_cards.clear()

func _create_character_card_entry(character) -> void:
	if not crew_grid:
		return
	# If character is a Character Resource, use CharacterCard scene
	if character is Character:
		var card: CharacterCard = CharacterCardScene.instantiate()
		crew_grid.add_child(card)
		card.set_variant(CharacterCard.CardVariant.STANDARD)
		card.set_character(character)
		card.view_details_pressed.connect(_on_card_view_details.bind(character))
		card.edit_pressed.connect(_on_card_edit.bind(character))
		card.remove_pressed.connect(_on_card_remove.bind(character))
		card.card_tapped.connect(_on_card_tapped.bind(character))
		character_cards.append(card)
	elif character is Dictionary:
		# Dictionary-based crew member (from save file)
		var name_str: String = character.get("character_name", character.get("name", "Unknown"))
		var species: String = character.get("species", "Unknown")
		var char_class: String = character.get("class", "Unknown")
		var stats := {
			"C": character.get("combat", 0),
			"R": character.get("reaction", 0),
			"T": character.get("toughness", 0),
			"S": character.get("speed", 0),
			"Sv": character.get("savvy", 0),
			"L": character.get("luck", 0),
		}
		var is_captain: bool = character.get("is_captain", false)
		var display_name := name_str
		if is_captain:
			display_name = "[Captain] " + name_str
		var card := _create_character_card(display_name, "%s / %s" % [species, char_class], stats)
		crew_grid.add_child(card)

func _update_crew_count() -> void:
	if not crew_count_label:
		return
	var crew_size := character_cards.size()
	# Also count any dictionary-based cards added directly
	if crew_grid:
		crew_size = max(crew_size, crew_grid.get_child_count())
	crew_count_label.text = "Crew: %d/%d" % [crew_size, MAX_CREW_SIZE]
	if crew_size >= MAX_CREW_SIZE:
		crew_count_label.add_theme_color_override("font_color", COLOR_WARNING)
	else:
		crew_count_label.remove_theme_color_override("font_color")

# ============ CHARACTER CARD SIGNAL HANDLERS ============

func _on_card_view_details(character: Character) -> void:
	var gsm = get_node_or_null("/root/GameStateManager")
	if gsm and gsm.has_method("set_temp_data"):
		gsm.set_temp_data(gsm.TEMP_KEY_SELECTED_CHARACTER, character)
		gsm.navigate_to_screen("character_details")

func _on_card_edit(character: Character) -> void:
	push_warning("CrewManagementScreen: Character editing not yet implemented")

func _on_card_remove(character: Character) -> void:
	var char_name = character.get_display_name()
	var dialog := ConfirmationDialog.new()
	dialog.title = "Remove Crew Member"
	dialog.dialog_text = "Remove %s from crew?\nThis cannot be undone." % char_name
	dialog.ok_button_text = "Remove"
	dialog.cancel_button_text = "Cancel"
	add_child(dialog)
	dialog.confirmed.connect(func():
		_actually_remove_character(character)
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.popup_centered()

func _on_card_tapped(character: Character) -> void:
	pass

func _actually_remove_character(character: Character) -> void:
	if not current_campaign:
		return
	var members: Array = current_campaign.get_crew_members() if current_campaign.has_method("get_crew_members") else []
	var index: int = members.find(character)
	if index >= 0:
		members.remove_at(index)
		var gsm = get_node_or_null("/root/GameStateManager")
		if gsm and gsm.has_method("mark_campaign_modified"):
			gsm.mark_campaign_modified()
		load_crew_data()

# ============ BUTTON HANDLERS ============

func _on_add_member_pressed() -> void:
	if character_cards.size() >= MAX_CREW_SIZE:
		push_warning("CrewManagementScreen: Cannot add member - crew at maximum size")
		return
	var gsm = get_node_or_null("/root/GameStateManager")
	if gsm and gsm.has_method("set_temp_data"):
		gsm.set_temp_data(gsm.TEMP_KEY_CREW_ADD_MODE, true)
		gsm.set_temp_data(gsm.TEMP_KEY_RETURN_SCREEN, "crew_management")
		gsm.navigate_to_scene_path("res://src/ui/screens/character/SimpleCharacterCreator.tscn")

func _on_save_pressed() -> void:
	if _game_state and _game_state.has_method("save_campaign"):
		var result: Dictionary = _game_state.save_campaign()
		if result.get("success", false):
			pass

func _on_back_pressed() -> void:
	var gsm = get_node_or_null("/root/GameStateManager")
	if gsm and gsm.has_method("has_temp_data"):
		if gsm.has_temp_data(gsm.TEMP_KEY_SELECTED_CHARACTER):
			gsm.clear_temp_data(gsm.TEMP_KEY_SELECTED_CHARACTER)
	var router = get_node_or_null("/root/SceneRouter")
	if router:
		router.navigate_to("campaign_turn_controller")
	else:
		get_tree().change_scene_to_file("res://src/ui/screens/campaign/CampaignTurnController.tscn")
