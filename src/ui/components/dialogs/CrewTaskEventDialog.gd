class_name CrewTaskEventDialog
extends Window

## Crew Task Event Dialog — Universal interactive dialog for Trade/Explore results
## Shows each crew task result as an interactive moment: event description,
## player action (roll dice, pick items, confirm), outcome display.
## Follows Deep Space theme. Art placeholder ready for future book illustrations.

signal event_completed(outcome: Dictionary)

# ── Event Types ───────────────────────────────────────────────────────
enum EventType {
	INFO_ONLY, # No mechanical effect, flavor text
	GAIN_CREDITS, # Static credit gain
	GAIN_XP, # Static XP gain
	GAIN_STORY_POINT, # Static story point gain
	ROLL_FOR_BONUS, # Roll for conditional bonus (trinkets, nice chat)
	ROLL_FOR_CREDITS, # Roll for variable credits (fuel, repair parts)
	ROLL_FOR_CREDITS_RISK, # Roll for credits + possible rival (contraband)
	ROLL_ON_TABLE, # Roll on loot/weapon/gear subtable
	CONDITIONAL_PURCHASE, # Pay credits for a roll (odd device, rare items)
	CHOICE_ITEM, # Choose between OR-separated items
	GRENADE_COMBO, # Frakk/Dazzle quantity picker
	DISCARD_ITEM, # Must discard 1 item from equipment
	SELL_WEAPONS, # Sell weapons for credits each
	SICK_BAY, # Enter sick bay for N turns
	GAIN_RIVAL, # Gain a rival
	GAIN_RUMOR, # Gain a quest rumor
	GAIN_PATRON, # Gain a patron
	RECRUIT, # Add new crew member
	BUY_RUMORS, # Purchase rumors at a price
	BUY_WEAPONS, # Purchase weapon rolls at a price
	SKILL_CHECK, # Roll + stat for pass/fail
	ITEM_TRADE, # Trade item for something else
	PAY_OR_LOSE, # Pay cost or suffer penalty
	TECH_FANATIC, # Complex conditional (damage + repair + engineer)
	DEFERRED, # Cached for future trigger
	IMMUNE, # Species immunity — skip with badge
}

# ── Deep Space Theme ──────────────────────────────────────────────────
const COLOR_BASE := Color("#1A1A2E")
const COLOR_ELEVATED := Color("#252542")
const COLOR_ACCENT := Color("#2D5A7B")
const COLOR_ACCENT_HOVER := Color("#3A7199")
const COLOR_FOCUS := Color("#4FC3F7")
const COLOR_TEXT_PRIMARY := Color("#E0E0E0")
const COLOR_TEXT_SECONDARY := Color("#808080")
const COLOR_TEXT_GOLD := Color("#FFD700")
const COLOR_BORDER := Color("#3A3A5C")
const COLOR_SUCCESS := Color("#10B981")
const COLOR_DANGER := Color("#DC2626")
const COLOR_DEFERRED := Color("#4FC3F7")
const TOUCH_TARGET_MIN := 48

# ── State ─────────────────────────────────────────────────────────────
var _event_data: Dictionary = {}
var _outcome: Dictionary = {}
var _interactive_area: VBoxContainer = null
var _outcome_container: VBoxContainer = null
var _continue_btn: Button = null
var _roll_btn: Button = null
var _action_taken: bool = false
var _content_panel: PanelContainer = null  # For draw/discard animation
var _content_margin: MarginContainer = null  # For draw/discard animation
var _is_dismissing: bool = false  # Prevent double-dismiss

# ── Grenade combo state ───────────────────────────────────────────────
var _frakk_count: int = 3
var _dazzle_count: int = 0
var _frakk_label: Label = null
var _dazzle_label: Label = null

# ── Sell weapons state ────────────────────────────────────────────────
var _sell_checkboxes: Array[CheckBox] = []
var _sell_total_label: Label = null
var _sell_credits_per: int = 0

# ── Buy quantity state ────────────────────────────────────────────────
var _buy_quantity: int = 0
var _buy_max: int = 0
var _buy_cost_each: int = 0
var _buy_quantity_label: Label = null
var _buy_total_label: Label = null

func _init() -> void:
	title = "Crew Task Event"
	size = Vector2i(420, 200) # Height adjusted in show_event()
	transient = true
	exclusive = true
	unresizable = true
	close_requested.connect(func(): pass ) # Must interact

# ── Public API ────────────────────────────────────────────────────────

func show_event(event_data: Dictionary) -> void:
	_event_data = event_data
	_outcome = {}
	_action_taken = false
	_is_dismissing = false
	_build_ui()
	popup_centered()
	_play_draw_animation()

# ── UI Construction ───────────────────────────────────────────────────

func _build_ui() -> void:
	var event_type: int = _event_data.get("type", EventType.INFO_ONLY)

	# Background panel
	_content_panel = PanelContainer.new()
	_content_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = COLOR_BASE
	panel_style.border_color = COLOR_BORDER
	panel_style.set_border_width_all(1)
	_content_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_content_panel)

	# Margin
	_content_margin = MarginContainer.new()
	_content_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content_margin.add_theme_constant_override("margin_left", 16)
	_content_margin.add_theme_constant_override("margin_right", 16)
	_content_margin.add_theme_constant_override("margin_top", 12)
	_content_margin.add_theme_constant_override("margin_bottom", 12)
	add_child(_content_margin)

	# ScrollContainer for tall dialogs
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_margin.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(vbox)

	# Art placeholder
	vbox.add_child(_build_art_area())

	# Event title
	var title_label := Label.new()
	title_label.text = str(_event_data.get("event_name", "Event"))
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)

	# Character + task type subtitle
	var crew_name: String = str(_event_data.get("crew_name", ""))
	var task_type: String = str(_event_data.get("task_type", ""))
	if not crew_name.is_empty():
		var subtitle := Label.new()
		var sub_text: String = crew_name
		if not task_type.is_empty():
			sub_text += " • %s" % task_type.capitalize()
		subtitle.text = sub_text
		subtitle.add_theme_font_size_override("font_size", 14)
		subtitle.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(subtitle)

	# Separator
	var sep := HSeparator.new()
	sep.modulate = COLOR_BORDER
	vbox.add_child(sep)

	# Effect description
	var effect_text: String = str(_event_data.get("effect_text", ""))
	if not effect_text.is_empty():
		var effect_label := Label.new()
		effect_label.text = effect_text
		effect_label.add_theme_font_size_override("font_size", 14)
		effect_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(effect_label)

	# Immunity badge
	if event_type == EventType.IMMUNE:
		var badge := _build_badge("IMMUNE — Species exception", COLOR_DEFERRED)
		vbox.add_child(badge)

	# Deferred badge
	if event_type == EventType.DEFERRED:
		var trigger: String = str(_event_data.get("deferred_trigger", ""))
		var badge_text: String = "Triggers later"
		match trigger:
			"NEXT_TURN": badge_text = "Triggers next campaign turn"
			"NEW_PLANET": badge_text = "Triggers on new planet arrival"
			"ON_BATTLE": badge_text = "Triggers during next battle"
			"ON_QUEST": badge_text = "Triggers when undertaking a quest"
			"ON_RECRUIT": badge_text = "Triggers when recruiting"
			"ON_OPPORTUNITY_MISSION": badge_text = "Triggers on opportunity mission"
			"PERSISTENT": badge_text = "Persistent — check when used"
		var badge := _build_badge(badge_text, COLOR_DEFERRED)
		vbox.add_child(badge)

	# Interactive area
	_interactive_area = VBoxContainer.new()
	_interactive_area.add_theme_constant_override("separation", 6)
	vbox.add_child(_interactive_area)
	_build_interactive_area(event_type)

	# Outcome container (hidden until action taken)
	_outcome_container = VBoxContainer.new()
	_outcome_container.add_theme_constant_override("separation", 4)
	_outcome_container.visible = false
	vbox.add_child(_outcome_container)

	# Auto-show outcome for simple types
	match event_type:
		EventType.GAIN_CREDITS:
			var credits: int = _event_data.get("credits", 0)
			_show_outcome("+%d credits" % credits, COLOR_TEXT_GOLD)
			_action_taken = true
		EventType.GAIN_XP:
			var xp: int = _event_data.get("xp", 0)
			_show_outcome("+%d XP to %s" % [xp, crew_name], COLOR_TEXT_GOLD)
			_action_taken = true
		EventType.GAIN_STORY_POINT:
			var sp: int = _event_data.get("story_points", 0)
			_show_outcome("+%d story point" % sp, COLOR_TEXT_GOLD)
			_action_taken = true
		EventType.GAIN_RIVAL:
			_show_outcome("Gained a Rival!", COLOR_DANGER)
			var kerin_bonus: String = str(_event_data.get("kerin_bonus", ""))
			if not kerin_bonus.is_empty():
				_add_outcome_line("K'Erin bonus: %s" % kerin_bonus, COLOR_DEFERRED)
			_action_taken = true
		EventType.GAIN_RUMOR:
			_show_outcome("Quest Rumor acquired!", COLOR_TEXT_GOLD)
			_action_taken = true
		EventType.GAIN_PATRON:
			_show_outcome("Patron job available!", COLOR_SUCCESS)
			_action_taken = true
		EventType.SICK_BAY:
			var turns: int = _event_data.get("sick_bay_turns", 1)
			_show_outcome("%d turn(s) in Sick Bay" % turns, COLOR_DANGER)
			_action_taken = true
		EventType.IMMUNE, EventType.INFO_ONLY, EventType.DEFERRED:
			_action_taken = true

	# Continue button
	_continue_btn = Button.new()
	_continue_btn.text = "Continue"
	_continue_btn.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
	_style_button(_continue_btn, COLOR_ACCENT)
	_continue_btn.pressed.connect(_on_continue_pressed)
	vbox.add_child(_continue_btn)

	# Size dialog based on content
	_resize_dialog(event_type)

func _build_art_area() -> Control:
	# Check for custom art
	var event_name: String = str(_event_data.get("event_name", ""))
	var snake_name: String = event_name.to_snake_case().replace(" ", "_")
	var art_path := "res://assets/event_art/%s.png" % snake_name
	if ResourceLoader.exists(art_path):
		var tex_rect := TextureRect.new()
		tex_rect.texture = load(art_path)
		tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.custom_minimum_size = Vector2(0, 80)
		return tex_rect

	# Fallback: gradient placeholder
	var art := ColorRect.new()
	art.custom_minimum_size = Vector2(0, 60)
	# Use event type to tint the placeholder
	var event_type: int = _event_data.get("type", EventType.INFO_ONLY)
	match event_type:
		EventType.GAIN_CREDITS, EventType.ROLL_FOR_CREDITS, EventType.SELL_WEAPONS:
			art.color = Color("#1E2A1E") # Green tint for money
		EventType.GAIN_RIVAL, EventType.DISCARD_ITEM, EventType.SICK_BAY:
			art.color = Color("#2A1E1E") # Red tint for danger
		EventType.ROLL_ON_TABLE, EventType.ROLL_FOR_BONUS:
			art.color = Color("#1E1E2A") # Blue tint for dice
		EventType.DEFERRED:
			art.color = Color("#1E2A2A") # Cyan tint for deferred
		_:
			art.color = COLOR_ELEVATED
	return art

func _build_interactive_area(event_type: int) -> void:
	match event_type:
		EventType.ROLL_FOR_BONUS, EventType.ROLL_FOR_CREDITS, EventType.ROLL_ON_TABLE, EventType.SKILL_CHECK:
			_build_roll_button("Roll")
		EventType.ROLL_FOR_CREDITS_RISK:
			_build_accept_decline_buttons()
		EventType.CONDITIONAL_PURCHASE:
			_build_purchase_buttons()
		EventType.CHOICE_ITEM:
			_build_choice_buttons()
		EventType.GRENADE_COMBO:
			_build_grenade_picker()
		EventType.DISCARD_ITEM:
			_build_discard_list()
		EventType.SELL_WEAPONS:
			_build_sell_list()
		EventType.BUY_RUMORS, EventType.BUY_WEAPONS:
			_build_quantity_picker()
		EventType.ITEM_TRADE:
			_build_trade_buttons()
		EventType.PAY_OR_LOSE:
			_build_pay_or_lose_buttons()
		EventType.TECH_FANATIC:
			_build_tech_fanatic_area()
		EventType.RECRUIT:
			_build_recruit_button()
		EventType.SICK_BAY:
			# If requires a roll (e.g., "Get in a bad fight" 1D3), show roll button
			if _event_data.get("requires_sick_bay_roll", false):
				_build_roll_button("Roll for Sick Bay turns")

# ── Interactive Builders ──────────────────────────────────────────────

func _build_roll_button(label_text: String) -> void:
	_roll_btn = Button.new()
	_roll_btn.text = label_text
	_roll_btn.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
	_style_button(_roll_btn, COLOR_ACCENT)
	_roll_btn.pressed.connect(_on_roll_pressed)
	_interactive_area.add_child(_roll_btn)

func _build_accept_decline_buttons() -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_interactive_area.add_child(hbox)

	var accept_btn := Button.new()
	accept_btn.text = "Accept"
	accept_btn.custom_minimum_size = Vector2(140, TOUCH_TARGET_MIN)
	_style_button(accept_btn, COLOR_ACCENT)
	accept_btn.pressed.connect(_on_accept_risk)
	hbox.add_child(accept_btn)

	var decline_btn := Button.new()
	decline_btn.text = "Decline"
	decline_btn.custom_minimum_size = Vector2(140, TOUCH_TARGET_MIN)
	_style_button(decline_btn, COLOR_ELEVATED)
	decline_btn.pressed.connect(_on_decline_risk)
	hbox.add_child(decline_btn)

func _build_purchase_buttons() -> void:
	var cost: int = _event_data.get("purchase_cost", 0)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_interactive_area.add_child(hbox)

	var buy_btn := Button.new()
	buy_btn.text = "Pay %d Credits" % cost
	buy_btn.custom_minimum_size = Vector2(160, TOUCH_TARGET_MIN)
	_style_button(buy_btn, COLOR_ACCENT)
	buy_btn.pressed.connect(_on_purchase_accepted)
	hbox.add_child(buy_btn)

	var skip_btn := Button.new()
	skip_btn.text = "No Thanks"
	skip_btn.custom_minimum_size = Vector2(120, TOUCH_TARGET_MIN)
	_style_button(skip_btn, COLOR_ELEVATED)
	skip_btn.pressed.connect(_on_purchase_declined)
	hbox.add_child(skip_btn)

func _build_choice_buttons() -> void:
	var options: Array = _event_data.get("choice_options", [])
	for option_name in options:
		var btn := Button.new()
		btn.text = str(option_name)
		btn.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_button(btn, COLOR_ACCENT)
		btn.pressed.connect(_on_choice_selected.bind(str(option_name)))
		_interactive_area.add_child(btn)

func _build_grenade_picker() -> void:
	_frakk_count = 3
	_dazzle_count = 0
	var desc := Label.new()
	desc.text = "Choose your combination (total = 3)"
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_interactive_area.add_child(desc)

	# Frakk row
	var frakk_row := _build_counter_row("Frakk Grenades", _frakk_count)
	_frakk_label = frakk_row.get_meta("count_label")
	frakk_row.get_meta("minus_btn").pressed.connect(_adjust_grenade.bind("frakk", -1))
	frakk_row.get_meta("plus_btn").pressed.connect(_adjust_grenade.bind("frakk", 1))
	_interactive_area.add_child(frakk_row)

	# Dazzle row
	var dazzle_row := _build_counter_row("Dazzle Grenades", _dazzle_count)
	_dazzle_label = dazzle_row.get_meta("count_label")
	dazzle_row.get_meta("minus_btn").pressed.connect(_adjust_grenade.bind("dazzle", -1))
	dazzle_row.get_meta("plus_btn").pressed.connect(_adjust_grenade.bind("dazzle", 1))
	_interactive_area.add_child(dazzle_row)

	# Confirm button
	var confirm := Button.new()
	confirm.text = "Confirm Grenades"
	confirm.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
	_style_button(confirm, COLOR_ACCENT)
	confirm.pressed.connect(_on_grenades_confirmed)
	_interactive_area.add_child(confirm)

func _build_discard_list() -> void:
	var equipment: Array = _event_data.get("equipment", [])
	if equipment.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No items to discard"
		empty_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_interactive_area.add_child(empty_label)
		_action_taken = true
		return

	var desc := Label.new()
	desc.text = "Choose an item to discard:"
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	_interactive_area.add_child(desc)

	for item_name in equipment:
		var btn := Button.new()
		btn.text = str(item_name)
		btn.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_button(btn, COLOR_ELEVATED)
		btn.pressed.connect(_on_discard_selected.bind(str(item_name)))
		_interactive_area.add_child(btn)

func _build_sell_list() -> void:
	var equipment: Array = _event_data.get("equipment", [])
	_sell_credits_per = _event_data.get("credits_per_item", 2)
	_sell_checkboxes.clear()

	if equipment.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No weapons to sell"
		empty_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		_interactive_area.add_child(empty_label)
		_action_taken = true
		return

	var desc := Label.new()
	desc.text = "Select weapons to sell (%d credits each):" % _sell_credits_per
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	_interactive_area.add_child(desc)

	for item_name in equipment:
		var cb := CheckBox.new()
		cb.text = str(item_name)
		cb.add_theme_font_size_override("font_size", 14)
		cb.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
		cb.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
		cb.toggled.connect(_on_sell_checkbox_toggled)
		_interactive_area.add_child(cb)
		_sell_checkboxes.append(cb)

	# Total display
	_sell_total_label = Label.new()
	_sell_total_label.text = "Total: 0 credits"
	_sell_total_label.add_theme_font_size_override("font_size", 16)
	_sell_total_label.add_theme_color_override("font_color", COLOR_TEXT_GOLD)
	_sell_total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_interactive_area.add_child(_sell_total_label)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_interactive_area.add_child(hbox)

	var sell_btn := Button.new()
	sell_btn.text = "Sell Selected"
	sell_btn.custom_minimum_size = Vector2(140, TOUCH_TARGET_MIN)
	_style_button(sell_btn, COLOR_ACCENT)
	sell_btn.pressed.connect(_on_sell_confirmed)
	hbox.add_child(sell_btn)

	var skip_btn := Button.new()
	skip_btn.text = "No Thanks"
	skip_btn.custom_minimum_size = Vector2(120, TOUCH_TARGET_MIN)
	_style_button(skip_btn, COLOR_ELEVATED)
	skip_btn.pressed.connect(_on_sell_declined)
	hbox.add_child(skip_btn)

func _build_quantity_picker() -> void:
	_buy_cost_each = _event_data.get("cost_each", 0)
	_buy_max = _event_data.get("max_quantity", 0)
	_buy_quantity = 0

	var desc := Label.new()
	desc.text = "%d credits each (max %d)" % [_buy_cost_each, _buy_max]
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_interactive_area.add_child(desc)

	var row := _build_counter_row("Quantity", 0)
	_buy_quantity_label = row.get_meta("count_label")
	row.get_meta("minus_btn").pressed.connect(_on_buy_quantity_changed.bind(-1))
	row.get_meta("plus_btn").pressed.connect(_on_buy_quantity_changed.bind(1))
	_interactive_area.add_child(row)

	_buy_total_label = Label.new()
	_buy_total_label.text = "Cost: 0 credits"
	_buy_total_label.add_theme_font_size_override("font_size", 16)
	_buy_total_label.add_theme_color_override("font_color", COLOR_TEXT_GOLD)
	_buy_total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_interactive_area.add_child(_buy_total_label)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_interactive_area.add_child(hbox)

	var buy_btn := Button.new()
	buy_btn.text = "Purchase"
	buy_btn.custom_minimum_size = Vector2(140, TOUCH_TARGET_MIN)
	_style_button(buy_btn, COLOR_ACCENT)
	buy_btn.pressed.connect(_on_buy_confirmed)
	hbox.add_child(buy_btn)

	var skip_btn := Button.new()
	skip_btn.text = "No Thanks"
	skip_btn.custom_minimum_size = Vector2(120, TOUCH_TARGET_MIN)
	_style_button(skip_btn, COLOR_ELEVATED)
	skip_btn.pressed.connect(_on_buy_declined)
	hbox.add_child(skip_btn)

func _build_trade_buttons() -> void:
	var trade_type: String = str(_event_data.get("trade_type", "weapon"))
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_interactive_area.add_child(hbox)

	var trade_btn := Button.new()
	trade_btn.text = "Trade a %s" % trade_type.capitalize()
	trade_btn.custom_minimum_size = Vector2(160, TOUCH_TARGET_MIN)
	_style_button(trade_btn, COLOR_ACCENT)
	trade_btn.pressed.connect(_on_trade_accepted)
	hbox.add_child(trade_btn)

	var skip_btn := Button.new()
	skip_btn.text = "No Thanks"
	skip_btn.custom_minimum_size = Vector2(120, TOUCH_TARGET_MIN)
	_style_button(skip_btn, COLOR_ELEVATED)
	skip_btn.pressed.connect(_on_trade_declined)
	hbox.add_child(skip_btn)

func _build_pay_or_lose_buttons() -> void:
	var pay_or_lose: Dictionary = _event_data.get("pay_or_lose_data", {})
	var cost_text: String = str(pay_or_lose.get("cost", "1 story point"))
	var penalty_text: String = str(pay_or_lose.get("penalty", "crew member leaves"))

	var pay_btn := Button.new()
	pay_btn.text = "Pay %s" % cost_text
	pay_btn.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
	pay_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(pay_btn, COLOR_ACCENT)
	pay_btn.pressed.connect(_on_pay_chosen)
	_interactive_area.add_child(pay_btn)

	var lose_btn := Button.new()
	lose_btn.text = "Accept: %s" % penalty_text
	lose_btn.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
	lose_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(lose_btn, COLOR_DANGER)
	lose_btn.pressed.connect(_on_lose_chosen)
	_interactive_area.add_child(lose_btn)

func _build_tech_fanatic_area() -> void:
	var is_engineer: bool = _event_data.get("is_engineer", false)
	if is_engineer:
		_show_outcome("+2 XP (Engineer bonus!)", COLOR_SUCCESS)
		_action_taken = true
		_outcome = {"xp": 2, "engineer_bonus": true}
	else:
		var random_item: String = str(_event_data.get("random_damaged_item", ""))
		if random_item.is_empty():
			_show_outcome("No items to damage", COLOR_TEXT_SECONDARY)
			_action_taken = true
		else:
			_show_outcome("Your %s is damaged!" % random_item, COLOR_DANGER)
			_build_roll_button("Roll for Repair (5+ to fix)")

func _build_recruit_button() -> void:
	var recruit_btn := Button.new()
	recruit_btn.text = "Recruit New Crew Member"
	recruit_btn.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
	recruit_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(recruit_btn, COLOR_SUCCESS)
	recruit_btn.pressed.connect(_on_recruit_pressed)
	_interactive_area.add_child(recruit_btn)

# ── Callback Handlers ─────────────────────────────────────────────────

func _on_roll_pressed() -> void:
	if _roll_btn:
		_roll_btn.disabled = true

	var event_type: int = _event_data.get("type", EventType.INFO_ONLY)
	match event_type:
		EventType.ROLL_FOR_BONUS:
			_handle_roll_for_bonus()
		EventType.ROLL_FOR_CREDITS:
			_handle_roll_for_credits()
		EventType.ROLL_ON_TABLE:
			_handle_roll_on_table()
		EventType.SKILL_CHECK:
			_handle_skill_check()
		EventType.SICK_BAY:
			_handle_sick_bay_roll()
		EventType.TECH_FANATIC:
			_handle_tech_repair_roll()

func _handle_roll_for_bonus() -> void:
	var roll: int = randi() % 6 + 1
	var savvy_mod: int = _event_data.get("savvy_modifier", 0)
	var total: int = roll + savvy_mod
	var threshold: int = _event_data.get("success_threshold", 6)

	var roll_text: String = "Rolled %d" % roll
	if savvy_mod > 0:
		roll_text = "Rolled %d + %d Savvy = %d" % [roll, savvy_mod, total]

	if total >= threshold:
		var sp: int = _event_data.get("bonus_story_points", 1)
		_show_outcome("%s — +%d story point!" % [roll_text, sp], COLOR_TEXT_GOLD)
		_outcome = {"story_points": sp, "roll": roll}
	else:
		_show_outcome("%s — No luck" % roll_text, COLOR_TEXT_SECONDARY)
		_outcome = {"story_points": 0, "roll": roll}
	_action_taken = true

func _handle_roll_for_credits() -> void:
	# Some events (Fuel, Starship repair parts) are rolled here in the dialog.
	# Others (Contraband, etc.) were pre-rolled — use _event_data["credits"] if set.
	var credits: int = _event_data.get("credits", 0)
	if credits == 0:
		# Not pre-rolled — this is the interactive roll moment
		credits = randi() % 6 + 1
	_show_outcome("Rolled %d — %d credits" % [credits, credits], COLOR_TEXT_GOLD)
	_outcome = {"credits": credits, "roll": credits}
	_action_taken = true

func _handle_roll_on_table() -> void:
	## Resolve loot items and display what was rolled (Core Rules pp.131-133)
	var items: Array = _event_data.get("items_to_resolve", [])
	var resolved_items: Array = []

	for item_str in items:
		var s: String = str(item_str)
		if "(random" in s:
			# Resolve via loot table roll
			var resolved: Array = _resolve_loot_roll(s)
			resolved_items.append_array(resolved)
		else:
			resolved_items.append(s)

	if resolved_items.is_empty():
		# No items to resolve — do a full main loot table roll
		var resolved: Array = _roll_main_loot()
		resolved_items.append_array(resolved)

	# Display results
	if resolved_items.is_empty():
		_show_outcome("No loot found", COLOR_TEXT_SECONDARY)
	else:
		_show_outcome("Loot rolled:", COLOR_TEXT_GOLD)
		for item_name in resolved_items:
			_add_outcome_line("  → %s" % str(item_name), COLOR_SUCCESS)

	# Update event data with resolved names so completion callback uses them
	_event_data["items_to_resolve"] = resolved_items
	_outcome = {"roll_requested": true, "items": resolved_items, "resolved_items": resolved_items}
	_action_taken = true


## ── Loot Table Resolution (for ROLL_ON_TABLE) ────────────────────────

const _LootConstants = preload("res://src/core/systems/LootSystemConstants.gd")

func _resolve_loot_roll(item_string: String) -> Array:
	## Resolve a "(random)" item string into actual item names via loot subtables
	if item_string.begins_with("Gear Loot") or item_string == "Gear (random)":
		return [_roll_subtable(_LootConstants.get_gear_subtable_data())]
	elif "Low Tech Weapon" in item_string:
		# Melee weapons only
		for entry in _LootConstants.get_weapon_subtable_data():
			if entry is Dictionary and entry.get("category") == "melee_weapons":
				var wpn_items: Array = entry.get("items", [])
				if wpn_items.size() > 0:
					return [wpn_items[randi() % wpn_items.size()]]
		return [item_string]
	elif "Gadget" in item_string:
		# Gun mods + sights from gear subtable
		var gadget_pool: Array = []
		for entry in _LootConstants.get_gear_subtable_data():
			if entry is Dictionary and entry.get("category", "") in ["gun_mods", "gun_sights"]:
				gadget_pool.append_array(entry.get("items", []))
		if gadget_pool.size() > 0:
			return [gadget_pool[randi() % gadget_pool.size()]]
		return [item_string]
	else:
		# Full main loot table roll
		return _roll_main_loot()

func _roll_main_loot() -> Array:
	## Roll D100 on main loot table, then resolve subtable (Core Rules pp.131-133)
	var main_data: Array = _LootConstants.get_main_loot_data()
	var roll: int = randi_range(1, 100)
	for entry in main_data:
		if entry is Dictionary:
			var r: Array = entry.get("roll_range", [0, 0])
			if roll >= r[0] and roll <= r[1]:
				var cat: String = entry.get("category", "")
				var count: int = entry.get("count", 1)
				var results: Array = []
				match cat:
					"WEAPON", "DAMAGED_WEAPONS":
						for _i in range(count):
							var name: String = _roll_subtable(_LootConstants.get_weapon_subtable_data())
							if entry.get("requires_repair", false):
								name += " (damaged)"
							results.append(name)
					"GEAR", "DAMAGED_GEAR":
						for _i in range(count):
							var name: String = _roll_subtable(_LootConstants.get_gear_subtable_data())
							if entry.get("requires_repair", false):
								name += " (damaged)"
							results.append(name)
					"ODDS_AND_ENDS":
						results.append(_roll_subtable(_LootConstants.get_odds_and_ends_data()))
					"REWARDS":
						var reward: Dictionary = _roll_reward()
						results.append(reward.get("description", "Reward"))
				return results
	return ["Unknown Loot"]

func _roll_subtable(subtable_data: Array) -> String:
	## Roll D100 on a subtable, pick a random item from the matched range
	var roll: int = randi_range(1, 100)
	for entry in subtable_data:
		if entry is Dictionary:
			var r: Array = entry.get("roll_range", [0, 0])
			if roll >= r[0] and roll <= r[1]:
				var sub_items: Array = entry.get("items", [])
				if sub_items.size() > 0:
					return str(sub_items[randi() % sub_items.size()])
				return str(entry.get("item", "Unknown"))
	return "Unknown Loot"

func _roll_reward() -> Dictionary:
	## Roll on rewards subtable — returns description dict
	var rewards_data: Array = _LootConstants.get_rewards_subtable_data()
	var roll: int = randi_range(1, 100)
	for entry in rewards_data:
		if entry is Dictionary:
			var r: Array = entry.get("roll_range", [0, 0])
			if roll >= r[0] and roll <= r[1]:
				var item_name: String = entry.get("item", "Reward")
				if entry.has("credits"):
					return {"description": "%s: +%d credits" % [item_name, entry["credits"]]}
				elif entry.has("credits_dice"):
					var credits: int = randi_range(1, 6)
					return {"description": "%s: +%d credits" % [item_name, credits]}
				elif entry.has("rumors"):
					return {"description": "%s: +%d Quest Rumor(s)" % [item_name, entry["rumors"]]}
				elif entry.has("story_points"):
					return {"description": "%s: +%d Story Point(s)" % [item_name, entry["story_points"]]}
				return {"description": item_name}
	return {"description": "Nothing notable"}

func _handle_skill_check() -> void:
	var roll: int = randi() % 6 + 1
	var stat_mod: int = _event_data.get("stat_modifier", 0)
	var total: int = roll + stat_mod
	var threshold: int = _event_data.get("success_threshold", 4)
	var stat_name: String = str(_event_data.get("stat_name", "Savvy"))

	var roll_text: String = "Rolled %d + %d %s = %d" % [roll, stat_mod, stat_name, total]

	if total >= threshold:
		_show_outcome("%s — Success!" % roll_text, COLOR_SUCCESS)
		_outcome = {"success": true, "roll": roll, "total": total}
	else:
		var fail_text: String = str(_event_data.get("failure_text", "Failed"))
		_show_outcome("%s — %s" % [roll_text, fail_text], COLOR_DANGER)
		_outcome = {"success": false, "roll": roll, "total": total}
	_action_taken = true

func _handle_sick_bay_roll() -> void:
	var turns: int = (randi() % 3) + 1 # 1D3
	_show_outcome("Rolled %d — %d turns in Sick Bay" % [turns, turns], COLOR_DANGER)
	_outcome = {"sick_bay_turns": turns}
	_event_data["sick_bay_turns"] = turns
	_action_taken = true

func _handle_tech_repair_roll() -> void:
	var roll: int = randi() % 6 + 1
	var item_name: String = str(_event_data.get("random_damaged_item", "item"))
	if roll >= 5:
		_add_outcome_line("Rolled %d — Repaired for free!" % roll, COLOR_SUCCESS)
		_outcome = {"repaired": true, "roll": roll, "damaged_item": item_name}
	else:
		_add_outcome_line("Rolled %d — Still damaged" % roll, COLOR_DANGER)
		_outcome = {"repaired": false, "roll": roll, "damaged_item": item_name}
	if _roll_btn:
		_roll_btn.disabled = true
	_action_taken = true

func _on_accept_risk() -> void:
	# Replace accept/decline with roll button
	for child in _interactive_area.get_children():
		child.queue_free()
	_build_roll_button("Roll 1D6")

func _on_decline_risk() -> void:
	_show_outcome("Declined — no credits, no risk", COLOR_TEXT_SECONDARY)
	_outcome = {"declined": true, "credits": 0}
	_action_taken = true

func _on_purchase_accepted() -> void:
	for child in _interactive_area.get_children():
		child.queue_free()
	_outcome = {"purchased": true}
	_build_roll_button("Roll on Loot Table")

func _on_purchase_declined() -> void:
	_show_outcome("Passed on the offer", COLOR_TEXT_SECONDARY)
	_outcome = {"purchased": false}
	_action_taken = true

func _on_choice_selected(item_name: String) -> void:
	_show_outcome("Chose: %s" % item_name, COLOR_TEXT_GOLD)
	_outcome = {"item_name": item_name}
	for child in _interactive_area.get_children():
		child.queue_free()
	_action_taken = true

func _on_grenades_confirmed() -> void:
	var summary: String = ""
	if _frakk_count > 0:
		summary += "%dx Frakk" % _frakk_count
	if _dazzle_count > 0:
		if not summary.is_empty():
			summary += " + "
		summary += "%dx Dazzle" % _dazzle_count
	_show_outcome("Grenades: %s" % summary, COLOR_TEXT_GOLD)
	_outcome = {"frakk": _frakk_count, "dazzle": _dazzle_count}
	for child in _interactive_area.get_children():
		child.queue_free()
	_action_taken = true

func _adjust_grenade(grenade_type: String, delta: int) -> void:
	if grenade_type == "frakk":
		_frakk_count = clampi(_frakk_count + delta, 0, 3)
		_dazzle_count = 3 - _frakk_count
	else:
		_dazzle_count = clampi(_dazzle_count + delta, 0, 3)
		_frakk_count = 3 - _dazzle_count
	if _frakk_label:
		_frakk_label.text = str(_frakk_count)
	if _dazzle_label:
		_dazzle_label.text = str(_dazzle_count)

func _on_discard_selected(item_name: String) -> void:
	_show_outcome("Discarded: %s" % item_name, COLOR_DANGER)
	_outcome = {"discarded_item": item_name}
	for child in _interactive_area.get_children():
		child.queue_free()
	_action_taken = true

func _on_sell_checkbox_toggled(_pressed: bool) -> void:
	var count: int = 0
	for cb in _sell_checkboxes:
		if cb.button_pressed:
			count += 1
	if _sell_total_label:
		_sell_total_label.text = "Total: %d credits" % (count * _sell_credits_per)

func _on_sell_confirmed() -> void:
	var sold: Array = []
	for cb in _sell_checkboxes:
		if cb.button_pressed:
			sold.append(cb.text)
	if sold.is_empty():
		_show_outcome("Nothing sold", COLOR_TEXT_SECONDARY)
	else:
		var total: int = sold.size() * _sell_credits_per
		_show_outcome("Sold %d weapon(s) for %d credits" % [sold.size(), total], COLOR_TEXT_GOLD)
	_outcome = {"sold_items": sold, "credits": sold.size() * _sell_credits_per}
	for child in _interactive_area.get_children():
		child.queue_free()
	_action_taken = true

func _on_sell_declined() -> void:
	_show_outcome("Kept all weapons", COLOR_TEXT_SECONDARY)
	_outcome = {"sold_items": [], "credits": 0}
	for child in _interactive_area.get_children():
		child.queue_free()
	_action_taken = true

func _on_buy_quantity_changed(delta: int) -> void:
	_buy_quantity = clampi(_buy_quantity + delta, 0, _buy_max)
	if _buy_quantity_label:
		_buy_quantity_label.text = str(_buy_quantity)
	if _buy_total_label:
		_buy_total_label.text = "Cost: %d credits" % (_buy_quantity * _buy_cost_each)

func _on_buy_confirmed() -> void:
	_outcome = {"quantity": _buy_quantity, "total_cost": _buy_quantity * _buy_cost_each}
	if _buy_quantity > 0:
		_show_outcome("Purchased %d for %d credits" % [_buy_quantity, _buy_quantity * _buy_cost_each], COLOR_TEXT_GOLD)
	else:
		_show_outcome("Nothing purchased", COLOR_TEXT_SECONDARY)
	for child in _interactive_area.get_children():
		child.queue_free()
	_action_taken = true

func _on_buy_declined() -> void:
	_outcome = {"quantity": 0, "total_cost": 0}
	_show_outcome("Passed on the offer", COLOR_TEXT_SECONDARY)
	for child in _interactive_area.get_children():
		child.queue_free()
	_action_taken = true

func _on_trade_accepted() -> void:
	# Replace trade buttons with item selection from equipment
	for child in _interactive_area.get_children():
		child.queue_free()
	_outcome = {"traded": true}
	var equipment: Array = _event_data.get("equipment", [])
	var trade_type: String = str(_event_data.get("trade_type", "item"))
	if equipment.is_empty():
		_show_outcome("No %ss to trade" % trade_type, COLOR_TEXT_SECONDARY)
		_action_taken = true
		return
	var desc := Label.new()
	desc.text = "Choose a %s to trade:" % trade_type
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	_interactive_area.add_child(desc)
	for item_name in equipment:
		var btn := Button.new()
		btn.text = str(item_name)
		btn.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_button(btn, COLOR_ELEVATED)
		btn.pressed.connect(_on_trade_item_selected.bind(str(item_name)))
		_interactive_area.add_child(btn)

func _on_trade_declined() -> void:
	_outcome = {"traded": false}
	_show_outcome("Kept your items", COLOR_TEXT_SECONDARY)
	for child in _interactive_area.get_children():
		child.queue_free()
	_action_taken = true

func _on_trade_item_selected(item_name: String) -> void:
	_outcome["traded_item"] = item_name
	for child in _interactive_area.get_children():
		child.queue_free()
	# Now roll for what you get
	_build_roll_button("Roll for reward")

func _on_pay_chosen() -> void:
	_show_outcome("Paid the cost", COLOR_TEXT_GOLD)
	_outcome = {"paid": true}
	for child in _interactive_area.get_children():
		child.queue_free()
	_action_taken = true

func _on_lose_chosen() -> void:
	_show_outcome("Crew member leaves...", COLOR_DANGER)
	_outcome = {"paid": false, "crew_lost": true}
	for child in _interactive_area.get_children():
		child.queue_free()
	_action_taken = true

func _on_recruit_pressed() -> void:
	_outcome = {"recruit": true}
	_show_outcome("New crew member recruited!", COLOR_SUCCESS)
	for child in _interactive_area.get_children():
		child.queue_free()
	_action_taken = true

func _on_continue_pressed() -> void:
	if not _action_taken:
		return # Must take action first
	if _is_dismissing:
		return # Prevent double-dismiss during animation
	_is_dismissing = true
	_play_discard_animation()

# ── Draw / Discard Animations ────────────────────────────────────────
# Inspired by Fallout Wasteland Warfare companion app: card slides in from
# the left (like drawing from a physical deck), drops + fades on dismiss
# (like tossing to the discard pile).

func _play_draw_animation() -> void:
	if not _content_margin:
		return
	# Slide content in from the left + fade in
	var original_x: float = _content_margin.position.x
	_content_margin.position.x = original_x - 300.0
	_content_margin.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(
		_content_margin, "position:x", original_x, 0.25
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(
		_content_margin, "modulate:a", 1.0, 0.2
	)

func _play_discard_animation() -> void:
	if not _content_margin:
		# Fallback: emit and free immediately
		event_completed.emit(_outcome)
		queue_free()
		return
	# Drop downward + fade out (discard to pile gesture)
	var tween := create_tween()
	tween.tween_property(
		_content_margin, "position:y",
		_content_margin.position.y + 80.0, 0.2
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(
		_content_margin, "modulate:a", 0.0, 0.15
	)
	tween.finished.connect(func():
		event_completed.emit(_outcome)
		queue_free()
	)

# ── Helper Methods ────────────────────────────────────────────────────

func _show_outcome(text: String, color: Color) -> void:
	if not _outcome_container:
		return
	_outcome_container.visible = true
	var sep := HSeparator.new()
	sep.modulate = COLOR_BORDER
	_outcome_container.add_child(sep)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_outcome_container.add_child(label)
	# Animate outcome reveal (fold in from zero height)
	TweenFX.fold_in(label, 0.3)

func _add_outcome_line(text: String, color: Color) -> void:
	if not _outcome_container:
		return
	_outcome_container.visible = true
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_outcome_container.add_child(label)
	# Animate outcome line reveal
	TweenFX.fold_in(label, 0.3)

func _build_badge(text: String, color: Color) -> PanelContainer:
	var badge_panel := PanelContainer.new()
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color(color, 0.15)
	badge_style.border_color = color
	badge_style.set_border_width_all(1)
	badge_style.set_corner_radius_all(4)
	badge_style.set_content_margin_all(8)
	badge_panel.add_theme_stylebox_override("panel", badge_style)
	var badge_label := Label.new()
	badge_label.text = text
	badge_label.add_theme_font_size_override("font_size", 14)
	badge_label.add_theme_color_override("font_color", color)
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_panel.add_child(badge_label)
	return badge_panel

func _build_counter_row(label_text: String, initial: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	var name_label := Label.new()
	name_label.text = label_text
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	var minus_btn := Button.new()
	minus_btn.text = "-"
	minus_btn.custom_minimum_size = Vector2(TOUCH_TARGET_MIN, TOUCH_TARGET_MIN)
	_style_counter_button(minus_btn)
	row.add_child(minus_btn)

	var count_label := Label.new()
	count_label.text = str(initial)
	count_label.add_theme_font_size_override("font_size", 18)
	count_label.add_theme_color_override("font_color", COLOR_FOCUS)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.custom_minimum_size = Vector2(40, 0)
	row.add_child(count_label)

	var plus_btn := Button.new()
	plus_btn.text = "+"
	plus_btn.custom_minimum_size = Vector2(TOUCH_TARGET_MIN, TOUCH_TARGET_MIN)
	_style_counter_button(plus_btn)
	row.add_child(plus_btn)

	row.set_meta("count_label", count_label)
	row.set_meta("minus_btn", minus_btn)
	row.set_meta("plus_btn", plus_btn)
	return row

func _style_button(btn: Button, bg_color: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = bg_color
	normal.set_corner_radius_all(6)
	normal.set_content_margin_all(8)
	btn.add_theme_stylebox_override("normal", normal)

	var hover := StyleBoxFlat.new()
	hover.bg_color = bg_color.lightened(0.15)
	hover.set_corner_radius_all(6)
	hover.set_content_margin_all(8)
	hover.border_color = COLOR_FOCUS
	hover.set_border_width_all(2)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = bg_color.darkened(0.1)
	pressed.set_corner_radius_all(6)
	pressed.set_content_margin_all(8)
	btn.add_theme_stylebox_override("pressed", pressed)

	var disabled := StyleBoxFlat.new()
	disabled.bg_color = bg_color.darkened(0.4)
	disabled.set_corner_radius_all(6)
	disabled.set_content_margin_all(8)
	btn.add_theme_stylebox_override("disabled", disabled)

	btn.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_disabled_color", COLOR_TEXT_SECONDARY)
	btn.add_theme_font_size_override("font_size", 16)

func _style_counter_button(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = COLOR_ELEVATED
	normal.set_corner_radius_all(6)
	normal.border_color = COLOR_BORDER
	normal.set_border_width_all(1)
	btn.add_theme_stylebox_override("normal", normal)
	var hover := StyleBoxFlat.new()
	hover.bg_color = COLOR_ACCENT
	hover.set_corner_radius_all(6)
	hover.border_color = COLOR_FOCUS
	hover.set_border_width_all(1)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	btn.add_theme_font_size_override("font_size", 18)

func _resize_dialog(event_type: int) -> void:
	# Estimate height based on event type complexity
	var base_height: int = 320
	match event_type:
		EventType.INFO_ONLY, EventType.GAIN_CREDITS, EventType.GAIN_XP, \
		EventType.GAIN_STORY_POINT, EventType.IMMUNE, EventType.DEFERRED, \
		EventType.GAIN_RIVAL, EventType.GAIN_RUMOR, EventType.GAIN_PATRON:
			base_height = 340
		EventType.ROLL_FOR_BONUS, EventType.ROLL_FOR_CREDITS, EventType.ROLL_ON_TABLE, \
		EventType.SKILL_CHECK, EventType.SICK_BAY, EventType.RECRUIT:
			base_height = 380
		EventType.ROLL_FOR_CREDITS_RISK, EventType.CONDITIONAL_PURCHASE, \
		EventType.PAY_OR_LOSE, EventType.TECH_FANATIC:
			base_height = 400
		EventType.CHOICE_ITEM:
			var opts: int = _event_data.get("choice_options", []).size()
			base_height = 340 + opts * 56
		EventType.GRENADE_COMBO:
			base_height = 440
		EventType.DISCARD_ITEM:
			var items: int = _event_data.get("equipment", []).size()
			base_height = 340 + items * 56
		EventType.SELL_WEAPONS:
			var items: int = _event_data.get("equipment", []).size()
			base_height = 400 + items * 48
		EventType.BUY_RUMORS, EventType.BUY_WEAPONS:
			base_height = 420
		EventType.ITEM_TRADE:
			base_height = 400
	size = Vector2i(420, mini(base_height, 600))
