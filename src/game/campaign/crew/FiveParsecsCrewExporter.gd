@tool
extends Node
# REMOVED: class_name FPCM_CrewExporter
# The authoritative version should be referenced via preload. Use explicit preloads instead of global class name.

# Self-reference constant for external scripts
const Self = preload("res://src/game/campaign/crew/FiveParsecsCrewExporter.gd")
# These files need to be created or renamed
# const FPCM_Crew = preload("res://src/game/campaign/crew/FiveParsecsCrew.gd")
# const FPCM_CrewMember = preload("res://src/game/campaign/crew/FiveParsecsCrewMember.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const FiveParsecsGameEnums = preload("res://src/game/campaign/crew/FiveParsecsGameEnums.gd")
const PDFGenerator = preload("res://src/core/utils/PDFGenerator.gd")

# Constants from BaseCrewExporter
const EXPORT_DIR = "user://exports/"

# Signals from BaseCrewExporter
signal export_completed(success: bool, message: String)
signal export_failed(error: String)

# Properties from BaseCrewExporter
var pdf_generator = null

func _init() -> void:
	_initialize_pdf_generator()

func _initialize_pdf_generator() -> void:
	pdf_generator = PDFGenerator.new()
	pdf_generator.set_template("res://assets/templates/five_parsecs_template.tres")

func export_crew_to_pdf(crew, file_name: String = "") -> void:
	if not crew.get_class() == "FPCM_Crew":
		export_failed.emit("Invalid crew type. Expected FPCM_Crew.")
		return
		
	if not pdf_generator:
		_initialize_pdf_generator()
	
	var actual_file_name = file_name
	if actual_file_name.is_empty():
		actual_file_name = "crew_roster_%s.pdf" % Time.get_datetime_string_from_system().replace(":", "-")
	
	# Generate the PDF content
	_generate_crew_roster_content(crew)
	
	# Save the document
	var save_path = EXPORT_DIR + actual_file_name
	var dir = DirAccess.open(EXPORT_DIR.get_base_dir())
	if not dir:
		dir = DirAccess.open("user://")
		dir.make_dir("exports")
	
	var result = pdf_generator.save_to_file(save_path)
	if result == OK:
		export_completed.emit(true, "Crew roster exported to %s" % save_path)
	else:
		export_failed.emit("Failed to save PDF file: %s" % error_string(result))

func export_character_sheet(character, file_name: String = "") -> void:
	if not character.get_class() == "FPCM_CrewMember":
		export_failed.emit("Invalid character type. Expected FPCM_CrewMember.")
		return
	
	if not pdf_generator:
		_initialize_pdf_generator()
	
	var actual_file_name = file_name
	if actual_file_name.is_empty():
		actual_file_name = "character_sheet_%s.pdf" % character.character_name.replace(" ", "_")
	
	# Generate the PDF content
	_generate_character_sheet_content(character)
	
	# Save the document
	var save_path = EXPORT_DIR + actual_file_name
	var dir = DirAccess.open(EXPORT_DIR.get_base_dir())
	if not dir:
		dir = DirAccess.open("user://")
		dir.make_dir("exports")
	
	var result = pdf_generator.save_to_file(save_path)
	if result == OK:
		export_completed.emit(true, "Character sheet exported to %s" % save_path)
	else:
		export_failed.emit("Failed to save PDF file: %s" % error_string(result))

func _generate_crew_roster_content(crew) -> void:
	if not pdf_generator:
		export_failed.emit("PDF generator not initialized")
		return
		
	# Create new document
	pdf_generator.create_document()
	
	# Add header
	pdf_generator.add_title("Five Parsecs From Home - Crew Roster")
	pdf_generator.add_subtitle(crew.name)
	pdf_generator.add_separator()
	
	# Add crew information
	pdf_generator.add_section("Crew Information")
	pdf_generator.add_field("Characteristic", crew.characteristic)
	pdf_generator.add_field("Meeting Story", crew.meeting_story)
	pdf_generator.add_field("Credits", str(crew.credits))
	pdf_generator.add_field("Ship", crew.ship_name)
	pdf_generator.add_field("Reputation", str(crew.reputation))
	pdf_generator.add_field("Current System", crew.current_system)
	pdf_generator.add_separator()
	
	# Add crew members
	pdf_generator.add_section("Crew Members")
	
	for member in crew.members:
		if member.get_class() == "FPCM_CrewMember":
			pdf_generator.add_subsection(member.character_name)
			
			# Add character class
			var class_name_str = "Unknown"
			match member.character_class:
				FiveParsecsGameEnums.CharacterClass.SOLDIER:
					class_name_str = "Soldier"
				FiveParsecsGameEnums.CharacterClass.ROGUE:
					class_name_str = "Rogue"
				FiveParsecsGameEnums.CharacterClass.PSIONICIST:
					class_name_str = "Psionicist"
				FiveParsecsGameEnums.CharacterClass.TECH:
					class_name_str = "Tech"
				FiveParsecsGameEnums.CharacterClass.MEDIC:
					class_name_str = "Medic"
				FiveParsecsGameEnums.CharacterClass.BRUTE:
					class_name_str = "Brute"
				FiveParsecsGameEnums.CharacterClass.GUNSLINGER:
					class_name_str = "Gunslinger"
				FiveParsecsGameEnums.CharacterClass.ACADEMIC:
					class_name_str = "Academic"
				FiveParsecsGameEnums.CharacterClass.PILOT:
					class_name_str = "Pilot"
			
			pdf_generator.add_field("Class", class_name_str)
			
			# Add stats
			pdf_generator.add_field("Reactions", str(member.reactions))
			pdf_generator.add_field("Speed", str(member.speed))
			pdf_generator.add_field("Combat Skill", str(member.combat_skill))
			pdf_generator.add_field("Toughness", str(member.toughness))
			pdf_generator.add_field("Savvy", str(member.savvy))
			pdf_generator.add_field("Luck", str(member.luck))
			
			# Add health and status
			pdf_generator.add_field("Health", str(member.health) + "/" + str(member.max_health))
			
			var status_name = "Unknown"
			match member.status:
				FiveParsecsGameEnums.CharacterStatus.HEALTHY:
					status_name = "Healthy"
				FiveParsecsGameEnums.CharacterStatus.INJURED:
					status_name = "Injured"
				FiveParsecsGameEnums.CharacterStatus.SERIOUSLY_INJURED:
					status_name = "Seriously Injured"
				FiveParsecsGameEnums.CharacterStatus.CRITICALLY_INJURED:
					status_name = "Critically Injured"
				FiveParsecsGameEnums.CharacterStatus.INCAPACITATED:
					status_name = "Incapacitated"
				FiveParsecsGameEnums.CharacterStatus.STUNNED:
					status_name = "Stunned"
				FiveParsecsGameEnums.CharacterStatus.SUPPRESSED:
					status_name = "Suppressed"
			
			pdf_generator.add_field("Status", status_name)
			
			# Add traits
			if member.traits.size() > 0:
				pdf_generator.add_field("Traits", ", ".join(member.traits))
			
			# Add equipment
			if member.inventory and member.inventory.has_method("get_weapons"):
				var weapons = member.inventory.get_weapons()
				if weapons.size() > 0:
					var weapon_names = []
					for weapon in weapons:
						weapon_names.append(weapon.get_display_name())
					pdf_generator.add_field("Weapons", ", ".join(weapon_names))
			
			pdf_generator.add_separator()

func _generate_character_sheet_content(character) -> void:
	if not pdf_generator:
		export_failed.emit("PDF generator not initialized")
		return
		
	# Create new document
	pdf_generator.create_document()
	
	# Add header
	pdf_generator.add_title("Five Parsecs From Home - Character Sheet")
	pdf_generator.add_subtitle(character.character_name)
	pdf_generator.add_separator()
	
	# Add character class
	var class_name_str = "Unknown"
	match character.character_class:
		FiveParsecsGameEnums.CharacterClass.SOLDIER:
			class_name_str = "Soldier"
		FiveParsecsGameEnums.CharacterClass.ROGUE:
			class_name_str = "Rogue"
		FiveParsecsGameEnums.CharacterClass.PSIONICIST:
			class_name_str = "Psionicist"
		FiveParsecsGameEnums.CharacterClass.TECH:
			class_name_str = "Tech"
		FiveParsecsGameEnums.CharacterClass.MEDIC:
			class_name_str = "Medic"
		FiveParsecsGameEnums.CharacterClass.BRUTE:
			class_name_str = "Brute"
		FiveParsecsGameEnums.CharacterClass.GUNSLINGER:
			class_name_str = "Gunslinger"
		FiveParsecsGameEnums.CharacterClass.ACADEMIC:
			class_name_str = "Academic"
		FiveParsecsGameEnums.CharacterClass.PILOT:
			class_name_str = "Pilot"
	
	pdf_generator.add_field("Class", class_name_str)
	
	# Add stats
	pdf_generator.add_section("Stats")
	pdf_generator.add_field("Reactions", str(character.reactions))
	pdf_generator.add_field("Speed", str(character.speed))
	pdf_generator.add_field("Combat Skill", str(character.combat_skill))
	pdf_generator.add_field("Toughness", str(character.toughness))
	pdf_generator.add_field("Savvy", str(character.savvy))
	pdf_generator.add_field("Luck", str(character.luck))
	
	# Add health and status
	pdf_generator.add_field("Health", str(character.health) + "/" + str(character.max_health))
	pdf_generator.add_field("Morale", str(character.morale))
	
	var status_name = "Unknown"
	match character.status:
		FiveParsecsGameEnums.CharacterStatus.HEALTHY:
			status_name = "Healthy"
		FiveParsecsGameEnums.CharacterStatus.INJURED:
			status_name = "Injured"
		FiveParsecsGameEnums.CharacterStatus.SERIOUSLY_INJURED:
			status_name = "Seriously Injured"
		FiveParsecsGameEnums.CharacterStatus.CRITICALLY_INJURED:
			status_name = "Critically Injured"
		FiveParsecsGameEnums.CharacterStatus.INCAPACITATED:
			status_name = "Incapacitated"
		FiveParsecsGameEnums.CharacterStatus.STUNNED:
			status_name = "Stunned"
		FiveParsecsGameEnums.CharacterStatus.SUPPRESSED:
			status_name = "Suppressed"
	
	pdf_generator.add_field("Status", status_name)
	
	# Add experience
	pdf_generator.add_section("Experience")
	pdf_generator.add_field("Level", str(character.level))
	pdf_generator.add_field("Experience", str(character.experience))
	pdf_generator.add_field("Advances Available", str(character.advances_available))
	
	# Add traits
	if character.traits.size() > 0:
		pdf_generator.add_section("Traits")
		for trait_item in character.traits:
			pdf_generator.add_bullet_point(trait_item)
	
	# Add equipment
	pdf_generator.add_section("Equipment")
	
	if character.inventory and character.inventory.has_method("get_weapons"):
		var weapons = character.inventory.get_weapons()
		if weapons.size() > 0:
			pdf_generator.add_subsection("Weapons")
			for weapon in weapons:
				pdf_generator.add_bullet_point(weapon.get_display_name())
	
	if character.inventory and character.inventory.has_method("get_equipment"):
		var equipment = character.inventory.get_equipment()
		if equipment.size() > 0:
			pdf_generator.add_subsection("Other Equipment")
			for item in equipment:
				pdf_generator.add_bullet_point(item.get_display_name())

func _generate_campaign_summary_content(campaign) -> void:
	if not pdf_generator:
		export_failed.emit("PDF generator not initialized")
		return
		
	# Create new document
	pdf_generator.create_document()
	
	# Add header
	pdf_generator.add_title("Five Parsecs From Home - Campaign Summary")
	pdf_generator.add_separator()
	
	# Add campaign information
	pdf_generator.add_section("Campaign Information")
	
	var campaign_type = "Unknown"
	if campaign.has("type"):
		match campaign.type:
			FiveParsecsGameEnums.CampaignType.STANDARD:
				campaign_type = "Standard"
			FiveParsecsGameEnums.CampaignType.FREELANCER:
				campaign_type = "Freelancer"
			FiveParsecsGameEnums.CampaignType.MERCENARY:
				campaign_type = "Mercenary"
			FiveParsecsGameEnums.CampaignType.EXPLORER:
				campaign_type = "Explorer"
			FiveParsecsGameEnums.CampaignType.TRADER:
				campaign_type = "Trader"
			FiveParsecsGameEnums.CampaignType.BOUNTY_HUNTER:
				campaign_type = "Bounty Hunter"
	
	pdf_generator.add_field("Campaign Type", campaign_type)
	
	if campaign.has("progress"):
		pdf_generator.add_field("Progress", str(campaign.progress))
	
	if campaign.has("battles_fought"):
		pdf_generator.add_field("Battles Fought", str(campaign.battles_fought))
	
	if campaign.has("battles_won"):
		pdf_generator.add_field("Battles Won", str(campaign.battles_won))
	
	if campaign.has("battles_lost"):
		pdf_generator.add_field("Battles Lost", str(campaign.battles_lost))
	
	# Add galaxy information
	if campaign.has("galaxy_map"):
		pdf_generator.add_section("Galaxy Information")
		
		var galaxy_map = campaign.galaxy_map
		
		if galaxy_map.has("current_system"):
			pdf_generator.add_field("Current System", galaxy_map.current_system)
		
		if galaxy_map.has("visited_systems") and galaxy_map.visited_systems.size() > 0:
			pdf_generator.add_subsection("Visited Systems")
			for system in galaxy_map.visited_systems:
				pdf_generator.add_bullet_point(system)
	
	# Add game time
	if campaign.has("game_time"):
		pdf_generator.add_section("Game Time")
		
		var game_time = campaign.game_time
		
		if game_time.has("year") and game_time.has("month") and game_time.has("day"):
			pdf_generator.add_field("Date", "%d-%02d-%02d" % [game_time.year, game_time.month, game_time.day])
		
		if game_time.has("total_days"):
			pdf_generator.add_field("Total Days", str(game_time.total_days))
	
	# Add completed missions
	if campaign.has("completed_missions") and campaign.completed_missions.size() > 0:
		pdf_generator.add_section("Completed Missions")
		
		for mission in campaign.completed_missions:
			if mission.has("title"):
				pdf_generator.add_subsection(mission.title)
				
				if mission.has("description"):
					pdf_generator.add_text(mission.description)
				
				if mission.has("reward"):
					pdf_generator.add_field("Reward", str(mission.reward))
				
				if mission.has("location"):
					pdf_generator.add_field("Location", mission.location)
				
				pdf_generator.add_separator()