extends BasePhasePanel
class_name UpkeepPhasePanel

@onready var upkeep_cost_label = $VBoxContainer/UpkeepCostLabel
@onready var crew_list = $VBoxContainer/CrewList
@onready var resources_list = $VBoxContainer/ResourcesList
@onready var pay_upkeep_button = $VBoxContainer/PayUpkeepButton

var total_upkeep_cost: int = 0
var crew_upkeep_costs: Dictionary = {}

func _setup_phase_ui() -> void:
	var base_container = VBoxContainer.new()
	base_container.add_theme_constant_override("separation", 10)
	add_child(base_container)
	
	var title = Label.new()
	title.text = "Upkeep Phase"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	base_container.add_child(title)
	
	upkeep_cost_label = Label.new()
	upkeep_cost_label.text = "Calculating upkeep costs..."
	base_container.add_child(upkeep_cost_label)
	
	crew_list = ItemList.new()
	crew_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	base_container.add_child(crew_list)
	
	resources_list = ItemList.new()
	resources_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	base_container.add_child(resources_list)
	
	pay_upkeep_button = Button.new()
	pay_upkeep_button.text = "Pay Upkeep"
	pay_upkeep_button.disabled = true
	base_container.add_child(pay_upkeep_button)

func _connect_signals() -> void:
	pay_upkeep_button.pressed.connect(_on_pay_upkeep_pressed)

func _on_phase_started() -> void:
	_calculate_upkeep_costs()
	_update_ui()

func _validate_phase_requirements() -> Dictionary:
	if not game_state or not game_state.campaign:
		return {
			"valid": false,
			"error": "No active campaign found"
		}
	
	if not game_state.campaign.crew_members or game_state.campaign.crew_members.is_empty():
		return {
			"valid": false,
			"error": "No crew members found"
		}
	
	return {
		"valid": true,
		"error": ""
	}

func _calculate_upkeep_costs() -> void:
	total_upkeep_cost = 0
	crew_upkeep_costs.clear()
	
	for crew_member in game_state.campaign.crew_members:
		var member_cost = _calculate_crew_member_upkeep(crew_member)
		crew_upkeep_costs[crew_member.id] = member_cost
		total_upkeep_cost += member_cost

func _calculate_crew_member_upkeep(crew_member: Character) -> int:
	# Base upkeep cost is 1 credit per level
	var base_cost = crew_member.level
	
	# Add equipment maintenance costs
	for item in crew_member.equipment:
		if item.has("maintenance_cost"):
			base_cost += item.maintenance_cost
	
	# Apply any cost modifiers from traits or abilities
	for current_trait in crew_member.traits:
		if current_trait.has("upkeep_modifier"):
			base_cost = base_cost * current_trait.upkeep_modifier
	
	return base_cost

func _update_ui() -> void:
	upkeep_cost_label.text = "Total Upkeep Cost: %d credits" % total_upkeep_cost
	
	crew_list.clear()
	for crew_member in game_state.campaign.crew_members:
		var cost = crew_upkeep_costs[crew_member.id]
		crew_list.add_item("%s - %d credits" % [crew_member.character_name, cost])
	
	resources_list.clear()
	resources_list.add_item("Available Credits: %d" % game_state.campaign.credits)
	
	pay_upkeep_button.disabled = game_state.campaign.credits < total_upkeep_cost

func _on_pay_upkeep_pressed() -> void:
	if game_state.campaign.credits >= total_upkeep_cost:
		game_state.campaign.credits -= total_upkeep_cost
		_handle_upkeep_effects()
		complete_phase()
	else:
		_on_phase_failed("Insufficient credits to pay upkeep")

func _handle_upkeep_effects() -> void:
	# Apply any special effects from not being able to pay full upkeep
	# or from traits/abilities that trigger during upkeep
	for crew_member in game_state.campaign.crew_members:
		for current_trait in crew_member.traits:
			if current_trait.has("upkeep_effect"):
				_apply_trait_upkeep_effect(crew_member, current_trait)

func _apply_trait_upkeep_effect(crew_member: Character, current_trait: Dictionary) -> void:
	match current_trait.upkeep_effect:
		"MORALE_BOOST":
			crew_member.morale += 1
		"MAINTENANCE_EXPERT":
			# Refund some maintenance costs
			var refund = crew_upkeep_costs[crew_member.id] * 0.25
			game_state.campaign.credits += int(refund)
		"RESOURCE_DRAIN":
			# Some traits might have negative effects
			crew_member.morale -= 1

func _on_phase_failed(error_message: String) -> void:
	push_error("Upkeep phase failed: " + error_message)
	var dialog = AcceptDialog.new()
	dialog.title = "Upkeep Failed"
	dialog.dialog_text = error_message
	add_child(dialog)
	dialog.popup_centered()