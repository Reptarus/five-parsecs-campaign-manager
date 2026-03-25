# Campaign Creation Flow (7 Phases)

## Architecture

```
MainMenu → CampaignCreationUI (thin shell) → CampaignCreationCoordinator → CampaignCreationStateManager
  Step 0: CONFIG         → ExpandedConfigPanel
  Step 1: CAPTAIN_CREATION → CaptainPanel + CharacterCreator
  Step 2: CREW_SETUP     → CrewPanel
  Step 3: EQUIPMENT_GENERATION → EquipmentPanel
  Step 4: SHIP_ASSIGNMENT → ShipPanel
  Step 5: WORLD_GENERATION → WorldInfoPanel
  Step 6: FINAL_REVIEW   → FinalPanel
```

## CampaignCreationCoordinator

**Path**: `src/ui/screens/campaign/CampaignCreationCoordinator.gd`
**class_name**: CampaignCreationCoordinator

### Signals
```
navigation_updated(can_go_back: bool, can_go_forward: bool, can_finish: bool)
phase_transition_requested(from_phase: Phase, to_phase: Phase)
step_changed(step: int, total_steps: int)
equipment_state_updated(equipment_data: Dictionary)
ship_state_updated(ship_data: Dictionary)
crew_state_updated(crew_data: Dictionary)
campaign_data_updated(campaign_data: Dictionary)
campaign_state_updated(state_data: Dictionary)
```

### Key Methods
```
advance_to_next_phase() → void
go_back_to_previous_phase() → void
jump_to_phase(phase: Phase) → void
get_current_phase_name() → String
update_campaign_config_state(config: Dictionary) → void
update_captain_state(captain_data: Dictionary) → void
update_crew_state(crew_data: Dictionary) → void
update_equipment_state(equipment_data: Dictionary) → void
update_ship_state(ship_data: Dictionary) → void
update_world_state(world_data: Dictionary) → void
provide_initial_state_to_panel(panel: Control) → void
get_campaign_data() → Dictionary
validate_current_phase() → Dictionary    # {valid: bool, errors: Array}
```

## CampaignCreationUI (Thin Shell)

**Path**: `src/ui/screens/campaign/CampaignCreationUI.gd`
~161 lines. Wires panels to coordinator, nothing more.

### Panel Signal Adapters
Control-based panels emit typed signals. CampaignCreationUI uses lambda adapters to convert to Dict format:
```gdscript
# Example: CaptainPanel → Coordinator
panel.captain_updated.connect(func(captain):
    coordinator.update_captain_state({"captain": captain}))
```

### Navigation Wiring
```gdscript
coordinator.navigation_updated.connect(_on_navigation_updated)
coordinator.step_changed.connect(_on_step_changed)
next_button.pressed.connect(func(): coordinator.advance_to_next_phase())
back_button.pressed.connect(_on_back_pressed)
finish_button.pressed.connect(func(): final_panel._on_create_campaign_pressed())
```

### Finalization Flow
```
FinalPanel._on_create_campaign_pressed()
  → CampaignCreationUI._on_campaign_finalized(data)
    → GameState.new_campaign(data)
    → GameState.save_campaign()
    → SceneRouter to CampaignTurnController
```

## Validation Per Phase

Each phase has validation rules checked by `coordinator.validate_current_phase()`:

| Phase | Required |
|-------|----------|
| CONFIG | Difficulty selected, victory type chosen |
| CAPTAIN_CREATION | Character created with name and valid stats |
| CREW_SETUP | 3-5 crew members generated |
| EQUIPMENT_GENERATION | Equipment assigned to crew |
| SHIP_ASSIGNMENT | Ship selected or generated |
| WORLD_GENERATION | Planet/homeworld set |
| FINAL_REVIEW | All prior phases valid |

Navigation buttons are enabled/disabled based on `navigation_updated` signal.

## Rules PDF Reference

Campaign creation rules (difficulty modes, victory conditions, crew sizes, starting equipment) can be verified against source PDFs:
- **Core Rules PDF**: `docs/rules/pdfcoffee_com_muh052042_five_parsecs_from_home_3e_rulebook_2021.pdf`
- **Compendium PDF**: `docs/rules/Five Parsecs From Home-Compendium.pdf`
- **Text extractions**: `docs/rules/core_rulebook.txt` and `docs/rules/compendium_source.txt`
- **Python page extraction**: `py -c "import fitz; doc = fitz.open('path'); print(doc[PAGE].get_text())"` (PyMuPDF 1.27.1 via `py` launcher)
