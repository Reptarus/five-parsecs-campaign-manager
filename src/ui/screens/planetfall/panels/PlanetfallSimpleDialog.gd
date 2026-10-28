class_name PlanetfallSimpleDialog
extends Control

## Reusable simple-interaction panel for Planetfall turn steps requiring
## light player input: roll buttons, spinners, simple choices.
## Used for Steps 2 (Repairs), 12 (Track Enemy Info), 13 (Replacements),
## and 17 (Character Event).
##
## Configured via configure() with a step ID that determines behavior.
## Implements the standard panel interface contract.

signal phase_completed(result_data: Dictionary)
## The turn screen's pinned footer is this step's completion control; it re-reads
## step_status() whenever this fires.
signal step_status_changed

const PlanetfallEventResolverScript := preload(
	"res://src/core/systems/PlanetfallEventResolver.gd")
const RosterRules := preload("res://src/core/systems/PlanetfallRosterRules.gd")
const CharacterEventsScript := preload("res://src/core/systems/PlanetfallCharacterEvents.gd")
## p.70 Change of assignment: "transferred to another Five Parsecs game of your choice".
const TRANSFER_TARGETS := [["five_parsecs", "Five Parsecs From Home"], ["bug_hunt", "Bug Hunt"],
		["tactics", "Tactics"]]

const COLOR_TEXT_PRIMARY := UIColors.COLOR_TEXT_PRIMARY
const COLOR_TEXT_SECONDARY := UIColors.COLOR_TEXT_SECONDARY
const COLOR_ELEVATED := UIColors.COLOR_SECONDARY
const COLOR_BORDER := UIColors.COLOR_BORDER
const COLOR_ACCENT := UIColors.COLOR_BLUE
const COLOR_SUCCESS := UIColors.COLOR_EMERALD
const COLOR_WARNING := UIColors.COLOR_AMBER
const COLOR_DANGER := UIColors.COLOR_RED
const COLOR_CYAN := UIColors.COLOR_CYAN
const FONT_SIZE_LG := 18
const FONT_SIZE_MD := 16
const FONT_SIZE_SM := 14
const SPACING_SM := 8
const SPACING_MD := 16
const SPACING_LG := 24

var _campaign: Resource
var _phase_manager: Node
var _step_id: String = ""
var _phase_index: int = -1
var _resolver: PlanetfallEventResolverScript
var _resolved: bool = false
var _result_data: Dictionary = {}

var _title_label: Label
var _content_vbox: VBoxContainer
var _result_container: VBoxContainer
var _action_btn: Button
## The step's result is in and nothing is waiting for the player, so the turn
## screen's footer may continue. This used to be a "Continue" button inside the
## scroll, beside a footer "Complete Phase" that was disabled on every step.
var _can_continue: bool = false

## Step-specific controls
var _rm_spinner: SpinBox
var _selected_character_id: String = ""
## Step 13: each replacement on offer {class, take: CheckBox, pick: OptionButton or null},
## and a Dismiss box per roster character, keyed by id (p.69).
var _replacement_offers: Array = []
var _dismiss_checks: Dictionary = {}
## Step 17: each Change of assignment awaiting the player's answer (p.70),
## {character_id, mode_pick: OptionButton, buttons: Array, decided: bool}.
var _assignment_choices: Array = []


func _ready() -> void:
	_resolver = PlanetfallEventResolverScript.new()
	_build_ui()


## ============================================================================
## PANEL INTERFACE CONTRACT
## ============================================================================

func set_campaign(campaign_resource: Resource) -> void:
	_campaign = campaign_resource


func set_phase_manager(pm: Node) -> void:
	_phase_manager = pm


func configure(step_id: String, phase_index: int) -> void:
	_step_id = step_id
	_phase_index = phase_index
	if _title_label:
		_title_label.text = _get_step_title().to_upper()


func refresh() -> void:
	_resolved = false
	_result_data = {}
	_selected_character_id = ""
	# The content below is freed and rebuilt, and a turn with no damage builds no
	# spinner, so a kept reference would point at last turn's freed node.
	_rm_spinner = null
	_replacement_offers = []
	_dismiss_checks = {}
	_assignment_choices = []
	if _title_label:
		_title_label.text = _get_step_title().to_upper()
	# Clear previous content and results
	_clear_container(_content_vbox)
	_clear_container(_result_container)
	# Build step-specific content
	_build_step_content()
	if _action_btn:
		_action_btn.visible = true
		_action_btn.disabled = false
		_action_btn.text = _get_action_button_text()
	# With no damage and no broken bot the Repairs step has nothing to decide (p.59),
	# so it is ready as built; making the player press "Apply Repairs" to apply nothing
	# only put a disabled footer and an amber "press above first" in the way.
	if _step_id == "repairs" and _nothing_to_repair():
		_resolved = true
		if _action_btn:
			_action_btn.visible = false
		_set_can_continue(true)
		return
	_set_can_continue(false)


func _nothing_to_repair() -> bool:
	if not _campaign:
		return true
	var bot_ok: bool = _campaign.bot_operational if "bot_operational" in _campaign else true
	return _colony_damage() <= 0 and bot_ok


func complete() -> void:
	if not _resolved:
		_on_action_pressed()
	else:
		_on_continue_pressed()


## ============================================================================
## UI BUILD
## ============================================================================

func _build_ui() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", SPACING_LG)
	scroll.add_child(vbox)

	# Title
	_title_label = Label.new()
	_title_label.text = _get_step_title().to_upper()
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_label.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_LG))
	_title_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	# Step-specific content area
	_content_vbox = VBoxContainer.new()
	_content_vbox.add_theme_constant_override("separation", SPACING_MD)
	vbox.add_child(_content_vbox)

	# Results area
	_result_container = VBoxContainer.new()
	_result_container.add_theme_constant_override("separation", SPACING_SM)
	vbox.add_child(_result_container)

	# Buttons
	var btn_box := HBoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_theme_constant_override("separation", SPACING_MD)
	vbox.add_child(btn_box)

	_action_btn = Button.new()
	_action_btn.text = _get_action_button_text()
	_action_btn.custom_minimum_size = Vector2(0, 48)
	_action_btn.pressed.connect(_on_action_pressed)
	btn_box.add_child(_action_btn)


## ============================================================================
## STEP-SPECIFIC CONTENT
## ============================================================================

func _build_step_content() -> void:
	match _step_id:
		"repairs":
			_build_repairs_content()
		"track_enemy_info":
			_build_track_info_content()
		"replacements":
			_build_replacements_content()
		"character_event":
			_build_character_event_content()


func _build_repairs_content() -> void:
	## Step 2: Colony damage repair + RM conversion. Planetfall p.59.
	if not _campaign:
		return
	var integrity: int = _campaign.colony_integrity if "colony_integrity" in _campaign else 0
	var repair_rate: int = _campaign.repair_capacity if "repair_capacity" in _campaign else 1
	var rm: int = _campaign.raw_materials if "raw_materials" in _campaign else 0
	var bot_broken: bool = not (_campaign.bot_operational if "bot_operational" in _campaign else true)
	var damage: int = _colony_damage()

	_add_info_text("Colony Integrity: %d" % integrity)
	if "max_colony_integrity" in _campaign:
		_add_info_text("Maximum Integrity: %d" % _campaign.max_colony_integrity)
	_add_info_text("Base Repair Rate: %d point(s) per turn" % repair_rate)
	_add_info_text("Raw Materials Available: %d" % rm)

	if damage <= 0:
		_add_info_text("\n[color=ui-success]No colony damage to repair.[/color]")

	if bot_broken:
		_add_info_text(
			"\n[color=ui-warning]Colony Bot is Broken — it will be repaired but cannot deploy this turn.[/color]")

	# RM-to-repair spinner: p.59 "up to 3 units", capped by what is held AND by the
	# damage the base rate leaves, so the dialog cannot take a unit that repairs nothing.
	var max_rm: int = mini(mini(3, rm), maxi(0, damage - repair_rate))
	if max_rm > 0:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", SPACING_SM)
		_content_vbox.add_child(row)

		var lbl := Label.new()
		lbl.text = "Spend Raw Materials for extra repairs (max 3):"
		lbl.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_SM))
		lbl.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
		row.add_child(lbl)

		_rm_spinner = SpinBox.new()
		_rm_spinner.min_value = 0
		_rm_spinner.max_value = max_rm
		_rm_spinner.value = 0
		_rm_spinner.step = 1
		_rm_spinner.custom_minimum_size.x = 80
		row.add_child(_rm_spinner)


func _build_track_info_content() -> void:
	## Step 12: Track Enemy Information & Mission Data. Planetfall p.68.
	_add_info_text(
		"If you fought a Tactical Enemy and won, add 1 Enemy Information for that enemy type.")
	_add_info_text(
		"Note any Mission Data obtained on your roster.")
	_add_info_text(
		"\nThe TurnController will track these automatically based on battle results.")


func _build_replacements_content() -> void:
	## Step 13: Replacement phase. Planetfall p.69.
	if not _campaign:
		return
	var roster_size: int = _campaign.roster.size() if "roster" in _campaign else 0
	var capacity: int = RosterRules.roster_capacity(_campaign)
	var milestones: int = _campaign.milestones_completed if "milestones_completed" in _campaign else 0
	var attempts: int = 1 + milestones

	_add_info_text("Current Roster: %d / %d" % [roster_size, capacity])
	_add_info_text("Replacement Attempts Available: %d (1 + %d milestones)" % [attempts, milestones])

	if roster_size >= capacity:
		_add_info_text("\n[color=ui-warning]Roster is full. Dismiss a character below "
				+ "before rolling to make room.[/color]")

	# p.69: "you may dismiss characters from your roster at this stage. Dismissed
	# characters cannot be returned to the campaign later." Chosen before the roll, so a
	# dismissal can make the room a replacement needs.
	if roster_size > 0:
		_add_info_text("\nDismiss (cannot return to the campaign later):")
		for c in _campaign.roster:
			if c is not Dictionary:
				continue
			var check := CheckBox.new()
			check.text = "%s (%s)" % [str(c.get("name", "?")),
					str(c.get("class", "")).capitalize()]
			check.custom_minimum_size = Vector2(0, 48)
			_content_vbox.add_child(check)
			_dismiss_checks[str(c.get("id", ""))] = check


func _build_character_event_content() -> void:
	## Step 17: Character Event. Planetfall pp.70-71.
	if not _campaign or not "roster" in _campaign:
		return
	var roster: Array = _campaign.roster
	_add_info_text("A random character will be selected for a Character Event.")
	_add_info_text("Roster size: %d characters" % roster.size())


## ============================================================================
## ACTION HANDLERS
## ============================================================================

func _on_action_pressed() -> void:
	_action_btn.disabled = true
	_resolved = true

	match _step_id:
		"repairs":
			_resolve_repairs()
		"track_enemy_info":
			_resolve_track_info()
		"replacements":
			_resolve_replacements()
		"character_event":
			_resolve_character_event()

	# A Change of assignment waits for the player's answer before the step can end.
	var waiting: bool = false
	for e in _assignment_choices:
		if not bool(e.decided):
			waiting = true
	_set_can_continue(not waiting)


func _on_continue_pressed() -> void:
	if _step_id == "replacements":
		_collect_replacements()
	# The footer can continue without an answer: the character stays (declines).
	for e in _assignment_choices.duplicate():
		if not bool(e.decided):
			_decide_assignment(e, false)
	_can_continue = false
	phase_completed.emit(_result_data)


func _resolve_repairs() -> void:
	## Step 2 resolution. Planetfall p.59.
	if not _campaign:
		return
	var repair_rate: int = _campaign.repair_capacity if "repair_capacity" in _campaign else 1

	# Base repair
	var total_repair: int = repair_rate

	# RM conversion
	var rm_spent: int = 0
	if _rm_spinner:
		rm_spent = int(_rm_spinner.value)
		total_repair += rm_spent

	# p.87: repairs restore Integrity up to its MAXIMUM, which buildings raise; this
	# used to stop at 0, so a colony that had built Integrity could never repair.
	# The Raw Materials are REPORTED in rm_spent and spent by the phase manager: this
	# dialog spent them as well until 2026-10-27, so every unit cost two (T2a).
	if _colony_damage() > 0:
		var actual_repair: int = _campaign.repair_colony(total_repair) \
			if _campaign.has_method("repair_colony") else 0
		_add_result_bbcode(
			"[color=ui-success]Repaired %d point(s) of colony damage.[/color]" % actual_repair)
		if rm_spent > 0:
			_add_result_bbcode("Spent %d Raw Material(s) for extra repairs." % rm_spent)
		_result_data["rm_spent"] = rm_spent
	else:
		_add_result_bbcode("No colony damage to repair.")

	# Bot repair. repair_bot() records the turn, which is what keeps the bot out of this
	# turn's battle (p.59) -- setting the flag alone let it deploy straight away.
	if _campaign and _campaign.has_method("repair_bot") and _campaign.repair_bot():
		_add_result_bbcode(
			"[color=ui-success]Colony Bot repaired![/color] (Cannot deploy this turn.)")


## Damage a repair may restore: how far Integrity is below its maximum (p.87).
func _colony_damage() -> int:
	if _campaign and _campaign.has_method("integrity_damage"):
		return _campaign.integrity_damage()
	var integrity: int = _campaign.colony_integrity if _campaign and "colony_integrity" in _campaign else 0
	return maxi(0, -integrity)


func _resolve_track_info() -> void:
	## Step 12 resolution. Planetfall p.68.
	_add_result_bbcode("Enemy Information and Mission Data tracked.")
	_add_result_bbcode(
		"[color=ui-secondary]Full tracking will be automated when battle results are wired.[/color]")


func _resolve_replacements() -> void:
	## Step 13 resolution. Planetfall p.69. This printed "N new character(s) added to
	## roster" while nothing read new_characters, and a 9-12 "replacement of your choice"
	## silently became a trooper. Each success is now an OFFER the player takes or not
	## ("You may take"); the phase manager adds what was taken when the step completes.
	if not _campaign:
		return
	for check in _dismiss_checks.values():
		(check as CheckBox).disabled = true
	var roster_size: int = (_campaign.roster.size() if "roster" in _campaign else 0) \
			- _dismissed_ids().size()
	var capacity: int = RosterRules.roster_capacity(_campaign)
	if roster_size >= capacity:
		_add_result_bbcode("Roster is full: no replacements needed.")
		return

	var milestones: int = _campaign.milestones_completed if "milestones_completed" in _campaign else 0
	var attempts: int = 1 + milestones

	for attempt_num in range(attempts):
		if roster_size + _replacement_offers.size() >= capacity:
			_add_result_bbcode("Roster full: remaining attempts skipped.")
			break

		var roll: int = _resolver.roll_2d6("Planetfall Replacement Roll")
		var result: Dictionary = _resolver.resolve_replacement(roll)
		var result_type: String = result.get("result", "none")

		_add_result_bbcode(
			"[b]Attempt %d:[/b] Rolled 2D6 = %d" % [attempt_num + 1, roll])

		match result_type:
			"none":
				_add_result_bbcode("  No replacement available.")
			"random_class":
				var class_roll: int = _resolver.roll_d6("Planetfall Replacement Class")
				var char_class: String = _resolver.resolve_replacement_class(class_roll)
				_add_result_bbcode(
					"  [color=ui-success]Replacement available![/color] D6 = %d → %s" % [
						class_roll, char_class.capitalize()])
				_add_replacement_offer(char_class, false)
			"player_choice":
				_add_result_bbcode(
					"  [color=ui-success]Replacement of your choice available![/color]")
				_add_replacement_offer("trooper", true)

	if not _replacement_offers.is_empty():
		_add_result_bbcode("\nEach replacement you take joins the roster with the standard "
				+ "profile at Loyalty Committed when you continue.")


func _add_replacement_offer(char_class: String, choice: bool) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", SPACING_SM)
	var take := CheckBox.new()
	take.button_pressed = true
	take.custom_minimum_size = Vector2(0, 48)
	take.text = "Take a replacement of your choice:" if choice \
			else "Take the %s" % char_class.capitalize()
	row.add_child(take)
	var pick: OptionButton = null
	if choice:
		pick = OptionButton.new()
		for cls in RosterRules.REPLACEMENT_CLASSES:
			pick.add_item(str(cls).capitalize())
		pick.custom_minimum_size = Vector2(0, 48)
		row.add_child(pick)
	_result_container.add_child(row)
	_replacement_offers.append({"class": char_class, "take": take, "pick": pick})


func _dismissed_ids() -> Array:
	var out: Array = []
	for id in _dismiss_checks:
		if (_dismiss_checks[id] as CheckBox).button_pressed:
			out.append(id)
	return out


## What the player chose at Step 13, for the phase manager to apply.
func _collect_replacements() -> void:
	var taken: Array = []
	for offer in _replacement_offers:
		if not (offer.take as CheckBox).button_pressed:
			continue
		var cls: String = str(offer["class"])
		var pick: OptionButton = offer.pick
		if pick != null and pick.selected >= 0:
			cls = str(RosterRules.REPLACEMENT_CLASSES[pick.selected])
		taken.append({"class": cls})
	_result_data["new_characters"] = taken
	_result_data["dismissed"] = _dismissed_ids()


func _resolve_character_event() -> void:
	## Step 17 resolution. Planetfall pp.70-71.
	if not _campaign or not "roster" in _campaign:
		_add_result_bbcode("No roster available.")
		return

	var roster: Array = _campaign.roster
	if roster.is_empty():
		_add_result_bbcode("No characters in roster.")
		return

	# The normal event plus any a Milestone queued (p.156: "Roll 2 Character Events
	# immediately ... in addition to the normal event"). The phase manager clears the
	# queue when this step completes.
	var extra: int = _campaign.get_extra_rolls("character_event") \
			if _campaign.has_method("get_extra_rolls") else 0
	var events: Array = []
	for n in range(1 + extra):
		if n > 0:
			_add_result_bbcode("\n[b]Milestone Character Event %d of %d[/b]" % [n, extra])
		events.append(_resolve_one_character_event(roster))
	_result_data["events"] = events


## pp.70-71. PlanetfallCharacterEvents decides, the phase manager applies. Until
## 2026-10-27 this applied six of the twenty rows itself and printed the rest.
func _resolve_one_character_event(_roster: Array) -> Dictionary:
	# p.70 R&R: a character off world "cannot be the target of events".
	var eligible: Array = []
	for c in _campaign.roster:
		if c is Dictionary and not (_campaign.has_method("is_away")
				and _campaign.is_away(str(c.get("id", "")))):
			eligible.append(c)
	if eligible.is_empty():
		_add_result_bbcode("Every character is off world: no Character Event.")
		return {}
	var char_dict: Dictionary = eligible[_resolver.pick_index(eligible.size(),
			"Planetfall Event Character Pick")]
	_selected_character_id = str(char_dict.get("id", ""))

	var roll: int = _resolver.roll_d100("Planetfall Step 17 Event")
	var ctx: Dictionary = _phase_manager.character_event_context() \
			if _phase_manager and _phase_manager.has_method("character_event_context") \
			else {"roster": _campaign.roster.duplicate(true), "campaign_turn": _campaign.campaign_turn}
	var receipt: Dictionary = CharacterEventsScript.new().resolve(ctx, _selected_character_id, roll)
	var event: Dictionary = receipt.get("event", {})

	_add_result_bbcode("[b]Selected Character:[/b] %s" % str(char_dict.get("name", "Unknown")))
	_add_result_bbcode("[b]D100 Roll:[/b] %d" % roll)
	_add_result_bbcode("\n[b]%s[/b]" % str(event.get("name", "Unknown Event")))
	_add_result_bbcode(str(event.get("description", "")))
	for line in receipt.get("lines", []):
		_add_result_bbcode("[color=ui-success]%s[/color]" % str(line))
	for note in _apply_event_ops(receipt.get("ops", [])):
		_add_result_bbcode("[color=ui-success]%s[/color]" % str(note))
	if not (receipt.get("choice", {}) as Dictionary).is_empty():
		_add_assignment_choice(receipt.choice)

	if not _result_data.has("character_id"):
		_result_data["character_id"] = _selected_character_id
		_result_data["event"] = event
	return {"character_id": _selected_character_id, "event": event}


func _apply_event_ops(ops: Array) -> Array:
	if ops.is_empty() or not _phase_manager \
			or not _phase_manager.has_method("apply_character_event_ops"):
		return []
	return _phase_manager.apply_character_event_ops(ops)


## p.70 Change of assignment: "Decide if they accept. If they do, they immediately earn
## 5 XP and are transferred to another Five Parsecs game of your choice. If they decline,
## gain 1 level of Loyalty."
func _add_assignment_choice(choice: Dictionary) -> void:
	var entry: Dictionary = {"character_id": str(choice.get("character_id", "")),
		"decided": false, "buttons": []}
	var mode_pick := OptionButton.new()
	mode_pick.custom_minimum_size = Vector2(0, 48)
	for t in TRANSFER_TARGETS:
		mode_pick.add_item(str(t[1]))
	entry["mode_pick"] = mode_pick
	_result_container.add_child(mode_pick)
	for accept in [true, false]:
		var btn := Button.new()
		btn.text = "Accept the transfer" if accept else "Decline (gain a level of Loyalty)"
		btn.custom_minimum_size = Vector2(0, 48)
		btn.pressed.connect(_decide_assignment.bind(entry, accept))
		_result_container.add_child(btn)
		(entry.buttons as Array).append(btn)
	_assignment_choices.append(entry)


func _decide_assignment(entry: Dictionary, accept: bool) -> void:
	if bool(entry.decided):
		return
	entry.decided = true
	for b in entry.buttons:
		(b as Button).disabled = true
	(entry.mode_pick as OptionButton).disabled = true
	var cid: String = str(entry.character_id)
	if not accept:
		for note in _apply_event_ops([{"op": "loyalty_gain", "character_id": cid}]):
			_add_result_bbcode("[color=ui-success]%s[/color]" % str(note))
		_after_assignment_decided()
		return
	_apply_event_ops([{"op": "xp", "character_id": cid, "amount": CharacterEventsScript.TRANSFER_XP}])
	var who: Variant = _campaign.get_roster_character_by_id(cid)
	var mode: String = str(TRANSFER_TARGETS[maxi((entry.mode_pick as OptionButton).selected, 0)][0])
	var path := ""
	if who is Dictionary:
		var envelope: Dictionary = CharacterTransferService.new().transfer_character(
				(who as Dictionary).duplicate(true), "planetfall", mode)
		envelope["source_campaign_id"] = _campaign.campaign_id if "campaign_id" in _campaign else ""
		path = CharacterTransferService.write_pending_transfer(envelope)
	# The transfer file is the only copy once the character leaves, so the roster entry
	# is dropped only after it is on disk.
	if path == "":
		_add_result_bbcode("[color=ui-danger]The transfer could not be written; the "
				+ "character stays on the roster.[/color]")
	else:
		_campaign.dismiss_character(cid)
		(_result_data.get_or_add("transfers", []) as Array).append(path)
		_add_result_bbcode("[color=ui-success]+%d XP, and transferred to %s.[/color]"
				% [CharacterEventsScript.TRANSFER_XP, str(TRANSFER_TARGETS[
				maxi((entry.mode_pick as OptionButton).selected, 0)][1])])
	_after_assignment_decided()


func _after_assignment_decided() -> void:
	for e in _assignment_choices:
		if not bool(e.decided):
			return
	_set_can_continue(true)


## ============================================================================
## HELPERS
## ============================================================================

## The book's step heading, read from the phase manager's one name table rather than
## hand-copied here (see PlanetfallAutoResolveDialog._get_step_title()).
func _get_step_title() -> String:
	var names: Dictionary = load("res://src/core/campaign/PlanetfallPhaseManager.gd").PHASE_NAMES
	if names.has(_phase_index):
		return "Step %d: %s" % [_phase_index + 1, names[_phase_index]]
	return "Simple Dialog"


func _get_action_button_text() -> String:
	match _step_id:
		"repairs": return "Apply Repairs"
		"track_enemy_info": return "Confirm"
		"replacements": return "Roll for Replacements"
		"character_event": return "Roll Character Event"
	return "Resolve"


func _add_info_text(text: String) -> void:
	var lbl := RichTextLabel.new()
	lbl.bbcode_enabled = true
	lbl.fit_content = true
	lbl.scroll_active = false
	lbl.text = UIColors.bbcode(text)
	ScreenChrome.size_rich_text(lbl, ScreenChrome.font_size(FONT_SIZE_SM))
	lbl.add_theme_color_override("default_color", COLOR_TEXT_SECONDARY)
	_content_vbox.add_child(lbl)


func _add_result_bbcode(text: String) -> void:
	var lbl := RichTextLabel.new()
	lbl.bbcode_enabled = true
	lbl.fit_content = true
	lbl.scroll_active = false
	lbl.text = UIColors.bbcode(text)
	ScreenChrome.size_rich_text(lbl, ScreenChrome.font_size(FONT_SIZE_SM))
	lbl.add_theme_color_override("default_color", COLOR_TEXT_PRIMARY)
	_result_container.add_child(lbl)


func _clear_container(container: VBoxContainer) -> void:
	if not container:
		return
	for child in container.get_children():
		child.queue_free()


## What the turn screen's footer shows for this step: {ready, reason}. The footer
## names the next step itself.
func step_status() -> Dictionary:
	var status: Dictionary = {"ready": _can_continue, "reason": ""}
	if not _can_continue:
		status.reason = "Press \"%s\" to finish this step." % _get_action_button_text() if not _resolved \
				else "Answer the Change of Assignment above first (p.70)."
	return status


func _set_can_continue(value: bool) -> void:
	_can_continue = value
	step_status_changed.emit()
