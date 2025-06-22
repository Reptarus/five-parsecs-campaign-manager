extends FPCM_BasePhasePanel
class_name FPCM_AdvancementPhasePanel

const FPCM_AdvancementSystem = preload("res://src/core/character/advancement/AdvancementSystem.gd")

# UI Components
@onready var crew_list: ItemList = $"VBoxContainer/CrewList"
@onready var advancement_options: ItemList = $"VBoxContainer/AdvancementOptions"
@onready var character_info: RichTextLabel = $"VBoxContainer/CharacterInfo"
@onready var experience_display: Label = $"VBoxContainer/ExperienceDisplay"
@onready var advancement_log = $VBoxContainer/AdvancementLog
@onready var apply_button = $VBoxContainer/ApplyButton
@onready var auto_advance_button = $VBoxContainer/AutoAdvanceButton

# Manager references
var advancement_system: FPCM_AdvancementSystem
var alpha_manager: Node = null
var dice_manager: Node = null
var campaign_manager: Resource = null

# Current state
var selected_crew_member: Resource = null
var available_advancements: Array[Dictionary] = []
var selected_advancement: Dictionary = {}
var crew_members: Array[Resource] = []

func _ready() -> void:
	super._ready()
	_initialize_managers()
	_connect_signals()
	_setup_advancement_system()

func _initialize_managers() -> void:
	"""Initialize manager references from autoloads"""
	alpha_manager = get_node("/root/AlphaGameManager") if has_node("/root/AlphaGameManager") else null
	dice_manager = get_node("/root/DiceManager") if has_node("/root/DiceManager") else null
	
	if alpha_manager and alpha_manager.has_method("get_campaign_manager"):
		campaign_manager = alpha_manager.get_campaign_manager()

func _setup_advancement_system() -> void:
	"""Setup the advancement system"""
	advancement_system = FPCM_AdvancementSystem.new()
	
	# Connect advancement system signals
	advancement_system.character_advanced.connect(_on_character_advanced)
	advancement_system.experience_gained.connect(_on_experience_gained)
	advancement_system.training_completed.connect(_on_training_completed)
	advancement_system.advancement_roll_made.connect(_on_advancement_roll_made)

func _connect_signals() -> void:
	crew_list.item_selected.connect(_on_crew_selected)
	advancement_options.item_selected.connect(_on_advancement_selected)
	apply_button.pressed.connect(_on_apply_advancement)
	auto_advance_button.pressed.connect(_on_auto_advance_crew)

func setup_phase() -> void:
	super.setup_phase()
	_load_crew_data()
	_refresh_ui()

## Load crew data from campaign

func _load_crew_data() -> void:
	"""Load crew data from campaign manager"""
	crew_members.clear()
	
	if campaign_manager and campaign_manager.has_method("get_crew_members"):
		crew_members = campaign_manager.get_crew_members()
	elif alpha_manager and alpha_manager.has_method("get_current_campaign"):
		var campaign = alpha_manager.get_current_campaign()
		if campaign and campaign.has_method("get_meta"):
			crew_members = campaign.get_meta("crew_members", [])
	
	_populate_crew_list()

## Populate the crew list UI

func _populate_crew_list() -> void:
	"""Populate the crew list with crew members"""
	crew_list.clear()
	
	for crew_member in crew_members:
		var name = crew_member.get("character_name") if crew_member.has("character_name") else "Unknown"
		var xp = crew_member.get("experience_points") if crew_member.has("experience_points") else 0
		var display_text: String = "%s (XP: %d)" % [name, xp]
		crew_list.add_item(display_text)

## Refresh the entire UI

func _refresh_ui() -> void:
	"""Refresh all UI elements"""
	_populate_crew_list()
	_update_character_info()
	_update_advancement_options()
	_update_buttons()

## Update character information display

func _update_character_info() -> void:
	"""Update the character information display"""
	if not selected_crew_member:
		character_info.text = "Select a crew member to view advancement options"
		experience_display.text = ""
		return
	
	var name = selected_crew_member.get("character_name") if selected_crew_member.has("character_name") else "Unknown"
	var xp = selected_crew_member.get("experience_points") if selected_crew_member.has("experience_points") else 0
	
	# Build character info text
	var info_text: String = "[b]%s[/b]\n" % name
	info_text += "Experience Points: %d\n\n" % xp
	
	# Show current stats
	info_text += "[b]Current Stats:[/b]\n"
	info_text += "Reactions: %d\n" % (selected_crew_member.get("reactions") if selected_crew_member.has("reactions") else 1)
	info_text += "Combat Skill: %d\n" % (selected_crew_member.get("combat_skill") if selected_crew_member.has("combat_skill") else 0)
	info_text += "Toughness: %d\n" % (selected_crew_member.get("toughness") if selected_crew_member.has("toughness") else 3)
	info_text += "Savvy: %d\n" % (selected_crew_member.get("savvy") if selected_crew_member.has("savvy") else 1)
	info_text += "Speed: %d\n" % (selected_crew_member.get("speed") if selected_crew_member.has("speed") else 4)
	info_text += "Luck: %d\n\n" % (selected_crew_member.get("luck") if selected_crew_member.has("luck") else 0)
	
	# Show training
	var training = selected_crew_member.get("training") if selected_crew_member.has("training") else []
	if training.size() > 0:
		info_text += "[b]Training:[/b]\n"
		for skill in training:
			info_text += "- %s\n" % skill.capitalize()
	else:
		info_text += "[b]Training:[/b] None\n"
	
	character_info.text = info_text
	
	# Update experience display
	var stats = advancement_system.get_advancement_stats(selected_crew_member)
	experience_display.text = "XP: %d | Improvements: %d | Training: %d" % [
		stats.experience_points,
		stats.total_stat_improvements,
		stats.training_completed
	]

## Update advancement options
func _update_advancement_options() -> void:
	"""Update the available advancement options"""
	advancement_options.clear()
	available_advancements.clear()
	
	if not selected_crew_member:
		return
	
	available_advancements = advancement_system.get_available_advancements(selected_crew_member)
	
	for advancement in available_advancements:
		var display_text: String = "%s - %d XP" % [advancement.description, advancement.cost]
		advancement_options.add_item(display_text)
	
	if available_advancements.size() == 0:
		advancement_options.add_item("No advancements available")

## Update button states
func _update_buttons() -> void:
	"""Update button states based on current selection"""
	apply_button.disabled = selected_advancement.is_empty() or not selected_crew_member
	
	# Auto advance is available if any crew member has XP to spend
	var has_advancement_available: bool = false
	for crew_member in crew_members:
		var member_advancements = advancement_system.get_available_advancements(crew_member)
		if member_advancements.size() > 0:
			has_advancement_available = true
			break
	
	auto_advance_button.disabled = not has_advancement_available

## Signal handlers

func _on_crew_selected(index: int) -> void:
	"""Handle crew member selection"""
	if index >= 0 and index < crew_members.size():
		selected_crew_member = crew_members[index]
		selected_advancement = {}
		_update_character_info()
		_update_advancement_options()
		_update_buttons()

func _on_advancement_selected(index: int) -> void:
	"""Handle advancement option selection"""
	if index >= 0 and index < available_advancements.size():
		selected_advancement = available_advancements[index]
		_update_buttons()

func _on_apply_advancement() -> void:
	"""Apply the selected advancement"""
	if not selected_crew_member or selected_advancement.is_empty():
		return
	
	var advancement = selected_advancement
	var success: bool = false
	
	match advancement.type:
		"stat":
			success = advancement_system.advance_stat(selected_crew_member, advancement.target)
		"training":
			success = advancement_system.purchase_training(selected_crew_member, advancement.target)
	
	if success:
		_log_advancement("Advancement successful!")
	else:
		_log_advancement("Advancement failed or insufficient XP")
	
	# Refresh UI
	selected_advancement = {}
	_refresh_ui()

func _on_auto_advance_crew() -> void:
	"""Automatically advance all eligible crew members"""
	_log_advancement("Auto-advancing crew members...")
	
	var total_advancements: int = 0
	
	for crew_member in crew_members:
		var member_advancements = advancement_system.get_available_advancements(crew_member)
		
		# Prioritize stat improvements over training
		for advancement in member_advancements:
			if advancement.type == "stat":
				var success = advancement_system.advance_stat(crew_member, advancement.target)
				if success:
					total_advancements += 1
					_log_advancement("%s improved %s!" % [
						crew_member.get("character_name") if crew_member.has("character_name") else "Unknown",
						advancement.target.capitalize()
					])
					break
		
		# Then try training if no stat improvement was made
		if member_advancements.size() > 0:
			for advancement in member_advancements:
				if advancement.type == "training":
					var success = advancement_system.purchase_training(crew_member, advancement.target)
					if success:
						total_advancements += 1
						_log_advancement("%s completed %s training!" % [
							crew_member.get("character_name") if crew_member.has("character_name") else "Unknown",
							advancement.target.capitalize()
						])
						break
	
	_log_advancement("Auto-advancement complete: %d improvements made" % total_advancements)
	_refresh_ui()

## Advancement system signal handlers

func _on_character_advanced(character: Resource, advancement_type: String, new_value: int) -> void:
	"""Handle character advancement"""
	var name = character.get("character_name") if character.has("character_name") else "Unknown"
	_log_advancement("%s advanced %s to %d" % [name, advancement_type, new_value])

func _on_experience_gained(character: Resource, amount: int, source: String) -> void:
	"""Handle experience gained"""
	var name = character.get("character_name") if character.has("character_name") else "Unknown"
	_log_advancement("%s gained %d XP from %s" % [name, amount, source])

func _on_training_completed(character: Resource, training_type: String) -> void:
	"""Handle training completion"""
	var name = character.get("character_name") if character.has("character_name") else "Unknown"
	_log_advancement("%s completed %s training" % [name, training_type.capitalize()])

func _on_advancement_roll_made(character: Resource, stat: String, roll_result: int, success: bool) -> void:
	"""Handle advancement dice roll"""
	var name = character.get("character_name") if character.has("character_name") else "Unknown"
	var result_text: String = "SUCCESS" if success else "FAILED"
	_log_advancement("%s rolled %d for %s advancement: %s" % [name, roll_result, stat.capitalize(), result_text])

## Utility functions

func _log_advancement(message: String) -> void:
	"""Log advancement message"""
	if advancement_log:
		advancement_log.append_text("[%s] %s\n" % [Time.get_time_string_from_system(), message])
		advancement_log.scroll_to_line(advancement_log.get_line_count())
	print("Advancement: " + message)

## Award post-battle experience

func award_post_battle_experience(battle_result: Dictionary) -> void:
	"""Award experience to crew after battle"""
	if not advancement_system:
		return
	
	advancement_system.award_post_battle_experience(crew_members, battle_result)
	_refresh_ui()
