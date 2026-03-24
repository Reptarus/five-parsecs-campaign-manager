class_name FPCM_ReactionRollAssignment
extends PanelContainer

## Interactive Reaction Roll Assignment — Core Rules p.112-113
##
## Each battle round, roll D6 per crew member, then the PLAYER ASSIGNS dice
## to characters. Die <= Reactions = Quick Actions, die > Reactions = Slow Actions.
## Feral Impetuous rule: if exactly one 1 rolled, must assign it to a Feral character.

signal reaction_assignment_confirmed(assignments: Dictionary)

# Design tokens
const SPACING_SM: int = UIColors.SPACING_SM
const SPACING_MD: int = UIColors.SPACING_MD
const SPACING_LG: int = UIColors.SPACING_LG
const TOUCH_TARGET_MIN: int = UIColors.TOUCH_TARGET_MIN
const FONT_SIZE_SM: int = UIColors.FONT_SIZE_SM
const FONT_SIZE_MD: int = UIColors.FONT_SIZE_MD
const FONT_SIZE_LG: int = UIColors.FONT_SIZE_LG
const FONT_SIZE_XL: int = UIColors.FONT_SIZE_XL

const COLOR_BASE: Color = UIColors.COLOR_BASE
const COLOR_ELEVATED: Color = UIColors.COLOR_ELEVATED
const COLOR_INPUT: Color = UIColors.COLOR_INPUT
const COLOR_BORDER: Color = UIColors.COLOR_BORDER
const COLOR_ACCENT: Color = UIColors.COLOR_ACCENT
const COLOR_TEXT_PRIMARY: Color = UIColors.COLOR_TEXT_PRIMARY
const COLOR_TEXT_SECONDARY: Color = UIColors.COLOR_TEXT_SECONDARY

# State
var _crew: Array = []        # Array of character dictionaries
var _dice_values: Array[int] = []     # Rolled dice values
var _assignments: Dictionary = {}     # char_name -> { die_value, action_type }
var _unassigned_dice: Array[int] = [] # Indices of unassigned dice
var _selected_die_index: int = -1     # Currently selected die for assignment
var _has_feral: bool = false          # Crew includes a Feral character
var _feral_name: String = ""          # Name of the Feral character
var _rng := RandomNumberGenerator.new()

# UI node references
var _title_label: Label
var _dice_container: HBoxContainer
var _crew_container: VBoxContainer
var _crew_scroll: ScrollContainer
var _roll_button: Button
var _confirm_button: Button
var _reset_button: Button
var _status_label: RichTextLabel
var _dice_buttons: Array[Button] = []
var _crew_buttons: Array[Button] = []

func _ready() -> void:
	_rng.seed = Time.get_unix_time_from_system()
	if is_inside_tree():
		_setup_ui()

# =====================================================
# PUBLIC API
# =====================================================

func set_crew(crew: Array) -> void:
	_crew = crew
	_has_feral = false
	_feral_name = ""
	for char_data: Dictionary in _crew:
		var species: String = str(char_data.get("species", "")).to_lower()
		if species == "feral":
			_has_feral = true
			_feral_name = str(char_data.get("character_name", char_data.get("name", "")))
			break
	reset()

func reset() -> void:
	_dice_values.clear()
	_assignments.clear()
	_unassigned_dice.clear()
	_selected_die_index = -1
	_rebuild_crew_buttons()
	_clear_dice_display()
	_update_status("Press 'Roll Reaction Dice' to begin the round.")
	if _roll_button:
		_roll_button.disabled = false
	if _confirm_button:
		_confirm_button.disabled = true

# =====================================================
# UI CONSTRUCTION
# =====================================================

func _setup_ui() -> void:
	custom_minimum_size = Vector2(420, 400)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = COLOR_ELEVATED
	panel_style.set_corner_radius_all(8)
	panel_style.border_color = COLOR_BORDER
	panel_style.border_width_left = 1
	panel_style.border_width_right = 1
	panel_style.border_width_top = 1
	panel_style.border_width_bottom = 1
	panel_style.content_margin_left = SPACING_MD
	panel_style.content_margin_right = SPACING_MD
	panel_style.content_margin_top = SPACING_MD
	panel_style.content_margin_bottom = SPACING_MD
	add_theme_stylebox_override("panel", panel_style)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", SPACING_SM)
	add_child(main_vbox)

	# Title
	_title_label = Label.new()
	_title_label.text = "Reaction Roll Assignment"
	_title_label.add_theme_font_size_override("font_size", FONT_SIZE_XL)
	_title_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(_title_label)

	# Roll button
	_roll_button = Button.new()
	_roll_button.text = "Roll Reaction Dice"
	_roll_button.custom_minimum_size.y = TOUCH_TARGET_MIN
	var roll_style := StyleBoxFlat.new()
	roll_style.bg_color = COLOR_ACCENT
	roll_style.set_corner_radius_all(6)
	_roll_button.add_theme_stylebox_override("normal", roll_style)
	_roll_button.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	_roll_button.pressed.connect(_on_roll_pressed)
	main_vbox.add_child(_roll_button)

	# Dice display area
	var dice_label := Label.new()
	dice_label.text = "Dice (tap to select, then tap a character to assign):"
	dice_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	dice_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	main_vbox.add_child(dice_label)

	_dice_container = HBoxContainer.new()
	_dice_container.add_theme_constant_override("separation", SPACING_SM)
	_dice_container.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(_dice_container)

	main_vbox.add_child(HSeparator.new())

	# Character assignment list
	_crew_scroll = ScrollContainer.new()
	_crew_scroll.custom_minimum_size = Vector2(0, 160)
	_crew_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(_crew_scroll)

	_crew_container = VBoxContainer.new()
	_crew_container.add_theme_constant_override("separation", 4)
	_crew_scroll.add_child(_crew_container)

	# Status display
	_status_label = RichTextLabel.new()
	_status_label.bbcode_enabled = true
	_status_label.fit_content = true
	_status_label.custom_minimum_size = Vector2(0, 40)
	_status_label.scroll_active = false
	_status_label.add_theme_font_size_override("normal_font_size", FONT_SIZE_SM)
	_status_label.add_theme_color_override("default_color", COLOR_TEXT_PRIMARY)
	main_vbox.add_child(_status_label)

	# Button row
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", SPACING_SM)
	main_vbox.add_child(btn_row)

	_reset_button = Button.new()
	_reset_button.text = "Reset"
	_reset_button.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
	_reset_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reset_button.pressed.connect(func(): reset())
	btn_row.add_child(_reset_button)

	_confirm_button = Button.new()
	_confirm_button.text = "Confirm Assignments"
	_confirm_button.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
	_confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm_button.disabled = true
	var confirm_style := StyleBoxFlat.new()
	confirm_style.bg_color = UIColors.COLOR_EMERALD
	confirm_style.set_corner_radius_all(6)
	_confirm_button.add_theme_stylebox_override("normal", confirm_style)
	_confirm_button.pressed.connect(_on_confirm_pressed)
	btn_row.add_child(_confirm_button)

# =====================================================
# DICE ROLLING
# =====================================================

func _on_roll_pressed() -> void:
	var active_crew: Array = _crew.filter(func(c: Dictionary) -> bool:
		return c.get("health", 1) > 0 and c.get("stun_markers", 0) < 3)

	if active_crew.is_empty():
		_update_status("[color=#DC2626]No active crew members to roll for.[/color]")
		return

	_dice_values.clear()
	_assignments.clear()
	_unassigned_dice.clear()

	# Roll D6 per active crew member
	for i: int in range(active_crew.size()):
		_dice_values.append(_rng.randi_range(1, 6))
		_unassigned_dice.append(i)

	_roll_button.disabled = true
	_selected_die_index = -1

	# Feral Impetuous rule (Core Rules p.112):
	# If exactly one 1 rolled, it MUST be assigned to a Feral character
	var ones_count: int = _dice_values.count(1)
	var feral_warning: String = ""
	if _has_feral and ones_count == 1:
		feral_warning = "\n[color=#D97706]Feral Impetuous: The single 1 must go to %s![/color]" % _feral_name

	_rebuild_dice_display()
	_rebuild_crew_buttons()
	_update_status("Rolled %d dice: %s%s\nTap a die, then tap a character to assign it." % [
		_dice_values.size(), str(_dice_values), feral_warning])

# =====================================================
# ASSIGNMENT LOGIC
# =====================================================

func _on_die_selected(die_index: int) -> void:
	if die_index not in _unassigned_dice:
		return
	_selected_die_index = die_index
	_highlight_selected_die()
	_update_status("Die [b]%d[/b] selected. Tap a character to assign." % _dice_values[die_index])

func _on_character_assign(char_name: String) -> void:
	if _selected_die_index < 0:
		_update_status("[color=#D97706]Select a die first![/color]")
		return

	var die_value: int = _dice_values[_selected_die_index]

	# Feral Impetuous enforcement
	if _has_feral and _dice_values.count(1) == 1 and die_value == 1:
		if char_name != _feral_name:
			_update_status("[color=#DC2626]Feral Impetuous rule: the single 1 must go to %s![/color]" % _feral_name)
			return

	# Find character's Reactions stat
	var reactions: int = 1
	for char_data: Dictionary in _crew:
		var name_val: String = str(char_data.get("character_name", char_data.get("name", "")))
		if name_val == char_name:
			reactions = char_data.get("reactions", char_data.get("reaction", 1))
			break

	var action_type: String = "quick" if die_value <= reactions else "slow"

	# Remove any previous assignment for this character
	if char_name in _assignments:
		var prev_die: int = _assignments[char_name]["die_index"]
		if prev_die not in _unassigned_dice:
			_unassigned_dice.append(prev_die)

	_assignments[char_name] = {
		"die_value": die_value,
		"die_index": _selected_die_index,
		"action_type": action_type,
		"reactions": reactions,
	}

	_unassigned_dice.erase(_selected_die_index)
	_selected_die_index = -1

	_rebuild_dice_display()
	_rebuild_crew_buttons()

	var color: String = "#10B981" if action_type == "quick" else "#D97706"
	_update_status("[color=%s]%s assigned die %d → %s Actions (Reactions: %d)[/color]" % [
		color, char_name, die_value, action_type.to_upper(), reactions])

	# Enable confirm when all dice assigned
	_confirm_button.disabled = not _unassigned_dice.is_empty()

func _on_confirm_pressed() -> void:
	# Build clean assignments dict (without internal tracking data)
	var clean: Dictionary = {}
	for char_name: String in _assignments:
		clean[char_name] = {
			"die_value": _assignments[char_name]["die_value"],
			"action_type": _assignments[char_name]["action_type"],
		}
	reaction_assignment_confirmed.emit(clean)

# =====================================================
# UI UPDATES
# =====================================================

func _clear_dice_display() -> void:
	for child: Node in _dice_container.get_children():
		child.queue_free()
	_dice_buttons.clear()

func _rebuild_dice_display() -> void:
	_clear_dice_display()

	for i: int in range(_dice_values.size()):
		var btn := Button.new()
		btn.text = str(_dice_values[i])
		btn.custom_minimum_size = Vector2(52, 52)
		btn.add_theme_font_size_override("font_size", FONT_SIZE_XL)

		var btn_style := StyleBoxFlat.new()
		btn_style.set_corner_radius_all(8)

		if i not in _unassigned_dice:
			# Already assigned — dim
			btn_style.bg_color = Color(0.3, 0.3, 0.3, 0.5)
			btn.disabled = true
		elif i == _selected_die_index:
			# Selected — highlight
			btn_style.bg_color = COLOR_ACCENT
		else:
			# Available
			btn_style.bg_color = COLOR_INPUT

		btn.add_theme_stylebox_override("normal", btn_style)
		btn.pressed.connect(_on_die_selected.bind(i))
		_dice_container.add_child(btn)
		_dice_buttons.append(btn)

func _highlight_selected_die() -> void:
	_rebuild_dice_display()

func _rebuild_crew_buttons() -> void:
	for child: Node in _crew_container.get_children():
		child.queue_free()
	_crew_buttons.clear()

	for char_data: Dictionary in _crew:
		# Skip out-of-action characters
		if char_data.get("health", 1) <= 0 or char_data.get("stun_markers", 0) >= 3:
			continue

		var char_name: String = str(char_data.get("character_name", char_data.get("name", "Unknown")))
		var reactions: int = char_data.get("reactions", char_data.get("reaction", 1))
		var species: String = str(char_data.get("species", ""))

		var btn := Button.new()
		btn.custom_minimum_size.y = 44
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

		var btn_style := StyleBoxFlat.new()
		btn_style.set_corner_radius_all(4)
		btn_style.content_margin_left = SPACING_SM

		if char_name in _assignments:
			var assignment: Dictionary = _assignments[char_name]
			var action_type: String = assignment["action_type"]
			var die_val: int = assignment["die_value"]
			if action_type == "quick":
				btn_style.bg_color = Color(0.06, 0.45, 0.32, 0.4)  # Green tint
				btn.text = "%s (R:%d) — Die: %d → QUICK" % [char_name, reactions, die_val]
			else:
				btn_style.bg_color = Color(0.55, 0.35, 0.0, 0.4)  # Orange tint
				btn.text = "%s (R:%d) — Die: %d → SLOW" % [char_name, reactions, die_val]
		else:
			btn_style.bg_color = COLOR_INPUT
			var feral_tag: String = " [Feral]" if species.to_lower() == "feral" else ""
			btn.text = "%s (Reactions: %d)%s" % [char_name, reactions, feral_tag]

		btn.add_theme_stylebox_override("normal", btn_style)
		btn.pressed.connect(_on_character_assign.bind(char_name))
		_crew_container.add_child(btn)
		_crew_buttons.append(btn)

func _update_status(text: String) -> void:
	if _status_label:
		_status_label.text = text
