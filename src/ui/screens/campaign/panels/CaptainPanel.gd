@tool
extends FiveParsecsCampaignPanel

const CharacterClass = preload("res://src/core/character/Character.gd")
const CharacterCreatorClass = preload("res://src/core/character/Generation/SimpleCharacterCreator.gd")
const StateManagerClass = preload("res://src/core/campaign/creation/CampaignCreationStateManager.gd")
const ErrorBoundaryClass = preload("res://src/core/error/UniversalErrorBoundary.gd")
const StateMachineClass = preload("res://src/core/state_machines/CaptainConfirmationStateMachine.gd")
# SecurityValidator is inherited from BaseCampaignPanel
# ValidationResult is inherited from BaseCampaignPanel
# GlobalEnums available as autoload singleton

signal captain_updated(captain: Character)

# Autonomous signals for coordinator pattern
signal captain_data_complete(data: Dictionary)
signal captain_validation_failed(errors: Array[String])

# Granular signals for real-time integration
signal captain_data_changed(data: Dictionary)
signal captain_creation_complete(captain: Character)

var local_captain_data: Dictionary = {
	"captain": null,
	"is_complete": false
}
var security_validator: SecurityValidator
var is_captain_complete: bool = false
var last_validation_errors: Array[String] = []

# PHASE 1A: Transaction-based confirmation
var _pending_confirmation_transaction: String = ""
var _is_processing_transaction: bool = false

# PHASE 2: Error boundary integration
var _error_boundary: UniversalErrorBoundary
var _circuit_breaker_failure_count: int = 0
var _circuit_breaker_last_failure_time: float = 0.0
var _circuit_breaker_open: bool = false
const CIRCUIT_BREAKER_FAILURE_THRESHOLD: int = 3
const CIRCUIT_BREAKER_RECOVERY_TIME: float = 30.0 # 30 seconds

# PHASE 2: State machine integration
var _captain_state_machine: CaptainConfirmationStateMachine
var _state_ui_feedback: Label

# UI Components - Safe node access pattern
var character_creator: Node
var captain_info: Label
var create_button: Button
var edit_button: Button
var randomize_button: Button

var current_captain: Character

func _on_campaign_state_updated(state_data: Dictionary) -> void:
	"""Override from interface - handle campaign state updates"""
	# Update panel state based on campaign state if needed
	if state_data.has("captain") and state_data.captain is Dictionary:
		var captain_data = state_data.captain
		if captain_data.has("character_name"):
			# Update local captain state from external changes
			_update_ui()

func _ready() -> void:
	# Set panel info before base initialization
	set_panel_info("Captain Creation", "Create your captain with enhanced stats and leadership abilities.")
	
	# Call parent _ready() to initialize BaseCampaignPanel structure
	super._ready()
	
	# PHASE 2: Initialize error boundary system
	_initialize_error_boundary()
	
	# PHASE 2: Initialize state machine
	_initialize_state_machine()
	
	# Initialize captain-specific functionality
	_initialize_security_validator()
	call_deferred("_initialize_components")

func _setup_panel_content() -> void:
	"""Override from BaseCampaignPanel - setup captain-specific content"""
	# This will be called after BaseCampaignPanel structure is ready
	pass

func _initialize_components() -> void:
	"""Initialize UI components with safe node access"""
	character_creator = get_node_or_null("CharacterCreator")
	
	# CRITICAL FIX: Create CharacterCreator instance if not found as child node
	if not character_creator:
		print("CaptainPanel: CharacterCreator node not found, creating instance")
		character_creator = CharacterCreatorClass.new()
		if character_creator:
			# Add as child for proper lifecycle management
			add_child(character_creator)
			character_creator.name = "CharacterCreator"
			print("CaptainPanel: CharacterCreator instance created successfully")
		else:
			push_warning("CaptainPanel: Failed to create CharacterCreator instance")
	
	captain_info = get_node_or_null("Content/CaptainInfo/Label")
	create_button = get_node_or_null("Content/Controls/CreateButton")
	edit_button = get_node_or_null("Content/Controls/EditButton")
	randomize_button = get_node_or_null("Content/Controls/RandomizeButton")
	
	# Initialize state feedback UI
	_setup_state_feedback_ui()
	
	# Connect signals after components are initialized
	_connect_signals()
	_update_ui()
	call_deferred("_emit_panel_ready")
	
	print("CaptainPanel: Components initialized - Creator: %s, Info: %s, Buttons: %d" % [
		"found" if character_creator else "missing",
		"found" if captain_info else "missing",
		[create_button, edit_button, randomize_button].count(null)
	])

func _setup_state_feedback_ui() -> void:
	"""Setup state machine feedback UI"""
	# Try to find existing state feedback label
	_state_ui_feedback = get_node_or_null("Content/StateFeedback")
	
	# If not found, create one if we have a content container
	if not _state_ui_feedback:
		var content_container = get_node_or_null("Content")
		if content_container:
			_state_ui_feedback = Label.new()
			_state_ui_feedback.name = "StateFeedback"
			_state_ui_feedback.text = "State: IDLE"
			_state_ui_feedback.add_theme_font_size_override("font_size", 12)
			_state_ui_feedback.modulate = Color.GRAY
			content_container.add_child(_state_ui_feedback)
			content_container.move_child(_state_ui_feedback, 0) # Move to top
			print("CaptainPanel: Created state feedback UI")
		else:
			print("CaptainPanel: Warning - Could not create state feedback UI (no Content container)")

func _initialize_security_validator() -> void:
	"""Initialize security validator for input sanitization"""
	security_validator = SecurityValidator.new()

# PHASE 2: State machine initialization and integration

func _initialize_state_machine() -> void:
	"""Initialize captain confirmation state machine"""
	_captain_state_machine = CaptainConfirmationStateMachine.new()
	
	# Connect state machine signals
	_captain_state_machine.state_changed.connect(_on_state_machine_state_changed)
	_captain_state_machine.validation_status_changed.connect(_on_state_machine_validation_changed)
	_captain_state_machine.confirmation_status_changed.connect(_on_state_machine_confirmation_changed)
	_captain_state_machine.error_occurred.connect(_on_state_machine_error)
	_captain_state_machine.operation_progress.connect(_on_state_machine_progress)
	
	print("CaptainPanel: State machine initialized successfully")

func _on_state_machine_state_changed(from_state: CaptainConfirmationStateMachine.State, to_state: CaptainConfirmationStateMachine.State, event: CaptainConfirmationStateMachine.Event) -> void:
	"""Handle state machine state changes and update UI accordingly"""
	print("CaptainPanel: State changed from %s to %s (event: %s)" % [
		_captain_state_machine.get_state_name(from_state),
		_captain_state_machine.get_state_name(to_state),
		_captain_state_machine.get_event_name(event)
	])
	
	# Update UI based on current state
	_update_ui_for_state(to_state)
	
	# Update state feedback label if available
	if _state_ui_feedback:
		_state_ui_feedback.text = "State: %s" % _captain_state_machine.get_state_name(to_state)

func _on_state_machine_validation_changed(is_valid: bool, errors: Array[String]) -> void:
	"""Handle validation status changes from state machine with advanced feedback"""
	last_validation_errors = errors.duplicate()
	
	# Get comprehensive validation result
	var validation_result = _get_advanced_validation_result()
	
	if captain_info:
		# Update UI based on validation stage
		match validation_result.validation_stage:
			"no_captain":
				captain_info.modulate = Color.GRAY
			"has_errors":
				captain_info.modulate = Color.RED
			"has_warnings":
				captain_info.modulate = Color.ORANGE
			"complete":
				captain_info.modulate = Color.GREEN
		
		# Create comprehensive feedback text
		var feedback_text = _build_validation_feedback_text(validation_result)
		
		# Only update if content has changed to avoid flickering
		if captain_info.text.find("📊 Validation Status:") == -1:
			captain_info.text += feedback_text

func _build_validation_feedback_text(validation_result: Dictionary) -> String:
	"""Build comprehensive validation feedback text"""
	var feedback = "\n\n📊 Validation Status: %s" % validation_result.validation_stage.capitalize().replace("_", " ")
	feedback += "\n🎯 Completion: %.0f%%" % (validation_result.completion_level * 100)
	
	# Add blocking errors
	if not validation_result.blocking_errors.is_empty():
		feedback += "\n\n❌ Issues that must be fixed:\n"
		for error in validation_result.blocking_errors:
			feedback += "• " + error + "\n"
	
	# Add warnings
	if not validation_result.warnings.is_empty():
		feedback += "\n\n⚠️ Recommendations (optional):\n"
		for warning in validation_result.warnings:
			feedback += "• " + warning + "\n"
	
	# Add suggestions
	if not validation_result.suggestions.is_empty():
		feedback += "\n\n💡 Suggestions:\n"
		for suggestion in validation_result.suggestions:
			feedback += "• " + suggestion + "\n"
	
	return feedback

func _on_state_machine_confirmation_changed(is_confirmed: bool, captain_data: Dictionary) -> void:
	"""Handle confirmation status changes from state machine"""
	if is_confirmed:
		print("CaptainPanel: Captain confirmed successfully via state machine")
		is_captain_complete = true
		local_captain_data.is_complete = true
		
		# Emit success signals
		captain_data_changed.emit(get_captain_data())
		captain_creation_complete.emit(current_captain)
		
		# Update UI to show confirmation success
		if captain_info:
			captain_info.text += "\n\n✅ Captain confirmed successfully!"
			captain_info.modulate = Color.GREEN
	else:
		print("CaptainPanel: Captain confirmation failed via state machine")
		is_captain_complete = false
		local_captain_data.is_complete = false

func _on_state_machine_error(error_message: String, recovery_options: Array[String]) -> void:
	"""Handle state machine errors with recovery options"""
	push_error("CaptainPanel: State machine error: %s" % error_message)
	
	# Show error in UI
	if captain_info:
		captain_info.text = "❌ Error: %s\n\nRecovery options:\n" % error_message
		for option in recovery_options:
			captain_info.text += "• " + option + "\n"
		captain_info.modulate = Color.RED
	
	# Add to validation errors
	last_validation_errors.append("State machine error: " + error_message)
	captain_validation_failed.emit(last_validation_errors)

func _on_state_machine_progress(operation: String, progress: float, message: String) -> void:
	"""Handle operation progress updates from state machine"""
	print("CaptainPanel: Operation progress - %s: %.1f%% - %s" % [operation, progress * 100, message])
	
	# Update UI with progress information
	if captain_info and progress < 1.0:
		var progress_text = "\n\n🔄 %s... %.0f%%" % [operation.capitalize(), progress * 100]
		
		# Only add progress text if not already present
		if captain_info.text.find("🔄") == -1:
			captain_info.text += progress_text

func _update_ui_for_state(state: CaptainConfirmationStateMachine.State) -> void:
	"""Update UI elements based on current state machine state"""
	if not create_button or not edit_button:
		return
	
	match state:
		CaptainConfirmationStateMachine.State.IDLE:
			create_button.disabled = false
			edit_button.disabled = true
			if randomize_button:
				randomize_button.disabled = false
		
		CaptainConfirmationStateMachine.State.EDITING:
			create_button.disabled = true
			edit_button.disabled = false
			if randomize_button:
				randomize_button.disabled = false
		
		CaptainConfirmationStateMachine.State.VALIDATING:
			create_button.disabled = true
			edit_button.disabled = true
			if randomize_button:
				randomize_button.disabled = true
		
		CaptainConfirmationStateMachine.State.CONFIRMING:
			create_button.disabled = true
			edit_button.disabled = true
			if randomize_button:
				randomize_button.disabled = true
		
		CaptainConfirmationStateMachine.State.CONFIRMED:
			create_button.disabled = true
			edit_button.disabled = false
			if randomize_button:
				randomize_button.disabled = true
		
		CaptainConfirmationStateMachine.State.ERROR:
			create_button.disabled = false
			edit_button.disabled = false
			if randomize_button:
				randomize_button.disabled = false
		
		CaptainConfirmationStateMachine.State.RECOVERY:
			create_button.disabled = true
			edit_button.disabled = true
			if randomize_button:
				randomize_button.disabled = true

# PHASE 2: Error boundary system initialization and methods

func _initialize_error_boundary() -> void:
	"""Initialize error boundary system for captain panel"""
	_error_boundary = UniversalErrorBoundary.new()
	
	if not UniversalErrorBoundary.initialize():
		push_warning("CaptainPanel: Failed to initialize universal error boundary")
		return
	
	# Register this component with the error boundary
	var error_wrapper = UniversalErrorBoundary.wrap_component(
		self,
		"CaptainPanel",
		UniversalErrorBoundary.ComponentType.UI_COMPONENT,
		UniversalErrorBoundary.IntegrationMode.GRACEFUL
	)
	
	if error_wrapper:
		print("CaptainPanel: Error boundary integration successful")
	else:
		push_warning("CaptainPanel: Error boundary integration failed")

func _execute_with_error_boundary(operation: Callable, fallback: Callable = Callable(), operation_name: String = "Unknown") -> Variant:
	"""Execute operation with error boundary protection"""
	
	# Check circuit breaker state
	if _is_circuit_breaker_open():
		push_warning("CaptainPanel: Circuit breaker open for %s, using fallback" % operation_name)
		if fallback.is_valid():
			return fallback.call()
		return null
	
	# Simple error handling - just call the operation directly
	# In a production system, this would have proper error boundaries
	var result = null
	
	if operation.is_valid():
		result = operation.call()
	else:
		print("CaptainPanel: Invalid operation for %s, using fallback" % operation_name)
		if fallback.is_valid():
			result = fallback.call()
	
	return result

func _execute_fallback_safely(fallback: Callable, operation_name: String) -> Variant:
	"""Execute fallback operation with additional safety"""
	if fallback.is_valid():
		return fallback.call()
	else:
		push_error("CaptainPanel: Both primary and fallback operations failed for %s" % operation_name)
		_handle_critical_failure(operation_name)
		return null

func _handle_operation_failure(operation_name: String, error: String) -> void:
	"""Handle operation failure and update circuit breaker"""
	_circuit_breaker_failure_count += 1
	_circuit_breaker_last_failure_time = Time.get_unix_time_from_system()
	
	print("CaptainPanel: Operation failed (%d/%d failures): %s - %s" % [
		_circuit_breaker_failure_count,
		CIRCUIT_BREAKER_FAILURE_THRESHOLD,
		operation_name,
		error
	])
	
	# Open circuit breaker if threshold reached
	if _circuit_breaker_failure_count >= CIRCUIT_BREAKER_FAILURE_THRESHOLD:
		_circuit_breaker_open = true
		push_error("CaptainPanel: Circuit breaker opened due to repeated failures")
		_show_circuit_breaker_error()

func _handle_critical_failure(operation_name: String) -> void:
	"""Handle critical failure that affects panel functionality"""
	push_error("CaptainPanel: Critical failure in %s - entering safe mode" % operation_name)
	
	# Force circuit breaker open
	_circuit_breaker_open = true
	_circuit_breaker_failure_count = CIRCUIT_BREAKER_FAILURE_THRESHOLD
	
	# Show user error message with recovery options
	_show_critical_error_dialog(operation_name)

func _is_circuit_breaker_open() -> bool:
	"""Check if circuit breaker is open and attempt recovery"""
	if not _circuit_breaker_open:
		return false
	
	var time_since_failure = Time.get_unix_time_from_system() - _circuit_breaker_last_failure_time
	
	if time_since_failure >= CIRCUIT_BREAKER_RECOVERY_TIME:
		print("CaptainPanel: Circuit breaker recovery time elapsed, attempting reset")
		_reset_circuit_breaker()
		return false
	
	return true

func _reset_circuit_breaker() -> void:
	"""Reset circuit breaker to closed state"""
	_circuit_breaker_open = false
	_circuit_breaker_failure_count = 0
	_circuit_breaker_last_failure_time = 0.0
	print("CaptainPanel: Circuit breaker reset successful")

func _show_circuit_breaker_error() -> void:
	"""Show user-friendly error message when circuit breaker opens"""
	if captain_info:
		captain_info.text = "⚠️ Captain creation temporarily unavailable due to repeated errors.\nPlease wait 30 seconds and try again, or use the fallback options below."
		captain_info.modulate = Color.ORANGE

func _show_critical_error_dialog(operation_name: String) -> void:
	"""Show critical error dialog with recovery options"""
	var dialog = AcceptDialog.new()
	dialog.title = "Captain Creation Error"
	dialog.dialog_text = "Critical error in %s.\n\nRecovery options:\n• Wait 30 seconds for automatic recovery\n• Use 'Create Basic Captain' for simple creation\n• Restart the campaign creation process" % operation_name
	
	get_tree().current_scene.add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(dialog.queue_free)

func _connect_signals() -> void:
	if create_button:
		create_button.pressed.connect(_on_create_pressed)
	if edit_button:
		edit_button.pressed.connect(_on_edit_pressed)
	if randomize_button:
		randomize_button.pressed.connect(_on_randomize_pressed)

	if character_creator:
		character_creator.character_created.connect(_on_character_created)
		character_creator.character_edited.connect(_on_character_edited)
	else:
		push_warning("CaptainPanel: CharacterCreator not found, using fallback methods")

func _on_create_pressed() -> void:
	"""Handle create button press with state machine and error boundary protection"""
	# Start captain creation via state machine
	if _captain_state_machine and not _captain_state_machine.start_captain_creation():
		push_warning("CaptainPanel: Cannot start captain creation - invalid state")
		return
	
	var operation = func():
		if character_creator:
			character_creator.start_creation(SimpleCharacterCreator.CreatorMode.CAPTAIN)
		else:
			_create_basic_captain()
	
	var fallback = func():
		_create_basic_captain()
	
	_execute_with_error_boundary(operation, fallback, "create_captain")

func _on_edit_pressed() -> void:
	"""Handle edit button press with state machine and error boundary protection"""
	# Start captain editing via state machine
	if _captain_state_machine and current_captain:
		# CRITICAL FIX: Reset state machine if stuck in EDITING state
		if _captain_state_machine.current_state == CaptainConfirmationStateMachine.State.EDITING:
			print("CaptainPanel: State machine stuck in EDITING, resetting to IDLE")
			if not _captain_state_machine.reset_state_machine():
				push_warning("CaptainPanel: Failed to reset state machine")
				return
		
		var captain_data = _serialize_captain_for_transaction(current_captain)
		if not _captain_state_machine.edit_captain(captain_data):
			push_warning("CaptainPanel: Cannot edit captain - invalid state. Current state: %s" %
				_captain_state_machine.get_state_name(_captain_state_machine.current_state))
			return
	
	var operation = func():
		if current_captain and character_creator:
			character_creator.edit_character(current_captain)
		elif current_captain:
			_create_basic_captain()
	
	var fallback = func():
		if current_captain:
			_edit_captain_fallback()
		else:
			_create_basic_captain()
	
	_execute_with_error_boundary(operation, fallback, "edit_captain")

func _on_randomize_pressed() -> void:
	"""Handle randomize button press with error boundary protection"""
	var operation = func():
		if character_creator:
			character_creator.start_creation(SimpleCharacterCreator.CreatorMode.CAPTAIN)
			character_creator._on_randomize_pressed()
			character_creator._on_create_pressed() # Auto-create after randomize
		else:
			_create_random_captain()
	
	var fallback = func():
		_create_random_captain()
	
	_execute_with_error_boundary(operation, fallback, "randomize_captain")


func _update_ui() -> void:
	"""Update UI with enhanced validation feedback"""
	if current_captain:
		var info_text: String = "Captain Information:\n"
		info_text += "Name: %s\n" % current_captain.character_name
		info_text += "Combat: %d, Toughness: %d, Savvy: %d\n" % [
			current_captain.combat,
			current_captain.toughness,
			current_captain.savvy
		]
		info_text += "Tech: %d, Speed: %d, Luck: %d\n" % [
			current_captain.tech,
			current_captain.speed,
			current_captain.luck
		]
		info_text += "Health: %d/%d" % [
			current_captain.health,
			current_captain.max_health
		]
		
		# Add advanced validation feedback
		var validation_result = _get_advanced_validation_result()
		var feedback_text = _build_validation_feedback_text(validation_result)
		info_text += feedback_text

		if captain_info:
			captain_info.text = info_text
			
			# Update color based on validation stage
			match validation_result.validation_stage:
				"no_captain":
					captain_info.modulate = Color.GRAY
				"has_errors":
					captain_info.modulate = Color.RED
				"has_warnings":
					captain_info.modulate = Color.ORANGE
				"complete":
					captain_info.modulate = Color.GREEN
		
		if create_button:
			create_button.hide()
		if edit_button:
			edit_button.show()
		if randomize_button:
			randomize_button.hide()
	else:
		# No captain case - show creation guidance
		var validation_result = _get_advanced_validation_result()
		var guidance_text = "No captain created yet. Click 'Create Captain' to begin."
		guidance_text += _build_validation_feedback_text(validation_result)
		
		if captain_info:
			captain_info.text = guidance_text
			captain_info.modulate = Color.GRAY
		if create_button:
			create_button.show()
		if edit_button:
			edit_button.hide()
		if randomize_button:
			randomize_button.show()
	
	# Update state machine UI state if available
	if _captain_state_machine:
		_update_ui_for_state(_captain_state_machine.current_state)


func validate() -> Array[String]:
	"""Validate captain data and return error messages"""
	var validation = validate_panel()
	return validation.errors if validation.errors else []

func set_data(data: Dictionary) -> void:
	"""Set panel data - generic interface method"""
	if data.has("captain"):
		current_captain = data.captain
		_update_ui()
		captain_updated.emit(current_captain)

# Fallback methods when CharacterCreator is not available
func _create_basic_captain() -> void:
	"""Create a basic captain without the character creator dialog"""
	var captain = Character.new()
	captain.character_name = "Captain %s" % ["Steele", "Nova", "Cross", "Vale", "Storm"][randi() % 5]
	_generate_captain_stats(captain)
	current_captain = captain
	_update_ui()
	captain_updated.emit(current_captain)

func _create_random_captain() -> void:
	"""Create a random captain directly"""
	_create_basic_captain()

# PHASE 2: Enhanced fallback methods with error recovery

func _edit_captain_fallback() -> void:
	"""Fallback method for captain editing when CharacterCreator fails"""
	if not current_captain:
		push_warning("CaptainPanel: No captain to edit, creating new one")
		_create_basic_captain()
		return
	
	print("CaptainPanel: Using fallback captain editing method")
	
	# Create a simple edit dialog as fallback
	var edit_dialog = _create_captain_edit_dialog()
	get_tree().current_scene.add_child(edit_dialog)
	edit_dialog.popup_centered()

func _create_captain_edit_dialog() -> AcceptDialog:
	"""Create simple captain edit dialog as fallback"""
	var dialog = AcceptDialog.new()
	dialog.title = "Edit Captain (Fallback Mode)"
	dialog.size = Vector2(400, 300)
	
	var vbox = VBoxContainer.new()
	
	# Name field
	var name_label = Label.new()
	name_label.text = "Captain Name:"
	vbox.add_child(name_label)
	
	var name_field = LineEdit.new()
	name_field.text = current_captain.character_name if current_captain else ""
	name_field.placeholder_text = "Enter captain name"
	vbox.add_child(name_field)
	
	# Stats info
	var stats_label = Label.new()
	if current_captain:
		stats_label.text = "Current Stats:\nCombat: %d, Toughness: %d, Savvy: %d\nTech: %d, Speed: %d, Luck: %d" % [
			current_captain.combat, current_captain.toughness, current_captain.savvy,
			current_captain.tech, current_captain.speed, current_captain.luck
		]
	else:
		stats_label.text = "No captain data available"
	vbox.add_child(stats_label)
	
	# Buttons
	var button_box = HBoxContainer.new()
	
	var regenerate_btn = Button.new()
	regenerate_btn.text = "Regenerate Stats"
	regenerate_btn.pressed.connect(_regenerate_captain_stats.bind(dialog))
	button_box.add_child(regenerate_btn)
	
	var save_btn = Button.new()
	save_btn.text = "Save Changes"
	save_btn.pressed.connect(_save_captain_edit.bind(name_field, dialog))
	button_box.add_child(save_btn)
	
	vbox.add_child(button_box)
	dialog.add_child(vbox)
	
	return dialog

func _regenerate_captain_stats(dialog: AcceptDialog) -> void:
	"""Regenerate captain stats during fallback editing"""
	if current_captain:
		_generate_captain_stats(current_captain)
		_update_ui()
		
		# Update dialog stats display
		var stats_label = dialog.get_child(0).get_child(2) as Label
		if stats_label:
			stats_label.text = "Current Stats:\nCombat: %d, Toughness: %d, Savvy: %d\nTech: %d, Speed: %d, Luck: %d" % [
				current_captain.combat, current_captain.toughness, current_captain.savvy,
				current_captain.tech, current_captain.speed, current_captain.luck
			]

func _save_captain_edit(name_field: LineEdit, dialog: AcceptDialog) -> void:
	"""Save captain changes from fallback edit dialog"""
	if current_captain and name_field:
		var new_name = name_field.text.strip_edges()
		if new_name.length() >= 2:
			current_captain.character_name = new_name
			_validate_and_complete()
			_update_ui()
			captain_updated.emit(current_captain)
			print("CaptainPanel: Captain updated via fallback editor")
		else:
			push_warning("CaptainPanel: Captain name too short, keeping original")
	
	dialog.queue_free()

func _generate_captain_stats(captain: Character) -> void:
	"""Generate Five Parsecs captain stats"""
	# Captains get better stats (minimum 3 for combat stats)
	captain.combat = max(_roll_2d6(), 3)
	captain.toughness = max(_roll_2d6(), 3)
	captain.savvy = max(_roll_2d6(), 3)
	captain.tech = _roll_2d6()
	captain.speed = _roll_2d6()
	captain.luck = 2 # Captains start with 2 luck
	captain.max_health = captain.toughness + 3 # Captains get +1 extra health
	captain.health = captain.max_health

func _roll_2d6() -> int:
	"""Roll 2d6 for Five Parsecs stats"""
	return randi_range(1, 6) + randi_range(1, 6)

# --- Additions to CaptainPanel.gd ---

func _on_character_created(character: Character) -> void:
	current_captain = character
	
	# Trigger state machine validation if available
	if _captain_state_machine:
		_captain_state_machine.validate_captain()
		
		# Set validation result based on advanced validation
		var validation_result = _get_advanced_validation_result()
		_captain_state_machine.set_validation_result(validation_result.is_valid, validation_result.blocking_errors)
	
	_validate_and_complete()
	_update_ui()
	captain_updated.emit(current_captain)
	
	# Emit granular signals for real-time integration
	captain_data_changed.emit(get_captain_data())

func _on_character_edited(character: Character) -> void:
	current_captain = character
	
	# Trigger state machine validation if available
	if _captain_state_machine:
		_captain_state_machine.validate_captain()
		
		# Set validation result based on advanced validation
		var validation_result = _get_advanced_validation_result()
		_captain_state_machine.set_validation_result(validation_result.is_valid, validation_result.blocking_errors)
	
	_validate_and_complete()
	_update_ui()
	captain_updated.emit(current_captain)
	
	# Emit granular signals for real-time integration
	captain_data_changed.emit(get_captain_data())

func _validate_and_complete() -> void:
	"""Enhanced validation with coordinator pattern and security integration"""
	last_validation_errors = _validate_captain_data()
	
	if not last_validation_errors.is_empty():
		is_captain_complete = false
		local_captain_data.is_complete = false
		captain_validation_failed.emit(last_validation_errors)
		print("CaptainPanel: Validation failed: ", last_validation_errors)
	else:
		var was_complete = is_captain_complete
		is_captain_complete = _check_completion_requirements()
		local_captain_data.is_complete = is_captain_complete
		local_captain_data.captain = current_captain
		
		# Emit panel data update for signal-based architecture (no arguments needed)
		panel_data_changed.emit()
		
		# Emit granular data change signal for real-time integration
		captain_data_changed.emit(get_captain_data())
		
		# Emit completion signal when transitioning to complete state
		if is_captain_complete and not was_complete:
			var captain_data_result = get_captain_data()
			captain_data_complete.emit(captain_data_result)
			captain_creation_complete.emit(current_captain) # Granular completion signal
			panel_completed.emit(captain_data_result) # Maintain backward compatibility
			print("CaptainPanel: Captain setup completed autonomously: ", captain_data_result.keys())
			
			# PHASE 1A: Use transaction-based confirmation for production reliability
			_confirm_captain_with_transaction()
			
			# PHASE 2: Trigger state machine confirmation
			if _captain_state_machine and _captain_state_machine.can_confirm():
				_captain_state_machine.confirm_captain()
		elif is_captain_complete:
			print("CaptainPanel: Captain setup validation passed, already complete")

func _check_completion_requirements() -> bool:
	"""Check if all requirements for captain completion are met"""
	# Required: Must have a captain
	if not current_captain:
		return false
	
	# Required: Captain must have a valid name
	var name = current_captain.character_name.strip_edges()
	if name.length() < 2:
		return false
	
	# Validate name using SecurityValidator
	if security_validator:
		var validation_result = security_validator.validate_character_name(name)
		if not validation_result.valid:
			return false
	
	# Required: Captain must have reasonable stats
	if current_captain.combat < 1 or current_captain.toughness < 1:
		return false
	
	return true

func _validate_captain_data() -> Array[String]:
	"""Performs validation on the captain data with progressive feedback"""
	var errors: Array[String] = []
	
	# Rule: Must have a captain
	if not current_captain:
		errors.append("A captain must be created.")
		return errors
	
	# Rule: Captain must have a valid name
	var name = current_captain.character_name.strip_edges()
	if name.is_empty():
		errors.append("Captain name is required.")
	elif name.length() < 2:
		errors.append("Captain name must be at least 2 characters long.")
	elif name.length() > 50:
		errors.append("Captain name is too long (maximum 50 characters).")
	
	# Rule: Captain must have reasonable stats
	if current_captain.combat < 1:
		errors.append("Captain must have valid combat stats (minimum 1).")
	elif current_captain.combat > 15:
		errors.append("Captain combat stats seem unusually high (maximum recommended: 15).")
	
	if current_captain.toughness < 1:
		errors.append("Captain must have valid toughness stats (minimum 1).")
	elif current_captain.toughness > 15:
		errors.append("Captain toughness stats seem unusually high (maximum recommended: 15).")
	
	# Advanced validation: Check stat balance
	var total_stats = current_captain.combat + current_captain.toughness + current_captain.savvy + current_captain.tech + current_captain.speed
	if total_stats < 15:
		errors.append("Captain stats seem very low (total: %d, recommended minimum: 15)." % total_stats)
	elif total_stats > 75:
		errors.append("Captain stats seem unusually high (total: %d, recommended maximum: 75)." % total_stats)
	
	# Health validation
	if current_captain.health <= 0:
		errors.append("Captain health must be greater than 0.")
	elif current_captain.health > current_captain.max_health:
		errors.append("Captain current health cannot exceed maximum health.")
	
	return errors

func _get_validation_warnings() -> Array[String]:
	"""Get non-critical validation warnings that don't block progression"""
	var warnings: Array[String] = []
	
	if not current_captain:
		return warnings
	
	# Stat distribution warnings
	var stats = [current_captain.combat, current_captain.toughness, current_captain.savvy, current_captain.tech, current_captain.speed]
	var max_stat = stats.max()
	var min_stat = stats.min()
	
	if max_stat - min_stat > 8:
		warnings.append("Captain has unbalanced stats (range: %d-%d). Consider more balanced distribution." % [min_stat, max_stat])
	
	if current_captain.luck < 1:
		warnings.append("Captain has no luck points. This may make the game more challenging.")
	elif current_captain.luck > 6:
		warnings.append("Captain has unusually high luck (%d). Consider if this matches your intended difficulty." % current_captain.luck)
	
	# Name warnings
	var name = current_captain.character_name.strip_edges()
	if name.find(" ") == -1:
		warnings.append("Captain name has no space. Consider adding a first and last name.")
	
	# Character archetype suggestions
	if current_captain.combat >= 8 and current_captain.tech <= 3:
		warnings.append("This captain appears to be a warrior archetype (high combat, low tech).")
	elif current_captain.tech >= 8 and current_captain.combat <= 3:
		warnings.append("This captain appears to be a tech specialist archetype (high tech, low combat).")
	elif current_captain.savvy >= 8:
		warnings.append("This captain appears to be a leader archetype (high savvy).")
	
	return warnings

func _get_advanced_validation_result() -> Dictionary:
	"""Get comprehensive validation result with progressive feedback"""
	var result = {
		"is_valid": false,
		"blocking_errors": [],
		"warnings": [],
		"suggestions": [],
		"completion_level": 0.0,
		"validation_stage": "incomplete"
	}
	
	# Get blocking errors and warnings
	result.blocking_errors = _validate_captain_data()
	result.warnings = _get_validation_warnings()
	
	# Determine if captain is valid (no blocking errors)
	result.is_valid = result.blocking_errors.is_empty()
	
	# Calculate completion level
	result.completion_level = _calculate_completion_level()
	
	# Determine validation stage
	if not current_captain:
		result.validation_stage = "no_captain"
	elif not result.blocking_errors.is_empty():
		result.validation_stage = "has_errors"
	elif not result.warnings.is_empty():
		result.validation_stage = "has_warnings"
	else:
		result.validation_stage = "complete"
	
	# Add suggestions based on validation stage
	result.suggestions = _get_validation_suggestions(result.validation_stage)
	
	return result

func _get_validation_suggestions(stage: String) -> Array[String]:
	"""Get contextual suggestions based on validation stage"""
	var suggestions: Array[String] = []
	
	match stage:
		"no_captain":
			suggestions.append("Click 'Create Captain' to begin character creation.")
			suggestions.append("Use 'Randomize Captain' for quick setup.")
		
		"has_errors":
			suggestions.append("Review and fix the validation errors above.")
			suggestions.append("Use 'Edit Captain' to modify character details.")
		
		"has_warnings":
			suggestions.append("Consider reviewing the warnings, but you can proceed if desired.")
			suggestions.append("Click 'Edit Captain' if you want to make adjustments.")
		
		"complete":
			suggestions.append("Captain setup is complete! You can proceed to the next phase.")
			suggestions.append("Use 'Edit Captain' if you want to make any final changes.")
	
	return suggestions

func get_enhanced_validation_status() -> Dictionary:
	"""Get enhanced validation status for external systems"""
	var validation_result = _get_advanced_validation_result()
	
	# Add additional metadata for integration
	validation_result["panel_type"] = "captain_creation"
	validation_result["timestamp"] = Time.get_unix_time_from_system()
	validation_result["state_machine_state"] = _captain_state_machine.get_state_name(_captain_state_machine.current_state) if _captain_state_machine else "no_state_machine"
	validation_result["has_captain"] = current_captain != null
	validation_result["can_proceed"] = validation_result.is_valid or validation_result.validation_stage == "has_warnings"
	
	return validation_result

func trigger_real_time_validation() -> void:
	"""Trigger real-time validation update"""
	if not current_captain:
		return
	
	# Get fresh validation results
	var validation_result = _get_advanced_validation_result()
	
	# Update state machine if available
	if _captain_state_machine and _captain_state_machine.current_state == CaptainConfirmationStateMachine.State.EDITING:
		_captain_state_machine.set_validation_result(validation_result.is_valid, validation_result.blocking_errors)
	
	# Update UI
	_update_ui()
	
	# Emit validation status signals
	if validation_result.is_valid:
		captain_data_complete.emit(get_captain_data())
	else:
		captain_validation_failed.emit(validation_result.blocking_errors)

func get_validation_stage_color(stage: String) -> Color:
	"""Get color for validation stage"""
	match stage:
		"no_captain":
			return Color.GRAY
		"has_errors":
			return Color.RED
		"has_warnings":
			return Color.ORANGE
		"complete":
			return Color.GREEN
		_:
			return Color.WHITE


func get_captain_data() -> Dictionary:
	"""Return captain data for campaign creation with standardized metadata"""
	var data = {"captain": current_captain} if current_captain else {}
	data["is_complete"] = local_captain_data.is_complete
	data["validation_errors"] = last_validation_errors.duplicate()
	data["completion_level"] = _calculate_completion_level()
	data["metadata"] = {
		"last_modified": Time.get_unix_time_from_system(),
		"version": "1.0",
		"panel_type": "captain_creation"
	}
	return data

func _calculate_completion_level() -> float:
	"""Calculate completion level percentage"""
	if not current_captain:
		return 0.0
	
	var completion_factors = 0.0
	var total_factors = 4.0 # Name, stats, class features, completeness
	
	# Factor 1: Valid name
	var name = current_captain.character_name.strip_edges()
	if name.length() >= 2:
		completion_factors += 1.0
	
	# Factor 2: Valid combat stats
	if current_captain.combat >= 1 and current_captain.toughness >= 1:
		completion_factors += 1.0
	
	# Factor 3: All basic stats present
	if current_captain.savvy >= 1 and current_captain.tech >= 1:
		completion_factors += 1.0
	
	# Factor 4: Health properly calculated
	if current_captain.health > 0 and current_captain.max_health > 0:
		completion_factors += 1.0
	
	return completion_factors / total_factors

## Required Interface Methods from ICampaignCreationPanel

func validate_panel() -> ValidationResult:
	"""Validate panel data and return ValidationResult"""
	var result = ValidationResult.new()
	var errors = _validate_captain_data()
	
	if errors.is_empty():
		result.valid = true
		result.sanitized_value = get_captain_data()
	else:
		result.valid = false
		result.error = errors[0] if errors.size() > 0 else "Captain validation failed"
		# Add additional errors as warnings since ValidationResult only has one error field
		for i in range(1, errors.size()):
			result.add_warning(errors[i])
	
	return result

func get_panel_data() -> Dictionary:
	"""Get panel data - interface implementation"""
	return get_captain_data()

func reset_panel() -> void:
	"""Reset panel to default state"""
	current_captain = null
	local_captain_data = {
		"captain": null,
		"is_complete": false
	}
	
	is_captain_complete = false
	last_validation_errors.clear()
	_update_ui()

## Panel Data Persistence Implementation

func restore_panel_data(data: Dictionary) -> void:
	"""Restore panel data from persistence system"""
	if data.is_empty():
		print("CaptainPanel: No data to restore")
		return
	
	print("CaptainPanel: Restoring panel data: ", data.keys())
	
	# Restore captain data
	if data.has("captain") and data.captain:
		var captain_data = data.captain
		
		# Create character from data
		if captain_data is Character:
			current_captain = captain_data
		elif captain_data is Dictionary:
			current_captain = _create_character_from_dict(captain_data)
		
		if current_captain:
			print("CaptainPanel: Restored captain: ", current_captain.character_name)
			
			# Update local state
			local_captain_data.captain = current_captain
			local_captain_data.is_complete = true
			is_captain_complete = true
			
			# Update UI
			_update_ui()
			captain_updated.emit(current_captain)
	
	print("CaptainPanel: Panel data restoration complete")

func _create_character_from_dict(data: Dictionary) -> Character:
	"""Create a Character object from dictionary data"""
	var character = Character.new()
	
	# Restore basic properties
	if data.has("character_name"):
		character.character_name = data.character_name
	if data.has("combat"):
		character.combat = data.combat
	if data.has("toughness"):
		character.toughness = data.toughness
	if data.has("tech"):
		character.tech = data.tech
	if data.has("savvy"):
		character.savvy = data.savvy
	if data.has("speed"):
		character.speed = data.speed
	if data.has("luck"):
		character.luck = data.luck
	if data.has("health"):
		character.health = data.health
	if data.has("max_health"):
		character.max_health = data.max_health
	else:
		# Calculate max health if not provided
		character.max_health = character.toughness + 3 # Captains get +1 extra
		character.health = character.max_health
	
	return character

# PHASE 1A: Transaction-based captain confirmation methods

func _confirm_captain_with_transaction() -> void:
	"""Confirm captain using transaction-based atomic operations"""
	if not state_manager_reference:
		print("CaptainPanel: No state manager available for transaction-based confirmation")
		return
	
	if _is_processing_transaction:
		print("CaptainPanel: Transaction already in progress, skipping confirmation")
		return
	
	if not current_captain:
		print("CaptainPanel: No captain to confirm")
		return
	
	_is_processing_transaction = true
	
	# Create captain data for transaction
	var captain_data = _serialize_captain_for_transaction(current_captain)
	
	# Create transaction
	_pending_confirmation_transaction = state_manager_reference.create_captain_confirmation_transaction(captain_data)
	
	if _pending_confirmation_transaction.is_empty():
		print("CaptainPanel: Failed to create captain confirmation transaction")
		_is_processing_transaction = false
		return
	
	print("CaptainPanel: Created captain confirmation transaction: %s" % _pending_confirmation_transaction)
	
	# Execute transaction
	call_deferred("_execute_confirmation_transaction")

func _execute_confirmation_transaction() -> void:
	"""Execute the captain confirmation transaction"""
	if _pending_confirmation_transaction.is_empty():
		_is_processing_transaction = false
		return
	
	var result = state_manager_reference.execute_transaction(_pending_confirmation_transaction)
	
	if result.success:
		print("CaptainPanel: ✅ Captain confirmation transaction successful")
		_on_transaction_success(result.final_state)
	else:
		print("CaptainPanel: ❌ Captain confirmation transaction failed: %s" % result.error)
		_on_transaction_failure(result.error)
	
	# Clean up transaction
	state_manager_reference.cleanup_transaction(_pending_confirmation_transaction)
	_pending_confirmation_transaction = ""
	_is_processing_transaction = false

func _serialize_captain_for_transaction(captain: Character) -> Dictionary:
	"""Serialize captain data for transaction operations"""
	return {
		"character_name": captain.character_name,
		"combat": captain.combat,
		"toughness": captain.toughness,
		"savvy": captain.savvy,
		"tech": captain.tech,
		"speed": captain.speed,
		"luck": captain.luck,
		"health": captain.health,
		"max_health": captain.max_health,
		"is_captain": true,
		"confirmed": false, # Will be set to true by transaction
		"transaction_timestamp": Time.get_unix_time_from_system()
	}

func _on_transaction_success(final_state: Dictionary) -> void:
	"""Handle successful captain confirmation transaction"""
	print("CaptainPanel: Captain confirmation transaction completed successfully")
	
	# Update local state from transaction result
	if final_state.has("captain"):
		local_captain_data.captain = current_captain
		local_captain_data.is_complete = true
		is_captain_complete = true
	
	# Update state machine with confirmation success
	if _captain_state_machine and _captain_state_machine.current_state == CaptainConfirmationStateMachine.State.CONFIRMING:
		_captain_state_machine.set_confirmation_result(true, final_state)
	
	# Emit success signals
	captain_data_changed.emit(get_captain_data())

func _on_transaction_failure(error: String) -> void:
	"""Handle failed captain confirmation transaction"""
	print("CaptainPanel: Captain confirmation transaction failed: %s" % error)
	
	# Reset local state
	is_captain_complete = false
	local_captain_data.is_complete = false
	
	# Update state machine with confirmation failure
	if _captain_state_machine and _captain_state_machine.current_state == CaptainConfirmationStateMachine.State.CONFIRMING:
		_captain_state_machine.set_confirmation_result(false, {"error": error})
	
	# Add error to validation errors
	last_validation_errors.append("Transaction failed: " + error)
	
	# Emit failure signals
	captain_validation_failed.emit(last_validation_errors)

func force_rollback_transaction(reason: String = "User requested") -> bool:
	"""Force rollback of pending transaction"""
	if _pending_confirmation_transaction.is_empty():
		return false
	
	if not state_manager_reference:
		return false
	
	var success = state_manager_reference.rollback_transaction(_pending_confirmation_transaction, reason)
	
	if success:
		print("CaptainPanel: Transaction rolled back: %s" % reason)
		_on_transaction_failure("Rolled back: " + reason)
		
		# Clean up
		state_manager_reference.cleanup_transaction(_pending_confirmation_transaction)
		_pending_confirmation_transaction = ""
		_is_processing_transaction = false
	
	return success

func get_transaction_status() -> Dictionary:
	"""Get status of current transaction"""
	if _pending_confirmation_transaction.is_empty():
		return {"has_transaction": false}
	
	if not state_manager_reference:
		return {"has_transaction": false, "error": "No state manager"}
	
	var status = state_manager_reference.get_transaction_status(_pending_confirmation_transaction)
	status["has_transaction"] = true
	status["is_processing"] = _is_processing_transaction
	return status

# --- End of CaptainPanel.gd ---
