extends PanelContainer
class_name MockCharacterCard

## Mock CharacterCard script for testing before UI implementation
## Provides minimal interface for test suite validation

# Signals expected by tests
signal card_tapped(character: Character)
signal view_details_pressed(character: Character)
signal edit_pressed(character: Character)
signal remove_pressed(character: Character)

# Variant constants
enum Variant {
	COMPACT = 0,
	STANDARD = 1,
	EXPANDED = 2
}

# State
var _character: Character = null
var _variant: Variant = Variant.STANDARD

# Mock UI nodes (minimal for testing)
var _name_label: Label
var _class_label: Label
var _combat_label: Label
var _reactions_label: Label
var _toughness_label: Label
var _xp_label: Label
var _view_button: Button
var _edit_button: Button
var _remove_button: Button

func _ready() -> void:
	"""Initialize mock UI nodes"""
	_create_mock_ui()
	_update_display()

# =====================================================
# PUBLIC API (matches expected interface)
# =====================================================

func set_character(character: Character) -> void:
	"""Set character data"""
	_character = character
	_update_display()

func get_character() -> Character:
	"""Get current character"""
	return _character

func set_variant(variant: Variant) -> void:
	"""Set display variant"""
	_variant = variant
	_update_size_for_variant()
	_update_display()

func get_variant() -> Variant:
	"""Get current variant"""
	return _variant

# =====================================================
# MOCK UI CREATION
# =====================================================

func _create_mock_ui() -> void:
	"""Create minimal mock UI structure for testing"""
	# Create labels
	_name_label = Label.new()
	_name_label.name = "CharacterName"
	add_child(_name_label)
	
	_class_label = Label.new()
	_class_label.name = "CharacterClass"
	add_child(_class_label)
	
	_combat_label = Label.new()
	_combat_label.name = "CombatStat"
	add_child(_combat_label)
	
	_reactions_label = Label.new()
	_reactions_label.name = "ReactionsStat"
	add_child(_reactions_label)
	
	_toughness_label = Label.new()
	_toughness_label.name = "ToughnessStat"
	add_child(_toughness_label)
	
	_xp_label = Label.new()
	_xp_label.name = "ExperienceLabel"
	add_child(_xp_label)
	
	# Create buttons with minimum touch target
	_view_button = Button.new()
	_view_button.name = "ViewDetailsButton"
	_view_button.text = "View Details"
	_view_button.custom_minimum_size = Vector2(0, 48)
	_view_button.pressed.connect(_on_view_button_pressed)
	add_child(_view_button)
	
	_edit_button = Button.new()
	_edit_button.name = "EditButton"
	_edit_button.text = "Edit"
	_edit_button.custom_minimum_size = Vector2(0, 48)
	_edit_button.pressed.connect(_on_edit_button_pressed)
	add_child(_edit_button)
	
	_remove_button = Button.new()
	_remove_button.name = "RemoveButton"
	_remove_button.text = "Remove"
	_remove_button.custom_minimum_size = Vector2(0, 48)
	_remove_button.pressed.connect(_on_remove_button_pressed)
	add_child(_remove_button)

func _update_size_for_variant() -> void:
	"""Update card size based on variant"""
	match _variant:
		Variant.COMPACT:
			custom_minimum_size = Vector2(200, 80)
		Variant.STANDARD:
			custom_minimum_size = Vector2(200, 120)
		Variant.EXPANDED:
			custom_minimum_size = Vector2(200, 160)

func _update_display() -> void:
	"""Update display based on character and variant"""
	if not _character:
		return
	
	# Update labels based on variant
	match _variant:
		Variant.COMPACT:
			_update_compact_display()
		Variant.STANDARD:
			_update_standard_display()
		Variant.EXPANDED:
			_update_expanded_display()

func _update_compact_display() -> void:
	"""Update display for COMPACT variant"""
	if _name_label:
		_name_label.text = _character.name
		_name_label.visible = true
	
	if _class_label:
		_class_label.text = _character.background  # Using background as class
		_class_label.visible = true
	
	# Hide stats in compact view
	if _combat_label:
		_combat_label.visible = false
	if _reactions_label:
		_reactions_label.visible = false
	if _toughness_label:
		_toughness_label.visible = false
	if _xp_label:
		_xp_label.visible = false

func _update_standard_display() -> void:
	"""Update display for STANDARD variant"""
	if _name_label:
		_name_label.text = _character.name
		_name_label.visible = true
	
	if _class_label:
		_class_label.text = _character.background
		_class_label.visible = true
	
	# Show basic stats
	if _combat_label:
		_combat_label.text = "Combat: %d" % _character.combat
		_combat_label.visible = true
	
	if _reactions_label:
		_reactions_label.text = "Reactions: %d" % _character.reactions
		_reactions_label.visible = true
	
	if _toughness_label:
		_toughness_label.text = "Toughness: %d" % _character.toughness
		_toughness_label.visible = true
	
	# Hide XP in standard view
	if _xp_label:
		_xp_label.visible = false

func _update_expanded_display() -> void:
	"""Update display for EXPANDED variant"""
	if _name_label:
		_name_label.text = _character.name
		_name_label.visible = true
	
	if _class_label:
		_class_label.text = _character.background
		_class_label.visible = true
	
	# Show all stats
	if _combat_label:
		_combat_label.text = "Combat: %d" % _character.combat
		_combat_label.visible = true
	
	if _reactions_label:
		_reactions_label.text = "Reactions: %d" % _character.reactions
		_reactions_label.visible = true
	
	if _toughness_label:
		_toughness_label.text = "Toughness: %d" % _character.toughness
		_toughness_label.visible = true
	
	# Show XP in expanded view
	if _xp_label:
		_xp_label.text = "XP: %d" % _character.experience
		_xp_label.visible = true

# =====================================================
# SIGNAL HANDLERS
# =====================================================

func _on_view_button_pressed() -> void:
	"""Handle view details button"""
	view_details_pressed.emit(_character)

func _on_edit_button_pressed() -> void:
	"""Handle edit button"""
	edit_pressed.emit(_character)

func _on_remove_button_pressed() -> void:
	"""Handle remove button"""
	remove_pressed.emit(_character)

func _gui_input(event: InputEvent) -> void:
	"""Handle card tap/click"""
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			card_tapped.emit(_character)
