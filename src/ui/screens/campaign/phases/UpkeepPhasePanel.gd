extends BasePhasePanel
class_name FPCM_UpkeepPhasePanel

const Character = preload("res://src/core/character/Base/Character.gd")

@onready var upkeep_cost_label = $VBoxContainer/UpkeepCostLabel
@onready var crew_list = $VBoxContainer/CrewList
@onready var resources_list = $VBoxContainer/ResourcesList
@onready var pay_upkeep_button = $VBoxContainer/PayUpkeepButton

var total_upkeep_cost: int = 0
var crew_members: Array[Character] = []

func _ready() -> void:
	super._ready()
	pay_upkeep_button.pressed.connect(_on_pay_upkeep_pressed)
	
func setup_phase() -> void:
	super.setup_phase()
	_update_crew_list()
	_calculate_upkeep()
	_update_resources_list()

func _update_crew_list() -> void:
	crew_list.clear()
	crew_members = game_state.campaign.get_active_crew_members()
	
	for crew_member in crew_members:
		var crew_item = crew_list.add_item(crew_member.character_name)
		if crew_member.is_wounded:
			crew_item.modulate = Color.RED

func _calculate_upkeep() -> void:
	total_upkeep_cost = 0
	
	for crew_member in crew_members:
		var member_cost = 6 # Base upkeep cost
		
		# Apply modifiers based on traits - convert enum to string
		if crew_member.has_trait("TACTICAL_MIND"): # Using string value instead of enum
			member_cost -= 1 # Tactical minds are more efficient with resources
		if crew_member.has_trait("STREET_SMART"): # Using string value instead of enum
			member_cost -= 2 # Street smart characters know how to live cheaply
			
		total_upkeep_cost += member_cost
	
	upkeep_cost_label.text = "Total Upkeep Cost: " + str(total_upkeep_cost) + " credits"

func _update_resources_list() -> void:
	resources_list.clear()
	var credits = game_state.campaign.credits
	resources_list.add_item("Credits: " + str(credits))
	
	pay_upkeep_button.disabled = credits < total_upkeep_cost

func _on_pay_upkeep_pressed() -> void:
	game_state.campaign.credits -= total_upkeep_cost
	_update_resources_list()
	complete_phase()

func validate_phase_requirements() -> bool:
	return game_state.campaign.credits >= total_upkeep_cost

func get_phase_data() -> Dictionary:
	return {
		"total_upkeep_cost": total_upkeep_cost,
		"crew_count": crew_members.size(),
		"can_pay": validate_phase_requirements()
	}

func _handle_upkeep_effects() -> void:
	# Apply any special effects from traits
	for crew_member in crew_members:
		if crew_member.has_trait("TACTICAL_MIND"): # Using string value instead of enum
			# Tactical minds can sometimes find ways to save money
			var refund = total_upkeep_cost * 0.1
			game_state.campaign.credits += int(refund)

func _on_phase_failed(error_message: String) -> void:
	push_error("Upkeep phase failed: " + error_message)
	var dialog = AcceptDialog.new()
	dialog.title = "Upkeep Failed"
	dialog.dialog_text = error_message
	add_child(dialog)
	dialog.popup_centered()
