extends FiveParsecsCampaignPanel

## Campaign Editor (v1: Overview + Crew) — edit a live 5PFH campaign's mid-campaign
## state. Two entry points share this surface: the Dashboard "Edit" button
## (correct/adjust an existing campaign) and the Main-Menu "Onboard Existing Game"
## flow (set the accumulated state of a tabletop game that is already N turns deep).
##
## HARD RULE (data-ownership, lint-enforced): every mutation goes through an owner
## setter — GameStateManager.set_* for counters, FiveParsecsCampaignCore
## add/update/remove_crew_member for the roster. NEVER a raw progress_data/crew_data
## write. See docs/sop / CLAUDE.md "Data Ownership".
##
## Code-built (mirrors GalaxyLogScreen): skip super._ready(), manual base init,
## build UI in _build_ui(). Tabs via AdaptivePanelGroup (grid on desktop, tab strip
## in portrait). SpinBoxes populate with set_value_no_signal() then write through the
## setter only on user-driven value_changed (SpinBox extends Range — a code-set fires
## value_changed, so populating without _no_signal would clobber on load).

const CharacterCreatorScene := preload("res://src/ui/screens/character/CharacterCreator.tscn")
const CharacterCreatorScript := preload("res://src/core/character/Generation/CharacterCreator.gd")
const AdaptivePanelGroupScript := preload("res://src/ui/components/base/AdaptivePanelGroup.gd")
const CharacterScript := preload("res://src/core/character/Character.gd")

# The 5 canonical Core Rules difficulty modes (p.63). The deprecated HARD/NIGHTMARE/
# ELITE values in GlobalEnums.DifficultyLevel are intentionally omitted (CLAUDE.md).
const DIFFICULTY_MODES := [
	{"label": "Easy", "value": 1},
	{"label": "Normal", "value": 2},
	{"label": "Challenging", "value": 4},
	{"label": "Hardcore", "value": 6},
	{"label": "Insanity", "value": 8},
]

var _campaign
var _onboarding: bool = false

var _character_creator: Control
var _body: Control
var _crew_list: ItemList
var _edit_button: Button
var _remove_button: Button

# Overview controls
var _turn_spin: SpinBox
var _credits_spin: SpinBox
var _supplies_spin: SpinBox
var _story_spin: SpinBox
var _rep_spin: SpinBox
var _debt_spin: SpinBox
var _difficulty_opt: OptionButton


func _ready() -> void:
	# Skip super._ready() panel structure — we build our own UI (GalaxyLogScreen pattern).
	_ensure_base_background()
	_setup_responsive_layout()
	_resolve_context()
	_build_ui()
	_load_from_campaign()
	# super._ready() is skipped above, so the band reservation it normally performs
	# is invoked by hand — same as _ensure_base_background() / _setup_responsive_layout().
	# Without it this screen's header draws under the floating gear/bug buttons.
	var _so := get_node_or_null("/root/SettingsOverlay")
	if _so and _so.has_method("reserve_band_on"):
		_so.reserve_band_on(self)


func _resolve_context() -> void:
	var gs := get_node_or_null("/root/GameState")
	if gs and gs.has_method("get_current_campaign"):
		_campaign = gs.get_current_campaign()
	var gsm := get_node_or_null("/root/GameStateManager")
	if gsm and gsm.has_method("get_temp_data"):
		_onboarding = bool(gsm.get_temp_data("onboarding_mode", false))
		# Consume the flag so a later plain edit doesn't inherit onboarding mode.
		if _onboarding and gsm.has_method("set_temp_data"):
			gsm.set_temp_data("onboarding_mode", false)


func _build_ui() -> void:
	_body = VBoxContainer.new()
	_body.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_body.add_theme_constant_override("separation", UIColors.SPACING_MD)
	_body.offset_left = UIColors.SPACING_XL
	_body.offset_right = -UIColors.SPACING_XL
	_body.offset_top = UIColors.SPACING_LG
	_body.offset_bottom = -UIColors.SPACING_LG
	add_child(_body)

	# --- Header ---
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", UIColors.SPACING_MD)
	_body.add_child(header)

	var back_btn := Button.new()
	back_btn.text = "< Back"
	back_btn.custom_minimum_size = Vector2(0, UIColors.TOUCH_TARGET_MIN)
	DialogStyles.style_secondary_button(back_btn)
	back_btn.pressed.connect(_on_back_pressed)
	header.add_child(back_btn)

	var title := Label.new()
	var cname := str(_campaign.campaign_name) if _campaign and "campaign_name" in _campaign else "Campaign"
	title.text = "Edit: %s" % cname
	title.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_XL)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	# --- Onboarding banner ---
	if _onboarding:
		var banner := Label.new()
		banner.text = "Set your current campaign state — turn, credits, story points, and each crew member's real stats."
		banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		banner.add_theme_color_override("font_color", UIColors.COLOR_WARNING)
		banner.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_SM)
		_body.add_child(banner)

	if _campaign == null:
		var err := Label.new()
		err.text = "No active campaign to edit."
		err.add_theme_color_override("font_color", UIColors.COLOR_DANGER)
		_body.add_child(err)
		return

	# --- Tabs (Overview + Crew) ---
	var group := AdaptivePanelGroupScript.new()
	group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	group.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(group)
	group.add_pane(_build_overview_pane(), "Overview")
	group.add_pane(_build_crew_pane(), "Crew")

	# --- Footer ---
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", UIColors.SPACING_MD)
	footer.alignment = BoxContainer.ALIGNMENT_END
	_body.add_child(footer)

	var validate_btn := Button.new()
	validate_btn.text = "Validate"
	validate_btn.custom_minimum_size = Vector2(0, UIColors.TOUCH_TARGET_MIN)
	DialogStyles.style_secondary_button(validate_btn)
	validate_btn.pressed.connect(_on_validate_pressed)
	footer.add_child(validate_btn)

	var save_btn := Button.new()
	save_btn.text = "Apply & Save"
	save_btn.custom_minimum_size = Vector2(0, UIColors.TOUCH_TARGET_MIN)
	DialogStyles.style_primary_button(save_btn)
	save_btn.pressed.connect(_on_save_pressed)
	footer.add_child(save_btn)

	# --- Character creator overlay (hidden until Add/Edit) ---
	_character_creator = CharacterCreatorScene.instantiate()
	_character_creator.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_character_creator.hide()
	add_child(_character_creator)
	if _character_creator.has_signal("character_created"):
		_character_creator.character_created.connect(_on_character_created)
	if _character_creator.has_signal("character_edited"):
		_character_creator.character_edited.connect(_on_character_edited)
	if _character_creator.has_signal("creation_cancelled"):
		_character_creator.creation_cancelled.connect(_on_creator_dismissed)


# ============================================================================
# OVERVIEW TAB
# ============================================================================

func _build_overview_pane() -> Control:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UIColors.SPACING_SM)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	_turn_spin = _add_spin_row(vbox, "Turn #", 0, 9999, 1)
	_turn_spin.value_changed.connect(func(v): _set_turn(int(v)))
	_credits_spin = _add_spin_row(vbox, "Credits", 0, 99999, 1)
	_credits_spin.value_changed.connect(func(v): _gsm_call("set_credits", int(v)))
	_supplies_spin = _add_spin_row(vbox, "Supplies", 0, 9999, 1)
	_supplies_spin.value_changed.connect(func(v): _gsm_call("set_supplies", int(v)))
	_story_spin = _add_spin_row(vbox, "Story Points", 0, 999, 1)
	_story_spin.value_changed.connect(func(v): _gsm_call("set_story_progress", int(v)))
	_rep_spin = _add_spin_row(vbox, "Reputation", 0, 999, 1)
	_rep_spin.value_changed.connect(func(v): _gsm_call("set_reputation", int(v)))
	_debt_spin = _add_spin_row(vbox, "Ship Debt", 0, 99999, 1)
	_debt_spin.value_changed.connect(func(v): _gsm_call("set_ship_debt", int(v)))

	# Difficulty dropdown.
	_difficulty_opt = OptionButton.new()
	_difficulty_opt.custom_minimum_size = Vector2(0, UIColors.TOUCH_TARGET_MIN)
	for i in range(DIFFICULTY_MODES.size()):
		_difficulty_opt.add_item(str(DIFFICULTY_MODES[i]["label"]), i)
	_style_option_button(_difficulty_opt)
	_difficulty_opt.item_selected.connect(_on_difficulty_selected)
	vbox.add_child(_create_labeled_input("Difficulty", _difficulty_opt))

	return scroll


func _add_spin_row(parent: VBoxContainer, label_text: String, mn: int, mx: int, stp: int) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = mn
	spin.max_value = mx
	spin.step = stp
	spin.custom_minimum_size = Vector2(0, UIColors.TOUCH_TARGET_MIN)
	parent.add_child(_create_labeled_input(label_text, spin))
	return spin


func _set_turn(n: int) -> void:
	# turns_played has no per-field setter on GameStateManager other than the new
	# set_turns_played; route through it (clamps >= 0).
	_gsm_call("set_turns_played", n)


func _on_difficulty_selected(idx: int) -> void:
	if idx < 0 or idx >= DIFFICULTY_MODES.size() or _campaign == null:
		return
	# difficulty is a top-level @export on the core (its own owner field) — not a
	# progress_data/crew_data key, so a direct set is the sanctioned write here.
	if "difficulty" in _campaign:
		_campaign.difficulty = int(DIFFICULTY_MODES[idx]["value"])


# ============================================================================
# CREW TAB
# ============================================================================

func _build_crew_pane() -> Control:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UIColors.SPACING_SM)

	_crew_list = ItemList.new()
	_crew_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_crew_list.custom_minimum_size = Vector2(0, 200)
	_crew_list.item_selected.connect(_on_crew_selected)
	vbox.add_child(_crew_list)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", UIColors.SPACING_SM)
	vbox.add_child(buttons)

	var add_btn := Button.new()
	add_btn.text = "+ Add"
	add_btn.custom_minimum_size = Vector2(0, UIColors.TOUCH_TARGET_MIN)
	add_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	DialogStyles.style_primary_button(add_btn)
	add_btn.pressed.connect(_on_add_crew_pressed)
	buttons.add_child(add_btn)

	_edit_button = Button.new()
	_edit_button.text = "Edit"
	_edit_button.custom_minimum_size = Vector2(0, UIColors.TOUCH_TARGET_MIN)
	_edit_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_edit_button.disabled = true
	DialogStyles.style_secondary_button(_edit_button)
	_edit_button.pressed.connect(_on_edit_crew_pressed)
	buttons.add_child(_edit_button)

	_remove_button = Button.new()
	_remove_button.text = "Remove"
	_remove_button.custom_minimum_size = Vector2(0, UIColors.TOUCH_TARGET_MIN)
	_remove_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_remove_button.disabled = true
	DialogStyles.style_danger_button(_remove_button)
	_remove_button.pressed.connect(_on_remove_crew_pressed)
	buttons.add_child(_remove_button)

	return vbox


func _refresh_crew_list() -> void:
	if _crew_list == null or _campaign == null:
		return
	_crew_list.clear()
	for m in _campaign.get_crew_members():
		if not (m is Dictionary):
			continue
		var nm := str(m.get("character_name", m.get("name", "Unknown")))
		if bool(m.get("is_captain", false)):
			nm += "  (Captain)"
		_crew_list.add_item(nm)
	_edit_button.disabled = true
	_remove_button.disabled = true


func _on_crew_selected(_idx: int) -> void:
	_edit_button.disabled = false
	_remove_button.disabled = false


func _selected_member() -> Dictionary:
	if _crew_list == null:
		return {}
	var sel := _crew_list.get_selected_items()
	if sel.is_empty():
		return {}
	var members: Array = _campaign.get_crew_members()
	var idx: int = sel[0]
	if idx >= 0 and idx < members.size() and members[idx] is Dictionary:
		return members[idx]
	return {}


func _member_id(m: Dictionary) -> String:
	return str(m.get("character_id", m.get("id", "")))


func _on_add_crew_pressed() -> void:
	_show_creator()
	_character_creator.start_creation(CharacterCreatorScript.CreatorMode.INITIAL_CREW)


func _on_edit_crew_pressed() -> void:
	var m := _selected_member()
	if m.is_empty():
		return
	var char_obj = CharacterScript.new()
	char_obj.from_dictionary(m)
	_show_creator()
	_character_creator.edit_character(char_obj)


func _on_remove_crew_pressed() -> void:
	var m := _selected_member()
	if m.is_empty():
		return
	var cid := _member_id(m)
	var nm := str(m.get("character_name", m.get("name", "this crew member")))
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = "Remove %s from the crew? This cannot be undone." % nm
	dialog.confirmed.connect(func():
		_campaign.remove_crew_member(cid)
		_refresh_crew_list()
		dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered()


func _on_character_created(character) -> void:
	_hide_creator()
	if _campaign and character and character.has_method("to_dictionary"):
		_campaign.add_crew_member(character.to_dictionary())
		_refresh_crew_list()


func _on_character_edited(character) -> void:
	_hide_creator()
	if _campaign == null or character == null or not character.has_method("to_dictionary"):
		return
	var dict: Dictionary = character.to_dictionary()
	var cid := str(dict.get("character_id", dict.get("id", "")))
	# In-place update preserves is_captain (add_crew_member would demote the captain).
	_campaign.update_crew_member(cid, dict)
	_refresh_crew_list()


func _on_creator_dismissed() -> void:
	_hide_creator()


func _show_creator() -> void:
	if _body:
		_body.hide()
	if _character_creator:
		_character_creator.show()


func _hide_creator() -> void:
	if _character_creator:
		_character_creator.hide()
	if _body:
		_body.show()


# ============================================================================
# LOAD / SAVE
# ============================================================================

func _load_from_campaign() -> void:
	if _campaign == null:
		return
	# Populate with set_value_no_signal so loading does NOT fire value_changed and
	# write straight back (SpinBox extends Range — a code-set fires the signal).
	_turn_spin.set_value_no_signal(int(_campaign.progress_data.get("turns_played", 0)) if "progress_data" in _campaign else 0)
	_credits_spin.set_value_no_signal(int(_campaign.credits) if "credits" in _campaign else 0)
	_supplies_spin.set_value_no_signal(int(_campaign.supplies) if "supplies" in _campaign else 0)
	_story_spin.set_value_no_signal(int(_campaign.story_points) if "story_points" in _campaign else 0)
	_rep_spin.set_value_no_signal(int(_campaign.reputation) if "reputation" in _campaign else 0)
	var debt := 0
	if "ship_data" in _campaign and _campaign.ship_data is Dictionary:
		debt = int(_campaign.ship_data.get("debt", 0))
	_debt_spin.set_value_no_signal(debt)

	var cur_diff := int(_campaign.difficulty) if "difficulty" in _campaign else 2
	for i in range(DIFFICULTY_MODES.size()):
		if int(DIFFICULTY_MODES[i]["value"]) == cur_diff:
			_difficulty_opt.select(i)
			break

	_refresh_crew_list()


func _on_validate_pressed() -> void:
	var msg := _validate()
	_notify(msg if msg != "" else "Campaign looks valid.", msg == "")


func _on_save_pressed() -> void:
	# Validate is a NON-blocking warning (single-player, their own game).
	var warn := _validate()
	var gs := get_node_or_null("/root/GameState")
	if gs and gs.has_method("save_campaign"):
		gs.save_campaign()
	var text := "Campaign saved."
	if warn != "":
		text = "Saved (with warnings): " + warn
	_notify(text, warn == "")


func _validate() -> String:
	# Returns "" if valid, else a human-readable warning. Reuses the creation
	# validator where a matching check exists; keeps it advisory.
	if _campaign == null:
		return "No campaign."
	var members: Array = _campaign.get_crew_members()
	var captains := 0
	for m in members:
		if m is Dictionary and bool(m.get("is_captain", false)):
			captains += 1
	if captains == 0:
		return "No captain in the crew (every campaign needs exactly one)."
	if captains > 1:
		return "More than one captain in the crew."
	if members.is_empty():
		return "Crew is empty."
	return ""


func _gsm_call(method: String, value) -> void:
	var gsm := get_node_or_null("/root/GameStateManager")
	if gsm and gsm.has_method(method):
		gsm.call(method, value)


func _notify(text: String, ok: bool) -> void:
	var nm := get_node_or_null("/root/NotificationManager")
	if nm and nm.has_method("show_toast"):
		nm.show_toast(text, "success" if ok else "warning")
		return
	# Fallback: a transient acknowledge dialog.
	AcknowledgeDialog.show_message(self, text)


func _on_back_pressed() -> void:
	var router := get_node_or_null("/root/SceneRouter")
	if router and router.has_method("navigate_to"):
		router.navigate_to("campaign_dashboard")
