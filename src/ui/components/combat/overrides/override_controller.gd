@tool
extends Node

## Signals
signal override_applied(context: String, value: int)
signal override_cancelled(context: String)

## Required dependencies
const BaseCombatManager := preload("res://src/base/combat/BaseCombatManager.gd")

## Node references
@onready var override_panel: PanelContainer = _find_override_panel()

## Properties
var active_context: String = ""
var combat_resolver: Node = null
var combat_manager: BaseCombatManager = null

## Called when the node enters scene tree
func _ready() -> void:
	if not Engine.is_editor_hint():
		# Find or create the override panel
		if override_panel:
			if override_panel.has_signal("override_applied"):
				override_panel.override_applied.connect(_on_override_applied)
			if override_panel.has_signal("override_cancelled"):
				override_panel.override_cancelled.connect(_on_override_cancelled)
		else:
			push_warning("Override panel not found. Some functionality will be limited.")

## Helper function to find the override panel
func _find_override_panel() -> PanelContainer:
	# Try the direct path first
	var panel = get_node_or_null("%ManualOverridePanel")
	
	# If not found, try searching in children
	if not panel:
		for child in get_children():
			if child is PanelContainer and (child.name == "ManualOverridePanel" or
				child.name == "OverridePanel" or "Override" in child.name):
				panel = child
				break
	
	# If still not found, try searching in parent
	if not panel and get_parent():
		panel = get_parent().get_node_or_null("%ManualOverridePanel")
		
		# Try searching in parent's children
		if not panel:
			for child in get_parent().get_children():
				if child is PanelContainer and (child.name == "ManualOverridePanel" or
					child.name == "OverridePanel" or "Override" in child.name):
					panel = child
					break
	
	# If still not found, create a fallback panel
	if not panel:
		push_warning("Creating fallback override panel")
		panel = PanelContainer.new()
		panel.name = "ManualOverridePanel"
		
		# Add minimal UI elements
		var vbox = VBoxContainer.new()
		panel.add_child(vbox)
		
		var label = Label.new()
		label.text = "Override Value:"
		vbox.add_child(label)
		
		var spinbox = SpinBox.new()
		spinbox.name = "override_value_spinbox"
		spinbox.min_value = 1
		spinbox.max_value = 6
		spinbox.value = 1
		vbox.add_child(spinbox)
		
		var hbox = HBoxContainer.new()
		vbox.add_child(hbox)
		
		var apply_btn = Button.new()
		apply_btn.text = "Apply"
		apply_btn.pressed.connect(func(): _on_override_applied(spinbox.value))
		hbox.add_child(apply_btn)
		
		var cancel_btn = Button.new()
		cancel_btn.text = "Cancel"
		cancel_btn.pressed.connect(_on_override_cancelled)
		hbox.add_child(cancel_btn)
		
		# Add signals to panel
		if not panel.has_signal("override_applied"):
			panel.add_user_signal("override_applied", [ {"name": "value", "type": TYPE_INT}])
		if not panel.has_signal("override_cancelled"):
			panel.add_user_signal("override_cancelled")
			
		# Add show/hide override methods
		if not panel.has_method("show_override"):
			panel.set_meta("show_override", func(context: String, current_value: int, min_val: int = 1, max_val: int = 6):
				spinbox.min_value = min_val
				spinbox.max_value = max_val
				spinbox.value = current_value
				panel.show()
			)
			
		add_child(panel)
		panel.hide()
	
	return panel

## Sets up combat system references
func setup_combat_system(resolver: Node, manager: BaseCombatManager) -> void:
	combat_resolver = resolver
	combat_manager = manager
	
	# Connect combat system signals
	if combat_resolver:
		if combat_resolver.has_signal("override_requested"):
			if not combat_resolver.is_connected("override_requested", _on_combat_override_requested):
				combat_resolver.override_requested.connect(_on_combat_override_requested)
		if combat_resolver.has_signal("dice_roll_completed"):
			if not combat_resolver.is_connected("dice_roll_completed", _on_dice_roll_completed):
				combat_resolver.dice_roll_completed.connect(_on_dice_roll_completed)
	
	if combat_manager:
		if combat_manager.has_signal("combat_state_changed"):
			if not combat_manager.is_connected("combat_state_changed", _on_combat_state_changed):
				combat_manager.combat_state_changed.connect(_on_combat_state_changed)
		if combat_manager.has_signal("override_validation_requested"):
			if not combat_manager.is_connected("override_validation_requested", _on_override_validation_requested):
				combat_manager.override_validation_requested.connect(_on_override_validation_requested)

## Shows override panel for combat context
func request_override(context: String, current_value: int, min_val: int = 1, max_val: int = 6) -> void:
	active_context = context
	
	# Add null check before accessing override_panel
	if override_panel:
		# Make sure the show_override method exists
		if override_panel.has_method("show_override"):
			override_panel.show_override(context, current_value, min_val, max_val)
		else:
			# Fallback if method doesn't exist
			override_panel.show()
			# Try to update any visible UI elements
			var spinbox = override_panel.get_node_or_null("override_value_spinbox")
			if spinbox and spinbox is SpinBox:
				spinbox.min_value = min_val
				spinbox.max_value = max_val
				spinbox.value = current_value
	else:
		push_warning("Cannot show override panel: panel is null")
		# Emit signal as fallback when panel is not available
		override_applied.emit(context, current_value)

## Validates override value against current combat state
func validate_override(context: String, value: int) -> bool:
	if not combat_manager:
		return true
	
	# Get validation rules based on context
	var validation_rules = _get_validation_rules(context)
	
	# Check against current combat state
	var current_state = combat_manager.get_current_state() if combat_manager.has_method("get_current_state") else {}
	if not current_state:
		return true
	
	# Apply validation rules
	for rule in validation_rules:
		if rule and rule.has("validate") and rule.validate is Callable:
			if not rule.validate.call(current_state, value):
				return false
	
	return true

## Gets validation rules for context
func _get_validation_rules(context: String) -> Array:
	var rules = []
	
	match context:
		"attack_roll":
			rules.append({
				validate = func(state: Dictionary, value: int) -> bool:
					var max_bonus = state.get("attack_bonus", 0)
					return value <= (6 + max_bonus)
			})
		"damage_roll":
			rules.append({
				validate = func(state: Dictionary, value: int) -> bool:
					var weapon_damage = state.get("weapon_damage", 0)
					return value <= weapon_damage * 2
			})
		"defense_roll":
			rules.append({
				validate = func(state: Dictionary, value: int) -> bool:
					var max_defense = state.get("defense_value", 0)
					return value <= (6 + max_defense)
			})
	
	return rules

## Signal handlers
func _on_override_applied(value: int) -> void:
	if validate_override(active_context, value):
		override_applied.emit(active_context, value)
		if combat_resolver and combat_resolver.has_method("apply_override"):
			combat_resolver.apply_override(active_context, value)
	else:
		# TODO: Show validation error
		pass

func _on_override_cancelled() -> void:
	override_cancelled.emit(active_context)
	active_context = ""

func _on_combat_override_requested(context: String, current_value: int) -> void:
	request_override(context, current_value)

func _on_dice_roll_completed(context: String, value: int) -> void:
	if active_context == context and override_panel and override_panel.has_method("hide"):
		override_panel.hide()

func _on_combat_state_changed(_new_state: Dictionary) -> void:
	# Update any active override validations
	if not active_context.is_empty() and override_panel:
		var current_value = 0
		
		# Try to get the current value safely
		var spinbox = override_panel.get_node_or_null("override_value_spinbox")
		if spinbox and spinbox is SpinBox:
			current_value = spinbox.value
		
		if not validate_override(active_context, current_value) and override_panel.has_method("hide"):
			override_panel.hide()

func _on_override_validation_requested(context: String, value: int) -> bool:
	return validate_override(context, value)
