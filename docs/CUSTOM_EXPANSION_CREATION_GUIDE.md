# Custom Expansion Creation Guide

**Version**: 1.0
**Last Updated**: 2024-11-16
**Audience**: Modders, expansion creators, advanced content creators

---

## Table of Contents

1. [Overview](#overview)
2. [Expansion Planning](#expansion-planning)
3. [Setting Up Your Expansion](#setting-up-your-expansion)
4. [Creating the Expansion Manifest](#creating-the-expansion-manifest)
5. [Building Specialized Systems](#building-specialized-systems)
6. [Creating Content Data Files](#creating-content-data-files)
7. [Integration with Core Systems](#integration-with-core-systems)
8. [Testing Your Expansion](#testing-your-expansion)
9. [Publishing and Distribution](#publishing-and-distribution)
10. [Complete Example: "Void Raiders" Expansion](#complete-example-void-raiders-expansion)
11. [Advanced Topics](#advanced-topics)
12. [Troubleshooting](#troubleshooting)

---

## Overview

This guide teaches you how to create complete expansion packs for the Five Parsecs Campaign Manager. You'll learn how to design, implement, and publish professional-quality expansions following the same patterns as official DLC.

### What is an Expansion?

An expansion is a **modular content pack** that adds new features, content, and systems to the game. Expansions can include:

- **New Content**: Species, powers, enemies, equipment, missions
- **Specialized Systems**: Custom game mechanics (stealth, difficulty scaling, etc.)
- **Campaign Modes**: Alternative ways to play (like Bug Hunt)
- **Quality of Life**: UI improvements, tools, utilities

### Design Philosophy

**90% Code Reuse**: Official expansions reuse 90% of core systems, adding only specialized overlays. Your expansion should follow this pattern.

**Data-Driven**: Content defined in JSON files, not hardcoded in scripts.

**Modular**: Can be enabled/disabled independently of other expansions.

**Non-Breaking**: Doesn't modify core systems, only extends them.

### Expansion Types

| Type | Description | Examples | Complexity |
|------|-------------|----------|------------|
| **Content Pack** | Only JSON data, no code | New species, enemies, equipment | Low |
| **Mechanic Expansion** | New systems + content | Stealth missions, psionic powers | Medium |
| **Campaign Mode** | Alternative campaign with specialized systems | Bug Hunt | High |
| **Total Conversion** | Completely new setting/rules | Future project | Very High |

This guide focuses on **Content Packs** and **Mechanic Expansions**.

---

## Expansion Planning

### Step 1: Concept and Theme

**Questions to answer**:

1. **What is your expansion about?**
   - Theme (pirates, aliens, psionics, corporate warfare, etc.)
   - Unique selling point (what makes it different?)

2. **What content will it include?**
   - Species (how many? what archetypes?)
   - Enemies (standard or elite?)
   - Equipment (weapons, gear, special items?)
   - Missions (what types? any special mechanics?)

3. **Will it need custom systems?**
   - Can you achieve your goals with existing systems?
   - Do you need specialized mechanics?

**Example: "Void Raiders" Expansion**
- **Theme**: Space piracy and smuggling
- **USP**: Reputation system, black market trading
- **Content**: 2 species (pirate races), 4 elite enemies (pirate leaders), 8 weapons, 6 missions
- **Systems**: Reputation system, black market system

### Step 2: Content Design

Create design documents for each content type.

**Species Design Template**:
```markdown
## Species: [Name]

**Concept**: [1-2 sentence description]
**Homeworld**: [Planet/system]
**Culture**: [Key traits]

**Stat Modifications** (net-zero):
- Reactions: [+/-X]
- Speed: [+/-X"]
- Combat Skill: [+/-X]
- Toughness: [+/-X]
- Savvy: [+/-X]
- **Total**: 0

**Special Rules** (2-3):
1. [Rule Name]: [Effect]
2. [Rule Name]: [Effect]

**Balance**: [Explain how this species is balanced]
```

**Mission Design Template**:
```markdown
## Mission: [Name]

**Type**: [Mission type]
**Theme**: [Setting/scenario]

**Objectives** (1-3):
1. [Objective]: [Success condition]

**Special Mechanics** (if any):
- [Mechanic]: [How it works]

**Deployment**:
- Enemies: [Count and types]
- Terrain: [Requirements]
- Special Rules: [Any modifications]

**Rewards**:
- Credits: [Range]
- Loot: [Rolls]
- Special: [Unique rewards]
```

**Elite Enemy Design Template**:
```markdown
## Elite Enemy: [Name]

**Base Type**: [Standard enemy]
**Concept**: [What makes them elite?]

**Stats**:
- Combat Skill: [+X] (was [+Y])
- Toughness: [X] (was [Y])
- Speed: [X"] (was [Y"])
- Reactions: [X] (was [Y])

**Abilities** (2-3):
1. [Ability]: [Effect]

**Deployment Points**: [X] (calculated via formula)

**Tactics**: [How they fight]
```

### Step 3: System Design (if needed)

If your expansion requires custom systems, design them before implementation.

**System Design Template**:
```markdown
## System: [Name]System

**Purpose**: [What problem does this solve?]
**Integration**: [How does it connect to core?]

**Core Mechanics**:
1. [Mechanic]: [How it works]

**Data Requirements**:
- [What JSON files needed?]

**Signals** (events emitted):
- `signal_name(params)`: [When emitted]

**Public Methods**:
- `method_name(params) -> return`: [What it does]

**Integration Points**:
- [Where does it hook into core systems?]
```

### Step 4: Scope and Timeline

Estimate your work:

| Task | Time Estimate |
|------|---------------|
| Design documentation | 1-3 days |
| JSON content creation | 2-5 days |
| Custom system implementation | 5-10 days (if needed) |
| Testing and balancing | 3-7 days |
| Documentation | 2-4 days |
| **Total** | **2-4 weeks** |

**Tip**: Start small. A content pack with 2 species, 3 enemies, and 5 weapons is a great first expansion.

---

## Setting Up Your Expansion

### Directory Structure

Create your expansion directory following the official pattern:

```
data/
└── dlc/
    └── your_expansion_name/           # Use snake_case, no spaces
        ├── manifest.json               # Required: Expansion metadata
        ├── your_expansion_species.json # Optional: Species data
        ├── your_expansion_enemies.json # Optional: Enemy data
        ├── your_expansion_equipment.json # Optional: Equipment data
        ├── your_expansion_missions.json # Optional: Mission data
        └── README.md                   # Optional: Documentation
```

**Example: Void Raiders**

```
data/
└── dlc/
    └── void_raiders/
        ├── manifest.json
        ├── void_raiders_species.json
        ├── void_raiders_elite_enemies.json
        ├── void_raiders_weapons.json
        ├── void_raiders_gear.json
        ├── void_raiders_missions.json
        ├── void_raiders_reputation.json
        └── README.md
```

### Naming Conventions

**Directory Name**:
- Use `snake_case` (lowercase with underscores)
- No spaces, no special characters
- Examples: `void_raiders`, `corporate_wars`, `alien_invasion`

**File Names**:
- Format: `{expansion_name}_{content_type}.json`
- Examples: `void_raiders_species.json`, `void_raiders_weapons.json`

**DLC Identifier**:
- Same as directory name
- Used in `dlc_required` field
- Example: `"dlc_required": "void_raiders"`

### Creating the Directory

**Bash commands**:
```bash
# Create expansion directory
mkdir -p data/dlc/void_raiders

# Create README
touch data/dlc/void_raiders/README.md

# Create manifest
touch data/dlc/void_raiders/manifest.json
```

---

## Creating the Expansion Manifest

The `manifest.json` file defines your expansion's metadata and content.

### Manifest Schema

```json
{
  "id": "String (directory name)",
  "name": "String (display name)",
  "version": "String (semantic version)",
  "author": "String",
  "description": "String",
  "requires_core_version": "String (minimum core version)",
  "dependencies": ["String (other expansions required)"],
  "content_types": {
    "species": Boolean,
    "psionic_powers": Boolean,
    "elite_enemies": Boolean,
    "difficulty_modifiers": Boolean,
    "equipment": Boolean,
    "weapons": Boolean,
    "missions": Boolean,
    "campaign_modes": Boolean
  },
  "systems": ["String (custom system class names)"],
  "metadata": {
    "homepage": "String (URL)",
    "repository": "String (URL)",
    "license": "String",
    "tags": ["String"]
  }
}
```

### Complete Example

```json
{
  "id": "void_raiders",
  "name": "Void Raiders",
  "version": "1.0.0",
  "author": "Your Name",
  "description": "Space piracy and smuggling expansion. Adds reputation system, black market trading, pirate species, elite pirate enemies, and smuggling missions.",
  "requires_core_version": "1.0.0",
  "dependencies": [],
  "content_types": {
    "species": true,
    "psionic_powers": false,
    "elite_enemies": true,
    "difficulty_modifiers": false,
    "equipment": true,
    "weapons": true,
    "missions": true,
    "campaign_modes": false
  },
  "systems": [
    "ReputationSystem",
    "BlackMarketSystem"
  ],
  "metadata": {
    "homepage": "https://your-website.com/void-raiders",
    "repository": "https://github.com/yourusername/void-raiders",
    "license": "MIT",
    "tags": [
      "pirates",
      "smuggling",
      "reputation",
      "black-market"
    ]
  }
}
```

### Field Descriptions

| Field | Required | Description |
|-------|----------|-------------|
| `id` | Yes | Unique identifier (directory name) |
| `name` | Yes | Display name for UI |
| `version` | Yes | Semantic version (major.minor.patch) |
| `author` | Yes | Creator name or team |
| `description` | Yes | 2-3 sentence summary |
| `requires_core_version` | Yes | Minimum core version needed |
| `dependencies` | Yes | Other expansions required (can be empty) |
| `content_types` | Yes | Which content types are included |
| `systems` | No | Custom system class names |
| `metadata` | No | Additional information |

### Versioning

Use **Semantic Versioning** (semver): `MAJOR.MINOR.PATCH`

- **MAJOR**: Breaking changes (incompatible with previous versions)
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes (backward compatible)

**Examples**:
- `1.0.0` - Initial release
- `1.1.0` - Added 2 new species (compatible with 1.0.0 saves)
- `1.1.1` - Fixed typo in species description
- `2.0.0` - Changed reputation system mechanics (breaks 1.x saves)

---

## Building Specialized Systems

If your expansion needs custom mechanics beyond what core systems provide, you'll create specialized systems.

### When to Create a System

**Create a system if**:
- You need persistent state (tracking values across battles)
- You have complex mechanics (multi-step processes)
- Multiple content types interact with the mechanic
- The mechanic modifies core systems

**Use JSON-only content if**:
- Content is self-contained
- No persistent state needed
- Standard mechanics apply

### System Architecture Pattern

All systems follow this pattern:

```gdscript
class_name YourSystem
extends Node

## YourSystem
##
## [Description of what this system does]
##
## Usage:
##   [Example usage]

# Signals (events this system emits)
signal event_name(param1, param2)

# Data (loaded from JSON)
var your_data: Array = []

# State (tracked during gameplay)
var current_state: Dictionary = {}

# Content filter (for DLC checking)
var content_filter: ContentFilter = null

func _ready() -> void:
    content_filter = ContentFilter.new()
    _load_data()

## Load data from DLC files
func _load_data() -> void:
    if not content_filter.is_content_type_available("your_content_type"):
        push_warning("YourSystem: Expansion not available.")
        return

    var expansion_manager := get_node_or_null("/root/ExpansionManager")
    if not expansion_manager:
        push_error("YourSystem: ExpansionManager not found.")
        return

    var data = expansion_manager.load_expansion_data("your_expansion", "data_file.json")
    if data and data.has("your_data"):
        your_data = data.your_data
        print("YourSystem: Loaded %d entries." % your_data.size())
    else:
        push_error("YourSystem: Failed to load data.")

## Public API methods
func your_method(param: String) -> void:
    # Implementation
    pass
```

### Example: ReputationSystem

**Purpose**: Track player reputation with various factions.

**File**: `src/core/systems/ReputationSystem.gd`

```gdscript
class_name ReputationSystem
extends Node

## ReputationSystem
##
## Tracks player reputation with factions.
## Reputation affects mission availability, prices, and encounters.
##
## Usage:
##   ReputationSystem.modify_reputation("Pirates", 10)
##   var rep = ReputationSystem.get_reputation("Pirates")

signal reputation_changed(faction: String, old_value: int, new_value: int)
signal reputation_tier_changed(faction: String, old_tier: String, new_tier: String)

## Faction data (loaded from JSON)
var factions: Array = []

## Current reputation values
var reputation_values: Dictionary = {}

## Reputation tiers
const TIERS = {
    "Hostile": -50,
    "Unfriendly": -20,
    "Neutral": 0,
    "Friendly": 20,
    "Allied": 50
}

var content_filter: ContentFilter = null

func _ready() -> void:
    content_filter = ContentFilter.new()
    _load_factions()
    _initialize_reputation()

func _load_factions() -> void:
    if not content_filter.is_content_type_available("reputation_factions"):
        push_warning("ReputationSystem: Void Raiders expansion not available.")
        return

    var expansion_manager := get_node_or_null("/root/ExpansionManager")
    if not expansion_manager:
        push_error("ReputationSystem: ExpansionManager not found.")
        return

    var data = expansion_manager.load_expansion_data("void_raiders", "void_raiders_reputation.json")
    if data and data.has("factions"):
        factions = data.factions
        print("ReputationSystem: Loaded %d factions." % factions.size())

func _initialize_reputation() -> void:
    for faction in factions:
        var faction_name = faction.get("name", "")
        var starting_rep = faction.get("starting_reputation", 0)
        reputation_values[faction_name] = starting_rep

## Get current reputation with faction
func get_reputation(faction: String) -> int:
    return reputation_values.get(faction, 0)

## Modify reputation with faction
func modify_reputation(faction: String, amount: int) -> void:
    if not faction in reputation_values:
        push_warning("ReputationSystem: Unknown faction '%s'." % faction)
        return

    var old_value = reputation_values[faction]
    var new_value = clamp(old_value + amount, -100, 100)
    reputation_values[faction] = new_value

    print("ReputationSystem: %s reputation changed: %d → %d (%+d)" % [
        faction, old_value, new_value, amount
    ])

    reputation_changed.emit(faction, old_value, new_value)

    # Check tier change
    var old_tier = _get_tier(old_value)
    var new_tier = _get_tier(new_value)
    if old_tier != new_tier:
        reputation_tier_changed.emit(faction, old_tier, new_tier)

## Get reputation tier for value
func _get_tier(value: int) -> String:
    for tier_name in TIERS:
        if value >= TIERS[tier_name]:
            continue
        else:
            return tier_name
    return "Allied"

## Get all factions
func get_all_factions() -> Array:
    return factions.duplicate()

## Save reputation state
func save_state() -> Dictionary:
    return {
        "reputation_values": reputation_values.duplicate()
    }

## Load reputation state
func load_state(state: Dictionary) -> void:
    if state.has("reputation_values"):
        reputation_values = state.reputation_values.duplicate()
```

**Corresponding JSON**: `data/dlc/void_raiders/void_raiders_reputation.json`

```json
{
  "factions": [
    {
      "name": "Void Raiders",
      "description": "A loose confederation of pirate crews operating in the outer systems.",
      "starting_reputation": 0,
      "effects": {
        "hostile": "Pirates actively hunt you. +50% pirate encounters.",
        "unfriendly": "Pirates are wary. Normal encounter rates.",
        "neutral": "Pirates ignore you unless provoked.",
        "friendly": "Pirates offer jobs. Access to black market.",
        "allied": "Pirates provide backup. Discounted black market prices."
      }
    },
    {
      "name": "Corporate Sector",
      "description": "The mega-corporations that control most inhabited space.",
      "starting_reputation": -10,
      "effects": {
        "hostile": "Corporate bounties on your crew. Security attacks on sight.",
        "unfriendly": "Restricted access to corporate stations.",
        "neutral": "Standard access and pricing.",
        "friendly": "Corporate contracts available. +10% mission pay.",
        "allied": "VIP access. Corporate security backup available."
      }
    },
    {
      "name": "Fringe Colonies",
      "description": "Independent settlements on the edge of known space.",
      "starting_reputation": 10,
      "effects": {
        "hostile": "Banned from colonies. No trade access.",
        "unfriendly": "Limited trade. Higher prices.",
        "neutral": "Standard trade and missions.",
        "friendly": "Priority missions. Rare equipment available.",
        "allied": "Colony militia assistance. Free medical care."
      }
    }
  ]
}
```

### Registering Your System

Systems must be registered as autoload singletons in `project.godot`:

```ini
[autoload]

# ... existing autoloads ...
ReputationSystem="*res://src/core/systems/ReputationSystem.gd"
BlackMarketSystem="*res://src/core/systems/BlackMarketSystem.gd"
```

**Note**: You'll need to instruct users to add this to their `project.godot` or provide a setup script.

---

## Creating Content Data Files

### Species File

**File**: `data/dlc/void_raiders/void_raiders_species.json`

```json
{
  "species": [
    {
      "name": "Voidborn",
      "playable": true,
      "description": "Humans adapted to life in zero-gravity environments. Generations in space have made them agile but fragile, with keen spatial awareness.",
      "homeworld": "The Void (various stations)",
      "traits": ["Agile", "Frail", "Spacer"],
      "starting_bonus": "Start with Vaccsuit and +2 credits (salvage experience)",
      "dlc_required": "void_raiders",
      "source": "Void Raiders",
      "base_profile": {
        "reactions": 2,
        "speed": "5\"",
        "combat_skill": "+0",
        "toughness": 2,
        "savvy": "+1"
      },
      "special_rules": [
        {
          "name": "Zero-G Adapted",
          "description": "Voidborn move effortlessly in zero-gravity.",
          "mechanical_effect": "Ignore movement penalties in zero-gravity environments. +2\" movement in zero-G."
        },
        {
          "name": "Fragile Frame",
          "description": "Low-gravity adaptation has made them physically delicate.",
          "mechanical_effect": "-1 Toughness in standard gravity. (Already reflected in base profile.)"
        },
        {
          "name": "Spacer Instincts",
          "description": "Lifetime in void environments grants superior awareness.",
          "mechanical_effect": "+1 to detect ambushes and avoid environmental hazards."
        }
      ]
    },
    {
      "name": "Krokar",
      "playable": true,
      "description": "Massive crustacean-like aliens with natural armor plating. Krokar are slow but incredibly durable, making them ideal heavy troops for boarding actions.",
      "homeworld": "Krok (high-gravity water world)",
      "traits": ["Durable", "Slow", "Armored"],
      "starting_bonus": "Start with natural armor (6+ save)",
      "dlc_required": "void_raiders",
      "source": "Void Raiders",
      "base_profile": {
        "reactions": 1,
        "speed": "3\"",
        "combat_skill": "+1",
        "toughness": 5,
        "savvy": "-1"
      },
      "special_rules": [
        {
          "name": "Carapace Armor",
          "description": "Natural chitinous plating provides protection.",
          "mechanical_effect": "Natural armor save of 6+. Stacks with worn armor (use best save, then make second save if first fails)."
        },
        {
          "name": "Lumbering",
          "description": "Krokar move slowly but steadily.",
          "mechanical_effect": "-1\" movement. (Already reflected in base profile.) Cannot use Dash action."
        },
        {
          "name": "Powerful Claws",
          "description": "Krokar possess crushing claws for melee combat.",
          "mechanical_effect": "Unarmed attacks deal 1 damage (instead of stunning). +1 to Brawling tests."
        }
      ]
    }
  ]
}
```

**Balance Check**:

**Voidborn**:
- Reactions +1 = +1
- Speed +1" = +1
- Toughness -1 = -1
- Savvy +1 = +1
- Total = +2 (slightly above neutral, but Fragile Frame special rule is a disadvantage)

**Krokar**:
- Reactions 0 = 0
- Speed -1" = -1
- Combat Skill +1 = +1
- Toughness +2 = +2
- Savvy -1 = -1
- Natural armor = +1
- Total = +2 (powerful but slow, balanced by disadvantages)

### Elite Enemies File

**File**: `data/dlc/void_raiders/void_raiders_elite_enemies.json`

```json
{
  "elite_enemies": [
    {
      "name": "Void Raider Captain",
      "enemy_type": "Pirate",
      "combat_skill": "+2",
      "toughness": 4,
      "speed": "5\"",
      "reactions": 2,
      "weapons": [
        "Hand Cannon",
        "Blade",
        "Frag Grenade"
      ],
      "special_abilities": [
        {
          "name": "Inspiring Leader",
          "effect": "All pirate allies within 6\" gain +1 to Morale tests. Represents the captain's charisma and leadership."
        },
        {
          "name": "Pirate Tactics",
          "effect": "Once per battle, may move an ally within 12\" up to their full movement distance (even if already activated). Represents tactical coordination."
        },
        {
          "name": "Void Hardened",
          "effect": "Ignore first injury result each battle (treat as Stun instead). Represents decades of combat experience."
        }
      ],
      "dlc_required": "void_raiders",
      "source": "Void Raiders",
      "deployment_points": 4
    }
  ]
}
```

**Deployment Points Calculation**:
- Base: 1
- Combat Skill +2 (vs +0): +2
- Toughness 4 (vs 3): +1
- Reactions 2 (vs 1): +0.5
- 3 abilities: +2
- Total: 6.5 → **4 DP** (rounded down for elite with weaknesses)

### Weapons File

**File**: `data/dlc/void_raiders/void_raiders_weapons.json`

```json
{
  "weapons": [
    {
      "name": "Ripper Cannon",
      "type": "heavy",
      "range": "18\"",
      "shots": 3,
      "damage": 2,
      "traits": [
        "Heavy",
        "Piercing"
      ],
      "cost": 1200,
      "rarity": "rare",
      "dlc_required": "void_raiders",
      "source": "Void Raiders",
      "description": "A devastating weapon designed for ship-to-ship boarding actions. Fires high-velocity flechettes that shred armor and flesh alike."
    },
    {
      "name": "Boarding Shotgun",
      "type": "rifle",
      "range": "12\"",
      "shots": 2,
      "damage": 2,
      "traits": [
        "Spread",
        "Close Quarters"
      ],
      "cost": 600,
      "rarity": "uncommon",
      "dlc_required": "void_raiders",
      "source": "Void Raiders",
      "description": "Short-range scattergun optimized for close-quarters combat in ship corridors. Devastating at point-blank range."
    }
  ]
}
```

### Missions File

**File**: `data/dlc/void_raiders/void_raiders_missions.json`

```json
{
  "missions": [
    {
      "name": "Smuggling Run",
      "type": "custom",
      "description": "Transport illegal cargo through a corporate blockade. Avoid detection by patrols while reaching the delivery point.",
      "objectives": [
        {
          "type": "Delivery",
          "description": "Reach extraction point with cargo intact",
          "success_condition": "At least one crew member carrying cargo reaches the extraction zone"
        }
      ],
      "deployment_conditions": {
        "enemy_count": "6+1D3",
        "enemy_types": [
          "Corporate Security",
          "Security Drone"
        ],
        "battlefield_size": "36\" × 36\"",
        "terrain_requirements": [
          "Cargo containers (partial cover)",
          "Patrol routes (marked paths)",
          "Extraction zone (6\" × 6\" area)"
        ],
        "special_rules": [
          "Cargo is Heavy (carrier moves at -2\")",
          "Patrols move on predetermined routes each round",
          "Detection triggers reinforcements"
        ]
      },
      "special_mechanics": {
        "detection_system": {
          "detection_range": "12\"",
          "detection_check": "1D6 + Guard Savvy vs Crew Savvy + Cover",
          "detection_penalty": "Add 1D3 enemies as reinforcements"
        }
      },
      "rewards": {
        "credits": "3D6×100",
        "loot_rolls": 0,
        "xp_bonus": 1,
        "special_rewards": [
          "Reputation +10 with Void Raiders",
          "Reputation -5 with Corporate Sector"
        ]
      },
      "dlc_required": "void_raiders",
      "source": "Void Raiders"
    }
  ]
}
```

---

## Integration with Core Systems

### ContentFilter Integration

Your content needs to be registered with the ContentFilter system.

**File to modify**: `src/core/systems/ContentFilter.gd`

Add your expansion to the content type mapping:

```gdscript
# In _initialize_content_types()
content_types["reputation_factions"] = ["void_raiders"]
content_types["black_market_items"] = ["void_raiders"]
```

**Note**: Users will need to add this or you provide a patch file.

### ExpansionManager Integration

The ExpansionManager automatically loads all expansions from `/data/dlc/`. No code changes needed if you follow the standard structure.

**Verification**:
```gdscript
# In your game code
var expansion_manager = get_node("/root/ExpansionManager")
var is_loaded = expansion_manager.is_expansion_loaded("void_raiders")
print("Void Raiders loaded: ", is_loaded)
```

### Integration Points

Your expansion can integrate with core systems through:

1. **Signals**: Listen to core system events
2. **Data Loading**: Core systems load your JSON data
3. **Method Calls**: Call core system methods
4. **Autoload Access**: Access global systems

**Example: Reputation affects mission pay**

```gdscript
# In mission reward calculation (you'd hook this)
func calculate_mission_reward(base_credits: int, faction: String) -> int:
    var reputation_system = get_node_or_null("/root/ReputationSystem")
    if not reputation_system:
        return base_credits

    var reputation = reputation_system.get_reputation(faction)
    var tier = reputation_system._get_tier(reputation)

    match tier:
        "Allied":
            return int(base_credits * 1.25)
        "Friendly":
            return int(base_credits * 1.10)
        "Neutral":
            return base_credits
        "Unfriendly":
            return int(base_credits * 0.90)
        "Hostile":
            return int(base_credits * 0.75)

    return base_credits
```

---

## Testing Your Expansion

### Testing Checklist

**1. Data Loading** ✓
- [ ] Expansion manifest loads without errors
- [ ] All JSON files parse correctly
- [ ] Content appears in ExpansionManager list
- [ ] Content filter recognizes content types

**2. Content Display** ✓
- [ ] Species appear in character creation
- [ ] Enemies appear in battle setup
- [ ] Equipment appears in shops/loot
- [ ] Missions appear in mission selection

**3. Functional Testing** ✓
- [ ] Species special rules work correctly
- [ ] Elite enemies use their abilities
- [ ] Custom weapons function properly
- [ ] Mission objectives complete correctly
- [ ] Custom systems track state properly

**4. Balance Testing** ✓
- [ ] Species are balanced (net-zero stats, useful but not OP)
- [ ] Elite enemies are challenging but fair
- [ ] Weapons are priced appropriately
- [ ] Mission rewards match difficulty

**5. Integration Testing** ✓
- [ ] Expansion works with base game
- [ ] Expansion works with other expansions
- [ ] Save/load preserves expansion state
- [ ] Disabling expansion doesn't break saves

### Test Script Example

Create automated tests for your systems:

**File**: `tests/test_reputation_system.gd`

```gdscript
extends GutTest

var reputation_system: ReputationSystem

func before_each():
    reputation_system = ReputationSystem.new()
    reputation_system._ready()

func test_initial_reputation():
    var rep = reputation_system.get_reputation("Void Raiders")
    assert_eq(rep, 0, "Initial reputation should be 0")

func test_modify_reputation():
    reputation_system.modify_reputation("Void Raiders", 10)
    var rep = reputation_system.get_reputation("Void Raiders")
    assert_eq(rep, 10, "Reputation should increase by 10")

func test_reputation_clamping():
    reputation_system.modify_reputation("Void Raiders", 200)
    var rep = reputation_system.get_reputation("Void Raiders")
    assert_eq(rep, 100, "Reputation should clamp at 100")

func test_tier_calculation():
    reputation_system.modify_reputation("Void Raiders", 50)
    var tier = reputation_system._get_tier(50)
    assert_eq(tier, "Allied", "Reputation 50 should be Allied tier")
```

Run with GUT (Godot Unit Testing) framework.

### Balance Testing Methodology

See **Testing & Validation Guide** (separate document) for detailed balance testing methodology.

**Quick balance checks**:

1. **Species**: Play 5 battles with each species. Win rate should be 40-60%.
2. **Elite Enemies**: Should require 2-3 crew members to defeat. Should not one-shot characters.
3. **Weapons**: Compare DPR (damage per round) to existing weapons. Should be within 20%.
4. **Missions**: Should take 30-60 minutes. Completion rate 50-70% for skilled players.

---

## Publishing and Distribution

### Documentation

Create comprehensive documentation for users:

**README.md Template**:

```markdown
# Void Raiders Expansion

**Version**: 1.0.0
**Author**: Your Name
**Requires**: Five Parsecs Campaign Manager v1.0.0+

## Overview

Space piracy and smuggling expansion for Five Parsecs Campaign Manager.

## Features

- **2 New Species**: Voidborn (zero-G adapted humans) and Krokar (armored crustaceans)
- **4 Elite Enemies**: Pirate captains, smuggler bosses, and more
- **8 New Weapons**: From boarding shotguns to ripper cannons
- **6 Missions**: Smuggling runs, pirate raids, black market deals
- **2 Systems**: Reputation tracking and black market trading

## Installation

1. Download the latest release
2. Extract to `data/dlc/void_raiders/`
3. Add autoload entries to `project.godot` (see INSTALL.md)
4. Restart the game

## Usage

### Reputation System

Track your standing with three factions:
- **Void Raiders**: Pirate confederation
- **Corporate Sector**: Mega-corporations
- **Fringe Colonies**: Independent settlements

Reputation affects mission availability, prices, and encounters.

### Black Market

Access illegal equipment and services:
- Rare weapons
- Stolen goods
- Forged credentials
- Requires Friendly+ reputation with Void Raiders

## Credits

Created by [Your Name]
Special thanks to [Contributors]

## License

MIT License (see LICENSE file)
```

### Installation Guide

**INSTALL.md**:

```markdown
# Installation Guide

## Automatic Installation (Recommended)

1. Download `void_raiders_v1.0.0.zip`
2. Extract to `data/dlc/` directory
3. Run the installer script: `void_raiders_install.sh` (Linux/Mac) or `void_raiders_install.bat` (Windows)
4. Restart the game

## Manual Installation

### Step 1: Extract Files

Extract the zip file to `data/dlc/void_raiders/`

Your directory structure should look like:
```
data/
└── dlc/
    └── void_raiders/
        ├── manifest.json
        ├── void_raiders_species.json
        ├── void_raiders_elite_enemies.json
        └── ...
```

### Step 2: Register Systems

Open `project.godot` and add these lines under `[autoload]`:

```ini
ReputationSystem="*res://src/core/systems/ReputationSystem.gd"
BlackMarketSystem="*res://src/core/systems/BlackMarketSystem.gd"
```

### Step 3: Update ContentFilter

Open `src/core/systems/ContentFilter.gd` and add to `_initialize_content_types()`:

```gdscript
content_types["reputation_factions"] = ["void_raiders"]
content_types["black_market_items"] = ["void_raiders"]
```

### Step 4: Restart

Restart the game. Void Raiders expansion should appear in the expansion list.

## Verification

1. Check expansion list in main menu
2. Create new character → Should see Voidborn and Krokar species
3. Start campaign → Reputation system should track factions
4. Visit shop → Black market option should appear (if Friendly+ with Void Raiders)

## Troubleshooting

**Expansion not appearing**:
- Check file paths match exactly
- Verify `manifest.json` is valid JSON
- Check console for errors

**Systems not working**:
- Verify autoload entries in `project.godot`
- Check system script paths
- Restart game editor (not just game)

**Content not loading**:
- Verify JSON files are valid (use JSON validator)
- Check `dlc_required` fields match `"void_raiders"`
- Check ContentFilter registration
```

### Packaging

Create a release package:

```bash
# Create release directory
mkdir -p releases/void_raiders_v1.0.0

# Copy expansion files
cp -r data/dlc/void_raiders releases/void_raiders_v1.0.0/

# Copy system files
mkdir -p releases/void_raiders_v1.0.0/systems
cp src/core/systems/ReputationSystem.gd releases/void_raiders_v1.0.0/systems/
cp src/core/systems/BlackMarketSystem.gd releases/void_raiders_v1.0.0/systems/

# Copy documentation
cp void_raiders/README.md releases/void_raiders_v1.0.0/
cp void_raiders/INSTALL.md releases/void_raiders_v1.0.0/
cp void_raiders/LICENSE releases/void_raiders_v1.0.0/

# Create installer scripts
# (Installation scripts here)

# Create archive
cd releases
zip -r void_raiders_v1.0.0.zip void_raiders_v1.0.0/
cd ..
```

### Distribution Platforms

**GitHub**:
1. Create repository
2. Tag release: `git tag v1.0.0`
3. Create GitHub Release
4. Upload zip file
5. Write release notes

**itch.io**:
1. Create project page
2. Upload zip file
3. Set pricing (free or paid)
4. Write description
5. Add screenshots/gameplay

**Modding Communities**:
- Nexus Mods
- ModDB
- Game-specific forums

### Licensing

Choose an appropriate license:

**MIT License** (permissive):
```
MIT License

Copyright (c) 2024 Your Name

Permission is hereby granted, free of charge, to any person obtaining a copy...
```

**CC-BY-4.0** (attribution required):
```
Creative Commons Attribution 4.0 International License

This work is licensed under CC-BY-4.0...
```

**GPL-3.0** (copyleft):
```
GNU General Public License v3.0

This program is free software: you can redistribute it and/or modify...
```

---

## Complete Example: "Void Raiders" Expansion

### File Structure Summary

```
void_raiders/
├── data/dlc/void_raiders/
│   ├── manifest.json (metadata)
│   ├── void_raiders_species.json (2 species)
│   ├── void_raiders_elite_enemies.json (4 elites)
│   ├── void_raiders_weapons.json (8 weapons)
│   ├── void_raiders_gear.json (6 gear items)
│   ├── void_raiders_missions.json (6 missions)
│   ├── void_raiders_reputation.json (faction data)
│   └── void_raiders_black_market.json (black market items)
├── src/core/systems/
│   ├── ReputationSystem.gd (reputation tracking)
│   └── BlackMarketSystem.gd (black market system)
├── README.md (user documentation)
├── INSTALL.md (installation guide)
├── CHANGELOG.md (version history)
└── LICENSE (license file)
```

### Content Summary

**Species (2)**:
- Voidborn: Zero-G adapted humans (agile, frail, spacer)
- Krokar: Armored crustaceans (durable, slow, powerful claws)

**Elite Enemies (4)**:
- Void Raider Captain (inspiring leader, pirate tactics, void hardened)
- Smuggler Boss (black market connections, escape artist, dirty fighter)
- Pirate Ace Pilot (evasive maneuvers, strafing run, ace pilot)
- Krokar Enforcer (shell fortress, crushing grip, relentless)

**Weapons (8)**:
- Ripper Cannon (heavy, piercing, 3 shots)
- Boarding Shotgun (spread, close quarters)
- Void Cutter (melee, armor bypass)
- Plasma Torch (short range, high damage)
- Mag-Grapple (utility, repositioning)
- EMP Grenade (disables tech)
- Scrap Cannon (improvised, unreliable, cheap)
- Pirate Cutlass (melee, iconic)

**Gear (6)**:
- Vaccsuit (environment protection)
- Mag Boots (zero-G mobility)
- Smuggler's Compartment (hide items)
- Forged Credentials (bypass security)
- Black Market Contact (special vendor access)
- Reputation Badge (faction identification)

**Missions (6)**:
- Smuggling Run (stealth delivery)
- Pirate Raid (aggressive assault)
- Black Market Deal (tense negotiation)
- Void Salvage (scavenging in space)
- Corporate Heist (infiltration)
- Territory War (faction conflict)

**Systems (2)**:
- ReputationSystem (faction standing)
- BlackMarketSystem (illegal trading)

### Statistics

- **Total Files**: 13
- **Total Lines**: ~2,000 (including systems)
- **Content Items**: 36 (2 species + 4 elites + 8 weapons + 6 gear + 6 missions + 3 factions + other data)
- **Systems**: 2 custom systems
- **Development Time**: 3-4 weeks (estimated)

---

## Advanced Topics

### Campaign Mode Creation

Creating alternative campaign modes (like Bug Hunt) is advanced. Key steps:

1. **Design Campaign Flow**: How does campaign progression work?
2. **Create Specialized Systems**: What unique mechanics are needed?
3. **Character Transfer**: How do characters convert between modes?
4. **Victory Conditions**: How does the campaign end?

See [Bug Hunt Integration Guide](./BUG_HUNT_INTEGRATION.md) for complete example.

### UI Integration

Add custom UI for your systems:

**Example: Reputation UI Panel**

```gdscript
# ReputationPanel.gd
extends Panel

var reputation_system: ReputationSystem

func _ready():
    reputation_system = get_node("/root/ReputationSystem")
    reputation_system.reputation_changed.connect(_on_reputation_changed)
    _update_display()

func _update_display():
    var factions = reputation_system.get_all_factions()
    for faction in factions:
        var rep = reputation_system.get_reputation(faction.name)
        var tier = reputation_system._get_tier(rep)
        # Update UI elements
        _display_faction(faction.name, rep, tier)

func _on_reputation_changed(faction: String, old_value: int, new_value: int):
    _update_display()
    # Show notification
    _show_reputation_change_notification(faction, old_value, new_value)
```

### Localization

Support multiple languages:

**File**: `data/dlc/void_raiders/localization/en.json`

```json
{
  "expansion_name": "Void Raiders",
  "expansion_description": "Space piracy and smuggling expansion",
  "species": {
    "voidborn": {
      "name": "Voidborn",
      "description": "Humans adapted to life in zero-gravity environments..."
    }
  },
  "ui": {
    "reputation": "Reputation",
    "black_market": "Black Market",
    "faction_standing": "Faction Standing"
  }
}
```

### Asset Integration

Add custom assets (models, textures, sounds):

```
void_raiders/
├── assets/
│   ├── textures/
│   │   ├── voidborn_portrait.png
│   │   └── krokar_portrait.png
│   ├── models/
│   │   ├── ripper_cannon.glb
│   │   └── boarding_shotgun.glb
│   └── sounds/
│       ├── reputation_increase.ogg
│       └── black_market_theme.ogg
```

Reference in JSON:

```json
{
  "name": "Voidborn",
  "portrait": "res://data/dlc/void_raiders/assets/textures/voidborn_portrait.png"
}
```

---

## Troubleshooting

### Common Issues

**1. Expansion Not Loading**

**Symptoms**: Expansion doesn't appear in list, content not available

**Checks**:
- Verify directory path: `data/dlc/your_expansion/`
- Check `manifest.json` is valid JSON (use validator)
- Check console for errors: Look for "ExpansionManager" messages
- Verify `id` in manifest matches directory name

**Solution**:
```bash
# Validate JSON
python3 -m json.tool data/dlc/void_raiders/manifest.json

# Check file permissions
ls -la data/dlc/void_raiders/

# Verify directory name matches manifest id
cat data/dlc/void_raiders/manifest.json | grep '"id"'
```

**2. Systems Not Working**

**Symptoms**: Custom systems not accessible, methods not found

**Checks**:
- Verify autoload registration in `project.godot`
- Check system script paths are correct
- Verify class_name matches autoload name
- Check for syntax errors in system code

**Solution**:
```gdscript
# Test system access
var system = get_node_or_null("/root/ReputationSystem")
if system:
    print("System loaded successfully")
else:
    print("ERROR: System not found")
```

**3. Content Not Appearing**

**Symptoms**: Species/enemies/equipment don't show up in game

**Checks**:
- Verify `dlc_required` field matches expansion ID
- Check ContentFilter registration
- Verify JSON structure matches schema
- Check for typos in field names

**Solution**:
```gdscript
# Test content filter
var content_filter = ContentFilter.new()
var available = content_filter.is_content_type_available("your_content_type")
print("Content available: ", available)
```

**4. Balance Issues**

**Symptoms**: Content is overpowered or underpowered

**Checks**:
- Review stat calculations (species net-zero, elite DP formula)
- Compare to official content
- Playtest with different crew compositions
- Get community feedback

**Solution**: Iterate on balance. See Testing & Validation Guide.

**5. Save/Load Errors**

**Symptoms**: Game crashes on load, expansion state lost

**Checks**:
- Verify system implements save_state() and load_state()
- Check for circular references in saved data
- Test with expansion enabled/disabled
- Verify version compatibility

**Solution**:
```gdscript
# Implement proper save/load
func save_state() -> Dictionary:
    return {
        "version": "1.0.0",
        "data": your_data.duplicate()
    }

func load_state(state: Dictionary) -> void:
    if state.get("version", "") != "1.0.0":
        push_warning("Version mismatch")
        return
    your_data = state.get("data", {}).duplicate()
```

### Getting Help

**Resources**:
- [Official Documentation](link)
- [Community Forum](link)
- [Discord Server](link)
- [GitHub Issues](link)

**Reporting Bugs**:
1. Check existing issues first
2. Provide minimal reproduction case
3. Include error messages and logs
4. Specify versions (core, expansion, Godot)

---

## Next Steps

You've learned how to create custom expansions! Here's what to do next:

### For Your First Expansion

1. **Start Small**: Create a content pack (2-3 species, 5 weapons, 3 missions)
2. **Follow Examples**: Use official expansions as templates
3. **Test Thoroughly**: Balance and playtest before release
4. **Get Feedback**: Share with community, iterate based on feedback
5. **Document Well**: Good documentation = happy users

### Advanced Learning

1. **Study Official Expansions**: Read all integration guides
2. **Campaign Modes**: Study Bug Hunt for campaign mode patterns
3. **System Design**: Learn Godot signals and autoload patterns
4. **Community Content**: See what others have created

### Contributing

Consider contributing your expansion:

1. **Open Source**: Share code on GitHub
2. **Community Showcase**: Post in forums/Discord
3. **Documentation**: Contribute guides and tutorials
4. **Support**: Help other modders

---

## Appendix: Quick Reference

### Expansion Checklist

**Planning**:
- [ ] Expansion concept defined
- [ ] Content list created
- [ ] Systems designed (if needed)
- [ ] Scope estimated

**Setup**:
- [ ] Directory created
- [ ] Manifest written
- [ ] README drafted

**Content**:
- [ ] Species designed and balanced
- [ ] Enemies created and costed
- [ ] Equipment designed
- [ ] Missions planned

**Systems** (if needed):
- [ ] Systems implemented
- [ ] Data files created
- [ ] Integration complete
- [ ] Autoload registered

**Testing**:
- [ ] Data loading verified
- [ ] Content displays correctly
- [ ] Functionality tested
- [ ] Balance validated

**Documentation**:
- [ ] README complete
- [ ] INSTALL guide written
- [ ] CHANGELOG started
- [ ] License included

**Distribution**:
- [ ] Package created
- [ ] Installer scripts written
- [ ] Release created
- [ ] Community announced

---

**Document Version**: 1.0
**Last Updated**: 2024-11-16
**Maintained By**: Five Parsecs Campaign Manager Development Team

**Related Documentation**:
- [Expansion Documentation Index](./EXPANSION_DOCUMENTATION_INDEX.md)
- [Content Creation Guide](./CONTENT_CREATION_GUIDE.md)
- [Data Format Specifications](./DATA_FORMAT_SPECIFICATIONS.md)
- [Testing & Validation Guide](./TESTING_VALIDATION_GUIDE.md)
