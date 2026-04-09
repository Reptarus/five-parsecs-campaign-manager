# Campaign Creation Flows

## 5PFH Creation (7 Phases)

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

## Creation Resource Data Flow (Session 30 Refactor)

Resources (bonus credits, patrons, rivals, story points, rumors, equipment rolls) are rolled at character creation time and stored on `Character.creation_bonuses`. The coordinator's `_generate_crew_extras()` aggregates FROM these stored values — it does NOT call `CharacterGeneration.roll_character_tables()` (that function does random D100 rolls ignoring the character's actual background).

**Data flow**: `CharacterCreator._roll_and_store_creation_bonuses()` → `Character.creation_bonuses` → `_character_to_dict()` preserves key → coordinator aggregates → finalization reads from crew_data fallback.

## Strange Character Creation Constraints (Session 34)

CharacterCreator.gd now enforces Strange Character rules (Core Rules pp.19-22) via `_enforce_species_constraints(species_id)`:

- **Forced motivation**: De-converted→Revenge, Unity Agent→Order, Hakshan→Truth, Emo-suppressed→Survival, Traveler→Truth. Dropdown auto-selects and disables.
- **Forced background**: Mutant→Lower Megacity Class, Manipulator→Bureaucrat, Primitive→Primitive World. Dropdown auto-selects and disables.
- **No creation tables**: Assault Bot — all three dropdowns (background/class/motivation) disabled.
- **Hulker class override**: If rolled class is Technician/Scientist/Hacker → forced to Primitive.
- **Creation bonus adjustments** (in `_roll_and_store_creation_bonuses()`): Mysterious Past zeroes story points, Genetic Uplift zeroes credits + adds rival, Minor Alien reduces bonuses by 1 + rolls XP discount stat, Traveler adds +2 story points/rumors, Hopeful Rookie sets luck to 1.

Strange Characters appear in the origin dropdown after a separator ("── Strange Characters ──") with negative item IDs. `_origin_species_ids: Array[String]` maps dropdown index → species_id. `SpeciesDataService.gd` provides all JSON lookups.

## Campaign Crew Size Selection (Session 39)

ExpandedConfigPanel (Step 0: CONFIG) now includes a CREW SIZE card:

- OptionButton with item IDs 4, 5, 6 (default: 6 = Standard)
- Descriptions per size: "Roll 2D6 pick LOWER" / "Roll 1D6" / "Roll 2D6 pick HIGHER"
- Stored in `local_campaign_config["campaign_crew_size"]`
- Wired through coordinator → `CampaignFinalizationService` sets `campaign.campaign_crew_size`
- FinalPanel shows "X Crew Members (Campaign Size: Y)" and uses setting for completion check
- CrewPanelController defaults updated: MIN=4, DEFAULT=6

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

---

## Planetfall Creation (6 Steps, Session 54)

```
MainMenu → PlanetfallCreationUI (code-built shell) → PlanetfallCreationCoordinator
  Step 0: EXPEDITION_TYPE  → PlanetfallExpeditionPanel (D100 roll)
  Step 1: ROSTER           → PlanetfallRosterPanel (class picker, sub-species, imports)
  Step 2: BACKGROUNDS      → PlanetfallBackgroundsPanel (Motivation + Prior Exp + Notable Event)
  Step 3: MAP_GENERATION   → PlanetfallMapPanel (grid size, home sector, 10 investigation sites)
  Step 4: TUTORIAL_MISSIONS → PlanetfallTutorialPanel (3 missions — play or skip)
  Step 5: FINAL_REVIEW     → PlanetfallReviewPanel
```

### Key Differences from 5PFH Creation
- **3 character classes** (Scientist/Scout/Trooper) — min 1 of each, recommended 2/2/4
- **Sub-species** (Feral/Hulker/Stalker/Soulless) — max 1 Feral + 1 other
- **No equipment at creation** — central colony store, weapons assigned per mission
- **Loyalty system** — Committed by default, Loyal from Prior Experience or import
- **Character import** — from 5PFH (Luck→KP, personal equipment) or Bug Hunt (Tech→Savvy, no equipment)
- **Class Training** — imported chars can take D6 aptitude test for class assignment (max 3)
- **Tutorial missions** — 3 optional intro battles (Beacons/Analysis/Perimeter) with starting bonuses

### Core Resource
`PlanetfallCampaignCore.gd` (extends Resource) — follows BugHuntCampaignCore pattern.
Colony stats: morale, integrity, BP/turn, RP/turn, repair_capacity, defenses, raw_materials, story_points, grunts, augmentation_points.
Roster: lightweight dicts (NOT Character.gd Resources).
Serialization: `to_dictionary()` / `from_dictionary()` / `save_to_file()` / `load_from_file()`.

### Files
- `src/ui/screens/planetfall/PlanetfallCreationUI.gd/.tscn`
- `src/ui/screens/planetfall/PlanetfallCreationCoordinator.gd`
- `src/ui/screens/planetfall/PlanetfallScreenBase.gd`
- `src/ui/screens/planetfall/panels/Planetfall{Expedition,Roster,Backgrounds,Map,Tutorial,Review}Panel.gd`
- `src/game/campaign/PlanetfallCampaignCore.gd`
- `data/planetfall/{character_classes,human_subspecies,character_backgrounds,expedition_types}.json`

---

## Rules PDF Reference

Campaign creation rules (difficulty modes, victory conditions, crew sizes, starting equipment) can be verified against source PDFs:
- **Core Rules PDF**: `docs/rules/pdfcoffee_com_muh052042_five_parsecs_from_home_3e_rulebook_2021.pdf`
- **Compendium PDF**: `docs/rules/Five Parsecs From Home-Compendium.pdf`
- **Planetfall PDF**: `docs/Five_Parsecs_From_Home_Modiphius_Entertainment_Planetfall_MUH084V044OEF2026/`
- **Text extractions**: `docs/rules/core_rulebook.txt`, `docs/rules/compendium_source.txt`, `docs/rules/planetfall_source.txt`
- **Python page extraction**: `py -c "import fitz; doc = fitz.open('path'); print(doc[PAGE].get_text())"` (PyMuPDF 1.27.1 via `py` launcher)
