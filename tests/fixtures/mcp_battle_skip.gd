## MCP Battle Skip Script
## Fast-forwards from MainMenu to TacticalBattleUI with proper mission data.
##
## Usage:
##   1. Run project via MCP: mcp__godot__run_project
##   2. Click "NewCampaign" via simulate_input
##   3. Wait 2s, then run this script via mcp__godot__run_script (timeout=60000)
##
## Prerequisites:
##   - Project running, current scene = CampaignCreationUI
##   - MCP bridge patched with `await` on execute() (see below)
##
## MCP Bridge Patch (required for async):
##   File: <npm_root>/godot-mcp-runtime/dist/scripts/mcp_bridge.gd
##   Line ~396: Change `result = instance.execute(get_tree())`
##           to `result = await instance.execute(get_tree())`
##
## Configurable Parameters:
##   - CAMPAIGN_NAME: Name for the test campaign
##   - MISSION_DATA: Dict injected as progress_data["current_mission"]
##     Change "type", "enemy_type", "enemy_category" to test different scenarios
##   - COMPANION_LEVEL: "Full Oracle", "Assisted", "Log Only", or "Skip"
##   - STARTING_CREDITS: Credits given to campaign (must cover 7cr upkeep)
##
## Output Dict Keys:
##   phase1: "campaign created" or error
##   phase2: "phase=N" where N should be 5 (MISSION)
##   deployed: true if Confirm Deployment clicked
##   oracle: true if companion level selected
##   final_scene: should be "CampaignTurnController"
extends RefCounted

const CAMPAIGN_NAME := "QA Battle Test"
const STARTING_CREDITS := 50
const COMPANION_LEVEL := "Full Oracle"

## Mission data injected into progress_data["current_mission"].
## EnemyGenerator reads "enemy_type" and "enemy_category" to generate forces.
## CampaignTurnController reads "type"/"objective" for terrain + objectives.
## Change these to test different mission types:
##   PATROL  → 3 objective markers on large features
##   ACCESS  → 1 center objective marker
##   FIGHT_OFF → no objective markers
##   MOVE_THROUGH → no objective markers
##   DELIVER → 1 center objective marker
##   SECURE  → 1 center objective marker
static func get_mission_data() -> Dictionary:
	return {
		"type": "PATROL",
		"objective": "Patrol",
		"title": "Sector Patrol: Outskirts",
		"description": "Patrol the area and engage any hostiles.",
		"battle_type": 0,  # GlobalEnums.BattleType.STANDARD
		"mission_source": "opportunity",
		"location": "Industrial Outskirts",
		"enemy_category": "criminal_elements",
		"enemy_type": "Gangers",
		"enemy_count": 5,
		"benefits": [],
		"hazards": [],
		"conditions": [],
	}


func execute(scene_tree: SceneTree) -> Variant:
	var result := {}

	# ── Phase 1: Campaign Creation ───────────────────────────────────
	var creation_ui = scene_tree.current_scene
	if creation_ui.name != "CampaignCreationUI":
		return {"error": "Expected CampaignCreationUI, got: "
			+ creation_ui.name}

	var coordinator = creation_ui.coordinator

	# Step 0: Config — set campaign name
	var line_edits: Array = []
	_find_by_class(creation_ui, "LineEdit", line_edits)
	for le in line_edits:
		if "campaign name" in le.placeholder_text.to_lower():
			le.text = CAMPAIGN_NAME
			le.text_changed.emit(CAMPAIGN_NAME)
			break

	# Step 1: Captain — randomize
	coordinator.next_panel()
	await scene_tree.create_timer(0.3).timeout
	_click_button(creation_ui, "Random Captain")
	await scene_tree.create_timer(0.5).timeout

	# Step 2: Crew — randomize all
	coordinator.next_panel()
	await scene_tree.create_timer(0.3).timeout
	_click_button_visible(creation_ui, "Randomize All")
	await scene_tree.create_timer(0.5).timeout

	# Steps 3-6: Equipment -> Ship -> World -> Review
	for i in range(4):
		coordinator.next_panel()
		await scene_tree.create_timer(0.3).timeout

	# Finalize campaign
	_click_button_by_name(creation_ui, "FinishButton")
	await scene_tree.create_timer(2.5).timeout
	result["phase1"] = "campaign created"

	# ── Phase 2: Inject Mission Data + Skip to Mission ───────────────
	var scene = scene_tree.current_scene
	if scene.name != "CampaignTurnController":
		return {"error": "Expected CampaignTurnController, got: "
			+ scene.name, "phase1": result.get("phase1", "")}

	var game_state = scene_tree.root.get_node_or_null(
		"/root/GameState")
	var campaign = game_state.current_campaign

	# Give credits so upkeep doesn't block
	campaign.progress_data["credits"] = STARTING_CREDITS
	campaign.credits = STARTING_CREDITS

	# Inject mission data
	campaign.progress_data["current_mission"] = get_mission_data()

	# Mark all world phase steps complete
	var wpc = scene.world_phase_controller
	for j in range(6):
		wpc.step_completed[j] = true

	# Advance: World Step -> Story -> Travel -> Upkeep -> Mission
	var cpm = scene.campaign_phase_manager
	for k in range(4):
		cpm.complete_current_phase()
		await scene_tree.create_timer(0.3).timeout
	result["phase2"] = "phase=" + str(cpm.get_current_phase())

	# ── Phase 3: Confirm Deployment ──────────────────────────────────
	# Wait for PreBattleUI to fully render
	await scene_tree.create_timer(1.0).timeout
	if _click_button_visible(scene, "Confirm Deployment"):
		result["deployed"] = true
	await scene_tree.create_timer(3.0).timeout

	# ── Phase 4: Select Companion Level ──────────────────────────────
	if COMPANION_LEVEL == "Skip":
		if _click_button_visible(scene, "Skip"):
			result["oracle"] = "skipped"
	else:
		if _click_button_containing(scene, COMPANION_LEVEL):
			result["oracle"] = COMPANION_LEVEL
	await scene_tree.create_timer(2.0).timeout

	result["final_scene"] = scene_tree.current_scene.name
	return result


# ── Helpers ──────────────────────────────────────────────────────────

func _find_by_class(
		node: Node, cls: String, results: Array) -> void:
	if node.is_class(cls):
		results.append(node)
	for child in node.get_children():
		_find_by_class(child, cls, results)

func _click_button(root: Node, text: String) -> bool:
	var buttons: Array = []
	_find_by_class(root, "Button", buttons)
	for btn in buttons:
		if btn.text == text:
			btn.pressed.emit()
			return true
	return false

func _click_button_visible(root: Node, text: String) -> bool:
	var buttons: Array = []
	_find_by_class(root, "Button", buttons)
	for btn in buttons:
		if btn.text == text and btn.is_visible_in_tree():
			btn.pressed.emit()
			return true
	return false

func _click_button_by_name(root: Node, btn_name: String) -> bool:
	var buttons: Array = []
	_find_by_class(root, "Button", buttons)
	for btn in buttons:
		if btn.name == btn_name and btn.is_visible_in_tree():
			btn.pressed.emit()
			return true
	return false

func _click_button_containing(
		root: Node, partial_text: String) -> bool:
	var buttons: Array = []
	_find_by_class(root, "Button", buttons)
	for btn in buttons:
		if partial_text in btn.text and btn.is_visible_in_tree():
			btn.pressed.emit()
			return true
	return false
