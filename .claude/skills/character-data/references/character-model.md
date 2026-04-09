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

### Creation Bonuses (Session 30)
```gdscript
@export var creation_bonuses: Dictionary = {}
# Set once by CharacterCreator._roll_and_store_creation_bonuses()
# Keys: bonus_credits, patrons, rivals, story_points, quest_rumors, xp, starting_rolls, credits_dice_sources
# Immutable after creation. Included in to_dictionary() and from_dictionary().
# All downstream consumers (CrewPanel, EquipmentPanel, coordinator, FinalPanel) read from this.
```

### Strange Character Species Data (Session 34, Core Rules pp.19-22)
```gdscript
@export var species_id: String = ""           # JSON id for lookup (e.g., "de_converted")
@export var special_rules: Array[String] = [] # Populated at creation from character_species.json
@export var xp_discount_stat: String = ""     # Minor Alien: one stat costs 1 less XP (rolled at creation)
```

Helper methods on Character:
- `can_receive_luck() -> bool` — false for emo_suppressed and bot types
- `can_earn_xp() -> bool` — false for bot, assault_bot
- `get_bonus_xp() -> int` — 1 for hopeful_rookie
- `can_perform_task(task_id: String) -> bool` — false for mutant on recruit/find_patron

Central lookup: `SpeciesDataService.gd` (static RefCounted, lazy-loads `character_species.json`). Used by CharacterCreator, gameplay systems, and UI. Character.gd does NOT import SpeciesDataService directly (load order issue) — helper methods use inline string checks instead.

`GameEnums.StrangeCharacterType` is DEPRECATED — use `species_id` string.

### Autoload Access from Character (Resource)
Character extends Resource, not Node. Cannot use `get_node_or_null()` directly. Use:
```gdscript
var tree = Engine.get_main_loop() as SceneTree
if tree:
    var autoload = tree.root.get_node_or_null("/root/GlobalEnums")
```
**Never** use `Engine.has_singleton()` for autoloads — always returns false.

### Combat Interface (BaseCharacterResource — Session 10)

`BaseCharacterResource` implements 22 combat methods required by `CombatResolver._validate_character_interface()`:

```gdscript
# Equipment
get_equipped_weapon() -> Dictionary   # weapons[0] as dict, or {}
get_combat_skill() -> int             # returns combat stat
get_speed() -> int                    # returns speed stat

# Damage
get_melee_damage() -> int             # weapon melee_damage or 1+combat
get_ranged_damage() -> int            # weapon damage or 0
get_armor_value() -> int              # armor[0].saving_throw or 0
apply_damage(amount: int) -> void     # health -= amount, marks wounded/dead
heal_damage(amount: int) -> void      # health += amount, capped at max

# Actions
add_action_points(amount: int) -> void
reduce_action_points(amount: int) -> void
can_perform_action(_action) -> bool   # action_points > 0 and not dead

# Abilities
get_active_ability() -> String
get_ability_cooldown(ability: String) -> int
is_ability_on_cooldown(ability: String) -> bool
add_combat_modifier(modifier) -> void

# Status checks (scan active_effects array)
is_mechanical() -> bool               # returns is_bot
is_suppressed() -> bool
is_pinned() -> bool
has_overwatch() -> bool
can_counter_attack() -> bool
can_dodge() -> bool
can_suppress() -> bool

# Lifecycle
reset_battle_state() -> void          # clears transient combat state
```

Property aliases: `name`→`character_name`, `bot`→`is_bot`, `soulless`→`is_soulless`
Transient state: `position`, `in_cover`, `elevation`, `active_effects`, `has_moved_this_turn`, `is_player_controlled`, `is_swift`, `_action_points`, `_combat_modifiers`, `_active_ability`, `_ability_cooldowns`

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
var status_effects: Array[Dictionary]  # {type, name, description, duration, source_event} — Character Events (Core Rules pp.128-130)
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
  "status_effects": [{"type": "skip_next_battle", "name": "Violence is Depressing", "duration": 1}],
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
