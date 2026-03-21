# Character Data Model Reference

## Character.gd (Canonical)
- **Path**: `src/core/character/Character.gd`
- **extends**: Resource
- **class_name**: Character
- **~1,900 lines**

### Signals
```
injury_added(injury: Dictionary)
injury_removed(index: int)
recovery_progressed(turns_remaining: int)
implant_added(implant: Dictionary)
implant_removed(index: int)
experience_changed(new_amount: int)
advancement_available(character: Resource)
```

### Flat Stats (CRITICAL — No Sub-Object)
```gdscript
var combat: int = 0
var reactions: int = 0
var toughness: int = 0
var savvy: int = 0
var tech: int = 0
var speed: int = 4        # canonical, replaces deprecated `move`
var luck: int = 0
```
These are direct properties on Character. There is NO `stats` Dictionary or sub-object. `CharacterStats.gd` exists as a separate Resource class but is NOT used as a character property.

### Identity & Status Properties
```gdscript
var name: String
var character_id: String   # auto-generated: "char_{timestamp}_{random}"
var is_captain: bool = false
var health: int = 5
var max_health: int = 5
var status: String         # "ACTIVE|INJURED|RECOVERING|DEAD|MISSING|RETIRED"
var background: String     # validated enum
var motivation: String     # validated enum
var origin: String         # validated enum
var character_class: String # validated enum
var portrait_path: String
var morale: int = 5
```

### Equipment & Inventory
```gdscript
var equipment: Array[String]
var injuries: Array[Dictionary]  # {type, severity, recovery_turns, turn_sustained}
var implants: Array[Dictionary]  # {type, name, stat_bonus} — max 3
var bot_upgrades: Array[String]
```

### Lifetime Stats
```gdscript
var lifetime_kills: int = 0
var lifetime_damage_dealt: int = 0
var lifetime_damage_taken: int = 0
var battles_participated: int = 0
var battles_survived: int = 0
var critical_hits_landed: int = 0
var experience: int = 0
var credits: int = 0
```

### Computed Properties (getters)
- `is_wounded: bool` — has active injuries
- `is_dead: bool` — get/set
- `weapons: Array` — filtered from equipment
- `items: Array` — filtered from equipment
- `current_recovery_turns: int`
- `character_name: String` — alias for `name`
- `combat_skill: int` — alias for `combat`

### Key Methods
```
# Experience & Advancement
add_experience(amount: int) -> void
can_advance() -> bool
spend_xp_on_stat(stat_name: String) -> bool

# Combat Modifiers
get_combat_modifiers() -> Dictionary        # all sources with stat breakdowns
get_effective_combat_skill() -> int
get_effective_toughness() -> int
get_effective_reactions() -> int
get_effective_stat(stat_name: String) -> int  # includes implant bonuses
get_natural_armor_save() -> int
has_natural_armor() -> bool
get_max_reactions() -> int
can_use_reaction() -> bool
spend_reaction() -> bool
reset_reactions() -> void
is_swift() -> bool

# Injuries
add_injury(injury: Dictionary) -> void
remove_injury(index: int) -> void
process_recovery_turn() -> void

# Implants (max 3)
add_implant(implant: Dictionary) -> bool
remove_implant(index: int) -> void
get_implant_bonuses() -> Dictionary

# Bot Upgrades
add_bot_upgrade(upgrade_id: String) -> void
has_bot_upgrade(upgrade_id: String) -> bool

# Status
get_status_enum() -> int          # String → GameEnums.CharacterStatus
set_status_from_enum(value: int) -> void

# Serialization
to_dictionary() -> Dictionary     # DUAL KEYS: "id"/"character_id", "name"/"character_name"
from_dictionary(data: Dictionary) -> void  # accepts both nested and flat stat formats
is_valid() -> bool

# Display
get_display_name() -> String
get_total_stats() -> int
get_experience_summary() -> String
get_service_record() -> String

# Tracking
add_kill() -> void
complete_mission(mission_credits: int = 0) -> void
modify_morale(amount: int) -> void
set_faction_relation(faction_id: String, value: int) -> void
get_faction_relation(faction_id: String) -> int
```

### Static Methods
```
Character.generate_character(background_type: String = "") -> Character
Character.generate_crew_members(count: int) -> Array[Character]
Character.create_captain_from_crew(crew_member: Character) -> Character
Character.create_implant_from_type(implant_type_key: String) -> Dictionary
Character.create_implant_from_loot(loot_name: String) -> Dictionary
```

### Implant System (Core Rules p.55)
- **MAX_IMPLANTS**: 2 (book says max 2, Bots/Soulless cannot use)
- **11 types**: AI_COMPANION, BODY_WIRE, BOOSTED_ARM, BOOSTED_LEG, CYBER_HAND, GENETIC_DEFENSES, HEALTH_BOOST, NERVE_ADJUSTER, NEURAL_OPTIMIZATION, NIGHT_SIGHT, PAIN_SUPPRESSOR
- **LOOT_TO_IMPLANT_MAP**: Maps book implant names directly to type keys
- Each implant: `{type: String, name: String, stat_bonus: Dictionary, description: String}`
- Most implants have special abilities (text descriptions) rather than stat bonuses

### Serialization Format (to_dictionary)
```json
{
  "id": "char_12345_678",
  "character_id": "char_12345_678",
  "name": "Captain Rex",
  "character_name": "Captain Rex",
  "combat": 3,
  "reactions": 2,
  "toughness": 3,
  "savvy": 1,
  "tech": 0,
  "speed": 4,
  "luck": 1,
  "health": 5,
  "max_health": 5,
  "experience": 12,
  "is_captain": true,
  "status": "ACTIVE",
  "equipment": ["laser_rifle", "combat_armor"],
  "injuries": [],
  "implants": [{"type": "NEURAL_LINK", "name": "Neural Link", "stat_bonus": {"savvy": 1}}],
  "background": "MILITARY",
  "origin": "HUMAN",
  "motivation": "GLORY",
  "character_class": "SOLDIER"
}
```

---

## BaseCharacterResource.gd
- **Path**: `src/core/character/Base/Character.gd`
- **extends**: Resource
- **class_name**: BaseCharacterResource
- **@tool**: Yes

### Key Differences from Character.gd
- Uses `int` enum values for `character_class`, `origin`, `background`, `motivation` (Character.gd uses String)
- Has `level: int` and `training: int` (Character.gd does not)
- Has `is_bot`, `is_soulless`, `is_human` booleans
- Has `traits: Array`
- Serialize methods: `serialize()` / `deserialize()` (vs Character.gd's `to_dictionary()` / `from_dictionary()`)

### MAX_STATS Constants
```gdscript
const MAX_STATS: Dictionary = {
  reaction: 6, combat: 5, speed: 8, savvy: 5, toughness: 6, luck: 1
}
```

### Signals
```
experience_changed(old_value, new_value)
level_changed(old_value, new_value)
health_changed(old_value, new_value)
status_changed(status)
training_changed(old_value, new_value)
```
