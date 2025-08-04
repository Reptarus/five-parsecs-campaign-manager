extends PanelContainer

## Five Parsecs Character Box UI Component
## Compact display widget for character information in lists/grids

# Safe imports
# GlobalEnums available as autoload singleton
const Character = preload("res://src/core/character/Character.gd")
# Removed PortraitManager dependency - using simple Godot-native image loading

# UI Components
@onready var portrait: TextureRect = get_node("MarginContainer/HBoxContainer/PortraitContainer/Portrait")
@onready var name_label: Label = get_node("MarginContainer/HBoxContainer/InfoContainer/NameLabel")
@onready var class_label: Label = get_node("MarginContainer/HBoxContainer/InfoContainer/ClassLabel")

# Stat value labels
@onready var reactions_value: Label = get_node("MarginContainer/HBoxContainer/InfoContainer/StatsContainer/ReactionsValue")
@onready var speed_value: Label = get_node("MarginContainer/HBoxContainer/InfoContainer/StatsContainer/SpeedValue")
@onready var combat_skill_value: Label = get_node("MarginContainer/HBoxContainer/InfoContainer/StatsContainer/CombatSkillValue")
@onready var toughness_value: Label = get_node("MarginContainer/HBoxContainer/InfoContainer/StatsContainer/ToughnessValue")
@onready var savvy_value: Label = get_node("MarginContainer/HBoxContainer/InfoContainer/StatsContainer/SavvyValue")
@onready var luck_value: Label = get_node("MarginContainer/HBoxContainer/InfoContainer/StatsContainer/LuckValue")

# Status
@onready var status_value: Label = get_node("MarginContainer/HBoxContainer/InfoContainer/StatusContainer/StatusValue")

# State
var displayed_character: Character = null
var is_selected: bool = false
var is_selectable: bool = true

# Style colors
var normal_color: Color = Color.WHITE
var selected_color: Color = Color(0.3, 0.6, 1.0, 1.0) # Light blue
var hover_color: Color = Color(0.9, 0.9, 0.9, 1.0) # Light gray

signal character_selected(character: Character)
signal character_double_clicked(character: Character)
signal character_right_clicked(character: Character)

func _ready() -> void:
	print("CharacterBox: Initializing...")
	_setup_ui()
	_connect_signals()

func _setup_ui() -> void:
	"""Setup the character box UI"""
	# Set default state
	set_selected(false)
	_clear_display()

	# Make it clickable
	mouse_filter = Control.MOUSE_FILTER_PASS

func _connect_signals() -> void:
	"""Connect UI signals"""
	# Connect mouse input
	var _connect_result: int = gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _on_gui_input(event: InputEvent) -> void:
	"""Handle mouse input on character box"""
	if not is_selectable or not displayed_character:
		return

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton

		if mouse_event.pressed:
			match mouse_event.button_index:
				MOUSE_BUTTON_LEFT:
					if mouse_event.double_click:
						character_double_clicked.emit(displayed_character)
					else:
						character_selected.emit(displayed_character)

				MOUSE_BUTTON_RIGHT:
					character_right_clicked.emit(displayed_character)

func _on_mouse_entered() -> void:
	"""Handle mouse enter"""
	if is_selectable and not is_selected:
		modulate = hover_color

func _on_mouse_exited() -> void:
	"""Handle mouse exit"""
	if not is_selected:
		modulate = normal_color

func display_character(character: Character) -> void:
	"""Display character information in the box"""
	displayed_character = character

	if not character:
		_clear_display()
		return

	_update_character_display(character)
	print("CharacterBox: Displaying character: ", character.character_name)

func _update_character_display(character: Character) -> void:
	"""Update all character information displays"""
	# Basic info
	if name_label:
		name_label.text = character.character_name if character.character_name else "Unnamed"

	if class_label:
		class_label.text = "Character Class"

	# Stats
	if reactions_value:
		reactions_value.text = str(character.reaction)

	if speed_value:
		speed_value.text = str(character.speed)

	if combat_skill_value:
		combat_skill_value.text = str(character.combat)

	if toughness_value:
		toughness_value.text = str(character.toughness)

	if savvy_value:
		savvy_value.text = str(character.savvy)

	if luck_value:
		luck_value.text = str(character.luck)

	# Status
	_update_status_display(character)

	# Portrait (placeholder - would load actual portrait if available)
	_update_portrait_display(character)

func _update_status_display(character: Character) -> void:
	"""Update character status display"""
	if not status_value:
		return

	var status_text: String = "Healthy"
	var status_color: Color = Color.GREEN

	# Check health status
	if character.health <= 0:
		status_text = "Unconscious"
		status_color = Color.RED
	elif character.health < character.max_health:
		var health_percent: float = float(character.health) / float(character.max_health)
		if health_percent <= 0.25:
			status_text = "Critically Injured"
			status_color = Color.RED
		elif health_percent <= 0.5:
			status_text = "Heavily Injured"
			status_color = Color.ORANGE
		elif health_percent <= 0.75:
			status_text = "Lightly Injured"
			status_color = Color.YELLOW
		else:
			status_text = "Wounded"
			status_color = Color.ORANGE

	# Check for other status effects
	if character and character.has_method("has_status_effect"):
		if character.has_status_effect("stunned"):
			status_text = "Stunned"
			status_color = Color.PURPLE
		elif character.has_status_effect("medical_treatment"):
			status_text = "In Treatment"
			status_color = Color.CYAN

	status_value.text = status_text
	status_value.modulate = status_color

func _update_portrait_display(character: Character) -> void:
	"""Update character portrait display"""
	if not portrait:
		return

	# Simple Godot-native portrait loading - no over-engineered PortraitManager
	if character.portrait_path and not character.portrait_path.is_empty():
		var image = Image.load_from_file(character.portrait_path)
		if image and image.get_width() > 0:
			var portrait_texture = ImageTexture.create_from_image(image)
			portrait.texture = portrait_texture
			portrait.modulate = Color.WHITE
			return
		else:
			print("CharacterBox: Failed to load portrait from path: ", character.portrait_path)
	
	# Simple fallback to default portrait - no complex portrait management
	var default_portrait_path = "res://assets/portraits/default_character.png"
	if FileAccess.file_exists(default_portrait_path):
		portrait.texture = load(default_portrait_path)
		portrait.modulate = Color.WHITE
	else:
		# Final fallback - colored background based on class
		portrait.texture = null
		var bg_color: Color = Color.GRAY

		match character.character_class:
			GlobalEnums.CharacterClass.SOLDIER:
				bg_color = Color(0.8, 0.3, 0.3, 1.0) # Red-ish
			GlobalEnums.CharacterClass.SCOUT:
				bg_color = Color(0.3, 0.8, 0.3, 1.0) # Green-ish
			GlobalEnums.CharacterClass.MEDIC:
				bg_color = Color(0.3, 0.3, 0.8, 1.0) # Blue-ish
			GlobalEnums.CharacterClass.ENGINEER:
				bg_color = Color(0.8, 0.8, 0.3, 1.0) # Yellow-ish
			GlobalEnums.CharacterClass.PILOT:
				bg_color = Color(0.8, 0.3, 0.8, 1.0) # Purple-ish
			_:
				bg_color = Color.GRAY

		portrait.modulate = bg_color

func _clear_display() -> void:
	"""Clear all character information"""
	displayed_character = null

	if name_label:
		name_label.text = "No Character"

	if class_label:
		class_label.text = "---"

	# Clear stats
	var stat_labels: Array[Label] = [reactions_value, speed_value, combat_skill_value, toughness_value, savvy_value, luck_value]
	for label: Label in stat_labels:
		if label:
			label.text = "0"

	if status_value:
		status_value.text = "N/A"
		status_value.modulate = Color.GRAY

	if portrait:
		portrait.modulate = Color.GRAY

func set_selected(selected: bool) -> void:
	"""Set the selection state of this character box"""
	is_selected = selected

	if selected:
		modulate = selected_color
		# Add visual feedback like border or glow
		if has_theme_stylebox_override("panel"):
			var style: StyleBox = get_theme_stylebox("panel").duplicate()
			if style is StyleBoxFlat:
				var flat_style: StyleBoxFlat = style as StyleBoxFlat
				flat_style.border_color = selected_color
				flat_style.border_width_left = 2
				flat_style.border_width_right = 2
				flat_style.border_width_top = 2
				flat_style.border_width_bottom = 2
				add_theme_stylebox_override("panel", flat_style)
	else:
		modulate = normal_color
		# Remove selection visual feedback
		remove_theme_stylebox_override("panel")

func set_selectable(selectable: bool) -> void:
	"""Set whether this character box can be selected"""
	is_selectable = selectable
	mouse_filter = Control.MOUSE_FILTER_PASS if selectable else Control.MOUSE_FILTER_IGNORE

	if not selectable:
		modulate = Color(0.6, 0.6, 0.6, 1.0) # Grayed out
	else:
		modulate = normal_color if not is_selected else selected_color

func get_displayed_character() -> Character:
	"""Get the currently displayed character"""
	return displayed_character

func refresh_display() -> void:
	"""Refresh the character display"""
	if displayed_character:
		_update_character_display(displayed_character)

func set_size_mode(mode: String) -> void:
	"""Set the display size mode (compact, normal, detailed)"""
	match mode:
		"compact":
			custom_minimum_size = Vector2(200, 100)
			# Hide some details in compact mode
			if class_label:
				class_label.visible = false
		"normal":
			custom_minimum_size = Vector2(0, 150) # Default size
			if class_label:
				class_label.visible = true
		"detailed":
			custom_minimum_size = Vector2(300, 200)
			# Show additional details in detailed mode

func update_character_data(character: Character) -> void:
	"""Update character data and refresh display"""
	displayed_character = character
	refresh_display()

func highlight_character(highlight: bool) -> void:
	"""Temporarily highlight the character box"""
	if highlight:
		var tween: Tween = create_tween()
		tween.set_loops(3)
		tween.tween_property(self, "modulate", Color.YELLOW, 0.3)
		tween.tween_property(self, "modulate", normal_color, 0.3)
	else:
		modulate = normal_color if not is_selected else selected_color
## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null