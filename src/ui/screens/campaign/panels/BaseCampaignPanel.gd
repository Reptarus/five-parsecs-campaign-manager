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

# Dirty flag to prevent update loops
var _is_updating_from_coordinator: bool = false

# UI Structure - provide expected content_container
@onready var content_container: Control = null

# Autoload reference (helps static analyzer) - may be null if autoload disabled
@onready var _responsive_manager: Node = get_node_or_null("/root/ResponsiveManager")

# ResponsiveManager breakpoint constants (matches ResponsiveManager.Breakpoint enum)
const RM_MOBILE := 0
const RM_TABLET := 1
const RM_DESKTOP := 2
const RM_WIDE := 3

func _ready() -> void:
	_ensure_base_background()
	_ensure_panel_structure()
	_setup_panel_content()

	# Setup responsive layout system
	_setup_responsive_layout()

	# Deferred: fix touch scrolling by setting MOUSE_FILTER_PASS on all non-interactive containers
	call_deferred("_fix_touch_scroll_filters")

## Ensure a COLOR_BASE background exists behind this panel.
## Prevents black fallback when the panel isn't nested inside a themed parent.
func _ensure_base_background() -> void:
	if not has_node("__panel_bg"):
		var bg := ColorRect.new()
		bg.name = "__panel_bg"
		bg.color = COLOR_BASE
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.show_behind_parent = true
		add_child(bg)
		move_child(bg, 0)

	# Connect to ResponsiveManager for centralized breakpoint management (if enabled)
	if _responsive_manager:
		_responsive_manager.breakpoint_changed.connect(_on_responsive_breakpoint_changed)
		# Initialize with current breakpoint
		_sync_with_responsive_manager()
	else:
		push_warning("ResponsiveManager autoload disabled - using viewport fallback")

	# Connect viewport resize signal for responsive updates (legacy support)
	get_viewport().size_changed.connect(_on_viewport_resized)

func _exit_tree() -> void:
	## Cleanup when panel is removed from scene tree
	# Disconnect from coordinator if connected
	var coordinator = get_coordinator_reference()
	if coordinator and coordinator.has_signal("campaign_state_updated"):
		if coordinator.is_connected("campaign_state_updated", _on_campaign_state_updated):
			coordinator.disconnect("campaign_state_updated", _on_campaign_state_updated)

	# Disconnect from ResponsiveManager
	if _responsive_manager and _responsive_manager.breakpoint_changed.is_connected(_on_responsive_breakpoint_changed):
		_responsive_manager.breakpoint_changed.disconnect(_on_responsive_breakpoint_changed)


func _ensure_panel_structure() -> void:
	## Ensure the expected node structure exists for panels
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

## Core Interface - Override in derived classes
# Validation state
var last_validation_errors: Array[String] = []

func validate_panel() -> bool:
	## Simple validation - return true if panel data is valid
	return true

func get_validation_message() -> String:
	## Get human-readable validation message for UI display
	if last_validation_errors.size() > 0:
		return last_validation_errors[0]
	return "Complete required fields to continue"

func get_panel_data() -> Dictionary:
	## Get panel data for campaign creation
	return {}

func set_panel_data(data: Dictionary) -> void:
	## Set panel data from campaign state
	pass

# SPRINT 5.5: Helper for safe UI updates
var _pending_panel_data: Dictionary = {}

func _can_update_ui() -> bool:
	## Check if it's safe to update UI elements (node is in tree and ready)
	return is_inside_tree() and is_node_ready()

func _safe_set_panel_data(data: Dictionary) -> void:
	## Safe wrapper for set_panel_data that handles race conditions.
	## Subclasses should call this instead of directly updating UI in set_panel_data()
	## if there's a risk the panel isn't fully initialized."""
	## if _can_update_ui():
	## set_panel_data(data)
	## else:
	## # Queue the data for when panel becomes ready
	## _pending_panel_data = data
	## if not is_inside_tree():
	## # Wait for tree entry, then apply
	## tree_entered.connect(_on_tree_entered_apply_pending_data, CONNECT_ONE_SHOT)
	##
	## func _on_tree_entered_apply_pending_data() -> void:
	if not _pending_panel_data.is_empty():
		call_deferred("set_panel_data", _pending_panel_data)
		_pending_panel_data = {}

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
	## Update UI elements to reflect panel_title and panel_description
	# Update header title if it exists
	if has_node("ContentMargin/MainContent/Header/Title"):
		var title_label = $ContentMargin/MainContent/Header/Title
		title_label.text = panel_title
	
	# Update header description if it exists
	if has_node("ContentMargin/MainContent/Header/Description"):
		var desc_label = $ContentMargin/MainContent/Header/Description
		desc_label.text = panel_description

## Simple validation and completion
func _validate_and_emit_completion() -> void:
	## Validate panel and emit appropriate signals - safe for all panels
	# Ensure panel is fully initialized before validation
	if not is_inside_tree():
		return
		
	var is_valid = validate_panel()
	panel_validation_changed.emit(is_valid)
	
	if is_valid:
		var data = get_panel_data()
		panel_completed.emit(data)
	else:
		var errors: Array[String] = ["Panel validation failed"]
		validation_failed.emit(errors)

## Override in derived classes
func _setup_panel_content() -> void:
	## Setup panel-specific content
	pass

# ============ RESPONSIVE LAYOUT SYSTEM (MOBILE-FIRST) ============
# Sprint 3: Mobile-first responsive design with breakpoint detection

func _setup_responsive_layout() -> void:
	## Initialize responsive layout system on panel load
	_apply_responsive_layout()
	pass # Responsive layout initialized

func _on_viewport_resized() -> void:
	## Handle viewport resize events to update layout
	var previous_mode = current_layout_mode
	_apply_responsive_layout()

	# Only log if layout mode changed
	if current_layout_mode != previous_mode:
		pass # Layout mode changed

func _apply_content_max_width() -> void:
	## Constrain form content width on wide screens.
	## Desktop uses wider max (1200px) for multi-column HFlowContainer layouts.
	## Mobile/tablet uses standard max (800px) for single-column readability.
	var cm := get_node_or_null("ContentMargin")
	if not cm:
		return
	var viewport := get_viewport()
	if not viewport:
		return
	var vp_width := viewport.get_visible_rect().size.x
	var effective_max: int = MAX_FORM_WIDTH
	if current_layout_mode == LayoutMode.DESKTOP:
		effective_max = 1200
	if vp_width > effective_max + SPACING_XL * 2:
		var side := int((vp_width - effective_max) / 2.0)
		cm.add_theme_constant_override("margin_left", side)
		cm.add_theme_constant_override("margin_right", side)
	else:
		cm.add_theme_constant_override("margin_left", SPACING_XL)
		cm.add_theme_constant_override("margin_right", SPACING_XL)

func _apply_responsive_layout() -> void:
	## Apply responsive layout based on current viewport width
	# SPRINT 26 FIX: Guard against null viewport during scene transitions
	var viewport = get_viewport()
	if not viewport:
		# Panel not in tree yet, defer layout until ready
		call_deferred("_apply_responsive_layout")
		return

	var viewport_width = viewport.get_visible_rect().size.x
	var new_mode: LayoutMode

	# Determine layout mode from viewport width
	if viewport_width < BREAKPOINT_MOBILE:
		new_mode = LayoutMode.MOBILE
	elif viewport_width < BREAKPOINT_TABLET:
		new_mode = LayoutMode.TABLET
	else:
		new_mode = LayoutMode.DESKTOP

	# Apply layout if mode changed
	if new_mode != current_layout_mode:
		current_layout_mode = new_mode
		_update_layout_for_mode()

	# Always update content max-width (viewport may resize without mode change)
	_apply_content_max_width()

func _update_layout_for_mode() -> void:
	## Update UI layout based on current mode - override in derived panels
	match current_layout_mode:
		LayoutMode.MOBILE:
			_apply_mobile_layout()
		LayoutMode.TABLET:
			_apply_tablet_layout()
		LayoutMode.DESKTOP:
			_apply_desktop_layout()

# Virtual methods for panels to override
func _apply_mobile_layout() -> void:
	## Apply mobile-specific layout (portrait, single column, large touch targets)
	# Override in derived panels for mobile-specific adjustments
	pass

func _apply_tablet_layout() -> void:
	## Apply tablet-specific layout (two-column where appropriate)
	# Override in derived panels for tablet-specific adjustments
	pass

func _apply_desktop_layout() -> void:
	## Apply desktop-specific layout (multi-column, full data visibility)
	# Override in derived panels for desktop-specific adjustments
	pass

func is_mobile_layout() -> bool:
	## Check if current layout is mobile
	return current_layout_mode == LayoutMode.MOBILE

func is_tablet_layout() -> bool:
	## Check if current layout is tablet
	return current_layout_mode == LayoutMode.TABLET

func is_desktop_layout() -> bool:
	## Check if current layout is desktop
	return current_layout_mode == LayoutMode.DESKTOP

func _get_layout_mode_name(mode: LayoutMode = current_layout_mode) -> String:
	## Get human-readable name for layout mode
	match mode:
		LayoutMode.MOBILE:
			return "MOBILE"
		LayoutMode.TABLET:
			return "TABLET"
		LayoutMode.DESKTOP:
			return "DESKTOP"
		_:
			return "UNKNOWN"

# ============ RESPONSIVE MANAGER INTEGRATION ============

func _sync_with_responsive_manager() -> void:
	## Synchronize panel layout mode with ResponsiveManager's current breakpoint
	if not _responsive_manager:
		return

	# Map ResponsiveManager.Breakpoint to BaseCampaignPanel.LayoutMode
	match _responsive_manager.current_breakpoint:
		RM_MOBILE:
			if current_layout_mode != LayoutMode.MOBILE:
				current_layout_mode = LayoutMode.MOBILE
				_update_layout_for_mode()
		RM_TABLET:
			if current_layout_mode != LayoutMode.TABLET:
				current_layout_mode = LayoutMode.TABLET
				_update_layout_for_mode()
		_:  # DESKTOP or WIDE
			if current_layout_mode != LayoutMode.DESKTOP:
				current_layout_mode = LayoutMode.DESKTOP
				_update_layout_for_mode()

func _on_responsive_breakpoint_changed(new_breakpoint: int) -> void:
	## Handle ResponsiveManager breakpoint changes
	var previous_mode := current_layout_mode

	# Map ResponsiveManager.Breakpoint to BaseCampaignPanel.LayoutMode
	match new_breakpoint:
		RM_MOBILE:
			current_layout_mode = LayoutMode.MOBILE
		RM_TABLET:
			current_layout_mode = LayoutMode.TABLET
		_:  # DESKTOP or WIDE
			current_layout_mode = LayoutMode.DESKTOP

	# Only update if mode actually changed
	if current_layout_mode != previous_mode:
		_update_layout_for_mode()
		pass # Layout updated via ResponsiveManager

# ============ RESPONSIVE HELPER METHODS ============

func get_responsive_font_size(base_size: int) -> int:
	## Get font size adjusted for current layout mode
	match current_layout_mode:
		LayoutMode.MOBILE:
			# Reduce font sizes on mobile for better density
			return max(FONT_SIZE_XS, base_size - 2)
		LayoutMode.TABLET:
			# Tablet uses base sizes
			return base_size
		LayoutMode.DESKTOP:
			# Desktop can use slightly larger for readability
			return base_size
		_:
			return base_size

func get_responsive_spacing(base_spacing: int) -> int:
	## Get spacing adjusted for current layout mode
	match current_layout_mode:
		LayoutMode.MOBILE:
			# Tighter spacing on mobile to maximize screen space
			return max(SPACING_XS, base_spacing - 4)
		LayoutMode.TABLET:
			# Tablet uses base spacing
			return base_spacing
		LayoutMode.DESKTOP:
			# Desktop can use more generous spacing
			return base_spacing + 4
		_:
			return base_spacing

func get_responsive_touch_target() -> int:
	## Get touch target size for current layout mode
	match current_layout_mode:
		LayoutMode.MOBILE:
			# Mobile needs comfortable 56dp targets
			return TOUCH_TARGET_COMFORT
		LayoutMode.TABLET:
			# Tablet uses standard 48dp
			return TOUCH_TARGET_MIN
		LayoutMode.DESKTOP:
			# Desktop can use minimum (mouse precision)
			return TOUCH_TARGET_MIN
		_:
			return TOUCH_TARGET_MIN

func should_use_single_column() -> bool:
	## Check if layout should use single column (mobile/portrait)
	if current_layout_mode == LayoutMode.MOBILE:
		return true

	# Check for portrait orientation even on larger devices
	var viewport_size = get_viewport().get_visible_rect().size
	return viewport_size.y > viewport_size.x  # Height > Width = Portrait

func get_optimal_column_count() -> int:
	## Get optimal number of columns for current layout
	if should_use_single_column():
		return 1

	match current_layout_mode:
		LayoutMode.MOBILE:
			return 1
		LayoutMode.TABLET:
			return 2
		LayoutMode.DESKTOP:
			return 3
		_:
			return 2

## Helper methods for safe panel operations
func emit_data_changed() -> void:
	## Safely emit data changed signal without validation
	var data = get_panel_data()
	panel_data_changed.emit(data)

func safe_validate_and_complete() -> void:
	## Safe wrapper for validation that checks panel state first
	if not is_inside_tree():
		return
	_validate_and_emit_completion()

## Panel ready signal method
func emit_panel_ready() -> void:
	## Emit panel ready signal for coordinator communication
	panel_ready.emit()
	pass # Panel ready signal emitted

## Coordinator Integration Methods (Phase 0: Foundation)
func set_coordinator(coord) -> void:
	## Set coordinator reference for panel integration
	_coordinator = coord
	call_deferred("_on_coordinator_set") # Defer to ensure panel is ready

func set_state_manager(manager) -> void:
	## Set state manager reference for panel integration
	_state_manager = manager

func get_coordinator():
	## Get coordinator with fallback to owner
	return _coordinator if _coordinator else null

func get_state_manager():
	## Get state manager with fallback to owner
	return _state_manager if _state_manager else null

# Virtual method for panels to override
func _on_coordinator_set() -> void:
	## Called when coordinator is set - override in derived panels
	pass

# ============ UNIVERSAL SAFE NODE ACCESS PATTERN ============
# Defensive node access with programmatic fallback creation

func safe_get_node(path: String, fallback_creation_func: Callable = Callable()) -> Node:
	## Safe node access with optional fallback creation.
	## Returns null if node not found and no fallback provided.
	## Creates node via fallback_creation_func if provided.
	var node = get_node_or_null(path)
	if not node and fallback_creation_func.is_valid():
		node = fallback_creation_func.call()
		if node:
			var parent_path = path.rsplit("/", true, 1)[0]
			var parent = get_node_or_null(parent_path) if parent_path else self
			if parent:
				parent.add_child(node)
				node.name = path.rsplit("/", true, 1)[1] if "/" in path else path
	return node

func safe_get_child_node(parent: Node, child_name: String, fallback_creation_func: Callable = Callable()) -> Node:
	## Safe child node access with optional fallback creation.
	## Useful when you have a parent reference and need a specific child.
	if not parent:
		return null
	
	var node = parent.get_node_or_null(child_name)
	if not node and fallback_creation_func.is_valid():
		node = fallback_creation_func.call()
		if node:
			parent.add_child(node)
			node.name = child_name
	return node

func create_basic_container(container_type: String = "VBox") -> Control:
	## Create basic UI container - utility for fallback creation
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
	## Universal sync method for ALL panels - Sprint 5.1 integration fix
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
		else:
			pass
	else:
		pass

func get_coordinator_reference():
	## Try multiple methods to find coordinator - defensive search
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
	## Set the phase key for state synchronization
	panel_phase_key = key

# Virtual method for panels to override when receiving state updates
func _on_campaign_state_updated(state_data: Dictionary) -> void:
	## Override in derived panels to handle campaign state updates.
	## IMPORTANT: Dirty flag is set automatically to prevent update loops.
	# Set dirty flag to prevent circular updates
	_is_updating_from_coordinator = true

	# Call derived class implementation
	_handle_campaign_state_update(state_data)

	# Reset dirty flag
	_is_updating_from_coordinator = false

func _handle_campaign_state_update(state_data: Dictionary) -> void:
	## Override this method in derived panels instead of _on_campaign_state_updated
	pass # State update received
	pass

## Helper method for safe signal emission (prevents update loops)
func _emit_panel_data_changed(data: Dictionary) -> void:
	## Safely emit panel_data_changed only when not processing coordinator updates.
	## Use this instead of emitting panel_data_changed directly.
	if _is_updating_from_coordinator:
		pass # Skipping emission during coordinator update
		return

	panel_data_changed.emit(data)


# ============ UNIFIED UI DESIGN SYSTEM ============
# All tokens sourced from UIColors (canonical design token file)

## Spacing System (8px grid)
const SPACING_XS := UIColors.SPACING_XS
const SPACING_SM := UIColors.SPACING_SM
const SPACING_MD := UIColors.SPACING_MD
const SPACING_LG := UIColors.SPACING_LG
const SPACING_XL := UIColors.SPACING_XL

## Touch Target Minimums
const TOUCH_TARGET_MIN := UIColors.TOUCH_TARGET_MIN
const TOUCH_TARGET_COMFORT := UIColors.TOUCH_TARGET_COMFORT

## Typography Sizes
const FONT_SIZE_XS := UIColors.FONT_SIZE_XS
const FONT_SIZE_SM := UIColors.FONT_SIZE_SM
const FONT_SIZE_MD := UIColors.FONT_SIZE_MD
const FONT_SIZE_LG := UIColors.FONT_SIZE_LG
const FONT_SIZE_XL := UIColors.FONT_SIZE_XL

## Responsive Breakpoints (Mobile-First Design)
const BREAKPOINT_MOBILE := UIColors.BREAKPOINT_MOBILE
const BREAKPOINT_TABLET := UIColors.BREAKPOINT_TABLET
const BREAKPOINT_DESKTOP := UIColors.BREAKPOINT_DESKTOP

## Max content width for form panels (prevents absurdly wide inputs on desktop)
const MAX_FORM_WIDTH := 800

# Responsive layout state
enum LayoutMode { MOBILE, TABLET, DESKTOP }
var current_layout_mode: LayoutMode = LayoutMode.DESKTOP

## Color Palette - Deep Space Theme (from UIColors)
const COLOR_PRIMARY := UIColors.COLOR_PRIMARY
const COLOR_SECONDARY := UIColors.COLOR_SECONDARY
const COLOR_TERTIARY := UIColors.COLOR_TERTIARY
const COLOR_BORDER := UIColors.COLOR_BORDER
const COLOR_BLUE := UIColors.COLOR_BLUE
const COLOR_PURPLE := UIColors.COLOR_PURPLE
const COLOR_EMERALD := UIColors.COLOR_EMERALD
const COLOR_AMBER := UIColors.COLOR_AMBER
const COLOR_RED := UIColors.COLOR_RED
const COLOR_CYAN := UIColors.COLOR_CYAN
const COLOR_TEXT_PRIMARY := UIColors.COLOR_TEXT_PRIMARY
const COLOR_TEXT_SECONDARY := UIColors.COLOR_TEXT_SECONDARY
const COLOR_TEXT_MUTED := UIColors.COLOR_TEXT_MUTED

# Legacy aliases
const COLOR_BASE := UIColors.COLOR_BASE
const COLOR_ELEVATED := UIColors.COLOR_ELEVATED
const COLOR_INPUT := UIColors.COLOR_INPUT
const COLOR_ACCENT := UIColors.COLOR_ACCENT
const COLOR_ACCENT_HOVER := UIColors.COLOR_ACCENT_HOVER
const COLOR_FOCUS := UIColors.COLOR_FOCUS
const COLOR_SUCCESS := UIColors.COLOR_SUCCESS
const COLOR_WARNING := UIColors.COLOR_WARNING
const COLOR_DANGER := UIColors.COLOR_DANGER
const COLOR_TEXT_DISABLED := UIColors.COLOR_TEXT_DISABLED


# ============ UI COMPONENT FACTORY METHODS ============

func _create_section_card(title: String, content: Control, description: String = "", icon: String = "") -> PanelContainer:
	## Create a styled section card with title, content, optional description and icon.
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_PASS  # Allow touch scroll through cards

	# Apply glass morphism style (modern look)
	panel.add_theme_stylebox_override("panel", _create_glass_card_style())

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", SPACING_SM)
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS  # Allow touch scroll through cards

	# Section header with optional icon (updated to support icon parameter)
	if not icon.is_empty():
		var header_hbox := HBoxContainer.new()
		header_hbox.add_theme_constant_override("separation", SPACING_SM)
		
		var icon_label := Label.new()
		icon_label.text = icon
		icon_label.add_theme_font_size_override("font_size", FONT_SIZE_LG)
		icon_label.add_theme_color_override("font_color", COLOR_ACCENT)
		header_hbox.add_child(icon_label)
		
		var title_label := Label.new()
		title_label.text = title.to_upper()
		title_label.add_theme_font_size_override("font_size", FONT_SIZE_LG)
		title_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		header_hbox.add_child(title_label)
		
		vbox.add_child(header_hbox)
	else:
		# Original code path (no icon)
		var title_label := Label.new()
		title_label.text = title.to_upper()
		title_label.add_theme_font_size_override("font_size", FONT_SIZE_LG)
		title_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		vbox.add_child(title_label)

	# Separator
	var sep := HSeparator.new()
	sep.modulate = COLOR_BORDER
	vbox.add_child(sep)

	# Content
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(content)

	# Optional description
	if description != "":
		var desc := Label.new()
		desc.text = description
		desc.add_theme_font_size_override("font_size", FONT_SIZE_SM)
		desc.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(desc)

	panel.add_child(vbox)
	return panel


func _fix_touch_scroll_filters() -> void:
	## Recursively set MOUSE_FILTER_PASS on layout containers so touch scrolling
	## works through cards/panels on mobile. Buttons and interactive controls keep STOP.
	_apply_pass_filter_recursive(self)

func _apply_pass_filter_recursive(node: Node) -> void:
	if node is Button or node is LineEdit or node is TextEdit or node is SpinBox \
		or node is OptionButton or node is CheckBox or node is CheckButton \
		or node is ScrollContainer or node is LinkButton:
		return  # Interactive controls must keep MOUSE_FILTER_STOP
	if node is Control:
		var ctrl := node as Control
		if ctrl.mouse_filter == Control.MOUSE_FILTER_STOP:
			ctrl.mouse_filter = Control.MOUSE_FILTER_PASS
	for child in node.get_children():
		_apply_pass_filter_recursive(child)


func _create_glass_card_style(alpha: float = 0.8) -> StyleBoxFlat:
	## Create glass morphism card style with adjustable transparency
	var style := StyleBoxFlat.new()
	style.bg_color = Color(COLOR_SECONDARY.r, COLOR_SECONDARY.g, COLOR_SECONDARY.b, alpha)
	style.border_color = Color(COLOR_BORDER.r, COLOR_BORDER.g, COLOR_BORDER.b, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(SPACING_LG)
	return style


func _create_glass_card_elevated() -> StyleBoxFlat:
	## Create elevated glass card (higher opacity for prominence)
	return _create_glass_card_style(0.9)


func _create_glass_card_subtle() -> StyleBoxFlat:
	## Create subtle glass card (lower opacity for backgrounds)
	return _create_glass_card_style(0.6)


func _create_elevated_card_style() -> StyleBoxFlat:
	## Create elevated card style (solid background, for inner elements)
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_TERTIARY
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(SPACING_MD)
	return style


func _create_labeled_input(label_text: String, input: Control) -> VBoxContainer:
	## Create a label above an input field with proper spacing.
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", SPACING_XS)
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if label_text != "":
		var label := Label.new()
		label.text = label_text
		label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
		label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		container.add_child(label)

	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.custom_minimum_size.y = TOUCH_TARGET_MIN
	container.add_child(input)

	return container


func _create_stat_display(stat_name: String, value: Variant) -> PanelContainer:
	## Create a compact stat display box.
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(64, 56)

	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_INPUT
	style.set_corner_radius_all(6)
	style.set_content_margin_all(SPACING_SM)
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER

	# Stat name
	var name_label := Label.new()
	name_label.text = stat_name.to_upper()
	name_label.add_theme_font_size_override("font_size", FONT_SIZE_XS)
	name_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)

	# Value
	var value_label := Label.new()
	value_label.text = str(value)
	value_label.add_theme_font_size_override("font_size", FONT_SIZE_XL)
	value_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(value_label)

	panel.add_child(vbox)
	return panel


func _create_stats_grid(stats: Dictionary, columns: int = 4) -> GridContainer:
	## Create a grid of stat displays.
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", SPACING_SM)
	grid.add_theme_constant_override("v_separation", SPACING_SM)

	for stat_name in stats:
		var stat_box := _create_stat_display(stat_name, stats[stat_name])
		grid.add_child(stat_box)

	return grid


func _create_button_group_selector(options: Array, selected_index: int = 0) -> HBoxContainer:
	## Create a horizontal button group for single selection (radio-like).
	var container := HBoxContainer.new()
	container.add_theme_constant_override("separation", SPACING_SM)

	var button_group := ButtonGroup.new()

	for i in range(options.size()):
		var btn := Button.new()
		btn.text = str(options[i])
		btn.toggle_mode = true
		btn.button_group = button_group
		btn.button_pressed = (i == selected_index)
		btn.custom_minimum_size.y = TOUCH_TARGET_MIN
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		container.add_child(btn)

	return container


func _create_character_card(char_name: String, subtitle: String, stats: Dictionary = {}, portrait_path: String = "") -> PanelContainer:
	## Create a character card with portrait (custom image or colored initials).
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size.y = 100

	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_ELEVATED
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(SPACING_MD)
	panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", SPACING_MD)

	# Portrait (custom image or colored initials)
	var portrait_size := 64
	var portrait_container := Control.new()
	portrait_container.custom_minimum_size = Vector2(portrait_size, portrait_size)
	portrait_container.clip_contents = true

	var avatar_colors := [Color("#3b82f6"), Color("#8b5cf6"), Color("#06b6d4"),
		Color("#10b981"), Color("#f59e0b"), Color("#ef4444"), Color("#ec4899"), Color("#14b8a6")]
	var color_idx := char_name.hash() % avatar_colors.size()
	if color_idx < 0:
		color_idx += avatar_colors.size()

	var bg := ColorRect.new()
	bg.custom_minimum_size = Vector2(portrait_size, portrait_size)
	bg.color = avatar_colors[color_idx]
	portrait_container.add_child(bg)

	var has_portrait := false
	if not portrait_path.is_empty():
		var tex: Texture2D = null
		if portrait_path.begins_with("res://") and ResourceLoader.exists(portrait_path):
			tex = load(portrait_path)
		elif FileAccess.file_exists(portrait_path):
			var img := Image.new()
			if img.load(portrait_path) == OK:
				tex = ImageTexture.create_from_image(img)
		if tex:
			var tex_rect := TextureRect.new()
			tex_rect.texture = tex
			tex_rect.custom_minimum_size = Vector2(portrait_size, portrait_size)
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			portrait_container.add_child(tex_rect)
			has_portrait = true

	if not has_portrait:
		var initial_label := Label.new()
		initial_label.text = char_name.substr(0, 1).to_upper() if not char_name.is_empty() else "?"
		initial_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		initial_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		initial_label.add_theme_font_size_override("font_size", int(portrait_size * 0.45))
		initial_label.add_theme_color_override("font_color", Color.WHITE)
		initial_label.custom_minimum_size = Vector2(portrait_size, portrait_size)
		portrait_container.add_child(initial_label)

	hbox.add_child(portrait_container)

	# Info column
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_label := Label.new()
	name_label.text = char_name
	name_label.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	name_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	info.add_child(name_label)

	var sub_label := Label.new()
	sub_label.text = subtitle
	sub_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	sub_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	info.add_child(sub_label)

	# Stats row
	if stats.size() > 0:
		var stats_text := ""
		for key in stats:
			if stats_text != "":
				stats_text += "  "
			stats_text += "%s: %s" % [key, stats[key]]
		var stats_label := Label.new()
		stats_label.text = stats_text
		stats_label.add_theme_font_size_override("font_size", FONT_SIZE_XS)
		stats_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		info.add_child(stats_label)

	hbox.add_child(info)
	panel.add_child(hbox)
	return panel


func _create_add_button(text: String) -> Button:
	## Create an 'add item' button with dashed border style.
	var btn := Button.new()
	btn.text = text
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size.y = TOUCH_TARGET_MIN

	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = COLOR_TEXT_SECONDARY
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(SPACING_MD)
	btn.add_theme_stylebox_override("normal", style)

	btn.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)

	return btn


func _create_stat_badge(stat_name: String, value: int, show_plus: bool = false) -> PanelContainer:
	## Create a compact stat badge for displaying character stats in summaries.
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(80, 32)
	
	# Subtle background styling
	var style := StyleBoxFlat.new()
	style.bg_color = Color(COLOR_INPUT, 0.6)  # Semi-transparent background
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(SPACING_XS)
	panel.add_theme_stylebox_override("panel", style)
	
	# Horizontal layout: stat name + value
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", SPACING_XS)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	
	# Stat name (small, secondary color)
	var name_label := Label.new()
	name_label.text = stat_name.to_upper()
	name_label.add_theme_font_size_override("font_size", FONT_SIZE_XS)
	name_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	hbox.add_child(name_label)
	
	# Stat value (larger, accent color, optional +)
	var value_label := Label.new()
	var value_text := str(value) if not show_plus else ("+" + str(value) if value >= 0 else str(value))
	value_label.text = value_text
	value_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	value_label.add_theme_color_override("font_color", COLOR_ACCENT)
	hbox.add_child(value_label)
	
	panel.add_child(hbox)
	return panel


func _style_line_edit(line_edit: LineEdit) -> void:
	## Apply consistent styling to a LineEdit.
	line_edit.custom_minimum_size.y = TOUCH_TARGET_COMFORT

	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_INPUT
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(SPACING_SM)
	line_edit.add_theme_stylebox_override("normal", style)

	var focus_style := style.duplicate()
	focus_style.border_color = COLOR_FOCUS
	focus_style.set_border_width_all(2)
	line_edit.add_theme_stylebox_override("focus", focus_style)


func _style_option_button(option_btn: OptionButton) -> void:
	## Apply consistent styling to an OptionButton.
	option_btn.custom_minimum_size.y = TOUCH_TARGET_MIN

	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_INPUT
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(SPACING_SM)
	option_btn.add_theme_stylebox_override("normal", style)


func _style_button(button: Button, is_primary: bool = false) -> void:
	## Apply consistent button styling. Use is_primary=true for action buttons.
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_BLUE if is_primary else COLOR_TERTIARY
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = SPACING_MD
	style.content_margin_right = SPACING_MD
	style.content_margin_top = SPACING_SM
	style.content_margin_bottom = SPACING_SM

	button.add_theme_stylebox_override("normal", style)
	button.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	button.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	button.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)

	# Hover state
	var hover_style := style.duplicate()
	hover_style.bg_color = COLOR_ACCENT_HOVER if is_primary else Color(COLOR_TERTIARY.r + 0.1, COLOR_TERTIARY.g + 0.1, COLOR_TERTIARY.b + 0.1)
	button.add_theme_stylebox_override("hover", hover_style)

	# Pressed state
	var pressed_style := style.duplicate()
	pressed_style.bg_color = Color(style.bg_color.r - 0.1, style.bg_color.g - 0.1, style.bg_color.b - 0.1)
	button.add_theme_stylebox_override("pressed", pressed_style)

	# Disabled state — clearly distinguishable from enabled
	var disabled_style := style.duplicate()
	disabled_style.bg_color = Color(style.bg_color.r, style.bg_color.g, style.bg_color.b, 0.2)
	disabled_style.border_color = Color(COLOR_BORDER.r, COLOR_BORDER.g, COLOR_BORDER.b, 0.25)
	disabled_style.set_border_width_all(1)
	button.add_theme_stylebox_override("disabled", disabled_style)
	button.add_theme_color_override("font_disabled_color", Color("#4b5563"))


func _style_danger_button(button: Button) -> void:
	## Apply danger/destructive button styling (red).
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_RED
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = SPACING_MD
	style.content_margin_right = SPACING_MD
	style.content_margin_top = SPACING_SM
	style.content_margin_bottom = SPACING_SM

	button.add_theme_stylebox_override("normal", style)
	button.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	button.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	button.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)

	# Hover state (lighter red)
	var hover_style := style.duplicate()
	hover_style.bg_color = Color(COLOR_RED.r + 0.1, COLOR_RED.g, COLOR_RED.b)
	button.add_theme_stylebox_override("hover", hover_style)


# ============ GLASS MORPHISM STYLING ============

func _create_glass_panel_style() -> StyleBoxFlat:
	## Create glass morphism style matching HTML mockup (semi-transparent with border)
	var style := StyleBoxFlat.new()

	# Background: rgba(17, 24, 39, 0.8) - semi-transparent
	style.bg_color = Color(COLOR_SECONDARY.r, COLOR_SECONDARY.g, COLOR_SECONDARY.b, 0.8)

	# Border: subtle gray with transparency
	style.border_color = Color(COLOR_BORDER.r, COLOR_BORDER.g, COLOR_BORDER.b, 0.5)
	style.set_border_width_all(1)

	# Rounded corners (16px = rounded-2xl in Tailwind)
	style.set_corner_radius_all(16)

	# Padding
	style.set_content_margin_all(SPACING_LG)

	return style


func _create_glass_panel_style_compact() -> StyleBoxFlat:
	## Compact glass panel with smaller padding (for cards within sections)
	var style := _create_glass_panel_style()
	style.set_content_margin_all(SPACING_MD)
	style.set_corner_radius_all(12)
	return style


func _create_accent_card_style(accent_color: Color) -> StyleBoxFlat:
	## Create accent-tinted card (e.g., amber for current step, pink for quests)
	var style := StyleBoxFlat.new()

	# Tinted background (10% opacity of accent)
	style.bg_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.1)

	# Accent border (20% opacity)
	style.border_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.2)
	style.set_border_width_all(1)

	# Rounded corners
	style.set_corner_radius_all(12)

	# Padding
	style.set_content_margin_all(SPACING_MD)

	return style


func _create_section_header(title: String, icon: String = "") -> HBoxContainer:
	## Create standardized section header with icon + title
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", SPACING_SM)

	# Icon container (if provided)
	if not icon.is_empty():
		var icon_panel := PanelContainer.new()
		icon_panel.custom_minimum_size = Vector2(32, 32)

		var icon_style := StyleBoxFlat.new()
		icon_style.bg_color = Color(COLOR_ACCENT.r, COLOR_ACCENT.g, COLOR_ACCENT.b, 0.2)
		icon_style.set_corner_radius_all(8)
		icon_panel.add_theme_stylebox_override("panel", icon_style)

		var icon_label := Label.new()
		icon_label.text = icon
		icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon_label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
		icon_panel.add_child(icon_label)
		hbox.add_child(icon_panel)

	# Title
	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	title_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	hbox.add_child(title_label)

	return hbox


# ============ PROGRESS INDICATOR ============

func _create_progress_indicator(current_step: int, total_steps: int, step_title: String = "") -> Control:
	## Create a visual progress indicator with breadcrumbs for multi-step wizards.
	##
	## Features:
	## - Progress bar showing % completion
	## - Breadcrumb circles (1-N) with visual states
	## - Step title display
	##
	## Visual States:
	## - Completed steps: Green background + checkmark (✓)
	## - Current step: Cyan background + step number
	## - Upcoming steps: Gray background + step number
	##
	## Parameters:
	## - current_step: 0-indexed current step (0 = first step)
	## - total_steps: Total number of steps (e.g., 7 for campaign wizard)
	## - step_title: Optional title override (uses panel_title if empty)
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", SPACING_SM)
	
	# === PROGRESS BAR ===
	var progress_bar := ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(0, 8)
	progress_bar.value = (float(current_step) / float(total_steps)) * 100.0
	progress_bar.show_percentage = false
	
	# Style progress bar
	var progress_bg := StyleBoxFlat.new()
	progress_bg.bg_color = COLOR_BORDER
	progress_bg.set_corner_radius_all(4)
	progress_bar.add_theme_stylebox_override("background", progress_bg)
	
	var progress_fill := StyleBoxFlat.new()
	progress_fill.bg_color = COLOR_FOCUS
	progress_fill.set_corner_radius_all(4)
	progress_bar.add_theme_stylebox_override("fill", progress_fill)
	
	container.add_child(progress_bar)
	
	# === BREADCRUMB CIRCLES ===
	var breadcrumb_container := HBoxContainer.new()
	breadcrumb_container.add_theme_constant_override("separation", SPACING_XS)
	breadcrumb_container.alignment = BoxContainer.ALIGNMENT_CENTER
	
	for i in range(total_steps):
		var step_indicator := PanelContainer.new()
		step_indicator.custom_minimum_size = Vector2(32, 32)
		
		# Style based on step state
		var style := StyleBoxFlat.new()
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		
		if i < current_step - 1:
			# Completed step
			style.bg_color = COLOR_SUCCESS
			label.text = "✓"
			label.add_theme_font_size_override("font_size", FONT_SIZE_LG)
			label.add_theme_color_override("font_color", UIColors.COLOR_TEXT_PRIMARY)
		elif i == current_step - 1:
			# Current step
			style.bg_color = COLOR_FOCUS
			label.text = str(i + 1)
			label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
			label.add_theme_color_override("font_color", UIColors.COLOR_TEXT_PRIMARY)
		else:
			# Upcoming step
			style.bg_color = COLOR_BORDER
			label.text = str(i + 1)
			label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
			label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		
		style.set_corner_radius_all(16)  # Circular
		step_indicator.add_theme_stylebox_override("panel", style)
		step_indicator.add_child(label)
		breadcrumb_container.add_child(step_indicator)
	
	container.add_child(breadcrumb_container)
	
	# === STEP TITLE (Optional) ===
	if not step_title.is_empty():
		var title_label := Label.new()
		title_label.text = step_title
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
		title_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
		container.add_child(title_label)
	
	return container
