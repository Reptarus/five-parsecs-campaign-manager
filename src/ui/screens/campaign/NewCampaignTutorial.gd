extends Control

signal tutorial_started(type: String)
signal tutorial_skipped
signal tutorial_step_completed(step: String)
signal tutorial_next_requested
signal tutorial_back_requested

@onready var title_label := $VBoxContainer/TitleLabel
@onready var content_label := $VBoxContainer/ContentLabel
@onready var next_button := $VBoxContainer/ButtonContainer/NextButton
@onready var back_button := $VBoxContainer/ButtonContainer/BackButton
@onready var skip_button := $VBoxContainer/ButtonContainer/SkipButton

var current_step: String = ""
var tutorial_type: String = "basic"

func _ready() -> void:
	_connect_signals()
	_initialize_ui()

func _connect_signals() -> void:
	if next_button:
		next_button.pressed.connect(_on_next_pressed)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	if skip_button:
		skip_button.pressed.connect(_on_skip_pressed)

func _initialize_ui() -> void:
	if title_label:
		title_label.text = "Welcome to Five Parsecs Campaign Manager"
	if content_label:
		content_label.text = "Choose your tutorial experience:"
	if back_button:
		back_button.hide()
	if next_button:
		next_button.text = "Next"
	if skip_button:
		skip_button.text = "Skip Tutorial"

func start_tutorial(type: String = "basic") -> void:
	tutorial_type = type
	tutorial_started.emit(type)
	
	match type:
		"basic":
			current_step = "welcome"
			_show_welcome_step()
		"story":
			current_step = "story_introduction"
			_show_story_introduction()
		"compendium":
			current_step = "compendium_overview"
			_show_compendium_overview()

func _show_welcome_step() -> void:
	if title_label:
		title_label.text = "Welcome to Five Parsecs"
	if content_label:
		content_label.text = """Welcome to Five Parsecs Campaign Manager!

This tutorial will guide you through:
	pass
1. Creating your crew
2. Setting up your campaign
3. Basic combat mechanics
4. Campaign turn structure

Press Next to continue."""
	if back_button:
		back_button.hide()
	if next_button:
		next_button.show()
	if skip_button:
		skip_button.show()

func _show_crew_creation_step() -> void:
	if title_label:
		title_label.text = "Crew Creation"
	if content_label:
		content_label.text = """Your crew is the heart of your campaign:
			pass
- Choose crew size (4-6 members)
- Select backgrounds and skills
- Equip starting gear
- Set crew name and details

Let's create your first crew member."""
	if back_button:
		back_button.show()
	if next_button:
		next_button.show()
	if skip_button:
		skip_button.show()

func _show_campaign_setup_step() -> void:
	if title_label:
		title_label.text = "Campaign Setup"
	if content_label:
		content_label.text = """Important campaign settings:
			pass
- Difficulty level affects rewards and challenges
- Victory conditions determine campaign goals
- Story tracks add narrative elements
- Starting resources impact early game

Configure these settings carefully."""
	if back_button:
		back_button.show()
	if next_button:
		next_button.show()
	if skip_button:
		skip_button.show()

func _show_basic_combat_step() -> void:
	if title_label:
		title_label.text = "Basic Combat"
	if content_label:
		content_label.text = """Combat follows these steps:
			pass
1. Setup battlefield
2. Deploy forces
3. Initiative and activation
4. Combat resolution
5. Post-battle sequence

We'll do a practice battle next."""
	if back_button:
		back_button.show()
	if next_button:
		next_button.show()
	if skip_button:
		skip_button.show()

func _show_campaign_turn_step() -> void:
	if title_label:
		title_label.text = "Campaign Turn Structure"
	if content_label:
		content_label.text = """Each turn consists of:
			pass
1. Travel Phase
2. World Phase
3. Battle Phase
4. Post-Battle Phase

Let's start your first turn!"""
	if back_button:
		back_button.show()
	if next_button:
		next_button.text = "Start Campaign"
	if skip_button:
		skip_button.hide()

func _show_story_introduction() -> void:
	if title_label:
		title_label.text = "Story Tracks"
	if content_label:
		content_label.text = """Story tracks add narrative depth:
			pass
- Choose from multiple story paths
- Complete story-specific missions
- Earn unique rewards
- Shape your crew's destiny

Learn about story mechanics."""
	if back_button:
		back_button.hide()
	if next_button:
		next_button.show()
	if skip_button:
		skip_button.show()

func _show_compendium_overview() -> void:
	if title_label:
		title_label.text = "Game Compendium"
	if content_label:
		content_label.text = """The compendium contains:
			pass
- Core game rules
- Random tables
- Equipment lists
- NPC generation
- World creation tools

Explore the available resources."""
	if back_button:
		back_button.hide()
	if next_button:
		next_button.show()
	if skip_button:
		skip_button.show()

func advance_tutorial() -> void:
	match tutorial_type:
		"basic":
			_advance_basic_tutorial()
		"story":
			_advance_story_tutorial()
		"compendium":
			_advance_compendium_tutorial()

func _advance_basic_tutorial() -> void:
	match current_step:
		"welcome":
			current_step = "crew_creation"
			_show_crew_creation_step()
		"crew_creation":
			current_step = "campaign_setup"
			_show_campaign_setup_step()
		"campaign_setup":
			current_step = "basic_combat"
			_show_basic_combat_step()
		"basic_combat":
			current_step = "campaign_turn"
			_show_campaign_turn_step()
		"campaign_turn":
			complete_tutorial()

func _advance_story_tutorial() -> void:
	match current_step:
		"story_introduction":
			complete_tutorial()

func _advance_compendium_tutorial() -> void:
	match current_step:
		"compendium_overview":
			complete_tutorial()

func back_tutorial() -> void:
	match tutorial_type:
		"basic":
			_back_basic_tutorial()
		"story", "compendium":
			tutorial_back_requested.emit()

func _back_basic_tutorial() -> void:
	match current_step:
		"crew_creation":
			current_step = "welcome"
			_show_welcome_step()
		"campaign_setup":
			current_step = "crew_creation"
			_show_crew_creation_step()
		"basic_combat":
			current_step = "campaign_setup"
			_show_campaign_setup_step()
		"campaign_turn":
			current_step = "basic_combat"
			_show_basic_combat_step()

func complete_tutorial() -> void:
	tutorial_step_completed.emit(current_step)
	_navigate_to_campaign_creation()

func _on_next_pressed() -> void:
	tutorial_next_requested.emit()
	advance_tutorial()

func _on_back_pressed() -> void:
	tutorial_back_requested.emit()
	back_tutorial()

func _on_skip_pressed() -> void:
	tutorial_skipped.emit()
	_navigate_to_campaign_creation()

func _navigate_to_campaign_creation() -> void:
	var gsm = get_node_or_null("/root/GameStateManager")
	if gsm and gsm.has_method("start_new_campaign"):
		gsm.start_new_campaign()
	var router = get_node_or_null("/root/SceneRouter")
	if router:
		router.navigate_to("campaign_creation")
	else:
		push_error("NewCampaignTutorial: SceneRouter not found")
