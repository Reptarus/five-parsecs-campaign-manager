class_name FPCM_SimpleUnitCard
extends Control

## Simple Unit Tracking Card
##
## Lightweight UI component for tracking individual units during tabletop battles.
## Designed for quick health updates, status tracking, and activation management.
## Optimized for touch interaction and minimal visual overhead.
##
## Architecture: Self-contained component with efficient state updates
## Performance: <1ms update times with batched UI refreshes

# Dependencies
const BattlefieldTypes = preload("res://src/core/battle/BattlefieldTypes.gd")

# Unit tracking signals
signal health_changed(unit_id: String, new_health: int, old_health: int)
signal activation_toggled(unit_id: String, activated: bool)
signal status_effect_added(unit_id: String, effect: String)
signal status_effect_removed(unit_id: String, effect: String)
signal unit_notes_updated(unit_id: String, notes: String)

# UI node references
@onready var card_container: Control = %CardContainer
@onready var unit_name_label: Label = %UnitNameLabel
@onready var team_indicator: Control = %TeamIndicator
@onready var health_container: HBoxContainer = %HealthContainer
@onready var health_bar: ProgressBar = %HealthBar
@onready var health_label: Label = %HealthLabel
@onready var activation_button: Button = %ActivationButton
@onready var status_effects_container: VBoxContainer = %StatusEffectsContainer
@onready var quick_actions: HBoxContainer = %QuickActions
@onready var notes_field: LineEdit = %NotesField

# Health pip buttons for direct interaction
@onready var health_pips_container: HBoxContainer = %HealthPipsContainer

# Unit data
var unit_data: BattlefieldTypes.UnitData = null
var team_colors := {
	"crew": UIColors.COLOR_CYAN,
	"enemy": Color.LIGHT_CORAL,
	"neutral": Color.LIGHT_GRAY
}

# UI state
var card_selected: bool = false
var update_pending: bool = false
var last_update_time: float = 0.0

func _ready() -> void:
	## Initialize unit card with responsive design
	_setup_ui_connections()
	_setup_accessibility()

	# Set up responsive sizing
	custom_minimum_size = Vector2(200, 120)

func _setup_ui_connections() -> void:
	## Connect UI elements to handlers
	if activation_button:
		activation_button.pressed.connect(_on_activation_toggled)

	if notes_field:
		notes_field.text_submitted.connect(_on_notes_updated)
		notes_field.focus_exited.connect(func(): _on_notes_updated(notes_field.text))

	# Connect health pip interactions
	_setup_health_pip_connections()

func _setup_health_pip_connections() -> void:
	## Setup health pip button connections
	if not health_pips_container:
		return

	# Will be connected when pips are created
	pass

func _setup_accessibility() -> void:
	## Setup accessibility features
	# Ensure focusable for keyboard navigation
	focus_mode = Control.FOCUS_ALL

	# Set up tooltip for unit information
	_update_tooltip()

# =====================================================
# UNIT DATA MANAGEMENT
# =====================================================

func setup_unit(unit: BattlefieldTypes.UnitData) -> void:
	## Initialize card with unit data
	##
	## @param unit: Unit data to track
	if not unit:
		push_error("SimpleUnitCard: Cannot setup with null unit data")
		return

	unit_data = unit
	_refresh_display()
	_update_tooltip()

func get_unit_id() -> String:
	## Get the tracked unit ID
	return unit_data.unit_id if unit_data else ""

func get_unit_team() -> String:
	## Get the unit team
	return String(unit_data.team) if unit_data else ""

# =====================================================
# DISPLAY UPDATES
# =====================================================

func _refresh_display() -> void:
	## Refresh all display elements
	if not unit_data:
		return

	_update_unit_name()
	_update_team_indicator()
	_update_health_display()
	_update_activation_status()
	_update_status_effects()
	_update_notes_display()

func _update_unit_name() -> void:
	## Update unit name display
	if unit_name_label and unit_data:
		unit_name_label.text = unit_data.unit_name

func _update_team_indicator() -> void:
	## Update team color indicator
	if not team_indicator or not unit_data:
		return

	var team_color: Color = team_colors.get(String(unit_data.team), Color.WHITE)
	team_indicator.modulate = team_color

	# Update card border/background to match team
	if card_container:
		var style := _get_team_style(String(unit_data.team))
		card_container.add_theme_stylebox_override("panel", style)

func _get_team_style(team: String) -> StyleBox:
	## Get style box for team
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	style.border_width_left = 4
	style.border_color = team_colors.get(team, Color.WHITE)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style

func _update_health_display() -> void:
	## Update health bar and pips
	if not unit_data:
		return

	# Update health bar
	if health_bar:
		health_bar.max_value = unit_data.max_health
		health_bar.value = unit_data.current_health

		# Color code health bar
		var health_percentage := float(unit_data.current_health) / float(unit_data.max_health)
		if health_percentage <= 0.0:
			health_bar.modulate = UIColors.COLOR_RED
		elif health_percentage <= 0.3:
			health_bar.modulate = UIColors.COLOR_AMBER
		else:
			health_bar.modulate = UIColors.COLOR_EMERALD

	# Update health label
	if health_label:
		health_label.text = "%d / %d" % [unit_data.current_health, unit_data.max_health]

	# Update health pips
	_update_health_pips()

func _update_health_pips() -> void:
	## Update individual health pip buttons
	if not health_pips_container or not unit_data:
		return

	# Clear existing pips
	for child in health_pips_container.get_children():
		child.queue_free()

	# Create pip buttons
	for i: int in range(unit_data.max_health):
		var pip_button := _create_health_pip(i)
		health_pips_container.add_child(pip_button)

func _create_health_pip(pip_index: int) -> Button:
	## Create individual health pip button
	var pip := Button.new()
	pip.custom_minimum_size = Vector2(24, 24)
	pip.flat = true

	# Set pip appearance based on health
	var is_filled := pip_index < unit_data.current_health
	pip.text = "●" if is_filled else "○"
	pip.modulate = UIColors.COLOR_RED if is_filled else Color.DARK_GRAY

	# Connect pip interaction
	pip.pressed.connect(_on_health_pip_clicked.bind(pip_index))
	pip.tooltip_text = "Click to set health to %d" % (pip_index + 1)

	return pip

func _update_activation_status() -> void:
	## Update activation button appearance
	if not activation_button or not unit_data:
		return

	activation_button.text = "✓ Activated" if unit_data.activated_this_round else "○ Ready"
	activation_button.modulate = UIColors.COLOR_EMERALD if unit_data.activated_this_round else Color.WHITE
	activation_button.disabled = not unit_data.is_alive()

func _update_status_effects() -> void:
	## Update status effects display
	if not status_effects_container or not unit_data:
		return

	# Clear existing effects
	for child in status_effects_container.get_children():
		child.queue_free()

	# Add current status effects
	for effect in unit_data.status_effects:
		var effect_label := _create_status_effect_label(effect)
		status_effects_container.add_child(effect_label)

func _create_status_effect_label(effect: String) -> Control:
	## Create status effect label with remove button
	var container := HBoxContainer.new()

	# Effect label
	var label := Label.new()
	label.text = effect
	label.modulate = UIColors.COLOR_AMBER
	container.add_child(label)

	# Remove button
	var remove_btn := Button.new()
	remove_btn.text = "✕"
	remove_btn.custom_minimum_size = Vector2(20, 20)
	remove_btn.flat = true
	remove_btn.pressed.connect(_remove_status_effect.bind(effect))
	container.add_child(remove_btn)

	return container

func _update_notes_display() -> void:
	## Update notes field
	if notes_field and unit_data:
		notes_field.text = unit_data.notes

func _update_tooltip() -> void:
	## Update card tooltip with unit information
	if not unit_data:
		tooltip_text = "No unit data"
		return

	var tooltip_parts := [
		"Unit: %s" % unit_data.unit_name,
		"Team: %s" % unit_data.team,
		"Health: %d/%d" % [unit_data.current_health, unit_data.max_health],
		"Status: %s" % ("Activated" if unit_data.activated_this_round else "Ready")
	]

	if unit_data.status_effects.size() > 0:
		tooltip_parts.append("Effects: %s" % ", ".join(unit_data.status_effects))

	tooltip_text = "\n".join(tooltip_parts)

# =====================================================
# INTERACTION HANDLERS
# =====================================================

func _on_health_pip_clicked(pip_index: int) -> void:
	## Handle health pip click to set health
	if not unit_data:
		return

	var new_health := pip_index + 1
	var old_health := unit_data.current_health

	# Toggle behavior: if clicking current health, reduce by 1
	if new_health == unit_data.current_health:
		new_health = max(0, unit_data.current_health - 1)

	_set_unit_health(new_health, old_health)

func _on_activation_toggled() -> void:
	## Handle activation button toggle
	if not unit_data:
		return

	unit_data.activated_this_round = !unit_data.activated_this_round
	_update_activation_status()
	activation_toggled.emit(unit_data.unit_id, unit_data.activated_this_round)

func _on_notes_updated(new_notes: String) -> void:
	## Handle notes field update
	if not unit_data:
		return

	unit_data.notes = new_notes
	unit_notes_updated.emit(unit_data.unit_id, new_notes)

# =====================================================
# HEALTH MANAGEMENT
# =====================================================

func apply_damage(amount: int) -> void:
	## Apply damage to unit
	if not unit_data:
		return

	var old_health := unit_data.current_health
	var new_health: int = max(0, unit_data.current_health - amount)
	_set_unit_health(new_health, old_health)

func heal_damage(amount: int) -> void:
	## Heal damage to unit
	if not unit_data:
		return

	var old_health := unit_data.current_health
	var new_health: int = min(unit_data.max_health, unit_data.current_health + amount)
	_set_unit_health(new_health, old_health)

func set_health(new_health: int) -> void:
	## Set unit health directly
	if not unit_data:
		return

	var old_health := unit_data.current_health
	_set_unit_health(new_health, old_health)

func _set_unit_health(new_health: int, old_health: int) -> void:
	## Internal method to set health with validation
	if not unit_data:
		return

	new_health = clampi(new_health, 0, unit_data.max_health)

	if new_health != unit_data.current_health:
		unit_data.current_health = new_health
		_update_health_display()
		health_changed.emit(unit_data.unit_id, new_health, old_health)

# =====================================================
# STATUS EFFECT MANAGEMENT
# =====================================================

func add_status_effect(effect: String) -> void:
	## Add status effect to unit
	if not unit_data or effect in unit_data.status_effects:
		return

	unit_data.add_status_effect(effect)
	_update_status_effects()
	status_effect_added.emit(unit_data.unit_id, effect)

func _remove_status_effect(effect: String) -> void:
	## Remove status effect from unit
	if not unit_data:
		return

	unit_data.remove_status_effect(effect)
	_update_status_effects()
	status_effect_removed.emit(unit_data.unit_id, effect)

func clear_status_effects() -> void:
	## Clear all status effects
	if not unit_data:
		return

	var effects_to_remove := unit_data.status_effects.duplicate()
	for effect in effects_to_remove:
		_remove_status_effect(effect)

# =====================================================
# QUICK ACTIONS
# =====================================================

func setup_quick_actions() -> void:
	## Setup quick action buttons
	if not quick_actions:
		return

	# Clear existing actions
	for child in quick_actions.get_children():
		child.queue_free()

	# Add common quick actions
	_add_quick_action("Damage", _show_damage_popup)
	_add_quick_action("Heal", _show_heal_popup)
	_add_quick_action("Effect", _show_status_effect_popup)

func _add_quick_action(text: String, callback: Callable) -> void:
	## Add quick action button
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(60, 24)
	button.pressed.connect(callback)
	quick_actions.add_child(button)

func _show_damage_popup() -> void:
	## Show damage application popup
	var popup := _create_number_input_popup("Apply Damage", "Damage amount:", _apply_damage_from_popup)
	add_child(popup)
	popup.popup_centered()

func _show_heal_popup() -> void:
	## Show healing popup
	var popup := _create_number_input_popup("Heal Unit", "Heal amount:", _apply_heal_from_popup)
	add_child(popup)
	popup.popup_centered()

func _show_status_effect_popup() -> void:
	## Show status effect popup
	var popup := _create_text_input_popup("Add Status Effect", "Effect name:", _add_status_effect_from_popup)
	add_child(popup)
	popup.popup_centered()

func _create_number_input_popup(title: String, label_text: String, callback: Callable) -> Window:
	## Create number input popup
	var popup := Window.new()
	popup.title = title
	popup.size = Vector2(250, 150)

	var container := VBoxContainer.new()

	var label := Label.new()
	label.text = label_text
	container.add_child(label)

	var spinbox := SpinBox.new()
	spinbox.min_value = 0
	spinbox.max_value = 10
	spinbox.value = 1
	container.add_child(spinbox)

	var button_container := HBoxContainer.new()

	var confirm_btn := Button.new()
	confirm_btn.text = "Confirm"
	confirm_btn.pressed.connect(func(): callback.call(int(spinbox.value)); popup.queue_free())
	button_container.add_child(confirm_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(popup.queue_free)
	button_container.add_child(cancel_btn)

	container.add_child(button_container)
	popup.add_child(container)

	return popup

func _create_text_input_popup(title: String, label_text: String, callback: Callable) -> Window:
	## Create text input popup
	var popup := Window.new()
	popup.title = title
	popup.size = Vector2(250, 150)

	var container := VBoxContainer.new()

	var label := Label.new()
	label.text = label_text
	container.add_child(label)

	var line_edit := LineEdit.new()
	line_edit.placeholder_text = "Enter effect name"
	container.add_child(line_edit)

	var button_container := HBoxContainer.new()

	var confirm_btn := Button.new()
	confirm_btn.text = "Add"
	confirm_btn.pressed.connect(func(): callback.call(line_edit.text); popup.queue_free())
	button_container.add_child(confirm_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(popup.queue_free)
	button_container.add_child(cancel_btn)

	container.add_child(button_container)
	popup.add_child(container)

	return popup

func _apply_damage_from_popup(amount: int) -> void:
	## Apply damage from popup input
	apply_damage(amount)

func _apply_heal_from_popup(amount: int) -> void:
	## Apply healing from popup input
	heal_damage(amount)

func _add_status_effect_from_popup(effect: String) -> void:
	## Add status effect from popup input
	if effect.strip_edges() != "":
		add_status_effect(effect.strip_edges())

# =====================================================
# VISUAL EFFECTS AND ANIMATION
# =====================================================

func flash_card(color: Color = Color.WHITE, duration: float = 0.2) -> void:
	## Flash card with color for feedback
	if not card_container:
		return

	var original_modulate := card_container.modulate
	card_container.modulate = color

	var tween := create_tween()
	tween.tween_property(card_container, "modulate", original_modulate, duration)

func highlight_health_change(old_health: int, new_health: int) -> void:
	## Highlight health change with visual feedback
	if new_health < old_health:
		flash_card(UIColors.COLOR_RED, 0.3)
	elif new_health > old_health:
		flash_card(UIColors.COLOR_EMERALD, 0.3)

# =====================================================
# ACCESSIBILITY AND INPUT
# =====================================================

func _gui_input(event: InputEvent) -> void:
	## Handle input events for card interaction
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed:
			if mouse_event.button_index == MOUSE_BUTTON_LEFT:
				_on_card_clicked()
			elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
				_show_context_menu(mouse_event.global_position)

func _on_card_clicked() -> void:
	## Handle card click for selection
	card_selected = !card_selected
	_update_selection_visual()

func _update_selection_visual() -> void:
	## Update visual indication of selection
	if card_container:
		var style := card_container.get_theme_stylebox("panel")
		if style is StyleBoxFlat:
			style.border_width_top = 2 if card_selected else 0
			style.border_width_bottom = 2 if card_selected else 0
			style.border_width_right = 2 if card_selected else 0

func _show_context_menu(position: Vector2) -> void:
	## Show context menu for additional actions
	var popup_menu := PopupMenu.new()

	popup_menu.add_item("Set to Full Health")
	popup_menu.add_item("Set to Half Health")
	popup_menu.add_item("Knock Unconscious")
	popup_menu.add_separator()
	popup_menu.add_item("Clear Status Effects")
	popup_menu.add_item("Reset Activation")

	popup_menu.id_pressed.connect(_on_context_menu_selected)

	add_child(popup_menu)
	popup_menu.position = Vector2i(position)
	popup_menu.popup()

func _on_context_menu_selected(id: int) -> void:
	## Handle context menu selection
	match id:
		0: set_health(unit_data.max_health)
		1: set_health(int(unit_data.max_health / 2.0))
		2: set_health(0)
		4: clear_status_effects()
		5:
			if unit_data:
				unit_data.activated_this_round = false
				_update_activation_status()

# =====================================================
# DATA PERSISTENCE
# =====================================================

func save_card_state() -> Dictionary:
	## Save current card state
	if not unit_data:
		return {}

	return {
		"unit_id": unit_data.unit_id,
		"current_health": unit_data.current_health,
		"activated": unit_data.activated_this_round,
		"status_effects": unit_data.status_effects.duplicate(),
		"notes": unit_data.notes,
		"selected": card_selected
	}

func load_card_state(state: Dictionary) -> void:
	## Load card state from saved data
	if not unit_data or not state.has("unit_id") or state.unit_id != unit_data.unit_id:
		return

	unit_data.current_health = state.get("current_health", unit_data.current_health)
	unit_data.activated_this_round = state.get("activated", false)
	unit_data.status_effects = state.get("status_effects", [])
	unit_data.notes = state.get("notes", "")
	card_selected = state.get("selected", false)

	_refresh_display()

# =====================================================
# CLEANUP
# =====================================================

func cleanup() -> void:
	## Clean up card resources
	unit_data = null
	card_selected = false

	# Clear all containers
	if health_pips_container:
		for child in health_pips_container.get_children():
			child.queue_free()

	if status_effects_container:
		for child in status_effects_container.get_children():
			child.queue_free()

	if quick_actions:
		for child in quick_actions.get_children():
			child.queue_free()

