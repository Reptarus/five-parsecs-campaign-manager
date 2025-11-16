# Five Parsecs Campaign Manager - Expansion Add-on Architecture Plan

**Document Version:** 1.0
**Base Branch:** `feature/campaign-creation-final`
**Created:** 2025-11-16
**Purpose:** Plan for restructuring expansion content as modular DLC add-ons to core rules

---

## Executive Summary

This document outlines the architecture and implementation plan for converting the Five Parsecs Campaign Manager's expansion content into modular, purchasable add-ons. The goal is to maintain a clean separation between:

- **Core Game** (Five Parsecs From Home base rules)
- **Expansion DLCs** (Trailblazer's Toolkit, Freelancer's Handbook, Fixer's Guidebook, Bug Hunt)

Each expansion will be:
1. **Independently purchasable** via DLCManager
2. **Modular** - can be enabled/disabled without breaking core game
3. **Composable** - expansions work together when multiple are owned
4. **Data-driven** - content loaded dynamically based on ownership

---

## Table of Contents

1. [Current State Analysis](#current-state-analysis)
2. [Expansion Content Breakdown](#expansion-content-breakdown)
3. [Proposed Architecture](#proposed-architecture)
4. [DLC Gating Strategy](#dlc-gating-strategy)
5. [Implementation Roadmap](#implementation-roadmap)
6. [Data File Reorganization](#data-file-reorganization)
7. [Code Refactoring Plan](#code-refactoring-plan)
8. [Testing Strategy](#testing-strategy)

---

## 1. Current State Analysis

### Core Game (Always Available)

Based on the official Five Parsecs from Home rulebook, the core game includes:

**Campaign Turn Structure (4 Phases):**

1. **TRAVEL PHASE**
   - Flee Invasion (if applicable)
   - Decide whether to travel
   - Starship travel event (if traveling)
   - New world arrival steps

2. **WORLD PHASE** (6 Steps)
   1. Upkeep and Ship Repairs
   2. Assign and Resolve Crew Tasks (8 tasks available):
      - **Find a Patron** (seek job offers)
      - **Train** (earn +1 XP)
      - **Trade** (roll on Trade Table)
      - **Recruit** (hire new crew members)
      - **Explore** (roll on Exploration Table)
      - **Track** (hunt down Rivals)
      - **Repair Your Kit** (fix damaged equipment)
      - **Decoy** (avoid being tracked by Rivals)
   3. Determine Job Offers (Patron jobs)
   4. Assign Equipment
   5. Resolve any Rumors (Quest progression)
   6. Choose Your Battle

3. **BATTLE PHASE** (4 Steps)
   1. Determine Deployment Conditions
   2. Determine the Objective
   3. Determine the Enemy
   4. Set up the Battlefield
   - Fight the Battle (tactical combat)

4. **POST-BATTLE PHASE** (14 Steps)
   1. Resolve Rival Status
   2. Resolve Patron Status
   3. Determine Quest Progress
   4. Get Paid (1D6 credits base)
   5. Battlefield Finds (D100 table)
   6. Check for Invasion!
   7. Gather the Loot (Loot Table)
   8. Determine Injuries and Recovery
   9. Experience and Character Upgrades
   10. Invest in Advanced Training
   11. Purchase Items
   12. Roll for a Campaign Event
   13. Roll for a Character Event
   14. Check for Galactic War Progress

**Character System:**
- Human species (core), Swift, Soulless
- Backgrounds (12+ types)
- Motivations (personal goals)
- Classes (8 types: Soldier, Mercenary, Scavenger, etc.)
- Skills and abilities progression via XP
- Equipment loadouts

**Combat System:**
- D6-based tabletop wargame combat
- Movement, actions, reactions
- Cover and terrain rules
- Weapons: Low-Tech, Military, High-Tech categories
- Gear and gadgets
- Bot companions

**Economy:**
- Credits (currency)
- Trade Table (100 entries)
- Equipment purchase system
- Ship upkeep costs
- Loot system with multiple tables

**Mission Types (Core):**
- Patron jobs (6 Patron types: Corporation, Government, etc.)
- Opportunity missions
- Quest missions (multi-stage story missions)
- Rival encounters
- Invasion battles (Galactic War)

**World System:**
- Planetary travel
- World generation (procedural)
- Exploration Table (100 entries)
- Rivals (persistent enemies)
- Patrons (job-givers with relationships)
- Story Points (campaign currency)

**Starship System:**
- Hull Points (ship health)
- Ship debt
- Fuel costs
- Ship upgrades and components

### Expansion Content (Currently Mixed In)

**Currently Implemented Expansions:**
1. ✅ **Trailblazer's Toolkit** - Partially integrated (psionics, new species)
2. ✅ **Freelancer's Handbook** - Partially integrated (elite enemies, difficulty scaling)
3. ✅ **Fixer's Guidebook** - Partially integrated (salvage, stealth missions)
4. 🚧 **Bug Hunt** - Planned (UI button exists, core docs written)

**Integration Issues:**
- Expansion content mixed with core content in same data files
- No clear separation in code between core and DLC features
- DLCManager exists but not consistently used
- Some expansion features hardcoded into core systems

---

## 2. Expansion Content Breakdown

### 2.1 Trailblazer's Toolkit (DLC ID: `trailblazers_toolkit`)

**Content Type:** Character & Power Expansion

**Features:**

#### A. New Playable Species
| Species | Description | Special Rules | Data Files |
|---------|-------------|---------------|------------|
| **Krag** | Stocky, belligerent humanoids | -1" movement, +1 toughness | `SpeciesList.json` |
| **Skulker** | Agile rodent-like aliens | +1" movement, biological resistance | `SpeciesList.json` |

**Implementation:**
- Update `CharacterGeneration.gd` to check DLC ownership before offering species
- Species data flagged with `"dlc_required": "trailblazers_toolkit"`
- UI species selection shows "DLC Required" badge if not owned

#### B. Psionics System
**Complete new subsystem:**

| Component | Description | Files |
|-----------|-------------|-------|
| **Psionic Powers** | 10 powers (Barrier, Grab, Lift, Push, etc.) | `psionic_powers.json` |
| **Psionic Characters** | Character creation option | `character_backgrounds.json` |
| **Psionic Advancement** | Power progression system | Core rules integration |
| **World Legality** | "Psionics Outlawed" world trait | `world_traits.json` |
| **Enemy Psionics** | Psi-capable enemies | `elite_enemy_types.json` |
| **Psi-Hunter Rivals** | Special rival type | `RulesReference/EliteEnemies.json` |

**Implementation:**
```gdscript
# PsionicSystem.gd (new)
class PsionicSystem:
    static func is_available() -> bool:
        return DLCManager.is_dlc_owned("trailblazers_toolkit")

    static func get_available_powers() -> Array:
        if not is_available():
            return []
        return DataManager.load_json("data/psionic_powers.json")
```

#### C. Enhanced Character Options
- Additional backgrounds
- Advanced bot upgrades (6 types)
- Expanded training courses
- Psionic-specific gear

**Gating Strategy:**
- Lock psionic character option in character creator
- Hide psionic powers in skill tree if DLC not owned
- Filter equipment list to exclude psionic gear
- Remove Krag/Skulker from species dropdown

**Estimated Content Size:**
- 15% increase to character customization
- New subsystem (psionics)
- 2 new playable species

---

### 2.2 Freelancer's Handbook (DLC ID: `freelancers_handbook`)

**Content Type:** Combat & Challenge Expansion

**Features:**

#### A. Advanced Combat Systems

| Feature | Description | Implementation |
|---------|-------------|----------------|
| **Difficulty Scaling** | 8 toggleable difficulty modifiers | `CombatDifficultySystem.gd` |
| **Progressive AI** | Randomized enemy behaviors | `EnemyBehaviorSystem.gd` |
| **Elite Enemies** | 15+ elite enemy types with unique abilities | `elite_enemy_types.json` |
| **Deployment Variables** | 9 enemy deployment variations | `AlternateEnemyDeployment.json` |
| **Escalating Battles** | Dynamic reinforcement system | `BattleManager.gd` |

**Difficulty Toggles:**
1. Brutal foes (+1 enemy toughness)
2. Larger battles (+25% deployment points)
3. Veteran opposition (+1 enemy combat skill)
4. Elite foes (replace basic with elite)
5. Desperate combat (double injury rolls)
6. Scarcity (reduced loot)
7. High stakes (increased rival/patron pressure)
8. Lethal encounters (critical hits more likely)

#### B. Multiplayer Systems

| Mode | Description | Required Systems |
|------|-------------|------------------|
| **PvP Battles** | Player vs Player campaign battles | Turn sync, player matching |
| **Co-op Campaigns** | Shared campaign progression | State synchronization |
| **Three-Way Battles** | 2 players + neutral AI | Multi-faction combat |

**Implementation Note:** Network infrastructure required (separate planning doc)

#### C. Alternative Combat Mechanics

| System | Description | Use Case |
|--------|-------------|----------|
| **No-Minis Combat** | Abstract tactical resolution | Mobile/accessibility |
| **Grid-Based Movement** | Hex/square grid overlay | Structured tactical play |
| **Dramatic Combat** | Cinematic narrative resolution | Story-focused players |

**Gating Strategy:**
- Combat setup screen shows "Advanced Options" section (locked icon)
- Elite enemy types filtered from enemy generator
- Difficulty toggles grayed out with "Requires Freelancer's Handbook"
- Alternative combat modes hidden in settings

**Estimated Content Size:**
- 40% increase to combat depth
- 15+ elite enemy types
- Major combat system overhaul

---

### 2.3 Fixer's Guidebook (DLC ID: `fixers_guidebook`)

**Content Type:** Campaign & Mission Expansion

**Features:**

#### A. Advanced Mission Types

| Mission Type | Description | Data Files | Systems |
|--------------|-------------|------------|---------|
| **Stealth Missions** | Infiltration, detection mechanics | `StealthAndStreet.json` | StealthMissionSystem.gd |
| **Street Fights** | Urban combat, civilian hazards | `StealthAndStreet.json` | UrbanCombatSystem.gd |
| **Salvage Jobs** | Exploration, tension mechanics | `SalvageJobs.json` | SalvageJobSystem.gd |
| **Expanded Opportunities** | Connection-based work expansion | `expanded_missions.json` | OpportunitySystem.gd |

**Stealth Mission Mechanics:**
- Detection system (noise, visibility)
- Alarm escalation
- Non-lethal options
- Infiltration objectives

**Salvage Job Mechanics:**
- Tension meter (0-10)
- Random encounter tables
- Loot discovery system
- Environmental hazards

#### B. World & Campaign Enhancements

| Feature | Description | Implementation |
|---------|-------------|----------------|
| **Fringe World Strife** | World instability mechanics | `FringeWorldStrife.json` |
| **Loans System** | Debt tracking, interest, repo consequences | LoanManager.gd |
| **Expanded Factions** | Deep faction relationship trees | FactionRelationshipSystem.gd |
| **Introductory Campaign** | Tutorial campaign path | TutorialCampaignController.gd |

**Loans System:**
```gdscript
class Loan:
    creditor: String  # Who you owe
    principal: int    # Original amount
    interest_rate: float  # Per turn %
    turns_remaining: int
    default_consequences: Array[String]
```

#### C. Enhanced Tables & Events

| Table Type | Description | Count |
|------------|-------------|-------|
| **Casualty Tables** | Detailed injury outcomes | 36 entries |
| **Post-Battle Injuries** | Specific wound effects | 24 types |
| **Quest Progressions** | Multi-stage quest chains | 12 quest types |
| **World Events** | Faction conflicts, economic shifts | 20+ events |

**Gating Strategy:**
- Mission selection filters stealth/salvage if DLC not owned
- Loan system UI hidden in finances screen
- Fringe World Strife disabled in world generation
- Enhanced quest progressions revert to basic version

**Estimated Content Size:**
- 50% increase to mission variety
- Major campaign depth addition
- 4 new mission types

---

### 2.4 Bug Hunt (DLC ID: `bug_hunt`)

**Content Type:** Standalone Campaign Variant

**Features:**

#### A. Bug Hunt Campaign Mode

**Complete alternate campaign system:**

| Component | Description | Status |
|-----------|-------------|--------|
| **Military Campaign** | Squad-based tactical gameplay | 🚧 Planned |
| **Bug Enemy Types** | Xenomorph-inspired aliens | 🚧 Planned |
| **Military Equipment** | Specialized gear (pulse rifles, motion trackers) | 🚧 Planned |
| **Squad Mechanics** | Larger squad sizes (8-12 soldiers) | 🚧 Planned |
| **Military Terrain** | Colony installations, alien hives | 🚧 Planned |
| **Character Transfer** | Import/export between Five Parsecs & Bug Hunt | 🚧 Planned |

**Campaign Structure:**
1. Deployment Phase (assign soldiers to mission)
2. Tactical Phase (bug hunt combat)
3. Post-Action Phase (casualties, extraction)
4. Base Phase (resupply, reinforcements)

#### B. Unique Systems

| System | Description |
|--------|-------------|
| **Motion Tracker** | Enemy detection mechanic |
| **Panic & Morale** | Fear system for bug encounters |
| **Alien Infestation** | Colony corruption mechanics |
| **Military Hierarchy** | Rank-based squad leadership |
| **Extraction Objectives** | Time-limited escape scenarios |

**Implementation:**
```gdscript
# Separate game mode, accessed from main menu
# MainMenu.gd:
if DLCManager.is_dlc_owned("bug_hunt"):
    bug_hunt_button.disabled = false
    bug_hunt_button.text = "Bug Hunt Campaign"
else:
    bug_hunt_button.disabled = true
    bug_hunt_button.text = "Bug Hunt (DLC Required)"
```

**Character Transfer System:**
- Export Five Parsecs character to Bug Hunt (becomes soldier)
- Import Bug Hunt veteran to Five Parsecs (gains military background)
- Shared progression (experience, skills)

**Gating Strategy:**
- Main menu button locked with "Requires Bug Hunt DLC"
- Complete separation from core campaign (no cross-contamination)
- Character transfer requires both base game and Bug Hunt DLC

**Estimated Content Size:**
- 100% new campaign mode (standalone)
- Separate enemy bestiary
- Unique equipment set
- Independent ruleset

---

## 3. Proposed Architecture

### 3.1 Content Organization Structure

```
/data
├── /core_rules                    # BASE GAME ONLY
│   ├── character_creation.json
│   ├── core_species.json          # Human, Swift, Soulless (base species)
│   ├── core_equipment.json
│   ├── core_enemies.json
│   ├── core_missions.json
│   ├── core_world_traits.json
│   └── core_campaign_tables.json
│
├── /dlc_trailblazers_toolkit      # TRAILBLAZER'S TOOLKIT DLC
│   ├── expanded_species.json      # Krag, Skulker
│   ├── psionic_powers.json
│   ├── psionic_character_options.json
│   ├── psionic_enemies.json
│   ├── psionic_equipment.json
│   ├── bot_upgrades.json
│   └── advanced_training.json
│
├── /dlc_freelancers_handbook      # FREELANCER'S HANDBOOK DLC
│   ├── elite_enemies.json
│   ├── difficulty_modifiers.json
│   ├── alternative_combat_systems.json
│   ├── enemy_deployment_variants.json
│   ├── multiplayer_rules.json
│   └── advanced_ai_behaviors.json
│
├── /dlc_fixers_guidebook          # FIXER'S GUIDEBOOK DLC
│   ├── stealth_missions.json
│   ├── street_fights.json
│   ├── salvage_jobs.json
│   ├── expanded_opportunities.json
│   ├── fringe_world_strife.json
│   ├── loans_system.json
│   ├── faction_relationships.json
│   ├── casualty_tables.json
│   └── tutorial_campaign.json
│
├── /dlc_bug_hunt                  # BUG HUNT DLC
│   ├── bug_enemies.json
│   ├── military_equipment.json
│   ├── military_campaign_rules.json
│   ├── bug_hunt_missions.json
│   ├── colony_terrain.json
│   └── character_transfer_rules.json
│
└── /RulesReference                # CURRENT MIXED CONTENT (TO MIGRATE)
    ├── Bestiary.json              → split to core + DLC
    ├── EquipmentItems.json        → split to core + DLC
    ├── SpeciesList.json           → split to core + DLC
    ├── SalvageJobs.json           → move to dlc_fixers_guidebook/
    ├── Psionics.json              → move to dlc_trailblazers_toolkit/
    └── EliteEnemies.json          → move to dlc_freelancers_handbook/
```

### 3.2 Code Architecture

**New Core System: ExpansionManager.gd**

```gdscript
# src/core/managers/ExpansionManager.gd
extends Node

# Singleton autoload

var registered_expansions: Dictionary = {}

func _ready():
    _register_all_expansions()

func _register_all_expansions():
    register_expansion("trailblazers_toolkit", {
        "name": "Trailblazer's Toolkit",
        "data_path": "res://data/dlc_trailblazers_toolkit/",
        "systems": ["PsionicSystem", "ExpandedSpeciesSystem"],
        "content_types": ["species", "powers", "equipment"]
    })

    register_expansion("freelancers_handbook", {
        "name": "Freelancer's Handbook",
        "data_path": "res://data/dlc_freelancers_handbook/",
        "systems": ["EliteEnemySystem", "DifficultyScalingSystem", "AdvancedCombatSystem"],
        "content_types": ["enemies", "combat_rules", "ai_behaviors"]
    })

    register_expansion("fixers_guidebook", {
        "name": "Fixer's Guidebook",
        "data_path": "res://data/dlc_fixers_guidebook/",
        "systems": ["StealthMissionSystem", "SalvageJobSystem", "LoanSystem", "FringeWorldStrifeSystem"],
        "content_types": ["missions", "world_events", "faction_rules"]
    })

    register_expansion("bug_hunt", {
        "name": "Bug Hunt",
        "data_path": "res://data/dlc_bug_hunt/",
        "systems": ["BugHuntCampaignManager", "MilitaryEquipmentSystem"],
        "content_types": ["campaign_mode", "enemies", "equipment"],
        "standalone": true
    })

func register_expansion(dlc_id: String, config: Dictionary):
    registered_expansions[dlc_id] = config

func is_expansion_available(dlc_id: String) -> bool:
    return DLCManager.is_dlc_owned(dlc_id)

func get_expansion_data_path(dlc_id: String) -> String:
    if not is_expansion_available(dlc_id):
        return ""
    return registered_expansions.get(dlc_id, {}).get("data_path", "")

func load_expansion_data(dlc_id: String, file_name: String) -> Dictionary:
    if not is_expansion_available(dlc_id):
        return {}

    var path = get_expansion_data_path(dlc_id) + file_name
    return DataManager.load_json(path)

func get_available_content(content_type: String) -> Array:
    var content = []

    # Always include core content
    content.append_array(_load_core_content(content_type))

    # Add DLC content if owned
    for dlc_id in registered_expansions.keys():
        if is_expansion_available(dlc_id):
            var expansion = registered_expansions[dlc_id]
            if content_type in expansion.get("content_types", []):
                content.append_array(_load_dlc_content(dlc_id, content_type))

    return content

func _load_core_content(content_type: String) -> Array:
    match content_type:
        "species":
            return DataManager.load_json("res://data/core_rules/core_species.json")
        "equipment":
            return DataManager.load_json("res://data/core_rules/core_equipment.json")
        "enemies":
            return DataManager.load_json("res://data/core_rules/core_enemies.json")
        "missions":
            return DataManager.load_json("res://data/core_rules/core_missions.json")
    return []

func _load_dlc_content(dlc_id: String, content_type: String) -> Array:
    var expansion = registered_expansions[dlc_id]
    var base_path = expansion.get("data_path", "")

    match content_type:
        "species":
            if dlc_id == "trailblazers_toolkit":
                return DataManager.load_json(base_path + "expanded_species.json")
        "equipment":
            if dlc_id == "trailblazers_toolkit":
                return DataManager.load_json(base_path + "psionic_equipment.json")
            elif dlc_id == "bug_hunt":
                return DataManager.load_json(base_path + "military_equipment.json")
        "enemies":
            if dlc_id == "freelancers_handbook":
                return DataManager.load_json(base_path + "elite_enemies.json")
            elif dlc_id == "bug_hunt":
                return DataManager.load_json(base_path + "bug_enemies.json")
        "missions":
            if dlc_id == "fixers_guidebook":
                var missions = []
                missions.append_array(DataManager.load_json(base_path + "stealth_missions.json"))
                missions.append_array(DataManager.load_json(base_path + "salvage_jobs.json"))
                return missions

    return []
```

### 3.3 System Integration Pattern

**Example: Character Species Selection**

```gdscript
# src/ui/screens/CharacterCreation.gd

func _populate_species_dropdown():
    species_dropdown.clear()

    # Get all available species (core + owned DLC)
    var available_species = ExpansionManager.get_available_content("species")

    for species in available_species:
        var label = species.name

        # Check if species requires DLC
        if "dlc_required" in species:
            var dlc_id = species.dlc_required
            if not DLCManager.is_dlc_owned(dlc_id):
                # Show locked option with DLC badge
                label += " 🔒 (Requires " + ExpansionManager.registered_expansions[dlc_id].name + ")"
                species_dropdown.add_item(label)
                species_dropdown.set_item_disabled(species_dropdown.get_item_count() - 1, true)
                continue

        species_dropdown.add_item(label)
```

**Example: Mission Generation**

```gdscript
# src/core/mission/MissionGenerator.gd

func generate_available_missions() -> Array:
    var missions = []

    # Core missions always available
    missions.append_array(_generate_core_missions())

    # Add DLC missions if owned
    if ExpansionManager.is_expansion_available("fixers_guidebook"):
        missions.append_array(_generate_stealth_missions())
        missions.append_array(_generate_salvage_jobs())

    return missions

func _generate_stealth_missions() -> Array:
    var stealth_data = ExpansionManager.load_expansion_data(
        "fixers_guidebook",
        "stealth_missions.json"
    )

    # Generate stealth missions from DLC data
    return StealthMissionSystem.generate_from_data(stealth_data)
```

---

## 4. DLC Gating Strategy

### 4.1 DLCManager Enhancement

**Current State:** DLCManager exists but is not consistently used

**Required Updates:**

```gdscript
# src/core/managers/DLCManager.gd

extends Node

# DLC Product IDs (platform-specific)
const DLC_PRODUCTS = {
    "trailblazers_toolkit": {
        "steam_app_id": "1234560",
        "google_play_sku": "com.fiveparsecs.dlc.trailblazers",
        "apple_product_id": "fiveparsecs.dlc.trailblazers",
        "display_name": "Trailblazer's Toolkit",
        "price_usd": 4.99
    },
    "freelancers_handbook": {
        "steam_app_id": "1234561",
        "google_play_sku": "com.fiveparsecs.dlc.freelancers",
        "apple_product_id": "fiveparsecs.dlc.freelancers",
        "display_name": "Freelancer's Handbook",
        "price_usd": 6.99
    },
    "fixers_guidebook": {
        "steam_app_id": "1234562",
        "google_play_sku": "com.fiveparsecs.dlc.fixers",
        "apple_product_id": "fiveparsecs.dlc.fixers",
        "display_name": "Fixer's Guidebook",
        "price_usd": 6.99
    },
    "bug_hunt": {
        "steam_app_id": "1234563",
        "google_play_sku": "com.fiveparsecs.dlc.bughunt",
        "apple_product_id": "fiveparsecs.dlc.bughunt",
        "display_name": "Bug Hunt",
        "price_usd": 9.99
    },
    "complete_compendium": {
        "steam_app_id": "1234564",
        "google_play_sku": "com.fiveparsecs.dlc.compendium",
        "apple_product_id": "fiveparsecs.dlc.compendium",
        "display_name": "Complete Compendium Bundle",
        "price_usd": 19.99,
        "includes": ["trailblazers_toolkit", "freelancers_handbook", "fixers_guidebook", "bug_hunt"]
    }
}

var owned_dlcs: Dictionary = {}

func _ready():
    _initialize_platform_store()
    _load_ownership_state()

func is_dlc_owned(dlc_id: String) -> bool:
    # Development override
    if OS.has_feature("editor") and ProjectSettings.get_setting("dlc/unlock_all_in_editor", true):
        return true

    # Check bundle ownership
    if is_dlc_owned("complete_compendium"):
        var bundle_includes = DLC_PRODUCTS["complete_compendium"].get("includes", [])
        if dlc_id in bundle_includes:
            return true

    # Check individual ownership
    return owned_dlcs.get(dlc_id, false)

func purchase_dlc(dlc_id: String):
    # Platform-specific purchase flow
    match OS.get_name():
        "Android":
            _purchase_google_play(dlc_id)
        "iOS":
            _purchase_app_store(dlc_id)
        "Windows", "Linux", "macOS":
            _purchase_steam(dlc_id)

func _purchase_steam(dlc_id: String):
    if not DLC_PRODUCTS.has(dlc_id):
        return

    var steam_app_id = DLC_PRODUCTS[dlc_id].steam_app_id
    # Use Steamworks plugin
    Steam.activateGameOverlayToStore(int(steam_app_id))

func _initialize_platform_store():
    match OS.get_name():
        "Android":
            # Initialize Google Play Billing
            pass
        "iOS":
            # Initialize StoreKit
            pass
        "Windows", "Linux", "macOS":
            # Initialize Steamworks
            if Engine.has_singleton("Steam"):
                Steam.steamInit()

func get_dlc_store_listing() -> Array:
    var listings = []
    for dlc_id in DLC_PRODUCTS.keys():
        if not is_dlc_owned(dlc_id):
            listings.append({
                "id": dlc_id,
                "name": DLC_PRODUCTS[dlc_id].display_name,
                "price": DLC_PRODUCTS[dlc_id].price_usd,
                "owned": false
            })
    return listings
```

### 4.2 UI Integration Points

**Main Menu DLC Upsell:**

```gdscript
# MainMenu.gd

func _on_dlc_store_button_pressed():
    var dlc_store_scene = preload("res://src/ui/screens/DLCStore.tscn")
    get_tree().change_scene_to_packed(dlc_store_scene)

func _update_bug_hunt_button():
    if DLCManager.is_dlc_owned("bug_hunt"):
        bug_hunt_button.disabled = false
        bug_hunt_button.text = "Bug Hunt Campaign"
    else:
        bug_hunt_button.disabled = false  # Clickable to show DLC prompt
        bug_hunt_button.text = "Bug Hunt 🔒"

func _on_bug_hunt_button_pressed():
    if not DLCManager.is_dlc_owned("bug_hunt"):
        _show_dlc_required_dialog("bug_hunt")
        return

    # Launch Bug Hunt campaign
    SceneRouter.change_scene("bug_hunt_menu")

func _show_dlc_required_dialog(dlc_id: String):
    var dlc_name = DLCManager.DLC_PRODUCTS[dlc_id].display_name
    var price = DLCManager.DLC_PRODUCTS[dlc_id].price_usd

    var dialog = AcceptDialog.new()
    dialog.title = "DLC Required"
    dialog.dialog_text = "This feature requires the %s DLC ($%.2f).\n\nWould you like to view the DLC store?" % [dlc_name, price]
    dialog.add_button("View Store", true, "view_store")
    dialog.custom_action.connect(_on_dlc_dialog_action)
    add_child(dialog)
    dialog.popup_centered()

func _on_dlc_dialog_action(action: String):
    if action == "view_store":
        _on_dlc_store_button_pressed()
```

**In-Game DLC Prompts:**

```gdscript
# CharacterCreation.gd

func _on_species_selected(index: int):
    var species = available_species[index]

    if "dlc_required" in species:
        var dlc_id = species.dlc_required
        if not DLCManager.is_dlc_owned(dlc_id):
            _show_dlc_species_preview(species, dlc_id)
            species_dropdown.selected = previous_selection
            return

    # Proceed with species selection
    selected_species = species

func _show_dlc_species_preview(species: Dictionary, dlc_id: String):
    var preview_panel = Panel.new()
    # Show species preview art, stats, lore
    # Display "Unlock with [DLC Name]" button
    # Button opens DLC store
```

### 4.3 Content Filtering System

**Automated Content Filter:**

```gdscript
# src/core/data/ContentFilter.gd

class_name ContentFilter

static func filter_by_ownership(items: Array) -> Array:
    var filtered = []

    for item in items:
        if not "dlc_required" in item:
            # Core content - always include
            filtered.append(item)
            continue

        var dlc_id = item.dlc_required
        if DLCManager.is_dlc_owned(dlc_id):
            # DLC content - include if owned
            filtered.append(item)

    return filtered

static func mark_dlc_items(items: Array) -> Array:
    # Add visual markers for DLC items (for shop UI, etc.)
    for item in items:
        if "dlc_required" in item:
            item["is_dlc_content"] = true
            item["dlc_display_name"] = DLCManager.DLC_PRODUCTS[item.dlc_required].display_name

    return items
```

---

## 5. Implementation Roadmap

### Phase 1: Data Separation (Week 1-2)

**Goal:** Separate all expansion content from core files

**Tasks:**

1. **Create new directory structure**
   - [ ] Create `/data/core_rules/` directory
   - [ ] Create `/data/dlc_trailblazers_toolkit/` directory
   - [ ] Create `/data/dlc_freelancers_handbook/` directory
   - [ ] Create `/data/dlc_fixers_guidebook/` directory
   - [ ] Create `/data/dlc_bug_hunt/` directory

2. **Split existing data files**
   - [ ] Split `SpeciesList.json` → `core_species.json` + `dlc_trailblazers_toolkit/expanded_species.json`
   - [ ] Split `Bestiary.json` → `core_enemies.json` + `dlc_freelancers_handbook/elite_enemies.json`
   - [ ] Split `EquipmentItems.json` → `core_equipment.json` + DLC equipment files
   - [ ] Move `Psionics.json` → `dlc_trailblazers_toolkit/psionic_powers.json`
   - [ ] Move `SalvageJobs.json` → `dlc_fixers_guidebook/salvage_jobs.json`
   - [ ] Move `StealthAndStreet.json` → `dlc_fixers_guidebook/stealth_missions.json`

3. **Add DLC metadata to content**
   - [ ] Tag all DLC items with `"dlc_required": "<dlc_id>"`
   - [ ] Add `"source": "core"` or `"source": "<dlc_id>"` to all content
   - [ ] Create content manifest files for each DLC

4. **Validation**
   - [ ] Create data validation script to ensure no orphaned references
   - [ ] Verify all content has proper DLC tags
   - [ ] Test data loading with new structure

**Deliverables:**
- Clean data separation
- DLC metadata complete
- Validation passing

---

### Phase 2: Core System Implementation (Week 3-4)

**Goal:** Implement ExpansionManager and update DataManager

**Tasks:**

1. **Create ExpansionManager**
   - [ ] Create `src/core/managers/ExpansionManager.gd`
   - [ ] Implement expansion registration system
   - [ ] Implement content loading methods
   - [ ] Add to autoload singletons

2. **Update DataManager**
   - [ ] Add support for DLC data paths
   - [ ] Implement content merging (core + DLC)
   - [ ] Add caching for DLC content
   - [ ] Update load methods to use ExpansionManager

3. **Enhance DLCManager**
   - [ ] Add all DLC product definitions
   - [ ] Implement platform-specific purchase flows
   - [ ] Add ownership verification
   - [ ] Create development override system

4. **Create ContentFilter utility**
   - [ ] Implement ownership-based filtering
   - [ ] Add DLC marking system
   - [ ] Create helper methods for common filtering patterns

5. **Testing**
   - [ ] Unit tests for ExpansionManager
   - [ ] Integration tests for content loading
   - [ ] Test DLC ownership toggling
   - [ ] Verify content filtering

**Deliverables:**
- ExpansionManager fully functional
- DLCManager enhanced
- Content loading updated
- Tests passing

---

### Phase 3: Trailblazer's Toolkit Integration (Week 5-6)

**Goal:** Fully integrate Trailblazer's Toolkit as DLC

**Tasks:**

1. **Psionics System**
   - [ ] Create `PsionicSystem.gd` with DLC gating
   - [ ] Update character creation to check DLC ownership
   - [ ] Add psionic power selection UI with DLC prompts
   - [ ] Implement world legality checks (Psionics Outlawed trait)
   - [ ] Add Psi-Hunter rival generation (DLC-gated)

2. **Species Expansion**
   - [ ] Update species dropdown to show DLC species with lock icons
   - [ ] Create species preview UI for locked species
   - [ ] Implement Krag special rules (movement penalty)
   - [ ] Implement Skulker special rules (biological resistance)
   - [ ] Add species-specific character generation

3. **Equipment & Training**
   - [ ] Gate bot upgrades behind DLC check
   - [ ] Gate psionic equipment in shop
   - [ ] Add DLC badges to equipment UI
   - [ ] Update training menu with DLC courses

4. **UI Integration**
   - [ ] Add "Trailblazer's Toolkit" DLC indicator to main menu
   - [ ] Create DLC preview panel for psionics
   - [ ] Implement "Unlock DLC" prompts in character creator
   - [ ] Add tooltips explaining locked features

5. **Testing**
   - [ ] Test with DLC enabled
   - [ ] Test with DLC disabled (all content hidden)
   - [ ] Test mixed crews (core + DLC species)
   - [ ] Verify psionic combat mechanics

**Deliverables:**
- Trailblazer's Toolkit fully gated
- All content accessible with DLC
- All content hidden without DLC
- UI prompts functional

---

### Phase 4: Freelancer's Handbook Integration (Week 7-8)

**Goal:** Integrate combat expansion as DLC

**Tasks:**

1. **Difficulty Scaling System**
   - [ ] Create `DifficultyScalingSystem.gd`
   - [ ] Implement 8 difficulty toggles
   - [ ] Gate difficulty options behind DLC check
   - [ ] Add difficulty UI to combat setup screen
   - [ ] Implement difficulty modifiers in combat

2. **Elite Enemy System**
   - [ ] Create `EliteEnemySystem.gd`
   - [ ] Filter elite enemies from generator if DLC not owned
   - [ ] Implement elite enemy special abilities
   - [ ] Add elite enemy UI indicators
   - [ ] Update enemy AI for elite behaviors

3. **Alternative Combat Systems**
   - [ ] Gate no-minis combat option
   - [ ] Gate grid-based movement option
   - [ ] Gate dramatic combat option
   - [ ] Add settings toggles with DLC prompts
   - [ ] Implement alternative combat resolvers

4. **Deployment Variations**
   - [ ] Implement 9 deployment variables
   - [ ] Gate deployment options in combat setup
   - [ ] Create UI for deployment selection
   - [ ] Test deployment variations

5. **Multiplayer Prep** (Foundation only)
   - [ ] Create multiplayer rule data files
   - [ ] Design multiplayer UI (non-functional)
   - [ ] Add "Coming Soon" multiplayer menu option
   - [ ] Document multiplayer requirements

6. **Testing**
   - [ ] Test all difficulty toggles
   - [ ] Test elite enemy generation
   - [ ] Test alternative combat modes
   - [ ] Verify DLC gating

**Deliverables:**
- Freelancer's Handbook fully gated
- Difficulty system functional
- Elite enemies integrated
- Alternative combat modes working

---

### Phase 5: Fixer's Guidebook Integration (Week 9-10)

**Goal:** Integrate mission & campaign expansion as DLC

**Tasks:**

1. **Stealth Mission System**
   - [ ] Create `StealthMissionSystem.gd`
   - [ ] Implement detection mechanics
   - [ ] Implement alarm system
   - [ ] Add stealth UI (detection meter, noise indicators)
   - [ ] Gate stealth missions in mission selection

2. **Salvage Job System**
   - [ ] Create `SalvageJobSystem.gd`
   - [ ] Implement tension mechanics
   - [ ] Implement random encounter system
   - [ ] Add salvage UI (tension meter, loot discovery)
   - [ ] Gate salvage jobs in mission selection

3. **Street Fight System**
   - [ ] Create `UrbanCombatSystem.gd`
   - [ ] Implement civilian hazards
   - [ ] Add urban terrain generation
   - [ ] Gate street fights in mission selection

4. **Loans System**
   - [ ] Create `LoanManager.gd`
   - [ ] Implement debt tracking
   - [ ] Implement interest accrual
   - [ ] Implement default consequences
   - [ ] Add loans UI to finances screen
   - [ ] Gate loans feature

5. **Fringe World Strife**
   - [ ] Create `FringeWorldStrifeSystem.gd`
   - [ ] Implement world instability mechanics
   - [ ] Add world event generation
   - [ ] Update world generation to include strife
   - [ ] Gate strife system

6. **Faction Relationships**
   - [ ] Enhance `FactionSystem.gd`
   - [ ] Implement relationship trees
   - [ ] Add faction conflict events
   - [ ] Create faction UI panel
   - [ ] Gate enhanced faction system

7. **Tutorial Campaign**
   - [ ] Create `TutorialCampaignController.gd`
   - [ ] Design tutorial mission sequence
   - [ ] Add tutorial UI guidance
   - [ ] Gate tutorial campaign option

8. **Testing**
   - [ ] Test stealth missions end-to-end
   - [ ] Test salvage jobs
   - [ ] Test loans system (debt, default)
   - [ ] Test world strife generation
   - [ ] Verify all DLC gating

**Deliverables:**
- Fixer's Guidebook fully gated
- All 4 mission types functional
- Campaign enhancements working
- Loans and world strife systems complete

---

### Phase 6: Bug Hunt Implementation (Week 11-14)

**Goal:** Create standalone Bug Hunt campaign mode

**Tasks:**

1. **Bug Hunt Core Systems**
   - [ ] Create `BugHuntCampaignManager.gd`
   - [ ] Implement military campaign phases
   - [ ] Create squad management system
   - [ ] Implement military hierarchy
   - [ ] Design Bug Hunt main menu

2. **Bug Enemy System**
   - [ ] Create bug enemy data files
   - [ ] Implement bug AI behaviors
   - [ ] Create bug enemy types (workers, soldiers, queens)
   - [ ] Implement swarm mechanics
   - [ ] Add alien infestation system

3. **Military Equipment**
   - [ ] Create military equipment data
   - [ ] Implement specialized gear (motion tracker, pulse rifle)
   - [ ] Add military equipment shop
   - [ ] Implement equipment restrictions

4. **Bug Hunt Missions**
   - [ ] Design bug hunt mission types
   - [ ] Implement extraction objectives
   - [ ] Create colony terrain generation
   - [ ] Add alien hive environments
   - [ ] Implement time-limited scenarios

5. **Panic & Morale System**
   - [ ] Create `PanicSystem.gd`
   - [ ] Implement fear mechanics
   - [ ] Implement morale tracking
   - [ ] Add panic UI indicators
   - [ ] Create panic resolution system

6. **Character Transfer System**
   - [ ] Create `CharacterTransferSystem.gd`
   - [ ] Implement Five Parsecs → Bug Hunt transfer
   - [ ] Implement Bug Hunt → Five Parsecs transfer
   - [ ] Add transfer UI
   - [ ] Implement stat conversion

7. **Bug Hunt UI**
   - [ ] Design Bug Hunt campaign screen
   - [ ] Create squad roster UI
   - [ ] Design military equipment menu
   - [ ] Create panic/morale indicators
   - [ ] Build Bug Hunt main menu

8. **DLC Gating**
   - [ ] Gate main menu Bug Hunt button
   - [ ] Add DLC purchase prompt
   - [ ] Implement DLC verification
   - [ ] Test with DLC disabled

9. **Testing**
   - [ ] Test Bug Hunt campaign flow
   - [ ] Test bug enemy encounters
   - [ ] Test panic system
   - [ ] Test character transfer
   - [ ] Full Bug Hunt playthrough

**Deliverables:**
- Bug Hunt fully playable
- Character transfer working
- All systems integrated
- DLC gating complete

---

### Phase 7: UI/UX Polish & DLC Store (Week 15-16)

**Goal:** Create cohesive DLC experience and store

**Tasks:**

1. **DLC Store UI**
   - [ ] Create `DLCStore.tscn` scene
   - [ ] Design DLC product cards
   - [ ] Add DLC preview screenshots
   - [ ] Implement purchase buttons
   - [ ] Add bundle pricing
   - [ ] Create "Complete Compendium" bundle UI

2. **In-Game DLC Prompts**
   - [ ] Standardize DLC prompt dialogs
   - [ ] Add preview panels for locked content
   - [ ] Create "Learn More" buttons
   - [ ] Implement consistent iconography (🔒)
   - [ ] Add hover tooltips for DLC features

3. **Main Menu Enhancements**
   - [ ] Add DLC indicators to main menu
   - [ ] Create "DLC Store" main menu button
   - [ ] Add "New DLC Available" notifications
   - [ ] Design DLC badge system

4. **Content Preview System**
   - [ ] Create species preview panels
   - [ ] Create mission type previews
   - [ ] Add "Try before you buy" demo missions
   - [ ] Implement content galleries

5. **Settings Integration**
   - [ ] Add DLC management section to settings
   - [ ] Show owned DLC status
   - [ ] Add "Restore Purchases" button (mobile)
   - [ ] Implement DLC verification refresh

6. **Testing**
   - [ ] Test purchase flow on all platforms
   - [ ] Test DLC store UI
   - [ ] Test all DLC prompts
   - [ ] Verify content previews
   - [ ] User acceptance testing

**Deliverables:**
- DLC store fully functional
- All DLC prompts polished
- Main menu updated
- Purchase flow tested

---

### Phase 8: Testing & Validation (Week 17-18)

**Goal:** Comprehensive testing of DLC system

**Tasks:**

1. **Ownership State Testing**
   - [ ] Test: No DLC owned (base game only)
   - [ ] Test: Trailblazer's Toolkit only
   - [ ] Test: Freelancer's Handbook only
   - [ ] Test: Fixer's Guidebook only
   - [ ] Test: Bug Hunt only
   - [ ] Test: Multiple DLC combinations
   - [ ] Test: Complete Compendium bundle

2. **Content Isolation Testing**
   - [ ] Verify no DLC content leaks into base game
   - [ ] Verify no cross-DLC dependencies
   - [ ] Test content filtering in all systems
   - [ ] Verify save game compatibility

3. **Purchase Flow Testing**
   - [ ] Test Steam purchase flow
   - [ ] Test Google Play purchase flow
   - [ ] Test Apple App Store purchase flow
   - [ ] Test purchase restoration
   - [ ] Test bundle purchases

4. **Campaign Integration Testing**
   - [ ] Test campaign with no DLC
   - [ ] Test campaign with each DLC individually
   - [ ] Test campaign with all DLC
   - [ ] Test mid-campaign DLC purchase
   - [ ] Test character progression with DLC content

5. **Performance Testing**
   - [ ] Load time testing with/without DLC
   - [ ] Memory usage profiling
   - [ ] Asset loading optimization
   - [ ] Save file size verification

6. **Bug Fixing**
   - [ ] Create bug tracking spreadsheet
   - [ ] Prioritize critical bugs
   - [ ] Fix and regression test
   - [ ] Final QA pass

**Deliverables:**
- All ownership states tested
- No content leakage
- Purchase flows verified
- Bugs fixed

---

### Phase 9: Documentation & Release Prep (Week 19-20)

**Goal:** Prepare for DLC launch

**Tasks:**

1. **Player Documentation**
   - [ ] Create DLC feature comparison chart
   - [ ] Write DLC descriptions for store pages
   - [ ] Create DLC FAQ
   - [ ] Design promotional materials

2. **Developer Documentation**
   - [ ] Document ExpansionManager API
   - [ ] Create DLC integration guide
   - [ ] Write modding guide (if applicable)
   - [ ] Update architecture diagrams

3. **Store Page Preparation**
   - [ ] Write Steam DLC descriptions
   - [ ] Create Google Play Store listings
   - [ ] Create Apple App Store listings
   - [ ] Design DLC promotional images
   - [ ] Create DLC trailers/videos

4. **Launch Preparation**
   - [ ] Set DLC pricing
   - [ ] Schedule release dates
   - [ ] Prepare launch day communications
   - [ ] Plan promotional campaigns

5. **Final Build**
   - [ ] Create release builds for all platforms
   - [ ] Submit to platform stores
   - [ ] Configure DLC product IDs
   - [ ] Test production DLC purchases (sandbox)

**Deliverables:**
- Documentation complete
- Store pages ready
- Release builds submitted
- Launch plan finalized

---

## 6. Data File Reorganization

### 6.1 Migration Script

**Tool: Data Migration Utility**

```gdscript
# tools/dlc_migration/migrate_data.gd
# Run from Godot Editor: Tools > DLC Migration > Migrate All Data

extends SceneTree

const MIGRATION_RULES = {
    "SpeciesList.json": {
        "core_items": ["Human", "Swift", "Soulless"],
        "dlc_items": {
            "Krag": "trailblazers_toolkit",
            "Skulker": "trailblazers_toolkit"
        },
        "output_files": {
            "core": "data/core_rules/core_species.json",
            "trailblazers_toolkit": "data/dlc_trailblazers_toolkit/expanded_species.json"
        }
    },

    "Bestiary.json": {
        "core_items": ["Pirate", "Raider", "Mercenary", "Corporate Security"],
        "dlc_items": {
            "Elite Mercenary": "freelancers_handbook",
            "Psionic Adept": "trailblazers_toolkit",
            "Bug Warrior": "bug_hunt"
        },
        "output_files": {
            "core": "data/core_rules/core_enemies.json",
            "freelancers_handbook": "data/dlc_freelancers_handbook/elite_enemies.json",
            "trailblazers_toolkit": "data/dlc_trailblazers_toolkit/psionic_enemies.json",
            "bug_hunt": "data/dlc_bug_hunt/bug_enemies.json"
        }
    },

    "EquipmentItems.json": {
        "core_items": ["Handgun", "Shotgun", "Rifle", "Blade", "Battle Armor"],
        "dlc_items": {
            "Psi-Amp": "trailblazers_toolkit",
            "Pulse Rifle": "bug_hunt",
            "Stealth Suit": "fixers_guidebook"
        },
        "output_files": {
            "core": "data/core_rules/core_equipment.json",
            "trailblazers_toolkit": "data/dlc_trailblazers_toolkit/psionic_equipment.json",
            "bug_hunt": "data/dlc_bug_hunt/military_equipment.json",
            "fixers_guidebook": "data/dlc_fixers_guidebook/stealth_equipment.json"
        }
    }
}

func _init():
    print("Starting DLC data migration...")

    for source_file in MIGRATION_RULES.keys():
        _migrate_file(source_file)

    print("Migration complete!")
    quit()

func _migrate_file(source_file: String):
    print("Migrating: " + source_file)

    var rules = MIGRATION_RULES[source_file]
    var source_path = "res://data/RulesReference/" + source_file

    # Load source data
    var source_data = _load_json(source_path)
    if source_data.is_empty():
        print("  ERROR: Could not load " + source_file)
        return

    # Separate items by destination
    var separated_data = {
        "core": [],
        "trailblazers_toolkit": [],
        "freelancers_handbook": [],
        "fixers_guidebook": [],
        "bug_hunt": []
    }

    for item in source_data:
        var item_name = item.get("name", "")

        # Check if core item
        if item_name in rules.core_items:
            item["source"] = "core"
            separated_data["core"].append(item)
            continue

        # Check if DLC item
        if item_name in rules.dlc_items.keys():
            var dlc_id = rules.dlc_items[item_name]
            item["source"] = dlc_id
            item["dlc_required"] = dlc_id
            separated_data[dlc_id].append(item)
            continue

        # Default to core if not specified
        print("  WARNING: " + item_name + " not in migration rules, defaulting to core")
        item["source"] = "core"
        separated_data["core"].append(item)

    # Write separated files
    for category in separated_data.keys():
        if separated_data[category].is_empty():
            continue

        var output_path = rules.output_files.get(category, "")
        if output_path.is_empty():
            continue

        _save_json(output_path, separated_data[category])
        print("  Wrote " + str(separated_data[category].size()) + " items to " + output_path)

func _load_json(path: String) -> Array:
    var file = FileAccess.open(path, FileAccess.READ)
    if not file:
        return []

    var json_string = file.get_as_text()
    file.close()

    var json = JSON.new()
    var parse_result = json.parse(json_string)

    if parse_result == OK:
        return json.data if json.data is Array else []

    return []

func _save_json(path: String, data: Array):
    var dir = DirAccess.open("res://")
    var dir_path = path.get_base_dir()

    # Create directory if doesn't exist
    if not dir.dir_exists(dir_path):
        dir.make_dir_recursive(dir_path)

    var file = FileAccess.open(path, FileAccess.WRITE)
    if not file:
        print("  ERROR: Could not write to " + path)
        return

    var json_string = JSON.stringify(data, "  ")
    file.store_string(json_string)
    file.close()
```

### 6.2 File Mapping

**Before Migration:**
```
/data/RulesReference/
├── SpeciesList.json          [MIXED: core + DLC]
├── Bestiary.json             [MIXED: core + DLC]
├── EquipmentItems.json       [MIXED: core + DLC]
├── Psionics.json             [DLC: Trailblazer's Toolkit]
├── SalvageJobs.json          [DLC: Fixer's Guidebook]
├── StealthAndStreet.json     [DLC: Fixer's Guidebook]
├── EliteEnemies.json         [DLC: Freelancer's Handbook]
└── AlternateEnemyDeployment.json [DLC: Freelancer's Handbook]
```

**After Migration:**
```
/data/
├── /core_rules/
│   ├── core_species.json              [Human, Swift, Soulless]
│   ├── core_enemies.json              [Pirates, Raiders, etc.]
│   ├── core_equipment.json            [Handgun, Rifle, etc.]
│   ├── core_missions.json             [Patrol, Defense, etc.]
│   ├── core_world_traits.json         [Standard worlds]
│   └── core_campaign_tables.json      [Base campaign events]
│
├── /dlc_trailblazers_toolkit/
│   ├── expanded_species.json          [Krag, Skulker]
│   ├── psionic_powers.json            [10 psionic powers]
│   ├── psionic_character_options.json [Psionic backgrounds]
│   ├── psionic_enemies.json           [Psionic Adept, etc.]
│   ├── psionic_equipment.json         [Psi-Amp, etc.]
│   ├── bot_upgrades.json              [6 bot upgrades]
│   └── advanced_training.json         [Psionic training]
│
├── /dlc_freelancers_handbook/
│   ├── elite_enemies.json             [Elite Mercenary, etc.]
│   ├── difficulty_modifiers.json      [8 difficulty toggles]
│   ├── alternative_combat_systems.json [No-minis, grid, dramatic]
│   ├── enemy_deployment_variants.json [9 deployment options]
│   ├── multiplayer_rules.json         [PvP, co-op rules]
│   └── advanced_ai_behaviors.json     [AI variations]
│
├── /dlc_fixers_guidebook/
│   ├── stealth_missions.json          [Infiltration missions]
│   ├── street_fights.json             [Urban combat]
│   ├── salvage_jobs.json              [Exploration missions]
│   ├── expanded_opportunities.json    [Connection jobs]
│   ├── fringe_world_strife.json       [World instability]
│   ├── loans_system.json              [Debt mechanics]
│   ├── faction_relationships.json     [Faction trees]
│   ├── casualty_tables.json           [36 casualty types]
│   └── tutorial_campaign.json         [Tutorial sequence]
│
└── /dlc_bug_hunt/
    ├── bug_enemies.json               [Bug workers, soldiers, queens]
    ├── military_equipment.json        [Pulse rifle, motion tracker]
    ├── military_campaign_rules.json   [Military phases]
    ├── bug_hunt_missions.json         [Extraction, defense]
    ├── colony_terrain.json            [Colony maps]
    └── character_transfer_rules.json  [Transfer mechanics]
```

---

## 7. Code Refactoring Plan

### 7.1 Files to Modify

**High Priority (Core Systems):**

| File | Required Changes | Complexity |
|------|------------------|------------|
| `src/core/managers/DataManager.gd` | Update to use ExpansionManager | Medium |
| `src/ui/screens/CharacterCreation.gd` | Add DLC gating for species, psionics | High |
| `src/core/character/CharacterGeneration.gd` | Filter species/backgrounds by DLC | Medium |
| `src/core/mission/MissionGenerator.gd` | Filter mission types by DLC | High |
| `src/core/enemy/EnemyGenerator.gd` | Filter elite enemies by DLC | Medium |
| `src/ui/screens/ShopSystem.gd` | Filter equipment by DLC, add badges | Medium |
| `src/game/world/WorldGeneration.gd` | Gate world traits by DLC | Low |
| `src/core/campaign/CampaignPhaseManager.gd` | Integrate DLC systems into phases | Medium |

**Medium Priority (DLC-Specific Systems):**

| File | Required Changes | Complexity |
|------|------------------|------------|
| `src/core/patrons/PatronSystem.gd` | Add salvage/stealth patron jobs | Medium |
| `src/core/battle/BattleResultsManager.gd` | Integrate DLC post-battle events | Low |
| `src/ui/screens/MainMenu.gd` | Add DLC store button, gate Bug Hunt | Low |
| `src/core/economy/TradingSystem.gd` | Filter DLC equipment from shop | Low |
| `src/core/systems/DiceSystem.gd` | No changes needed | None |

**New Files to Create:**

| File | Purpose | Dependencies |
|------|---------|--------------|
| `src/core/managers/ExpansionManager.gd` | Central DLC management | DLCManager |
| `src/core/dlc/PsionicSystem.gd` | Psionic power system | ExpansionManager |
| `src/core/dlc/StealthMissionSystem.gd` | Stealth mission mechanics | MissionGenerator |
| `src/core/dlc/SalvageJobSystem.gd` | Salvage job mechanics | MissionGenerator |
| `src/core/dlc/DifficultyScalingSystem.gd` | Combat difficulty system | BattleManager |
| `src/core/dlc/EliteEnemySystem.gd` | Elite enemy generation | EnemyGenerator |
| `src/core/dlc/LoanManager.gd` | Debt tracking system | EconomySystem |
| `src/core/dlc/FringeWorldStrifeSystem.gd` | World instability | WorldGeneration |
| `src/core/dlc/BugHuntCampaignManager.gd` | Bug Hunt campaign controller | CampaignManager |
| `src/core/dlc/PanicSystem.gd` | Bug Hunt panic mechanics | BattleManager |
| `src/ui/screens/DLCStore.tscn` | DLC purchase UI | DLCManager |
| `src/core/data/ContentFilter.gd` | Content filtering utility | ExpansionManager |

### 7.2 Code Pattern Examples

**Pattern 1: Content Loading with DLC Filtering**

```gdscript
# BEFORE (Mixed content)
func load_all_species() -> Array:
    return DataManager.load_json("res://data/RulesReference/SpeciesList.json")

# AFTER (Separated content)
func load_all_species() -> Array:
    return ExpansionManager.get_available_content("species")
```

**Pattern 2: Feature Gating in UI**

```gdscript
# BEFORE (No gating)
func _on_psionic_power_selected(power_index: int):
    selected_power = available_powers[power_index]
    _apply_psionic_power()

# AFTER (DLC gated)
func _on_psionic_power_selected(power_index: int):
    if not ExpansionManager.is_expansion_available("trailblazers_toolkit"):
        _show_dlc_required_popup("trailblazers_toolkit", "Psionic powers")
        return

    selected_power = available_powers[power_index]
    _apply_psionic_power()
```

**Pattern 3: Mission Generation with DLC**

```gdscript
# BEFORE (Hardcoded mission types)
func generate_mission_offers() -> Array:
    var missions = []
    missions.append(_generate_patrol_mission())
    missions.append(_generate_defense_mission())
    missions.append(_generate_salvage_mission())  # Should be DLC!
    return missions

# AFTER (DLC-aware)
func generate_mission_offers() -> Array:
    var missions = []

    # Core missions
    missions.append(_generate_patrol_mission())
    missions.append(_generate_defense_mission())

    # DLC missions
    if ExpansionManager.is_expansion_available("fixers_guidebook"):
        missions.append(_generate_salvage_mission())
        missions.append(_generate_stealth_mission())

    return missions
```

**Pattern 4: Equipment Shop Filtering**

```gdscript
# BEFORE (All equipment visible)
func populate_shop_inventory():
    var all_equipment = DataManager.load_json("res://data/RulesReference/EquipmentItems.json")

    for item in all_equipment:
        _add_shop_item(item)

# AFTER (DLC filtering + badges)
func populate_shop_inventory():
    var all_equipment = ExpansionManager.get_available_content("equipment")
    var filtered_equipment = ContentFilter.mark_dlc_items(all_equipment)

    for item in filtered_equipment:
        var shop_item = _add_shop_item(item)

        if item.get("is_dlc_content", false):
            # Add DLC badge
            var dlc_badge = Label.new()
            dlc_badge.text = "[" + item.dlc_display_name + "]"
            dlc_badge.add_theme_color_override("font_color", Color.GOLD)
            shop_item.add_child(dlc_badge)
```

---

## 8. Testing Strategy

### 8.1 Test Matrix

**DLC Ownership Combinations:**

| Test Case | TT | FH | FG | BH | Expected Behavior |
|-----------|----|----|----|----|-------------------|
| Base Game Only | ❌ | ❌ | ❌ | ❌ | Only core content visible |
| TT Only | ✅ | ❌ | ❌ | ❌ | Psionics, Krag, Skulker available |
| FH Only | ❌ | ✅ | ❌ | ❌ | Elite enemies, difficulty scaling |
| FG Only | ❌ | ❌ | ✅ | ❌ | Stealth, salvage, loans |
| BH Only | ❌ | ❌ | ❌ | ✅ | Bug Hunt mode only |
| TT + FH | ✅ | ✅ | ❌ | ❌ | Psionic + elite content |
| TT + FG | ✅ | ❌ | ✅ | ❌ | Psionic + stealth content |
| FH + FG | ❌ | ✅ | ✅ | ❌ | Elite + stealth content |
| TT + FH + FG | ✅ | ✅ | ✅ | ❌ | All DLC except Bug Hunt |
| Complete Compendium | ✅ | ✅ | ✅ | ✅ | Full content access |

*TT = Trailblazer's Toolkit, FH = Freelancer's Handbook, FG = Fixer's Guidebook, BH = Bug Hunt*

### 8.2 Test Scenarios

**Scenario 1: Character Creation (Base Game)**
1. Start new campaign
2. Open character creator
3. **Expected:** Only core species (Human, Swift, Soulless) visible
4. **Expected:** No psionic power option
5. Create character successfully

**Scenario 2: Character Creation (Trailblazer's Toolkit)**
1. Enable Trailblazer's Toolkit DLC
2. Start new campaign
3. Open character creator
4. **Expected:** Krag and Skulker species available
5. **Expected:** Psionic power selection available
6. Select Krag species
7. **Expected:** Character has -1" movement
8. Create character successfully

**Scenario 3: Mission Selection (Fixer's Guidebook)**
1. Enable Fixer's Guidebook DLC
2. Reach world phase
3. View mission offers
4. **Expected:** Stealth and salvage missions appear
5. Select stealth mission
6. **Expected:** Stealth mechanics active (detection, alarms)

**Scenario 4: DLC Purchase Flow**
1. Start with base game only
2. Attempt to select Krag species
3. **Expected:** "DLC Required" popup appears
4. Click "View in Store"
5. **Expected:** DLC store opens with Trailblazer's Toolkit highlighted
6. (Simulate purchase)
7. Return to character creator
8. **Expected:** Krag species now selectable

**Scenario 5: Mid-Campaign DLC Purchase**
1. Start campaign with base game
2. Play 5 turns
3. (Simulate Fixer's Guidebook purchase)
4. Continue campaign
5. **Expected:** Next world phase offers stealth/salvage missions
6. **Expected:** Loan system appears in finances screen
7. **Expected:** Existing save game loads correctly

**Scenario 6: Content Isolation**
1. Create campaign with all DLC enabled
2. Add Krag character, assign psionic powers
3. Equip psionic gear
4. Save campaign
5. (Simulate DLC uninstall)
6. Load campaign
7. **Expected:** Warning about missing DLC content
8. **Expected:** Krag character visible but cannot be edited
9. **Expected:** Psionic powers disabled
10. **Expected:** Campaign playable with core content

### 8.3 Automated Test Suite

**Unit Tests:**

```gdscript
# tests/unit/test_expansion_manager.gd
extends GdUnitTestSuite

func test_expansion_registration():
    assert_true(ExpansionManager.registered_expansions.has("trailblazers_toolkit"))
    assert_true(ExpansionManager.registered_expansions.has("freelancers_handbook"))
    assert_true(ExpansionManager.registered_expansions.has("fixers_guidebook"))
    assert_true(ExpansionManager.registered_expansions.has("bug_hunt"))

func test_dlc_ownership_check():
    # Simulate DLC not owned
    DLCManager.owned_dlcs["trailblazers_toolkit"] = false
    assert_false(ExpansionManager.is_expansion_available("trailblazers_toolkit"))

    # Simulate DLC owned
    DLCManager.owned_dlcs["trailblazers_toolkit"] = true
    assert_true(ExpansionManager.is_expansion_available("trailblazers_toolkit"))

func test_content_loading_core_only():
    # Disable all DLC
    for dlc_id in DLCManager.owned_dlcs.keys():
        DLCManager.owned_dlcs[dlc_id] = false

    var species = ExpansionManager.get_available_content("species")

    # Should only have core species
    assert_true(species.size() == 3)  # Human, Swift, Soulless
    assert_false(_has_species(species, "Krag"))
    assert_false(_has_species(species, "Skulker"))

func test_content_loading_with_dlc():
    # Enable Trailblazer's Toolkit
    DLCManager.owned_dlcs["trailblazers_toolkit"] = true

    var species = ExpansionManager.get_available_content("species")

    # Should have core + DLC species
    assert_true(species.size() == 5)  # Core + Krag + Skulker
    assert_true(_has_species(species, "Krag"))
    assert_true(_has_species(species, "Skulker"))

func _has_species(species_array: Array, species_name: String) -> bool:
    for species in species_array:
        if species.name == species_name:
            return true
    return false
```

**Integration Tests:**

```gdscript
# tests/integration/test_character_creation_dlc.gd
extends GdUnitTestSuite

func test_character_creation_dlc_gating():
    # Start with DLC disabled
    DLCManager.owned_dlcs["trailblazers_toolkit"] = false

    var char_creator = load("res://src/ui/screens/CharacterCreation.tscn").instantiate()
    add_child(char_creator)

    # Attempt to select Krag (should fail)
    var species_dropdown = char_creator.get_node("SpeciesDropdown")
    assert_false(_is_species_selectable(species_dropdown, "Krag"))

    # Enable DLC
    DLCManager.owned_dlcs["trailblazers_toolkit"] = true
    char_creator._populate_species_dropdown()

    # Krag should now be selectable
    assert_true(_is_species_selectable(species_dropdown, "Krag"))

func _is_species_selectable(dropdown: OptionButton, species_name: String) -> bool:
    for i in range(dropdown.get_item_count()):
        if species_name in dropdown.get_item_text(i):
            return not dropdown.is_item_disabled(i)
    return false
```

---

## 9. Monetization Strategy

### 9.1 Pricing Recommendations

| DLC | Suggested Price | Justification |
|-----|-----------------|---------------|
| **Trailblazer's Toolkit** | $4.99 | Character expansion, new subsystem (psionics) |
| **Freelancer's Handbook** | $6.99 | Major combat overhaul, high replay value |
| **Fixer's Guidebook** | $6.99 | 4 new mission types, campaign depth |
| **Bug Hunt** | $9.99 | Standalone campaign mode (most content) |
| **Complete Compendium Bundle** | $19.99 | 30% discount vs. individual ($28.96 total) |

### 9.2 Launch Strategy

**Phase 1: Core Game Launch**
- Release base game
- Include teaser content for DLC (locked previews)
- Announce DLC roadmap

**Phase 2: Early Adopter DLC (Month 1-2)**
- Release Trailblazer's Toolkit
- Launch discount: $3.99 (20% off)
- Build initial DLC revenue

**Phase 3: Major Expansion (Month 3-4)**
- Release Freelancer's Handbook + Fixer's Guidebook together
- Bundle discount: $11.99 (both)
- Cross-promote both DLC

**Phase 4: Standalone Campaign (Month 6)**
- Release Bug Hunt
- Market as separate campaign experience
- Offer bundle with base game for new players

**Phase 5: Complete Edition (Month 12)**
- Release Complete Compendium bundle
- "Game of the Year" marketing push
- Physical edition with all DLC included

### 9.3 Free Content Updates

**To maintain community goodwill:**

- Balance patches (always free)
- Bug fixes (always free)
- UI improvements (always free)
- 1-2 free minor content drops per year:
  - New character backgrounds (core)
  - Additional world events (core)
  - Quality of life features

**Differentiation:**
- **Free updates:** Quality of life, balance
- **Paid DLC:** New game systems, major content

---

## 10. Technical Specifications

### 10.1 File Size Estimates

| Content | Estimated Size |
|---------|---------------|
| **Core Game** | 150 MB |
| **Trailblazer's Toolkit** | 15 MB |
| **Freelancer's Handbook** | 20 MB |
| **Fixer's Guidebook** | 25 MB |
| **Bug Hunt** | 60 MB |
| **Total (All DLC)** | 270 MB |

### 10.2 Platform Requirements

**Desktop (Steam):**
- Steamworks SDK integration
- Steam DLC API
- Cloud save support for DLC content

**Mobile (Android/iOS):**
- Google Play Billing Library v5+
- Apple StoreKit 2
- In-app purchase restoration

**Compatibility:**
- DLC must work on all platforms
- Cross-platform save game support
- Unified DLC ownership across platforms (if possible)

### 10.3 Save Game Compatibility

**Versioning System:**

```gdscript
# SaveManager.gd enhancement

const SAVE_VERSION = "2.0.0"  # Include DLC support

func save_campaign(campaign: Campaign) -> bool:
    var save_data = {
        "version": SAVE_VERSION,
        "timestamp": Time.get_unix_time_from_system(),
        "dlc_manifest": _get_active_dlc_manifest(),
        "campaign_data": campaign.serialize()
    }

    # Save to file
    return _write_save_file(save_data)

func _get_active_dlc_manifest() -> Dictionary:
    return {
        "trailblazers_toolkit": DLCManager.is_dlc_owned("trailblazers_toolkit"),
        "freelancers_handbook": DLCManager.is_dlc_owned("freelancers_handbook"),
        "fixers_guidebook": DLCManager.is_dlc_owned("fixers_guidebook"),
        "bug_hunt": DLCManager.is_dlc_owned("bug_hunt")
    }

func load_campaign(save_file_path: String) -> Campaign:
    var save_data = _read_save_file(save_file_path)

    # Check DLC compatibility
    var saved_dlc = save_data.get("dlc_manifest", {})
    var current_dlc = _get_active_dlc_manifest()

    if not _is_dlc_compatible(saved_dlc, current_dlc):
        _show_dlc_warning(saved_dlc, current_dlc)

    return Campaign.deserialize(save_data.campaign_data)

func _is_dlc_compatible(saved: Dictionary, current: Dictionary) -> bool:
    # Check if any DLC content in save is not currently owned
    for dlc_id in saved.keys():
        if saved[dlc_id] and not current.get(dlc_id, false):
            return false

    return true

func _show_dlc_warning(saved: Dictionary, current: Dictionary):
    var missing_dlc = []

    for dlc_id in saved.keys():
        if saved[dlc_id] and not current.get(dlc_id, false):
            missing_dlc.append(DLCManager.DLC_PRODUCTS[dlc_id].display_name)

    var warning = "This save game includes content from:\n\n"
    for dlc_name in missing_dlc:
        warning += "• " + dlc_name + "\n"
    warning += "\nSome content may be unavailable or disabled."

    OS.alert(warning, "Missing DLC Content")
```

---

## 11. Success Metrics

### 11.1 KPIs to Track

**Sales Metrics:**
- DLC attach rate (% of base game owners who buy DLC)
- Average revenue per user (ARPU)
- Bundle vs. individual DLC sales ratio
- DLC revenue as % of total revenue

**Engagement Metrics:**
- DLC feature usage rates (% of DLC owners using features)
- Campaign completion rates (base vs. DLC content)
- DLC content playtime
- DLC refund rates

**Technical Metrics:**
- DLC loading performance
- Save game compatibility success rate
- Purchase flow completion rate
- Platform-specific purchase issues

### 11.2 Target Goals

**Year 1:**
- 40% DLC attach rate (at least one DLC per base game owner)
- 15% Complete Compendium adoption
- <2% refund rate
- 4.5+ star DLC reviews

**Revenue Targets:**
- DLC revenue = 60% of total revenue
- Bug Hunt = 35% of DLC revenue
- Other DLC = 65% of DLC revenue

---

## 12. Risk Mitigation

### 12.1 Identified Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| **DLC content leakage** | High | Rigorous testing, content filtering, code review |
| **Save game corruption** | High | Robust versioning, DLC manifest, graceful degradation |
| **Platform purchase failures** | Medium | Retry logic, clear error messages, support documentation |
| **Player backlash (content gating)** | Medium | Clear communication, generous free updates, fair pricing |
| **Cross-DLC bugs** | Medium | Comprehensive test matrix, beta testing |
| **Performance issues** | Low | Profiling, lazy loading, asset optimization |

### 12.2 Contingency Plans

**If DLC sales underperform:**
- Run promotional discounts
- Bundle DLC with base game sales
- Release free "lite" version of DLC features
- Adjust pricing strategy

**If technical issues arise:**
- Rollback capability for DLC updates
- Emergency hotfix process
- Clear player communication
- Compensation for affected players (free DLC, refunds)

---

## 13. Next Steps

### Immediate Actions (This Week)

1. **Review this document** with stakeholders
2. **Approve architecture** and implementation plan
3. **Set up development environment** with DLC testing flags
4. **Create project board** with all tasks from roadmap
5. **Begin Phase 1** (Data Separation)

### Decision Points

**Decisions Needed:**
- [ ] Final DLC pricing approval
- [ ] Platform priority (Steam first vs. multi-platform)
- [ ] Beta testing scope and timeline
- [ ] Marketing budget and strategy
- [ ] Bug Hunt release timing (with other DLC or separate?)

### Resources Required

**Development:**
- 1 senior developer (18-20 weeks full-time)
- 1 junior developer (testing support)
- 1 UI/UX designer (DLC store, prompts)

**QA:**
- 1 QA engineer (testing all DLC combinations)
- Beta testing community (50-100 players)

**External:**
- Platform store setup (Steam, Google Play, Apple)
- Marketing materials (trailers, screenshots)
- Legal review (DLC terms, pricing)

---

## 14. Conclusion

This expansion add-on architecture provides a comprehensive, modular approach to integrating Five Parsecs' rich compendium content as purchasable DLC. The system is designed to:

✅ **Maximize player value** through fair pricing and meaningful content
✅ **Ensure technical stability** via robust gating and testing
✅ **Support long-term growth** through modular, extensible architecture
✅ **Respect base game owners** with generous free updates
✅ **Generate sustainable revenue** through compelling expansion content

**Total Implementation Time:** 18-20 weeks
**Estimated DLC Revenue Potential:** 60% of total game revenue
**Technical Risk Level:** Medium (mitigated through comprehensive testing)

---

**Document Status:** Draft v1.0 - Awaiting Review
**Next Review Date:** TBD
**Approval Required From:** Project Lead, Technical Director, Business Manager

---

*End of Planning Document*
