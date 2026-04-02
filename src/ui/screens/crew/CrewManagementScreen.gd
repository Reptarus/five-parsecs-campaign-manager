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
		var name_str: String = character.get(
			"character_name", character.get("name", "Unknown"))
		var is_captain: bool = character.get("is_captain", false)

		# Resolve background/class from enum ints or traits
		var bg_val = character.get("background", -1)
		var cls_val = character.get("character_class",
			character.get("class", -1))
		var bg_name: String = _resolve_background_name(bg_val)
		var cls_name: String = _resolve_class_name(cls_val)

		# Captain entries lack flat stats — parse traits
		if bg_name == "Unknown" or cls_name == "Unknown":
			var parsed := _parse_traits(
				character.get("traits", []))
			if bg_name == "Unknown" and not parsed.bg.is_empty():
				bg_name = parsed.bg
			if cls_name == "Unknown" and not parsed.cls.is_empty():
				cls_name = parsed.cls

		# Build stat display — captain may lack flat stats
		var char_ref = character.get("character", null)
		var stats := {}
		if character.has("combat") or character.has("reactions"):
			stats = {
				"C": int(character.get("combat", 0)),
				"R": int(character.get("reactions",
					character.get("reaction", 0))),
				"T": int(character.get("toughness", 0)),
				"S": int(character.get("speed", 0)),
				"Sv": int(character.get("savvy", 0)),
				"L": int(character.get("luck", 0)),
			}
		elif char_ref is Resource and char_ref.has_method("get"):
			stats = {
				"C": int(char_ref.get("combat") if char_ref.get("combat") else 0),
				"R": int(char_ref.get("reactions") if char_ref.get("reactions") else 0),
				"T": int(char_ref.get("toughness") if char_ref.get("toughness") else 0),
				"S": int(char_ref.get("speed") if char_ref.get("speed") else 0),
				"Sv": int(char_ref.get("savvy") if char_ref.get("savvy") else 0),
				"L": int(char_ref.get("luck") if char_ref.get("luck") else 0),
			}

		var display_name := name_str
		if is_captain:
			display_name = "[Captain] " + name_str
		var subtitle := "%s / %s" % [bg_name, cls_name]
		var card := _create_character_card(
			display_name, subtitle, stats)
		crew_grid.add_child(card)

		# Make dict-based cards clickable → navigate to character details
		card.gui_input.connect(
			_on_dict_card_clicked.bind(character)
		)

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
	_on_card_view_details(character)

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
	_on_card_view_details(character)

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
		router.navigate_to("campaign_dashboard")
	else:
		get_tree().change_scene_to_file(
			"res://src/ui/screens/campaign/CampaignDashboard.tscn"
		)

func _on_dict_card_clicked(event: InputEvent, char_dict: Dictionary) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Convert dict to Character Resource for the details screen
		var character := Character.new()
		character.from_dictionary(char_dict)
		var gsm = get_node_or_null("/root/GameStateManager")
		if gsm and gsm.has_method("set_temp_data"):
			gsm.set_temp_data(gsm.TEMP_KEY_SELECTED_CHARACTER, character)
			# Store the source dict so CharacterDetailsScreen can write changes back
			gsm.set_temp_data("source_crew_dict", char_dict)
			gsm.navigate_to_screen("character_details")

# ============ DATA RESOLUTION HELPERS ============

func _parse_traits(traits: Array) -> Dictionary:
	var result := {"bg": "", "cls": ""}
	for trait_str in traits:
		if trait_str is String:
			if trait_str.begins_with("Background: "):
				result.bg = trait_str.substr(12)
			elif trait_str.begins_with("Class: "):
				result.cls = trait_str.substr(7)
	return result

func _resolve_background_name(val) -> String:
	if val is String:
		return val
	if val is int or val is float:
		var idx := int(val)
		var keys: Array = GlobalEnums.Background.keys()
		if idx >= 0 and idx < keys.size():
			return keys[idx].capitalize()
	return "Unknown"

func _resolve_class_name(val) -> String:
	if val is String:
		return val
	if val is int or val is float:
		var idx := int(val)
		var keys: Array = GlobalEnums.CharacterClass.keys()
		if idx >= 0 and idx < keys.size():
			return keys[idx].capitalize()
	return "Unknown"
