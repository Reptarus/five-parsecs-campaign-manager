class_name CampaignValidator
extends RefCounted

## Simple Campaign Validation Wrapper
## Complements existing SecurityValidator with campaign-specific checks
## Framework Bible compliant: Simple, focused validation

func validate_campaign_data(data: Dictionary) -> Dictionary:
	"""Validate complete campaign data for finalization"""
	var errors = []
	var warnings = []
	
	# Check required sections exist
	var required_sections = ["config", "crew", "captain", "ship", "equipment", "world"]
	for section in required_sections:
		if not data.has(section) or data[section].is_empty():
			errors.append("Missing %s data - please complete the %s phase" % [section, section.capitalize()])
	
	# Validate config section
	if data.has("config") and not data["config"].is_empty():
		var config = data["config"]
		if not config.has("name") or config["name"].is_empty():
			errors.append("Campaign must have a name")
		if not config.has("difficulty"):
			warnings.append("No difficulty selected, using default")

	# Validate crew section
	if data.has("crew") and not data["crew"].is_empty():
		var crew = data["crew"]
		if not crew.has("members") or crew["members"].size() == 0:
			errors.append("Campaign must have at least one crew member")
		elif crew["members"].size() > 8:
			warnings.append("Large crew size may affect game balance")

	# Validate captain section
	if data.has("captain") and not data["captain"].is_empty():
		var captain = data["captain"]
		if not captain.has("name") or captain["name"].is_empty():
			errors.append("Captain must have a name")

	# Validate ship section
	if data.has("ship") and not data["ship"].is_empty():
		var ship = data["ship"]
		if not ship.has("name") or ship["name"].is_empty():
			warnings.append("Ship should have a name")
	
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"warnings": warnings,
		"details": {
			"sections_validated": required_sections.size(),
			"errors_found": errors.size(),
			"warnings_found": warnings.size()
		}
	}

func validate_phase_data(phase: int, data: Dictionary) -> Dictionary:
	"""Validate data for a specific campaign phase"""
	var errors = []
	var warnings = []
	
	match phase:
		0: # CONFIG
			if not data.has("name") or data.name.is_empty():
				errors.append("Campaign name is required")
			if not data.has("difficulty"):
				warnings.append("Difficulty not set")
		
		1: # CREW_SETUP
			if not data.has("members") or data.members.size() == 0:
				errors.append("At least one crew member required")
		
		2: # CAPTAIN_CREATION
			if not data.has("name") or data.name.is_empty():
				errors.append("Captain name is required")
		
		3: # SHIP_ASSIGNMENT
			if data.is_empty():
				warnings.append("Ship configuration incomplete")
		
		4: # EQUIPMENT_GENERATION
			if data.is_empty():
				warnings.append("Equipment not generated")
		
		5: # WORLD_GENERATION
			if data.is_empty():
				warnings.append("World parameters not set")
		
		6: # FINAL_REVIEW
			# Final validation happens in validate_campaign_data
			pass
	
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"warnings": warnings
	}

func get_validation_summary(campaign_data: Dictionary) -> String:
	"""Get human-readable validation summary"""
	var result = validate_campaign_data(campaign_data)
	
	if result.valid:
		return "✅ Campaign validation passed - ready to create!"
	else:
		var summary = "❌ Campaign validation failed:\n"
		for error in result.errors:
			summary += "  • " + error + "\n"
		
		if result.warnings.size() > 0:
			summary += "\n⚠️ Warnings:\n"
			for warning in result.warnings:
				summary += "  • " + warning + "\n"
		
		return summary