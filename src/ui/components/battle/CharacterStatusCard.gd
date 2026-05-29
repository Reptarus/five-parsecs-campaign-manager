class_name FPCM_CharacterStatusCard
extends PanelContainer

## Character Status Card - Battle Dashboard Component
##
## Displays real-time character status during battles with manual tracking.
## Shows health, stats, actions, and provides manual confirmation buttons
## for Five Parsecs tabletop-style combat.

# Preload-based refs — global class_name cache can lag behind file edits
# (see CLAUDE.md "Preload Pattern for UI Class References").
const KeywordLinker = preload("res://src/ui/components/tooltips/KeywordLinker.gd")

# Modiphius official Planetfall token art (shared across all campaign modes).
# These are the 5 universal character-status tokens — triangle-shape = status
# effect per Modiphius's shape-encodes-rule-type convention.
const STATUS_TOKEN_PATHS := {
	"stunned":   "res://assets/tokens/token_stunned.png",
	"sprawling": "res://assets/tokens/token_sprawling.png",
	"aid":       "res://assets/tokens/token_aid.png",
	"activated": "res://assets/tokens/token_activated.png",
	"poison":    "res://assets/tokens/token_poison.png",
}
const STATUS_ICON_SIZE := 40

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

# Per-battle status tokens (Modiphius shape-coded triangles).
# stun_markers above already covers Stunned. _is_activated covers Activated.
var aid_markers: int = 0
var is_sprawling: bool = false
var is_poisoned: bool = false

# Status icon row built programmatically; nil until _ready() finishes.
var _status_icons_container: HBoxContainer = null
var _status_icon_nodes: Dictionary = {}

# Battle state tracking (Phase 4 — Snap Fire, Aim, Panic Fire)
var is_aiming: bool = false          # Didn't move, chose to aim (Core Rules p.46)
var is_holding_snap: bool = false    # Quick Action char holding for snap fire (p.113)
var has_panic_fired: bool = false    # Used panic fire — weapon empty rest of battle (p.46)

# Lazy keyword tooltip for inline stat-name popovers (Sprint 2 F2).
var _keyword_tooltip: KeywordTooltip = null

# UI References
@onready var name_label: Label = %CharacterName
@onready var stats_label: RichTextLabel = %StatsDisplay
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
	_build_status_icon_row()

func _connect_button_signals() -> void:
	## Connect interactive button signals
	if stun_button:
		stun_button.pressed.connect(_on_stun_button_pressed)
	if damage_button:
		damage_button.pressed.connect(_on_damage_button_pressed)
	if use_action_button:
		use_action_button.pressed.connect(_on_use_action_button_pressed)

	# Add Aim and Snap Fire toggle buttons to action container
	if action_container:
		var aim_btn := Button.new()
		aim_btn.text = "Aim"
		aim_btn.toggle_mode = true
		aim_btn.custom_minimum_size = Vector2(60, 44)
		aim_btn.tooltip_text = "Reroll 1s on hit dice (must not move, Core Rules p.46)"
		aim_btn.toggled.connect(_on_aim_toggled)
		action_container.add_child(aim_btn)

		var snap_btn := Button.new()
		snap_btn.text = "Snap"
		snap_btn.toggle_mode = true
		snap_btn.custom_minimum_size = Vector2(60, 44)
		snap_btn.tooltip_text = "Hold for Snap Fire during Enemy Actions (-1 hit, p.113)"
		snap_btn.toggled.connect(_on_snap_toggled)
		action_container.add_child(snap_btn)

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
	var char_name: String = character_data.get("character_name",
		character_data.get("name", "Unknown"))
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

	# Per-battle status tokens (round-trip with character_data dict)
	aid_markers = character_data.get("aid_markers", 0)
	is_sprawling = character_data.get("is_sprawling", false)
	is_poisoned = character_data.get("is_poisoned", false)
	_is_activated = character_data.get("is_activated", false)

	# Update display
	_update_display()

func _update_display() -> void:
	## Update all display elements
	if not is_node_ready():
		return

	var char_name: String = character_data.get("character_name",
		character_data.get("name", "Unknown"))

	# Update name
	if name_label:
		name_label.text = char_name

	# Update stats display — RichTextLabel with clickable keyword links
	# so a player can tap "Combat" / "Tough" / "Speed" for the rules tooltip.
	if stats_label:
		stats_label.text = _build_basic_stats_bbcode()
		_ensure_keyword_tooltip_attached()

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
			if stun_markers >= 3:
				status_parts.append("[KNOCKED OUT - 3+ Stuns]")
			else:
				status_parts.append("Stunned x%d (Move OR Combat, not both)" % stun_markers)

		if is_aiming:
			status_parts.append("[AIMING - reroll 1s]")
		if is_holding_snap:
			status_parts.append("[SNAP FIRE - waiting]")
		if has_panic_fired:
			status_parts.append("[WEAPON EMPTY]")

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

	_refresh_status_icons()

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

	# Reset per-round states (aim/snap fire reset each round)
	is_aiming = false
	is_holding_snap = false
	# Note: has_panic_fired persists for the entire battle (weapon stays empty)
	# Note: stun markers persist across rounds (Five Parsecs rules)

	character_data["actions_remaining"] = actions_remaining
	character_data["movement_remaining"] = movement_remaining
	character_data["is_aiming"] = false
	character_data["is_holding_snap"] = false

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
	# NOTE: Deferred — create DamageInputDialog for manual damage entry; defaults to 1
	apply_damage(1)

func _on_use_action_button_pressed() -> void:
	## Handle Use Action button press
	use_action()

func _on_aim_toggled(pressed: bool) -> void:
	## Toggle Aim state (Core Rules p.46: reroll 1s if didn't move)
	is_aiming = pressed
	if pressed:
		is_holding_snap = false  # Can't aim and snap fire simultaneously
	character_data["is_aiming"] = is_aiming
	character_data["is_holding_snap"] = is_holding_snap
	_update_display()
	action_used.emit(get_character_name(), "aim" if pressed else "aim_cancel")

func _on_snap_toggled(pressed: bool) -> void:
	## Toggle Snap Fire hold (Core Rules p.113: -1 to hit during enemy actions)
	is_holding_snap = pressed
	if pressed:
		is_aiming = false  # Can't snap fire and aim simultaneously
	character_data["is_holding_snap"] = is_holding_snap
	character_data["is_aiming"] = is_aiming
	_update_display()
	action_used.emit(get_character_name(), "snap_fire" if pressed else "snap_cancel")

func set_panic_fired() -> void:
	## Mark weapon as empty after Panic Fire (Core Rules p.46)
	has_panic_fired = true
	character_data["has_panic_fired"] = true
	_update_display()

func get_stun_markers() -> int:
	## Get stun marker count (used by brawl calculations: +1 per stun to attacker)
	return stun_markers

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

	# Tier 1+: Show stats and status details — BBCode with keyword links
	if stats_label:
		if _display_tier >= 1:
			stats_label.text = _build_tier1_stats_bbcode()
		else:
			# Tier 0: minimal stats
			stats_label.text = _build_basic_stats_bbcode()
		_ensure_keyword_tooltip_attached()

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

	_refresh_status_icons()

## Mark this character as activated (Tier 1+ feature).
func set_activated(activated: bool) -> void:
	_is_activated = activated
	character_data["is_activated"] = activated
	if _display_tier >= 1:
		_apply_tier_display()

## Check if character has been activated this round.
func is_activated() -> bool:
	return _is_activated

# =====================================================
# KEYWORD-LINKED STATS DISPLAY (Sprint 2 F2)
# =====================================================

## Tier 0 stat strip: Combat | Tough | Speed.
## Each label is a clickable keyword link wired to KeywordTooltip.
func _build_basic_stats_bbcode() -> String:
	var combat: int = character_data.get("combat", 0)
	var tough: int = character_data.get("toughness", 4)
	var speed: int = character_data.get("speed", 4)
	return "%s: %d | %s: %d | %s: %d" % [
		KeywordLinker.build_keyword_link_labeled("combat_skill", "Combat"),
		combat,
		KeywordLinker.build_keyword_link_labeled("toughness", "Tough"),
		tough,
		KeywordLinker.build_keyword_link_labeled("speed", "Speed"),
		speed]

## Tier 1+ stat strip: + Reactions + Savvy (and optional weapon line).
func _build_tier1_stats_bbcode() -> String:
	var combat: int = character_data.get("combat", 0)
	var tough: int = character_data.get("toughness", 4)
	var reactions: int = character_data.get("reactions", 1)
	var savvy: int = character_data.get("savvy", 0)
	var weapon: String = character_data.get("weapon_name", "")
	var line: String = "%s: %d | %s: %d | %s: %d | %s: %d" % [
		KeywordLinker.build_keyword_link_labeled("combat_skill", "Combat"),
		combat,
		KeywordLinker.build_keyword_link_labeled("toughness", "Tough"),
		tough,
		KeywordLinker.build_keyword_link_labeled("reactions", "React"),
		reactions,
		KeywordLinker.build_keyword_link_labeled("savvy", "Savvy"),
		savvy]
	if not weapon.is_empty():
		# Weapon name itself isn't a KeywordDB term, but trait words inside
		# weapon descriptions get wrapped where they're rendered (e.g. enemy
		# weapons col). Here just include the name.
		line += "\nWeapon: %s" % weapon
	return line

## Lazy-instantiate KeywordTooltip + wire stats_label meta_clicked once.
## Idempotent: safe to call from both display paths.
func _ensure_keyword_tooltip_attached() -> void:
	if stats_label == null:
		return
	if _keyword_tooltip == null:
		_keyword_tooltip = KeywordTooltip.new()
		add_child(_keyword_tooltip)
	KeywordLinker.attach(stats_label, _keyword_tooltip)

# =====================================================
# STATUS TOKEN ICONS (Modiphius Planetfall art, universal status family)
# =====================================================

## Build the status-icon row once, attaching it as a sibling immediately
## before status_label in the existing layout. Programmatic so no scene edit.
## Icons default hidden; _refresh_status_icons() shows the active ones.
func _build_status_icon_row() -> void:
	if status_label == null:
		return
	var parent: Node = status_label.get_parent()
	if parent == null:
		return
	_status_icons_container = HBoxContainer.new()
	_status_icons_container.name = "StatusIconRow"
	_status_icons_container.add_theme_constant_override("separation", 4)
	for status_id in STATUS_TOKEN_PATHS:
		var icon := TextureRect.new()
		icon.name = "Icon_%s" % status_id
		icon.custom_minimum_size = Vector2(STATUS_ICON_SIZE, STATUS_ICON_SIZE)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		# Guard the load so a missing PNG falls back to invisible rather than
		# crashing (see CLAUDE.md gotcha: optional asset paths must be
		# ResourceLoader.exists()-guarded).
		var path: String = STATUS_TOKEN_PATHS[status_id]
		if ResourceLoader.exists(path):
			icon.texture = load(path)
		icon.tooltip_text = status_id.capitalize()
		icon.visible = false
		_status_icons_container.add_child(icon)
		_status_icon_nodes[status_id] = icon
	parent.add_child(_status_icons_container)
	# Place the row immediately above status_label.
	parent.move_child(_status_icons_container, status_label.get_index())

## Show/hide each icon based on current per-battle state. Idempotent.
func _refresh_status_icons() -> void:
	if _status_icons_container == null:
		return
	if "stunned" in _status_icon_nodes:
		_status_icon_nodes["stunned"].visible = stun_markers > 0
	if "sprawling" in _status_icon_nodes:
		_status_icon_nodes["sprawling"].visible = is_sprawling
	if "aid" in _status_icon_nodes:
		_status_icon_nodes["aid"].visible = aid_markers > 0
	if "activated" in _status_icon_nodes:
		_status_icon_nodes["activated"].visible = _is_activated
	if "poison" in _status_icon_nodes:
		_status_icon_nodes["poison"].visible = is_poisoned

# Setters mirror the existing stun/action API: mutate state, write through
# to character_data so save/load round-trips, then refresh display.

func set_sprawling(value: bool) -> void:
	is_sprawling = value
	character_data["is_sprawling"] = value
	_update_display()

func set_poisoned(value: bool) -> void:
	is_poisoned = value
	character_data["is_poisoned"] = value
	_update_display()

func add_aid_marker() -> void:
	aid_markers += 1
	character_data["aid_markers"] = aid_markers
	_update_display()

func clear_aid() -> void:
	aid_markers = 0
	character_data["aid_markers"] = 0
	_update_display()
