@tool
extends PanelContainer
class_name EnemyIntentPanel

## Enemy Intent Display - Shows AI behavior and targeting
## Provides transparency into enemy decision-making for tactical play

signal intent_revealed(enemy_id: String, intent: Dictionary)
signal target_highlighted(target_id: String)

# Design system constants
const SPACING_SM: int = 8
const SPACING_MD: int = 16
const SPACING_LG: int = 24
const TOUCH_TARGET_MIN: int = 48
const FONT_SIZE_SM: int = 14
const FONT_SIZE_MD: int = 16
const FONT_SIZE_LG: int = 18

const COLOR_ELEVATED: Color = Color("#252542")
const COLOR_BORDER: Color = Color("#3A3A5C")
const COLOR_ACCENT: Color = Color("#2D5A7B")
const COLOR_DANGER: Color = Color("#DC2626")
const COLOR_TEXT_PRIMARY: Color = Color("#E0E0E0")
const COLOR_TEXT_SECONDARY: Color = Color("#808080")

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

# UI references
var header_label: Label
var intents_container: VBoxContainer
var ai_type_label: Label

func _ready() -> void:
	_setup_ui()

func _setup_ui() -> void:
	# Panel styling
	custom_minimum_size = Vector2(280, 180)

	var style_box := StyleBoxFlat.new()
	style_box.bg_color = COLOR_ELEVATED
	style_box.border_color = COLOR_BORDER
	style_box.set_border_width_all(1)
	style_box.set_corner_radius_all(4)
	style_box.set_content_margin_all(SPACING_MD)
	add_theme_stylebox_override("panel", style_box)

	# Main container
	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", SPACING_MD)
	add_child(main_vbox)

	# Header
	header_label = Label.new()
	header_label.text = "Enemy Intentions"
	header_label.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	header_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	main_vbox.add_child(header_label)

	# Intents container (scrollable for many enemies)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(scroll)

	intents_container = VBoxContainer.new()
	intents_container.add_theme_constant_override("separation", SPACING_SM)
	intents_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(intents_container)

	# AI type label
	ai_type_label = Label.new()
	ai_type_label.text = "AI: %s" % _ai_behavior_type
	ai_type_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	ai_type_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	main_vbox.add_child(ai_type_label)

func set_enemy_intents(intents: Array) -> void:
	"""Set all enemy intents for display"""
	_enemy_intents.clear()
	for intent in intents:
		_enemy_intents.append(intent)
	_update_intents_display()

	# Emit signal for each revealed intent
	for intent in _enemy_intents:
		intent_revealed.emit(intent.get("enemy_id", ""), intent)

func update_enemy_intent(enemy_id: String, intent_type: IntentType, target_id: String = "", target_name: String = "") -> void:
	"""Update specific enemy's intent"""
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
	"""Set the AI behavior type label"""
	_ai_behavior_type = behavior
	if ai_type_label:
		ai_type_label.text = "AI: %s" % behavior

func clear_intents() -> void:
	"""Clear all displayed intents"""
	_enemy_intents.clear()
	_update_intents_display()

func _update_intents_display() -> void:
	"""Rebuild the intents list"""
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
	"""Create UI row for single enemy intent"""
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
		target_label.text = "→ %s" % intent.get("target_name", "Target")
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
	"""Get emoji icon for intent type"""
	match intent_type:
		IntentType.MOVE:
			return "🏃"
		IntentType.ATTACK:
			return "⚔️"
		IntentType.DEFEND:
			return "🛡️"
		IntentType.FLEE:
			return "💨"
		_:
			return "❓"

func _get_intent_description(intent_type: IntentType) -> String:
	"""Get tooltip description for intent type"""
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
