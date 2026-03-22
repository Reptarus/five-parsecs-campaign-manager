extends "res://src/ui/screens/campaign/phases/BasePhasePanel.gd"
# This file should be referenced via preload
# Use explicit preloads instead of global class names

const ThisClass = preload("res://src/ui/screens/campaign/phases/EndPhasePanel.gd")
const PlayerProfileRef = preload("res://src/core/player/PlayerProfile.gd")

signal cycle_completed
signal campaign_saved

@onready var summary_label: Label = $VBoxContainer/SummaryLabel
@onready var stats_container: VBoxContainer = $VBoxContainer/StatsContainer
@onready var save_button: Button = $VBoxContainer/SaveButton
@onready var continue_button: Button = $VBoxContainer/ContinueButton
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
		continue_button.pressed.connect(_on_continue_button_pressed)
		continue_button.disabled = true
		_style_button_disabled(continue_button)
		_setup_validation_hint(continue_button)
		_show_validation_hint("Save your campaign before continuing")

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
	var vc: Dictionary = campaign.victory_conditions \
		if "victory_conditions" in campaign else {}
	if not vc.is_empty():
		# Victory conditions may be stored in two formats:
		# 1) Direct: {target, type, progress}
		# 2) Creation format: {selected_conditions: {type: {target: N}}}
		var vc_target: int = 0
		var vc_type: String = ""
		var vc_progress: int = int(pd.get("turns_played", 0))
		if vc.has("target"):
			vc_target = int(vc.get("target", 0))
			vc_type = str(vc.get("type", ""))
			vc_progress = int(vc.get("progress", vc_progress))
		elif vc.has("selected_conditions"):
			var sel: Dictionary = vc.get("selected_conditions", {})
			for cond_type in sel:
				vc_type = str(cond_type)
				var cond_data = sel[cond_type]
				if cond_data is Dictionary:
					vc_target = int(cond_data.get("target", 0))
				break
		if vc_target > 0:
			cycle_summary["victory_progress"] = "%d / %d (%s)" % [
				vc_progress, vc_target, vc_type
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
	for stat in cycle_summary:
		var stat_label = Label.new()
		var value = cycle_summary[stat]
		var value_str: String
		if (value is int or value is float) and stat in ["credits", "story_points"]:
			value_str = _format_credits(int(value))
		elif value is float and value == floorf(value):
			value_str = str(int(value))
		else:
			value_str = str(value)
		stat_label.text = stat.capitalize().replace("_", " ") + ": " + value_str
		stats_container.add_child(stat_label)

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

func _try_archive_campaign() -> void:
	if not game_state or not game_state.campaign:
		return
	var campaign = game_state.campaign
	var vc: Dictionary = campaign.victory_conditions \
		if "victory_conditions" in campaign else {}
	var is_victory: bool = false
	if not vc.is_empty():
		var progress: int = vc.get("progress", 0)
		var target: int = vc.get("target", 0)
		is_victory = target > 0 and progress >= target

	var pd: Dictionary = campaign.progress_data \
		if "progress_data" in campaign else {}
	var turns: int = pd.get("turns_played", 0)

	# Award Elite Rank on victory (Core Rules p.65)
	if is_victory:
		var vc_type: int = vc.get("type", -1)
		var profile = PlayerProfileRef.get_instance()
		if profile and vc_type >= 0:
			var awarded: bool = profile.award_elite_rank(vc_type)
			if awarded:
				print("EndPhasePanel: Elite Rank awarded for victory condition %d (total: %d)" % [vc_type, profile.elite_ranks])

	# Archive on victory, after 20+ turns, or explicit crew retirement
	var crew_retired: bool = pd.get("crew_retired", false)
	if not is_victory and not crew_retired and turns < 20:
		return

	var legacy_sys = get_node_or_null("/root/LegacySystem")
	if not legacy_sys or not legacy_sys.has_method("archive_campaign"):
		return

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

	legacy_sys.archive_campaign(campaign_id, {
		"crew": crew_dicts,
		"story_points": campaign.story_points if "story_points" in campaign else 0,
		"turns_survived": turns,
		"victory": is_victory,
		"credits_earned": campaign.credits if "credits" in campaign else 0,
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
