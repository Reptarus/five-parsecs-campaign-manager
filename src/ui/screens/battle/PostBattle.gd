extends Control

## PostBattle UI for Five Parsecs Campaign Manager
## Handles post-battle results, rewards, and progression

signal phase_completed()
signal results_processed()

# UI References
@onready var mission_summary: Control = $MarginContainer/HBoxContainer/MissionSummary
@onready var rewards_panel: Control = $MarginContainer/HBoxContainer/Rewards

# State tracking
var campaign_data: Resource = null
var battle_results: Dictionary = {}
var rewards_data: Dictionary = {}

# Manager references
var alpha_manager: Node = null
var campaign_manager: Node = null

func _ready() -> void:
	_initialize_managers()
	_connect_signals()

func _initialize_managers() -> void:
	"""Initialize manager references from autoloads"""
	alpha_manager = get_node("/root/AlphaGameManager") if has_node("/root/AlphaGameManager") else null
	campaign_manager = get_node("/root/CampaignManager") if has_node("/root/CampaignManager") else null

func _connect_signals() -> void:
	"""Connect UI signals"""
	# Connect to summary and rewards panels if they have signals
	if mission_summary and mission_summary.has_signal("summary_acknowledged"):
		mission_summary.summary_acknowledged.connect(_on_summary_acknowledged)
	if rewards_panel and rewards_panel.has_signal("rewards_claimed"):
		rewards_panel.rewards_claimed.connect(_on_rewards_claimed)

func setup_phase(data: Resource) -> void:
	"""Setup the post-battle phase with campaign data"""
	campaign_data = data
	battle_results = data.get_meta("battle_results", {}) if data else {}
	_process_battle_results()
	_update_displays()

func _process_battle_results() -> void:
	"""Process the battle results and generate rewards"""
	if not alpha_manager:
		print("No alpha manager available for post-battle processing")
		return
	
	# Get battle outcome
	var victory = battle_results.get("victory", false)
	var _casualties: Array = battle_results.get("casualties", [])
	var loot_found: Array = battle_results.get("loot", [])
	
	# Generate rewards based on outcome
	rewards_data = {
		"victory": victory,
		"credits": _calculate_credit_rewards(victory),
		"experience": _calculate_experience_rewards(),
		"loot": loot_found,
		"story_progress": _calculate_story_progress(victory)
	}

	print("Battle results processed: Victory=%s, Credits=%d" % [victory, rewards_data.get("credits", 0)])

func _calculate_credit_rewards(victory: bool) -> int:
	"""Calculate credit rewards based on mission and outcome"""

	var base_credits = battle_results.get("mission_payment", 1000)
	if victory:
		return base_credits
	else:
		return base_credits / 2 # Half payment for partial success

func _calculate_experience_rewards() -> Dictionary:
	"""Calculate experience rewards for crew members"""
	var exp_rewards: Dictionary = {}
	var crew_data: Array = campaign_data.get_meta("crew", []) if campaign_data else []
	
	for crew_member in crew_data:
		var member_id = crew_member.get("id", "")
		if member_id != "":
			exp_rewards[member_id] = 1 # Base experience for participation
	
	return exp_rewards

func _calculate_story_progress(victory: bool) -> int:
	"""Calculate story progress points based on outcome"""
	if victory:
		return 2 # Victory gives more story progress
	else:
		return 1 # Participation still gives some progress

func _update_displays() -> void:
	"""Update the summary and rewards displays"""
	# Update mission summary
	if mission_summary and mission_summary.has_method("set_battle_results"):
		mission_summary.set_battle_results(battle_results)
	
	# Update rewards panel
	if rewards_panel and rewards_panel.has_method("set_rewards"):
		rewards_panel.set_rewards(rewards_data)

func _apply_rewards_to_campaign() -> void:
	"""Apply the rewards to the campaign data"""
	if not campaign_data:
		return
	
	# Add credits
	var current_credits = campaign_data.get_meta("credits", 0)
	var new_credits = current_credits + rewards_data.get("credits", 0)
	campaign_data.set_meta("credits", new_credits)
	
	# Apply experience to crew
	var experience_rewards = rewards_data.get("experience", {})
	var crew_data: Array = campaign_data.get_meta("crew", [])
	for i in range(crew_data.size()):
		var crew_member = crew_data[i]
		var member_id = crew_member.get("id", "")
		if member_id in experience_rewards:
			var current_exp = crew_member.get("experience", 0)
			crew_member["experience"] = current_exp + experience_rewards[member_id]
	campaign_data.set_meta("crew", crew_data)
	
	# Add story progress
	var current_story_points = campaign_data.get_meta("story_points", 0)
	var new_story_points = current_story_points + rewards_data.get("story_progress", 0)
	campaign_data.set_meta("story_points", new_story_points)
	
	print("Rewards applied to campaign: +%d credits, +%d story points" % [
		rewards_data.get("credits", 0),
		rewards_data.get("story_progress", 0)
	])

# Signal handlers
func _on_summary_acknowledged() -> void:
	"""Handle summary acknowledgment"""
	print("Battle summary acknowledged")

func _on_rewards_claimed() -> void:
	"""Handle rewards being claimed"""
	_apply_rewards_to_campaign()
	results_processed.emit()  # warning: return value discarded (intentional)
	print("Rewards claimed and applied")
	
	# Auto-advance after a short delay
	await get_tree().create_timer(1.0).timeout
	phase_completed.emit()  # warning: return value discarded (intentional)

func get_phase_status() -> Dictionary:
	"""Get the current phase status"""
	return {
		"battle_results": battle_results,
		"rewards_data": rewards_data,
		"results_processed": not rewards_data.is_empty()
	}

func load_campaign_data(data: Resource) -> void:
	"""Load campaign data for this phase"""
	campaign_data = data
	battle_results = data.get_meta("battle_results", {}) if data else {}
	_process_battle_results()
	_update_displays()

