extends PanelContainer
class_name TrainingSelectionDialog

## Training Selection Dialog for Post-Battle Phase
## Implements Five Parsecs training system with approval roll mechanic
## Reference: Core Rules - Advanced Training section

# Signals
# Sprint 26.3: Character-Everywhere - use Character type instead of Resource
## `character` is untyped because crew members are Character Resources on a fresh
## campaign and Dictionaries on every loaded save. `payment` carries the actual
## p.124 split that was charged: {cost, xp_spent, credits_spent, ...}.
signal training_completed(character: Variant, training_type: String, payment: Dictionary)
signal dialog_closed()

# Design System Constants (from BaseCampaelPanel)
const SPACING_XS := 4
const SPACING_SM := 8
const SPACING_MD := 16
const SPACING_LG := 24
const SPACING_XL := 32
const TOUCH_TARGET_MIN := 48
const TOUCH_TARGET_COMFORT := 56
const FONT_SIZE_XS := 11
const FONT_SIZE_SM := 14
const FONT_SIZE_MD := 16
const FONT_SIZE_LG := 18
const FONT_SIZE_XL := 24

const COLOR_BASE := UIColors.COLOR_PRIMARY
const COLOR_ELEVATED := UIColors.COLOR_SECONDARY
const COLOR_INPUT := UIColors.COLOR_TERTIARY
const COLOR_BORDER := UIColors.COLOR_BORDER
const COLOR_ACCENT := UIColors.COLOR_BLUE
const COLOR_ACCENT_HOVER := UIColors.COLOR_ACCENT_HOVER
const COLOR_FOCUS := UIColors.COLOR_CYAN
const COLOR_TEXT_PRIMARY := UIColors.COLOR_TEXT_PRIMARY
const COLOR_TEXT_SECONDARY := UIColors.COLOR_TEXT_SECONDARY
const COLOR_TEXT_DISABLED := UIColors.COLOR_TEXT_MUTED
const COLOR_SUCCESS := UIColors.COLOR_EMERALD
const COLOR_WARNING := UIColors.COLOR_AMBER
const COLOR_DANGER := UIColors.COLOR_RED

# The seven Advanced Training courses, Core Rules p.125. Names, costs and
# effect text are verbatim from the book's table.
#
# There used to be an eighth, "Engineer" at cost 15. It is NOT a course — p.125
# has exactly seven rows, and "Engineer" appears there only as a CHARACTER CLASS
# inside the Mechanic entry ("Engineers count any XP spent as double value for
# obtaining this"). A fabricated course, removed per the data-integrity rule.
const TRAINING_TYPES := {
	"pilot": {
		"name": "Pilot Training",
		"cost": 20,
		"description": "If a Starship Travel event calls for a Savvy test, you may "
			+ "roll 2D6, pick the better die and add +2 to the score."
	},
	"mechanic": {
		"name": "Mechanic training",
		"cost": 15,
		"description": "If your ship is in need of Repairs, you may repair +1 Hull "
			+ "Point damage every campaign turn. Engineers count any XP spent as "
			+ "double value for obtaining this."
	},
	"medical": {
		"name": "Medical school",
		"cost": 20,
		"description": "After each battle, you may nominate a casualty that will "
			+ "roll twice on the Injury Table, picking the better result."
	},
	"merchant": {
		"name": "Merchant school",
		"cost": 10,
		"description": "When this crew member Trades, you may reroll one Trade roll "
			+ "each campaign turn. The new roll must be accepted."
	},
	"security": {
		"name": "Security training",
		"cost": 10,
		"description": "If this crew member is part of your squad, you may add +1 "
			+ "when rolling to Seize the Initiative. Ferals obtain this at -2 Cost."
	},
	"broker": {
		"name": "Broker training",
		"cost": 15,
		"description": "When rolling to obtain licenses, Advanced Training "
			+ "applications, or searching for Patrons, add +1 to the roll."
	},
	"bot_tech": {
		"name": "Bot technician",
		"cost": 10,
		"description": "All Bot upgrades cost 1 credit less. If a Bot or Soulless "
			+ "character must roll for a post-battle injury, roll twice and pick "
			+ "the better result."
	}
}

## Sprint 20.2: Fixed constants to match backend (Core Rules p.123)
const ENROLLMENT_FEE := 1    # 1 credit application fee per Core Rules
const APPROVAL_THRESHOLD := 4  # 2D6 roll, 4+ required for approval
const APPROVAL_DICE := "2D6"   # Dice type for approval roll display

# State
#
# UNTYPED on purpose. crew_data["members"] holds Character RESOURCES on a fresh
# campaign and DICTIONARIES on every loaded save (the save round-trip narrows
# them). The old `Array[Resource]` meant the caller's `if member is Resource`
# filter dropped every member of a loaded campaign, so a tester who saved and
# reloaded opened this step to an empty character list — the one situation where
# a crew has enough XP to want it. Accessors below read either shape.
var available_crew: Array = []
var selected_character: Variant = null
var selected_training_type: String = ""
var current_credits: int = 0
var can_afford_enrollment: bool = false
## p.124: "Only one attempt is permitted per campaign turn." The fee is paid and
## the 2D6 rolled once, pass or fail; a denied application does not refund and
## does not get a retry until next turn.
var attempted_this_turn: bool = false

# Node references
@onready var title_label: Label = %TitleLabel
@onready var character_selector: OptionButton = %CharacterSelector
@onready var training_list: VBoxContainer = %TrainingList
@onready var cost_display: HBoxContainer = %CostDisplay
@onready var xp_cost_label: Label = %XPCostLabel
@onready var credits_cost_label: Label = %CreditsCostLabel
@onready var roll_button: Button = %RollButton
@onready var result_display: Label = %ResultDisplay
@onready var close_button: Button = %CloseButton

func _ready() -> void:
	_setup_ui()
	_connect_signals()
	_update_ui_state()

func _setup_ui() -> void:
	## Setup UI styling using design system
	# Panel background
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = COLOR_BASE
	panel_style.border_color = COLOR_BORDER
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.set_corner_radius_all(4)
	panel_style.set_content_margin_all(SPACING_XL)
	add_theme_stylebox_override("panel", panel_style)
	
	# Title styling
	title_label.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_XL))
	title_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	
	# Style buttons
	_style_button(roll_button, COLOR_ACCENT)
	_style_button(close_button, COLOR_ELEVATED)
	
	# Character selector styling
	character_selector.custom_minimum_size.y = TOUCH_TARGET_MIN
	
	# Cost display styling
	xp_cost_label.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_MD))
	credits_cost_label.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_MD))
	
	# Result display styling
	result_display.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_MD))
	result_display.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _style_button(button: Button, bg_color: Color) -> void:
	## Apply consistent button styling
	button.custom_minimum_size.y = TOUCH_TARGET_MIN
	
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = bg_color
	normal_style.set_corner_radius_all(4)
	normal_style.set_content_margin_all(SPACING_MD)
	button.add_theme_stylebox_override("normal", normal_style)
	
	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = COLOR_ACCENT_HOVER
	hover_style.set_corner_radius_all(4)
	hover_style.set_content_margin_all(SPACING_MD)
	button.add_theme_stylebox_override("hover", hover_style)

func _connect_signals() -> void:
	## Connect UI signals
	character_selector.item_selected.connect(_on_character_selected)
	roll_button.pressed.connect(_on_roll_pressed)
	close_button.pressed.connect(_on_close_pressed)

func setup(crew: Array, credits: int) -> void:
	## Initialize dialog with crew data and credit availability
	available_crew = crew
	current_credits = credits
	can_afford_enrollment = current_credits >= ENROLLMENT_FEE

	_populate_character_list()
	_populate_training_list()
	_update_ui_state()


# ── Dual-shape accessors (Character Resource OR crew Dictionary) ────────────

func _char_name(c: Variant) -> String:
	if c is Dictionary:
		return str(c.get("character_name", c.get("name", "Unknown")))
	if c and "character_name" in c:
		return str(c.character_name)
	return "Unknown"

func _char_xp(c: Variant) -> int:
	if c is Dictionary:
		return int(c.get("experience", c.get("xp", 0)))
	if c and "experience" in c:
		return int(c.experience)
	return 0

## p.124: "Each crew member can only ever be trained in a single course."
## The canonical field is `acquired_training: Array[String]`. This used to read
## `selected_character.training`, a property Character does NOT have — so the
## check was always against an empty array and the one-course rule never held.
func _char_training(c: Variant) -> Array:
	if c is Dictionary:
		var t: Variant = c.get("acquired_training", [])
		return t if t is Array else []
	if c and "acquired_training" in c:
		return c.acquired_training
	return []

## p.124: "Bots can have a training module installed, but the cost must be paid
## in credits exclusively."
func _char_is_bot(c: Variant) -> bool:
	if c is Dictionary:
		return bool(c.get("is_bot", false))
	if c and "is_bot" in c:
		return bool(c.is_bot)
	return false

func _char_origin(c: Variant) -> String:
	if c is Dictionary:
		return str(c.get("species_id", c.get("origin", ""))).to_lower()
	if c and "species_id" in c:
		return str(c.species_id).to_lower()
	if c and "origin" in c:
		return str(c.origin).to_lower()
	return ""

func _char_class(c: Variant) -> String:
	if c is Dictionary:
		return str(c.get("character_class", c.get("class", ""))).to_lower()
	if c and "character_class" in c:
		return str(c.character_class).to_lower()
	return ""

## The cost of a course FOR THIS CHARACTER (Core Rules p.125 footnotes):
## "Ferals can obtain this training at -2 Cost" (Security training) and
## "Engineers count any XP spent as double value for obtaining this" (Mechanic
## training) — the latter is a payment-side rule, returned separately so the
## credits half of a split payment is not also halved.
func _course_cost_for(c: Variant, training_key: String) -> int:
	var base: int = int(TRAINING_TYPES[training_key]["cost"])
	if training_key == "security" and _char_origin(c).contains("feral"):
		base = maxi(0, base - 2)
	return base

func _xp_multiplier_for(c: Variant, training_key: String) -> int:
	if training_key == "mechanic" and _char_class(c).contains("engineer"):
		return 2
	return 1

func _populate_character_list() -> void:
	## Populate character dropdown with available crew
	character_selector.clear()

	for character in available_crew:
		var display_text := "%s (%d XP)" % [_char_name(character), _char_xp(character)]
		if not _char_training(character).is_empty():
			display_text += " — already trained"
		character_selector.add_item(display_text)

	if available_crew.size() > 0:
		character_selector.selected = 0
		selected_character = available_crew[0]

func _populate_training_list() -> void:
	## Create training option buttons
	# Clear existing children
	for child in training_list.get_children():
		child.queue_free()
	
	# Create button for each training type
	for training_key in TRAINING_TYPES.keys():
		var training_data: Dictionary = TRAINING_TYPES[training_key]
		var button := _create_training_button(training_key, training_data)
		training_list.add_child(button)

func _create_training_button(training_key: String, training_data: Dictionary) -> Button:
	## Create a styled training selection button
	var button := Button.new()
	button.custom_minimum_size.y = TOUCH_TARGET_MIN
	button.toggle_mode = true
	button.button_group = _get_or_create_button_group()
	
	# Button text with cost
	var button_text := "%s (%d XP)" % [training_data["name"], training_data["cost"]]
	button.text = button_text
	button.tooltip_text = training_data["description"]
	
	# Button styling
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = COLOR_ELEVATED
	normal_style.border_color = COLOR_BORDER
	normal_style.border_width_left = 1
	normal_style.border_width_top = 1
	normal_style.border_width_right = 1
	normal_style.border_width_bottom = 1
	normal_style.set_corner_radius_all(4)
	normal_style.set_content_margin_all(SPACING_MD)
	button.add_theme_stylebox_override("normal", normal_style)
	
	var pressed_style := StyleBoxFlat.new()
	pressed_style.bg_color = COLOR_ACCENT
	pressed_style.set_corner_radius_all(4)
	pressed_style.set_content_margin_all(SPACING_MD)
	button.add_theme_stylebox_override("pressed", pressed_style)
	
	# Connect signal
	button.toggled.connect(func(toggled_on: bool): _on_training_selected(training_key, toggled_on))
	
	return button

var _training_button_group: ButtonGroup = null
func _get_or_create_button_group() -> ButtonGroup:
	## Get or create button group for training selection
	if not _training_button_group:
		_training_button_group = ButtonGroup.new()
	return _training_button_group

func _on_character_selected(index: int) -> void:
	## Handle character selection change
	if index >= 0 and index < available_crew.size():
		selected_character = available_crew[index]
		_update_ui_state()

func _on_training_selected(training_key: String, toggled_on: bool) -> void:
	## Handle training type selection
	if toggled_on:
		selected_training_type = training_key
		_update_cost_display()
		_update_ui_state()

## How a course would be paid for (Core Rules p.124): "The cost can be paid
## using unspent XP, credits or any combination thereof."
##
## The book's own worked example — 8 unspent XP plus 12 credits for a cost-20
## Pilot Training — was IMPOSSIBLE here: the dialog required the full cost in XP
## and offered no credits half at all, so training was unaffordable until very
## late in a campaign, which is the opposite of the book's intent.
##
## XP is spent first because it has no other post-battle use at this step, and
## the book presents it that way ("The character has 8 unspent XP I can use, so
## I'd have to pay the rest as an additional 12 credits").
## Returns {cost, xp_spent, credits_spent, affordable, reason}.
func _payment_plan(c: Variant, training_key: String) -> Dictionary:
	var cost: int = _course_cost_for(c, training_key)
	var plan: Dictionary = {
		"cost": cost, "xp_spent": 0, "credits_spent": 0,
		"affordable": false, "reason": "",
	}
	# Credits available for the COURSE, after reserving the application fee.
	var spendable_credits: int = maxi(0, current_credits - ENROLLMENT_FEE)

	if _char_is_bot(c):
		# p.124: "Bots can have a training module installed, but the cost must be
		# paid in credits exclusively."
		plan["credits_spent"] = cost
		plan["affordable"] = spendable_credits >= cost
		if not plan["affordable"]:
			plan["reason"] = "Bots must pay in credits: %d needed, %d spare" % [
				cost, spendable_credits]
		return plan

	var xp_value: int = _char_xp(c) * _xp_multiplier_for(c, training_key)
	var xp_applied: int = mini(xp_value, cost)
	# Undo the multiplier to find how much XP actually leaves the sheet.
	plan["xp_spent"] = int(ceil(float(xp_applied) / float(
		_xp_multiplier_for(c, training_key))))
	plan["credits_spent"] = cost - xp_applied
	plan["affordable"] = spendable_credits >= plan["credits_spent"]
	if not plan["affordable"]:
		plan["reason"] = "Need %d XP + %d credits (have %d XP, %d spare credits)" % [
			plan["xp_spent"], plan["credits_spent"], _char_xp(c), spendable_credits]
	return plan

func _update_cost_display() -> void:
	## Update cost display labels
	if selected_training_type.is_empty() or selected_character == null:
		xp_cost_label.text = "XP Cost: -"
		credits_cost_label.text = "Enrollment: -"
		return

	var plan: Dictionary = _payment_plan(selected_character, selected_training_type)
	xp_cost_label.text = "Course %d: %d XP + %d credits" % [
		plan["cost"], plan["xp_spent"], plan["credits_spent"]]
	credits_cost_label.text = "Application fee: %d credit" % ENROLLMENT_FEE

	xp_cost_label.add_theme_color_override(
		"font_color", COLOR_SUCCESS if plan["affordable"] else COLOR_DANGER)
	credits_cost_label.add_theme_color_override(
		"font_color", COLOR_SUCCESS if can_afford_enrollment else COLOR_DANGER)

func _update_ui_state() -> void:
	## Update button states based on selections and affordability
	var has_selection := selected_character != null and not selected_training_type.is_empty()

	if attempted_this_turn:
		roll_button.disabled = true
		result_display.text = "Only one Advanced Training attempt per campaign turn (p.124)"
		result_display.add_theme_color_override("font_color", COLOR_WARNING)
		return

	if has_selection:
		# p.124: "Each crew member can only ever be trained in a single course."
		# ANY existing course blocks a second one — not just the same course.
		var current_training: Array = _char_training(selected_character)
		if not current_training.is_empty():
			roll_button.disabled = true
			result_display.text = "%s is already trained in %s — one course per crew member" % [
				_char_name(selected_character), str(current_training[0])]
			result_display.add_theme_color_override("font_color", COLOR_WARNING)
			return

		var plan: Dictionary = _payment_plan(selected_character, selected_training_type)
		roll_button.disabled = not (plan["affordable"] and can_afford_enrollment)
		if not can_afford_enrollment:
			result_display.text = "Insufficient credits for the 1-credit application fee"
			result_display.add_theme_color_override("font_color", COLOR_DANGER)
		elif not plan["affordable"]:
			result_display.text = str(plan["reason"])
			result_display.add_theme_color_override("font_color", COLOR_DANGER)
		else:
			result_display.text = ""
		return

	roll_button.disabled = true
	result_display.text = ""

func _on_roll_pressed() -> void:
	## Core Rules p.124, in the book's own order: "Select a crew member who wishes
	## to attend, pay an application fee of 1 credit, and roll 2D6, requiring a 4+
	## to be approved."
	if selected_character == null or selected_training_type.is_empty():
		return
	if attempted_this_turn:
		return

	var gsm = get_node_or_null("/root/GameStateManager")
	var plan: Dictionary = _payment_plan(selected_character, selected_training_type)

	# The application fee is paid to APPLY, so it is spent whether or not the
	# roll is approved. It was displayed and gated on, and never deducted.
	if gsm and gsm.has_method("remove_credits"):
		gsm.remove_credits(ENROLLMENT_FEE)
	current_credits = maxi(0, current_credits - ENROLLMENT_FEE)
	attempted_this_turn = true

	var dice_manager = get_node_or_null("/root/DiceManager")
	var roll_result: int = 0
	if dice_manager and dice_manager.has_method("roll_d6"):
		roll_result = dice_manager.roll_d6("Training Approval (die 1)") \
			+ dice_manager.roll_d6("Training Approval (die 2)")
	else:
		roll_result = randi_range(1, 6) + randi_range(1, 6)

	# p.125 Broker training: "When rolling to obtain licenses, ADVANCED TRAINING
	# APPLICATIONS, or searching for Patrons, add +1 to the roll." The other two
	# uses were wired; this one was not.
	var broker_bonus: int = 1 if _crew_has_broker_training() else 0
	roll_result += broker_bonus

	var approved := roll_result >= APPROVAL_THRESHOLD
	var roll_text: String = "%s Roll: %d" % [APPROVAL_DICE, roll_result]
	if broker_bonus > 0:
		roll_text += " (incl. +1 Broker)"

	if approved:
		_apply_training(plan)
		result_display.text = "%s - APPROVED. Paid %d XP + %d credits (+%d fee)." % [
			roll_text, plan["xp_spent"], plan["credits_spent"], ENROLLMENT_FEE]
		result_display.add_theme_color_override("font_color", COLOR_SUCCESS)
		training_completed.emit(selected_character, selected_training_type, plan)
	else:
		result_display.text = "%s - DENIED (need %d+). The %d-credit fee is spent; try again next turn." % [
			roll_text, APPROVAL_THRESHOLD, ENROLLMENT_FEE]
		result_display.add_theme_color_override("font_color", COLOR_DANGER)

	roll_button.disabled = true

## Does anyone in the crew have Broker training (Core Rules p.125)? The bonus is
## a CREW-level benefit — the book's Advanced Training application is made by the
## crew, not by the applicant, and p.124 notes "you cannot benefit from more than
## one crew member with the same training", so one Broker is enough and a second
## adds nothing.
func _crew_has_broker_training() -> bool:
	for c in available_crew:
		if "broker" in _char_training(c):
			return true
	return false

## Actually hand over the training (Core Rules p.124). Everything below this line
## used to be missing entirely: the player picked a course, saw "Training
## APPROVED!", read "<name> completed pilot training" in the log, and nothing was
## spent and nothing was learned. The step was pure theatre.
func _apply_training(plan: Dictionary) -> void:
	var gsm = get_node_or_null("/root/GameStateManager")
	if gsm and gsm.has_method("remove_credits") and int(plan["credits_spent"]) > 0:
		gsm.remove_credits(int(plan["credits_spent"]))
	current_credits = maxi(0, current_credits - int(plan["credits_spent"]))

	var xp_spent: int = int(plan["xp_spent"])
	if selected_character is Dictionary:
		selected_character["experience"] = maxi(
			0, int(selected_character.get("experience", 0)) - xp_spent)
		var training: Array = _char_training(selected_character)
		if selected_training_type not in training:
			training = training.duplicate()
			training.append(selected_training_type)
			selected_character["acquired_training"] = training
	else:
		if "experience" in selected_character:
			selected_character.experience = maxi(
				0, int(selected_character.experience) - xp_spent)
		# add_training() is the canonical mutator; the direct append is the
		# fallback for a Character that predates it.
		if selected_character.has_method("add_training"):
			selected_character.add_training(selected_training_type)
		elif "acquired_training" in selected_character:
			if selected_training_type not in selected_character.acquired_training:
				selected_character.acquired_training.append(selected_training_type)

	_populate_character_list()

func _on_close_pressed() -> void:
	## Handle close button press
	dialog_closed.emit()
	queue_free()

