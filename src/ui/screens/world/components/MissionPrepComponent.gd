extends WorldPhaseComponent
class_name MissionPrepComponent

## Mission Prep Phase Component - Single Responsibility
## Extracted from WorldPhaseUI monolith to handle Five Parsecs mission preparation
## Implements Core Rules p.82-85 - Equipment assignment and crew readiness

# Five Parsecs dependencies
const WorldPhaseResources = preload("res://src/core/world_phase/WorldPhaseResources.gd")
const RedZoneSystem = preload("res://src/core/mission/RedZoneSystem.gd")
const BlackZoneSystem = preload("res://src/core/mission/BlackZoneSystem.gd")

# UI Components
@onready var mission_prep_container: VBoxContainer = %MissionPrepContainer
@onready var mission_briefing_label: Label = %MissionBriefingLabel
@onready var crew_list: ItemList = %CrewMembersList
@onready var equipment_list: ItemList = %EquipmentList
@onready var assign_button: Button = %AssignEquipmentButton
@onready var ready_button: Button = %ReadyForBattleButton
@onready var readiness_status_label: Label = %ReadinessStatusLabel

# Mission prep state
var mission_data: Dictionary = {}
# Sprint 26.3: Crew members are Character objects (Array type removed for flexibility)
var crew_data: Array = []
var available_equipment: Array = []
var crew_equipment_assignments: Dictionary = {}  # crew_id -> [equipment_ids]
var selected_crew_index: int = -1
var selected_equipment_index: int = -1
var prep_completed: bool = false
var automation_enabled: bool = false

# Zone info display (Core Rules Appendix III)
var _zone_info_container: VBoxContainer

func _ready() -> void:
	name = "MissionPrepComponent"
	super._ready()

func _subscribe_to_events() -> void:
	_subscribe(CampaignTurnEventBus.TurnEvent.PHASE_STARTED, _on_phase_started)
	_subscribe(CampaignTurnEventBus.TurnEvent.AUTOMATION_TOGGLED, _on_automation_toggled)
	_subscribe(CampaignTurnEventBus.TurnEvent.JOB_ACCEPTED, _on_job_accepted)

func _connect_ui_signals() -> void:
	## Connect UI button and list signals
	if crew_list:
		crew_list.item_selected.connect(_on_crew_selected)
	if equipment_list:
		equipment_list.item_selected.connect(_on_equipment_selected)
	if assign_button:
		assign_button.pressed.connect(_on_assign_equipment_pressed)
	if ready_button:
		ready_button.pressed.connect(_on_ready_for_battle_pressed)

func _setup_initial_state() -> void:
	## Initialize the component state
	prep_completed = false
	selected_crew_index = -1
	selected_equipment_index = -1
	crew_equipment_assignments.clear()
	_add_required_indicator()
	_update_ui_display()

func _add_required_indicator() -> void:
	## Add 'Required' indicator to the component title for UX clarity
	var title_label = get_node_or_null("MissionPrepContainer/HeaderPanel/HeaderContent/TitleRow/Title")
	if title_label and title_label is Label:
		# Add required badge if not already present
		if not title_label.text.contains("Required"):
			title_label.text = "Mission Preparation  •  REQUIRED"

## Public API: Initialize mission prep phase with campaign data
func initialize_mission_prep(mission: Dictionary, crew: Array, equipment: Array) -> void:
	## Initialize mission prep with mission and crew data
	mission_data = mission.duplicate()
	crew_data = crew.duplicate()
	available_equipment = equipment.duplicate()

	pass # Mission prep initialized

	# Initialize assignments from crew member's existing equipment
	crew_equipment_assignments.clear()
	for member in crew_data:
		var member_id: String = member.get("id", member.get("character_id", ""))
		var member_equipment: Array = member.get("equipment", [])
		var eq_ids: Array = []
		for eq_item in member_equipment:
			if eq_item is Dictionary:
				eq_ids.append(eq_item.get("id", eq_item.get("name", "")))
			elif eq_item is String:
				eq_ids.append(eq_item)
		crew_equipment_assignments[member_id] = eq_ids

	prep_completed = false
	_update_ui_display()

	# Publish mission prep started event
	if event_bus:
		event_bus.publish_event(CampaignTurnEventBus.TurnEvent.MISSION_PREP_STARTED, {
			"mission": mission_data,
			"crew_size": crew_data.size()
		})

## Equipment assignment logic
func assign_equipment_to_crew(crew_id: String, equipment_id: String) -> bool:
	## Assign equipment to crew member (Core Rules p.83)
	# Validate equipment is available
	var equipment_item = null
	for item in available_equipment:
		if item.get("id", "") == equipment_id:
			equipment_item = item
			break

	if not equipment_item:
		return false

	# Check if equipment is already assigned
	for assignments in crew_equipment_assignments.values():
		if equipment_id in assignments:
			return false

	# Add to crew's equipment
	if not crew_equipment_assignments.has(crew_id):
		crew_equipment_assignments[crew_id] = []

	crew_equipment_assignments[crew_id].append(equipment_id)

	pass # Equipment assigned to crew

	_update_ui_display()
	return true

func unassign_equipment_from_crew(crew_id: String, equipment_id: String) -> bool:
	## Remove equipment assignment from crew member
	if not crew_equipment_assignments.has(crew_id):
		return false

	var assignments = crew_equipment_assignments[crew_id]
	var index = assignments.find(equipment_id)
	if index >= 0:
		assignments.remove_at(index)
		_update_ui_display()
		return true

	return false

## Crew readiness checks (Core Rules p.84)
func check_crew_readiness() -> Dictionary:
	## Check if crew is ready for battle
	var readiness = {
		"is_ready": true,
		"warnings": [],
		"crew_count": crew_data.size(),
		"equipped_crew": 0,
		"total_equipment": 0
	}

	# Check each crew member
	for member in crew_data:
		var member_id = member.get("id", "")
		var equipment_count = crew_equipment_assignments.get(member_id, []).size()

		readiness.total_equipment += equipment_count

		if equipment_count > 0:
			readiness.equipped_crew += 1
		else:
			readiness.warnings.append("Warning: %s has no equipment assigned" % member.get("name", "Unknown"))

	# Core Rules p.84: Minimum crew size for mission
	if readiness.crew_count < 1:
		readiness.is_ready = false
		readiness.warnings.append("Error: No crew members available")

	# Check if mission has special requirements
	var required_crew = mission_data.get("required_crew_size", 1)
	if readiness.crew_count < required_crew:
		readiness.is_ready = false
		readiness.warnings.append("Error: Mission requires at least %d crew members" % required_crew)

	# Equipment assignment is optional — the tabletop player handles physical equip.
	# Show a warning but don't block proceeding to battle.
	if readiness.crew_count > 0 and readiness.equipped_crew == 0:
		readiness.warnings.append("Warning: No crew members have equipment assigned in-app")

	return readiness

## Auto-equip crew with best available gear
func auto_equip_crew() -> void:
	## Automatically assign equipment to crew based on roles

	# Sort equipment by effectiveness (weapons first, then gear)
	var weapons = []
	var gear = []

	for equipment in available_equipment:
		var equipment_type = equipment.get("type", "gear")
		if equipment_type == "weapon":
			weapons.append(equipment)
		else:
			gear.append(equipment)

	# Assign weapons first
	var crew_index = 0
	for weapon in weapons:
		if crew_index >= crew_data.size():
			break

		var crew_id = crew_data[crew_index].get("id", "")
		assign_equipment_to_crew(crew_id, weapon.get("id", ""))
		crew_index += 1

	# Then assign remaining gear
	crew_index = 0
	for item in gear:
		var crew_id = crew_data[crew_index % crew_data.size()].get("id", "")
		assign_equipment_to_crew(crew_id, item.get("id", ""))
		crew_index += 1


## UI Event Handlers
func _on_crew_selected(index: int) -> void:
	## Handle crew selection from list
	selected_crew_index = index
	_update_button_states()

func _on_equipment_selected(index: int) -> void:
	## Handle equipment selection from list
	selected_equipment_index = index
	_update_button_states()

func _on_assign_equipment_pressed() -> void:
	## Handle assign equipment button press
	if selected_crew_index < 0 or selected_crew_index >= crew_data.size():
		return
	if selected_equipment_index < 0 or selected_equipment_index >= available_equipment.size():
		return

	var crew_id = crew_data[selected_crew_index].get("id", "")
	var equipment_id = available_equipment[selected_equipment_index].get("id", "")

	assign_equipment_to_crew(crew_id, equipment_id)

func _on_ready_for_battle_pressed() -> void:
	## Handle ready for battle button press
	var readiness = check_crew_readiness()

	if not readiness.is_ready:
		_show_readiness_warnings(readiness.warnings)
		return

	prep_completed = true

	# Publish mission prep completed event
	if event_bus:
		event_bus.publish_event(CampaignTurnEventBus.TurnEvent.MISSION_PREPARED, {
			"mission": mission_data,
			"crew_assignments": crew_equipment_assignments,
			"readiness": readiness
		})

	_update_ui_display()

## UI Updates
func _update_ui_display() -> void:
	## Update UI display with current prep data
	_update_mission_briefing()
	_update_crew_list()
	_update_equipment_list()
	_update_readiness_status()
	_update_button_states()

func _update_mission_briefing() -> void:
	## Update mission briefing display
	if not mission_briefing_label:
		return

	var briefing: String = "Mission Briefing:\n\n"
	briefing += "Objective: %s\n" % mission_data.get(
		"objective", "Unknown")
	briefing += "Enemy: %s\n" % mission_data.get(
		"enemy_type", "Unknown")
	briefing += "Danger Level: %d\n" % mission_data.get(
		"danger_level", 0)
	briefing += "Location: %s\n" % mission_data.get(
		"location", "Unknown")
	briefing += "Pay: %d credits\n" % mission_data.get("pay", 0)
	briefing += "\nPrepare your crew and assign equipment."

	mission_briefing_label.text = briefing

	# Build zone info section if applicable
	_build_zone_info_section()

func _build_zone_info_section() -> void:
	## Build zone-specific info cards below the mission briefing
	# Clear previous zone info
	if _zone_info_container and is_instance_valid(_zone_info_container):
		_zone_info_container.queue_free()
		_zone_info_container = null

	var is_red: bool = mission_data.get("is_red_zone", false)
	var is_black: bool = mission_data.get("is_black_zone", false)
	if not is_red and not is_black:
		return

	_zone_info_container = VBoxContainer.new()
	_zone_info_container.name = "ZoneInfoContainer"
	_zone_info_container.add_theme_constant_override("separation", 8)

	if is_red:
		_build_red_zone_info()
	elif is_black:
		_build_black_zone_info()

	# Insert after the HeaderPanel in MissionPrepContainer
	if mission_prep_container:
		var insert_idx: int = 1  # After HeaderPanel
		if insert_idx < mission_prep_container.get_child_count():
			mission_prep_container.add_child(_zone_info_container)
			mission_prep_container.move_child(
				_zone_info_container, insert_idx)
		else:
			mission_prep_container.add_child(_zone_info_container)

func _build_red_zone_info() -> void:
	## Build Red Zone info card with threat condition and rules
	var card: PanelContainer = _create_zone_card(
		Color(0.86, 0.15, 0.15, 0.3),
		Color(0.86, 0.15, 0.15, 1))
	var vbox: VBoxContainer = card.get_child(0)

	var title: Label = Label.new()
	title.text = "RED ZONE MISSION"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override(
		"font_color", Color(1, 0.5, 0.5, 1))
	vbox.add_child(title)

	# Opposition info
	var opp_rules: Dictionary = RedZoneSystem.get_opposition_rules()
	var opp_label: Label = Label.new()
	opp_label.text = (
		"Fixed Opposition: %d enemies, %d Specialists "
		+ "(1 Lieutenant), +1 Unique Individual roll"
	) % [
		opp_rules.get("base_enemy_count", 7),
		opp_rules.get("specialist_count", 3)]
	opp_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	opp_label.add_theme_font_size_override("font_size", 13)
	opp_label.add_theme_color_override(
		"font_color", Color(0.88, 0.88, 0.88, 1))
	vbox.add_child(opp_label)

	# Threat condition and time constraint warnings
	var warn_label: Label = Label.new()
	warn_label.text = (
		"Threat Condition: Rolled before battle (D6)\n"
		+ "Time Constraint: Checked at end of Round 6 (D6)\n"
		+ "Invasion rolls: +2 | Galactic War: -1")
	warn_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warn_label.add_theme_font_size_override("font_size", 12)
	warn_label.add_theme_color_override(
		"font_color", Color(0.7, 0.7, 0.7, 1))
	vbox.add_child(warn_label)

	# Rewards summary
	var reward_label: Label = Label.new()
	reward_label.text = (
		"Improved Rewards: +1 XP/survivor (held field), "
		+ "credits roll 2x pick best, extra Loot roll on Win")
	reward_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reward_label.add_theme_font_size_override("font_size", 12)
	reward_label.add_theme_color_override(
		"font_color", Color(0.063, 0.725, 0.506, 1))
	vbox.add_child(reward_label)

	_zone_info_container.add_child(card)

func _build_black_zone_info() -> void:
	## Build Black Zone info card with mission type and rules
	var card: PanelContainer = _create_zone_card(
		Color(0.2, 0.05, 0.35, 0.3),
		Color(0.4, 0.1, 0.6, 1))
	var vbox: VBoxContainer = card.get_child(0)

	var title: Label = Label.new()
	title.text = "BLACK ZONE MISSION — Unity Drop"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override(
		"font_color", Color(0.85, 0.6, 1.0, 1))
	vbox.add_child(title)

	# Mission type
	var bz_mission: Dictionary = BlackZoneSystem.roll_mission_type()
	var mission_label: Label = Label.new()
	mission_label.text = "Mission: %s\n%s" % [
		bz_mission.get("name", "Unknown"),
		bz_mission.get("description", "")]
	mission_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mission_label.add_theme_font_size_override("font_size", 13)
	mission_label.add_theme_color_override(
		"font_color", Color(0.88, 0.88, 0.88, 1))
	vbox.add_child(mission_label)

	# Opposition info
	var opp_label: Label = Label.new()
	opp_label.text = (
		"Opposition: Roving Threats, 4 teams of 4 "
		+ "(16 initial enemies)\n"
		+ "Reinforcement wave arrives every round "
		+ "(Active/Passive system)\n"
		+ "No Notable Sights or Deployment Conditions")
	opp_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	opp_label.add_theme_font_size_override("font_size", 12)
	opp_label.add_theme_color_override(
		"font_color", Color(0.7, 0.7, 0.7, 1))
	vbox.add_child(opp_label)

	# Warning
	var warn_label: Label = Label.new()
	warn_label.text = (
		"WARNING: This is not intended to be fair. "
		+ "Your entire team may become casualties.")
	warn_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warn_label.add_theme_font_size_override("font_size", 12)
	warn_label.add_theme_color_override(
		"font_color", Color(0.86, 0.15, 0.15, 1))
	vbox.add_child(warn_label)

	# Advantages reminder
	var adv_label: Label = Label.new()
	adv_label.text = (
		"Advantages: 3 free Weapon Table rolls, "
		+ "no Upkeep, no Rival interference")
	adv_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	adv_label.add_theme_font_size_override("font_size", 12)
	adv_label.add_theme_color_override(
		"font_color", Color(0.063, 0.725, 0.506, 1))
	vbox.add_child(adv_label)

	_zone_info_container.add_child(card)

func _create_zone_card(
		bg_color: Color, border_color: Color) -> PanelContainer:
	## Create a styled zone info card
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = border_color
	style.set_corner_radius_all(8)
	style.content_margin_left = 16.0
	style.content_margin_top = 12.0
	style.content_margin_right = 16.0
	style.content_margin_bottom = 12.0
	card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)

	return card

func _update_crew_list() -> void:
	## Update crew list display
	if not crew_list:
		return

	var prev_selection = selected_crew_index
	crew_list.clear()
	for i in range(crew_data.size()):
		var member = crew_data[i]
		var member_id: String = ""
		var member_name: String = "Unknown"
		if member is Dictionary:
			member_id = member.get("id", "")
			member_name = member.get("name", member.get("character_name", "Unknown"))
		elif member is Object and "character_id" in member:
			member_id = member.character_id
			member_name = member.character_name if "character_name" in member else "Unknown"
		var equipment_count = crew_equipment_assignments.get(member_id, []).size()

		var crew_text = "%s (%d equipment)" % [member_name, equipment_count]
		crew_list.add_item(crew_text)

	# UX-092 FIX: Restore crew selection after list rebuild to keep button states in sync
	if prev_selection >= 0 and prev_selection < crew_list.item_count:
		crew_list.select(prev_selection)
		selected_crew_index = prev_selection
	else:
		selected_crew_index = -1

func _update_equipment_list() -> void:
	## Update equipment list display
	if not equipment_list:
		return

	# UX-092 FIX: Reset equipment selection when list is rebuilt — old index is stale
	selected_equipment_index = -1
	equipment_list.clear()
	for equipment_item in available_equipment:
		var equipment_id: String = equipment_item.get("id", "") if equipment_item is Dictionary else ""
		var equipment_name: String = equipment_item.get("name", "Unknown") if equipment_item is Dictionary else str(equipment_item)
		var is_assigned = false

		# Check if already assigned
		for assignments in crew_equipment_assignments.values():
			if equipment_id in assignments:
				is_assigned = true
				break

		var equipment_text = "%s%s" % [
			equipment_name,
			" (assigned)" if is_assigned else ""
		]
		equipment_list.add_item(equipment_text)

		# Disable if assigned
		if is_assigned:
			equipment_list.set_item_disabled(equipment_list.item_count - 1, true)

func _update_readiness_status() -> void:
	## Update readiness status display
	if not readiness_status_label:
		return

	var readiness = check_crew_readiness()

	var status_text = "Status: %s\n%d/%d crew equipped" % [
		"READY" if readiness.is_ready else "NOT READY",
		readiness.equipped_crew,
		readiness.crew_count
	]

	readiness_status_label.text = status_text

	if readiness.is_ready:
		readiness_status_label.modulate = UIColors.COLOR_EMERALD
	else:
		readiness_status_label.modulate = UIColors.COLOR_AMBER

func _update_button_states() -> void:
	## Update button enabled/disabled states
	var has_crew = selected_crew_index >= 0 and selected_crew_index < crew_data.size()
	var has_equipment = selected_equipment_index >= 0 and selected_equipment_index < available_equipment.size()

	if assign_button:
		assign_button.disabled = not (has_crew and has_equipment) or prep_completed

	if ready_button:
		ready_button.disabled = prep_completed

	# Lock selection lists after Ready (no ItemList.disabled — use mouse_filter)
	if crew_list:
		crew_list.mouse_filter = Control.MOUSE_FILTER_IGNORE if prep_completed else Control.MOUSE_FILTER_STOP
		crew_list.modulate.a = 0.5 if prep_completed else 1.0
	if equipment_list:
		equipment_list.mouse_filter = Control.MOUSE_FILTER_IGNORE if prep_completed else Control.MOUSE_FILTER_STOP
		equipment_list.modulate.a = 0.5 if prep_completed else 1.0

func _show_readiness_warnings(warnings: Array) -> void:
	## Display readiness warnings to player
	for warning in warnings:
		pass

## Event Bus Handlers
func _on_phase_started(data: Dictionary) -> void:
	## Handle phase started events
	var phase_name = data.get("phase_name", "")
	if phase_name == "mission_prep":
		pass

func _on_automation_toggled(data: Dictionary) -> void:
	## Handle automation toggle events
	automation_enabled = data.get("enabled", false)
	if automation_enabled:
		auto_equip_crew()
	pass # Automation toggled

func _on_job_accepted(data: Dictionary) -> void:
	## Handle job accepted events - auto-initialize prep phase
	var job_data = data.get("job_data", {})
	if not job_data.is_empty():

		# Get crew from GameState
		var crew: Array = []
		var game_state = get_node_or_null("/root/GameState")
		if game_state and game_state.current_campaign:
			var campaign = game_state.current_campaign
			# FiveParsecsCampaign has crew_members (Array[Character]) and get_crew_members() method
			if campaign.has_method("get_crew_members"):
				var raw_crew = campaign.get_crew_members()
				for member in raw_crew:
					if member is Dictionary:
						crew.append(member)
					elif member != null and member.has_method("to_dictionary"):
						crew.append(member.to_dictionary())
			elif "crew_data" in campaign:
				var members = campaign.crew_data.get("members", [])
				for member in members:
					if member is Dictionary:
						crew.append(member)
					elif member != null and member.has_method("to_dictionary"):
						crew.append(member.to_dictionary())

		# Get equipment from ship stash
		var equipment: Array = []
		if game_state and game_state.current_campaign:
			var campaign_eq = game_state.current_campaign
			var pool: Array = []
			if campaign_eq.has_method("get_all_equipment"):
				pool = campaign_eq.get_all_equipment()
			elif "equipment_data" in campaign_eq:
				pool = campaign_eq.equipment_data.get("equipment", [])
			for item in pool:
				if item is Dictionary:
					equipment.append(item)
			# Also gather equipment from crew members (returns Dictionaries)
			var crew_members_eq: Array = []
			if campaign_eq.has_method("get_crew_members"):
				crew_members_eq = campaign_eq.get_crew_members()
			elif "crew_data" in campaign_eq:
				crew_members_eq = campaign_eq.crew_data.get("members", [])
			for member in crew_members_eq:
				if member is Dictionary:
					var eq_list: Array = member.get("equipment", [])
					for item in eq_list:
						if item is Dictionary:
							equipment.append(item)

		pass # Initializing with crew and equipment

		# Initialize with actual data
		initialize_mission_prep(job_data, crew, equipment)

## Public API for integration
func is_prep_completed() -> bool:
	## Check if mission prep is completed
	return prep_completed

## Sprint 22.1: Alias for WorldPhaseController compatibility
func is_mission_prepared() -> bool:
	## Alias for is_prep_completed() - used by WorldPhaseController
	return is_prep_completed()

func get_crew_assignments() -> Dictionary:
	## Get crew equipment assignments
	return crew_equipment_assignments.duplicate()

func get_mission_data() -> Dictionary:
	## Get mission data
	return mission_data.duplicate()

## Sprint 12.2: Standardized step results for WorldPhaseController integration
func get_step_results() -> Dictionary:
	## Get step results for phase completion (standardized interface)
	return {
		"prep_completed": prep_completed,
		"mission_data": mission_data.duplicate(),
		"crew_assignments": crew_equipment_assignments.duplicate(),
		"crew_data": crew_data.duplicate(),
		"available_equipment": available_equipment.duplicate()
	}

func reset_mission_prep() -> void:
	## Reset mission prep for new mission
	prep_completed = false
	selected_crew_index = -1
	selected_equipment_index = -1
	crew_equipment_assignments.clear()
	mission_data.clear()
	crew_data.clear()
	available_equipment.clear()
	_update_ui_display()
