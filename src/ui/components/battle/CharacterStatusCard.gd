class_name FPCM_CharacterStatusCard
extends PanelContainer

## Character Status Card - Battle Dashboard Component
##
## Displays real-time character status during battles with manual tracking.
## Shows health, stats, actions, and provides manual confirmation buttons
## for Five Parsecs tabletop-style combat.

# Signals for manual action confirmation
signal action_used(character_name: String, action_type: String)
signal damage_taken(character_name: String, amount: int)
signal stun_marked(character_name: String)
signal character_selected(character_name: String)

# Character data reference
var character_data: Dictionary = {}

# Status tracking
var current_health: int = 0
var max_health: int = 10
var stun_markers: int = 0
var actions_remaining: int = 2
var movement_remaining: int = 6
var _display_tier: int = 0 # 0=LOG_ONLY, 1=ASSISTED, 2=FULL_ORACLE
var _is_activated: bool = false

# UI References
@onready var name_label: Label = %CharacterName
@onready var stats_label: Label = %StatsDisplay
@onready var health_bar: ProgressBar = %HealthBar
@onready var health_text: Label = %HealthText
@onready var status_label: Label = %StatusLabel
@onready var action_container: HBoxContainer = %ActionContainer
@onready var stun_button: Button = %StunButton
@onready var damage_button: Button = %DamageButton
@onready var use_action_button: Button = %UseActionButton

func _ready() -> void:
	## Initialize card UI
	_connect_button_signals()

func _connect_button_signals() -> void:
	## Connect interactive button signals
	if stun_button:
		stun_button.pressed.connect(_on_stun_button_pressed)
	if damage_button:
		damage_button.pressed.connect(_on_damage_button_pressed)
	if use_action_button:
		use_action_button.pressed.connect(_on_use_action_button_pressed)

# =====================================================
# CHARACTER DATA SETUP
# =====================================================

func set_character_data(character) -> void:
	## Initialize card with character data (Dictionary or Character Resource)
	if character is Dictionary:
		character_data = character.duplicate()
	elif character != null and character.has_method("to_dictionary"):
		character_data = character.to_dictionary()
	else:
		push_warning("CharacterStatusCard: Invalid character data type: %s" % typeof(character))
		character_data = {}
		_update_display()
		return

	# Extract character stats using safe access
	var char_name: String = character_data.get("character_name", "Unknown")
	var combat: int = character_data.get("combat", 0)
	var toughness: int = character_data.get("toughness", 4)
	var speed: int = character_data.get("speed", 4)
	var savvy: int = character_data.get("savvy", 0)
	var reactions: int = character_data.get("reactions", 1)

	# Initialize health tracking
	max_health = character_data.get("max_health", 10)
	current_health = character_data.get("health", max_health)

	# Initialize action tracking
	actions_remaining = character_data.get("actions_remaining", 2)
	movement_remaining = character_data.get("movement_remaining", 6)
	stun_markers = character_data.get("stun_markers", 0)

	# Update display
	_update_display()

func _update_display() -> void:
	## Update all display elements
	if not is_node_ready():
		return

	var char_name: String = character_data.get("character_name", "Unknown")

	# Update name
	if name_label:
		name_label.text = char_name

	# Update stats display
	if stats_label:
		stats_label.text = "Combat: %d | Tough: %d | Speed: %d" % [
			character_data.get("combat", 0),
			character_data.get("toughness", 4),
			character_data.get("speed", 4)
		]

	# Update health bar
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health

		# Color code health bar
		if current_health <= 0:
			health_bar.modulate = Color.BLACK
		elif current_health <= max_health * 0.3:
			health_bar.modulate = UIColors.COLOR_RED
		elif current_health <= max_health * 0.6:
			health_bar.modulate = UIColors.COLOR_AMBER
		else:
			health_bar.modulate = UIColors.COLOR_EMERALD

	# Update health text
	if health_text:
		health_text.text = "%d / %d HP" % [current_health, max_health]

	# Update status label
	if status_label:
		var status_parts: Array[String] = []

		if stun_markers > 0:
			status_parts.append("Stunned: %d" % stun_markers)

		if actions_remaining >= 0:
			status_parts.append("Actions: %d" % actions_remaining)

		if current_health <= 0:
			status_parts.append("[CASUALTY]")
		elif stun_markers >= 3:
			status_parts.append("[OUT OF ACTION]")

		status_label.text = " | ".join(status_parts) if status_parts.size() > 0 else "Ready"

		# Color code status
		if current_health <= 0:
			status_label.modulate = UIColors.COLOR_RED
		elif stun_markers >= 3:
			status_label.modulate = UIColors.COLOR_AMBER
		else:
			status_label.modulate = UIColors.COLOR_TEXT_PRIMARY

# =====================================================
# STATUS UPDATES
# =====================================================

func apply_damage(amount: int) -> void:
	## Apply damage to character - manual confirmation
	current_health = max(0, current_health - amount)
	character_data["health"] = current_health

	_update_display()
	damage_taken.emit(character_data.get("character_name", ""), amount)

func add_stun_marker() -> void:
	## Add stun marker - Five Parsecs rules
	stun_markers += 1
	character_data["stun_markers"] = stun_markers

	_update_display()
	stun_marked.emit(character_data.get("character_name", ""))

func use_action() -> void:
	## Use one action - manual tracking
	if actions_remaining > 0:
		actions_remaining -= 1
		character_data["actions_remaining"] = actions_remaining

		_update_display()
		action_used.emit(character_data.get("character_name", ""), "generic_action")

func reset_round() -> void:
	## Reset per-round values - called at start of new round
	actions_remaining = character_data.get("max_actions", 2)
	movement_remaining = character_data.get("max_movement", 6)

	# Stun markers persist across rounds (Five Parsecs rules)
	character_data["actions_remaining"] = actions_remaining
	character_data["movement_remaining"] = movement_remaining

	_update_display()

func heal(amount: int) -> void:
	## Heal character
	current_health = min(max_health, current_health + amount)
	character_data["health"] = current_health

	_update_display()

func clear_stun() -> void:
	## Clear all stun markers
	stun_markers = 0
	character_data["stun_markers"] = 0

	_update_display()

# =====================================================
# QUERY METHODS
# =====================================================

func is_out_of_action() -> bool:
	## Check if character is out of action (casualty or 3+ stun markers)
	return current_health <= 0 or stun_markers >= 3

func is_casualty() -> bool:
	## Check if character is a casualty (health <= 0)
	return current_health <= 0

func can_take_actions() -> bool:
	## Check if character can take actions this round
	return not is_out_of_action() and actions_remaining > 0

func get_character_name() -> String:
	## Get character name
	return character_data.get("character_name", "")

func get_current_data() -> Dictionary:
	## Get current character data with all updates
	return character_data.duplicate()

# =====================================================
# BUTTON HANDLERS
# =====================================================

func _on_stun_button_pressed() -> void:
	## Handle Stun button press
	add_stun_marker()

func _on_damage_button_pressed() -> void:
	## Handle Damage button press - opens damage input dialog
	# TODO: Create DamageInputDialog for manual damage entry
	# For now, apply 1 damage
	apply_damage(1)

func _on_use_action_button_pressed() -> void:
	## Handle Use Action button press
	use_action()

# =====================================================
# VISUAL FEEDBACK
# =====================================================

func highlight() -> void:
	## Highlight card (for selection)
	modulate = Color(1.2, 1.2, 1.0)

func unhighlight() -> void:
	## Remove highlight
	modulate = Color.WHITE

func _on_gui_input(event: InputEvent) -> void:
	## Handle card click for selection
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			character_selected.emit(get_character_name())

# =====================================================
# TIER-AWARE DISPLAY
# =====================================================

## Set display tier to control what information is shown.
## Tier 0 (LOG_ONLY): Name + health, damage/stun buttons
## Tier 1 (ASSISTED): + Reactions, status effects, weapon, activated toggle
## Tier 2 (FULL_ORACLE): + AI-suggested action display
func set_display_tier(tier: int) -> void:
	_display_tier = tier
	_apply_tier_display()

func _apply_tier_display() -> void:
	if not is_node_ready():
		return

	# Tier 0: Basic - name + health + damage/stun buttons always visible
	# (these are the default visible elements)

	# Tier 1+: Show stats and status details
	if stats_label:
		if _display_tier >= 1:
			var reactions: int = character_data.get("reactions", 1)
			var savvy: int = character_data.get("savvy", 0)
			var weapon: String = character_data.get("weapon_name", "")
			stats_label.text = "Combat: %d | Tough: %d | React: %d | Savvy: %d" % [
				character_data.get("combat", 0),
				character_data.get("toughness", 4),
				reactions,
				savvy]
			if not weapon.is_empty():
				stats_label.text += "\nWeapon: %s" % weapon
		else:
			# Tier 0: minimal stats
			stats_label.text = "Combat: %d | Tough: %d" % [
				character_data.get("combat", 0),
				character_data.get("toughness", 4)]

	# Tier 1+: Show activation status
	if status_label and _display_tier >= 1:
		var status_parts: Array[String] = []
		if _is_activated:
			status_parts.append("[ACTIVATED]")
		if stun_markers > 0:
			status_parts.append("Stunned: %d" % stun_markers)
		if actions_remaining >= 0:
			status_parts.append("Actions: %d" % actions_remaining)
		if current_health <= 0:
			status_parts.append("[CASUALTY]")
		elif stun_markers >= 3:
			status_parts.append("[OUT OF ACTION]")

		status_label.text = " | ".join(status_parts) if status_parts.size() > 0 else "Ready"

## Mark this character as activated (Tier 1+ feature).
func set_activated(activated: bool) -> void:
	_is_activated = activated
	character_data["is_activated"] = activated
	if _display_tier >= 1:
		_apply_tier_display()

## Check if character has been activated this round.
func is_activated() -> bool:
	return _is_activated
