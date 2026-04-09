class_name PlanetfallEndGamePanel
extends Control

## Full-screen panel for End Game sequence: Summit, Colony Security,
## Final Milestone construction, and path resolution.
## Shown when campaign.game_phase == "endgame".
## Source: Planetfall pp.160-164

signal phase_completed(result_data: Dictionary)

const PlanetfallEndGameScript := preload(
	"res://src/core/systems/PlanetfallEndGameSystem.gd")

const COLOR_TEXT_PRIMARY := Color("#E0E0E0")
const COLOR_TEXT_SECONDARY := Color("#808080")
const COLOR_ELEVATED := Color("#252542")
const COLOR_BORDER := Color("#3A3A5C")
const COLOR_ACCENT := Color("#2D5A7B")
const COLOR_SUCCESS := Color("#10B981")
const COLOR_WARNING := Color("#D97706")
const COLOR_DANGER := Color("#DC2626")
const COLOR_BASE := Color("#1A1A2E")
const FONT_SIZE_XL := 24
const FONT_SIZE_LG := 18
const FONT_SIZE_MD := 16
const FONT_SIZE_SM := 14
const FONT_SIZE_XS := 11
const SPACING_SM := 8
const SPACING_MD := 16
const SPACING_LG := 24

enum Stage { SUMMIT, PATH_SELECTION, SECURITY_CHECK, FINAL_CONSTRUCTION, RESOLUTION, COMPLETE }

var _campaign: Resource
var _endgame: PlanetfallEndGameScript
var _current_stage: int = Stage.SUMMIT
var _summit_results: Dictionary = {}
var _selected_path: String = ""
var _content: VBoxContainer
var _action_btn: Button


func _ready() -> void:
	_endgame = PlanetfallEndGameScript.new()
	_build_ui()


func set_campaign(campaign_resource: Resource) -> void:
	_campaign = campaign_resource


func refresh() -> void:
	_current_stage = Stage.SUMMIT
	_summit_results = {}
	_selected_path = ""
	_refresh_content()


## ============================================================================
## UI BUILD
## ============================================================================

func _build_ui() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bg.color = COLOR_BASE
	add_child(bg)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", SPACING_LG)
	scroll.add_child(vbox)

	var title := Label.new()
	title.text = "THE END GAME"
	title.add_theme_font_size_override("font_size", FONT_SIZE_XL)
	title.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", SPACING_MD)
	vbox.add_child(_content)

	_action_btn = Button.new()
	_action_btn.text = "Hold Summit"
	_action_btn.custom_minimum_size = Vector2(240, 48)
	_action_btn.pressed.connect(_on_action)
	vbox.add_child(_action_btn)
	_action_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER


func _refresh_content() -> void:
	for child in _content.get_children():
		child.queue_free()

	match _current_stage:
		Stage.SUMMIT:
			_build_summit_intro()
			_action_btn.text = "Hold Summit"
			_action_btn.disabled = false
			_action_btn.visible = true

		Stage.PATH_SELECTION:
			_build_path_selection()
			_action_btn.visible = false

		Stage.SECURITY_CHECK:
			_build_security_check()
			_action_btn.text = "Confirm Security"
			_action_btn.disabled = false
			_action_btn.visible = true

		Stage.FINAL_CONSTRUCTION:
			_build_final_construction()
			_action_btn.text = "Begin Construction"
			_action_btn.visible = true

		Stage.RESOLUTION:
			_build_resolution()
			_action_btn.text = "Resolve Fate"
			_action_btn.disabled = false
			_action_btn.visible = true

		Stage.COMPLETE:
			_build_completion()
			_action_btn.text = "Return to Main Menu"
			_action_btn.disabled = false
			_action_btn.visible = true


## ============================================================================
## STAGE CONTENT
## ============================================================================

func _build_summit_intro() -> void:
	_add_text("THE SUMMIT", FONT_SIZE_LG, COLOR_ACCENT)
	_add_text(
		"Everyone knows that a moment of decision has been reached. " +
		"You summon your most trusted companions and advisors to " +
		"discuss the fate of the colony.", FONT_SIZE_SM, COLOR_TEXT_SECONDARY)
	_add_text(
		"Each character on your roster voices an opinion. " +
		"Roll D6 per character (not bots/grunts) plus 1 for the general population.",
		FONT_SIZE_SM, COLOR_TEXT_PRIMARY)


func _build_path_selection() -> void:
	_add_text("SUMMIT RESULTS", FONT_SIZE_LG, COLOR_ACCENT)

	# Show individual votes
	for vote in _summit_results.get("individual_votes", []):
		if vote is not Dictionary:
			continue
		_add_text("  %s rolled %d → %s" % [
			vote.get("character", "?"),
			vote.get("roll", 0),
			vote.get("vote_name", "?")],
			FONT_SIZE_SM, COLOR_TEXT_PRIMARY)

	_add_text("", FONT_SIZE_SM, COLOR_TEXT_PRIMARY)
	_add_text("SELECT YOUR PATH:", FONT_SIZE_MD, COLOR_TEXT_PRIMARY)

	# Path cards
	var available: Array = _summit_results.get("available_paths", [])
	for path_id in available:
		var path_data: Dictionary = _endgame.get_path_data(path_id)
		var cost: Dictionary = _endgame.get_final_milestone_cost(path_id)
		var secure: bool = _endgame.check_colony_security(_campaign, path_id)

		var btn := Button.new()
		btn.text = "%s (Cost: %d BP, %d RP)%s" % [
			path_data.get("name", path_id.capitalize()),
			cost.get("bp", 0), cost.get("rp", 0),
			"" if secure else " [SECURITY NOT MET]"]
		btn.custom_minimum_size = Vector2(0, 48)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_path_selected.bind(path_id))
		_content.add_child(btn)

		var desc := Label.new()
		desc.text = path_data.get("description", "")
		desc.add_theme_font_size_override("font_size", FONT_SIZE_XS)
		desc.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_content.add_child(desc)


func _build_security_check() -> void:
	var req: int = _endgame.get_security_requirement(_selected_path)
	var met: bool = _endgame.check_colony_security(_campaign, _selected_path)

	_add_text("COLONY SECURITY", FONT_SIZE_LG, COLOR_ACCENT)
	_add_text("Path: %s" % _selected_path.capitalize(), FONT_SIZE_MD, COLOR_TEXT_PRIMARY)
	_add_text("Strongpoints destroyed required: %d" % req, FONT_SIZE_SM, COLOR_TEXT_PRIMARY)

	if met:
		_add_text("Colony security requirement: MET", FONT_SIZE_MD, COLOR_SUCCESS)
	else:
		_add_text("Colony security requirement: NOT MET", FONT_SIZE_MD, COLOR_DANGER)
		_add_text(
			"You must defeat enough Tactical Enemy Strongpoints before proceeding.",
			FONT_SIZE_SM, COLOR_TEXT_SECONDARY)
		_action_btn.disabled = true


func _build_final_construction() -> void:
	var cost: Dictionary = _endgame.get_final_milestone_cost(_selected_path)
	var can_afford: bool = _endgame.can_afford_final_milestone(
		_campaign, _selected_path, "")

	_add_text("FINAL MILESTONE CONSTRUCTION", FONT_SIZE_LG, COLOR_ACCENT)
	_add_text("Path: %s" % _selected_path.capitalize(), FONT_SIZE_MD, COLOR_TEXT_PRIMARY)
	_add_text("Cost: %d Build Points, %d Research Points" % [
		cost.get("bp", 0), cost.get("rp", 0)], FONT_SIZE_SM, COLOR_TEXT_PRIMARY)

	if can_afford:
		_add_text("Resources available — ready to construct.", FONT_SIZE_SM, COLOR_SUCCESS)
		_action_btn.disabled = false
	else:
		_add_text("Insufficient resources. Earn more BP/RP to construct.", FONT_SIZE_SM, COLOR_DANGER)
		_action_btn.disabled = true


func _build_resolution() -> void:
	_add_text("RESOLUTION", FONT_SIZE_LG, COLOR_ACCENT)
	_add_text("Path: %s" % _selected_path.capitalize(), FONT_SIZE_MD, COLOR_TEXT_PRIMARY)
	_add_text(
		"Press the button to determine the fate of your colony...",
		FONT_SIZE_SM, COLOR_TEXT_SECONDARY)


func _build_completion() -> void:
	_add_text("CAMPAIGN COMPLETE", FONT_SIZE_XL, COLOR_SUCCESS)
	_add_text("The story of your colony has reached its conclusion.", FONT_SIZE_MD, COLOR_TEXT_PRIMARY)

	if _campaign and "endgame_path" in _campaign:
		_add_text("Path chosen: %s" % _campaign.endgame_path.capitalize(),
			FONT_SIZE_MD, COLOR_ACCENT)


## ============================================================================
## ACTION HANDLER
## ============================================================================

func _on_action() -> void:
	match _current_stage:
		Stage.SUMMIT:
			_summit_results = _endgame.run_summit(_campaign)
			_current_stage = Stage.PATH_SELECTION
			_refresh_content()

		Stage.SECURITY_CHECK:
			_current_stage = Stage.FINAL_CONSTRUCTION
			_refresh_content()

		Stage.FINAL_CONSTRUCTION:
			# Deduct cost
			var cost: Dictionary = _endgame.get_final_milestone_cost(_selected_path)
			if _campaign and "buildings_data" in _campaign:
				_campaign.buildings_data["current_bp"] = _campaign.buildings_data.get("current_bp", 0) - cost.get("bp", 0)
			if _campaign and "research_data" in _campaign:
				_campaign.research_data["current_rp"] = _campaign.research_data.get("current_rp", 0) - cost.get("rp", 0)
			_current_stage = Stage.RESOLUTION
			_refresh_content()

		Stage.RESOLUTION:
			var result: Dictionary = _endgame.resolve_path(_campaign, _selected_path, {})
			_current_stage = Stage.COMPLETE
			_refresh_content()

			# Show resolution results
			_add_text("", FONT_SIZE_SM, COLOR_TEXT_PRIMARY)
			_add_text("FATE:", FONT_SIZE_MD, COLOR_WARNING)
			var outcome: String = result.get("outcome", "")
			if not outcome.is_empty():
				_add_text(outcome, FONT_SIZE_SM, COLOR_TEXT_PRIMARY)
			for char_result in result.get("character_results", []):
				if char_result is Dictionary:
					_add_text("  %s: %s (rolled %d)" % [
						char_result.get("character", "?"),
						char_result.get("outcome", "?"),
						char_result.get("roll", 0)],
						FONT_SIZE_SM, COLOR_TEXT_PRIMARY)
			for nomad_result in result.get("nomad_results", []):
				if nomad_result is Dictionary:
					_add_text("  Round %d: %s (rolled %d)" % [
						nomad_result.get("round", 0),
						nomad_result.get("outcome", "?"),
						nomad_result.get("roll", 0)],
						FONT_SIZE_SM, COLOR_TEXT_PRIMARY)

		Stage.COMPLETE:
			phase_completed.emit({"endgame_completed": true, "path": _selected_path})


func _on_path_selected(path_id: String) -> void:
	_selected_path = path_id
	if _campaign and "endgame_path" in _campaign:
		_campaign.endgame_path = path_id
	_current_stage = Stage.SECURITY_CHECK
	_refresh_content()


## ============================================================================
## HELPERS
## ============================================================================

func _add_text(text: String, size: int, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(lbl)
