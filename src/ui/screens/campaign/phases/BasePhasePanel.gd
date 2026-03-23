extends Control
# This file should be referenced via preload
# Use explicit preloads instead of global class names

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

## Validation hint label — created by _setup_validation_hint() and shown/hidden
## by _show_validation_hint() / _hide_validation_hint().  Panels call these
## helpers whenever a primary-action button's disabled state changes.
var _validation_hint_label: Label = null

## Phase name lookup for breadcrumb display
const _PHASE_NAMES: Dictionary = {
	0: "", # NONE
	1: "Setup",
	2: "Story",
	3: "Travel",
	4: "Pre-Mission",
	5: "Mission",
	6: "Battle Setup",
	7: "Battle Resolution",
	8: "Post-Mission",
	9: "Upkeep",
	10: "Advancement",
	11: "Trading",
	12: "Character",
	13: "Retirement",
}

## Breadcrumb label shown at the top of each phase panel
var _breadcrumb_label: Label = null

## Base ready function
func _ready() -> void:
	game_state = get_node_or_null("/root/GameState")
	if not game_state:
		push_error("BasePhasePanel: GameState autoload not found")
	_apply_phase_theme()
	_setup_breadcrumb()

## Setup the phase panel
func setup_phase() -> void:
	# Base implementation - should be overridden by subclasses
	if not game_state:
		push_error("Cannot setup phase - no game state")
		return

	# Get the current phase from the game state
	current_phase = game_state.get_current_phase()
	_update_breadcrumb()

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

# ── Breadcrumb Infrastructure ─────────────────────────────────────

## Create a breadcrumb label and insert it at the top of the panel's VBoxContainer.
func _setup_breadcrumb() -> void:
	# Find the VBoxContainer child (all phase panels have one)
	var vbox: VBoxContainer = null
	for child in get_children():
		if child is VBoxContainer:
			vbox = child
			break
		# PanelContainer > VBoxContainer pattern
		if child is PanelContainer:
			for sub in child.get_children():
				if sub is VBoxContainer:
					vbox = sub
					break
	if not vbox:
		return

	_breadcrumb_label = Label.new()
	_breadcrumb_label.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_SM)
	_breadcrumb_label.add_theme_color_override("font_color", UIColors.COLOR_TEXT_MUTED)
	_breadcrumb_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	vbox.add_child(_breadcrumb_label)
	vbox.move_child(_breadcrumb_label, 0)
	_update_breadcrumb()

## Update the breadcrumb text with current turn and phase info.
func _update_breadcrumb() -> void:
	if not _breadcrumb_label:
		return
	var turn: int = 0
	if game_state and game_state.has_method("get_campaign_turn"):
		turn = game_state.get_campaign_turn()
	var phase_name: String = _PHASE_NAMES.get(current_phase, "")
	if phase_name.is_empty() and game_state:
		var phase_int: int = game_state.get_current_phase()
		phase_name = _PHASE_NAMES.get(phase_int, "Unknown")
	var parts: Array = []
	if turn > 0:
		parts.append("Turn %d" % turn)
	if not phase_name.is_empty():
		parts.append(phase_name)
	_breadcrumb_label.text = " > ".join(parts) if not parts.is_empty() else ""

# ── Formatting Helpers ────────────────────────────────────────────

## Format a credit amount with thousands separators: 1234 → "1,234"
func _format_credits(amount: int) -> String:
	var s: String = str(absi(amount))
	var result: String = ""
	var count: int = 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = s[i] + result
		count += 1
	return ("-" + result) if amount < 0 else result

## Format credits for inline display in lists: "150 cr"
func _format_credits_short(amount: int) -> String:
	return "%s cr" % _format_credits(amount)

## Format credits for detail/label display: "150 credits"
func _format_credits_long(amount: int) -> String:
	return "%s credits" % _format_credits(amount)

# ── KeywordDB Integration ─────────────────────────────────────────

## Set BBCode text on a RichTextLabel, auto-linking any recognized keywords.
## Also wires the meta_clicked signal so tapping a keyword shows its definition.
func _set_keyword_text(rtl: RichTextLabel, text: String) -> void:
	if not rtl:
		return
	var keyword_db = get_node_or_null("/root/KeywordDB")
	if keyword_db and keyword_db.has_method("parse_text_for_keywords"):
		rtl.text = keyword_db.parse_text_for_keywords(text)
	else:
		rtl.text = text
	# Wire signal only once
	if not rtl.meta_clicked.is_connected(_on_keyword_clicked):
		rtl.meta_clicked.connect(_on_keyword_clicked)

## Handle keyword link clicks — show a tooltip popup with the definition.
func _on_keyword_clicked(meta: Variant) -> void:
	var term: String = str(meta)
	var keyword_db = get_node_or_null("/root/KeywordDB")
	if not keyword_db or not keyword_db.has_method("get_keyword"):
		return
	var data: Dictionary = keyword_db.get_keyword(term)
	var definition: String = data.get("definition", "Unknown term")
	var related: Array = data.get("related", [])

	# Show as a temporary overlay panel
	var popup := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(UIColors.COLOR_SECONDARY.r, UIColors.COLOR_SECONDARY.g,
		UIColors.COLOR_SECONDARY.b, 0.97)
	style.border_color = UIColors.COLOR_CYAN
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(UIColors.SPACING_MD)
	popup.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	popup.add_child(vbox)

	var title_lbl := Label.new()
	title_lbl.text = data.get("term", term).capitalize()
	title_lbl.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_LG)
	title_lbl.add_theme_color_override("font_color", UIColors.COLOR_CYAN)
	vbox.add_child(title_lbl)

	var def_lbl := Label.new()
	def_lbl.text = definition
	def_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	def_lbl.custom_minimum_size = Vector2(250, 0)
	def_lbl.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_MD)
	def_lbl.add_theme_color_override("font_color", UIColors.COLOR_TEXT_PRIMARY)
	vbox.add_child(def_lbl)

	if not related.is_empty():
		var related_lbl := Label.new()
		related_lbl.text = "See also: " + ", ".join(related)
		related_lbl.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_SM)
		related_lbl.add_theme_color_override("font_color", UIColors.COLOR_TEXT_MUTED)
		vbox.add_child(related_lbl)

	# Close on any click
	var close_btn := Button.new()
	close_btn.text = "Close"
	_style_phase_button(close_btn)
	close_btn.pressed.connect(func(): popup.queue_free())
	vbox.add_child(close_btn)

	# Add as overlay to the scene tree
	popup.position = Vector2(UIColors.SPACING_XL, UIColors.SPACING_XL)
	var root_control = get_tree().root if get_tree() else null
	if root_control:
		root_control.add_child(popup)

# ── Theme Infrastructure ──────────────────────────────────────────

## Apply the Deep Space theme to this phase panel.
## Called automatically from _ready(). Override in subclasses to add
## panel-specific styling after calling super._ready().
## Ensures ALL phase panels have the correct COLOR_BASE background,
## whether they are PanelContainers or plain Controls.
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

	# Apply max-width constraint for desktop readability
	_apply_max_width_constraint()

	# Ensure a COLOR_BASE background exists behind this panel.
	# This prevents the default black/gray fallback on panels that
	# don't inherit a themed parent background.
	if not has_node("__phase_bg"):
		var bg := ColorRect.new()
		bg.name = "__phase_bg"
		bg.color = UIColors.COLOR_BASE
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.show_behind_parent = true
		add_child(bg)
		move_child(bg, 0)

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

	# Auto-apply disabled state styling for all phase buttons
	_style_button_disabled(button)

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

# ── Validation Hint Infrastructure ───────────────────────────────

## Create a validation hint label and insert it just before the given button.
## Call once in _ready() for each panel's primary action button.
func _setup_validation_hint(before_button: Button) -> void:
	if not before_button or _validation_hint_label:
		return
	_validation_hint_label = Label.new()
	_validation_hint_label.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_SM)
	_validation_hint_label.add_theme_color_override("font_color", Color("#D97706"))  # Amber warning
	_validation_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_validation_hint_label.visible = false
	# Insert before button in its parent container
	var parent = before_button.get_parent()
	if parent:
		var idx: int = before_button.get_index()
		parent.add_child(_validation_hint_label)
		parent.move_child(_validation_hint_label, idx)

## Show a validation hint message (e.g., "Not enough credits — need 12 to pay upkeep")
func _show_validation_hint(message: String) -> void:
	if _validation_hint_label:
		_validation_hint_label.text = message
		_validation_hint_label.visible = true

## Hide the validation hint
func _hide_validation_hint() -> void:
	if _validation_hint_label:
		_validation_hint_label.visible = false

## Apply a max-width constraint to the panel's main VBox
## so content doesn't stretch uncomfortably wide on desktop.
func _apply_max_width_constraint() -> void:
	var vbox: VBoxContainer = null
	for child in get_children():
		if child is VBoxContainer:
			vbox = child
			break
		if child is PanelContainer:
			for sub in child.get_children():
				if sub is VBoxContainer:
					vbox = sub
					break
	if vbox:
		vbox.custom_maximum_size.x = 1200
		vbox.size_flags_horizontal = (
			Control.SIZE_SHRINK_CENTER)

## Create a themed card container with a title header.
## Content is placed inside the card below the title separator.
func _create_phase_card(
	title: String, content: Control,
	description: String = ""
) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(
		UIColors.COLOR_SECONDARY.r,
		UIColors.COLOR_SECONDARY.g,
		UIColors.COLOR_SECONDARY.b, 0.8)
	style.border_color = Color(
		UIColors.COLOR_BORDER.r,
		UIColors.COLOR_BORDER.g,
		UIColors.COLOR_BORDER.b, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(UIColors.SPACING_MD)
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override(
		"separation", UIColors.SPACING_SM)

	var title_label := Label.new()
	title_label.text = title.to_upper()
	title_label.add_theme_font_size_override(
		"font_size", UIColors.FONT_SIZE_LG)
	title_label.add_theme_color_override(
		"font_color", UIColors.COLOR_TEXT_SECONDARY)
	vbox.add_child(title_label)

	var sep := HSeparator.new()
	sep.modulate = UIColors.COLOR_BORDER
	vbox.add_child(sep)

	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(content)

	if not description.is_empty():
		var desc := Label.new()
		desc.text = description
		desc.add_theme_font_size_override(
			"font_size", UIColors.FONT_SIZE_SM)
		desc.add_theme_color_override(
			"font_color", UIColors.COLOR_TEXT_MUTED)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(desc)

	panel.add_child(vbox)
	return panel

## Wrap an existing node in a phase card by reparenting it.
## Replaces the node at its current position in the tree.
func _wrap_in_phase_card(
	node: Control, title: String
) -> PanelContainer:
	if not node or not node.get_parent():
		return null
	var parent = node.get_parent()
	var idx = node.get_index()
	parent.remove_child(node)
	var card := _create_phase_card(title, node)
	parent.add_child(card)
	parent.move_child(card, idx)
	return card

## Style a disabled button with clearly reduced contrast for visual feedback
func _style_button_disabled(button: Button) -> void:
	if not button:
		return
	var disabled_style := StyleBoxFlat.new()
	disabled_style.bg_color = Color(UIColors.COLOR_TERTIARY.r, UIColors.COLOR_TERTIARY.g,
		UIColors.COLOR_TERTIARY.b, 0.2)
	disabled_style.border_color = Color(UIColors.COLOR_BORDER.r, UIColors.COLOR_BORDER.g,
		UIColors.COLOR_BORDER.b, 0.25)
	disabled_style.set_border_width_all(1)
	disabled_style.set_corner_radius_all(8)
	disabled_style.content_margin_left = UIColors.SPACING_MD
	disabled_style.content_margin_right = UIColors.SPACING_MD
	disabled_style.content_margin_top = UIColors.SPACING_SM
	disabled_style.content_margin_bottom = UIColors.SPACING_SM
	button.add_theme_stylebox_override("disabled", disabled_style)
	button.add_theme_color_override("font_disabled_color", Color("#4b5563"))
