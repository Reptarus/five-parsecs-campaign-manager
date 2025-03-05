# UIManager.gd
@tool
extends Node
class_name FPCM_UIManager

## Main UI management system for Five Parsecs Campaign Manager
##
## Manages UI screens, dialogs, transitions, and coordinates with the theme system.
## Handles responsive UI adjustments and accessibility features.

## Dependencies - explicit loading to avoid circular references
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const FiveParsecsGameState = preload("res://src/core/state/GameState.gd")
const GameStateManager = preload("res://src/core/managers/GameStateManager.gd")
const ThemeManager = preload("res://src/ui/themes/ThemeManager.gd")

## Signal when screen changes with proper type annotations
signal screen_changed(screen: Control)
## Signal when dialog opens with proper type annotations
signal dialog_opened(dialog: Control)
## Signal when dialog closes with proper type annotations
signal dialog_closed(dialog: Control)
## Signal when UI scale changes
signal ui_scale_changed(scale_factor: float)
## Signal when UI accessibility settings change
signal accessibility_settings_changed(settings: Dictionary)

## Reference to scene resources
@export var main_menu_scene: PackedScene
@export var game_over_scene: PackedScene
@export var hud_scene: PackedScene
@export var settings_dialog_scene: PackedScene

## UI Performance settings
@export_group("Performance Settings")
@export var use_subviewport_container: bool = true
@export var use_gpu_skinning: bool = true
@export var batch_ui_updates: bool = true
@export_range(1, 10, 1) var ui_update_frequency: int = 2
@export var enable_ui_caching: bool = true

## UI state
var screens: Dictionary = {}
var current_screen: Control = null
var game_state: FiveParsecsGameState
var game_manager: GameStateManager
var hud: Control
var active_dialogs: Array[Control] = []
var cached_ui_elements: Dictionary = {}
var _batch_update_timer: Timer
var _last_update_time: int = 0
var _pending_updates: Array[Dictionary] = []

## Theme management
var theme_manager: ThemeManager
var _responsive_ui_elements: Array[Dictionary] = []

## Initialize the UI Manager
## @param _game_state: Reference to the game state
func _init(_game_state: FiveParsecsGameState) -> void:
	game_state = _game_state
	
	# Initialize theme manager
	theme_manager = ThemeManager.new()
	add_child(theme_manager)
	
	# Create batch update timer
	_batch_update_timer = Timer.new()
	_batch_update_timer.wait_time = 1.0 / ui_update_frequency
	_batch_update_timer.one_shot = false
	_batch_update_timer.timeout.connect(_process_batch_updates)
	add_child(_batch_update_timer)
	
	if batch_ui_updates:
		_batch_update_timer.start()

func _ready() -> void:
	# Initialize HUD if scene is provided
	if hud_scene:
		hud = hud_scene.instantiate()
		add_child(hud)
		apply_theme_to_node(hud)
		hud.hide()
	
	# Set up window resize response
	get_tree().root.size_changed.connect(_handle_window_resize)
	
	# Connect to theme manager signals
	theme_manager.theme_changed.connect(_on_theme_changed)
	theme_manager.scale_changed.connect(_on_scale_changed)
	theme_manager.high_contrast_changed.connect(_on_high_contrast_changed)
	theme_manager.reduced_animation_changed.connect(_on_reduced_animation_changed)

## Initialize manager with game state reference
## @param manager: Reference to the game state manager
func initialize(manager: GameStateManager) -> void:
	game_manager = manager
	var state = manager.get_game_state()
	if state is FiveParsecsGameState:
		game_state = state
	else:
		push_error("Invalid game state type received from manager")
	
	# Connect to all relevant signals
	if game_manager:
		game_manager.state_changed.connect(_on_game_state_changed)
		game_manager.campaign_phase_changed.connect(_on_campaign_phase_changed)
		game_manager.battle_phase_changed.connect(_on_battle_phase_changed)
		game_manager.game_started.connect(_on_game_started)
		game_manager.game_ended.connect(_on_game_ended)
		game_manager.campaign_victory_achieved.connect(_on_campaign_victory_achieved)
		
		# Show HUD if game is already active
		if game_manager.is_game_active():
			hud.show()

## Register a screen for navigation
## @param screen_name: Identifier for the screen
## @param screen: Control node reference
func register_screen(screen_name: String, screen: Control) -> void:
	if screen == null:
		push_error("Attempting to register null screen: " + screen_name)
		return
		
	screens[screen_name] = screen
	apply_theme_to_node(screen)
	
	if screen.is_inside_tree():
		screen.hide()
	else:
		await screen.ready
		screen.hide()

## Change to a different screen
## @param screen_name: Identifier for the screen to display
func change_screen(screen_name: String) -> void:
	if not screen_name in screens:
		push_error("Screen not found: " + screen_name)
		return
		
	if current_screen != null and is_instance_valid(current_screen):
		if use_subviewport_container:
			# Use animation to fade out
			var tween = create_tween()
			tween.tween_property(current_screen, "modulate", Color(1, 1, 1, 0), 0.3)
			await tween.finished
		current_screen.hide()
		
	current_screen = screens[screen_name]
	if current_screen != null and is_instance_valid(current_screen):
		apply_theme_to_node(current_screen)
		current_screen.show()
		
		if use_subviewport_container:
			# Use animation to fade in
			current_screen.modulate = Color(1, 1, 1, 0)
			var tween = create_tween()
			tween.tween_property(current_screen, "modulate", Color(1, 1, 1, 1), 0.3)
		
		screen_changed.emit(current_screen)

## Open a dialog on top of the current screen
## @param dialog: Dialog to display
## @param modal: Whether dialog blocks underlying UI
func open_dialog(dialog: Control, modal: bool = true) -> void:
	if dialog == null:
		push_error("Attempting to open null dialog")
		return
	
	apply_theme_to_node(dialog)
	
	if dialog not in active_dialogs:
		active_dialogs.append(dialog)
		
	if modal:
		dialog.popup_centered()
	else:
		dialog.show()
		
	dialog_opened.emit(dialog)

## Close a currently open dialog
## @param dialog: Dialog to close
func close_dialog(dialog: Control) -> void:
	if dialog == null:
		return
		
	dialog.hide()
	var index = active_dialogs.find(dialog)
	if index >= 0:
		active_dialogs.remove_at(index)
		
	dialog_closed.emit(dialog)

## Close all open dialogs
func close_all_dialogs() -> void:
	for dialog in active_dialogs.duplicate():
		close_dialog(dialog)

## Apply theme to a node and all its children
## @param node: Target node
func apply_theme_to_node(node: Control) -> void:
	if node is Control:
		node.theme = theme_manager.get_current_theme()
		
		# Register for responsive design if tagged
		if node.has_meta("responsive_ui"):
			register_responsive_element(node)
	
	for child in node.get_children():
		if child is Control:
			apply_theme_to_node(child)

## Register an element for responsive UI adjustments
## @param element: UI element to adjust responsively
## @param properties: Properties to adjust
func register_responsive_element(element: Control, properties: Dictionary = {}) -> void:
	var responsive_data = {
		"element": element,
		"properties": properties,
		"original_size": element.size,
		"original_position": element.position,
		"original_font_size": {}
	}
	
	# Store original font sizes if applicable
	if element is Label or element is Button or element is LineEdit:
		var font = element.get("theme_override_fonts/font")
		if font:
			responsive_data.original_font_size["font"] = font.get_size()
	
	# Add to responsive elements list
	_responsive_ui_elements.append(responsive_data)

## Update batch update frequency
## @param frequency: New update frequency
func set_ui_update_frequency(frequency: int) -> void:
	ui_update_frequency = frequency
	_batch_update_timer.wait_time = 1.0 / ui_update_frequency

## Enable or disable batch updates
## @param enabled: Whether to enable batch updates
func set_batch_updates(enabled: bool) -> void:
	batch_ui_updates = enabled
	if enabled:
		_batch_update_timer.start()
	else:
		_batch_update_timer.stop()
		# Process any pending updates
		_process_batch_updates()

## Queue a UI update for batch processing
## @param node: Target node
## @param property: Property to update
## @param value: New value
func queue_ui_update(node: Node, property: String, value: Variant) -> void:
	if not batch_ui_updates:
		# Apply immediately if batching is disabled
		node.set(property, value)
		return
	
	_pending_updates.append({
		"node": node,
		"property": property,
		"value": value,
		"timestamp": Time.get_unix_time_from_system()
	})

## Process batched UI updates
func _process_batch_updates() -> void:
	var current_time = Time.get_unix_time_from_system()
	if _pending_updates.is_empty() or current_time - _last_update_time < 0.016: # About 60 FPS
		return
	
	# Apply updates
	for update in _pending_updates:
		var node = update.node
		if is_instance_valid(node):
			node.set(update.property, update.value)
	
	_pending_updates.clear()
	_last_update_time = current_time

## Cache a commonly used UI element
## @param key: Cache key for the element
## @param element: UI element to cache
func cache_ui_element(key: String, element: Control) -> void:
	if not enable_ui_caching:
		return
		
	cached_ui_elements[key] = element
	element.hide() # Hide by default
	
	# Ensure it's properly themed
	apply_theme_to_node(element)

## Get a cached UI element
## @param key: Cache key for the element
## @return: The cached element or null if not found
func get_cached_ui_element(key: String) -> Control:
	if not enable_ui_caching or not cached_ui_elements.has(key):
		return null
		
	return cached_ui_elements[key]

## Clear the UI cache
## @param key: Optional specific key to clear, or empty to clear all
func clear_ui_cache(key: String = "") -> void:
	if key.is_empty():
		cached_ui_elements.clear()
	elif cached_ui_elements.has(key):
		cached_ui_elements.erase(key)

## Handle window resize for responsive UI
func _handle_window_resize() -> void:
	var viewport_size = get_viewport().get_visible_rect().size
	
	# Adjust responsive elements based on screen size
	for element_data in _responsive_ui_elements:
		var element = element_data.element
		if not is_instance_valid(element):
			continue
			
		var scale_factor = min(
			viewport_size.x / 1920.0, # Base resolution width
			viewport_size.y / 1080.0 # Base resolution height
		)
		
		# Apply scaling to position and size
		if element_data.has("original_size"):
			element.size = element_data.original_size * scale_factor
		
		if element_data.has("original_position"):
			element.position = element_data.original_position * scale_factor
		
		# Scale fonts if applicable
		if element is Label or element is Button or element is LineEdit:
			var font = element.get("theme_override_fonts/font")
			if font and element_data.original_font_size.has("font"):
				font.set_size(element_data.original_font_size.font * scale_factor)

## Handle game state events
func _on_game_started() -> void:
	hud.show()
	if game_manager.is_tutorial:
		change_screen("tutorial")
	else:
		change_screen("setup")

func _on_game_ended() -> void:
	hud.hide()
	hide_all_screens()
	change_screen("main_menu")

func _on_game_state_changed(new_state: int) -> void:
	match new_state:
		GameEnums.GameState.SETUP:
			change_screen("setup")
		GameEnums.GameState.CAMPAIGN:
			change_screen("campaign")
		GameEnums.GameState.BATTLE:
			change_screen("battle")
		GameEnums.GameState.GAME_OVER:
			show_game_over_screen(game_state.victory_achieved)

func _on_campaign_phase_changed(new_phase: GameEnums.CampaignPhase) -> void:
	update_campaign_phase_display(new_phase)
	if current_screen and current_screen.has_method("on_campaign_phase_changed"):
		current_screen.on_campaign_phase_changed(new_phase)

func _on_battle_phase_changed(new_phase: int) -> void:
	update_battle_phase_display(new_phase)
	if current_screen and current_screen.has_method("on_battle_phase_changed"):
		current_screen.on_battle_phase_changed(new_phase)

func _on_campaign_victory_achieved(victory_type: int) -> void:
	var victory_message := ""
	match victory_type:
		GameEnums.FiveParcsecsCampaignVictoryType.WEALTH_GOAL:
			victory_message = "You've amassed great wealth!"
		GameEnums.FiveParcsecsCampaignVictoryType.REPUTATION_GOAL:
			victory_message = "Your reputation precedes you!"
		GameEnums.FiveParcsecsCampaignVictoryType.FACTION_DOMINANCE:
			victory_message = "You've become a dominant force!"
		GameEnums.FiveParcsecsCampaignVictoryType.STORY_COMPLETE:
			victory_message = "You've completed your epic journey!"
	
	show_game_over_screen(true, victory_message)

## Handle theme events
func _on_theme_changed(theme_name: String) -> void:
	for screen in screens.values():
		if is_instance_valid(screen):
			apply_theme_to_node(screen)
	
	if is_instance_valid(hud):
		apply_theme_to_node(hud)
	
	for dialog in active_dialogs:
		if is_instance_valid(dialog):
			apply_theme_to_node(dialog)

func _on_scale_changed(scale_factor: float) -> void:
	ui_scale_changed.emit(scale_factor)
	# Apply scaling to all screens and dialogs
	_on_theme_changed("") # Reapply theme which handles scaling

func _on_high_contrast_changed(enabled: bool) -> void:
	var settings = {
		"high_contrast": enabled,
		"reduced_animation": theme_manager.is_reduced_animation_enabled()
	}
	accessibility_settings_changed.emit(settings)

func _on_reduced_animation_changed(enabled: bool) -> void:
	use_subviewport_container = !enabled
	var settings = {
		"high_contrast": theme_manager.is_high_contrast_enabled(),
		"reduced_animation": enabled
	}
	accessibility_settings_changed.emit(settings)

## UI Display functions
func update_campaign_phase_display(phase: GameEnums.CampaignPhase) -> void:
	if has_node("HUD/PhaseLabel"):
		queue_ui_update($HUD/PhaseLabel, "text", "Phase: " + str(GameEnums.CampaignPhase.keys()[phase]))

func update_battle_phase_display(phase: GameEnums.BattlePhase) -> void:
	if has_node("HUD/BattlePhaseLabel"):
		queue_ui_update($HUD/BattlePhaseLabel, "text", "Battle Phase: " + str(GameEnums.BattlePhase.keys()[phase]))

func show_game_over_screen(victory: bool, message: String = "") -> void:
	if has_node("GameOverScreen"):
		queue_ui_update($GameOverScreen/TitleLabel, "text", "Victory!" if victory else "Game Over")
		queue_ui_update($GameOverScreen/MessageLabel, "text", message if message else \
			"Congratulations! You have achieved victory." if victory else \
			"Your campaign has come to an end.")
		$GameOverScreen.show()

func hide_all_screens() -> void:
	for screen in screens.values():
		if is_instance_valid(screen):
			screen.hide()

func hide_game_over_screen() -> void:
	if has_node("GameOverScreen"):
		$GameOverScreen.hide()

func update_tutorial_display(text: String) -> void:
	if has_node("TutorialDisplay"):
		queue_ui_update($TutorialDisplay, "text", text)
		$TutorialDisplay.show()

func hide_tutorial_display() -> void:
	if has_node("TutorialDisplay"):
		$TutorialDisplay.hide()

## Show settings dialog
func show_settings() -> void:
	if settings_dialog_scene:
		var settings_dialog = settings_dialog_scene.instantiate()
		add_child(settings_dialog)
		
		# Connect settings to theme manager
		if settings_dialog.has_method("connect_theme_manager"):
			settings_dialog.connect_theme_manager(theme_manager)
		
		open_dialog(settings_dialog, true)
	else:
		push_error("Settings dialog scene not set")
     