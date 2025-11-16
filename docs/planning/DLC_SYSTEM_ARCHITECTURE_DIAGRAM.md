# DLC System Architecture Diagram

**Visual representation of the Five Parsecs DLC system**

---

## System Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         PLAYER EXPERIENCE                            │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                          UI LAYER                                    │
├─────────────────────────────────────────────────────────────────────┤
│  Main Menu │ Character Creator │ Mission Select │ Shop │ DLC Store  │
│                                                                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐              │
│  │ Core Content │  │ DLC Content  │  │ Locked       │              │
│  │ (Always On)  │  │ (If Owned)   │  │ (🔒 Badge)   │              │
│  └──────────────┘  └──────────────┘  └──────────────┘              │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      CONTENT MANAGERS                                │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│   ┌──────────────────────────────────────────────────────┐          │
│   │           EXPANSION MANAGER (Singleton)              │          │
│   ├──────────────────────────────────────────────────────┤          │
│   │  • Registers all expansions                          │          │
│   │  • Routes content requests                           │          │
│   │  • Merges core + DLC content                         │          │
│   │  • Validates ownership                               │          │
│   └──────────────────────┬───────────────────────────────┘          │
│                          │                                           │
│            ┌─────────────┼─────────────┐                            │
│            ▼             ▼             ▼                            │
│   ┌────────────┐ ┌────────────┐ ┌────────────┐                     │
│   │   Core     │ │    DLC     │ │  Content   │                     │
│   │  Loader    │ │  Loader    │ │  Filter    │                     │
│   └────────────┘ └────────────┘ └────────────┘                     │
│                                                                       │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                       DLC VERIFICATION                               │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│   ┌──────────────────────────────────────────────────────┐          │
│   │             DLC MANAGER (Singleton)                  │          │
│   ├──────────────────────────────────────────────────────┤          │
│   │  • Checks ownership per DLC                          │          │
│   │  • Platform integration (Steam/Play/AppStore)        │          │
│   │  • Purchase flow management                          │          │
│   │  • Development overrides                             │          │
│   └──────────────────────┬───────────────────────────────┘          │
│                          │                                           │
│            ┌─────────────┼─────────────┐                            │
│            ▼             ▼             ▼                            │
│     ┌───────────┐ ┌───────────┐ ┌───────────┐                      │
│     │  Steam    │ │  Google   │ │   Apple   │                      │
│     │   API     │ │   Play    │ │  StoreKit │                      │
│     └───────────┘ └───────────┘ └───────────┘                      │
│                                                                       │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                          DATA LAYER                                  │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  ┌────────────────────┐  ┌──────────────────────────────────┐      │
│  │   CORE RULES       │  │      DLC EXPANSIONS              │      │
│  ├────────────────────┤  ├──────────────────────────────────┤      │
│  │ /core_rules/       │  │ /dlc_trailblazers_toolkit/       │      │
│  │  • core_species    │  │  • expanded_species.json         │      │
│  │  • core_enemies    │  │  • psionic_powers.json           │      │
│  │  • core_equipment  │  │  • psionic_equipment.json        │      │
│  │  • core_missions   │  │                                  │      │
│  │                    │  │ /dlc_freelancers_handbook/       │      │
│  │                    │  │  • elite_enemies.json            │      │
│  │                    │  │  • difficulty_modifiers.json     │      │
│  │                    │  │                                  │      │
│  │                    │  │ /dlc_fixers_guidebook/           │      │
│  │                    │  │  • stealth_missions.json         │      │
│  │                    │  │  • salvage_jobs.json             │      │
│  │                    │  │  • loans_system.json             │      │
│  │                    │  │                                  │      │
│  │                    │  │ /dlc_bug_hunt/                   │      │
│  │                    │  │  • bug_enemies.json              │      │
│  │                    │  │  • military_equipment.json       │      │
│  └────────────────────┘  └──────────────────────────────────┘      │
│                                                                       │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Content Flow Diagram

```
PLAYER REQUESTS CONTENT (e.g., "Get all species")
    │
    ▼
┌───────────────────────┐
│  UI Component         │
│  (CharacterCreator)   │
└───────┬───────────────┘
        │
        │ ExpansionManager.get_available_content("species")
        ▼
┌───────────────────────┐
│  ExpansionManager     │
│                       │
│  1. Load core content │────────┐
│  2. Check DLC owned   │        │
│  3. Load DLC content  │        │
│  4. Merge & return    │        │
└───────┬───────────────┘        │
        │                        │
        │ DLCManager.is_dlc_owned("trailblazers_toolkit")?
        ▼                        │
┌───────────────────────┐        │
│  DLCManager           │        │
│                       │        │
│  Check ownership:     │        │
│  ✅ Owned  → return   │        │
│  ❌ Not owned → skip  │        │
└───────────────────────┘        │
                                 │
                                 ▼
                        ┌────────────────────┐
                        │  DataManager       │
                        │                    │
                        │  Load JSON:        │
                        │  core_species.json │
                        │  + (if owned)      │
                        │  expanded_species  │
                        └────────┬───────────┘
                                 │
                                 ▼
                        ┌────────────────────┐
                        │  ContentFilter     │
                        │                    │
                        │  Filter by DLC     │
                        │  ownership         │
                        └────────┬───────────┘
                                 │
                                 ▼
                        ┌────────────────────┐
                        │  RETURN TO UI      │
                        │                    │
                        │  [Human, Swift,    │
                        │   Soulless, Krag,  │
                        │   Skulker]         │
                        └────────────────────┘
```

---

## DLC Ownership Decision Tree

```
USER ATTEMPTS TO SELECT KRAG SPECIES
    │
    ▼
┌─────────────────────────────────────┐
│ Is "trailblazers_toolkit" owned?    │
└─────────┬───────────────────┬───────┘
          │                   │
        YES                  NO
          │                   │
          ▼                   ▼
┌─────────────────┐  ┌──────────────────────┐
│ Allow selection │  │ Show DLC prompt      │
│ Apply Krag      │  │                      │
│ special rules   │  │ "Requires            │
│ (-1" movement)  │  │  Trailblazer's       │
│                 │  │  Toolkit"            │
└─────────────────┘  │                      │
                     │ [View in Store] [OK] │
                     └──────┬───────────────┘
                            │
                            ▼ (if clicked View)
                     ┌──────────────────────┐
                     │ Open DLC Store       │
                     │ Highlight TT DLC     │
                     │ Show price ($4.99)   │
                     └──────┬───────────────┘
                            │
                            ▼ (if purchased)
                     ┌──────────────────────┐
                     │ Platform Purchase    │
                     │ (Steam/Play/Apple)   │
                     └──────┬───────────────┘
                            │
                            ▼
                     ┌──────────────────────┐
                     │ DLCManager updates   │
                     │ ownership status     │
                     └──────┬───────────────┘
                            │
                            ▼
                     ┌──────────────────────┐
                     │ Content now          │
                     │ accessible!          │
                     └──────────────────────┘
```

---

## Expansion Registration System

```
GAME STARTUP
    │
    ▼
┌────────────────────────────────────────────────────────┐
│  ExpansionManager._ready()                             │
└────┬───────────────────────────────────────────────────┘
     │
     ├─► register_expansion("trailblazers_toolkit", {
     │       "name": "Trailblazer's Toolkit",
     │       "data_path": "res://data/dlc_trailblazers_toolkit/",
     │       "systems": ["PsionicSystem", "ExpandedSpeciesSystem"],
     │       "content_types": ["species", "powers", "equipment"]
     │   })
     │
     ├─► register_expansion("freelancers_handbook", {
     │       "name": "Freelancer's Handbook",
     │       "data_path": "res://data/dlc_freelancers_handbook/",
     │       "systems": ["EliteEnemySystem", "DifficultyScalingSystem"],
     │       "content_types": ["enemies", "combat_rules"]
     │   })
     │
     ├─► register_expansion("fixers_guidebook", {
     │       "name": "Fixer's Guidebook",
     │       "data_path": "res://data/dlc_fixers_guidebook/",
     │       "systems": ["StealthMissionSystem", "SalvageJobSystem"],
     │       "content_types": ["missions", "world_events"]
     │   })
     │
     └─► register_expansion("bug_hunt", {
             "name": "Bug Hunt",
             "data_path": "res://data/dlc_bug_hunt/",
             "systems": ["BugHuntCampaignManager"],
             "content_types": ["campaign_mode", "enemies"],
             "standalone": true
         })

REGISTERED EXPANSIONS AVAILABLE
    │
    ▼
All game systems can now query:
• ExpansionManager.is_expansion_available("dlc_id")
• ExpansionManager.get_available_content("content_type")
• ExpansionManager.load_expansion_data("dlc_id", "file.json")
```

---

## Save Game Integration

```
SAVING CAMPAIGN
    │
    ▼
┌─────────────────────────────────────┐
│ SaveManager.save_campaign()         │
└─────┬───────────────────────────────┘
      │
      ├─► Capture DLC manifest:
      │   {
      │     "trailblazers_toolkit": true,
      │     "freelancers_handbook": false,
      │     "fixers_guidebook": true,
      │     "bug_hunt": false
      │   }
      │
      └─► Save data:
          {
            "version": "2.0.0",
            "dlc_manifest": {...},
            "campaign_data": {
              "crew": [
                {
                  "species": "Krag",          ← DLC content
                  "psionic_powers": ["Barrier"] ← DLC content
                }
              ]
            }
          }

LOADING CAMPAIGN
    │
    ▼
┌─────────────────────────────────────┐
│ SaveManager.load_campaign()         │
└─────┬───────────────────────────────┘
      │
      ├─► Load DLC manifest from save
      │
      ├─► Compare with current ownership:
      │   Saved: TT=✅, FH=❌, FG=✅, BH=❌
      │   Current: TT=✅, FH=❌, FG=❌, BH=❌
      │                            ↑ MISMATCH!
      │
      ├─► If mismatch detected:
      │   Show warning: "This save uses Fixer's Guidebook content.
      │                  Some features may be unavailable."
      │
      └─► Load campaign (gracefully handle missing DLC)
          • Krag character loads OK (TT owned)
          • Psionic powers work (TT owned)
          • Loans system disabled (FG not owned)
          • Salvage missions hidden (FG not owned)
```

---

## Mission Generation Flow (With DLC)

```
WORLD PHASE: Generate Mission Offers
    │
    ▼
┌────────────────────────────────────┐
│ MissionGenerator.generate_offers() │
└────┬───────────────────────────────┘
     │
     ├─► CORE MISSIONS (Always)
     │   ├─► Patrol mission
     │   ├─► Defense mission
     │   └─► Basic patron job
     │
     ├─► Check Fixer's Guidebook owned?
     │   │
     │   ├─► YES → Add DLC missions:
     │   │   ├─► Stealth mission (StealthMissionSystem.generate())
     │   │   ├─► Salvage job (SalvageJobSystem.generate())
     │   │   └─► Street fight (UrbanCombatSystem.generate())
     │   │
     │   └─► NO → Skip DLC missions
     │
     └─► RETURN: [Patrol, Defense, Patron, Stealth, Salvage, Street]
                                           ↑DLC↑    ↑DLC↑  ↑DLC↑
```

---

## Character Creation Flow (Species Selection)

```
CHARACTER CREATOR OPENED
    │
    ▼
┌───────────────────────────────────────────┐
│ CharacterCreation._populate_species()     │
└───────┬───────────────────────────────────┘
        │
        ├─► Get available species:
        │   ExpansionManager.get_available_content("species")
        │
        ▼
┌───────────────────────────────────────────┐
│ ExpansionManager loads:                   │
│                                            │
│ CORE:  [Human, Swift, Soulless]           │
│                                            │
│ IF TT owned: [Krag, Skulker]              │
│ IF BH owned: [] (no species in Bug Hunt)  │
└───────┬───────────────────────────────────┘
        │
        ▼
┌───────────────────────────────────────────┐
│ For each species in list:                 │
│                                            │
│ IF "dlc_required" in species:             │
│   ├─► Check DLCManager.is_dlc_owned()    │
│   │                                        │
│   ├─► Owned? → Add to dropdown            │
│   │   "Krag"                               │
│   │                                        │
│   └─► Not owned? → Add with 🔒 badge      │
│       "Krag 🔒 (Requires TT)"              │
│       └─ Disabled = true                  │
│                                            │
│ ELSE (core species):                      │
│   └─► Add to dropdown (always enabled)   │
│       "Human"                              │
└───────────────────────────────────────────┘
```

---

## Combat Setup Flow (Difficulty Options)

```
COMBAT SETUP SCREEN
    │
    ▼
┌────────────────────────────────────────┐
│ BattleSetup._ready()                   │
└────┬───────────────────────────────────┘
     │
     ├─► Show CORE options (always):
     │   • Select enemy type
     │   • Set battlefield terrain
     │   • Choose deployment zone
     │
     └─► Check Freelancer's Handbook owned?
         │
         ├─► YES → Show ADVANCED section:
         │   │
         │   ├─► [✓] Brutal Foes (+1 toughness)
         │   ├─► [✓] Larger Battles (+25% DP)
         │   ├─► [ ] Veteran Opposition (+1 skill)
         │   ├─► [ ] Elite Foes (use elite types)
         │   └─► ... (8 total difficulty toggles)
         │
         └─► NO → Show locked section:
             │
             └─► "⚔ Advanced Options 🔒"
                 "Requires Freelancer's Handbook"
                 [View in Store]
```

---

## Shop Equipment Flow (With DLC Filtering)

```
SHOP OPENED
    │
    ▼
┌────────────────────────────────────┐
│ ShopSystem.populate_inventory()    │
└────┬───────────────────────────────┘
     │
     ├─► Get all equipment:
     │   ExpansionManager.get_available_content("equipment")
     │
     ▼
┌──────────────────────────────────────────────────────┐
│ Loaded equipment (with ownership filtering):         │
│                                                       │
│ CORE (always visible):                               │
│  • Handgun      [100 cr]                             │
│  • Rifle        [300 cr]                             │
│  • Battle Armor [500 cr]                             │
│                                                       │
│ DLC (if TT owned):                                   │
│  • Psi-Amp 🌟   [800 cr] [Trailblazer's Toolkit]     │
│                                                       │
│ DLC (if BH owned):                                   │
│  • Pulse Rifle 🌟 [1200 cr] [Bug Hunt]               │
│  • Motion Tracker 🌟 [600 cr] [Bug Hunt]             │
│                                                       │
│ DLC (if FG owned):                                   │
│  • Stealth Suit 🌟 [900 cr] [Fixer's Guidebook]      │
└──────────────────────────────────────────────────────┘
     │
     └─► UI Rendering:
         • Core items: standard display
         • DLC items: gold 🌟 badge + DLC name label
         • Player can purchase any visible item
```

---

## Platform Purchase Flow

```
USER CLICKS "Buy Trailblazer's Toolkit"
    │
    ▼
┌─────────────────────────────────────┐
│ DLCManager.purchase_dlc(            │
│   "trailblazers_toolkit"            │
│ )                                    │
└────┬────────────────────────────────┘
     │
     ├─► Detect platform:
     │   OS.get_name()
     │
     ├─────┬──────────┬─────────┐
     │     │          │         │
   Steam  Android   iOS    Desktop
     │     │          │         │
     ▼     ▼          ▼         ▼
┌─────────────────────────────────────────────────────┐
│ STEAM:                                              │
│  Steam.activateGameOverlayToStore("1234560")        │
│    │                                                 │
│    └─► User completes purchase in Steam overlay     │
│        └─► Steamworks callback: DLC now owned       │
│                                                      │
│ ANDROID:                                            │
│  GooglePlayBilling.purchaseDLC("com.fiveparsecs...") │
│    │                                                 │
│    └─► User completes Google Play purchase          │
│        └─► Billing callback: DLC now owned          │
│                                                      │
│ iOS:                                                │
│  StoreKit.purchaseProduct("fiveparsecs.dlc...")     │
│    │                                                 │
│    └─► User completes App Store purchase            │
│        └─► StoreKit callback: DLC now owned         │
│                                                      │
│ DESKTOP (non-Steam):                                │
│  Open browser to DLC store page                     │
│  Manual license key entry                           │
└─────────────────────────────────────────────────────┘
     │
     ▼
┌─────────────────────────────────────┐
│ DLCManager receives purchase        │
│ confirmation                         │
└────┬────────────────────────────────┘
     │
     ├─► Update owned_dlcs:
     │   owned_dlcs["trailblazers_toolkit"] = true
     │
     ├─► Emit signal:
     │   dlc_ownership_changed.emit("trailblazers_toolkit", true)
     │
     └─► Save to disk (persistent ownership)
         │
         ▼
┌─────────────────────────────────────┐
│ Game systems listen for signal:     │
│                                      │
│ • CharacterCreation refreshes UI    │
│ • Shop restocks with DLC items      │
│ • Mission generator adds DLC types  │
│                                      │
│ User can now access Krag/Skulker,   │
│ psionic powers, and DLC equipment!  │
└─────────────────────────────────────┘
```

---

## Bug Hunt Standalone Mode

```
MAIN MENU
    │
    ├─► [New Campaign] ──► Five Parsecs (Core game)
    │
    └─► [Bug Hunt] ───┬─► Is "bug_hunt" DLC owned?
                      │
                    YES
                      │
                      ▼
              ┌───────────────────────┐
              │ Bug Hunt Main Menu    │
              ├───────────────────────┤
              │ • New Campaign        │ ──► BugHuntCampaignManager
              │ • Continue            │
              │ • Options             │
              │ • Transfer Character  │ ──► CharacterTransferSystem
              │ • Back                │
              └───────────────────────┘
                      │
                      ├─► New Campaign selected
                      │
                      ▼
              ┌───────────────────────┐
              │ Bug Hunt Campaign     │
              ├───────────────────────┤
              │ PHASES:               │
              │ 1. Deployment Phase   │ ← Assign soldiers
              │ 2. Tactical Phase     │ ← Bug combat
              │ 3. Post-Action Phase  │ ← Casualties
              │ 4. Base Phase         │ ← Resupply
              └───────────────────────┘

                     NO (DLC not owned)
                      │
                      ▼
              ┌───────────────────────┐
              │ DLC Required Popup    │
              ├───────────────────────┤
              │ Bug Hunt requires     │
              │ the Bug Hunt DLC      │
              │ ($9.99)               │
              │                       │
              │ [View in Store] [OK]  │
              └───────────────────────┘
```

---

## Class Hierarchy

```
                    ┌──────────────┐
                    │ Node (Godot) │
                    └──────┬───────┘
                           │
         ┌─────────────────┼─────────────────┐
         │                 │                 │
         ▼                 ▼                 ▼
┌─────────────────┐ ┌──────────────┐ ┌─────────────┐
│ ExpansionManager│ │ DLCManager   │ │ DataManager │
│ (Singleton)     │ │ (Singleton)  │ │ (Singleton) │
└─────────────────┘ └──────────────┘ └─────────────┘
         │
         ├─► Uses DLCManager for ownership checks
         ├─► Uses DataManager for file loading
         └─► Provides content to game systems
                           │
         ┌─────────────────┼─────────────────────────┐
         │                 │                         │
         ▼                 ▼                         ▼
┌──────────────────┐ ┌──────────────┐ ┌──────────────────────┐
│ PsionicSystem    │ │ StealthMission│ │ EliteEnemySystem     │
│ (DLC: TT)        │ │ System        │ │ (DLC: FH)            │
│                  │ │ (DLC: FG)     │ │                      │
└──────────────────┘ └──────────────┘ └──────────────────────┘
         │
         └─► All DLC systems check:
             ExpansionManager.is_expansion_available()
             before executing DLC-specific logic
```

---

## Data Structure: JSON Content with DLC Tags

```json
// EXAMPLE: core_rules/core_species.json
[
  {
    "name": "Human",
    "source": "core",
    "description": "Versatile and adaptable",
    "stat_modifiers": {}
  },
  {
    "name": "Swift",
    "source": "core",
    "description": "Fast and agile",
    "stat_modifiers": {
      "movement": +1
    }
  }
]

// EXAMPLE: dlc_trailblazers_toolkit/expanded_species.json
[
  {
    "name": "Krag",
    "source": "trailblazers_toolkit",
    "dlc_required": "trailblazers_toolkit",
    "description": "Stocky, belligerent humanoids",
    "stat_modifiers": {
      "movement": -1,
      "toughness": +1
    }
  },
  {
    "name": "Skulker",
    "source": "trailblazers_toolkit",
    "dlc_required": "trailblazers_toolkit",
    "description": "Agile rodent-like aliens",
    "stat_modifiers": {
      "movement": +1
    },
    "special_abilities": ["biological_resistance"]
  }
]
```

---

## Security: DLC Verification Chain

```
CONTENT ACCESS ATTEMPT
    │
    ▼
┌─────────────────────────────────────┐
│ 1. UI Request                       │
│    "User wants to equip Psi-Amp"    │
└────┬────────────────────────────────┘
     │
     ▼
┌─────────────────────────────────────┐
│ 2. Check item.dlc_required          │
│    psi_amp.dlc_required =           │
│    "trailblazers_toolkit"           │
└────┬────────────────────────────────┘
     │
     ▼
┌─────────────────────────────────────┐
│ 3. ExpansionManager verification    │
│    is_expansion_available("TT")?    │
└────┬────────────────────────────────┘
     │
     ▼
┌─────────────────────────────────────┐
│ 4. DLCManager ownership check       │
│    is_dlc_owned("TT")?              │
└────┬────────────────────────────────┘
     │
     ├─────────┬──────────┐
     │         │          │
   Platform  Bundle   Dev Override
   Specific   Check    Check
     │         │          │
     ▼         ▼          ▼
┌──────────────────────────────────────┐
│ • Steam: Check Steamworks API        │
│ • Android: Check Google Play receipt │
│ • iOS: Check StoreKit receipt        │
│ • Bundle: Check if "complete_        │
│   compendium" owned (includes TT)    │
│ • Dev: Check editor flag              │
└───────┬──────────────────────────────┘
        │
        ├─► VERIFIED ✅
        │   └─► Allow equip
        │
        └─► NOT VERIFIED ❌
            └─► Show DLC prompt
                "Requires Trailblazer's Toolkit"
```

---

## Performance Optimization

```
LAZY LOADING STRATEGY
    │
    ▼
┌──────────────────────────────────────┐
│ GAME STARTUP                         │
├──────────────────────────────────────┤
│ • Load core data only                │
│ • Register expansion metadata        │
│ • Check DLC ownership (async)        │
│ • DO NOT load DLC data yet           │
└───────┬──────────────────────────────┘
        │
        ▼
┌──────────────────────────────────────┐
│ ON-DEMAND LOADING                    │
├──────────────────────────────────────┤
│ User opens Character Creator:        │
│  └─► Load species data               │
│      (core + owned DLC only)         │
│                                       │
│ User opens Shop:                     │
│  └─► Load equipment data             │
│      (core + owned DLC only)         │
│                                       │
│ User selects mission:                │
│  └─► Load mission-specific data      │
│      (only needed DLC)               │
└──────────────────────────────────────┘

CACHING STRATEGY
    │
    ▼
┌──────────────────────────────────────┐
│ ExpansionManager maintains cache:    │
│                                       │
│ var content_cache = {                │
│   "species": [...],  # Cached        │
│   "equipment": [...], # Cached       │
│   "enemies": null    # Not loaded    │
│ }                                     │
│                                       │
│ • Cache invalidated on DLC purchase  │
│ • Cache persists during session      │
│ • Reduces file I/O                   │
└──────────────────────────────────────┘
```

---

## Error Handling Flow

```
GRACEFUL DEGRADATION
    │
    ▼
┌──────────────────────────────────────┐
│ SCENARIO: Save has DLC content,      │
│ but DLC no longer owned              │
└───────┬──────────────────────────────┘
        │
        ▼
┌──────────────────────────────────────┐
│ Load Save File                       │
│  Campaign has:                       │
│  • 1 Krag character (TT DLC)         │
│  • Psi-Amp equipped (TT DLC)         │
│  • Stealth mission active (FG DLC)   │
│                                       │
│ Current ownership:                   │
│  • TT: NOT OWNED ❌                  │
│  • FG: NOT OWNED ❌                  │
└───────┬──────────────────────────────┘
        │
        ▼
┌──────────────────────────────────────┐
│ DEGRADATION STRATEGY                 │
│                                       │
│ 1. Show warning to player            │
│    "Missing DLC content detected"    │
│                                       │
│ 2. Krag character:                   │
│    • Keep in roster (read-only)      │
│    • Cannot be edited                │
│    • Stats still apply in combat     │
│    • Visual badge: "DLC Character"   │
│                                       │
│ 3. Psi-Amp equipment:                │
│    • Remains equipped                │
│    • Cannot be re-equipped if removed│
│    • Still provides bonuses          │
│                                       │
│ 4. Stealth mission:                  │
│    • Convert to basic patrol mission │
│    • Notify player of change         │
│    • OR: Skip mission (player choice)│
│                                       │
│ 5. Future content:                   │
│    • No new DLC content accessible   │
│    • DLC features disabled           │
│    • Prompts to re-purchase DLC      │
└──────────────────────────────────────┘
```

---

## Summary: Key Architecture Principles

1. **Separation of Concerns**
   - Core game vs DLC content strictly separated
   - Each DLC is independent module

2. **Ownership Verification**
   - Multiple verification layers (UI → Manager → Platform)
   - Platform-specific API integration

3. **Graceful Degradation**
   - Game playable without DLC
   - Missing DLC content handled gracefully

4. **Content Filtering**
   - Dynamic filtering based on ownership
   - UI always reflects current access

5. **Modularity**
   - DLC systems are pluggable
   - Easy to add new expansions

6. **Performance**
   - Lazy loading
   - Content caching
   - Only load owned DLC data

7. **User Experience**
   - Clear DLC indicators (🔒, 🌟)
   - Helpful prompts
   - Easy purchase flow

---

**Document Version:** 1.0
**Architecture Status:** Proposed
**Implementation:** Pending approval

---

*This diagram should be referenced during all DLC implementation work.*
