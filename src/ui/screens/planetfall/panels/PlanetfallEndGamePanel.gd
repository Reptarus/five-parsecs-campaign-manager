class_name PlanetfallEndGamePanel
extends Control

## Full-screen panel for End Game sequence: Summit, Colony Security,
## Final Milestone construction, and path resolution.
## Shown when campaign.game_phase == "endgame" between campaign turns.
## Source: Planetfall pp.160-164
##
## The stage, the Summit votes and the result live on campaign.endgame_state, so a
## relaunch reopens where the player left off instead of re-holding the Summit with fresh
## dice. Colony Security (pp.160-161) and the final milestone's cost (pp.161-163) both
## need more campaign turns when they are not met yet; "Play a Campaign Turn" hands back
## to the turn flow (continue_campaign_requested) rather than softlocking the colony.

signal phase_completed(result_data: Dictionary)
signal continue_campaign_requested

const PlanetfallEndGameScript := preload(
	"res://src/core/systems/PlanetfallEndGameSystem.gd")
const TouchScrollOpenerRef := preload("res://src/ui/components/common/TouchScrollOpener.gd")

const COLOR_TEXT_PRIMARY := UIColors.COLOR_TEXT_PRIMARY
const COLOR_TEXT_SECONDARY := UIColors.COLOR_TEXT_SECONDARY
const COLOR_ELEVATED := UIColors.COLOR_SECONDARY
const COLOR_BORDER := UIColors.COLOR_BORDER
const COLOR_ACCENT := UIColors.COLOR_BLUE
const COLOR_SUCCESS := UIColors.COLOR_EMERALD
const COLOR_WARNING := UIColors.COLOR_AMBER
const COLOR_DANGER := UIColors.COLOR_RED
const COLOR_BASE := UIColors.COLOR_PRIMARY
const FONT_SIZE_XL := 24
const FONT_SIZE_LG := 18
const FONT_SIZE_MD := 16
const FONT_SIZE_SM := 14
const FONT_SIZE_XS := 11
const SPACING_SM := 8
const SPACING_MD := 16
const SPACING_LG := 24

enum Stage { SUMMIT, PATH_SELECTION, SECURITY_CHECK, FINAL_CONSTRUCTION, RESOLUTION, COMPLETE }

## Saved by name, not ordinal, so a reordered enum cannot reopen a save on the wrong stage.
const STAGE_IDS := ["summit", "path_selection", "security_check", "final_construction",
	"resolution", "complete"]

var _campaign: Resource
var _endgame: PlanetfallEndGameScript
var _current_stage: int = Stage.SUMMIT
var _summit_results: Dictionary = {}
var _selected_path: String = ""
var _colony_future_dice: Array = []
var _loyalty_pick: int = 0
var _result: Dictionary = {}
var _moved_in_time_option: OptionButton
var _scroll: ScrollContainer
var _content: VBoxContainer
var _action_btn: Button
var _narrate_btn: Button
var _turn_btn: Button


func _ready() -> void:
	_endgame = PlanetfallEndGameScript.new()
	_build_ui()


func set_campaign(campaign_resource: Resource) -> void:
	_campaign = campaign_resource


func refresh() -> void:
	# A finished campaign (a completed End Game, or the p.90 Campaign Failure) opens on
	# its conclusion (C13); anything else opens on the stage the campaign recorded.
	var gp: String = str(_campaign.game_phase) if _campaign and "game_phase" in _campaign else ""
	var state: Dictionary = _state()
	_summit_results = state.get("summit", {}) if state.get("summit") is Dictionary else {}
	_colony_future_dice = state.get("colony_future_dice", []) \
			if state.get("colony_future_dice") is Array else []
	_result = state.get("result", {}) if state.get("result") is Dictionary else {}
	_selected_path = str(_campaign.endgame_path) if _campaign and "endgame_path" in _campaign \
			else ""
	_loyalty_pick = 0
	if gp == "completed" or gp == "failed":
		_current_stage = Stage.COMPLETE
	else:
		_current_stage = maxi(STAGE_IDS.find(str(state.get("stage", "summit"))), 0)
	_refresh_content()


## ============================================================================
## UI BUILD
## ============================================================================

func _build_ui() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bg.color = COLOR_BASE
	add_child(bg)

	_scroll = ScrollContainer.new()
	_scroll.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", SPACING_LG)
	_scroll.add_child(vbox)

	var title := Label.new()
	title.text = "THE END GAME"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_XL))
	title.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", SPACING_MD)
	vbox.add_child(_content)

	var buttons := HFlowContainer.new()
	buttons.alignment = FlowContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("h_separation", SPACING_MD)
	vbox.add_child(buttons)

	_action_btn = _make_button("Hold Summit", _on_action)
	buttons.add_child(_action_btn)
	_narrate_btn = _make_button("End With Your Own Story", _on_narrate)
	buttons.add_child(_narrate_btn)
	_turn_btn = _make_button("Play a Campaign Turn", _on_play_turn)
	buttons.add_child(_turn_btn)


func _make_button(text: String, handler: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 48)
	btn.pressed.connect(handler)
	return btn


func _refresh_content() -> void:
	for child in _content.get_children():
		child.queue_free()
	_moved_in_time_option = null
	_action_btn.visible = true
	_action_btn.disabled = false
	_narrate_btn.visible = false
	_turn_btn.visible = false

	# Each builder sets its own buttons last, so nothing here can undo a stage's gate
	# (Colony Security re-enabled its button on the very next line until 2026-10-27).
	match _current_stage:
		Stage.SUMMIT:
			_build_summit_intro()
		Stage.PATH_SELECTION:
			_build_path_selection()
		Stage.SECURITY_CHECK:
			_build_security_check()
		Stage.FINAL_CONSTRUCTION:
			_build_final_construction()
		Stage.RESOLUTION:
			_build_resolution()
		Stage.COMPLETE:
			_build_completion()
	TouchScrollOpenerRef.open_subtree(_scroll)


## ============================================================================
## STAGE CONTENT
## ============================================================================

func _build_summit_intro() -> void:
	_add_text("THE SUMMIT", FONT_SIZE_LG, COLOR_ACCENT)
	_add_text(
		"Everyone knows that a moment of decision has been reached. " +
		"You summon your most trusted companions and advisors to " +
		"discuss the fate of the colony.", FONT_SIZE_SM, COLOR_TEXT_SECONDARY)
	_add_text(
		"Each character on your roster voices an opinion. " +
		"Roll D6 per character (not bots/grunts) plus 1 for the general population.",
		FONT_SIZE_SM, COLOR_TEXT_PRIMARY)
	_action_btn.text = "Hold Summit"


func _build_path_selection() -> void:
	_action_btn.visible = false
	_add_text("SUMMIT RESULTS", FONT_SIZE_LG, COLOR_ACCENT)

	for vote in _summit_results.get("individual_votes", []):
		if vote is not Dictionary:
			continue
		_add_text("  %s rolled %d → %s" % [
			vote.get("character", "?"),
			vote.get("roll", 0),
			vote.get("vote_name", "?")],
			FONT_SIZE_SM, COLOR_TEXT_PRIMARY)

	_add_text("", FONT_SIZE_SM, COLOR_TEXT_PRIMARY)
	_add_text("SELECT YOUR PATH:", FONT_SIZE_MD, COLOR_TEXT_PRIMARY)

	var available: Array = _summit_results.get("available_paths", [])
	if available.is_empty():
		_add_text("No path has support. (p.160: an opinion nobody supports cannot be "
				+ "selected.)", FONT_SIZE_SM, COLOR_WARNING)
	for path_id in available:
		var path_data: Dictionary = _endgame.get_path_data(path_id)
		var cost: Dictionary = _endgame.final_cost_for(_campaign, path_id)
		var secure: bool = _endgame.check_colony_security(_campaign, path_id)

		var btn := Button.new()
		btn.text = "%s (Cost: %d BP, %d RP)%s" % [
			path_data.get("name", path_id.capitalize()),
			cost.get("bp", 0), cost.get("rp", 0),
			"" if secure else " [SECURITY NOT MET]"]
		btn.custom_minimum_size = Vector2(0, 48)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# "Independence (Cost: 15 BP, 5 RP) [SECURITY NOT MET]" on one line ran past a
		# phone and dragged the whole stage off-centre.
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.pressed.connect(_on_path_selected.bind(path_id))
		_content.add_child(btn)

		var desc := Label.new()
		desc.text = path_data.get("description", "")
		desc.add_theme_font_size_override("font_size", ScreenChrome.font_size(FONT_SIZE_XS))
		desc.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_content.add_child(desc)


func _build_security_check() -> void:
	var req: int = _endgame.get_security_requirement(_selected_path)
	var have: int = _endgame.get_strongpoints_destroyed(_campaign)
	var met: bool = _endgame.check_colony_security(_campaign, _selected_path)

	_add_text("COLONY SECURITY", FONT_SIZE_LG, COLOR_ACCENT)
	_add_text("Path: %s" % _selected_path.capitalize(), FONT_SIZE_MD, COLOR_TEXT_PRIMARY)
	_add_text("Strongpoints destroyed: %d of %d required" % [have, req],
			FONT_SIZE_SM, COLOR_TEXT_PRIMARY)

	_action_btn.text = "Confirm Security"
	if met:
		_add_text("Colony security requirement: MET", FONT_SIZE_MD, COLOR_SUCCESS)
	else:
		_add_text("Colony security requirement: NOT MET", FONT_SIZE_MD, COLOR_DANGER)
		_add_text("Track down and destroy a Tactical Enemy's Strongpoint (p.51) to secure "
				+ "the colony. Keep playing campaign turns until you have.",
				FONT_SIZE_SM, COLOR_TEXT_SECONDARY)
		_action_btn.disabled = true
		_turn_btn.visible = true


func _build_final_construction() -> void:
	var cost: Dictionary = _endgame.final_cost_for(_campaign, _selected_path)
	var can_afford: bool = _endgame.can_afford_final_milestone(_campaign, _selected_path,
			str(_campaign.final_breakthrough) if "final_breakthrough" in _campaign else "")

	_add_text("FINAL MILESTONE CONSTRUCTION", FONT_SIZE_LG, COLOR_ACCENT)
	_add_text("Path: %s" % _selected_path.capitalize(), FONT_SIZE_MD, COLOR_TEXT_PRIMARY)
	_add_text("Cost: %d Build Points, %d Research Points" % [
		cost.get("bp", 0), cost.get("rp", 0)], FONT_SIZE_SM, COLOR_TEXT_PRIMARY)
	_add_text("You have %d Build Points and %d Research Points." % [
		int(_campaign.buildings_data.get("current_bp", 0)),
		int(_campaign.research_data.get("current_rp", 0))], FONT_SIZE_SM, COLOR_TEXT_SECONDARY)

	_action_btn.text = "Begin Construction"
	if can_afford:
		_add_text("Resources available — ready to construct.", FONT_SIZE_SM, COLOR_SUCCESS)
	else:
		_add_text("Insufficient resources. Earn more BP/RP to construct.", FONT_SIZE_SM,
				COLOR_DANGER)
		_action_btn.disabled = true
		_turn_btn.visible = true


func _build_resolution() -> void:
	_add_text("RESOLUTION", FONT_SIZE_LG, COLOR_ACCENT)
	_add_text("Path: %s" % _selected_path.capitalize(), FONT_SIZE_MD, COLOR_TEXT_PRIMARY)
	_action_btn.text = "Resolve Fate"
	_narrate_btn.visible = _endgame.can_narrate_victory(_selected_path)
	if _narrate_btn.visible:
		_add_text("You may end the campaign as a victory here and narrate how it all ends, "
				+ "or roll for the outcome.", FONT_SIZE_SM, COLOR_TEXT_SECONDARY)

	match _selected_path:
		"loyalty":
			_build_loyalty_pick()
		"ascension":
			_build_moved_in_time_pick()
		_:
			_add_text("Press the button to determine the fate of your colony...",
					FONT_SIZE_SM, COLOR_TEXT_SECONDARY)


## p.162: "Roll 2D6 and pick either result". The dice are rolled once and saved, so
## leaving and coming back cannot re-roll them.
func _build_loyalty_pick() -> void:
	if _colony_future_dice.size() != 2:
		_colony_future_dice = _endgame.roll_colony_future_dice()
		_save_state()
	var entries: Array = _endgame.get_path_data("loyalty").get("resolution", {}) \
			.get("colony_future_entries", [])
	_add_text("The colony's long-term plan: pick either die.", FONT_SIZE_SM,
			COLOR_TEXT_PRIMARY)
	# Stacked and wrapping: a rolled 2 is "Staging ground for continued colonization
	# missions", which no phone fits on one button line.
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", SPACING_SM)
	_content.add_child(row)
	for value in _colony_future_dice:
		var name: String = ""
		for e in entries:
			if e is Dictionary and int(e.get("value", 0)) == int(value):
				name = str(e.get("name", ""))
		var btn := Button.new()
		btn.toggle_mode = true
		btn.button_pressed = _loyalty_pick == int(value)
		btn.text = "%d: %s" % [int(value), name]
		btn.custom_minimum_size = Vector2(0, 48)
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.pressed.connect(_on_loyalty_pick.bind(int(value)))
		row.add_child(btn)
	_action_btn.disabled = _loyalty_pick <= 0


## p.162: with Moved in Time and Space, "you may select one character that
## automatically rolls a 6 instead of rolling the die".
func _build_moved_in_time_pick() -> void:
	if str(_campaign.final_breakthrough) != "moved_in_time_or_space":
		_add_text("Each character on your roster undergoes the ascension process.",
				FONT_SIZE_SM, COLOR_TEXT_SECONDARY)
		return
	_add_text("Moved in Time and Space: choose one character who automatically rolls a 6.",
			FONT_SIZE_SM, COLOR_TEXT_PRIMARY)
	_moved_in_time_option = OptionButton.new()
	_moved_in_time_option.custom_minimum_size = Vector2(0, 48)
	_moved_in_time_option.add_item("(no one)")
	_moved_in_time_option.set_item_metadata(0, "")
	for c in _campaign.roster:
		if c is Dictionary:
			_moved_in_time_option.add_item(str(c.get("name", c.get("id", ""))))
			_moved_in_time_option.set_item_metadata(
					_moved_in_time_option.item_count - 1, str(c.get("id", "")))
	_content.add_child(_moved_in_time_option)


func _build_completion() -> void:
	_action_btn.text = "Return to Dashboard"
	if _campaign and _campaign.has_method("is_failed") and _campaign.is_failed():
		# p.90 Campaign Failure, verbatim.
		_add_text("CAMPAIGN FAILURE", FONT_SIZE_XL, COLOR_DANGER)
		_add_text("The Crisis ended in open rebellion. Unity forces move in to secure "
				+ "the site and take over control (Planetfall p.90).",
				FONT_SIZE_MD, COLOR_TEXT_PRIMARY)
		_add_text("Players of Five Parsecs from Home: Tactics may enjoy playing out a "
				+ "combat campaign set on your former colony, while others may take some "
				+ "of their loyal (or disloyal!) characters and set off into a Five Parsecs "
				+ "from Home adventure.", FONT_SIZE_SM, COLOR_TEXT_SECONDARY)
		return
	_add_text("CAMPAIGN COMPLETE", FONT_SIZE_XL, COLOR_SUCCESS)
	_add_text("The story of your colony has reached its conclusion.", FONT_SIZE_MD, COLOR_TEXT_PRIMARY)

	if _campaign and "endgame_path" in _campaign:
		_add_text("Path chosen: %s" % _campaign.endgame_path.capitalize(),
			FONT_SIZE_MD, COLOR_ACCENT)
	if not _result.is_empty():
		_add_text("FATE:", FONT_SIZE_MD, COLOR_WARNING)
		for line in _result.get("lines", []):
			_add_text(str(line), FONT_SIZE_SM, COLOR_TEXT_PRIMARY)


## ============================================================================
## ACTION HANDLER
## ============================================================================

func _on_action() -> void:
	match _current_stage:
		Stage.SUMMIT:
			_summit_results = _endgame.run_summit(_campaign)
			_go_to(Stage.PATH_SELECTION)

		Stage.SECURITY_CHECK:
			if _endgame.check_colony_security(_campaign, _selected_path):
				_go_to(Stage.FINAL_CONSTRUCTION)

		Stage.FINAL_CONSTRUCTION:
			# One price shown, checked and charged; a refusal charges nothing.
			if _endgame.pay_final_milestone(_campaign, _selected_path):
				_go_to(Stage.RESOLUTION)

		Stage.RESOLUTION:
			_resolve({})

		Stage.COMPLETE:
			phase_completed.emit({"endgame_completed": true, "path": _selected_path})


func _on_narrate() -> void:
	if _current_stage == Stage.RESOLUTION and _endgame.can_narrate_victory(_selected_path):
		_resolve({"narrated": true})


func _resolve(choices: Dictionary) -> void:
	if _selected_path == "loyalty":
		if _loyalty_pick <= 0:
			return
		choices["loyalty_future"] = _loyalty_pick
	if _moved_in_time_option and _moved_in_time_option.selected > 0:
		choices["moved_in_time_character"] = str(
				_moved_in_time_option.get_item_metadata(_moved_in_time_option.selected))
	_result = _endgame.resolve_path(_campaign, _selected_path, choices)
	_go_to(Stage.COMPLETE)


func _on_loyalty_pick(value: int) -> void:
	_loyalty_pick = value
	_refresh_content()


func _on_play_turn() -> void:
	continue_campaign_requested.emit()


func _on_path_selected(path_id: String) -> void:
	_selected_path = path_id
	if _campaign and "endgame_path" in _campaign:
		_campaign.endgame_path = path_id
	_go_to(Stage.SECURITY_CHECK)


func _go_to(stage: int) -> void:
	_current_stage = stage
	_save_state()
	_refresh_content()


## ============================================================================
## STATE
## ============================================================================

func _state() -> Dictionary:
	if _campaign and "endgame_state" in _campaign and _campaign.endgame_state is Dictionary:
		return _campaign.endgame_state
	return {}


func _save_state() -> void:
	if not _campaign or not "endgame_state" in _campaign:
		return
	_campaign.endgame_state = {
		"stage": STAGE_IDS[_current_stage],
		"summit": _summit_results.duplicate(true),
		"colony_future_dice": _colony_future_dice.duplicate(),
		"result": _result.duplicate(true),
	}
	# Every stage change follows dice or a payment, so it is saved at once: a relaunch
	# must not re-roll the Summit or charge the final milestone twice. Same route as the
	# turn controller's Save button.
	var gs := get_node_or_null("/root/GameState")
	if gs and gs.has_method("save_campaign"):
		gs.save_campaign(_campaign)


## ============================================================================
## HELPERS
## ============================================================================

func _add_text(text: String, size: int, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", ScreenChrome.font_size(size))
	lbl.add_theme_color_override("font_color", color)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(lbl)
