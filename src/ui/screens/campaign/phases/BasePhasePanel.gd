extends Control
# This file should be referenced via preload
# Use explicit preloads instead of global class names

const Self = preload("res://src/ui/screens/campaign/phases/BasePhasePanel.gd")
const FiveParsecsGameState = preload("res://src/core/state/GameState.gd")
const GameEnums = preload("res://src/core/enums/GameEnums.gd")
const GameStateManager = preload("res://src/core/managers/GameStateManager.gd")
const UIColors = preload("res://src/ui/components/base/UIColors.gd")

signal phase_completed(phase_data: Dictionary)
signal phase_failed(reason: String)

## The game state
var game_state: FiveParsecsGameState

## The current campaign phase
var current_phase: int = -1

## Base ready function
func _ready() -> void:
	game_state = get_node_or_null("/root/GameState")
	if not game_state:
		push_error("BasePhasePanel: GameState autoload not found")
	_apply_phase_theme()

## Setup the phase panel
func setup_phase() -> void:
	# Base implementation - should be overridden by subclasses
	if not game_state:
		push_error("Cannot setup phase - no game state")
		return

	# Get the current phase from the game state
	current_phase = game_state.get_current_phase()

## Validate that all requirements are met to proceed with this phase
func validate_phase_requirements() -> bool:
	# Base implementation - should be overridden by subclasses
	return game_state != null

## Complete the current phase
func complete_phase() -> void:
	if not game_state:
		push_error("Cannot complete phase - no game state")
		return

	# Save phase data before completing
	var phase_data = get_phase_data()

	# Emit completion signal
	phase_completed.emit(phase_data)

## Fail the current phase with a reason
func fail_phase(reason: String) -> void:
	phase_failed.emit(reason)

## Get phase data to pass to the next phase
func get_phase_data() -> Dictionary:
	# Base implementation - should be overridden by subclasses
	return {
		"phase": current_phase
	}

## Set phase data from the previous phase
func set_phase_data(_data: Dictionary) -> void:
	# Base implementation - should be overridden by subclasses
	pass

## Cleanup before removal - override in subclasses if needed
func cleanup() -> void:
	pass

# ── Theme Infrastructure ──────────────────────────────────────────

## Style the root PanelContainer with deep-space glass card appearance.
## Called automatically from _ready(). Override in subclasses to add
## panel-specific styling after calling super._ready().
func _apply_phase_theme() -> void:
	if is_class("PanelContainer"):
		var style := StyleBoxFlat.new()
		style.bg_color = Color(
			UIColors.COLOR_SECONDARY.r,
			UIColors.COLOR_SECONDARY.g,
			UIColors.COLOR_SECONDARY.b, 0.95
		)
		style.border_color = UIColors.COLOR_BORDER
		style.set_border_width_all(1)
		style.set_corner_radius_all(12)
		style.set_content_margin_all(UIColors.SPACING_MD)
		add_theme_stylebox_override("panel", style)

## Style a button with deep-space accent theme
func _style_phase_button(button: Button, is_primary: bool = false) -> void:
	if not button:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = UIColors.COLOR_BLUE if is_primary else UIColors.COLOR_TERTIARY
	style.set_corner_radius_all(8)
	style.content_margin_left = UIColors.SPACING_MD
	style.content_margin_right = UIColors.SPACING_MD
	style.content_margin_top = UIColors.SPACING_SM
	style.content_margin_bottom = UIColors.SPACING_SM
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_MD)
	button.add_theme_color_override("font_color", UIColors.COLOR_TEXT_PRIMARY)
	button.custom_minimum_size = Vector2(0, UIColors.TOUCH_TARGET_MIN)
	var hover := style.duplicate()
	hover.bg_color = UIColors.COLOR_ACCENT_HOVER if is_primary \
		else Color(
			UIColors.COLOR_TERTIARY.r + 0.1,
			UIColors.COLOR_TERTIARY.g + 0.1,
			UIColors.COLOR_TERTIARY.b + 0.1
		)
	button.add_theme_stylebox_override("hover", hover)
	var pressed := style.duplicate()
	pressed.bg_color = Color(
		style.bg_color.r - 0.1,
		style.bg_color.g - 0.1,
		style.bg_color.b - 0.1
	)
	button.add_theme_stylebox_override("pressed", pressed)

## Style a title label (panel titles)
func _style_phase_title(label: Label) -> void:
	if not label:
		return
	label.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_XL)
	label.add_theme_color_override("font_color", UIColors.COLOR_TEXT_PRIMARY)

## Style a section label (sub-headers)
func _style_section_label(label: Label) -> void:
	if not label:
		return
	label.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_LG)
	label.add_theme_color_override("font_color", UIColors.COLOR_TEXT_SECONDARY)

## Style a sub-panel with elevated card appearance
func _style_sub_panel(panel: PanelContainer) -> void:
	if not panel:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = UIColors.COLOR_TERTIARY
	style.border_color = UIColors.COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(UIColors.SPACING_SM)
	panel.add_theme_stylebox_override("panel", style)

## Style an ItemList with deep-space colors
func _style_item_list(item_list: ItemList) -> void:
	if not item_list:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = UIColors.COLOR_PRIMARY
	style.border_color = UIColors.COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(UIColors.SPACING_SM)
	item_list.add_theme_stylebox_override("panel", style)
	item_list.add_theme_color_override("font_color", UIColors.COLOR_TEXT_PRIMARY)
	item_list.add_theme_color_override("font_selected_color", UIColors.COLOR_CYAN)

## Style a RichTextLabel
func _style_rich_text(rtl: RichTextLabel) -> void:
	if not rtl:
		return
	rtl.add_theme_color_override("default_color", UIColors.COLOR_TEXT_PRIMARY)
	rtl.add_theme_font_size_override("normal_font_size", UIColors.FONT_SIZE_MD)
