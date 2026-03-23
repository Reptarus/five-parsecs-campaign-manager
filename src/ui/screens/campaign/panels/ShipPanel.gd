extends FiveParsecsCampaignPanel

## Five Parsecs Ship Assignment Panel
## Production-ready implementation with comprehensive ship generation

# Progress tracking
const STEP_NUMBER := 5  # Step 5 of 7 in campaign wizard (Core Rules: Ship after Equipment)

# GlobalEnums available as autoload singleton

signal ship_updated(ship_data: Dictionary)
signal ship_setup_complete(ship_data: Dictionary)

const CampaignStateManager = preload("res://src/core/campaign/creation/CampaignCreationStateManager.gd")
# SecurityValidator is inherited from BaseCampaignPanel
# ValidationResult is inherited from BaseCampaignPanel

# Autonomous signals for coordinator pattern
signal ship_data_complete(data: Dictionary)
signal ship_validation_failed(errors: Array[String])

# Granular signals for real-time integration
signal ship_data_changed(data: Dictionary)
signal ship_configuration_complete(ship: Dictionary)

var local_ship_data: Dictionary = {
	"ship": {},
	"is_complete": false
}
var is_ship_complete: bool = false
# Note: last_validation_errors is inherited from BaseCampaignPanel

# UI Components with safe access
var ship_name_input: LineEdit
var ship_type_option: OptionButton
var hull_points_spinbox: SpinBox
var debt_spinbox: SpinBox
var traits_container: VBoxContainer
var generate_button: Button
var reroll_button: Button
var select_button: Button

# Ship manager instance (optional for advanced ship management)
var ship_manager_instance: Node = null
var ship_container: Control = null

var ship_data: Dictionary = {
	"name": "",
	"type": "Freelancer",
	"hull_points": 10,
	"max_hull": 10,
	"debt": 1,
	"traits": [],
	"components": [],
	"is_configured": false
}
var available_ships: Array[Dictionary] = []

# Ship data loaded from ships.json (Core Rules pp.68-71)
var _ships_db: Dictionary = {}

# Guard variable to prevent duplicate panel_completed emissions
var _completion_emitted: bool = false

func _on_campaign_state_updated(state_data: Dictionary) -> void:
	## Override from interface - handle campaign state updates
	# CRITICAL FIX: Ignore updates that originated from this panel to prevent double-loading
	var source = state_data.get("source", "")
	if source == "ship_panel":
		return

	var phase = state_data.get("phase", "")
	if phase == "ship_update":
		return

	# Update panel state based on campaign state if needed
	if state_data.has("ship") and state_data.ship is Dictionary:
		var ship_state_data = state_data.ship
		
		# Update local ship state from external changes - merge instead of replace
		if ship_state_data.has("name") or ship_state_data.has("type") or ship_state_data.has("hull_points"):
			# Merge the received data with existing ship_data
			for key in ship_state_data.keys():
				ship_data[key] = ship_state_data[key]
			_update_ship_display()
		else:
			pass
	else:
		pass

func _ready() -> void:
	# Set panel info before base initialization with more informative description
	set_panel_info("Ship Selection", "Choose your starting vessel. Ship type affects cargo capacity and combat capabilities.")

	# Call parent _ready() to initialize BaseCampaignPanel structure
	super._ready()

	# Load ship data from JSON
	_load_ships_database()

	# Apply design system styling to scene-defined inputs
	call_deferred("_apply_input_styling")

	# NOTE: Progress indicator removed - CampaignCreationUI handles progress display

	# COMPREHENSIVE DEBUG OUTPUT - Panel Initialization
	call_deferred("_log_panel_initialization_debug")

	# Initialize ship-specific functionality
	_initialize_security_validator()
	# Initialize components immediately after base structure is ready
	_initialize_components()

	# BUG-017/016/023: Auto-generate a ship so Next is immediately available.
	# The user can still re-roll via the Reroll button.
	call_deferred("_auto_generate_if_needed")

# NOTE: _add_progress_indicator() removed - CampaignCreationUI handles progress display centrally

func _apply_input_styling() -> void:
	## Apply design system styling to scene-defined inputs (eliminates stretched teal bars)
	# Style OptionButton
	if ship_type_option:
		_style_option_button(ship_type_option)

	# Style LineEdit
	if ship_name_input:
		_style_line_edit(ship_name_input)

	# Style SpinBoxes with touch-friendly sizing
	if hull_points_spinbox:
		hull_points_spinbox.custom_minimum_size.y = TOUCH_TARGET_MIN
	if debt_spinbox:
		debt_spinbox.custom_minimum_size.y = TOUCH_TARGET_MIN

	# Style Buttons
	if generate_button:
		_style_button(generate_button)
	if reroll_button:
		_style_button(reroll_button)
	if select_button:
		_style_button(select_button)


# NOTE: _style_button() now inherited from BaseCampaignPanel - removed duplicate

func _wrap_form_in_cards() -> void:
	## Wrap form sections in glass morphism cards for visual consistency
	var content_node = get_node_or_null("ContentMargin/MainContent/FormContent/FormContainer/Content")
	if not content_node:
		return

	# Create a new container to hold the cards
	var cards_container := VBoxContainer.new()
	cards_container.name = "CardsContainer"
	cards_container.add_theme_constant_override("separation", SPACING_LG)

	# === SHIP IDENTITY CARD (Name + Type) ===
	var identity_card := _create_form_section_card("SHIP IDENTITY", "Name your vessel and select its class.")
	var identity_content := identity_card.get_node("CardMargin/CardContent")

	# Move ship name section into card
	var ship_name_section = content_node.get_node_or_null("ShipName")
	if ship_name_section:
		content_node.remove_child(ship_name_section)
		identity_content.add_child(ship_name_section)

	# Move ship type section into card
	var ship_type_section = content_node.get_node_or_null("ShipType")
	if ship_type_section:
		content_node.remove_child(ship_type_section)
		identity_content.add_child(ship_type_section)

	cards_container.add_child(identity_card)

	# === SHIP SPECS CARD (Hull + Debt) ===
	var specs_card := _create_form_section_card("SHIP SPECIFICATIONS", "Hull integrity and financial obligations.")
	var specs_content := specs_card.get_node("CardMargin/CardContent")

	# Move hull points section into card
	var hull_section = content_node.get_node_or_null("HullPoints")
	if hull_section:
		content_node.remove_child(hull_section)
		specs_content.add_child(hull_section)

	# Move debt section into card
	var debt_section = content_node.get_node_or_null("Debt")
	if debt_section:
		content_node.remove_child(debt_section)
		specs_content.add_child(debt_section)

	# Move ship stats if present
	var stats_section = content_node.get_node_or_null("ShipStats")
	if stats_section:
		content_node.remove_child(stats_section)
		specs_content.add_child(stats_section)

	cards_container.add_child(specs_card)

	# === SHIP TRAITS CARD ===
	var traits_section = content_node.get_node_or_null("Traits")
	if traits_section:
		var traits_card := _create_form_section_card("SHIP TRAITS", "Special capabilities and modifications.")
		var traits_content := traits_card.get_node("CardMargin/CardContent")
		content_node.remove_child(traits_section)
		traits_content.add_child(traits_section)
		cards_container.add_child(traits_card)

	# === ACTION BUTTONS (no card, centered) ===
	var controls_section = content_node.get_node_or_null("Controls")
	if controls_section:
		content_node.remove_child(controls_section)
		controls_section.alignment = BoxContainer.ALIGNMENT_CENTER
		cards_container.add_child(controls_section)

	# Add cards container to content
	content_node.add_child(cards_container)
	content_node.move_child(cards_container, 0)


func _create_form_section_card(title: String, description: String = "") -> PanelContainer:
	## Create a glass morphism card for form sections
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _create_form_card_style())

	var margin := MarginContainer.new()
	margin.name = "CardMargin"
	margin.add_theme_constant_override("margin_left", SPACING_MD)
	margin.add_theme_constant_override("margin_right", SPACING_MD)
	margin.add_theme_constant_override("margin_top", SPACING_MD)
	margin.add_theme_constant_override("margin_bottom", SPACING_MD)
	card.add_child(margin)

	var content := VBoxContainer.new()
	content.name = "CardContent"
	content.add_theme_constant_override("separation", SPACING_SM)
	margin.add_child(content)

	# Card header
	var header := Label.new()
	header.text = title
	header.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	header.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	content.add_child(header)

	# Separator
	var sep := HSeparator.new()
	sep.modulate = COLOR_BORDER
	content.add_child(sep)

	# Description (if provided)
	if not description.is_empty():
		var desc := Label.new()
		desc.text = description
		desc.add_theme_font_size_override("font_size", FONT_SIZE_XS)
		desc.add_theme_color_override("font_color", Color(COLOR_TEXT_SECONDARY, 0.7))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(desc)

	return card

func _create_form_card_style() -> StyleBoxFlat:
	## Create glass morphism style for form cards
	var style := StyleBoxFlat.new()
	style.bg_color = Color(COLOR_ELEVATED.r, COLOR_ELEVATED.g, COLOR_ELEVATED.b, 0.8)
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(0)  # Margin handled by MarginContainer
	return style

func _setup_panel_content() -> void:
	## Override from BaseCampaignPanel - setup ship-specific content
	# This will be called after BaseCampaignPanel structure is ready
	pass

func _initialize_security_validator() -> void:
	## Initialize security validator for input sanitization
	# Security validator initialization - placeholder for future implementation
	pass

func _initialize_components() -> void:
	## Initialize ship panel with defensive null checks and programmatic fallbacks
	
	# NOTE: ShipPanelTransitionFix.gd file not found - using inline fixes
	# Apply basic transition fixes directly
	
	# Store Content node reference once with fallback creation
	# Content node is nested in BaseCampaignPanel structure
	var content_node = get_node_or_null("ContentMargin/MainContent/FormContent/FormContainer/Content")
	if not content_node:
		push_warning("ShipPanel: Content node missing - creating programmatically")
		content_node = _create_fallback_ui()
		add_child(content_node)
	else:
		pass
	
	# METHOD 1: Try unique names first (most reliable if set in scene)
	ship_name_input = get_node_or_null("%ShipNameInput")
	ship_type_option = get_node_or_null("%ShipTypeOption") 
	hull_points_spinbox = get_node_or_null("%HullPointsSpinBox")
	debt_spinbox = get_node_or_null("%DebtSpinBox")
	
	# METHOD 2: If unique names fail, use full paths with CORRECT node names
	if not ship_name_input:
		ship_name_input = content_node.get_node_or_null("ShipName/ShipNameInput")
		if ship_name_input:
			pass
		else:
			ship_name_input = _create_ship_name_section(content_node)
	else:
		pass
	
	if not ship_type_option:
		ship_type_option = content_node.get_node_or_null("ShipType/ShipTypeOption")
		if ship_type_option:
			pass
		else:
			ship_type_option = _create_ship_type_section(content_node)
	else:
		pass

	# Ensure ship types are populated (scene OptionButton may be empty)
	if ship_type_option and ship_type_option.get_item_count() == 0:
		_populate_ship_types()

	if not hull_points_spinbox:
		hull_points_spinbox = content_node.get_node_or_null("HullPoints/HullPointsSpinBox")
		if hull_points_spinbox:
			pass
		else:
			hull_points_spinbox = _create_hull_points_section(content_node)
	else:
		pass
	
	if not debt_spinbox:
		# Note: Scene might have DebtSpinBox not just SpinBox
		debt_spinbox = content_node.get_node_or_null("Debt/DebtSpinBox")
		if not debt_spinbox:
			debt_spinbox = content_node.get_node_or_null("Debt/SpinBox")
		if debt_spinbox:
			pass
		else:
			debt_spinbox = _create_debt_section(content_node)
	else:
		pass

	# BUG-016 FIX: Override scene-defined spinbox properties that have wrong values
	# Scene has debt step=100 (should be 1) and hull max=20 (should be 100)
	if debt_spinbox:
		debt_spinbox.step = 1
		debt_spinbox.max_value = 200
	if hull_points_spinbox:
		hull_points_spinbox.max_value = 100
	
	# Traits might be at different location
	traits_container = content_node.get_node_or_null("Traits/Container")
	if not traits_container:
		traits_container = content_node.get_node_or_null("Traits")
		if traits_container:
			pass
		else:
			traits_container = _create_traits_section(content_node)
	else:
		pass
	
	# Control buttons with fallbacks
	generate_button = content_node.get_node_or_null("Controls/GenerateButton")
	reroll_button = content_node.get_node_or_null("Controls/RerollButton")
	select_button = content_node.get_node_or_null("Controls/SelectButton")
	
	# Sprint 26.6: Hide unimplemented Select button
	if select_button:
		select_button.visible = false
		select_button.tooltip_text = "Ship presets coming in a future update"

	if not generate_button or not reroll_button:
		_create_control_buttons(content_node)
	
	# Only create fallback if critical components are missing
	var critical_missing = not ship_name_input or not ship_type_option
	if critical_missing:
		push_warning("ShipPanel: Critical UI components missing - creating fallback")
		_create_fallback_ui()
	else:
		pass
	
	# Validate no duplication with improved logic
	call_deferred("_validate_no_ui_duplication")
	
	
	# Skip ShipManager integration - handle directly in panel

	_connect_signals()
	_initialize_ship_data()
	# NOTE: Do NOT call _generate_ship() here — _auto_generate_if_needed() handles it
	# to avoid double-generation (which causes spinbox/card value mismatch BUG-016)
	# Wrap form sections in glass morphism cards
	call_deferred("_wrap_form_in_cards")
	call_deferred("emit_panel_ready")

# Remove ShipManager integration to prevent overlay issues
func _setup_ship_management_ui() -> void:
	## Setup ship management UI directly in the panel
	
	# Use existing Content node from scene
	var content_node = get_node_or_null("ContentMargin/MainContent/FormContent/FormContainer/Content")
	if not content_node:
		content_node = get_node_or_null("Content")
	
	if not content_node:
		push_warning("ShipPanel: Content node not found for ship management UI")
		return
	
	# Ship management UI is already defined in the scene file
	# Just connect the existing controls
	_connect_existing_controls()
	

func _connect_ship_manager_signals() -> void:
	## Stub function - no ShipManager to connect
	pass

func _initialize_ship_manager_data() -> void:
	## Stub function - no ShipManager to initialize
	pass

func _connect_existing_controls() -> void:
	## Connect the existing UI controls from the scene
	# The controls are already defined in ShipPanel.tscn
	# Just ensure they're connected properly
	if generate_button and not generate_button.pressed.is_connected(_on_generate_pressed):
		generate_button.pressed.connect(_on_generate_pressed)
	if reroll_button and not reroll_button.pressed.is_connected(_on_reroll_pressed):
		reroll_button.pressed.connect(_on_reroll_pressed)

	# No ShipManager integration - handle everything directly

func _get_current_ship_data() -> Dictionary:
	## Get current ship data from local state
	return ship_data

# ShipManager signal handlers
func _on_ship_repaired(hull_points: int) -> void:
	## Handle ship repair from ShipManager
	
	# Update local ship data
	_update_ship_data_from_manager()
	
	# Emit signal to coordinator
	ship_data_changed.emit(local_ship_data)
	
	# PHASE 2 INTEGRATION: Update coordinator state
	_notify_coordinator_of_ship_update()

func _validate_no_ui_duplication() -> void:
	## Ensure no UI duplication occurred - improved to only remove true duplicates
	var content_containers = []
	var form_containers = []
	
	# Check all children recursively
	_find_containers_recursive(self, content_containers, form_containers)
	
	if content_containers.size() > 1:
		push_warning("ShipPanel: Duplication detected - found %d Content containers" % content_containers.size())
		
		# Only remove duplicates that are at the same hierarchy level with same parent
		var parent_paths = {}
		var containers_to_remove = []
		
		for container_path in content_containers:
			var node = get_node_or_null(container_path)
			if node and node.get_parent():
				var parent_path = str(node.get_parent().get_path())
				var node_name = node.name
				var key = parent_path + "/" + node_name
				
				if parent_paths.has(key):
					# This is a true duplicate - same parent, same name
					containers_to_remove.append(container_path)
				else:
					parent_paths[key] = container_path
		
		# Remove only the true duplicates
		for container_path in containers_to_remove:
			var node = get_node_or_null(container_path)
			if node:
				node.queue_free()
		
		if containers_to_remove.size() > 0:
			pass
		else:
			pass
	

func _find_containers_recursive(node: Node, content_list: Array, form_list: Array) -> void:
	## Recursively find all Content and FormContainer nodes
	# Match exact name "Content" only — not substrings like "FormContent", "MainContent"
	if node.name == "Content":
		content_list.append(node.get_path())
	if node.name == "FormContainer":
		form_list.append(node.get_path())

	for child in node.get_children():
		_find_containers_recursive(child, content_list, form_list)

func _notify_coordinator_of_ship_update() -> void:
	## Notify the campaign coordinator of ship state changes
	# Use base class method instead of get_parent() traversal
	var coordinator = get_coordinator_reference()
	if coordinator and coordinator.has_method("update_ship_state"):
		coordinator.update_ship_state(ship_data)
	else:
		pass

func _on_debt_paid(amount: int) -> void:
	## Handle debt payment from ShipManager
	
	# Update local ship data
	_update_ship_data_from_manager()
	
	# Emit signal to coordinator
	ship_data_changed.emit(local_ship_data)
	
	# PHASE 2 INTEGRATION: Update coordinator state
	_notify_coordinator_of_ship_update()

func _on_upgrade_purchased(upgrade: Dictionary) -> void:
	## Handle upgrade purchase from ShipManager
	# Update local ship data
	_update_ship_data_from_manager()
	
	# Emit signal to coordinator
	ship_data_changed.emit(local_ship_data)
	
	# PHASE 2 INTEGRATION: Update coordinator state
	_notify_coordinator_of_ship_update()

func _on_travel_initiated() -> void:
	## Handle travel initiation from ShipManager
	
	# Update local ship data
	_update_ship_data_from_manager()
	
	# Emit signal to coordinator
	ship_data_changed.emit(local_ship_data)
	
	# PHASE 2 INTEGRATION: Update coordinator state
	_notify_coordinator_of_ship_update()

func _update_ship_data_from_manager() -> void:
	## Update local ship data from ShipManager
	if not ship_manager_instance:
		return
	
	# Get ship state from manager if available
	if ship_manager_instance.has_method("get_ship_data"):
		var manager_state = ship_manager_instance.get_ship_data()
		if manager_state:
			ship_data = manager_state
			_update_ship_display()

func _connect_signals() -> void:
	## Establish signal connections with error handling
	if generate_button and not generate_button.pressed.is_connected(_on_generate_pressed):
		generate_button.pressed.connect(_on_generate_pressed)
	if reroll_button and not reroll_button.pressed.is_connected(_on_reroll_pressed):
		reroll_button.pressed.connect(_on_reroll_pressed)
	if select_button and not select_button.pressed.is_connected(_on_select_specific_pressed):
		select_button.pressed.connect(_on_select_specific_pressed)
	if ship_name_input and not ship_name_input.text_changed.is_connected(_on_ship_name_changed):
		ship_name_input.text_changed.connect(_on_ship_name_changed)

	# Connect input field signals for real-time updates
	if ship_type_option and not ship_type_option.item_selected.is_connected(_on_ship_type_changed):
		ship_type_option.item_selected.connect(_on_ship_type_changed)
	if hull_points_spinbox and not hull_points_spinbox.value_changed.is_connected(_on_hull_points_changed):
		hull_points_spinbox.value_changed.connect(_on_hull_points_changed)
	if debt_spinbox and not debt_spinbox.value_changed.is_connected(_on_debt_changed):
		debt_spinbox.value_changed.connect(_on_debt_changed)

func _load_ships_database() -> void:
	var path := "res://data/ships.json"
	if not FileAccess.file_exists(path):
		push_warning("ShipPanel: ships.json not found, using fallback data")
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("ShipPanel: Failed to parse ships.json")
		return
	if json.data is Dictionary:
		_ships_db = json.data

func _get_ship_type_data(ship_name: String) -> Dictionary:
	## Look up ship type data from ships.json by display name
	for entry in _ships_db.get("ship_types", []):
		if entry is Dictionary and entry.get("name", "") == ship_name:
			return entry
	return {}

func _initialize_ship_data() -> void:
	## Initialize ship data structure
	# Reset to default values
	ship_data.clear()
	ship_data = {
		"name": "",
		"type": "Freelancer",
		"hull_points": 10,
		"max_hull": 10,
		"debt": 1,
		"traits": [],
		"components": [],
		"is_configured": false
	}

func _generate_ship_name() -> String:
	## Generate a random ship name — Compendium DLC tables (pp.157-162) if available,
	## then ships.json, otherwise hardcoded fallback.
	var CompendiumWorldOptions = load("res://src/data/compendium_world_options.gd")
	if CompendiumWorldOptions:
		var compendium_name: String = CompendiumWorldOptions.generate_ship_name()
		if not compendium_name.is_empty():
			return compendium_name
	# JSON-driven name generation from ships.json
	var names_data: Dictionary = _ships_db.get("ship_names", {})
	var prefixes: Array = names_data.get("prefixes", ["Star", "Nova", "Dawn", "Void", "Deep", "Far", "Solar", "Cosmic", "Stellar", "Astral"])
	var suffixes: Array = names_data.get("suffixes", ["Runner", "Wanderer", "Seeker", "Hunter", "Trader", "Explorer", "Voyager", "Nomad", "Spirit", "Quest"])
	return "%s %s" % [prefixes[randi() % prefixes.size()], suffixes[randi() % suffixes.size()]]

func _populate_ship_types() -> void:
	## Populate ship type dropdown from ships.json (Core Rules pp.68-71)
	if not ship_type_option:
		return
	ship_type_option.clear()
	var ship_types: Array = _ships_db.get("ship_types", [])
	if ship_types.is_empty():
		# Fallback if JSON not loaded
		for sname in ["Freelancer", "Worn Freighter", "Scout Ship", "Patrol Boat", "Armed Trader", "Converted Transport", "Light Freighter"]:
			ship_type_option.add_item(sname)
		return
	for entry in ship_types:
		if entry is Dictionary:
			ship_type_option.add_item(entry.get("name", "Unknown"))

func _calculate_starting_hull(ship_type: String) -> int:
	## Calculate starting hull points from ships.json (Core Rules p.31: 20-40)
	var data: Dictionary = _get_ship_type_data(ship_type)
	return int(data.get("hull_points", 30))

func _calculate_starting_debt(ship_type: String) -> int:
	## Calculate starting debt from ships.json (Core Rules p.31: 1D6 + base)
	var data: Dictionary = _get_ship_type_data(ship_type)
	# New format: debt_base + 1D6
	if data.has("debt_base"):
		return int(data.get("debt_base", 20)) + randi_range(1, 6)
	# Legacy format fallback
	var debt_min: int = int(data.get("debt_min", 20))
	var debt_max: int = int(data.get("debt_max", 26))
	if debt_min == debt_max:
		return debt_min
	return randi_range(debt_min, debt_max)

func _calculate_cargo_capacity(_ship_type: String) -> int:
	## Cargo capacity — not in Core Rules ship table, app feature
	return 0

func _update_ship_display() -> void:
	## Update UI to reflect current ship data with glass morphism styling
	# Ensure ship_data has all required fields
	_ensure_ship_data_structure()
	
	if ship_name_input:
		ship_name_input.text = ship_data.get("name", "")
	if ship_type_option:
		ship_type_option.text = ship_data.get("type", "")
	if hull_points_spinbox:
		hull_points_spinbox.value = ship_data.get("hull_points", 0)
	if debt_spinbox:
		debt_spinbox.value = ship_data.get("debt", 0)

	_update_traits_display()
	_update_ship_stats_display()

func _ensure_ship_data_structure() -> void:
	## Ensure ship_data has all required fields with default values
	if not ship_data.has("name"):
		ship_data["name"] = ""
	if not ship_data.has("type"):
		ship_data["type"] = "Freelancer"
	if not ship_data.has("hull_points"):
		ship_data["hull_points"] = 10
	if not ship_data.has("max_hull"):
		ship_data["max_hull"] = 10
	if not ship_data.has("debt"):
		ship_data["debt"] = 1
	if not ship_data.has("traits"):
		ship_data["traits"] = []
	if not ship_data.has("components"):
		ship_data["components"] = []
	if not ship_data.has("is_configured"):
		ship_data["is_configured"] = false

func _update_traits_display() -> void:
	## Update the traits display with glass morphism styling
	if not traits_container:
		return

	# Clear existing traits
	for child in traits_container.get_children():
		child.queue_free()

	# Add trait labels - defensive check for traits array
	if ship_data.has("traits") and ship_data.traits is Array:
		for ship_trait in ship_data.traits:
			if ship_trait is String:
				# GLASS MORPHISM: Create styled trait badge
				var trait_panel = PanelContainer.new()
				trait_panel.add_theme_stylebox_override("panel", _create_glass_card_style(0.6))
				trait_panel.custom_minimum_size.y = 32
				
				var trait_hbox = HBoxContainer.new()
				trait_hbox.add_theme_constant_override("separation", SPACING_SM)
				
				# Trait icon (visual indicator)
				var icon_label = Label.new()
				icon_label.text = "⭐"  # Star icon for traits
				icon_label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
				icon_label.add_theme_color_override("font_color", COLOR_ACCENT)
				trait_hbox.add_child(icon_label)
				
				# Trait name
				var label = Label.new()
				label.text = ship_trait
				label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
				label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
				label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				trait_hbox.add_child(label)
				
				trait_panel.add_child(trait_hbox)
				traits_container.add_child(trait_panel)
	else:
		# Initialize traits array if missing
		if not ship_data.has("traits"):
			ship_data["traits"] = []

func _update_ship_stats_display() -> void:
	## Create glass morphism stat containers for ship stats
	# Find or create stats container
	var content_node = get_node_or_null("ContentMargin/MainContent/FormContent/FormContainer/Content")
	if not content_node:
		return
	
	# Check if stats container already exists
	var stats_container = content_node.get_node_or_null("ShipStats")
	if stats_container:
		# Update existing stats
		for child in stats_container.get_children():
			child.queue_free()
	else:
		# Create new stats container
		stats_container = HBoxContainer.new()
		stats_container.name = "ShipStats"
		stats_container.add_theme_constant_override("separation", SPACING_MD)
		
		# Insert stats above hull/debt controls
		var hull_section = content_node.get_node_or_null("HullPoints")
		if hull_section:
			var hull_index = hull_section.get_index()
			content_node.add_child(stats_container)
			content_node.move_child(stats_container, hull_index)
		else:
			content_node.add_child(stats_container)
	
	# Create glass morphism stat cards
	var hull_stat = _create_ship_stat_card("Hull", ship_data.get("hull_points", 0), ship_data.get("max_hull", 0), COLOR_BLUE)
	stats_container.add_child(hull_stat)
	
	var debt_stat = _create_ship_stat_card("Debt", ship_data.get("debt", 0), 0, COLOR_AMBER)
	stats_container.add_child(debt_stat)

func _create_ship_stat_card(stat_name: String, current_value: int, max_value: int, accent_color: Color) -> PanelContainer:
	## Create a glass morphism stat card for ship stats
	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _create_glass_card_style(0.8))
	panel.custom_minimum_size = Vector2(120, 80)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", SPACING_XS)
	
	# Stat name label
	var name_label = Label.new()
	name_label.text = stat_name.to_upper()
	name_label.add_theme_font_size_override("font_size", FONT_SIZE_XS)
	name_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)
	
	# Stat value
	var value_label = Label.new()
	if max_value > 0:
		value_label.text = "%d / %d" % [current_value, max_value]
	else:
		value_label.text = str(current_value)
	value_label.add_theme_font_size_override("font_size", FONT_SIZE_XL)
	value_label.add_theme_color_override("font_color", accent_color)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(value_label)
	
	panel.add_child(vbox)
	return panel

func _auto_generate_if_needed() -> void:
	## BUG-017/016/023: Auto-generate ship on panel entry if no ship data exists yet.
	## This eliminates the dead-end where data is visible but Next is disabled.
	if not local_ship_data.get("is_complete", false):
		_on_generate_pressed()

	# After auto-generation, hide Generate and show Reroll as the primary action
	if generate_button:
		generate_button.visible = false
	if reroll_button:
		reroll_button.visible = true
		reroll_button.text = "Re-roll Ship"

	# Direct coordinator notification as fallback (signals may debounce)
	var coord: Node = null
	if has_method("get_coordinator"):
		coord = get_coordinator()
	elif _coordinator:
		coord = _coordinator
	if coord and coord.has_method("mark_phase_complete"):
		coord.mark_phase_complete(4, true)  # 4 = SHIP_ASSIGNMENT

# Signal handlers
func _on_generate_pressed() -> void:
	## Generate ship and mark panel as complete.
	## _generate_ship() populates ship_data and updates the UI via _update_ship_display().
	## We then set completion flags and emit signals ONCE with the final data.
	_generate_ship()

	# Mark panel as complete after successful generation
	local_ship_data["is_complete"] = true
	local_ship_data["ship"] = ship_data.duplicate()
	ship_data["is_configured"] = true
	is_ship_complete = true

	# UI is already updated by _generate_ship() → _update_ship_display()
	# No need to set spinboxes/inputs again (was causing spinbox/card mismatch BUG-016)

	# Emit completion signals with flat data dict
	_update_validation_status()
	panel_data_changed.emit(local_ship_data)
	panel_validation_changed.emit(true)
	var complete_data: Dictionary = _build_ship_data()
	ship_data_complete.emit(complete_data)
	# Note: _generate_ship() already emits ship_updated with raw ship_data,
	# but we emit again with the enriched complete_data (includes is_complete flag)
	ship_updated.emit(complete_data)
	
func _on_reroll_pressed() -> void:
	## Re-roll delegates to _on_generate_pressed() to ensure completion flags are set
	_on_generate_pressed()

func _on_select_specific_pressed() -> void:
	## Show ship selection dialog - implement based on your UI architecture
	pass


func _build_ship_data() -> Dictionary:
	## Internal: Build ship data dictionary
	var data = ship_data.duplicate()
	data["is_complete"] = local_ship_data.is_complete
	data["validation_errors"] = last_validation_errors.duplicate()
	data["completion_level"] = _calculate_completion_level()
	data["cargo_capacity"] = _calculate_cargo_capacity(
		data.get("type", "Worn Freighter"))
	data["metadata"] = {
		"last_modified": Time.get_unix_time_from_system(),
		"version": "1.0",
		"panel_type": "ship_assignment"
	}
	return data

func get_ship_data() -> Dictionary:
	## DEPRECATED: Use get_panel_data() instead.
	push_warning("ShipPanel.get_ship_data() is deprecated - use get_panel_data() instead")
	return _build_ship_data()

func _calculate_completion_level() -> float:
	## Calculate completion level percentage
	if ship_data.is_empty():
		return 0.0
	
	var completion_factors = 0.0
	var total_factors = 4.0 # Name, type, hull points, configuration
	
	# Factor 1: Valid name
	if ship_data.name.strip_edges().length() >= 2:
		completion_factors += 1.0
	
	# Factor 2: Valid ship type
	if ship_data.has("type") and not ship_data.type.is_empty():
		completion_factors += 1.0
	
	# Factor 3: Valid hull points
	if ship_data.get("hull_points", 0) > 0:
		completion_factors += 1.0
	
	# Factor 4: Has traits and basic configuration
	if ship_data.get("traits", []).size() > 0:
		completion_factors += 1.0
	
	return completion_factors / total_factors

func is_setup_complete() -> bool:
	## Check if ship setup is complete and valid
	return ship_data.is_configured and not ship_data.name.is_empty()

func _update_validation_status() -> void:
	## Update validation status for ship data
	var validation_errors = _validate_ship_data()
	var is_valid = validation_errors.is_empty()
	
	local_ship_data.is_complete = is_valid and not ship_data.name.is_empty()
	last_validation_errors = validation_errors.duplicate()
	
	# Update completion status
	if is_valid:
		pass
	else:
		push_warning("ShipPanel: Validation failed - %s" % ", ".join(validation_errors))

func validate() -> Array[String]:
	## Validate ship data and return error messages
	var validation = validate_panel()
	return validation.errors if validation.errors else []

func set_data(data: Dictionary) -> void:
	## Set panel data - generic interface method
	ship_data = data.duplicate()
	_update_ship_ui()
	ship_updated.emit(ship_data)

func _generate_ship() -> void:
	## Generate ship following Five Parsecs Ship Table from ships.json (Core Rules pp.68-71)
	var ship_roll: int = randi_range(1, 100)
	var gen_table: Array = _ships_db.get("generation_table", [])
	var chosen_type_id: String = ""

	for entry in gen_table:
		if entry is Dictionary:
			var r: Array = entry.get("range", [1, 100])
			if ship_roll >= int(r[0]) and ship_roll <= int(r[1]):
				chosen_type_id = entry.get("type", "")
				break

	if chosen_type_id.is_empty():
		# Fallback: pick random from custom_ship_types
		var custom_types: Array = _ships_db.get("custom_ship_types", ["freelancer"])
		chosen_type_id = custom_types[randi() % custom_types.size()]

	# Find the ship type data and apply it
	_create_ship_from_type_id(chosen_type_id)

	# Set default name if empty
	if ship_data.name.is_empty():
		ship_data.name = _generate_ship_name()

	_update_ship_display()
	ship_updated.emit(ship_data)

	# Validate and emit completion signal after generation
	# Reset guards so the false→true transition fires in _validate_and_complete()
	is_ship_complete = false
	_completion_emitted = false
	_validate_and_complete()

func _create_ship_from_type_id(type_id: String) -> void:
	## Create a ship from its JSON type ID (Core Rules p.31)
	for entry in _ships_db.get("ship_types", []):
		if entry is Dictionary and entry.get("id", "") == type_id:
			ship_data.type = entry.get("name", "Worn Freighter")
			var hull: int = int(entry.get("hull_points", 30))
			ship_data.hull_points = hull
			ship_data.max_hull = hull
			# Core Rules: debt = 1D6 + base
			if entry.has("debt_base"):
				ship_data.debt = int(entry.get("debt_base", 20)) + randi_range(1, 6)
			else:
				var debt_min: int = int(entry.get("debt_min", 20))
				var debt_max: int = int(entry.get("debt_max", 26))
				ship_data.debt = debt_min if debt_min == debt_max else randi_range(debt_min, debt_max)
			# Core Rules: traits from ship table, not random roll
			var ship_traits: Array = entry.get("traits", [])
			ship_data.traits = ship_traits if not ship_traits.is_empty() else _roll_ship_traits()
			return
	# Fallback if type_id not found (Core Rules default: Worn Freighter)
	ship_data.type = "Worn Freighter"
	ship_data.hull_points = 30
	ship_data.max_hull = 30
	ship_data.debt = randi_range(0, 3)
	ship_data.traits = _roll_ship_traits()

func _roll_ship_traits() -> Array[String]:
	## Roll for random ship traits from ships.json
	var traits: Array[String] = []
	var traits_data: Dictionary = _ships_db.get("traits", {})
	var trait_roll: int = randi_range(1, 100)

	# Primary trait based on D100 roll
	var primary_table: Array = traits_data.get("primary", [])
	if primary_table.is_empty():
		# Fallback
		traits.append(["Fast Engine", "Heavy Armor", "Extra Cargo", "Advanced Sensors", "Weapon Hardpoints"][randi() % 5])
	else:
		for entry in primary_table:
			if entry is Dictionary:
				var r: Array = entry.get("range", [1, 100])
				if trait_roll >= int(r[0]) and trait_roll <= int(r[1]):
					traits.append(entry.get("name", "Unknown Trait"))
					break

	# Secondary trait chance
	var secondary_chance: float = traits_data.get("secondary_chance", 0.3)
	if randf() <= secondary_chance:
		var secondary_table: Array = traits_data.get("secondary", [])
		if secondary_table.is_empty():
			secondary_table = [{"name": "Efficient Drive"}, {"name": "Luxury Interior"}, {"name": "Advanced AI"}]
		var second_entry: Dictionary = secondary_table[randi() % secondary_table.size()]
		var second_trait: String = second_entry.get("name", "")
		if not second_trait.is_empty() and not traits.has(second_trait):
			traits.append(second_trait)

	return traits

func set_ship_data(data: Dictionary) -> void:
	## Set ship data and update display
	ship_data = data.duplicate()
	_update_ship_display()

func _update_ship_ui() -> void:
	## Update ship UI components to reflect current ship_data - alias for _update_ship_display
	_update_ship_display()


# --- Additions to ShipPanel.gd ---

func _on_ship_name_changed(new_name: String) -> void:
	ship_data.name = new_name
	_validate_and_complete()
	ship_updated.emit(ship_data)

	# Emit granular signal for real-time integration
	ship_data_changed.emit(_build_ship_data())

func _on_ship_type_changed(index: int) -> void:
	## Handle ship type selection change
	if ship_type_option:
		ship_data.type = ship_type_option.get_item_text(index)
		_validate_and_complete()
		ship_updated.emit(ship_data)
		ship_data_changed.emit(_build_ship_data())

func _on_hull_points_changed(value: float) -> void:
	## Handle hull points spinbox change
	ship_data.hull_points = int(value)
	ship_data.max_hull = int(value)  # Update max hull as well
	_validate_and_complete()
	ship_updated.emit(ship_data)
	ship_data_changed.emit(_build_ship_data())

func _on_debt_changed(value: float) -> void:
	## Handle debt spinbox change
	ship_data.debt = int(value)
	_validate_and_complete()
	ship_updated.emit(ship_data)
	ship_data_changed.emit(_build_ship_data())

func _validate_and_complete() -> void:
	## Enhanced validation with coordinator pattern and security integration
	last_validation_errors = _validate_ship_data()
	
	if not last_validation_errors.is_empty():
		is_ship_complete = false
		local_ship_data.is_complete = false
		ship_validation_failed.emit(last_validation_errors)
	else:
		var was_complete = is_ship_complete
		is_ship_complete = _check_completion_requirements()
		local_ship_data.is_complete = is_ship_complete
		local_ship_data.ship = ship_data
		
		# Emit panel data update for signal-based architecture
		panel_data_changed.emit(local_ship_data)
		
		# Emit granular data change signal for real-time integration
		ship_data_changed.emit(_build_ship_data())
		
		# Emit completion signal when transitioning to complete state
		if is_ship_complete and not was_complete and not _completion_emitted:
			var ship_data_result = _build_ship_data()
			ship_data_complete.emit(ship_data_result)
			ship_configuration_complete.emit(ship_data_result) # Granular completion signal - FIXED: was using undefined ship_data
			panel_completed.emit(ship_data_result) # Maintain backward compatibility
			_completion_emitted = true  # Prevent duplicate emissions
		elif is_ship_complete:
			pass

func _check_completion_requirements() -> bool:
	## Check if all requirements for ship completion are met
	# Required: Ship must have a valid name
	if ship_data.name.strip_edges().length() < 2:
		return false
	
	# Validate name using basic validation
	if ship_data.name.strip_edges().length() < 2:
		return false
	
	# Required: Ship must have basic configuration
	if not ship_data.has("type") or ship_data.type.is_empty():
		return false
	
	# Required: Ship must have hull points
	if ship_data.get("hull_points", 0) <= 0:
		return false
	
	return true

func cleanup_panel() -> void:
	## Clean up panel state when navigating away
	
	# Clear ship manager instance
	if ship_manager_instance:
		if ship_manager_instance.has_method("cleanup"):
			ship_manager_instance.cleanup()
		ship_manager_instance.queue_free()
		ship_manager_instance = null
	
	# Clear ship container
	if ship_container:
		ship_container.queue_free()
		ship_container = null
	
	# Reset local ship data
	local_ship_data = {
		"name": "",
		"type": "",
		"hull_points": 0,
		"max_hull": 0,
		"debt": 0,
		"is_complete": false
	}
	
	# Clear ship data
	ship_data.clear()
	available_ships.clear()
	

func _validate_ship_data() -> Array[String]:
	## Performs validation on the ship data
	var errors: Array[String] = []
	
	# Rule: Must have a name
	if ship_data.name.strip_edges().is_empty():
		errors.append("Ship name is required.")
	elif ship_data.name.strip_edges().length() < 2:
		errors.append("Ship name must be at least 2 characters long.")
	
	# Rule: Must have a valid ship type
	if not ship_data.has("type") or ship_data.type.is_empty():
		errors.append("Ship type must be selected.")
	
	# Rule: Must have valid hull points
	if ship_data.get("hull_points", 0) <= 0:
		errors.append("Ship must have valid hull points.")
	
	# Rule: Must have reasonable debt amount
	if ship_data.get("debt", 0) < 0:
		errors.append("Ship debt cannot be negative.")
	
	return errors

func get_data() -> Dictionary:
	## DEPRECATED: Use get_panel_data() instead. Will be removed in future version.
	push_warning("ShipPanel.get_data() is deprecated - use get_panel_data() instead")
	return get_panel_data()

## Required Interface Methods from ICampaignCreationPanel

func validate_panel() -> bool:
	## Validate panel data and return simple boolean result
	var errors = _validate_ship_data()
	return errors.is_empty()

func get_panel_data() -> Dictionary:
	## Get panel data - interface implementation
	return _build_ship_data()

func set_panel_data(data: Dictionary) -> void:
	## Set panel data - interface implementation for state restoration
	if data.is_empty():
		return

	# Handle both direct ship data and nested ship data
	if data.has("ship") and data["ship"] is Dictionary:
		ship_data = data["ship"].duplicate()
	else:
		# Data might be the ship data itself
		ship_data = data.duplicate()

	local_ship_data["ship"] = ship_data
	local_ship_data["is_complete"] = data.get("is_complete", false)
	is_ship_complete = local_ship_data["is_complete"]

	# Update UI with restored data
	call_deferred("_update_ship_display")

	# Emit signals
	ship_updated.emit(ship_data)

func _on_coordinator_set() -> void:
	## Called when coordinator is assigned - sync initial state

	var coordinator = get_coordinator_reference()
	if coordinator and coordinator.has_method("get_unified_campaign_state"):
		var state = coordinator.get_unified_campaign_state()
		if state.has("ship") and state.ship is Dictionary and not state.ship.is_empty():
			ship_data = state.ship.duplicate()
			local_ship_data["ship"] = ship_data
			local_ship_data["is_complete"] = state.ship.get("is_complete", false)
			call_deferred("_update_ship_display")
		else:
			pass
	else:
		pass

func reset_panel() -> void:
	## Reset panel to default state
	ship_data.clear()
	available_ships.clear()
	local_ship_data = {
		"ship": {},
		"is_complete": false
	}
	
	# Reset UI components if available
	if ship_name_input:
		ship_name_input.text = ""
	if ship_type_option:
		ship_type_option.select(-1)
	if hull_points_spinbox:
		hull_points_spinbox.value = 0
	if debt_spinbox:
		debt_spinbox.value = 0
	
	is_ship_complete = false
	last_validation_errors.clear()
	_update_ship_display()

## Panel Data Persistence Implementation

func restore_panel_data(data: Dictionary) -> void:
	## Restore panel data from persistence system
	if data.is_empty():
		return
	
	# Restore ship data
	if data.has("ship") and data["ship"] is Dictionary:
		ship_data = data["ship"].duplicate()
		local_ship_data["ship"] = ship_data
		local_ship_data.is_complete = data.get("is_complete", false)
		is_ship_complete = local_ship_data.is_complete
		
		# Update UI with restored data
		_restore_ui_from_ship_data(ship_data)
		_update_ship_display()
		
		# Emit signals
		ship_updated.emit(ship_data)
	

func _restore_ui_from_ship_data(ship_data: Dictionary) -> void:
	## Restore UI elements from ship data
	if not ship_data:
		return
	
	# Restore ship name
	if ship_name_input and ship_data.has("name"):
		ship_name_input.text = ship_data.name
	
	# Restore ship type selection
	if ship_type_option and ship_data.has("type"):
		_select_ship_type_option(ship_data.type)
	
	# Restore hull points
	if hull_points_spinbox and ship_data.has("hull_points"):
		hull_points_spinbox.value = ship_data.hull_points
	
	# Restore debt
	if debt_spinbox and ship_data.has("debt"):
		debt_spinbox.value = ship_data.debt

func _select_ship_type_option(ship_type: String) -> void:
	## Select ship type in option button by type name
	if not ship_type_option:
		return
	
	for i in range(ship_type_option.get_item_count()):
		if ship_type_option.get_item_text(i) == ship_type:
			ship_type_option.select(i)
			break

## Debug Helper Methods

func _log_panel_initialization_debug() -> void:
	## Debug output for panel initialization (no-op in release)
	pass
	

# ============ DEFENSIVE UI CREATION METHODS ============
# These methods create UI components programmatically when scene structure is missing

func _create_fallback_ui() -> Control:
	## Create minimal UI when scene structure missing
	var container = VBoxContainer.new()
	container.name = "Content"
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_theme_constant_override("separation", SPACING_MD)

	var title = Label.new()
	title.text = "Ship Selection"
	title.add_theme_font_size_override("font_size", FONT_SIZE_XL)
	title.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	container.add_child(title)

	return container

func _create_ship_name_section(parent: Node) -> LineEdit:
	## Create ship name input section
	var container = HBoxContainer.new()
	container.name = "ShipName"
	container.add_theme_constant_override("separation", SPACING_SM)
	parent.add_child(container)

	var label = Label.new()
	label.text = "Ship Name:"
	label.custom_minimum_size.x = 100
	label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	container.add_child(label)

	var input = LineEdit.new()
	input.name = "LineEdit"
	input.placeholder_text = "Enter ship name"
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_line_edit(input)
	container.add_child(input)

	return input

func _create_ship_type_section(parent: Node) -> OptionButton:
	## Create ship type selection section
	var container = HBoxContainer.new()
	container.name = "ShipType"
	container.add_theme_constant_override("separation", SPACING_SM)
	parent.add_child(container)

	var label = Label.new()
	label.text = "Ship Type:"
	label.custom_minimum_size.x = 100
	label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	container.add_child(label)

	var option = OptionButton.new()
	option.name = "Value"
	# Add all Five Parsecs ship types from Ship Table
	option.add_item("Worn Freighter")
	option.add_item("Patrol Boat")
	option.add_item("Converted Transport")
	option.add_item("Scout Ship")
	option.add_item("Armed Trader")
	option.add_item("Light Freighter")
	option.add_item("Modified Corvette")
	option.add_item("Salvage Hauler")
	option.add_item("Deep Space Explorer")
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_option_button(option)
	container.add_child(option)

	return option

func _create_hull_points_section(parent: Node) -> SpinBox:
	## Create hull points section
	var container = HBoxContainer.new()
	container.name = "HullPoints"
	container.add_theme_constant_override("separation", SPACING_SM)
	parent.add_child(container)

	var label = Label.new()
	label.text = "Hull Points:"
	label.custom_minimum_size.x = 100
	label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	container.add_child(label)

	var spinbox = SpinBox.new()
	spinbox.name = "Value"
	spinbox.min_value = 1
	spinbox.max_value = 20
	spinbox.value = 10
	spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spinbox.custom_minimum_size.y = TOUCH_TARGET_MIN
	container.add_child(spinbox)

	return spinbox

func _create_debt_section(parent: Node) -> SpinBox:
	## Create ship debt section
	var container = HBoxContainer.new()
	container.name = "Debt"
	container.add_theme_constant_override("separation", SPACING_SM)
	parent.add_child(container)

	var label = Label.new()
	label.text = "Ship Debt:"
	label.custom_minimum_size.x = 100
	label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	container.add_child(label)

	var spinbox = SpinBox.new()
	spinbox.name = "Value"
	spinbox.min_value = 0
	spinbox.max_value = 10
	spinbox.step = 1
	spinbox.value = 0
	spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spinbox.custom_minimum_size.y = TOUCH_TARGET_MIN
	container.add_child(spinbox)

	return spinbox

func _create_traits_section(parent: Node) -> VBoxContainer:
	## Create ship traits section
	var container = VBoxContainer.new()
	container.name = "Traits"
	container.add_theme_constant_override("separation", SPACING_SM)
	parent.add_child(container)

	var label = Label.new()
	label.text = "Ship Traits:"
	label.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	container.add_child(label)

	var traits_list = VBoxContainer.new()
	traits_list.name = "Container"
	traits_list.add_theme_constant_override("separation", SPACING_XS)
	container.add_child(traits_list)

	return traits_list

func _create_control_buttons(parent: Node) -> void:
	## Create control buttons section
	var container = HBoxContainer.new()
	container.name = "Controls"
	container.add_theme_constant_override("separation", SPACING_SM)
	parent.add_child(container)

	generate_button = Button.new()
	generate_button.name = "GenerateButton"
	generate_button.text = "Generate Ship"
	generate_button.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
	generate_button.pressed.connect(_on_generate_pressed)
	container.add_child(generate_button)

	reroll_button = Button.new()
	reroll_button.name = "RerollButton"
	reroll_button.text = "Reroll Ship"
	reroll_button.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
	reroll_button.pressed.connect(_on_reroll_pressed)
	container.add_child(reroll_button)

	# Sprint 26.6: Select button created but hidden (not yet implemented)
	select_button = Button.new()
	select_button.name = "SelectButton"
	select_button.text = "Select Ship"
	select_button.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
	select_button.visible = false
	select_button.tooltip_text = "Ship presets coming in a future update"
	select_button.pressed.connect(_on_select_pressed)
	container.add_child(select_button)

func _on_select_pressed() -> void:
	## Handle ship selection button press
	# Signal selection made - completion handled by _validate_and_complete()
	var selection_data = {
		"ship_name": "Default Ship", # Safe default
		"ship_type": "Standard Hull", # Safe default
		"ship_configuration": "Basic" # Safe default
	}
	# Removed redundant panel_completed.emit() - completion handled by _validate_and_complete()

## Responsive Layout Overrides

func _apply_mobile_layout() -> void:
	## Mobile: Single column, 56dp targets, compact ship display
	super._apply_mobile_layout()

	# Increase button touch targets to TOUCH_TARGET_COMFORT (56dp)
	if generate_button:
		generate_button.custom_minimum_size.y = TOUCH_TARGET_COMFORT
	if reroll_button:
		reroll_button.custom_minimum_size.y = TOUCH_TARGET_COMFORT
	if select_button:
		select_button.custom_minimum_size.y = TOUCH_TARGET_COMFORT

func _apply_tablet_layout() -> void:
	## Tablet: Two columns, 48dp targets, detailed ship display
	super._apply_tablet_layout()

	# Standard button touch targets at TOUCH_TARGET_MIN (48dp)
	if generate_button:
		generate_button.custom_minimum_size.y = TOUCH_TARGET_MIN
	if reroll_button:
		reroll_button.custom_minimum_size.y = TOUCH_TARGET_MIN
	if select_button:
		select_button.custom_minimum_size.y = TOUCH_TARGET_MIN

func _apply_desktop_layout() -> void:
	## Desktop: Multi-column, 48dp targets, full ship details
	super._apply_desktop_layout()

	# Standard button touch targets at TOUCH_TARGET_MIN (48dp)
	if generate_button:
		generate_button.custom_minimum_size.y = TOUCH_TARGET_MIN
	if reroll_button:
		reroll_button.custom_minimum_size.y = TOUCH_TARGET_MIN
	if select_button:
		select_button.custom_minimum_size.y = TOUCH_TARGET_MIN

# --- End of additions ---
