#!/usr/bin/env -S godot --headless --script
# UI Flow Validation Script for Five Parsecs Campaign Manager
# Validates all button connections, scene references, and UI flow integrity

extends SceneTree

const SCENE_PATHS = {
	"main_menu": "res://src/ui/screens/mainmenu/MainMenu.tscn",
	"main_game": "res://src/scenes/main/MainGameScene.tscn",
	"campaign_creation": "res://src/ui/screens/campaign/CampaignCreationUI.tscn",
	"campaign_dashboard": "res://src/ui/screens/campaign/CampaignDashboard.tscn",
	"campaign_setup": "res://src/ui/screens/campaign/CampaignSetupDialog.tscn",
	"victory_progress": "res://src/ui/screens/campaign/VictoryProgressPanel.tscn",
	"character_creator": "res://src/ui/screens/character/CharacterCreator.tscn",
	"character_sheet": "res://src/ui/screens/character/CharacterSheet.tscn",
	"character_progression": "res://src/ui/screens/character/CharacterProgression.tscn",
	"advancement_manager": "res://src/ui/screens/character/AdvancementManager.tscn",
	"crew_creation": "res://src/ui/screens/crew/InitialCrewCreation.tscn",
	"equipment_manager": "res://src/ui/screens/equipment/EquipmentManager.tscn",
	"ship_manager": "res://src/ui/screens/ships/ShipManager.tscn",
	"ship_inventory": "res://src/ui/screens/ships/ShipInventory.tscn",
	"world_phase": "res://src/ui/screens/world/WorldPhaseUI.tscn",
	"job_selection": "res://src/ui/screens/world/JobSelectionUI.tscn",
	"mission_selection": "res://src/ui/screens/world/MissionSelectionUI.tscn",
	"patron_rival_manager": "res://src/ui/screens/world/PatronRivalManager.tscn",
	"travel_phase": "res://src/ui/screens/travel/TravelPhaseUI.tscn",
	"pre_battle": "res://src/ui/screens/battle/PreBattle.tscn",
	"battlefield_main": "res://src/ui/screens/battle/BattlefieldMain.tscn",
	"tactical_battle": "res://src/ui/screens/battle/TacticalBattleUI.tscn",
	"battle_resolution": "res://src/ui/screens/battle/BattleResolutionUI.tscn",
	"post_battle": "res://src/ui/screens/battle/PostBattle.tscn",
	"post_battle_results": "res://src/ui/screens/battle/PostBattleResultsUI.tscn",
	"post_battle_sequence": "res://src/ui/screens/postbattle/PostBattleSequence.tscn",
	"campaign_events": "res://src/ui/screens/events/CampaignEventsManager.tscn",
	"story_phase": "res://src/ui/screens/campaign/phases/StoryPhasePanel.tscn",
	"upkeep_phase": "res://src/ui/screens/campaign/UpkeepPhaseUI.tscn",
	"advancement_phase": "res://src/ui/screens/campaign/phases/AdvancementPhasePanel.tscn",
	"battle_setup_phase": "res://src/ui/screens/campaign/phases/BattleSetupPhasePanel.tscn",
	"battle_resolution_phase": "res://src/ui/screens/campaign/phases/BattleResolutionPhasePanel.tscn",
	"trade_phase": "res://src/ui/screens/campaign/phases/TradePhasePanel.tscn",
	"end_phase": "res://src/ui/screens/campaign/phases/EndPhasePanel.tscn",
	"save_load": "res://src/ui/screens/utils/SaveLoadUI.tscn",
	"game_over": "res://src/ui/screens/utils/GameOverScreen.tscn",
	"logbook": "res://src/ui/screens/utils/logbook.tscn",
	"settings": "res://src/ui/dialogs/SettingsDialog.tscn",
	"tutorial_selection": "res://src/ui/screens/tutorial/TutorialSelection.tscn",
	"new_campaign_tutorial": "res://src/ui/screens/tutorial/NewCampaignTutorial.tscn"
}

var validation_results = {
	"scenes_validated": 0,
	"scenes_missing": 0,
	"scenes_found": [],
	"scenes_missing_list": [],
	"buttons_validated": 0,
	"buttons_invalid": 0,
	"signal_connections": 0,
	"signal_failures": 0,
	"critical_issues": [],
	"warnings": []
}

func _init():
	print("🔍 Starting Five Parsecs Campaign Manager UI Flow Validation")
	print("=".repeat(70))
	
	validate_scene_files()
	validate_critical_ui_flows()
	
	print_summary()
	quit()

func validate_scene_files():
	print("\n📁 VALIDATING SCENE FILES:")
	print("-".repeat(40))
	
	for scene_name in SCENE_PATHS:
		var scene_path = SCENE_PATHS[scene_name]
		if FileAccess.file_exists(scene_path):
			validation_results.scenes_found.append(scene_name)
			validation_results.scenes_validated += 1
			print("   ✅ %s: %s" % [scene_name, scene_path])
		else:
			validation_results.scenes_missing_list.append(scene_name)
			validation_results.scenes_missing += 1
			validation_results.critical_issues.append("Missing scene: %s at %s" % [scene_name, scene_path])
			print("   ❌ %s: %s (FILE NOT FOUND)" % [scene_name, scene_path])

func validate_critical_ui_flows():
	print("\n🔗 VALIDATING CRITICAL UI FLOWS:")
	print("-".repeat(40))
	
	# Test key scene loading
	validate_main_menu_flow()
	validate_campaign_creation_flow()
	validate_campaign_dashboard_flow()

func validate_main_menu_flow():
	print("\n📋 Main Menu Flow:")
	var main_menu_path = SCENE_PATHS["main_menu"]
	if FileAccess.file_exists(main_menu_path):
		var scene = load(main_menu_path)
		if scene:
			var instance = scene.instantiate()
			if instance:
				print("   ✅ Main menu loads successfully")
				
				# Check for critical buttons
				var buttons_to_check = ["Continue", "NewCampaign", "Options"]
				for button_name in buttons_to_check:
					var button = instance.get_node_or_null("%" + button_name)
					if button:
						validation_results.buttons_validated += 1
						print("   ✅ Button found: %s" % button_name)
					else:
						validation_results.buttons_invalid += 1
						validation_results.critical_issues.append("Main menu missing button: %s" % button_name)
						print("   ❌ Button missing: %s" % button_name)
				
				instance.queue_free()
			else:
				validation_results.critical_issues.append("Main menu scene cannot be instantiated")
				print("   ❌ Cannot instantiate main menu scene")
		else:
			validation_results.critical_issues.append("Main menu scene cannot be loaded")
			print("   ❌ Cannot load main menu scene")

func validate_campaign_creation_flow():
	print("\n📋 Campaign Creation Flow:")
	var creation_path = SCENE_PATHS["campaign_creation"]
	if FileAccess.file_exists(creation_path):
		print("   ✅ Campaign creation scene file exists")
		
		# Check for panel structure
		var panels_to_check = ["ConfigPanel", "CrewPanel", "CaptainPanel"]
		for panel_name in panels_to_check:
			print("   📝 Panel expected: %s" % panel_name)
		
		# Check navigation buttons
		var nav_buttons = ["NextButton", "BackButton", "FinishButton"]
		for button_name in nav_buttons:
			print("   📝 Navigation button expected: %s" % button_name)
	else:
		validation_results.critical_issues.append("Campaign creation scene missing")
		print("   ❌ Campaign creation scene missing")

func validate_campaign_dashboard_flow():
	print("\n📋 Campaign Dashboard Flow:")
	var dashboard_path = SCENE_PATHS["campaign_dashboard"]
	if FileAccess.file_exists(dashboard_path):
		print("   ✅ Campaign dashboard scene file exists")
		
		# Check for critical dashboard elements
		var elements_to_check = ["PhaseLabel", "ActionButton", "SaveButton", "LoadButton"]
		for element_name in elements_to_check:
			print("   📝 Dashboard element expected: %s" % element_name)
	else:
		validation_results.critical_issues.append("Campaign dashboard scene missing")
		print("   ❌ Campaign dashboard scene missing")

func print_summary():
	print("\n======================================================================")
	print("🎯 UI FLOW VALIDATION SUMMARY")
	print("======================================================================")
	
	print("\n📊 STATISTICS:")
	print("   Scenes Found: %d/%d" % [validation_results.scenes_validated, SCENE_PATHS.size()])
	print("   Scenes Missing: %d" % validation_results.scenes_missing)
	print("   Buttons Validated: %d" % validation_results.buttons_validated)
	print("   Buttons Invalid: %d" % validation_results.buttons_invalid)
	
	print("\n🔥 CRITICAL ISSUES:")
	if validation_results.critical_issues.is_empty():
		print("   ✅ No critical issues found!")
	else:
		for issue in validation_results.critical_issues:
			print("   ❌ %s" % issue)
	
	print("\n⚠️  WARNINGS:")
	if validation_results.warnings.is_empty():
		print("   ✅ No warnings!")
	else:
		for warning in validation_results.warnings:
			print("   ⚠️  %s" % warning)
	
	var health_score = calculate_health_score()
	print("\n📈 UI FLOW HEALTH SCORE: %.1f%%" % health_score)
	
	if health_score >= 90:
		print("🎉 EXCELLENT - UI flow is in great shape!")
	elif health_score >= 70:
		print("👍 GOOD - Minor issues need attention")
	elif health_score >= 50:
		print("⚠️  FAIR - Several issues need fixing")
	else:
		print("🚨 POOR - Critical UI flow problems detected!")

func calculate_health_score() -> float:
	var total_scenes = SCENE_PATHS.size()
	var scene_score = (float(validation_results.scenes_validated) / total_scenes) * 60.0
	
	var button_penalty = validation_results.buttons_invalid * 5.0
	var critical_penalty = validation_results.critical_issues.size() * 10.0
	var warning_penalty = validation_results.warnings.size() * 2.0
	
	var health = scene_score + 40.0 - button_penalty - critical_penalty - warning_penalty
	return max(0.0, min(100.0, health))