class_name ActivationTrackerPanel
extends PanelContainer

## Activation Tracker Panel - Manages all unit activation cards
##
## Displays crew and enemy units with activation tracking.
## Integrates with BattleRoundTracker using "call down, signal up" pattern.
##
## Structure:
## - Round header with reset button
## - Crew section (ScrollContainer with unit cards)
## - Enemy section (ScrollContainer with unit cards)
##
## Signals up when units are activated.
## Listens to BattleRoundTracker signals for round/activation updates.

# Signals (signal-up pattern)
signal unit_activation_requested(unit_id: String)
signal reset_all_requested()

# Constants from UIColors design system
const SPACING_XS := UIColors.SPACING_XS
const SPACING_SM := UIColors.SPACING_SM
const SPACING_MD := UIColors.SPACING_MD
const SPACING_LG := UIColors.SPACING_LG

const FONT_SIZE_MD := UIColors.FONT_SIZE_MD
const FONT_SIZE_LG := UIColors.FONT_SIZE_LG
const FONT_SIZE_XL := UIColors.FONT_SIZE_XL

const COLOR_BASE := UIColors.COLOR_BASE
const COLOR_ELEVATED := UIColors.COLOR_ELEVATED
const COLOR_BORDER := UIColors.COLOR_BORDER
const COLOR_TEXT_PRIMARY := UIColors.COLOR_TEXT_PRIMARY
const COLOR_TEXT_SECONDARY := UIColors.COLOR_TEXT_SECONDARY

const TOUCH_TARGET_MIN := UIColors.TOUCH_TARGET_MIN

# Preload UnitActivationCard scene
const UnitActivationCardScene := preload("res://src/ui/components/battle/UnitActivationCard.tscn")

# UI references
@onready var _round_label: Label = %RoundLabel
@onready var _reset_button: Button = %ResetButton
@onready var _crew_container: VBoxContainer = %CrewContainer
@onready var _enemy_container: VBoxContainer = %EnemyContainer
@onready var _crew_label: Label = %CrewLabel
@onready var _enemy_label: Label = %EnemyLabel

# State
var _current_round: int = 1
var _battle_tracker: Node = null
var _unit_cards: Dictionary = {}  # unit_id -> Control (UnitActivationCard)

func _ready() -> void:
	## Initialize panel UI
	_connect_button_signals()
	_update_round_display()

func _connect_button_signals() -> void:
	## Connect button signals
	if _reset_button:
		_reset_button.pressed.connect(_on_reset_button_pressed)

# =====================================================
# PUBLIC INTERFACE
# =====================================================

func initialize(battle_tracker: Node) -> void:
	## Connect to BattleRoundTracker signals (call-down pattern)
	if not battle_tracker:
		push_error("ActivationTrackerPanel: Cannot initialize with null battle_tracker")
		return

	_battle_tracker = battle_tracker

	# Connect to tracker signals
	if _battle_tracker.has_signal("round_started"):
		_battle_tracker.round_started.connect(_on_tracker_round_started)
	if _battle_tracker.has_signal("round_ended"):
		_battle_tracker.round_ended.connect(_on_tracker_round_ended)
	if _battle_tracker.has_signal("battle_started"):
		_battle_tracker.battle_started.connect(_on_tracker_battle_started)
	if _battle_tracker.has_signal("battle_ended"):
		_battle_tracker.battle_ended.connect(_on_tracker_battle_ended)

	print("ActivationTrackerPanel: Initialized with BattleRoundTracker")

func cleanup() -> void:
	## Disconnect from tracker (cleanup)
	if not _battle_tracker:
		return

	if _battle_tracker.has_signal("round_started") and _battle_tracker.round_started.is_connected(_on_tracker_round_started):
		_battle_tracker.round_started.disconnect(_on_tracker_round_started)
	if _battle_tracker.has_signal("round_ended") and _battle_tracker.round_ended.is_connected(_on_tracker_round_ended):
		_battle_tracker.round_ended.disconnect(_on_tracker_round_ended)
	if _battle_tracker.has_signal("battle_started") and _battle_tracker.battle_started.is_connected(_on_tracker_battle_started):
		_battle_tracker.battle_started.disconnect(_on_tracker_battle_started)
	if _battle_tracker.has_signal("battle_ended") and _battle_tracker.battle_ended.is_connected(_on_tracker_battle_ended):
		_battle_tracker.battle_ended.disconnect(_on_tracker_battle_ended)

	_battle_tracker = null

func add_unit(unit_data: Dictionary, is_crew: bool) -> void:
	## Add unit card to appropriate section
	var unit_id: String = unit_data.get("id", "")
	if unit_id.is_empty():
		push_warning("ActivationTrackerPanel: Cannot add unit without id")
		return

	# Don't add duplicates
	if _unit_cards.has(unit_id):
		push_warning("ActivationTrackerPanel: Unit %s already exists" % unit_id)
		return

	# Instantiate card
	var card: Control = UnitActivationCardScene.instantiate()
	card.initialize(unit_data)

	# Connect card signals
	card.activation_toggled.connect(_on_unit_card_activation_toggled)
	card.unit_selected.connect(_on_unit_card_selected)

	# Add to appropriate container
	var container: VBoxContainer = _crew_container if is_crew else _enemy_container
	container.add_child(card)

	# Store reference
	_unit_cards[unit_id] = card

	print("ActivationTrackerPanel: Added %s unit %s" % ["crew" if is_crew else "enemy", unit_data.get("name", "Unknown")])

func remove_unit(unit_id: String) -> void:
	## Remove unit card
	if not _unit_cards.has(unit_id):
		push_warning("ActivationTrackerPanel: Cannot remove non-existent unit %s" % unit_id)
		return

	var card: Control = _unit_cards[unit_id]

	# Disconnect signals
	if card.has_signal("activation_toggled") and card.activation_toggled.is_connected(_on_unit_card_activation_toggled):
		card.activation_toggled.disconnect(_on_unit_card_activation_toggled)
	if card.has_signal("unit_selected") and card.unit_selected.is_connected(_on_unit_card_selected):
		card.unit_selected.disconnect(_on_unit_card_selected)

	# Remove from tree
	card.queue_free()

	# Remove from tracking
	_unit_cards.erase(unit_id)

	print("ActivationTrackerPanel: Removed unit %s" % unit_id)

func update_round(round_number: int) -> void:
	## Update round display (called from parent)
	_current_round = round_number
	_update_round_display()

func reset_all_activations() -> void:
	## Reset all unit activation states
	for unit_id in _unit_cards:
		var card: Control = _unit_cards[unit_id]
		if card.has_method("set_activated"):
			card.set_activated(false)

	print("ActivationTrackerPanel: Reset all unit activations")

func set_unit_activated(unit_id: String, activated: bool) -> void:
	## Set specific unit activation state (called from parent)
	if not _unit_cards.has(unit_id):
		push_warning("ActivationTrackerPanel: Cannot set activation for non-existent unit %s" % unit_id)
		return

	var card: Control = _unit_cards[unit_id]
	if card.has_method("set_activated"):
		card.set_activated(activated)

func set_unit_defeated(unit_id: String, defeated: bool) -> void:
	## Mark unit as defeated (called from parent)
	if not _unit_cards.has(unit_id):
		push_warning("ActivationTrackerPanel: Cannot set defeated for non-existent unit %s" % unit_id)
		return

	var card: Control = _unit_cards[unit_id]
	if card.has_method("update_health"):
		var current: int = card.get("current_health") if "current_health" in card else 10
		var max_hp: int = card.get("max_health") if "max_health" in card else 10
		card.update_health(0 if defeated else current, max_hp)

func update_unit_health(unit_id: String, current_health: int, max_health: int) -> void:
	## Update unit health display (called from parent)
	if not _unit_cards.has(unit_id):
		push_warning("ActivationTrackerPanel: Cannot update health for non-existent unit %s" % unit_id)
		return

	var card: Control = _unit_cards[unit_id]
	if card.has_method("update_health"):
		card.update_health(current_health, max_health)

func clear_all_units() -> void:
	## Remove all unit cards
	for unit_id in _unit_cards.keys():
		remove_unit(unit_id)

	_unit_cards.clear()
	print("ActivationTrackerPanel: Cleared all units")

# =====================================================
# DISPLAY UPDATES
# =====================================================

func _update_round_display() -> void:
	## Update round header
	if _round_label:
		_round_label.text = "ROUND %d" % _current_round
		_round_label.add_theme_font_size_override("font_size", FONT_SIZE_XL)
		_round_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)

	if _crew_label:
		_crew_label.add_theme_font_size_override("font_size", FONT_SIZE_LG)
		_crew_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)

	if _enemy_label:
		_enemy_label.add_theme_font_size_override("font_size", FONT_SIZE_LG)
		_enemy_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)

	if _reset_button:
		_reset_button.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)

# =====================================================
# SIGNAL HANDLERS - BATTLE TRACKER (CALL-DOWN)
# =====================================================

func _on_tracker_round_started(round_number: int) -> void:
	## Handle round start from tracker
	_current_round = round_number
	_update_round_display()
	reset_all_activations()
	print("ActivationTrackerPanel: Round %d started - reset all activations" % round_number)

func _on_tracker_round_ended(round_number: int) -> void:
	## Handle round end from tracker
	print("ActivationTrackerPanel: Round %d ended" % round_number)

func _on_tracker_battle_started() -> void:
	## Handle battle start from tracker
	_current_round = 1
	_update_round_display()
	clear_all_units()
	print("ActivationTrackerPanel: Battle started - cleared all units")

func _on_tracker_battle_ended() -> void:
	## Handle battle end from tracker
	print("ActivationTrackerPanel: Battle ended")

# =====================================================
# SIGNAL HANDLERS - UNIT CARDS (SIGNAL-UP)
# =====================================================

func _on_unit_card_activation_toggled(unit_id: String) -> void:
	## Handle card activation toggle - signal up to parent
	unit_activation_requested.emit(unit_id)
	print("ActivationTrackerPanel: Unit activation requested - %s" % unit_id)

func _on_unit_card_selected(unit_id: String) -> void:
	## Handle card selection (dead units)
	print("ActivationTrackerPanel: Unit selected - %s" % unit_id)
	# Could emit selection signal if needed

# =====================================================
# INPUT HANDLERS
# =====================================================

func _on_reset_button_pressed() -> void:
	## Handle Reset All button press - signal up to parent
	reset_all_requested.emit()
	print("ActivationTrackerPanel: Reset all requested")
