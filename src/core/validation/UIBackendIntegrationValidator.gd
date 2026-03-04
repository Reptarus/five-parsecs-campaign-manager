class_name UIBackendIntegrationValidator
extends RefCounted

## UI-Backend Integration Validation System
## Validates data flow integrity between UI components and backend systems
## Part of the Five Parsecs Campaign Manager validation framework

# GlobalEnums available as autoload singleton

## Validation result types for UI-backend integration
enum IntegrationValidationType {
	CAMPAIGN_CREATION_FLOW,
	TURN_SYSTEM_INTEGRATION,
	BACKEND_SYSTEM_AVAILABILITY,
	SIGNAL_CONNECTION_INTEGRITY,
	DATA_FLOW_CONSISTENCY,
	PERFORMANCE_BENCHMARKS
}

## Validation severity levels
enum ValidationSeverity {
	INFO,
	WARNING,
	ERROR,
	CRITICAL
}

## Integration validation result
class IntegrationValidationResult:
	var integration_type: IntegrationValidationType
	var severity: ValidationSeverity
	var backend_system: String = ""
	var ui_component: String = ""
	var performance_data: Dictionary = {}
	var type: int = 0
	var result: int = 0
	var message: String = ""
	var context: Dictionary = {}
	
	func _init(
		p_integration_type: IntegrationValidationType,
		p_severity: ValidationSeverity,
		p_message: String = "",
		p_backend_system: String = "",
		p_ui_component: String = "",
		p_context: Dictionary = {}
	) -> void:
		integration_type = p_integration_type
		severity = p_severity
		message = p_message
		backend_system = p_backend_system
		ui_component = p_ui_component
		context = p_context
		
		# Map severity to result types
		match severity:
			ValidationSeverity.INFO:
				result = 4 # SUCCESS equivalent
			ValidationSeverity.WARNING:
				result = 3 # WARNING equivalent
			ValidationSeverity.ERROR, ValidationSeverity.CRITICAL:
				result = 1 # ERROR equivalent

## Validate complete campaign creation workflow
static func validate_campaign_creation_integration(ui_controller: Node) -> Array[IntegrationValidationResult]:
	var results: Array[IntegrationValidationResult] = []
	
	
	# Check UI controller availability
	if not ui_controller:
		results.append(IntegrationValidationResult.new(
			IntegrationValidationType.CAMPAIGN_CREATION_FLOW,
			ValidationSeverity.CRITICAL,
			"Campaign creation UI controller is null",
			"CampaignCreationUI",
			"N/A"
		))
		return results
	
	# Validate panel availability and backend signal connections
	var panels = ["config_panel", "crew_panel", "captain_panel", "ship_panel", "equipment_panel", "final_panel"]
	for panel_name in panels:
		var panel = ui_controller.get(panel_name)
		if not panel:
			results.append(IntegrationValidationResult.new(
				IntegrationValidationType.CAMPAIGN_CREATION_FLOW,
				ValidationSeverity.ERROR,
				"Panel not found: %s" % panel_name,
				"CampaignCreationUI",
				panel_name
			))
			continue
		
		# Check backend integration signals for crew and equipment panels
		if panel_name == "crew_panel":
			if not panel.has_signal("crew_generation_requested"):
				results.append(IntegrationValidationResult.new(
					IntegrationValidationType.SIGNAL_CONNECTION_INTEGRITY,
					ValidationSeverity.ERROR,
					"Missing backend integration signal: crew_generation_requested",
					"SimpleCharacterCreator",
					"crew_panel"
				))
			else:
				results.append(IntegrationValidationResult.new(
					IntegrationValidationType.SIGNAL_CONNECTION_INTEGRITY,
					ValidationSeverity.INFO,
					"Backend integration signal available: crew_generation_requested",
					"SimpleCharacterCreator",
					"crew_panel"
				))
		
		elif panel_name == "equipment_panel":
			if not panel.has_signal("equipment_requested"):
				results.append(IntegrationValidationResult.new(
					IntegrationValidationType.SIGNAL_CONNECTION_INTEGRITY,
					ValidationSeverity.ERROR,
					"Missing backend integration signal: equipment_requested",
					"StartingEquipmentGenerator",
					"equipment_panel"
				))
			else:
				results.append(IntegrationValidationResult.new(
					IntegrationValidationType.SIGNAL_CONNECTION_INTEGRITY,
					ValidationSeverity.INFO,
					"Backend integration signal available: equipment_requested",
					"StartingEquipmentGenerator",
					"equipment_panel"
				))
	
	# Validate backend system signal handlers in UI controller
	var backend_handlers = [
		"_on_crew_generation_requested",
		"_on_equipment_requested_with_backend",
		"_on_character_customization_needed"
	]
	
	for handler_name in backend_handlers:
		if not ui_controller.has_method(handler_name):
			results.append(IntegrationValidationResult.new(
				IntegrationValidationType.CAMPAIGN_CREATION_FLOW,
				ValidationSeverity.ERROR,
				"Missing backend integration handler: %s" % handler_name,
				"Backend Systems",
				"CampaignCreationUI"
			))
		else:
			results.append(IntegrationValidationResult.new(
				IntegrationValidationType.CAMPAIGN_CREATION_FLOW,
				ValidationSeverity.INFO,
				"Backend integration handler available: %s" % handler_name,
				"Backend Systems",
				"CampaignCreationUI"
			))
	
	return results

## Validate campaign turn system integration
static func validate_turn_system_integration(turn_controller: Node) -> Array[IntegrationValidationResult]:
	var results: Array[IntegrationValidationResult] = []
	
	
	if not turn_controller:
		results.append(IntegrationValidationResult.new(
			IntegrationValidationType.TURN_SYSTEM_INTEGRATION,
			ValidationSeverity.CRITICAL,
			"Campaign turn controller is null",
			"CampaignTurnController",
			"N/A"
		))
		return results
	
	# Validate backend system availability
	var backend_systems = [
		{"name": "BackendPlanetManager", "class": "PlanetDataManager"},
		{"name": "BackendContactManager", "class": "ContactManager"},
		{"name": "BackendRivalGenerator", "class": "RivalBattleGenerator"}
	]
	
	for system in backend_systems:
		var backend_node = turn_controller.get_node_or_null(system.name)
		if not backend_node:
			results.append(IntegrationValidationResult.new(
				IntegrationValidationType.BACKEND_SYSTEM_AVAILABILITY,
				ValidationSeverity.WARNING,
				"Backend system not initialized: %s" % system.name,
				system.class ,
				"CampaignTurnController"
			))
		else:
			results.append(IntegrationValidationResult.new(
				IntegrationValidationType.BACKEND_SYSTEM_AVAILABILITY,
				ValidationSeverity.INFO,
				"Backend system available: %s" % system.name,
				system.class ,
				"CampaignTurnController"
			))
	
	# Validate world phase UI integration
	var world_phase_ui = turn_controller.get("world_phase_ui")
	if world_phase_ui:
		# Check for backend integration methods
		var integration_methods = [
			"update_planet_data_backend",
			"generate_random_contact_backend"
		]
		
		for method_name in integration_methods:
			if not world_phase_ui.has_method(method_name):
				results.append(IntegrationValidationResult.new(
					IntegrationValidationType.TURN_SYSTEM_INTEGRATION,
					ValidationSeverity.WARNING,
					"Missing backend integration method in WorldPhaseUI: %s" % method_name,
					"Backend Systems",
					"WorldPhaseUI"
				))
			else:
				results.append(IntegrationValidationResult.new(
					IntegrationValidationType.TURN_SYSTEM_INTEGRATION,
					ValidationSeverity.INFO,
					"Backend integration method available in WorldPhaseUI: %s" % method_name,
					"Backend Systems",
					"WorldPhaseUI"
				))
	
	# Validate rival encounter integration
	if turn_controller.has_method("_check_rival_encounter_backend"):
		results.append(IntegrationValidationResult.new(
			IntegrationValidationType.TURN_SYSTEM_INTEGRATION,
			ValidationSeverity.INFO,
			"Rival encounter backend integration available",
			"RivalBattleGenerator",
			"CampaignTurnController"
		))
	else:
		results.append(IntegrationValidationResult.new(
			IntegrationValidationType.TURN_SYSTEM_INTEGRATION,
			ValidationSeverity.ERROR,
			"Missing rival encounter backend integration",
			"RivalBattleGenerator",
			"CampaignTurnController"
		))
	
	return results

## Validate backend system availability and health
static func validate_backend_system_health() -> Array[IntegrationValidationResult]:
	var results: Array[IntegrationValidationResult] = []
	
	
	# Check backend system class availability
	var backend_classes = [
		{"path": "res://src/core/character/Generation/SimpleCharacterCreator.gd", "name": "SimpleCharacterCreator"},
		{"path": "res://src/core/character/Equipment/StartingEquipmentGenerator.gd", "name": "StartingEquipmentGenerator"},
		{"path": "res://src/core/world/ContactManager.gd", "name": "ContactManager"},
		{"path": "res://src/core/world/PlanetDataManager.gd", "name": "PlanetDataManager"},
		{"path": "res://src/core/rivals/RivalBattleGenerator.gd", "name": "RivalBattleGenerator"},
		{"path": "res://src/core/patrons/PatronJobGenerator.gd", "name": "PatronJobGenerator"}
	]
	
	for backend_class in backend_classes:
		var resource = load(backend_class.path)
		if not resource:
			results.append(IntegrationValidationResult.new(
				IntegrationValidationType.BACKEND_SYSTEM_AVAILABILITY,
				ValidationSeverity.CRITICAL,
				"Backend class not found: %s at %s" % [backend_class.name, backend_class.path],
				backend_class.name,
				"System"
			))
		else:
			results.append(IntegrationValidationResult.new(
				IntegrationValidationType.BACKEND_SYSTEM_AVAILABILITY,
				ValidationSeverity.INFO,
				"Backend class available: %s" % backend_class.name,
				backend_class.name,
				"System"
			))
	
	return results

## Validate data flow consistency between UI and backend
static func validate_data_flow_consistency(ui_data: Dictionary, backend_data: Dictionary) -> Array[IntegrationValidationResult]:
	var results: Array[IntegrationValidationResult] = []
	
	
	# Validate crew data consistency
	if ui_data.has("crew") and backend_data.has("crew"):
		var ui_crew = ui_data.crew
		var backend_crew = backend_data.crew
		
		if ui_crew.size() != backend_crew.size():
			results.append(IntegrationValidationResult.new(
				IntegrationValidationType.DATA_FLOW_CONSISTENCY,
				ValidationSeverity.ERROR,
				"Crew size mismatch - UI: %d, Backend: %d" % [ui_crew.size(), backend_crew.size()],
				"CharacterGeneration",
				"CrewPanel"
			))
		else:
			results.append(IntegrationValidationResult.new(
				IntegrationValidationType.DATA_FLOW_CONSISTENCY,
				ValidationSeverity.INFO,
				"Crew size consistent - %d members" % ui_crew.size(),
				"CharacterGeneration",
				"CrewPanel"
			))
	
	# Validate equipment data consistency
	if ui_data.has("equipment") and backend_data.has("equipment"):
		var ui_equipment = ui_data.equipment
		var backend_equipment = backend_data.equipment
		
		if ui_equipment.size() != backend_equipment.size():
			results.append(IntegrationValidationResult.new(
				IntegrationValidationType.DATA_FLOW_CONSISTENCY,
				ValidationSeverity.ERROR,
				"Equipment count mismatch - UI: %d, Backend: %d" % [ui_equipment.size(), backend_equipment.size()],
				"StartingEquipmentGenerator",
				"EquipmentPanel"
			))
		else:
			results.append(IntegrationValidationResult.new(
				IntegrationValidationType.DATA_FLOW_CONSISTENCY,
				ValidationSeverity.INFO,
				"Equipment count consistent - %d items" % ui_equipment.size(),
				"StartingEquipmentGenerator",
				"EquipmentPanel"
			))
	
	return results

## Validate performance benchmarks for integration operations
static func validate_integration_performance(performance_data: Dictionary) -> Array[IntegrationValidationResult]:
	var results: Array[IntegrationValidationResult] = []
	
	
	# Performance thresholds (in milliseconds)
	var thresholds = {
		"crew_generation": 100,
		"equipment_generation": 150,
		"contact_generation": 75,
		"rival_encounter_check": 50,
		"planet_data_update": 25
	}
	
	for operation in thresholds.keys():
		if performance_data.has(operation):
			var duration = performance_data[operation]
			var threshold = thresholds[operation]
			
			if duration > threshold:
				results.append(IntegrationValidationResult.new(
					IntegrationValidationType.PERFORMANCE_BENCHMARKS,
					ValidationSeverity.WARNING,
					"Performance threshold exceeded for %s: %dms (threshold: %dms)" % [operation, duration, threshold],
					"Backend System",
					"Performance"
				))
			else:
				results.append(IntegrationValidationResult.new(
					IntegrationValidationType.PERFORMANCE_BENCHMARKS,
					ValidationSeverity.INFO,
					"Performance within threshold for %s: %dms" % [operation, duration],
					"Backend System",
					"Performance"
				))
	
	return results

## Comprehensive integration validation
static func validate_complete_integration(ui_controller: Node, turn_controller: Node) -> Array[IntegrationValidationResult]:
	var all_results: Array[IntegrationValidationResult] = []
	
	
	# Run all validation checks
	all_results.append_array(validate_backend_system_health())
	all_results.append_array(validate_campaign_creation_integration(ui_controller))
	all_results.append_array(validate_turn_system_integration(turn_controller))
	
	# Summary statistics
	var error_count = 0
	var warning_count = 0
	var info_count = 0
	var critical_count = 0
	
	for result in all_results:
		match result.severity:
			ValidationSeverity.CRITICAL:
				critical_count += 1
			ValidationSeverity.ERROR:
				error_count += 1
			ValidationSeverity.WARNING:
				warning_count += 1
			ValidationSeverity.INFO:
				info_count += 1
	
	
	return all_results

## Generate validation report
static func generate_integration_report(results: Array) -> String:
	var report = "# UI-Backend Integration Validation Report\n\n"
	
	# Summary
	var critical_count = 0
	var error_count = 0
	var warning_count = 0
	var info_count = 0
	
	for result in results:
		match result.severity:
			ValidationSeverity.CRITICAL:
				critical_count += 1
			ValidationSeverity.ERROR:
				error_count += 1
			ValidationSeverity.WARNING:
				warning_count += 1
			ValidationSeverity.INFO:
				info_count += 1
	
	report += "## Summary\n"
	report += "- Critical Issues: %d\n" % critical_count
	report += "- Errors: %d\n" % error_count
	report += "- Warnings: %d\n" % warning_count
	report += "- Info: %d\n" % info_count
	report += "\n"
	
	# Detailed results by category
	var categories = {}
	for result in results:
		var category = IntegrationValidationType.keys()[result.integration_type]
		if not categories.has(category):
			categories[category] = []
		categories[category].append(result)
	
	for category in categories.keys():
		report += "## %s\n" % category.replace("_", " ").capitalize()
		for result in categories[category]:
			var severity_text = ValidationSeverity.keys()[result.severity]
			report += "- [%s] %s (%s → %s)\n" % [severity_text, result.message, result.backend_system, result.ui_component]
		report += "\n"
	
	return report