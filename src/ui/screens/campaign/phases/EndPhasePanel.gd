extends "res://src/ui/screens/campaign/phases/BasePhasePanel.gd"
# This file should be referenced via preload
# Use explicit preloads instead of global class names

const ThisClass = preload("res://src/ui/screens/campaign/phases/EndPhasePanel.gd")
const PlayerProfileRef = preload("res://src/core/player/PlayerProfile.gd")
const VictoryCheckerRef = preload("res://src/core/victory/VictoryChecker.gd")

signal cycle_completed
signal campaign_saved
## Emitted after the crew retires and the campaign has been archived, so a host
## screen can leave the campaign rather than offer a next turn that cannot happen.
signal campaign_retired

@onready var summary_label: Label = $VBoxContainer/SummaryLabel
@onready var stats_container: VBoxContainer = $VBoxContainer/StatsContainer
@onready var save_button: Button = $VBoxContainer/SaveButton
@onready var continue_button: Button = $VBoxContainer/ContinueButton
@onready var retire_button: Button = $VBoxContainer/RetireButton
@onready var _cpm: Node = get_node_or_null("/root/CampaignPhaseManager")

var cycle_summary: Dictionary = {}

func _ready() -> void:
	super._ready()
	_style_phase_title(summary_label)
	_style_phase_button(save_button)
	_style_phase_button(continue_button, true)
	if save_button:
		save_button.pressed.connect(_on_save_button_pressed)
	if continue_button:
		continue_button.pressed.connect(
			_on_continue_button_pressed)
		continue_button.disabled = true
		_style_button_disabled(continue_button)
		_setup_validation_hint(continue_button)
		_show_validation_hint(
			"Save your campaign before continuing")
	# Core Rules p.8: a campaign may simply end when the players decide it has —
	# "just play until they feel their crew is either forced to disband, or has
	# made it big and can retire". The archival gate below has always read
	# progress_data["crew_retired"], and NOTHING in the codebase ever wrote it, so
	# a crew that retired was silently dropped instead of entering the Hall of
	# Fame. This button is the missing writer.
	if retire_button:
		_style_phase_button(retire_button)
		DialogStyles.style_danger_button(retire_button)
		retire_button.tooltip_text = (
			"End this campaign here and archive the crew to the Hall of Fame."
			+ "\nThis cannot be undone.")
		retire_button.pressed.connect(_on_retire_button_pressed)
	# Remove bare HSeparators, wrap stats in a card
	var vbox = $VBoxContainer
	if vbox:
		for child in vbox.get_children():
			if child is HSeparator:
				child.queue_free()
		if stats_container \
			and stats_container.get_parent() == vbox:
			_wrap_in_phase_card(
				stats_container, "Turn Summary")

func setup_phase() -> void:
	super.setup_phase()
	generate_cycle_summary()
	update_summary_display()
	if save_button:
		save_button.disabled = false

func generate_cycle_summary() -> void:
	cycle_summary = {}
	if not game_state or not "campaign" in game_state or not game_state.campaign:
		cycle_summary = {
			"turns_played": 0, "missions_completed": 0,
			"credits": 0, "crew_size": 0
		}
		return
	var campaign = game_state.campaign
	var pd: Dictionary = campaign.progress_data \
		if "progress_data" in campaign else {}
	# turns_played in progress_data may not be updated yet (written at turn completion),
	# so also check CampaignPhaseManager.turn_number as the authoritative source.
	var turn_num: int = _cpm.turn_number if _cpm and "turn_number" in _cpm else pd.get("turns_played", 0)
	cycle_summary["turns_played"] = turn_num
	cycle_summary["missions_completed"] = pd.get("missions_completed", 0)
	cycle_summary["battles_won"] = pd.get("battles_won", 0)
	cycle_summary["battles_lost"] = pd.get("battles_lost", 0)
	cycle_summary["credits"] = campaign.credits \
		if "credits" in campaign else 0
	cycle_summary["story_points"] = campaign.story_points \
		if "story_points" in campaign else 0
	var members: Array = []
	if campaign.has_method("get_crew_members"):
		members = campaign.get_crew_members()
	elif "crew_data" in campaign:
		members = campaign.crew_data.get("members", [])
	cycle_summary["crew_size"] = members.size()
	# Victory progress (Core Rules p.64) from VictoryChecker, the one counter. This
	# used to accept a top-level {target, type, progress} or a {selected_conditions}
	# wrapper; the wizard writes neither (it keys the dict by condition id), so the
	# card never rendered, and it counted turns for every condition.
	var vc_result: Dictionary = VictoryCheckerRef.check_victory(campaign, turn_num)
	if vc_result.has("required"):
		cycle_summary["victory_progress"] = "%s: %d / %d" % [
			str(vc_result.get("name", "")),
			int(vc_result.get("progress", 0)), int(vc_result.get("required", 0))
		]

func update_summary_display() -> void:
	if summary_label:
		summary_label.text = "Campaign Cycle Summary"

	if not stats_container:
		return
	# Clear existing stats
	for child in stats_container.get_children():
		child.queue_free()

	# Add stats to container
	if cycle_summary.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No campaign data available"
		empty_label.add_theme_color_override("font_color", UIColors.COLOR_TEXT_MUTED)
		stats_container.add_child(empty_label)
		return

	# Campaign Stats card
	var stats_card := PanelContainer.new()
	_style_sub_panel(stats_card)
	var stats_vbox := VBoxContainer.new()
	stats_vbox.add_theme_constant_override("separation", UIColors.SPACING_XS)

	var stats_title := Label.new()
	stats_title.text = "CAMPAIGN STATS"
	_style_section_label(stats_title)
	stats_vbox.add_child(stats_title)
	stats_vbox.add_child(HSeparator.new())

	# Core stats with formatting
	var stat_entries := {
		"Turns Played": str(cycle_summary.get("turns_played", 0)),
		"Battles": "%dW / %dL" % [
			int(cycle_summary.get("battles_won", 0)),
			int(cycle_summary.get("battles_lost", 0))
		],
		"Missions Completed": str(int(cycle_summary.get("missions_completed", 0))),
		"Credits": _format_credits(int(cycle_summary.get("credits", 0))),
		"Story Points": str(cycle_summary.get("story_points", 0)),
		"Crew Size": str(cycle_summary.get("crew_size", 0)),
	}
	for label_text in stat_entries:
		var row := HBoxContainer.new()
		var name_lbl := Label.new()
		name_lbl.text = label_text
		name_lbl.add_theme_color_override("font_color", UIColors.COLOR_TEXT_SECONDARY)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)
		var val_lbl := Label.new()
		val_lbl.text = stat_entries[label_text]
		val_lbl.add_theme_color_override("font_color", UIColors.COLOR_TEXT_PRIMARY)
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(val_lbl)
		stats_vbox.add_child(row)

	stats_card.add_child(stats_vbox)
	stats_container.add_child(stats_card)

	# Victory Progress card (if available)
	var vp: String = str(cycle_summary.get("victory_progress", ""))
	if not vp.is_empty():
		var vp_card := PanelContainer.new()
		_style_sub_panel(vp_card)
		var vp_vbox := VBoxContainer.new()
		var vp_title := Label.new()
		vp_title.text = "VICTORY PROGRESS"
		_style_section_label(vp_title)
		vp_vbox.add_child(vp_title)
		vp_vbox.add_child(HSeparator.new())
		var vp_lbl := Label.new()
		vp_lbl.text = vp
		vp_lbl.add_theme_color_override("font_color", UIColors.COLOR_CYAN)
		vp_lbl.add_theme_font_size_override("font_size", ScreenChrome.font_size(UIColors.FONT_SIZE_LG))
		vp_vbox.add_child(vp_lbl)
		vp_card.add_child(vp_vbox)
		stats_container.add_child(vp_card)

func _on_save_button_pressed() -> void:
	if game_state and game_state.has_method("save_campaign"):
		game_state.save_campaign()

	# Archive campaign to LegacySystem if victory achieved or significant play
	_try_archive_campaign()

	campaign_saved.emit()
	if save_button:
		save_button.disabled = true
	if continue_button:
		continue_button.disabled = false
		_hide_validation_hint()

## Core Rules p.8 — the players decide the campaign is over. Confirmed, because it
## is irreversible: the archive is written and the campaign stops taking turns.
func _on_retire_button_pressed() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Retire the Crew"
	dialog.ok_button_text = "Retire"
	dialog.cancel_button_text = "Keep Playing"
	var turns: int = int(cycle_summary.get("turns_played", 0))
	var crew: int = int(cycle_summary.get("crew_size", 0))
	dialog.dialog_text = (
		"End the campaign here?\n\n"
		+ "%d crew retire after %d campaign turn(s). They are archived to the "
		% [crew, turns]
		+ "Hall of Fame\nand this campaign stops taking turns.\n\n"
		+ "This cannot be undone.")
	dialog.confirmed.connect(_retire_crew)
	dialog.close_requested.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()


func _retire_crew() -> void:
	if not game_state or not game_state.campaign:
		return
	var campaign = game_state.campaign
	if not ("progress_data" in campaign):
		return
	# The flag the archival gate has always read. Written on the campaign, which
	# owns it, so it survives a save and a reload rather than living on the panel.
	campaign.progress_data["crew_retired"] = true
	if game_state.has_method("save_campaign"):
		game_state.save_campaign()
	_try_archive_campaign()
	var journal_sys = get_node_or_null("/root/CampaignJournal")
	if journal_sys and journal_sys.has_method("auto_create_milestone_entry"):
		journal_sys.auto_create_milestone_entry("crew_retired", {
			"turn": int(cycle_summary.get("turns_played", 0)),
			"stats": {"crew_count": int(cycle_summary.get("crew_size", 0))},
		})
	if retire_button:
		retire_button.disabled = true
		_style_button_disabled(retire_button)
	if continue_button:
		continue_button.disabled = true
		_style_button_disabled(continue_button)
	if save_button:
		save_button.disabled = true
	campaign_retired.emit()


## Was the picked Victory Condition met, and which one (Core Rules pp.64-65)? Pure,
## so a test can drive it without the player profile on disk. This used to read
## "progress" and "target" off the top of campaign.victory_conditions, a dict keyed
## by condition id that has neither, so no campaign ever earned an Elite Rank.
## A custom goal still wins (and is filed as a victory), but its type is -1: p.65's
## Elite Ranks are for the p.64 conditions, and a custom "7 turns" stored as TURNS_20
## would otherwise spend the real Turns-20 rank, which can be awarded only once.
static func victory_for_archive(campaign, turns: int) -> Dictionary:
	var r: Dictionary = VictoryCheckerRef.check_victory(campaign, turns)
	var vc_type: int = -1 if bool(r.get("is_custom", false)) else int(r.get("type", -1))
	return {"is_victory": bool(r.get("achieved", false)), "type": vc_type}

func _try_archive_campaign() -> void:
	if not game_state or not game_state.campaign:
		return
	var campaign = game_state.campaign
	var pd: Dictionary = campaign.progress_data \
		if "progress_data" in campaign else {}
	var turns: int = pd.get("turns_played", 0)
	var outcome: Dictionary = victory_for_archive(campaign, turns)
	var is_victory: bool = bool(outcome.get("is_victory", false))

	# Award Elite Rank on victory (Core Rules p.65)
	if is_victory:
		var vc_type: int = int(outcome.get("type", -1))
		var profile = PlayerProfileRef.get_instance()
		if profile and vc_type >= 0:
			var awarded: bool = profile.award_elite_rank(vc_type)
			if awarded:
				print_verbose("EndPhasePanel: Elite Rank awarded for victory condition %d (total: %d)" % [vc_type, profile.elite_ranks])

	# Archive on victory, after 20+ turns, or explicit crew retirement
	var crew_retired: bool = pd.get("crew_retired", false)
	if not is_victory and not crew_retired and turns < 20:
		return

	# ONCE per campaign. This function runs on every Save press, `setup_phase()`
	# re-enables the Save button each turn, and the gate above stays true forever
	# once it opens — so a campaign played past turn 20 was appending a fresh Hall
	# of Fame entry EVERY turn, and `get_best_campaign()` / `get_legacy_bonus()`
	# read that list. A campaign taken to turn 30 filed eleven copies of itself.
	if bool(pd.get("campaign_archived", false)):
		return

	var legacy_sys = get_node_or_null("/root/LegacySystem")
	if not legacy_sys or not legacy_sys.has_method("archive_campaign"):
		return
	# Claimed only once the archive is actually going to be written. Setting it
	# above the autoload guard would consume the one chance on a null LegacySystem
	# and lose the campaign permanently.
	if "progress_data" in campaign:
		campaign.progress_data["campaign_archived"] = true

	var campaign_id: String = ""
	if "campaign_id" in campaign:
		campaign_id = campaign.campaign_id
	elif "name" in campaign:
		campaign_id = campaign.name

	var crew_dicts: Array = []
	if campaign.has_method("get_crew_members"):
		for m in campaign.get_crew_members():
			if m is Dictionary:
				crew_dicts.append(m)
			elif m != null and m.has_method("to_dictionary"):
				crew_dicts.append(m.to_dictionary())

	# Victory wins the label when both are true: a crew that retires ON the turn it
	# completes its Victory Condition still earned the Elite Rank above.
	var ended_by := "ended"
	if is_victory:
		ended_by = "victory"
	elif crew_retired:
		ended_by = "retired"

	legacy_sys.archive_campaign(campaign_id, {
		"crew": crew_dicts,
		"story_points": campaign.story_points if "story_points" in campaign else 0,
		"turns_survived": turns,
		"victory": is_victory,
		"credits_earned": campaign.credits if "credits" in campaign else 0,
		"ended_by": ended_by,
	})

	# Log campaign archive as milestone in CampaignJournal
	var journal_sys = get_node_or_null("/root/CampaignJournal")
	if journal_sys and journal_sys.has_method("auto_create_milestone_entry"):
		journal_sys.auto_create_milestone_entry("campaign_archive", {
			"turn": turns,
			"stats": {
				"victory": is_victory,
				"crew_count": crew_dicts.size(),
				"turns_survived": turns,
			},
		})

func _on_continue_button_pressed() -> void:
	cycle_completed.emit()
	complete_phase()

func validate_phase_requirements() -> bool:
	return true

func get_phase_data() -> Dictionary:
	return {
		"cycle_summary": cycle_summary,
		"save_completed": save_button != null and save_button.disabled,
		"cycle_completed": continue_button != null and not continue_button.disabled
	}
