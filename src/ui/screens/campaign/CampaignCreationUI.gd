class_name CampaignCreationUI
extends Control

## Campaign Creation UI Bridge
## Connects existing CampaignCreationUI.tscn scene to refactored architecture
## Routes to CampaignCreationCoordinator and modern panel system

# GlobalEnums available as autoload singleton

# Signals for campaign creation workflow
signal campaign_data_updated(campaign_data: Dictionary)
signal campaign_completion_ready(campaign_data: Dictionary)
signal campaign_creation_completed(campaign_data: Dictionary)

# Import refactored components (using non-conflicting names)
const CampaignCoordinator = preload("res://src/ui/screens/campaign/CampaignCreationCoordinator.gd")
const CampaignStateManager = preload("res://src/core/campaign/creation/CampaignCreationStateManager.gd")
const CampaignPersistence = preload("res://src/core/campaign/creation/CampaignCreationPersistence.gd")
const SecurityValidator = preload("res://src/core/validation/SecurityValidator.gd")
const CampaignFinalizationService = preload("res://src/core/campaign/creation/CampaignFinalizationService.gd")
const CampaignValidator = preload("res://src/core/validation/CampaignValidator.gd")
const FiveParsecsCampaignCore = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")

# PHASE 1: Enhanced Safety Systems (using non-conflicting names)
const FeatureFlags = preload("res://src/core/systems/CampaignCreationFeatureFlags.gd")
const PerformanceTracker = preload("res://src/core/systems/CampaignCreationPerformanceTracker.gd")
const ErrorMonitor = preload("res://src/core/systems/CampaignCreationErrorMonitor.gd")

# PHASE 2: Formal State Machine (using non-conflicting name)
const CampaignStateMachine = preload("res://src/core/systems/CampaignCreationStateMachine.gd")

# Import AutoloadManager for safe scene transitions
const AutoloadManager = preload("res://src/core/systems/AutoloadManager.gd")

# PHASE 3 INTEGRATION: Enhanced UI Components
var header_container: VBoxContainer
var content_area: HSplitContainer
var navigation_footer: HBoxContainer
var status_panel: PanelContainer

# Cached dialog to prevent multiple exclusive window conflicts
var _validation_error_dialog: AcceptDialog = null

# Mapping of validation error messages to their corresponding phases for navigation
const VALIDATION_ERROR_PHASES: Dictionary = {
	"Captain creation is not complete": CampaignStateManager.Phase.CAPTAIN_CREATION,
	"Victory conditions are not set": CampaignStateManager.Phase.CONFIG,
	"Ship assignment is not complete": CampaignStateManager.Phase.SHIP_ASSIGNMENT,
}

# Human-readable panel names for error messages
const PHASE_DISPLAY_NAMES: Dictionary = {
	CampaignStateManager.Phase.CONFIG: "Configuration",
	CampaignStateManager.Phase.CAPTAIN_CREATION: "Captain Creation",
	CampaignStateManager.Phase.CREW_SETUP: "Crew Setup",
	CampaignStateManager.Phase.SHIP_ASSIGNMENT: "Ship Assignment",
	CampaignStateManager.Phase.EQUIPMENT_GENERATION: "Equipment",
	CampaignStateManager.Phase.WORLD_GENERATION: "World Info",
	CampaignStateManager.Phase.FINAL_REVIEW: "Final Review",
}

# Scene node references (from .tscn file)
@onready var responsive_margin: MarginContainer = $ResponsiveMargin
@onready var main_container: VBoxContainer = $ResponsiveMargin/MainContainer
@onready var progress_indicator: ProgressBar = $ResponsiveMargin/MainContainer/HeaderSection/HeaderContainer/ProgressBar
@onready var breadcrumb_container: HBoxContainer = $ResponsiveMargin/MainContainer/HeaderSection/HeaderContainer/BreadcrumbContainer
@onready var step_indicator: Label = $ResponsiveMargin/MainContainer/HeaderSection/HeaderContainer/StepIndicator
@onready var content_container: Control = $ResponsiveMargin/MainContainer/ContentArea/ContentMargin/PanelContainer
@onready var back_button: Button = $ResponsiveMargin/MainContainer/NavigationFooter/NavigationContainer/BackButton
@onready var validation_status_container: HBoxContainer = $ResponsiveMargin/MainContainer/NavigationFooter/NavigationContainer/ValidationStatus
@onready var validation_icon: Label = $ResponsiveMargin/MainContainer/NavigationFooter/NavigationContainer/ValidationStatus/ValidationIcon
@onready var validation_text: Label = $ResponsiveMargin/MainContainer/NavigationFooter/NavigationContainer/ValidationStatus/ValidationText
@onready var next_button: Button = $ResponsiveMargin/MainContainer/NavigationFooter/NavigationContainer/NextButton
@onready var finish_button: Button = $ResponsiveMargin/MainContainer/NavigationFooter/NavigationContainer/FinishButton

# Transition animation properties
var panel_transition_duration: float = 0.15
var is_panel_fading: bool = false

# Refactored architecture components
var coordinator: CampaignCreationCoordinator
var state_manager: CampaignStateManager
var persistence_manager: CampaignPersistence
var security_validator: FiveParsecsSecurityValidator
var finalization_service: CampaignFinalizationService
var current_panel: Control = null

# PHASE 4: Signal optimization and memory safety
var _panel_signal_connections: Array[Dictionary] = []
var _coordinator_panel_connections: Array[Dictionary] = []  # Track coordinator->panel connections separately
var _cleanup_timer: Timer

# PHASE 2: Formal State Machine Integration
var formal_state_machine: CampaignStateMachine
var state_machine_enabled: bool = false

# PHASE 3 INTEGRATION: Responsive Layout Management
var is_responsive_layout_enabled: bool = true
var current_layout_mode: String = "desktop" # desktop, tablet, mobile
var layout_breakpoints: Dictionary = {
	"mobile": 768,
	"tablet": 1024,
	"desktop": 1025
}

# Legacy UI state (kept for backward compatibility during transition)
enum UIState {
	IDLE,
	LOADING_PANEL,
	PANEL_ACTIVE,
	TRANSITIONING,
	ERROR_RECOVERY,
	EMERGENCY_ROLLBACK
}

var ui_state: UIState = UIState.IDLE
var ui_state_lock: Mutex = Mutex.new()
var panel_load_timeout: float = 5.0
var _navigation_update_pending: bool = false

# PHASE 1: Enhanced Safety Systems
var performance_tracker: CampaignCreationPerformanceTracker
var error_monitor: CampaignCreationErrorMonitor
var error_count: int = 0
var max_errors_before_fallback: int = 3
var last_successful_phase: CampaignStateManager.Phase = CampaignStateManager.Phase.CONFIG
var pending_panel_cleanup: Array[Control] = []
var panel_ready_confirmation: bool = false

# GDScript 2.0: Panel Management (7 phases, VICTORY_CONDITIONS removed)
var panel_scenes: Dictionary = {
	CampaignStateManager.Phase.CONFIG: "res://src/ui/screens/campaign/panels/ExpandedConfigPanel.tscn",
	# REMOVED: CampaignStateManager.Phase.VICTORY_CONDITIONS
	CampaignStateManager.Phase.CAPTAIN_CREATION: "res://src/ui/screens/campaign/panels/CaptainPanel.tscn",
	CampaignStateManager.Phase.CREW_SETUP: "res://src/ui/screens/campaign/panels/CrewPanel.tscn",
	CampaignStateManager.Phase.SHIP_ASSIGNMENT: "res://src/ui/screens/campaign/panels/ShipPanel.tscn",
	CampaignStateManager.Phase.EQUIPMENT_GENERATION: "res://src/ui/screens/campaign/panels/EquipmentPanel.tscn",
	CampaignStateManager.Phase.WORLD_GENERATION: "res://src/ui/screens/campaign/panels/WorldInfoPanel.tscn",
	CampaignStateManager.Phase.FINAL_REVIEW: "res://src/ui/screens/campaign/panels/FinalPanel.tscn"
}

# CRITICAL: Panel loading state management to prevent overlap
var _is_panel_loading: bool = false
var _panel_load_queue: Array[CampaignStateManager.Phase] = []
var _transition_start_time: int = 0
const TRANSITION_TIMEOUT_MS: int = 10000  # 10 second timeout for transitions
var _pending_phase_transition: CampaignStateManager.Phase
var _is_transitioning: bool = false

# Enhanced panel caching system
var panel_cache: Dictionary = {}
var preloaded_scenes: Dictionary = {}
var panel_load_queue: Array[CampaignStateManager.Phase] = []
var is_preloading: bool = false
var preload_progress: int = 0

# Navigation update protection and optimization
var _is_updating_navigation: bool = false
var _auto_advance_pending: bool = false

# PHASE 3 INTEGRATION: Enhanced UI Initialization
func _ready() -> void:
	"""Initialize the enhanced campaign creation UI with responsive layout"""
	print("CampaignCreationUI: Initializing enhanced UI with Phase 3 integration")
	
	# Apply responsive margins based on viewport
	_apply_responsive_margins()
	
	# Style progress bar and breadcrumbs
	_style_wizard_header()
	
	# Connect navigation button signals
	_connect_navigation_signals()
	
	# Initialize coordinator and state management
	_initialize_coordinator()
	
	# Setup responsive layout monitoring
	_setup_responsive_layout_monitoring()
	
	# Initialize panel management
	_initialize_panel_management()
	
	# Validate panel paths
	_validate_and_fix_panel_paths()
	
	# Apply comprehensive panel fixes
	_apply_panel_transition_fixes()
	
	# Start with first phase
	_switch_to_phase(CampaignStateManager.Phase.CONFIG)
	
	# Setup debug input handling (Phase 3 feature)
	_setup_debug_input_handling()
	
	# Setup memory safety systems (Phase 4 feature)
	_setup_memory_safety_timer()

func _exit_tree() -> void:
	"""PHASE 4: Cleanup when scene is destroyed"""
	_cleanup_panel_signals()
	if _cleanup_timer:
		_cleanup_timer.queue_free()
	print("CampaignCreationUI: ✅ Scene cleanup completed")

# PHASE 3: Debug Input Handling
func _setup_debug_input_handling() -> void:
	"""Setup debug input handling for state inspection"""
	# Enable input processing for debug keys
	set_process_input(true)
	print("CampaignCreationUI: ✅ Debug input handling enabled (PageDown for state inspection)")

func _input(event: InputEvent) -> void:
	"""Handle debug input events"""
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_PAGEDOWN:
				_show_debug_state_inspection()
				get_viewport().set_input_as_handled()

func _show_debug_state_inspection() -> void:
	"""Show comprehensive debug state information"""
	print("\n🔍 ===== DEBUG STATE INSPECTION =====")
	var current_phase_name = state_manager.get_current_phase() if state_manager else "Unknown"
	print("Current Phase: %s" % current_phase_name)
	print("Panel Container Children: %d" % (content_container.get_child_count() if content_container else 0))
	
	# Show current panel info
	if current_panel:
		print("Current Panel: %s" % current_panel.get_class())
		if current_panel.has_method("get_coordinator"):
			var coordinator_ref = current_panel.get_coordinator()
			print("  Panel Coordinator Access: %s" % (coordinator_ref != null))
		
		if current_panel.has_method("get_panel_data"):
			var panel_data = current_panel.get_panel_data()
			print("  Panel Data Keys: %s" % str(panel_data.keys()))
	else:
		print("Current Panel: None")
	
	# Show coordinator state
	if coordinator:
		print("Coordinator Available: true")
		if coordinator.has_method("get_unified_campaign_state"):
			var campaign_state = coordinator.get_unified_campaign_state()
			print("  Campaign State Keys: %s" % str(campaign_state.keys()))
		else:
			print("  No unified campaign state method")
	else:
		print("Coordinator Available: false")
	
	# Show state manager info
	if state_manager:
		print("State Manager Available: true")
		print("  Current Phase: %s" % state_manager.get_current_phase())
	else:
		print("State Manager Available: false")
	
	print("===== END DEBUG INSPECTION =====\n")

# ============ RESPONSIVE WIZARD LAYOUT HELPERS ============

func _apply_responsive_margins() -> void:
	"""Apply responsive margins to the root container based on viewport width"""
	if not responsive_margin:
		return
	
	var viewport_width = get_viewport().get_visible_rect().size.x
	var margin_size: int
	
	# Mobile: 16px, Tablet: 32px, Desktop: 64px
	if viewport_width < 768:
		margin_size = 16
	elif viewport_width < 1024:
		margin_size = 32
	else:
		margin_size = 64
	
	responsive_margin.add_theme_constant_override("margin_left", margin_size)
	responsive_margin.add_theme_constant_override("margin_right", margin_size)
	responsive_margin.add_theme_constant_override("margin_top", margin_size)
	responsive_margin.add_theme_constant_override("margin_bottom", margin_size)
	
	print("CampaignCreationUI: Applied %dpx responsive margins" % margin_size)

func _style_wizard_header() -> void:
	"""Apply visual styling to progress bar and breadcrumbs"""
	if not progress_indicator:
		return
	
	# Style progress bar
	var progress_bg = StyleBoxFlat.new()
	progress_bg.bg_color = Color("#3A3A5C")  # COLOR_BORDER
	progress_bg.set_corner_radius_all(4)
	progress_indicator.add_theme_stylebox_override("background", progress_bg)
	
	var progress_fill = StyleBoxFlat.new()
	progress_fill.bg_color = Color("#2D5A7B")  # COLOR_ACCENT
	progress_fill.set_corner_radius_all(4)
	progress_indicator.add_theme_stylebox_override("fill", progress_fill)
	
	# Style breadcrumbs (Step1-Step7)
	if breadcrumb_container:
		for i in range(7):
			var step_node = breadcrumb_container.get_node_or_null("Step%d" % (i + 1))
			if step_node:
				# First step active by default
				if i == 0:
					step_node.add_theme_color_override("font_color", Color("#2D5A7B"))
				else:
					step_node.add_theme_color_override("font_color", Color("#808080"))
	
	print("CampaignCreationUI: Wizard header styled")

func _connect_navigation_signals() -> void:
	"""Connect navigation button press signals"""
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	if next_button:
		next_button.pressed.connect(_on_next_pressed)
	if finish_button:
		finish_button.pressed.connect(_on_finish_pressed)
	
	print("CampaignCreationUI: Navigation signals connected")

func update_progress_indicator(step: int, panel_title: String) -> void:
	"""Update the visual progress indicator with current step"""
	if not progress_indicator or not step_indicator:
		return
	
	# Update progress bar
	progress_indicator.value = step
	
	# Update breadcrumbs
	if breadcrumb_container:
		for i in range(7):
			var dot = breadcrumb_container.get_node_or_null("Step%d" % (i + 1))
			if dot:
				if i < step - 1:
					# Completed steps: accent color
					dot.add_theme_color_override("font_color", Color("#2D5A7B"))
				elif i == step - 1:
					# Current step: focus color
					dot.add_theme_color_override("font_color", Color("#4FC3F7"))
				else:
					# Future steps: secondary color
					dot.add_theme_color_override("font_color", Color("#808080"))
	
	# Update step label
	step_indicator.text = "Step %d of 7 • %s" % [step, panel_title]
	
	print("CampaignCreationUI: Progress updated - Step %d: %s" % [step, panel_title])

# PHASE 3 INTEGRATION: Responsive Layout Management
func _setup_responsive_layout_monitoring() -> void:
	"""Setup monitoring for responsive layout changes"""
	if not is_responsive_layout_enabled:
		return
	
	# Connect to viewport size changes
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	
	# Initial layout check
	call_deferred("_check_and_apply_responsive_layout")

func _on_viewport_size_changed() -> void:
	"""Handle viewport size changes for responsive layout"""
	if not is_responsive_layout_enabled:
		return
	
	_check_and_apply_responsive_layout()
	_apply_responsive_margins()

func _check_and_apply_responsive_layout() -> void:
	"""Check current viewport size and apply appropriate layout"""
	var viewport_size = get_viewport().get_visible_rect().size
	var width = viewport_size.x
	
	# Determine layout mode
	var new_layout_mode = "desktop"
	if width <= layout_breakpoints.mobile:
		new_layout_mode = "mobile"
	elif width <= layout_breakpoints.tablet:
		new_layout_mode = "tablet"
	
	# Apply layout if changed
	if new_layout_mode != current_layout_mode:
		_apply_responsive_layout(new_layout_mode)

func _apply_responsive_layout(layout_mode: String) -> void:
	"""Apply responsive layout based on mode"""
	print("CampaignCreationUI: Applying responsive layout: %s" % layout_mode)
	
	current_layout_mode = layout_mode
	
	match layout_mode:
		"mobile":
			_apply_mobile_layout()
		"tablet":
			_apply_tablet_layout()
		"desktop":
			_apply_desktop_layout()

func _apply_mobile_layout() -> void:
	"""Apply mobile-specific layout"""
	# Adjust button sizes
	if back_button:
		back_button.custom_minimum_size = Vector2(80, 48)
	if next_button:
		next_button.custom_minimum_size = Vector2(80, 48)
	if finish_button:
		finish_button.custom_minimum_size = Vector2(80, 48)
	
	# Adjust header font size
	if step_indicator:
		step_indicator.add_theme_font_size_override("font_size", 14)
	
	print("CampaignCreationUI: Mobile layout applied (touch targets: 48dp)")

func _apply_tablet_layout() -> void:
	"""Apply tablet-specific layout"""
	# Standard button sizes
	if back_button:
		back_button.custom_minimum_size = Vector2(100, 48)
	if next_button:
		next_button.custom_minimum_size = Vector2(100, 48)
	if finish_button:
		finish_button.custom_minimum_size = Vector2(100, 48)
	
	# Standard header font
	if step_indicator:
		step_indicator.add_theme_font_size_override("font_size", 16)
	
	print("CampaignCreationUI: Tablet layout applied")

func _apply_desktop_layout() -> void:
	"""Apply desktop-specific layout"""
	# Standard button sizes
	if back_button:
		back_button.custom_minimum_size = Vector2(100, 48)
	if next_button:
		next_button.custom_minimum_size = Vector2(100, 48)
	if finish_button:
		finish_button.custom_minimum_size = Vector2(100, 48)
	
	# Standard header font
	if step_indicator:
		step_indicator.add_theme_font_size_override("font_size", 18)
	
	print("CampaignCreationUI: Desktop layout applied")

# PHASE 3 INTEGRATION: Enhanced Panel Switching with Fade Transitions
func _switch_to_phase(phase: CampaignStateManager.Phase) -> void:
	"""Enhanced panel switching with smooth fade transitions"""
	print("CampaignCreationUI: Switching to phase: %s" % phase)

	# Check for stuck transition state and recover if needed
	if _is_transitioning:
		var current_time = Time.get_ticks_msec()
		if _transition_start_time > 0 and (current_time - _transition_start_time) > TRANSITION_TIMEOUT_MS:
			push_warning("CampaignCreationUI: Transition timeout detected, recovering from stuck state")
			_is_transitioning = false
			is_panel_fading = false
			_transition_start_time = 0

	if _is_transitioning or is_panel_fading:
		print("CampaignCreationUI: Already transitioning, queuing phase switch")
		_panel_load_queue.append(phase)
		return

	_is_transitioning = true
	_transition_start_time = Time.get_ticks_msec()

	# Update progress indicator
	_update_progress_for_phase(phase)

	# Fade out current panel, then load new panel
	if current_panel and is_instance_valid(current_panel):
		await _fade_out_panel(current_panel)
		# Safety check after await
		if not is_inside_tree():
			_is_transitioning = false
			return

	# Load and display panel
	await _load_and_display_panel(phase)
	# Safety check after await
	if not is_inside_tree():
		_is_transitioning = false
		return

	# Fade in new panel
	if current_panel and is_instance_valid(current_panel):
		await _fade_in_panel(current_panel)
		# Safety check after await
		if not is_inside_tree():
			_is_transitioning = false
			return

	# Update navigation state
	_update_navigation_state()

	_is_transitioning = false
	_transition_start_time = 0

func _load_and_display_panel(phase: CampaignStateManager.Phase) -> void:
	"""Load and display panel with enhanced error handling and fallback"""
	var scene_path = panel_scenes.get(phase, "")
	if scene_path.is_empty():
		push_error("No scene path for phase: %s" % phase)
		_display_fallback_panel(phase, "No scene path configured for this phase")
		_is_transitioning = false
		return
	
	# Verify resource exists with automatic path correction
	if not ResourceLoader.exists(scene_path):
		push_warning("Panel scene doesn't exist: %s" % scene_path)
		
		# Try to fix panels_backup references automatically
		var corrected_path = scene_path.replace("panels_backup", "panels")
		if corrected_path != scene_path and ResourceLoader.exists(corrected_path):
			push_warning("Auto-corrected path from %s to %s" % [scene_path, corrected_path])
			scene_path = corrected_path
			# Update the panel_scenes dictionary to prevent future issues
			panel_scenes[phase] = corrected_path
		else:
			push_error("Panel scene doesn't exist even after path correction: %s" % scene_path)
			_display_fallback_panel(phase, "Panel scene file not found: " + scene_path)
			_is_transitioning = false
			return
	
	# Clear current panel (await to ensure cleanup completes before loading new panel)
	await _clear_current_panel()

	# Safety check after await
	if not is_inside_tree():
		_is_transitioning = false
		return

	# Load the scene
	print("CampaignCreationUI: Loading panel scene: %s" % scene_path)
	var scene = load(scene_path)
	if not scene:
		push_error("Failed to load panel scene resource: %s" % scene_path)
		_display_fallback_panel(phase, "Failed to load scene resource: " + scene_path)
		_is_transitioning = false
		return
	
	print("CampaignCreationUI: Successfully loaded scene resource: %s" % scene_path)
	
	# Instance and add new panel
	var panel_instance = scene.instantiate()
	if not panel_instance:
		push_error("Failed to instantiate panel: %s" % scene_path)
		_display_fallback_panel(phase, "Failed to instantiate panel object")
		_is_transitioning = false
		return
	
	# Validate panel instance
	if not (panel_instance is Control):
		push_error("Panel instance is not a Control node: %s" % scene_path)
		panel_instance.queue_free()
		_display_fallback_panel(phase, "Invalid panel type - not a Control node")
		_is_transitioning = false
		return
	
	print("CampaignCreationUI: Successfully instantiated panel: %s" % panel_instance.get_class())
	
	content_container.add_child(panel_instance)
	current_panel = panel_instance

	# CRITICAL: Ensure panel fills the content container properly
	# Set anchors to fill parent (PRESET_FULL_RECT)
	panel_instance.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Godot 4.x: Set offsets individually (set_offsets_all doesn't exist)
	panel_instance.offset_left = 0
	panel_instance.offset_top = 0
	panel_instance.offset_right = 0
	panel_instance.offset_bottom = 0
	panel_instance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_instance.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# ENHANCED: Use robust panel setup with proper coordinator integration
	await _setup_panel_references(panel_instance, phase)
	
	# Initialize panel with state data
	if panel_instance.has_method("set_panel_data"):
		var phase_data = state_manager.get_phase_data(phase)
		if phase_data and not phase_data.is_empty():
			panel_instance.set_panel_data(phase_data)
	elif panel_instance.has_method("initialize"):
		panel_instance.initialize()
	else:
		push_warning("Panel has no initialization method: %s" % scene_path)

	# NOTE: Signal connection removed here - already done in _setup_panel_references()
	# which handles coordinator integration properly (Sprint 26.20)

	_is_transitioning = false
	print("Panel loaded successfully: %s" % scene_path)

# ============ PANEL TRANSITION ANIMATIONS ============

func _fade_out_panel(panel: Control) -> void:
	"""Smoothly fade out a panel over panel_transition_duration seconds"""
	if not panel or not is_instance_valid(panel):
		return

	if not is_inside_tree():
		return

	is_panel_fading = true
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(panel, "modulate:a", 0.0, panel_transition_duration)
	await tween.finished
	is_panel_fading = false

func _fade_in_panel(panel: Control) -> void:
	"""Smoothly fade in a panel over panel_transition_duration seconds"""
	if not panel or not is_instance_valid(panel):
		return

	if not is_inside_tree():
		return

	# Start invisible
	panel.modulate.a = 0.0

	is_panel_fading = true
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(panel, "modulate:a", 1.0, panel_transition_duration)
	await tween.finished
	is_panel_fading = false

func _clear_current_panel() -> void:
	"""Clear the current panel safely with enhanced cleanup and race condition prevention"""
	print("CampaignCreationUI: Clearing current panel")
	
	if current_panel and is_instance_valid(current_panel):
		# Disconnect all signals first
		_disconnect_panel_signals(current_panel)
		
		# Call cleanup method if available
		if current_panel.has_method("cleanup_panel"):
			current_panel.cleanup_panel()
		
		# Remove from parent BEFORE queue_free to prevent stacking
		if current_panel.get_parent():
			current_panel.get_parent().remove_child(current_panel)

		# Queue for deletion
		current_panel.queue_free()
		current_panel = null

		# CRITICAL: Wait one frame to ensure cleanup completes (with null safety)
		if not is_inside_tree():
			print("CampaignCreationUI: Panel cleared (no frame delay - not in tree)")
			return
		await get_tree().process_frame

		# Safety check after await
		if not is_inside_tree():
			return

		print("CampaignCreationUI: Panel cleared successfully with frame delay")
	else:
		print("CampaignCreationUI: No current panel to clear")

func _create_fallback_panel(phase: CampaignStateManager.Phase, error_message: String) -> Control:
	"""Create a fallback panel when panel loading fails"""
	print("CampaignCreationUI: Creating fallback panel for phase: %s" % phase)
	
	var fallback_panel = Control.new()
	fallback_panel.name = "FallbackPanel"
	fallback_panel.layout_mode = 2
	fallback_panel.size_flags_horizontal = 3 # SIZE_EXPAND_FILL
	fallback_panel.size_flags_vertical = 3 # SIZE_EXPAND_FILL
	
	# Create content container
	var content_margin = MarginContainer.new()
	content_margin.layout_mode = 3 # LAYOUT_MODE_ANCHORS
	content_margin.anchors_preset = 15 # ANCHOR_FULL_RECT
	content_margin.add_theme_constant_override("margin_left", 40)
	content_margin.add_theme_constant_override("margin_top", 40)
	content_margin.add_theme_constant_override("margin_right", 40)
	content_margin.add_theme_constant_override("margin_bottom", 40)
	fallback_panel.add_child(content_margin)
	
	var main_container = VBoxContainer.new()
	main_container.layout_mode = 2
	main_container.alignment = BoxContainer.ALIGNMENT_CENTER
	content_margin.add_child(main_container)
	
	# Error icon and title
	var error_label = Label.new()
	error_label.text = "⚠️ Panel Loading Error"
	error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	error_label.add_theme_font_size_override("font_size", 24)
	main_container.add_child(error_label)
	
	# Spacer
	var spacer1 = Control.new()
	spacer1.custom_minimum_size.y = 20
	main_container.add_child(spacer1)
	
	# Error message
	var message_label = Label.new()
	message_label.text = "Failed to load the %s panel.\n\nError: %s" % [_get_phase_display_name(phase), error_message]
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main_container.add_child(message_label)
	
	# Spacer
	var spacer2 = Control.new()
	spacer2.custom_minimum_size.y = 30
	main_container.add_child(spacer2)
	
	# Action buttons
	var button_container = HBoxContainer.new()
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	button_container.add_theme_constant_override("separation", 20)
	main_container.add_child(button_container)
	
	# Retry button
	var retry_button = Button.new()
	retry_button.text = "Retry"
	retry_button.custom_minimum_size = Vector2(120, 40)
	retry_button.pressed.connect(func(): _retry_panel_load(phase))
	button_container.add_child(retry_button)
	
	# Continue button (if previous phase available)
	if _can_continue_without_panel(phase):
		var continue_button = Button.new()
		continue_button.text = "Continue"
		continue_button.custom_minimum_size = Vector2(120, 40)
		continue_button.pressed.connect(func(): _continue_without_panel(phase))
		button_container.add_child(continue_button)
	
	# Restart button
	var restart_button = Button.new()
	restart_button.text = "Restart"
	restart_button.custom_minimum_size = Vector2(120, 40)
	restart_button.pressed.connect(func(): _restart_campaign_creation())
	button_container.add_child(restart_button)
	
	print("CampaignCreationUI: Fallback panel created successfully")
	return fallback_panel

## PHASE 1: Robust Panel Detection & Coordinator Setup
func _setup_panel_references(panel_instance: Control, phase: CampaignStateManager.Phase) -> void:
	"""Robust panel detection and coordinator setup"""
	var is_campaign_panel = false
	
	# Method 1: Check script inheritance
	if panel_instance.get_script():
		var base = panel_instance.get_script().get_base_script()
		if base and base.resource_path.ends_with("BaseCampaignPanel.gd"):
			is_campaign_panel = true
			print("CampaignCreationUI: Panel detected via script inheritance")
	
	# Method 2: Duck typing fallback
	if not is_campaign_panel:
		is_campaign_panel = panel_instance.has_method("set_panel_info")
		if is_campaign_panel:
			print("CampaignCreationUI: Panel detected via duck typing")
	
	if is_campaign_panel:
		# SPRINT 26.20 FIX: Use Dictionary container for closure capture
		# GDScript closures capture by reference, but assignment creates shadow variables
		# Using a Dictionary allows the lambda to modify the outer state
		var panel_state = {"ready_received": false}
		var ready_callback = func():
			panel_state.ready_received = true

		if panel_instance.has_signal("panel_ready"):
			if not panel_instance.is_connected("panel_ready", ready_callback):
				panel_instance.panel_ready.connect(ready_callback, CONNECT_ONE_SHOT)

		# NOW pass coordinator (which triggers panel initialization and may emit panel_ready)
		if coordinator and coordinator.has_method("pass_coordinator_to_panel"):
			coordinator.pass_coordinator_to_panel(panel_instance)
			print("CampaignCreationUI: ✅ Used enhanced coordinator integration")
		else:
			# Fallback to legacy method
			panel_instance.set_coordinator(coordinator)
			panel_instance.set_state_manager(state_manager)
			print("CampaignCreationUI: ⚠️ Used legacy coordinator integration")

		# Wait for panel_ready if we haven't received it yet
		if panel_instance.has_signal("panel_ready") and not panel_state.ready_received:
			# Create a timeout to avoid waiting forever
			var timeout_timer = get_tree().create_timer(2.0)

			# Wait for either panel_ready or timeout
			while not panel_state.ready_received and timeout_timer.time_left > 0:
				await get_tree().process_frame

			if panel_state.ready_received:
				print("CampaignCreationUI: ✅ Panel ready signal received")
			else:
				print("CampaignCreationUI: ⚠️ Panel ready timeout - proceeding anyway")
		elif panel_state.ready_received:
			print("CampaignCreationUI: ✅ Panel ready signal already received (fast init)")
		else:
			# Fallback: wait one frame for panels without panel_ready signal
			await get_tree().process_frame

		# Configure panel title/description for this phase
		_configure_panel_for_phase(panel_instance, phase)

		# Connect panel signals (cleanup any existing first)
		_connect_panel_signals(panel_instance)

		print("CampaignCreationUI: Panel setup complete with coordinator")
	else:
		push_warning("CampaignCreationUI: Panel is not a campaign panel type")

func _configure_panel_for_phase(panel: Control, phase: CampaignStateManager.Phase) -> void:
	"""Configure panel with phase-specific information"""
	var phase_info = _get_phase_configuration(phase)
	
	# Set panel title and description
	if panel.has_method("set_panel_info"):
		panel.set_panel_info(phase_info.title, phase_info.description)
		print("CampaignCreationUI: ✅ Panel configured - %s" % phase_info.title)
	
	# Update UI elements if they exist
	_update_panel_ui_elements(panel, phase_info)

func _get_phase_configuration(phase: CampaignStateManager.Phase) -> Dictionary:
	"""Get phase-specific configuration data"""
	match phase:
		CampaignStateManager.Phase.CONFIG:
			return {
				"title": "Campaign Configuration",
				"description": "Set up your campaign name, difficulty, and game mode settings."
			}
		CampaignStateManager.Phase.CAPTAIN_CREATION:
			return {
				"title": "Captain Creation",
				"description": "Create your crew's captain. Choose background, generate stats, or customize."
			}
		CampaignStateManager.Phase.CREW_SETUP:
			return {
				"title": "Crew Generation",
				"description": "Generate your crew members. You need at least 4 crew to start your campaign."
			}
		CampaignStateManager.Phase.SHIP_ASSIGNMENT:
			return {
				"title": "Ship Assignment",
				"description": "Choose your crew's starship and configure its capabilities."
			}
		CampaignStateManager.Phase.EQUIPMENT_GENERATION:
			return {
				"title": "Equipment & Gear",
				"description": "Generate starting equipment, weapons, and credits for your crew."
			}
		CampaignStateManager.Phase.WORLD_GENERATION:
			return {
				"title": "Starting World",
				"description": "Generate your starting world and explore available opportunities."
			}
		CampaignStateManager.Phase.FINAL_REVIEW:
			return {
				"title": "Campaign Review",
				"description": "Review all settings and launch your Five Parsecs campaign."
			}
		_:
			return {"title": "Campaign Creation", "description": "Configure your campaign settings."}

func _update_panel_ui_elements(panel: Control, phase_info: Dictionary) -> void:
	"""Update panel UI elements with phase information"""
	# Look for common UI elements to update
	var title_label = panel.get_node_or_null("Title")
	if not title_label:
		title_label = panel.get_node_or_null("ContentMargin/MainContent/Title")
	if not title_label:
		title_label = panel.get_node_or_null("ContentMargin/MainContent/FormContent/Title")
	
	if title_label and title_label is Label:
		title_label.text = phase_info.title
		print("CampaignCreationUI: ✅ Updated panel title: %s" % phase_info.title)
	
	var description_label = panel.get_node_or_null("Description")
	if not description_label:
		description_label = panel.get_node_or_null("ContentMargin/MainContent/Description")
	if not description_label:
		description_label = panel.get_node_or_null("ContentMargin/MainContent/FormContent/Description")
	
	if description_label and description_label is Label:
		description_label.text = phase_info.description
		print("CampaignCreationUI: ✅ Updated panel description")

func _get_phase_display_name(phase: CampaignStateManager.Phase) -> String:
	"""GDScript 2.0: Get display name for phase (7 phases)"""
	match phase:
		CampaignStateManager.Phase.CONFIG:
			return "Campaign Setup" # Updated name to include victory conditions
		# REMOVED: CampaignStateManager.Phase.VICTORY_CONDITIONS
		CampaignStateManager.Phase.CAPTAIN_CREATION:
			return "Captain Creation"
		CampaignStateManager.Phase.CREW_SETUP:
			return "Crew Setup"
		CampaignStateManager.Phase.SHIP_ASSIGNMENT:
			return "Ship Assignment"
		CampaignStateManager.Phase.EQUIPMENT_GENERATION:
			return "Equipment Distribution"
		CampaignStateManager.Phase.WORLD_GENERATION:
			return "World Generation"
		CampaignStateManager.Phase.FINAL_REVIEW:
			return "Final Review"
		_:
			return "Unknown Phase"

func get_coordinator() -> CampaignCreationCoordinator:
	"""Get the campaign coordinator instance for panels to use"""
	print("CampaignCreationUI: Providing coordinator reference to panel")
	return coordinator

func get_state_manager() -> CampaignStateManager:
	"""Get the state manager instance for panels to use"""
	print("CampaignCreationUI: Providing state manager reference to panel")
	return state_manager

func _can_continue_without_panel(phase: CampaignStateManager.Phase) -> bool:
	"""Check if campaign creation can continue without this panel"""
	# Allow continuing without optional phases
	return phase in [
		CampaignStateManager.Phase.EQUIPMENT_GENERATION,
		CampaignStateManager.Phase.WORLD_GENERATION
	]

func _retry_panel_load(phase: CampaignStateManager.Phase) -> void:
	"""Retry loading the failed panel"""
	print("CampaignCreationUI: Retrying panel load for phase: %s" % phase)
	_clear_current_panel()
	_switch_to_phase(phase)

func _continue_without_panel(phase: CampaignStateManager.Phase) -> void:
	"""Continue to next phase without loading the failed panel"""
	print("CampaignCreationUI: Continuing without panel for phase: %s" % phase)
	if coordinator and coordinator.can_advance_to_next_phase():
		coordinator.advance_to_next_phase()
		var next_phase = state_manager.current_phase
		_switch_to_phase(next_phase)
	else:
		push_warning("CampaignCreationUI: Cannot advance to next phase")

func _validate_and_fix_panel_paths() -> void:
	"""Validate and fix panel paths, correcting any panels_backup references"""
	print("CampaignCreationUI: Validating panel paths...")
	
	var fixed_paths = 0
	var missing_paths = 0
	
	for phase in panel_scenes:
		var scene_path = panel_scenes[phase]
		
		if not ResourceLoader.exists(scene_path):
			push_warning("Panel path doesn't exist: %s" % scene_path)
			
			# Try to fix panels_backup references
			var corrected_path = scene_path.replace("panels_backup", "panels")
			if corrected_path != scene_path and ResourceLoader.exists(corrected_path):
				print("✓ Fixed path: %s -> %s" % [scene_path, corrected_path])
				panel_scenes[phase] = corrected_path
				fixed_paths += 1
			else:
				push_error("✗ Cannot fix path: %s" % scene_path)
				missing_paths += 1
		else:
			print("✓ Valid path: %s" % scene_path)
	
	if fixed_paths > 0:
		print("CampaignCreationUI: Fixed %d panel paths" % fixed_paths)
	if missing_paths > 0:
		push_error("CampaignCreationUI: %d panel paths are still missing!" % missing_paths)
	else:
		print("CampaignCreationUI: All panel paths validated successfully")

func _restart_campaign_creation() -> void:
	"""Restart the entire campaign creation process"""
	print("CampaignCreationUI: Restarting campaign creation")
	_clear_current_panel()
	
	# Reset coordinator state
	if coordinator:
		coordinator.reset_to_beginning()
	
	# Return to first phase
	_switch_to_phase(CampaignStateManager.Phase.CONFIG)

func _display_fallback_panel(phase: CampaignStateManager.Phase, error_message: String) -> void:
	"""Display fallback panel when loading fails"""
	var fallback_panel = _create_fallback_panel(phase, error_message)
	content_container.add_child(fallback_panel)

	# Ensure fallback panel fills the content container properly
	fallback_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	fallback_panel.offset_left = 0
	fallback_panel.offset_top = 0
	fallback_panel.offset_right = 0
	fallback_panel.offset_bottom = 0
	fallback_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fallback_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	current_panel = fallback_panel
	print("CampaignCreationUI: Fallback panel displayed for phase: %s" % phase)

# PHASE 4: Enhanced Signal Management with Memory Safety
func _safe_connect_signal(panel: Control, signal_name: String, callback: Callable) -> void:
	"""Safely connect signals with duplicate prevention, handler validation, and cleanup tracking"""
	if not panel or not panel.has_signal(signal_name):
		return

	# SPRINT 3.3: Validate callback is valid before attempting connection
	if not callback.is_valid():
		push_warning("CampaignCreationUI: Callback for signal '%s' is not valid" % signal_name)
		return

	# Check if already connected
	if panel.is_connected(signal_name, callback):
		print("CampaignCreationUI: Signal '%s' already connected, skipping" % signal_name)
		return

	# Connect signal with error handling
	var error = panel.connect(signal_name, callback)
	if error != OK:
		push_warning("CampaignCreationUI: Failed to connect signal '%s': error code %d" % [signal_name, error])
		return

	# Track connection for cleanup (only if connection succeeded)
	_panel_signal_connections.append({
		"panel": panel,
		"signal_name": signal_name,
		"callback": callback
	})

	print("CampaignCreationUI: ✅ Connected signal: %s" % signal_name)

func _cleanup_panel_signals() -> void:
	"""Clean up all tracked signal connections for memory safety"""
	var cleaned_count = 0

	# Clean up panel-to-UI connections
	for connection in _panel_signal_connections:
		var panel = connection.get("panel")
		var signal_name = connection.get("signal_name")
		var callback = connection.get("callback")

		if panel and is_instance_valid(panel) and panel.is_connected(signal_name, callback):
			panel.disconnect(signal_name, callback)
			cleaned_count += 1

	_panel_signal_connections.clear()

	# Clean up coordinator-to-panel connections
	if coordinator:
		for connection in _coordinator_panel_connections:
			var panel = connection.get("panel")
			var signal_name = connection.get("signal_name")
			var callback = connection.get("callback")

			if panel and is_instance_valid(panel) and coordinator.is_connected(signal_name, callback):
				coordinator.disconnect(signal_name, callback)
				cleaned_count += 1

	_coordinator_panel_connections.clear()

	print("CampaignCreationUI: ✅ Cleaned up %d signal connections" % cleaned_count)

func _setup_memory_safety_timer() -> void:
	"""Setup timer for periodic memory cleanup"""
	_cleanup_timer = Timer.new()
	_cleanup_timer.timeout.connect(_periodic_memory_cleanup)
	_cleanup_timer.wait_time = 30.0 # Clean up every 30 seconds
	_cleanup_timer.autostart = true
	add_child(_cleanup_timer)
	print("CampaignCreationUI: ✅ Memory safety timer enabled")

func _periodic_memory_cleanup() -> void:
	"""Periodic cleanup of invalid connections and references"""
	var invalid_connections = 0
	
	# Clean up invalid signal connections
	for i in range(_panel_signal_connections.size() - 1, -1, -1):
		var connection = _panel_signal_connections[i]
		var panel = connection.get("panel")
		
		if not panel or not is_instance_valid(panel):
			_panel_signal_connections.remove_at(i)
			invalid_connections += 1
	
	if invalid_connections > 0:
		print("CampaignCreationUI: ✅ Cleaned up %d invalid signal connections" % invalid_connections)

func _get_panel_script_name(panel: Control) -> String:
	"""Extract the panel script name for signal connection routing.
	SPRINT 26.24: get_class() returns 'PanelContainer' for all panels since they
	extend PanelContainer via BaseCampaignPanel. We need the actual script name."""
	if panel and panel.get_script():
		var script_path: String = panel.get_script().resource_path
		# Extract filename without extension: ".../FinalPanel.gd" -> "FinalPanel"
		var filename = script_path.get_file().get_basename()
		return filename
	return panel.get_class() if panel else ""

func _connect_panel_signals(panel: Control) -> void:
	"""Connect signals from panel to coordinator and state management with comprehensive coverage"""
	if not panel:
		return

	# SPRINT 26.24: Use script name instead of get_class() which returns "PanelContainer" for all panels
	var panel_name = _get_panel_script_name(panel)
	print("CampaignCreationUI: Connecting signals for panel: %s" % panel_name)
	
	# PHASE 4: Clean up previous connections before connecting new ones
	_cleanup_panel_signals()

	# CRITICAL FIX: Connect coordinator's campaign_state_updated TO the panel
	# This enables cross-panel communication and real-time state synchronization
	if coordinator and panel.has_method("_on_campaign_state_updated"):
		if not coordinator.campaign_state_updated.is_connected(panel._on_campaign_state_updated):
			coordinator.campaign_state_updated.connect(panel._on_campaign_state_updated, CONNECT_DEFERRED)

			# Track coordinator->panel connection for cleanup
			_coordinator_panel_connections.append({
				"panel": panel,
				"signal_name": "campaign_state_updated",
				"callback": panel._on_campaign_state_updated
			})

			print("CampaignCreationUI: ✅ Connected coordinator.campaign_state_updated -> %s._on_campaign_state_updated" % panel_name)
		else:
			print("CampaignCreationUI: ⚠️ coordinator.campaign_state_updated already connected to %s" % panel_name)
	else:
		if not coordinator:
			print("CampaignCreationUI: ⚠️ Coordinator not initialized")
		elif not panel.has_method("_on_campaign_state_updated"):
			print("CampaignCreationUI: ⚠️ Panel %s missing _on_campaign_state_updated method" % panel_name)
	
	# Connect BaseCampaignPanel signals (standard interface) with safe connections
	_safe_connect_signal(panel, "panel_data_changed", _on_panel_data_changed)
	_safe_connect_signal(panel, "panel_validation_changed", _on_panel_validation_changed)
	_safe_connect_signal(panel, "panel_completed", _on_panel_completed)
	_safe_connect_signal(panel, "validation_failed", _on_panel_validation_failed)
	_safe_connect_signal(panel, "panel_ready", _on_panel_ready)
	
	# Connect specific panel signals based on panel type
	# SPRINT 26.24: Use panel_name (from script) instead of get_class() which returns "PanelContainer"
	match panel_name:
		"ConfigPanel", "ExpandedConfigPanel":
			_connect_config_panel_signals(panel)

		"CaptainPanel":
			_connect_captain_panel_signals(panel)

		"CrewPanel":
			_connect_crew_panel_signals(panel)

		# REMOVED: "VictoryConditionsPanel" (merged into ExpandedConfigPanel)

		"EquipmentPanel":
			_connect_equipment_panel_signals(panel)

		"ShipPanel":
			_connect_ship_panel_signals(panel)

		"WorldInfoPanel":
			_connect_world_panel_signals(panel)

		"FinalPanel":
			_connect_final_panel_signals(panel)

	print("CampaignCreationUI: Signal connections completed for %s" % panel_name)

func _connect_config_panel_signals(panel: Control) -> void:
	"""GDScript 2.0: Connect ConfigPanel specific signals with victory conditions support and deduplication"""
	if panel.has_signal("config_updated") and not panel.config_updated.is_connected(_on_config_updated):
		panel.config_updated.connect(_on_config_updated, CONNECT_DEFERRED)
	
	if panel.has_signal("configuration_complete") and not panel.configuration_complete.is_connected(_on_configuration_complete):
		panel.configuration_complete.connect(_on_configuration_complete, CONNECT_DEFERRED)
	
	if panel.has_signal("campaign_name_changed") and not panel.campaign_name_changed.is_connected(_on_campaign_name_changed):
		panel.campaign_name_changed.connect(_on_campaign_name_changed, CONNECT_DEFERRED)
	
	if panel.has_signal("difficulty_changed") and not panel.difficulty_changed.is_connected(_on_difficulty_changed):
		panel.difficulty_changed.connect(_on_difficulty_changed, CONNECT_DEFERRED)
	
	if panel.has_signal("ironman_toggled") and not panel.ironman_toggled.is_connected(_on_ironman_toggled):
		panel.ironman_toggled.connect(_on_ironman_toggled, CONNECT_DEFERRED)
	
	# GDScript 2.0: New victory conditions signals for ExpandedConfigPanel with deduplication
	if panel.has_signal("campaign_config_data_complete") and not panel.campaign_config_data_complete.is_connected(_on_campaign_config_data_complete):
		panel.campaign_config_data_complete.connect(_on_campaign_config_data_complete, CONNECT_DEFERRED)
	
	if panel.has_signal("victory_conditions_changed") and not panel.victory_conditions_changed.is_connected(_on_victory_conditions_changed):
		panel.victory_conditions_changed.connect(_on_victory_conditions_changed, CONNECT_DEFERRED)

func _connect_captain_panel_signals(panel: Control) -> void:
	"""Connect CaptainPanel specific signals with deduplication"""
	if panel.has_signal("captain_created") and not panel.captain_created.is_connected(_on_captain_created):
		panel.captain_created.connect(_on_captain_created, CONNECT_DEFERRED)
	
	if panel.has_signal("captain_data_updated") and not panel.captain_data_updated.is_connected(_on_captain_data_updated):
		panel.captain_data_updated.connect(_on_captain_data_updated, CONNECT_DEFERRED)
	
	if panel.has_signal("captain_updated") and not panel.captain_updated.is_connected(_on_captain_created):
		panel.captain_updated.connect(_on_captain_created, CONNECT_DEFERRED)
	
	if panel.has_signal("captain_generated") and not panel.captain_generated.is_connected(_on_captain_created):
		panel.captain_generated.connect(_on_captain_created, CONNECT_DEFERRED)

func _connect_crew_panel_signals(panel: Control) -> void:
	"""Connect CrewPanel specific signals with deduplication"""
	if panel.has_signal("crew_setup_complete") and not panel.crew_setup_complete.is_connected(_on_crew_setup_complete):
		panel.crew_setup_complete.connect(_on_crew_setup_complete, CONNECT_DEFERRED)
	
	if panel.has_signal("crew_data_complete") and not panel.crew_data_complete.is_connected(_on_crew_data_complete):
		panel.crew_data_complete.connect(_on_crew_data_complete, CONNECT_DEFERRED)
	
	if panel.has_signal("crew_data_changed") and not panel.crew_data_changed.is_connected(_on_crew_data_complete):
		panel.crew_data_changed.connect(_on_crew_data_complete, CONNECT_DEFERRED)
	
	if panel.has_signal("crew_updated") and not panel.crew_updated.is_connected(_on_crew_updated):
		panel.crew_updated.connect(_on_crew_updated, CONNECT_DEFERRED)
	
	if panel.has_signal("crew_member_added") and not panel.crew_member_added.is_connected(_on_crew_member_added):
		panel.crew_member_added.connect(_on_crew_member_added, CONNECT_DEFERRED)

func _connect_victory_conditions_panel_signals(panel: Control) -> void:
	"""Connect VictoryConditionsPanel specific signals with deduplication"""
	if panel.has_signal("victory_conditions_updated") and not panel.victory_conditions_updated.is_connected(_on_victory_conditions_updated):
		panel.victory_conditions_updated.connect(_on_victory_conditions_updated, CONNECT_DEFERRED)
	
	if panel.has_signal("victory_conditions_changed") and not panel.victory_conditions_changed.is_connected(_on_victory_conditions_updated):
		panel.victory_conditions_changed.connect(_on_victory_conditions_updated, CONNECT_DEFERRED)
	
	if panel.has_signal("conditions_updated") and not panel.conditions_updated.is_connected(_on_victory_conditions_updated):
		panel.conditions_updated.connect(_on_victory_conditions_updated, CONNECT_DEFERRED)

func _connect_equipment_panel_signals(panel: Control) -> void:
	"""Connect EquipmentPanel specific signals with deduplication"""
	if panel.has_signal("equipment_data_changed") and not panel.equipment_data_changed.is_connected(_on_equipment_data_changed):
		panel.equipment_data_changed.connect(_on_equipment_data_changed, CONNECT_DEFERRED)
	
	if panel.has_signal("equipment_generated") and not panel.equipment_generated.is_connected(_on_equipment_generated):
		panel.equipment_generated.connect(_on_equipment_generated, CONNECT_DEFERRED)
	
	if panel.has_signal("equipment_setup_complete") and not panel.equipment_setup_complete.is_connected(_on_equipment_setup_complete):
		panel.equipment_setup_complete.connect(_on_equipment_setup_complete, CONNECT_DEFERRED)
	
	if panel.has_signal("equipment_generation_complete") and not panel.equipment_generation_complete.is_connected(_on_equipment_generation_complete):
		panel.equipment_generation_complete.connect(_on_equipment_generation_complete, CONNECT_DEFERRED)

func _connect_ship_panel_signals(panel: Control) -> void:
	"""Connect ShipPanel specific signals with deduplication"""
	if panel.has_signal("ship_data_changed") and not panel.ship_data_changed.is_connected(_on_ship_data_changed):
		panel.ship_data_changed.connect(_on_ship_data_changed, CONNECT_DEFERRED)
	
	if panel.has_signal("ship_updated") and not panel.ship_updated.is_connected(_on_ship_updated):
		panel.ship_updated.connect(_on_ship_updated, CONNECT_DEFERRED)
	
	if panel.has_signal("ship_setup_complete") and not panel.ship_setup_complete.is_connected(_on_ship_setup_complete):
		panel.ship_setup_complete.connect(_on_ship_setup_complete, CONNECT_DEFERRED)
	
	if panel.has_signal("ship_configuration_complete") and not panel.ship_configuration_complete.is_connected(_on_ship_configuration_complete):
		panel.ship_configuration_complete.connect(_on_ship_configuration_complete, CONNECT_DEFERRED)

func _connect_world_panel_signals(panel: Control) -> void:
	"""Connect WorldInfoPanel specific signals with deduplication"""
	if panel.has_signal("world_generated") and not panel.world_generated.is_connected(_on_world_generated):
		panel.world_generated.connect(_on_world_generated, CONNECT_DEFERRED)
	
	if panel.has_signal("world_updated") and not panel.world_updated.is_connected(_on_world_updated):
		panel.world_updated.connect(_on_world_updated, CONNECT_DEFERRED)
	
	if panel.has_signal("world_created") and not panel.world_created.is_connected(_on_world_created):
		panel.world_created.connect(_on_world_created, CONNECT_DEFERRED)

func _connect_final_panel_signals(panel: Control) -> void:
	"""Connect FinalPanel specific signals with bridge integration"""
	if not panel:
		push_warning("CampaignCreationUI: Attempted to connect signals to null panel")
		return
	
	# Connect existing signals for compatibility
	if panel.has_signal("review_completed"):
		panel.review_completed.connect(_on_review_completed)
	
	if panel.has_signal("final_review_complete"):
		panel.final_review_complete.connect(_on_final_review_complete)
	
	if panel.has_signal("campaign_validated"):
		panel.campaign_validated.connect(_on_campaign_validated)
	
	# NEW: Connect actual FinalPanel signals to bridge
	if panel.has_signal("campaign_creation_requested"):
		panel.campaign_creation_requested.connect(_on_campaign_creation_requested_from_panel)

	if panel.has_signal("campaign_finalization_complete"):
		panel.campaign_finalization_complete.connect(_on_campaign_finalization_complete_from_panel)

	# Sprint 20.3: Connect campaign_confirmed signal for Create Campaign button
	if panel.has_signal("campaign_confirmed"):
		panel.campaign_confirmed.connect(_on_campaign_confirmed_from_panel)

func _disconnect_panel_signals(panel: Control) -> void:
	"""Disconnect all signals from panel with comprehensive coverage"""
	if not panel:
		return

	# SPRINT 26.24: Use script name for consistent logging
	var panel_name = _get_panel_script_name(panel)
	print("CampaignCreationUI: Disconnecting signals for panel: %s" % panel_name)

	# CRITICAL FIX: Disconnect campaign data updates FROM the panel
	if panel.has_method("_on_campaign_state_updated"):
		if campaign_data_updated.is_connected(panel._on_campaign_state_updated):
			campaign_data_updated.disconnect(panel._on_campaign_state_updated)
			print("CampaignCreationUI: ✅ Disconnected campaign_data_updated from %s._on_campaign_state_updated" % panel_name)
	
	# Disconnect common BaseCampaignPanel signals
	if panel.has_signal("panel_data_changed") and panel.panel_data_changed.is_connected(_on_panel_data_changed):
		panel.panel_data_changed.disconnect(_on_panel_data_changed)
	
	if panel.has_signal("panel_validation_changed") and panel.panel_validation_changed.is_connected(_on_panel_validation_changed):
		panel.panel_validation_changed.disconnect(_on_panel_validation_changed)
	
	if panel.has_signal("panel_completed") and panel.panel_completed.is_connected(_on_panel_completed):
		panel.panel_completed.disconnect(_on_panel_completed)
	
	if panel.has_signal("validation_failed") and panel.validation_failed.is_connected(_on_panel_validation_failed):
		panel.validation_failed.disconnect(_on_panel_validation_failed)
	
	# Disconnect CaptainPanel specific signals
	if panel.has_signal("captain_created") and panel.captain_created.is_connected(_on_captain_created):
		panel.captain_created.disconnect(_on_captain_created)
	
	if panel.has_signal("captain_data_updated") and panel.captain_data_updated.is_connected(_on_captain_data_updated):
		panel.captain_data_updated.disconnect(_on_captain_data_updated)
	
	# Disconnect CrewPanel specific signals
	if panel.has_signal("crew_setup_complete") and panel.crew_setup_complete.is_connected(_on_crew_setup_complete):
		panel.crew_setup_complete.disconnect(_on_crew_setup_complete)
	
	if panel.has_signal("crew_data_complete") and panel.crew_data_complete.is_connected(_on_crew_data_complete):
		panel.crew_data_complete.disconnect(_on_crew_data_complete)
	
	if panel.has_signal("crew_data_changed") and panel.crew_data_changed.is_connected(_on_crew_data_complete):
		panel.crew_data_changed.disconnect(_on_crew_data_complete)
	
	# Disconnect VictoryConditionsPanel specific signals
	if panel.has_signal("victory_conditions_updated") and panel.victory_conditions_updated.is_connected(_on_victory_conditions_updated):
		panel.victory_conditions_updated.disconnect(_on_victory_conditions_updated)
	
	if panel.has_signal("victory_conditions_changed") and panel.victory_conditions_changed.is_connected(_on_victory_conditions_updated):
		panel.victory_conditions_changed.disconnect(_on_victory_conditions_updated)
	
	# Disconnect EquipmentPanel specific signals
	if panel.has_signal("equipment_data_changed") and panel.equipment_data_changed.is_connected(_on_equipment_data_changed):
		panel.equipment_data_changed.disconnect(_on_equipment_data_changed)
	
	# Disconnect ShipPanel specific signals
	if panel.has_signal("ship_data_changed") and panel.ship_data_changed.is_connected(_on_ship_data_changed):
		panel.ship_data_changed.disconnect(_on_ship_data_changed)

	print("CampaignCreationUI: Signal disconnections completed for %s" % panel_name)

func _update_progress_for_phase(phase: CampaignStateManager.Phase) -> void:
	"""Update progress indicator for current phase with step name"""
	# Map phase enum to step number (1-7) - Core Rules SOP order
	var step_number := 1
	match phase:
		CampaignStateManager.Phase.CONFIG:
			step_number = 1
		CampaignStateManager.Phase.CAPTAIN_CREATION:
			step_number = 2
		CampaignStateManager.Phase.CREW_SETUP:
			step_number = 3
		CampaignStateManager.Phase.EQUIPMENT_GENERATION:
			step_number = 4  # Core Rules: Equipment before Ship
		CampaignStateManager.Phase.SHIP_ASSIGNMENT:
			step_number = 5  # Core Rules: Ship is final step (determines debt)
		CampaignStateManager.Phase.WORLD_GENERATION:
			step_number = 6
		CampaignStateManager.Phase.FINAL_REVIEW:
			step_number = 7
	
	var phase_name = _get_phase_display_name(phase)
	update_progress_indicator(step_number, phase_name)

func _update_navigation_state() -> void:
	"""Update navigation button states with debouncing protection"""
	if not coordinator:
		return
	
	# Prevent concurrent navigation updates
	if _is_updating_navigation:
		print("CampaignCreationUI: Navigation update already in progress, skipping")
		return
	
	# Queue deferred update if navigation update is pending
	if _navigation_update_pending:
		return
	
	_navigation_update_pending = true
	call_deferred("_perform_navigation_update")

func _perform_navigation_update() -> void:
	"""Perform the actual navigation state update"""
	_is_updating_navigation = true
	_navigation_update_pending = false
	
	# Safety check - ensure coordinator and buttons exist
	if not coordinator or not back_button or not next_button or not finish_button:
		push_warning("CampaignCreationUI: Missing coordinator or navigation buttons during update")
		_is_updating_navigation = false
		return
	
	var current_phase = state_manager.current_phase if state_manager else CampaignStateManager.Phase.CONFIG
	
	# Update back button
	var can_go_back = coordinator.can_go_back_to_previous_phase()
	back_button.disabled = not can_go_back
	
	# Update next/finish button  
	var can_advance = coordinator.can_advance_to_next_phase()
	# Check if this is the final phase by comparing with total steps
	var is_final_phase = (coordinator.current_step >= coordinator.total_steps - 1)
	
	if is_final_phase:
		next_button.visible = false
		finish_button.visible = true
		finish_button.disabled = not can_advance
	else:
		next_button.visible = true
		finish_button.visible = false
		next_button.disabled = not can_advance
	
	# Update progress indicator if available
	if progress_indicator and step_indicator:
		_update_progress_for_phase(current_phase)
	
	_is_updating_navigation = false
	print("CampaignCreationUI: Navigation state updated for phase: %s" % current_phase)

# PHASE 3 INTEGRATION: Duplicate signal handlers removed - using comprehensive versions above

# Victory conditions handler is implemented above as _on_victory_conditions_updated

# State persistence helper
func _save_current_panel_state() -> void:
	"""Save current panel state to coordinator before navigation to prevent data loss"""
	if not current_panel or not is_instance_valid(current_panel):
		return

	if not current_panel.has_method("get_panel_data"):
		push_warning("CampaignCreationUI: Panel does not have get_panel_data() - data may not be saved")
		return

	var data = current_panel.get_panel_data()
	if data == null:
		push_warning("CampaignCreationUI: get_panel_data() returned null - attempting recovery")
		# Retry once after frame delay (panel may still be initializing)
		if is_inside_tree():
			await get_tree().process_frame
			if is_inside_tree() and is_instance_valid(current_panel):
				data = current_panel.get_panel_data()

		if data == null:
			push_error("CampaignCreationUI: CRITICAL - Panel data permanently unavailable after retry")
			_show_panel_data_sync_warning("Unable to retrieve panel data. Your changes may not be saved.")
			data = {}  # Use empty dict to continue instead of silent exit

	if data.is_empty():
		# Empty data is valid for some panels (e.g., no changes made yet)
		return

	print("CampaignCreationUI: Saving panel state before navigation")
	var sync_failed := false

	# Route data to coordinator based on current phase
	if coordinator:
		var data_routed = _route_data_to_coordinator_with_validation(data)
		if not data_routed:
			sync_failed = true
			push_warning("CampaignCreationUI: Failed to route panel data to coordinator")
	else:
		sync_failed = true
		push_warning("CampaignCreationUI: Coordinator not available - panel data not synchronized")

	# Also update state manager
	if state_manager:
		var current_phase = state_manager.get_current_phase()
		_update_state_manager_data(current_phase, data)
	else:
		sync_failed = true
		push_warning("CampaignCreationUI: State manager not available - panel data not persisted")

	if sync_failed:
		_show_panel_data_sync_warning("Some data may not have been saved. Please review before continuing.")
	else:
		print("CampaignCreationUI: Panel state saved successfully")

func _show_panel_data_sync_warning(message: String) -> void:
	"""Show a non-blocking warning about panel data sync issues"""
	# Use NotificationManager if available, otherwise use print
	if has_node("/root/NotificationManager"):
		var notif_manager = get_node("/root/NotificationManager")
		if notif_manager.has_method("show_warning"):
			notif_manager.show_warning("Data Sync Warning", message)
			return
	# Fallback: Log the warning
	push_warning("CampaignCreationUI: " + message)

func _route_data_to_coordinator_with_validation(data: Dictionary) -> bool:
	"""Route panel data to coordinator with validation - returns true if data was routed"""
	if not coordinator:
		return false

	var current_phase = state_manager.get_current_phase() if state_manager else CampaignStateManager.Phase.CONFIG
	var data_routed := false

	# Route data based on current phase and data content
	match current_phase:
		CampaignStateManager.Phase.CONFIG:
			if data.has("campaign_config") or data.has("campaign_name") or data.has("victory_conditions"):
				coordinator.update_campaign_config_state(data)
				data_routed = true

		CampaignStateManager.Phase.CAPTAIN_CREATION:
			# CRITICAL FIX: Pass FULL data object so coordinator can access captain_character for stats
			if data.has("captain") or data.has("captain_character"):
				coordinator.update_captain_state(data)
				data_routed = true
			elif data.has("captain_name") or data.has("captain_background") or data.has("name") or data.has("background"):
				coordinator.update_captain_state(data)
				data_routed = true

		CampaignStateManager.Phase.CREW_SETUP:
			if data.has("crew") or data.has("crew_members") or data.has("members"):
				coordinator.update_crew_state(data)
				data_routed = true

		CampaignStateManager.Phase.SHIP_ASSIGNMENT:
			if data.has("ship"):
				coordinator.update_ship_state(data)
				data_routed = true

		CampaignStateManager.Phase.EQUIPMENT_GENERATION:
			if data.has("equipment") or data.has("items"):
				coordinator.update_equipment_state(data)
				data_routed = true

		CampaignStateManager.Phase.WORLD_GENERATION:
			if data.has("world") or data.has("location"):
				coordinator.update_world_state(data)
				data_routed = true

		CampaignStateManager.Phase.FINAL_REVIEW:
			# Final review doesn't generate new data, it just confirms
			data_routed = true

	return data_routed

# Navigation button handlers
func _on_back_pressed() -> void:
	"""Handle back button press with enhanced safety"""
	print("CampaignCreationUI: Back button pressed")

	if not coordinator:
		push_warning("CampaignCreationUI: Coordinator not available for back navigation")
		return

	if not coordinator.can_go_back_to_previous_phase():
		print("CampaignCreationUI: Cannot go back - at first phase")
		return

	# Prevent multiple simultaneous back presses
	if _is_transitioning:
		print("CampaignCreationUI: Back press ignored - transition in progress")
		return

	# CRITICAL: Save panel state BEFORE clearing to prevent data loss
	_save_current_panel_state()

	# Perform navigation FIRST (updates state_manager.current_phase)
	var navigation_success = coordinator.go_back_to_previous_phase()
	if navigation_success:
		var previous_phase = state_manager.current_phase
		print("CampaignCreationUI: Navigating back to phase: %s" % previous_phase)
		# _switch_to_phase handles panel clearing internally with proper sequencing
		await _switch_to_phase(previous_phase)
	else:
		push_error("CampaignCreationUI: Failed to navigate back")

func _on_next_pressed() -> void:
	"""Handle next button press"""
	# Prevent multiple simultaneous next presses
	if _is_transitioning:
		print("CampaignCreationUI: Next press ignored - transition in progress")
		return

	if coordinator and coordinator.can_advance_to_next_phase():
		coordinator.advance_to_next_phase()
		var next_phase = state_manager.current_phase
		await _switch_to_phase(next_phase)

# Signal handlers for panel data changes
func _on_panel_data_changed(data: Dictionary) -> void:
	"""Handle real-time data updates from panels"""

	# DEFENSIVE PROGRAMMING: If signal emitted without data, fetch manually
	if data.is_empty():
		push_warning("CampaignCreationUI: Received empty data from panel - fetching manually")
		if current_panel and current_panel.has_method("get_panel_data"):
			data = current_panel.get_panel_data()
			print("CampaignCreationUI: Fetched panel data manually: ", data.keys())
		else:
			push_error("CampaignCreationUI: Cannot retrieve panel data - no get_panel_data() method")
			return

	print("CampaignCreationUI: Panel data changed: ", data.keys())

	# Update state manager with new data based on current phase
	if state_manager:
		var current_phase = state_manager.get_current_phase()
		_update_state_manager_data(current_phase, data)

	# Update coordinator based on current phase
	if coordinator:
		_route_data_to_coordinator(data)

	# Update navigation state
	_update_navigation_state()

func _update_state_manager_data(phase: CampaignStateManager.Phase, data: Dictionary) -> void:
	"""Update state manager with data based on phase"""
	match phase:
		CampaignStateManager.Phase.CONFIG:
			state_manager.update_config_data(data)
		CampaignStateManager.Phase.CAPTAIN_CREATION:
			state_manager.update_captain_data(data)
		CampaignStateManager.Phase.CREW_SETUP:
			state_manager.update_crew_data(data)
		CampaignStateManager.Phase.SHIP_ASSIGNMENT:
			state_manager.update_ship_data(data)
		CampaignStateManager.Phase.EQUIPMENT_GENERATION:
			state_manager.update_equipment_data(data)
		CampaignStateManager.Phase.WORLD_GENERATION:
			state_manager.update_world_data(data)
		CampaignStateManager.Phase.FINAL_REVIEW:
			# Final review doesn't need state manager update
			pass

func _route_data_to_coordinator(data: Dictionary) -> void:
	"""Route panel data to appropriate coordinator update methods"""
	if not coordinator:
		return
		
	var current_phase = state_manager.get_current_phase() if state_manager else CampaignStateManager.Phase.CONFIG
	
	# Route data based on current phase and data content
	match current_phase:
		CampaignStateManager.Phase.CONFIG:
			if data.has("campaign_config") or data.has("campaign_name") or data.has("victory_conditions"):
				coordinator.update_campaign_config_state(data)
		
		CampaignStateManager.Phase.CAPTAIN_CREATION:
			# Captain data can come in various formats - check all possibilities
			# CRITICAL FIX: Pass FULL data object so coordinator can access captain_character for stats
			if data.has("captain") or data.has("captain_character"):
				# Pass full data - coordinator needs both nested captain dict AND captain_character
				coordinator.update_captain_state(data)
			elif data.has("captain_name") or data.has("captain_background") or data.has("name") or data.has("background"):
				# Pass individual captain properties directly
				coordinator.update_captain_state(data)
		
		CampaignStateManager.Phase.CREW_SETUP:
			if data.has("crew") or data.has("crew_members") or data.has("members"):
				coordinator.update_crew_state(data)
		
		CampaignStateManager.Phase.SHIP_ASSIGNMENT:
			if data.has("ship"):
				# Extract ship data from nested structure
				coordinator.update_ship_state(data.ship)
			elif data.has("ship_name") or data.has("ship_type") or data.has("name") or data.has("type"):
				# Pass individual ship properties directly
				coordinator.update_ship_state(data)
		
		CampaignStateManager.Phase.EQUIPMENT_GENERATION:
			if data.has("equipment") or data.has("items") or data.has("credits"):
				coordinator.update_equipment_state(data)
		
		CampaignStateManager.Phase.WORLD_GENERATION:
			if data.has("world"):
				# Extract world data from nested structure
				coordinator.update_world_state(data.world)
			elif data.has("world_data") or data.has("starting_world") or data.has("world_type"):
				# Pass world properties directly
				coordinator.update_world_state(data)
		
		CampaignStateManager.Phase.FINAL_REVIEW:
			if data.has("review") or data.has("final_data"):
				coordinator.update_review_state(data)

func _on_panel_validation_changed(is_valid: bool, errors: Array = []) -> void:
	"""Handle panel validation state changes"""
	print("CampaignCreationUI: Panel validation changed - Valid: %s" % str(is_valid))

	# Update validation status bar
	_update_validation_status(is_valid, errors)

	if not coordinator or not state_manager:
		return

	# Update coordinator with validation status
	coordinator.mark_phase_complete(state_manager.current_phase, is_valid)

	# Update navigation
	_update_navigation_state()

func _update_validation_status(is_valid: bool, errors: Array = []) -> void:
	"""Update the validation status bar in the footer"""
	if not validation_icon or not validation_text:
		return

	if is_valid:
		validation_icon.text = "✅"
		validation_text.text = "Ready to continue"
		validation_text.add_theme_color_override("font_color", Color("#10B981"))  # Green
	else:
		validation_icon.text = "⚠️"
		# Show first error or default message
		if errors.size() > 0:
			validation_text.text = str(errors[0])
		else:
			# Try to get validation message from current panel
			var message = "Complete required fields to continue"
			if current_panel and current_panel.has_method("get_validation_message"):
				message = current_panel.get_validation_message()
			elif current_panel and "last_validation_errors" in current_panel:
				var panel_errors = current_panel.last_validation_errors
				if panel_errors.size() > 0:
					message = panel_errors[0]
			validation_text.text = message
		validation_text.add_theme_color_override("font_color", Color("#D97706"))  # Orange

func _on_panel_completed(data: Dictionary) -> void:
	"""Handle panel completion with comprehensive debugging"""
	print("=====================================")
	print("CampaignCreationUI: DEBUG - Panel completion received!")
	print("  Data keys: %s" % str(data.keys()))
	print("  Data size: %d items" % data.size())
	print("  Current panel: %s" % (current_panel.get_class() if current_panel else "None"))
	
	# Validate state manager and coordinator with recovery attempts
	if not coordinator:
		push_error("CampaignCreationUI: CRITICAL - coordinator is null during panel completion!")
		print("=====================================")
		return

	if not state_manager:
		push_warning("CampaignCreationUI: state_manager is null - attempting recovery from coordinator")
		# Try to recover state_manager from coordinator
		if coordinator and "state_manager" in coordinator:
			state_manager = coordinator.state_manager
			if state_manager:
				push_warning("CampaignCreationUI: Recovered state_manager from coordinator")
			else:
				push_error("CampaignCreationUI: CRITICAL - coordinator.state_manager is also null!")
				print("=====================================")
				return
		else:
			push_error("CampaignCreationUI: CRITICAL - Cannot recover state_manager, coordinator lacks state_manager property")
			print("=====================================")
			return
	
	# Get current phase info
	var current_phase = state_manager.get_current_phase()
	print("  Current phase: %s" % str(current_phase))
	print("  Phase name: %s" % state_manager.get_phase_name(current_phase))
	
	# Mark phase as complete
	print("  Marking phase complete...")
	coordinator.mark_phase_complete(current_phase)
	print("  Phase marked complete: %s" % str(current_phase))
	
	# Update navigation state
	print("  Updating navigation state...")
	_update_navigation_state()
	
	# Check if validation passes (enables Next button)
	var can_advance = state_manager.validate_current_step()
	print("  Can advance: %s" % str(can_advance))

	# AUTO-ADVANCE DISABLED: Users should explicitly click "Next" to proceed
	# This gives users time to review their choices before advancing
	# The panel_completed signal now only updates navigation state (enables Next button)
	# rather than automatically advancing to the next panel
	print("  Auto-advance disabled - user must click Next to proceed")

	print("CampaignCreationUI: Panel completion processing finished")
	print("=====================================")

func _safe_auto_advance() -> void:
	"""Safely auto-advance to next panel after ensuring cleanup is complete"""
	if not _auto_advance_pending:
		return

	# Wait one frame to ensure previous panel is fully cleaned up (with null safety)
	if not is_inside_tree():
		_auto_advance_pending = false
		return
	await get_tree().process_frame

	# Safety check after await - node may have been removed from tree
	if not is_inside_tree():
		_auto_advance_pending = false
		return

	_auto_advance_pending = false

	# Re-check conditions after waiting
	if _is_transitioning:
		print("CampaignCreationUI: Auto-advance cancelled - transition in progress")
		return

	if not state_manager.validate_current_step():
		print("CampaignCreationUI: Auto-advance cancelled - validation failed")
		return

	print("CampaignCreationUI: Executing safe auto-advance")
	_on_next_pressed()

func _on_panel_validation_failed(errors: Array) -> void:
	"""Handle validation failures"""
	print("CampaignCreationUI: Panel validation failed: ", errors)
	# Update validation status bar with errors
	_update_validation_status(false, errors)
	# Show validation errors to user (popup/toast if implemented)
	_show_validation_errors(errors)

# Specific panel signal handlers
func _on_navigation_updated(can_go_back: bool, can_go_forward: bool, can_finish: bool) -> void:
	"""Handle navigation state updates from coordinator"""
	if _is_updating_navigation:
		return # Prevent recursive updates
	
	print("CampaignCreationUI: Navigation updated - back: %s, forward: %s, finish: %s" % [can_go_back, can_go_forward, can_finish])
	
	# Update button states directly from coordinator signal
	if back_button:
		back_button.disabled = not can_go_back
	
	# Determine if we're on final phase
	var is_final_phase = (state_manager.current_phase == CampaignStateManager.Phase.FINAL_REVIEW)
	
	if is_final_phase:
		if next_button:
			next_button.visible = false
		if finish_button:
			finish_button.visible = true
			finish_button.disabled = not can_finish
	else:
		if next_button:
			next_button.visible = true
			next_button.disabled = not can_go_forward
		if finish_button:
			finish_button.visible = false

func _on_captain_created(captain_data: Dictionary) -> void:
	"""Handle captain creation"""
	print("CampaignCreationUI: Captain created: ", captain_data.get("name", "Unknown"))
	coordinator.update_captain_state(captain_data)

func _on_captain_data_updated(captain_data: Dictionary) -> void:
	"""Handle captain data updates"""
	coordinator.update_captain_state(captain_data)

func _on_crew_setup_complete(crew_data: Dictionary) -> void:
	"""Handle crew setup completion"""
	print("CampaignCreationUI: Crew setup complete")
	coordinator.update_crew_state(crew_data)

func _on_crew_data_complete(crew_data: Dictionary) -> void:
	"""Handle crew data completion"""
	coordinator.update_crew_state(crew_data)

func _on_victory_conditions_updated(victory_data: Dictionary) -> void:
	"""Handle victory conditions updates"""
	coordinator.update_victory_conditions_state(victory_data)

func _on_equipment_data_changed(equipment_data: Dictionary) -> void:
	"""Handle equipment data changes"""
	coordinator.update_equipment_state(equipment_data)

func _on_ship_data_changed(ship_data: Dictionary) -> void:
	"""Handle ship data changes"""
	coordinator.update_ship_state(ship_data)

func _on_campaign_config_data_complete(data: Dictionary) -> void:
	"""Handle campaign config data completion with deduplication safety"""
	state_manager.update_campaign_data({"config": data})
	coordinator.unified_campaign_state["campaign_config"] = data
	print("Config data updated with victory conditions: ", data.get("victory_conditions", {}))

func _on_victory_conditions_changed(conditions: Dictionary) -> void:
	"""Handle victory conditions changes with deduplication safety"""
	var config: Dictionary = coordinator.unified_campaign_state.get("campaign_config", {})
	config["victory_conditions"] = conditions
	state_manager.update_campaign_data({"config": config})
	coordinator.unified_campaign_state["campaign_config"]["victory_conditions"] = conditions
	print("Victory conditions updated: ", conditions)

func _show_validation_errors(errors: Array) -> void:
	"""Show validation errors to the user with navigation hints"""
	if errors.is_empty():
		return

	# Build error content with panel hints
	var has_navigable_errors = false
	for error in errors:
		if VALIDATION_ERROR_PHASES.has(error):
			has_navigable_errors = true
			break

	# Create dialog on first use, reuse thereafter to prevent exclusive window conflicts
	if _validation_error_dialog == null:
		_validation_error_dialog = AcceptDialog.new()
		_validation_error_dialog.title = "Validation Errors"
		add_child(_validation_error_dialog)

	# Clear any previous custom content
	for child in _validation_error_dialog.get_children():
		if child is VBoxContainer:
			child.queue_free()

	if has_navigable_errors:
		# Create custom content with navigation buttons
		var content = VBoxContainer.new()
		content.add_theme_constant_override("separation", 12)

		var header_label = Label.new()
		header_label.text = "Please fix the following issues:"
		header_label.add_theme_font_size_override("font_size", 14)
		content.add_child(header_label)

		for error in errors:
			var error_row = HBoxContainer.new()
			error_row.add_theme_constant_override("separation", 8)

			var error_label = Label.new()
			error_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

			# Check if this error has a navigable panel
			if VALIDATION_ERROR_PHASES.has(error):
				var target_phase = VALIDATION_ERROR_PHASES[error]
				var panel_name = PHASE_DISPLAY_NAMES.get(target_phase, "Unknown")
				error_label.text = "• " + error + " (" + panel_name + " panel)"

				var go_button = Button.new()
				go_button.text = "Go to Panel"
				go_button.custom_minimum_size = Vector2(100, 32)
				go_button.pressed.connect(_navigate_to_validation_error_panel.bind(target_phase))
				error_row.add_child(error_label)
				error_row.add_child(go_button)
			else:
				error_label.text = "• " + error
				error_row.add_child(error_label)

			content.add_child(error_row)

		_validation_error_dialog.add_child(content)
		_validation_error_dialog.dialog_text = ""
		_validation_error_dialog.min_size = Vector2(450, 0)
	else:
		# Simple text display for non-navigable errors
		var error_text = "Please fix the following issues:\n"
		for error in errors:
			error_text += "• " + error + "\n"
		_validation_error_dialog.dialog_text = error_text.strip_edges()

	_validation_error_dialog.popup_centered()

func _navigate_to_validation_error_panel(target_phase: CampaignStateManager.Phase) -> void:
	"""Navigate to the panel that needs fixing and close the error dialog"""
	print("CampaignCreationUI: Navigating to panel for validation fix: %s" % target_phase)

	# Close the validation dialog
	if _validation_error_dialog:
		_validation_error_dialog.hide()

	# Update state manager to allow navigation to the target phase
	if state_manager:
		state_manager.current_phase = target_phase

	# Navigate to the target panel
	await _switch_to_phase(target_phase)

func _on_finish_pressed() -> void:
	"""Handle finish button press - Complete campaign creation"""
	print("CampaignCreationUI: Starting campaign finalization...")
	
	# Validate all campaign data
	if not _validate_campaign_completion():
		return
	
	# Compile final campaign data
	var campaign_data = _compile_final_campaign_data()
	
	# Create and save campaign
	if _create_and_save_campaign(campaign_data):
		# Emit completion signal
		campaign_creation_completed.emit(campaign_data)
		# Transition to main campaign scene
		_transition_to_campaign_scene(campaign_data)
	else:
		_show_validation_errors(["Failed to save campaign. Please try again."])

func _validate_campaign_completion() -> bool:
	"""Validate that all required campaign data is complete"""
	print("CampaignCreationUI: Validating campaign completion...")
	
	if not coordinator:
		_show_validation_errors(["Campaign coordinator not initialized"])
		return false
	
	# Get unified campaign state
	var campaign_state = coordinator.get_unified_campaign_state()
	
	# Check required components
	var errors: Array[String] = []
	
	# Validate captain
	if not campaign_state.get("captain", {}).get("is_complete", false):
		errors.append("Captain creation is not complete")
	
	# Validate crew (optional but recommended)
	var crew_data = campaign_state.get("crew", {})
	if crew_data.get("members", []).is_empty():
		print("CampaignCreationUI: Warning - No crew members created")
	
	# Validate victory conditions (now in campaign_config)
	# Victory conditions are stored as nested dictionaries - check if any condition is selected
	var victory_conditions = campaign_state.get("campaign_config", {}).get("victory_conditions", {})
	var has_victory_condition := false
	for key in victory_conditions:
		var condition_data = victory_conditions.get(key, {})
		if condition_data is Dictionary and not condition_data.is_empty():
			has_victory_condition = true
			break
	if not has_victory_condition:
		errors.append("Victory conditions are not set")
	
	# Validate ship
	if not campaign_state.get("ship", {}).get("is_complete", false):
		errors.append("Ship assignment is not complete")
	
	if not errors.is_empty():
		_show_validation_errors(errors)
		return false
	
	print("CampaignCreationUI: Campaign validation passed")
	return true

func _compile_final_campaign_data() -> Dictionary:
	"""Compile all campaign data into final structure"""
	print("CampaignCreationUI: Compiling final campaign data...")
	
	var campaign_data = coordinator.get_unified_campaign_state()
	
	# Add metadata
	campaign_data["creation_metadata"] = {
		"created_at": Time.get_datetime_string_from_system(),
		"version": "1.0.0",
		"game_mode": "Five Parsecs From Home",
		"creator": "Campaign Creation System"
	}
	
	# Ensure campaign has a name
	var campaign_name = campaign_data.get("campaign_config", {}).get("campaign_name", "")
	if campaign_name.is_empty():
		campaign_name = "Five Parsecs Campaign " + Time.get_datetime_string_from_system()
		campaign_data["campaign_name"] = campaign_name
	
	print("CampaignCreationUI: Campaign data compiled - %s" % campaign_name)
	return campaign_data

func _create_and_save_campaign(campaign_data: Dictionary) -> bool:
	"""Create campaign object and save to persistent storage"""
	print("CampaignCreationUI: Creating and saving campaign...")
	
	# CRITICAL FIX: Initialize VictoryConditionTracker with selected victory condition
	_initialize_victory_condition_tracker(campaign_data)
	
	# Create campaign save data structure
	var save_data = {
		"campaign_data": campaign_data,
		"save_version": "1.0.0",
		"game_version": "Five Parsecs Campaign Manager 1.0",
		"save_timestamp": Time.get_unix_time_from_system()
	}
	
	# Generate save file name
	var campaign_name = campaign_data.get("campaign_name", "UnnamedCampaign")
	var save_filename = campaign_name.to_lower().replace(" ", "_") + ".json"
	var save_path = "user://campaigns/" + save_filename
	
	# Ensure campaigns directory exists
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("campaigns"):
		dir.make_dir("campaigns")
	
	# Save campaign data
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if not file:
		push_error("CampaignCreationUI: Failed to open save file: " + save_path)
		return false
	
	var json_string = JSON.stringify(save_data, "\t")
	file.store_string(json_string)
	file.close()
	
	print("CampaignCreationUI: Campaign saved to: " + save_path)
	return true

func _initialize_victory_condition_tracker(campaign_data: Dictionary) -> void:
	"""Initialize VictoryConditionTracker with selected victory conditions"""
	# Get victory conditions from config - support both "campaign_config" (coordinator) and "config" (state_manager) keys
	var config = campaign_data.get("campaign_config", campaign_data.get("config", {}))
	var victory_conditions = config.get("victory_conditions", {})
	var story_track_enabled = campaign_data.get("story_track_enabled", false)

	print("CampaignCreationUI: Initializing VictoryConditionTracker with %d conditions" % victory_conditions.size())

	# Store victory conditions in GameStateManager (primary storage)
	if GameStateManager and GameStateManager.has_method("set_victory_conditions"):
		GameStateManager.set_victory_conditions(victory_conditions)
		print("CampaignCreationUI: Victory conditions stored in GameStateManager")

	# Also store in GameState meta for legacy compatibility
	if AutoloadManager:
		var game_state = AutoloadManager.get_autoload_safe("GameState")
		if game_state:
			game_state.set_meta("victory_conditions", victory_conditions)
			game_state.set_meta("story_track_enabled", story_track_enabled)
			print("CampaignCreationUI: Victory conditions also stored in GameState meta")
		else:
			print("CampaignCreationUI: Warning - GameState not available for victory condition storage")
	else:
		print("CampaignCreationUI: Warning - AutoloadManager not available for victory condition storage")

func _transition_to_campaign_scene(data: Dictionary) -> void:
	"""Transition to the main campaign management screen with enhanced safety
	SPRINT 26.23: Handles both new result format (with 'campaign' Resource) and legacy Dictionary format"""

	# SPRINT 26.23: Detect format - new has "campaign" key with Resource, legacy is raw dict
	var campaign_resource = data.get("campaign") if data.has("campaign") else null
	var save_path = data.get("save_path", "")
	var raw_data = data.get("raw_data", data) if data.has("campaign") else data

	# PHASE 3 FIX: Enhanced structured logging for debugging
	print("=== CAMPAIGN TRANSITION DEBUG ===")
	if campaign_resource:
		print("Campaign resource type: %s" % campaign_resource.get_class())
		print("Campaign name: %s" % (campaign_resource.campaign_name if "campaign_name" in campaign_resource else "Unknown"))
		print("Save path: %s" % save_path)
	else:
		# Legacy mode - no resource, using raw dictionary
		print("Legacy mode: No campaign resource, using raw dictionary")
		print("Campaign name: %s" % raw_data.get("campaign_name", raw_data.get("name", "Unknown")))
	print("Raw data keys: %s" % str(raw_data.keys()))
	print("================================")

	# SPRINT 26.23: For new format, validate campaign resource; for legacy, validate raw_data
	if data.has("campaign") and not campaign_resource:
		push_error("CampaignCreationUI: No campaign resource - cannot transition")
		_show_transition_error("Campaign resource is missing. Please try creating the campaign again.")
		return

	if raw_data.is_empty():
		push_error("CampaignCreationUI: Empty campaign data - cannot transition")
		_show_transition_error("Campaign data is missing. Please try creating the campaign again.")
		return

	# PHASE 3 FIX: Log validation success
	print("✅ Campaign data validation successful")

	# Validate AutoloadManager availability
	if not AutoloadManager:
		push_warning("CampaignCreationUI: AutoloadManager not available, proceeding without state storage")
	else:
		# SPRINT 26.23: Store campaign RESOURCE if available, otherwise store dictionary (legacy)
		var game_state = AutoloadManager.get_autoload_safe("GameState")
		if game_state:
			if campaign_resource:
				# New path: Store the finalized resource for MainCampaignScene
				game_state.set_meta("pending_campaign_resource", campaign_resource)
				game_state.set_meta("pending_campaign_save_path", save_path)
				game_state.current_campaign = campaign_resource
				# Note: campaign_loaded signal emitted automatically by current_campaign setter
				print("CampaignCreationUI: Campaign resource stored in GameState meta and current_campaign")
			else:
				# Legacy path: Store raw dictionary
				game_state.set_meta("pending_campaign_data", raw_data)
				game_state.current_campaign = raw_data
				# Note: campaign_loaded signal emitted automatically by current_campaign setter
				print("CampaignCreationUI: Legacy - Campaign data stored in GameState meta")

			# PHASE 3 FIX: Auto-save the newly created campaign
			var game_state_manager = AutoloadManager.get_autoload_safe("GameStateManager")
			if game_state_manager and game_state_manager.has_method("save_campaign"):
				var save_result = game_state_manager.save_campaign()
				if save_result:
					print("CampaignCreationUI: Campaign auto-saved successfully")
				else:
					push_warning("CampaignCreationUI: Campaign auto-save failed (non-critical)")
			else:
				push_warning("CampaignCreationUI: GameStateManager not available for auto-save")
		else:
			push_warning("CampaignCreationUI: GameState autoload not available")
	
	# PHASE 3 FIX: Log pre-transition state
	print("📊 Pre-transition checks complete - initiating scene transition")

	# Define scene transition candidates in order of preference
	var scene_candidates = [
		"res://src/scenes/campaign/CampaignMainScreen.tscn",
		"res://src/ui/screens/campaign/MainCampaignScene.tscn",
		"res://src/scenes/campaign/MainCampaignScene.tscn",
		"res://src/ui/screens/mainmenu/MainMenu.tscn"
	]

	# Try each scene candidate
	var transition_successful = false
	for scene_path in scene_candidates:
		if ResourceLoader.exists(scene_path):
			# PHASE 3 FIX: Enhanced transition logging
			print("✅ Scene found: %s" % scene_path)
			print("🚀 Initiating transition to campaign dashboard...")

			# Show success dialog before transitioning if not going to main menu
			if not scene_path.ends_with("MainMenu.tscn"):
				_show_campaign_success_dialog(raw_data, scene_path)
			else:
				# Direct transition to main menu as fallback
				print("⚠️ Fallback: Transitioning to main menu")
				get_tree().change_scene_to_file(scene_path)

			transition_successful = true
			print("✅ Transition initiated successfully")
			break
	
	# If all scenes failed, show error
	if not transition_successful:
		push_error("CampaignCreationUI: No valid scene found for transition")
		_show_critical_error("Failed to transition to campaign scene. Please restart the application.")

func _show_campaign_success_dialog(campaign_data: Dictionary, target_scene: String) -> void:
	"""Show success dialog before transitioning to campaign scene"""
	# CRASH FIX: Ensure any existing dialogs are closed first to prevent exclusive window conflict
	if _validation_error_dialog and is_instance_valid(_validation_error_dialog):
		_validation_error_dialog.hide()
		_validation_error_dialog.queue_free()
		_validation_error_dialog = null

	var campaign_name = campaign_data.get("campaign_name", "Unnamed Campaign")

	# Create success dialog
	var success_dialog = AcceptDialog.new()
	success_dialog.title = "Campaign Created Successfully!"
	# PHASE 3 FIX: Enhanced dialog with first-time dashboard hint
	success_dialog.dialog_text = "🎉 Campaign '%s' has been created successfully!\n\n📊 The Campaign Dashboard is your mission control center:\n• Track crew status and resources\n• Manage equipment and ship\n• Generate missions and progress through campaign turns\n\nYou will now be taken to the dashboard to start playing!" % campaign_name
	success_dialog.add_cancel_button("Stay Here")
	
	# Configure dialog appearance
	success_dialog.min_size = Vector2(400, 200)
	
	# Add dialog to scene
	add_child(success_dialog)
	
	# Connect signals for dialog response
	success_dialog.confirmed.connect(func():
		print("CampaignCreationUI: User confirmed transition to campaign scene")
		success_dialog.queue_free()
		get_tree().change_scene_to_file(target_scene)
	)
	
	success_dialog.canceled.connect(func():
		print("CampaignCreationUI: User chose to stay in campaign creation")
		success_dialog.queue_free()
		_show_campaign_options_dialog(campaign_data)
	)
	
	# Show dialog
	success_dialog.popup_centered()
	print("CampaignCreationUI: Success dialog displayed for campaign: %s" % campaign_name)

func _show_campaign_options_dialog(campaign_data: Dictionary) -> void:
	"""Show options dialog when user chooses to stay after campaign creation"""
	var options_dialog = ConfirmationDialog.new()
	options_dialog.title = "Campaign Options"
	options_dialog.dialog_text = "Your campaign has been saved successfully.\n\nWhat would you like to do next?"
	
	# Add custom buttons
	options_dialog.add_button("Create Another Campaign", false, "create_another")
	options_dialog.add_button("Go to Main Menu", false, "main_menu")
	options_dialog.get_ok_button().text = "Load Campaign"
	
	# Configure dialog
	options_dialog.min_size = Vector2(350, 150)
	add_child(options_dialog)
	
	# Connect signals
	options_dialog.confirmed.connect(func():
		print("CampaignCreationUI: Loading campaign")
		options_dialog.queue_free()
		_transition_to_campaign_scene(campaign_data)
	)
	
	options_dialog.canceled.connect(func():
		print("CampaignCreationUI: Canceling options dialog")
		options_dialog.queue_free()
	)
	
	options_dialog.custom_action.connect(func(action: String):
		options_dialog.queue_free()
		match action:
			"create_another":
				print("CampaignCreationUI: Creating another campaign")
				_restart_campaign_creation()
			"main_menu":
				print("CampaignCreationUI: Going to main menu")
				get_tree().change_scene_to_file("res://src/ui/screens/mainmenu/MainMenu.tscn")
	)
	
	# Show dialog
	options_dialog.popup_centered()

func _show_transition_error(error_msg: String) -> void:
	"""PHASE 1 FIX: Show transition error with recovery options"""
	push_error("CampaignCreationUI: Transition error - %s" % error_msg)

	var dialog = AcceptDialog.new()
	dialog.title = "Transition Error"
	dialog.dialog_text = "Failed to start campaign:\n\n%s\n\n✅ Your campaign has been saved successfully.\n📁 You can load it from the main menu." % error_msg

	# Add return to menu button
	dialog.add_cancel_button("Return to Menu")

	# Configure dialog
	dialog.min_size = Vector2(400, 200)
	add_child(dialog)

	# Connect signals
	dialog.confirmed.connect(func():
		print("CampaignCreationUI: User acknowledged transition error")
		dialog.queue_free()
	)

	dialog.canceled.connect(func():
		print("CampaignCreationUI: Returning to main menu after transition error")
		dialog.queue_free()
		get_tree().change_scene_to_file("res://src/ui/screens/mainmenu/MainMenu.tscn")
	)

	# Show dialog
	dialog.popup_centered()

# PHASE 3 INTEGRATION: Initialize coordinator and panel management
func _initialize_coordinator() -> void:
	"""Initialize the campaign coordinator"""
	coordinator = CampaignCoordinator.new()
	state_manager = coordinator.state_manager
	security_validator = FiveParsecsSecurityValidator.new()
	persistence_manager = CampaignPersistence.new()
	finalization_service = CampaignFinalizationService.new()
	
	# Connect to navigation updates for responsive button states
	if coordinator.has_signal("navigation_updated"):
		coordinator.navigation_updated.connect(_on_navigation_updated)
	
	# Connect coordinator signals
	coordinator.equipment_state_updated.connect(_on_coordinator_equipment_updated)
	coordinator.ship_state_updated.connect(_on_coordinator_ship_updated)
	coordinator.crew_state_updated.connect(_on_coordinator_crew_updated)
	coordinator.campaign_data_updated.connect(_on_coordinator_campaign_updated)
	
	print("CampaignCreationUI: All components initialized successfully")

func _initialize_panel_management() -> void:
	"""Initialize panel management system"""
	print("CampaignCreationUI: Initializing panel management")
	
	# Preload critical panels
	_preload_critical_panels()

func _preload_critical_panels() -> void:
	"""Preload critical panels for better performance"""
	var critical_phases = [
		CampaignStateManager.Phase.CONFIG,
		CampaignStateManager.Phase.CREW_SETUP,
		CampaignStateManager.Phase.CAPTAIN_CREATION
	]
	
	for phase in critical_phases:
		var scene_path = panel_scenes.get(phase, "")
		if scene_path != "":
			var scene = load(scene_path)
			if scene:
				preloaded_scenes[phase] = scene
				print("CampaignCreationUI: Preloaded panel for phase: %s" % phase)

# Panel signal handlers
func _on_panel_ready() -> void:
	"""Handle panel ready signal"""
	print("CampaignCreationUI: Panel is ready")

func _on_config_updated(config_data: Dictionary) -> void:
	"""Handle configuration updates from ConfigPanel"""
	print("CampaignCreationUI: Configuration updated")
	if coordinator:
		coordinator.update_config_state(config_data)

func _on_configuration_complete(config_data: Dictionary) -> void:
	"""Handle configuration completion from ConfigPanel"""
	print("CampaignCreationUI: Configuration completed")
	if coordinator:
		coordinator.update_config_state(config_data)

func _on_campaign_name_changed(name: String) -> void:
	"""Handle campaign name changes"""
	print("CampaignCreationUI: Campaign name changed to: %s" % name)
	if coordinator:
		coordinator.update_campaign_name(name)

func _on_difficulty_changed(difficulty: int) -> void:
	"""Handle difficulty changes"""
	print("CampaignCreationUI: Difficulty changed to: %d" % difficulty)
	if coordinator:
		coordinator.update_difficulty(difficulty)

func _on_ironman_toggled(enabled: bool) -> void:
	"""Handle ironman mode toggle"""
	print("CampaignCreationUI: Ironman mode toggled: %s" % enabled)
	if coordinator:
		coordinator.update_ironman_mode(enabled)

func _on_crew_updated(crew_data: Array) -> void:
	"""Handle crew updates from CrewPanel"""
	print("CampaignCreationUI: Crew updated")
	if coordinator:
		coordinator.update_crew_state({"members": crew_data})

func _on_crew_member_added(member_data: Dictionary) -> void:
	"""Handle crew member addition"""
	print("CampaignCreationUI: Crew member added")
	if coordinator:
		coordinator.add_crew_member(member_data)

func _on_equipment_generated(equipment: Array) -> void:
	"""Handle equipment generation"""
	print("CampaignCreationUI: Equipment generated")
	if coordinator:
		coordinator.update_equipment_state({"equipment": equipment})

func _on_equipment_setup_complete(equipment_data: Dictionary) -> void:
	"""Handle equipment setup completion"""
	print("CampaignCreationUI: Equipment setup completed")
	if coordinator:
		coordinator.update_equipment_state(equipment_data)

func _on_equipment_generation_complete(equipment: Array) -> void:
	"""Handle equipment generation completion"""
	print("CampaignCreationUI: Equipment generation completed")
	if coordinator:
		coordinator.update_equipment_state({"equipment": equipment})

func _on_ship_updated(ship_data: Dictionary) -> void:
	"""Handle ship updates"""
	print("CampaignCreationUI: Ship updated")
	if coordinator:
		coordinator.update_ship_state(ship_data)

func _on_ship_setup_complete(ship_data: Dictionary) -> void:
	"""Handle ship setup completion"""
	print("CampaignCreationUI: Ship setup completed")
	if coordinator:
		coordinator.update_ship_state(ship_data)

func _on_ship_configuration_complete(ship: Dictionary) -> void:
	"""Handle ship configuration completion"""
	print("CampaignCreationUI: Ship configuration completed")
	if coordinator:
		coordinator.update_ship_state(ship)

func _on_world_generated(world_data: Dictionary) -> void:
	"""Handle world generation"""
	print("CampaignCreationUI: World generated")
	if coordinator:
		coordinator.update_world_state(world_data)

func _on_world_updated(world_data: Dictionary) -> void:
	"""Handle world updates"""
	print("CampaignCreationUI: World updated")
	if coordinator:
		coordinator.update_world_state(world_data)

func _on_world_created(world_data: Dictionary) -> void:
	"""Handle world creation"""
	print("CampaignCreationUI: World created")
	if coordinator:
		coordinator.update_world_state(world_data)

func _on_review_completed(review_data: Dictionary) -> void:
	"""Handle review completion"""
	print("CampaignCreationUI: Review completed")
	if coordinator:
		coordinator.update_review_state(review_data)

func _on_final_review_complete(review_data: Dictionary) -> void:
	"""Handle final review completion"""
	print("CampaignCreationUI: Final review completed")
	if coordinator:
		coordinator.update_review_state(review_data)

func _on_campaign_validated(validation_data: Dictionary) -> void:
	"""Handle campaign validation"""
	print("CampaignCreationUI: Campaign validated")
	if coordinator:
		coordinator.update_validation_state(validation_data)

# NEW: Bridge integration signal handlers
func _on_campaign_creation_requested_from_panel(campaign_data: Dictionary) -> void:
	"""Handle campaign creation request from FinalPanel via bridge"""
	print("CampaignCreationUI: Campaign creation requested from FinalPanel")
	# This is the actual FinalPanel button press - trigger full finalization
	_on_finish_pressed()

func _on_campaign_finalization_complete_from_panel(result: Dictionary) -> void:
	"""Handle campaign finalization completion from FinalPanel via bridge
	SPRINT 26.23: Now receives result with Campaign resource, not just raw dictionary"""
	print("CampaignCreationUI: Campaign finalization completed from FinalPanel")

	# SPRINT 26.23: Extract the finalized Campaign resource
	var campaign_resource = result.get("campaign")
	var save_path = result.get("save_path", "")

	if not campaign_resource:
		push_error("CampaignCreationUI: No campaign resource in finalization result!")
		return

	# SPRINT 26.23: Store the RESOURCE (not dictionary) for MainCampaignScene
	if AutoloadManager:
		var game_state = AutoloadManager.get_autoload_safe("GameState")
		if game_state:
			game_state.set_meta("pending_campaign_resource", campaign_resource)
			game_state.set_meta("pending_campaign_save_path", save_path)
			print("CampaignCreationUI: Stored campaign resource for MainCampaignScene transition")

	# Emit completion signal (for any listening MainCampaignScene instances)
	campaign_completion_ready.emit(result)

	# FIX: Always transition after successful finalization (removed broken auto_transition check)
	_transition_to_campaign_scene(result)

## Sprint 20.3: Handler for Create Campaign button confirmation
func _on_campaign_confirmed_from_panel() -> void:
	"""Handle campaign confirmation from FinalPanel Create Campaign button"""
	print("CampaignCreationUI: Campaign confirmed from FinalPanel - triggering finalization")
	# Trigger the same flow as pressing finish
	_on_finish_pressed()

# Coordinator signal handlers
func _on_coordinator_equipment_updated(data: Dictionary) -> void:
	"""Handle equipment state updates from coordinator"""
	print("CampaignCreationUI: Equipment state updated from coordinator")

func _on_coordinator_ship_updated(data: Dictionary) -> void:
	"""Handle ship state updates from coordinator"""
	print("CampaignCreationUI: Ship state updated from coordinator")

func _on_coordinator_crew_updated(data: Dictionary) -> void:
	"""Handle crew state updates from coordinator"""
	print("CampaignCreationUI: Crew state updated from coordinator")

func _on_coordinator_campaign_updated(data: Dictionary) -> void:
	"""Handle campaign data updates from coordinator"""
	print("CampaignCreationUI: Campaign data updated from coordinator")
	campaign_data_updated.emit(data)

# Critical error handler
func _show_critical_error(message: String) -> void:
	"""Show critical error message to user"""
	var error_label = Label.new()
	error_label.text = "CRITICAL ERROR: " + message
	error_label.add_theme_color_override("font_color", Color.RED)
	error_label.add_theme_font_size_override("font_size", 24)
	error_label.anchors_preset = Control.PRESET_CENTER
	add_child(error_label)

# SHIP PANEL TRANSITION FIX: Apply comprehensive fixes for panel transitions
func _apply_panel_transition_fixes() -> void:
	"""Apply basic panel transition fixes using built-in logic"""
	print("CampaignCreationUI: Applying panel transition fixes...")
	
	# NOTE: PanelTransitionMasterFix.gd file not found - using inline fixes
	# Apply basic transition fixes directly
	
	# Ensure content container exists
	if not content_container:
		push_warning("CampaignCreationUI: Content container not found - creating fallback")
		content_container = VBoxContainer.new()
		content_container.name = "ContentContainer"
		add_child(content_container)
	
	# Ensure transition state is clean
	_is_transitioning = false
	
	# Clear any stale panel references
	if current_panel and not is_instance_valid(current_panel):
		current_panel = null
		print("CampaignCreationUI: Cleared invalid panel reference")
	
	print("CampaignCreationUI: ✅ Applied inline panel transition fixes")
