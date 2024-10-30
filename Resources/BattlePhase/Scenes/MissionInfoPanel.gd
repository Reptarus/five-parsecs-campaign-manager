extends PanelContainer

@onready var source_label = %SourceLabel
@onready var conditions_list = %ConditionsList
@onready var deployment_label = %DeploymentLabel
@onready var terrain_list = %TerrainList

func setup(mission_data: Dictionary) -> void:
	# Set mission source and patron
	var source_text = "Source: %s" % mission_data.source
	if mission_data.patron:
		source_text += " [%s]" % mission_data.patron
	source_label.text = source_text
	
	# Set special conditions
	conditions_list.clear()
	conditions_list.add_text("Special Conditions:")
	for condition in mission_data.conditions:
		conditions_list.add_text("• " + condition)
	
	# Set deployment type
	deployment_label.text = "Deployment Type:\n%s" % mission_data.deployment_type
	
	# Set suggested terrain
	terrain_list.clear()
	terrain_list.add_text("Suggested Terrain:")
	for terrain in mission_data.terrain_requirements:
		terrain_list.add_text("- " + terrain)
