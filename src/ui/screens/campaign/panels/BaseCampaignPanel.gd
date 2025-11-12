extends Control
class_name FiveParsecsCampaignPanel

## Minimal Base Campaign Panel - Framework Bible Compliant
## Simple interface for campaign creation panels - NO Enhanced bloat
## Focuses on Five Parsecs functionality, not enterprise complexity

# Essential panel signals - keep it simple
signal panel_data_changed(data: Dictionary)
signal panel_validation_changed(is_valid: bool)
signal panel_completed(data: Dictionary)
signal validation_failed(errors: Array[String])
signal panel_ready()

# Simple panel state
var panel_title: String = ""
var panel_description: String = ""

# Coordinator/Manager references (pragmatic approach for existing architecture)
var _coordinator = null # Untyped to avoid circular dependencies
var _state_manager = null

# UI Structure - provide expected content_container
@onready var content_container: Control = null

func _ready() -> void:
	_ensure_panel_structure()
	_setup_panel_content()

func _ensure_panel_structure() -> void:
	"""Ensure the expected node structure exists for panels"""
	# Check if structure already exists
	if has_node("ContentMargin/MainContent/FormContent/FormContainer"):
		content_container = $ContentMargin/MainContent/FormContent/FormContainer
		return
	
	# Create the expected structure
	var content_margin = MarginContainer.new()
	content_margin.name = "ContentMargin"
	add_child(content_margin)
	
	var main_content = VBoxContainer.new()
	main_content.name = "MainContent"
	content_margin.add_child(main_content)
	
	var form_content = VBoxContainer.new()
	form_content.name = "FormContent"
	main_content.add_child(form_content)
	
	var form_container = VBoxContainer.new()
	form_container.name = "FormContainer"
	form_content.add_child(form_container)
	
	content_container = form_container
	print("BaseCampaignPanel: Created panel structure for %s" % get_class())

## Core Interface - Override in derived classes
func validate_panel() -> bool:
	"""Simple validation - return true if panel data is valid"""
	return true

func get_panel_data() -> Dictionary:
	"""Get panel data for campaign creation"""
	return {}

func set_panel_data(data: Dictionary) -> void:
	"""Set panel data from campaign state"""
	pass

## Panel Information
func get_panel_title() -> String:
	return panel_title

func get_panel_description() -> String:
	return panel_description

func set_panel_info(title: String, description: String) -> void:
	panel_title = title
	panel_description = description
	_update_panel_display()

func _update_panel_display() -> void:
	"""Update UI elements to reflect panel_title and panel_description"""
	# Update header title if it exists
	if has_node("ContentMargin/MainContent/Header/Title"):
		var title_label = $ContentMargin/MainContent/Header/Title
		title_label.text = panel_title
		print("BaseCampaignPanel: Updated title to '%s'" % panel_title)
	
	# Update header description if it exists
	if has_node("ContentMargin/MainContent/Header/Description"):
		var desc_label = $ContentMargin/MainContent/Header/Description
		desc_label.text = panel_description
		print("BaseCampaignPanel: Updated description to '%s'" % panel_description)

## Simple validation and completion
func _validate_and_emit_completion() -> void:
	"""Validate panel and emit appropriate signals - safe for all panels"""
	# Ensure panel is fully initialized before validation
	if not is_inside_tree():
		print("BaseCampaignPanel: Skipping validation - panel not in tree yet")
		return
		
	var is_valid = validate_panel()
	panel_validation_changed.emit(is_valid)
	
	if is_valid:
		var data = get_panel_data()
		panel_completed.emit(data)
		print("BaseCampaignPanel: Panel validation passed, emitted completion")
	else:
		var errors: Array[String] = ["Panel validation failed"]
		validation_failed.emit(errors)
		print("BaseCampaignPanel: Panel validation failed")

## Override in derived classes
func _setup_panel_content() -> void:
	"""Setup panel-specific content"""
	pass

## Helper methods for safe panel operations
func emit_data_changed() -> void:
	"""Safely emit data changed signal without validation"""
	var data = get_panel_data()
	panel_data_changed.emit(data)

func safe_validate_and_complete() -> void:
	"""Safe wrapper for validation that checks panel state first"""
	if not is_inside_tree():
		print("BaseCampaignPanel: Cannot validate - panel not ready")
		return
	_validate_and_emit_completion()

## Panel ready signal method
func emit_panel_ready() -> void:
	"""Emit panel ready signal for coordinator communication"""
	panel_ready.emit()
	print("%s: Panel ready signal emitted" % get_class())

## Coordinator Integration Methods (Phase 0: Foundation)
func set_coordinator(coord) -> void:
	"""Set coordinator reference for panel integration"""
	_coordinator = coord
	print("%s: Coordinator set" % panel_title)
	call_deferred("_on_coordinator_set") # Defer to ensure panel is ready

func set_state_manager(manager) -> void:
	"""Set state manager reference for panel integration"""
	_state_manager = manager
	print("%s: State manager set" % panel_title)

func get_coordinator():
	"""Get coordinator with fallback to owner"""
	return _coordinator if _coordinator else null

func get_state_manager():
	"""Get state manager with fallback to owner"""
	return _state_manager if _state_manager else null

# Virtual method for panels to override
func _on_coordinator_set() -> void:
	"""Called when coordinator is set - override in derived panels"""
	pass

# ============ UNIVERSAL SAFE NODE ACCESS PATTERN ============
# Defensive node access with programmatic fallback creation

func safe_get_node(path: String, fallback_creation_func: Callable = Callable()) -> Node:
	"""
	Safe node access with optional fallback creation.
	Returns null if node not found and no fallback provided.
	Creates node via fallback_creation_func if provided.
	"""
	var node = get_node_or_null(path)
	if not node and fallback_creation_func.is_valid():
		node = fallback_creation_func.call()
		if node:
			var parent_path = path.rsplit("/", true, 1)[0]
			var parent = get_node_or_null(parent_path) if parent_path else self
			if parent:
				parent.add_child(node)
				node.name = path.rsplit("/", true, 1)[1] if "/" in path else path
				print("BaseCampaignPanel: Created fallback node: %s" % path)
	return node

func safe_get_child_node(parent: Node, child_name: String, fallback_creation_func: Callable = Callable()) -> Node:
	"""
	Safe child node access with optional fallback creation.
	Useful when you have a parent reference and need a specific child.
	"""
	if not parent:
		return null
	
	var node = parent.get_node_or_null(child_name)
	if not node and fallback_creation_func.is_valid():
		node = fallback_creation_func.call()
		if node:
			parent.add_child(node)
			node.name = child_name
			print("BaseCampaignPanel: Created fallback child: %s" % child_name)
	return node

func create_basic_container(container_type: String = "VBox") -> Control:
	"""Create basic UI container - utility for fallback creation"""
	var container: Control
	match container_type:
		"VBox":
			container = VBoxContainer.new()
		"HBox":
			container = HBoxContainer.new()
		"Margin":
			container = MarginContainer.new()
		"Panel":
			container = PanelContainer.new()
		_:
			container = Control.new()
	
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return container

# ============ UNIVERSAL STATE SYNCHRONIZATION (SPRINT 5.1) ============
# Integration layer to connect existing panels with coordinator

var panel_phase_key: String = ""

func sync_with_coordinator() -> void:
	"""Universal sync method for ALL panels - Sprint 5.1 integration fix"""
	# Find coordinator through multiple methods
	var coordinator = get_coordinator_reference()
	if not coordinator:
		push_error("%s: No coordinator found!" % name)
		return
	
	# Get unified state
	if coordinator.has_method("get_unified_campaign_state"):
		var state = coordinator.get_unified_campaign_state()
		if state.has(panel_phase_key) and state[panel_phase_key] != null:
			_on_campaign_state_updated(state)
			print("%s: Synced with coordinator - phase key: %s" % [name, panel_phase_key])
		else:
			print("%s: No data for phase key: %s" % [name, panel_phase_key])
	else:
		print("%s: Coordinator has no get_unified_campaign_state method" % name)

func get_coordinator_reference():
	"""Try multiple methods to find coordinator - defensive search"""
	# Method 1: Use existing _coordinator reference
	if _coordinator and is_instance_valid(_coordinator):
		return _coordinator
	
	# Method 2: Direct node path to UI
	var coord = get_node_or_null("/root/CampaignCreationUI")
	if coord and coord.has_method("get_coordinator"):
		return coord.get_coordinator()
	
	# Method 3: Through owner
	if owner and owner.has_method("get_coordinator"):
		var owner_coord = owner.get_coordinator()
		if owner_coord:
			return owner_coord
	
	# Method 4: Search up parent tree
	var parent = get_parent()
	while parent:
		if parent.has_method("get_coordinator"):
			var parent_coord = parent.get_coordinator()
			if parent_coord:
				return parent_coord
		elif parent.name == "CampaignCreationUI":
			# Found the UI, check if it IS the coordinator
			if parent.has_method("get_unified_campaign_state"):
				return parent
		parent = parent.get_parent()
	
	return null

func set_panel_phase_key(key: String) -> void:
	"""Set the phase key for state synchronization"""
	panel_phase_key = key
	print("%s: Set phase key to '%s'" % [name, key])

# Virtual method for panels to override when receiving state updates
func _on_campaign_state_updated(state_data: Dictionary) -> void:
	"""Override in derived panels to handle campaign state updates"""
	print("%s: Received state update with keys: %s" % [name, str(state_data.keys())])
	pass
