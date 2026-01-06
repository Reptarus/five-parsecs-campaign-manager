# Crew Management Screen - Post-Campaign Crew Roster Management
# Allows viewing and managing crew members after campaign creation
class_name CrewManagementScreen
extends Control

# ============ CONSTANTS (Design System) ============
const SPACING_MD := 16
const SPACING_LG := 24
const COLOR_WARNING := Color("#D97706")

# Responsive breakpoints (mobile-first)
const BREAKPOINT_MOBILE := 480   # < 480px: 1 column
const BREAKPOINT_TABLET := 1024  # 480-1024px: 2 columns
# >= 1024px: 3 columns

const MAX_CREW_SIZE := 8  # Campaign maximum

# ============ PRELOADS ============
const CharacterCardScene := preload("res://src/ui/components/character/CharacterCard.tscn")

# ============ NODE REFERENCES ============
@onready var crew_grid: GridContainer = %CrewGrid
@onready var crew_count_label: Label = %CrewCountLabel
@onready var add_button: Button = %AddButton
@onready var save_button: Button = %SaveButton
@onready var back_button: Button = %BackButton

# Autoload reference (helps static analyzer)
@onready var _responsive_manager: Node = get_node("/root/ResponsiveManager")

# ============ STATE ============
var current_campaign = null
var character_cards: Array[CharacterCard] = []  # Typed array for performance
var current_columns: int = 1  # Track current grid columns

func _ready() -> void:
	print("CrewManagementScreen: Initializing...")

	# Setup responsive grid
	_setup_responsive_grid()

	# Connect signals
	if add_button:
		add_button.pressed.connect(_on_add_member_pressed)
	if save_button:
		save_button.pressed.connect(_on_save_pressed)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	
	# Connect to ResponsiveManager for centralized breakpoint management
	_responsive_manager.breakpoint_changed.connect(_on_responsive_breakpoint_changed)
	# Initialize with current breakpoint
	_update_grid_columns_from_responsive_manager()

	# Connect viewport resize for responsive updates (legacy support)
	get_viewport().size_changed.connect(_on_viewport_resized)

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
	_clear_crew_grid()

	# Get crew members
	if "crew_members" in current_campaign and current_campaign.crew_members:
		var crew_members = current_campaign.crew_members
		print("CrewManagementScreen: Found %d crew members" % crew_members.size())

		for character in crew_members:
			_create_character_card(character)
	else:
		print("CrewManagementScreen: No crew members found")

	# Update crew count display
	_update_crew_count()

# ============ RESPONSIVE GRID SYSTEM ============
func _setup_responsive_grid() -> void:
	"""Initialize responsive grid with mobile-first defaults"""
	if not crew_grid:
		return
	
	crew_grid.columns = 1  # Start mobile
	crew_grid.add_theme_constant_override("h_separation", SPACING_MD)
	crew_grid.add_theme_constant_override("v_separation", SPACING_MD)
	
	# Calculate initial column count
	_update_grid_columns()

func _on_viewport_resized() -> void:
	"""Handle viewport resize for responsive layout (legacy support)"""
	_update_grid_columns()

func _on_responsive_breakpoint_changed(new_breakpoint: int) -> void:
	"""Handle ResponsiveManager breakpoint changes"""
	_update_grid_columns_from_responsive_manager()
	print("CrewManagementScreen: Layout updated via ResponsiveManager - Breakpoint: %s, Columns: %d" % [
		_responsive_manager.get_breakpoint_name(),
		current_columns
	])

func _update_grid_columns_from_responsive_manager() -> void:
	"""Update grid columns using ResponsiveManager's optimal column count"""
	if not crew_grid or not _responsive_manager:
		return

	var new_columns: int = _responsive_manager.get_crew_grid_columns()

	# Update spacing based on responsive multiplier
	var spacing: int = _responsive_manager.get_responsive_spacing(SPACING_MD)
	crew_grid.add_theme_constant_override("h_separation", spacing)
	crew_grid.add_theme_constant_override("v_separation", spacing)

	# Only update if changed (prevent unnecessary layout recalculation)
	if new_columns != current_columns:
		crew_grid.columns = new_columns
		current_columns = new_columns
		print("CrewManagementScreen: Grid columns updated to %d via ResponsiveManager" % new_columns)

func _update_grid_columns() -> void:
	"""Calculate and update grid columns based on viewport width (legacy method)"""
	if not crew_grid:
		return
	
	var viewport_width := get_viewport_rect().size.x
	var new_columns := _calculate_column_count(viewport_width)
	
	# Only update if changed (prevent unnecessary layout recalculation)
	if new_columns != current_columns:
		crew_grid.columns = new_columns
		current_columns = new_columns
		print("CrewManagementScreen: Grid columns updated to %d (viewport: %dpx)" % [new_columns, viewport_width])

func _calculate_column_count(viewport_width: float) -> int:
	"""Calculate optimal column count based on viewport width (legacy method)"""
	if viewport_width < BREAKPOINT_MOBILE:
		return 1  # Mobile: single column
	elif viewport_width < BREAKPOINT_TABLET:
		return 2  # Tablet: two columns
	else:
		return 3  # Desktop: three columns

# ============ CHARACTER CARD MANAGEMENT ============
func _clear_crew_grid() -> void:
	"""Remove all character cards from grid"""
	if not crew_grid:
		return

	for card in character_cards:
		if is_instance_valid(card):
			card.queue_free()
	
	character_cards.clear()

func _create_character_card(character: Character) -> void:
	"""Create and configure CharacterCard STANDARD variant"""
	if not crew_grid:
		return
	
	# Instantiate CharacterCard
	var card: CharacterCard = CharacterCardScene.instantiate()
	crew_grid.add_child(card)
	
	# Configure card variant
	card.set_variant(CharacterCard.CardVariant.STANDARD)
	
	# Bind character data (call down)
	card.set_character(character)
	
	# Connect signals (signal up)
	card.view_details_pressed.connect(_on_card_view_details.bind(character))
	card.edit_pressed.connect(_on_card_edit.bind(character))
	card.remove_pressed.connect(_on_card_remove.bind(character))
	card.card_tapped.connect(_on_card_tapped.bind(character))
	
	# Track card
	character_cards.append(card)

func _update_crew_count() -> void:
	"""Update crew count label with current/max display"""
	if not crew_count_label:
		return

	var crew_size := character_cards.size()
	crew_count_label.text = "Crew: %d/%d" % [crew_size, MAX_CREW_SIZE]
	
	# Warning color if at max capacity
	if crew_size >= MAX_CREW_SIZE:
		crew_count_label.add_theme_color_override("font_color", COLOR_WARNING)
	else:
		crew_count_label.remove_theme_color_override("font_color")

# ============ CHARACTER CARD SIGNAL HANDLERS ============
func _on_card_view_details(character: Character) -> void:
	"""Handle CharacterCard view_details_pressed signal"""
	print("CrewManagementScreen: View details - %s" % character.get_display_name())

	# Store character reference for CharacterDetailsScreen
	if GameStateManager:
		GameStateManager.set_temp_data(GameStateManager.TEMP_KEY_SELECTED_CHARACTER, character)

	# Navigate to character details screen
	GameStateManager.navigate_to_screen("character_details")

func _on_card_edit(character: Character) -> void:
	"""Handle CharacterCard edit_pressed signal"""
	print("CrewManagementScreen: Edit character - %s" % character.get_display_name())
	
	# TODO: Implement character editor dialog
	push_warning("CrewManagementScreen: Character editing not yet implemented")

func _on_card_remove(character: Character) -> void:
	"""Handle CharacterCard remove_pressed signal with confirmation"""
	var char_name := character.get_display_name()
	print("CrewManagementScreen: Remove character requested - %s" % char_name)

	# Create confirmation dialog
	var dialog := ConfirmationDialog.new()
	dialog.title = "Remove Crew Member"
	dialog.dialog_text = "Remove %s from crew?\nThis cannot be undone." % char_name
	dialog.ok_button_text = "Remove"
	dialog.cancel_button_text = "Cancel"
	add_child(dialog)

	# Connect signals
	dialog.confirmed.connect(func():
		_actually_remove_character(character)
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.popup_centered()

func _on_card_tapped(character: Character) -> void:
	"""Handle CharacterCard card_tapped signal (visual feedback)"""
	# Optional: Add selection/highlight visual feedback
	print("CrewManagementScreen: Card tapped - %s" % character.get_display_name())

func _actually_remove_character(character: Character) -> void:
	"""Actually remove character after confirmation"""
	if not current_campaign or not "crew_members" in current_campaign:
		return
	
	var index: int = current_campaign.crew_members.find(character)
	if index >= 0:
		current_campaign.crew_members.remove_at(index)
		print("CrewManagementScreen: Removed character at index %d" % index)

		# Mark campaign as modified
		if GameStateManager:
			GameStateManager.mark_campaign_modified()

		# Reload crew display
		load_crew_data()

# ============ BUTTON HANDLERS ============
func _on_add_member_pressed() -> void:
	"""Add new crew member"""
	print("CrewManagementScreen: Add member requested")
	
	# Check max crew size
	if character_cards.size() >= MAX_CREW_SIZE:
		push_warning("CrewManagementScreen: Cannot add member - crew at maximum size")
		# TODO: Show user-facing warning dialog
		return

	# Store return context for character creation
	if GameStateManager:
		GameStateManager.set_temp_data(GameStateManager.TEMP_KEY_CREW_ADD_MODE, true)
		GameStateManager.set_temp_data(GameStateManager.TEMP_KEY_RETURN_SCREEN, "crew_management")

	# Navigate to character creation (SimpleCharacterCreator replaces deprecated InitialCrewCreation)
	GameStateManager.navigate_to_scene_path("res://src/ui/screens/character/SimpleCharacterCreator.tscn")

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
