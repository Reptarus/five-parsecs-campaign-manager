@tool
extends PanelContainer
class_name EnemyIntentPanel

## Enemy Intent Display - Shows AI behavior and targeting
## Provides transparency into enemy decision-making for tactical play.
##
## Tier 3 (FULL_ORACLE): Adds oracle mode selector with three companion modes:
##   Reference - Shows AI type rules text from EnemyAI.json
##   D6 Table  - Player rolls d6 per group, lookup behavior table
##   Card Oracle - Draw card, interpret by suit/rank

signal intent_revealed(enemy_id: String, intent: Dictionary)
signal target_highlighted(target_id: String)
signal oracle_instruction_ready(group_name: String, instruction: String)

# Dependencies
const EnemyAIOracleRouterClass = preload("res://src/core/battle/EnemyAIOracleRouter.gd")

# Design system constants
const SPACING_SM: int = 8
const SPACING_MD: int = 16
const SPACING_LG: int = 24
const TOUCH_TARGET_MIN: int = 48
const FONT_SIZE_SM: int = 14
const FONT_SIZE_MD: int = 16
const FONT_SIZE_LG: int = 18

const COLOR_BASE: Color = UIColors.COLOR_BASE
const COLOR_ELEVATED: Color = UIColors.COLOR_ELEVATED
const COLOR_BORDER: Color = UIColors.COLOR_BORDER
const COLOR_ACCENT: Color = UIColors.COLOR_ACCENT
const COLOR_ACCENT_HOVER: Color = UIColors.COLOR_ACCENT_HOVER
const COLOR_DANGER: Color = UIColors.COLOR_DANGER
const COLOR_TEXT_PRIMARY: Color = UIColors.COLOR_TEXT_PRIMARY
const COLOR_TEXT_SECONDARY: Color = UIColors.COLOR_TEXT_SECONDARY
const COLOR_SUCCESS: Color = UIColors.COLOR_SUCCESS

# Intent types
enum IntentType {
	MOVE,
	ATTACK,
	DEFEND,
	FLEE,
	UNKNOWN
}

# Intent data
var _enemy_intents: Array[Dictionary] = []
var _ai_behavior_type: String = "Tactical"

# Oracle system
var _oracle_router: EnemyAIOracleRouterClass = null
var _enemy_groups: Array[Dictionary] = []  # [{name, ai_type, done}]
var _oracle_active: bool = false

# UI references - original intent display
var header_label: Label
var intents_container: VBoxContainer
var ai_type_label: Label

# UI references - oracle mode
var _main_vbox: VBoxContainer
var _oracle_container: VBoxContainer
var _mode_buttons: Array[Button] = []
var _oracle_output: VBoxContainer
var _oracle_scroll: ScrollContainer
var _group_list_container: VBoxContainer

func _ready() -> void:
	_setup_ui()

func _setup_ui() -> void:
	# Panel styling
	custom_minimum_size = Vector2(320, 200)

	var style_box := StyleBoxFlat.new()
	style_box.bg_color = COLOR_ELEVATED
	style_box.border_color = COLOR_BORDER
	style_box.set_border_width_all(1)
	style_box.set_corner_radius_all(4)
	style_box.set_content_margin_all(SPACING_MD)
	add_theme_stylebox_override("panel", style_box)

	# Main container
	_main_vbox = VBoxContainer.new()
	_main_vbox.add_theme_constant_override("separation", SPACING_MD)
	add_child(_main_vbox)

	# Header
	header_label = Label.new()
	header_label.text = "Enemy Intentions"
	header_label.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	header_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_main_vbox.add_child(header_label)

	# === Original intents container (scrollable for many enemies) ===
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_main_vbox.add_child(scroll)

	intents_container = VBoxContainer.new()
	intents_container.add_theme_constant_override("separation", SPACING_SM)
	intents_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(intents_container)

	# AI type label
	ai_type_label = Label.new()
	ai_type_label.text = "AI: %s" % _ai_behavior_type
	ai_type_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	ai_type_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	_main_vbox.add_child(ai_type_label)

	# === Oracle Mode UI (hidden until activated) ===
	_oracle_container = VBoxContainer.new()
	_oracle_container.add_theme_constant_override("separation", SPACING_SM)
	_oracle_container.visible = false
	_main_vbox.add_child(_oracle_container)

	_build_oracle_ui()

# =====================================================
# ORACLE MODE UI
# =====================================================

func _build_oracle_ui() -> void:
	# Mode selector row (3 tab-style buttons)
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 4)
	_oracle_container.add_child(mode_row)

	var mode_names: Array[String] = ["Reference", "D6 Table", "Card Oracle"]
	for i: int in range(mode_names.size()):
		var btn := Button.new()
		btn.text = mode_names[i]
		btn.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", FONT_SIZE_SM)
		btn.toggle_mode = true
		btn.button_pressed = (i == 0)
		btn.pressed.connect(_on_mode_button_pressed.bind(i))
		mode_row.add_child(btn)
		_mode_buttons.append(btn)

	# Enemy group list (player adds groups to query)
	_group_list_container = VBoxContainer.new()
	_group_list_container.add_theme_constant_override("separation", SPACING_SM)
	_oracle_container.add_child(_group_list_container)

	# Add Group button
	var add_group_btn := Button.new()
	add_group_btn.text = "+ Add Enemy Group"
	add_group_btn.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
	add_group_btn.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	add_group_btn.pressed.connect(_on_add_group_pressed)
	_oracle_container.add_child(add_group_btn)

	# Oracle output area (scrollable)
	var output_label := Label.new()
	output_label.text = "Instructions:"
	output_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	output_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	_oracle_container.add_child(output_label)

	_oracle_scroll = ScrollContainer.new()
	_oracle_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_oracle_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_oracle_scroll.custom_minimum_size = Vector2(0, 120)
	_oracle_container.add_child(_oracle_scroll)

	_oracle_output = VBoxContainer.new()
	_oracle_output.add_theme_constant_override("separation", SPACING_SM)
	_oracle_output.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_oracle_scroll.add_child(_oracle_output)

func _on_mode_button_pressed(mode_index: int) -> void:
	# Toggle-style: only one mode active at a time
	for i: int in range(_mode_buttons.size()):
		_mode_buttons[i].button_pressed = (i == mode_index)
	if _oracle_router:
		_oracle_router.set_mode(mode_index)

func _on_add_group_pressed() -> void:
	# Add a new enemy group with AI type selector
	var group_index: int = _enemy_groups.size()
	var group_name: String = "Enemy Group %s" % char(65 + group_index)  # A, B, C...

	var ai_types: Array[String] = []
	if _oracle_router:
		ai_types = _oracle_router.get_ai_types()
	if ai_types.is_empty():
		ai_types = ["Aggressive", "Cautious", "Tactical", "Defensive", "Beast", "Rampage", "Guardian"]

	var group_data: Dictionary = {"name": group_name, "ai_type": ai_types[0], "done": false}
	_enemy_groups.append(group_data)
	_build_group_row(group_data, group_index, ai_types)

func _build_group_row(group_data: Dictionary, index: int, ai_types: Array[String]) -> void:
	var row := HBoxContainer.new()
	row.name = "GroupRow_%d" % index
	row.add_theme_constant_override("separation", SPACING_SM)

	# Group name label
	var name_lbl := Label.new()
	name_lbl.text = group_data.name
	name_lbl.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	name_lbl.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name_lbl)

	# AI type dropdown
	var ai_dropdown := OptionButton.new()
	ai_dropdown.custom_minimum_size = Vector2(100, TOUCH_TARGET_MIN)
	ai_dropdown.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	for ai_name: String in ai_types:
		ai_dropdown.add_item(ai_name)
	ai_dropdown.item_selected.connect(_on_group_ai_changed.bind(index))
	row.add_child(ai_dropdown)

	# "Get Instruction" button
	var query_btn := Button.new()
	query_btn.text = "Go"
	query_btn.custom_minimum_size = Vector2(60, TOUCH_TARGET_MIN)
	query_btn.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	query_btn.pressed.connect(_on_query_group.bind(index))
	row.add_child(query_btn)

	_group_list_container.add_child(row)

func _on_group_ai_changed(item_index: int, group_index: int) -> void:
	if group_index < _enemy_groups.size():
		var ai_types: Array[String] = []
		if _oracle_router:
			ai_types = _oracle_router.get_ai_types()
		if ai_types.is_empty():
			ai_types = ["Aggressive", "Cautious", "Tactical", "Defensive", "Beast", "Rampage", "Guardian"]
		if item_index < ai_types.size():
			_enemy_groups[group_index].ai_type = ai_types[item_index]

func _on_query_group(group_index: int) -> void:
	if group_index >= _enemy_groups.size() or not _oracle_router:
		return

	var group: Dictionary = _enemy_groups[group_index]
	var result: Dictionary = _oracle_router.get_instruction(
		group.ai_type, group.name)

	# Display result in oracle output
	_display_oracle_result(result)

	# Mark group as done
	_enemy_groups[group_index].done = true

	# Emit signal
	oracle_instruction_ready.emit(group.name, result.get("instruction", ""))

func _display_oracle_result(result: Dictionary) -> void:
	# Create an instruction card in the output area
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 2)

	# Card background
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_BASE
	style.set_corner_radius_all(4)
	style.set_content_margin_all(SPACING_SM)
	style.set_border_width_all(1)
	style.border_color = COLOR_BORDER
	panel.add_theme_stylebox_override("panel", style)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 4)
	panel.add_child(inner)

	# Group + AI type header
	var header := Label.new()
	header.text = "%s (%s)" % [result.get("group", ""), result.get("ai_type", "")]
	header.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	header.add_theme_color_override("font_color", COLOR_ACCENT)
	inner.add_child(header)

	# Roll info (D6 mode)
	if result.get("roll", -1) >= 1:
		var roll_lbl := Label.new()
		roll_lbl.text = "Rolled: %d" % result.roll
		roll_lbl.add_theme_font_size_override("font_size", FONT_SIZE_SM)
		roll_lbl.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		inner.add_child(roll_lbl)

	# Card info (Card Oracle mode)
	var card_data: Dictionary = result.get("card", {})
	if not card_data.is_empty() and card_data.has("suit_name"):
		var card_lbl := Label.new()
		card_lbl.text = "Card: %s of %s" % [card_data.get("rank_name", ""), card_data.get("suit_name", "")]
		card_lbl.add_theme_font_size_override("font_size", FONT_SIZE_SM)
		card_lbl.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		inner.add_child(card_lbl)

	# Instruction text (the main output)
	var instruction_lbl := RichTextLabel.new()
	instruction_lbl.bbcode_enabled = true
	instruction_lbl.fit_content = true
	instruction_lbl.scroll_active = false
	instruction_lbl.add_theme_font_size_override("normal_font_size", FONT_SIZE_MD)
	instruction_lbl.add_theme_color_override("default_color", COLOR_TEXT_PRIMARY)
	instruction_lbl.text = result.get("instruction", "No instruction available.")
	inner.add_child(instruction_lbl)

	# "Done" button - player confirms they executed the instruction
	var done_btn := Button.new()
	done_btn.text = "Done - Applied on Table"
	done_btn.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
	done_btn.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	done_btn.pressed.connect(func():
		done_btn.text = "Applied"
		done_btn.disabled = true
		done_btn.add_theme_color_override("font_color", COLOR_SUCCESS)
	)
	inner.add_child(done_btn)

	card.add_child(panel)
	_oracle_output.add_child(card)

# =====================================================
# ORACLE ACTIVATION
# =====================================================

## Activate oracle mode (called when tier is FULL_ORACLE).
func activate_oracle() -> void:
	if _oracle_active:
		return
	_oracle_active = true
	_oracle_router = EnemyAIOracleRouterClass.new()

	# Show oracle UI, keep original intents visible too
	_oracle_container.visible = true
	header_label.text = "Enemy AI Oracle"

## Deactivate oracle mode.
func deactivate_oracle() -> void:
	_oracle_active = false
	_oracle_router = null
	_oracle_container.visible = false
	header_label.text = "Enemy Intentions"

	# Clear oracle state
	_enemy_groups.clear()
	for child in _group_list_container.get_children():
		child.queue_free()
	for child in _oracle_output.get_children():
		child.queue_free()

## Get the oracle router (for external save/load).
func get_oracle_router() -> EnemyAIOracleRouterClass:
	return _oracle_router

# =====================================================
# ORIGINAL INTENT DISPLAY METHODS (preserved)
# =====================================================

func set_enemy_intents(intents: Array) -> void:
	## Set all enemy intents for display
	_enemy_intents.clear()
	for intent in intents:
		_enemy_intents.append(intent)
	_update_intents_display()

	# Emit signal for each revealed intent
	for intent in _enemy_intents:
		intent_revealed.emit(intent.get("enemy_id", ""), intent)

func update_enemy_intent(enemy_id: String, intent_type: IntentType, target_id: String = "", target_name: String = "") -> void:
	## Update specific enemy's intent
	var found: bool = false
	for intent in _enemy_intents:
		if intent.get("enemy_id") == enemy_id:
			intent["type"] = intent_type
			intent["target_id"] = target_id
			intent["target_name"] = target_name
			found = true
			break

	if not found:
		# Create new intent entry
		_enemy_intents.append({
			"enemy_id": enemy_id,
			"enemy_name": "Enemy",
			"type": intent_type,
			"target_id": target_id,
			"target_name": target_name
		})

	_update_intents_display()

	# Emit target highlight if attacking
	if intent_type == IntentType.ATTACK and target_id != "":
		target_highlighted.emit(target_id)

func set_ai_behavior_type(behavior: String) -> void:
	## Set the AI behavior type label
	_ai_behavior_type = behavior
	if ai_type_label:
		ai_type_label.text = "AI: %s" % behavior

func clear_intents() -> void:
	## Clear all displayed intents
	_enemy_intents.clear()
	_update_intents_display()

func _update_intents_display() -> void:
	## Rebuild the intents list
	if not intents_container:
		return

	# Clear existing rows
	for child in intents_container.get_children():
		child.queue_free()

	# Show placeholder if no intents
	if _enemy_intents.is_empty():
		var placeholder := Label.new()
		placeholder.text = "No enemy intents detected"
		placeholder.add_theme_font_size_override("font_size", FONT_SIZE_SM)
		placeholder.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		intents_container.add_child(placeholder)
		return

	# Create row for each enemy
	for intent in _enemy_intents:
		var row := _create_intent_row(intent)
		intents_container.add_child(row)

func _create_intent_row(intent: Dictionary) -> HBoxContainer:
	## Create UI row for single enemy intent
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", SPACING_SM)
	row.custom_minimum_size.y = TOUCH_TARGET_MIN

	# Enemy name
	var name_label := Label.new()
	name_label.text = intent.get("enemy_name", "Enemy")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	name_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name_label)

	# Intent icon with tooltip
	var icon_label := Label.new()
	icon_label.text = _get_intent_icon(intent.get("type", IntentType.UNKNOWN))
	icon_label.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_label.tooltip_text = _get_intent_description(intent.get("type", IntentType.UNKNOWN))
	row.add_child(icon_label)

	# Target (if attacking or moving toward)
	var target_id: String = intent.get("target_id", "")
	if target_id != "":
		var target_label := Label.new()
		target_label.text = "-> %s" % intent.get("target_name", "Target")
		target_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
		target_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

		# Color based on intent type
		if intent.get("type") == IntentType.ATTACK:
			target_label.add_theme_color_override("font_color", COLOR_DANGER)
		else:
			target_label.add_theme_color_override("font_color", COLOR_ACCENT)

		row.add_child(target_label)

	return row

func _get_intent_icon(intent_type: IntentType) -> String:
	## Get text icon for intent type
	match intent_type:
		IntentType.MOVE:
			return "[M]"
		IntentType.ATTACK:
			return "[A]"
		IntentType.DEFEND:
			return "[D]"
		IntentType.FLEE:
			return "[F]"
		_:
			return "[?]"

func _get_intent_description(intent_type: IntentType) -> String:
	## Get tooltip description for intent type
	match intent_type:
		IntentType.MOVE:
			return "Moving to position"
		IntentType.ATTACK:
			return "Preparing to attack"
		IntentType.DEFEND:
			return "Taking defensive stance"
		IntentType.FLEE:
			return "Attempting to flee"
		_:
			return "Unknown intent"
