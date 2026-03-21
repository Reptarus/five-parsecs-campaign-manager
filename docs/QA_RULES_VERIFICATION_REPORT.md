# Rules Verification Report

**Date**: 2026-03-21
**Method**: Cross-reference RulesReference JSON data files against GDScript implementations
**Scope**: All 170 implemented mechanics
**Limitation**: Verified against digitized rules in `data/RulesReference/*.json`, NOT the physical Core Rules book

---

## Verification Summary

| Category | Verified | Matches | Mismatches | Intentional Divergence | Needs Manual Review |
|----------|----------|---------|------------|----------------------|-------------------|
| Species/Origin Bonuses | 7 | 4 | 3 | 0 | 0 |
| Difficulty System | 5 | 2 | 0 | 3 | 0 |
| Weapon Stats | 12 | 0 | 7 | 5 | 0 |
| Campaign Structure | 9 | 9 | 0 | 0 | 0 |
| Equipment/Armor | — | — | — | — | Full review needed |
| Loot Tables | — | — | — | — | Full review needed |
| Battle Mechanics | — | — | — | — | Full review needed |

**Total Verified**: ~33 mechanics via JSON cross-reference
**Remaining**: ~137 mechanics require physical Core Rules book review

---

## Species/Origin Bonuses (7 verified)

| Species | Rules Bonus | Code Implementation | Status |
|---------|------------|-------------------|--------|
| Human | None | No bonuses | MATCH |
| Engineer | +1 Savvy | +1 Savvy | MATCH |
| Feral | +1 Speed | +1 Speed | MATCH |
| K'Erin | +1 Combat Skill | +1 Combat Skill | MATCH |
| Precursor | Start with one Psionic power | +1 Savvy only | MISMATCH |
| Soulless | +1 Toughness | +1 Toughness + +1 Reactions | EXTRA BONUS |
| Swift | +2 Speed | +1 Speed + +1 Reactions | MISMATCH |

### Action Items (Species)
- **BUG-036**: Precursor missing psionic power assignment at creation. Code only gives +1 Savvy. Needs design decision: add psionic power in CharacterCreator or document as deferred.
- ~~**BUG-037**~~: **FIXED** — Swift now gives +2 Speed (was +1 Speed +1 Reactions). Matched Core Rules p.50.
- ~~**BUG-038**~~: **FIXED** — Soulless now gives +1 Toughness only (removed extra +1 Reactions). Matched Core Rules p.50.

---

## Difficulty System (5 verified)

The difficulty system is an **intentional digital adaptation** of the tabletop rules:

| Level | Rules (Tabletop) | Code (Digital) | Status |
|-------|-----------------|----------------|--------|
| EASY | Contact markers -1, Encounter -1, Support +2 | XP bonus +1, enemy reduction | DIGITAL ADAPTATION |
| NORMAL | Contact markers -1 / standard | No modifiers (base rules) | MATCH |
| CHALLENGING | N/A in JSON | Reroll enemy dice 1-2 | CODE-ONLY |
| HARDCORE | Contact +1, Encounter +1 | +1 enemy, +2 invasion, -2 init, etc. | DIGITAL ADAPTATION |
| INSANITY | Contact +1, Encounter +1, spawning rule | +1 specialist, +3 invasion, story disabled | DIGITAL ADAPTATION |

**Conclusion**: The tabletop rules describe physical miniature mechanics (Contact markers, Encounter numbers) that don't map 1:1 to a digital campaign manager. The `DifficultyModifiers.gd` implementation correctly adapts these to campaign-level equivalents. **No bugs here.**

**Note**: Enum values HARD (3), NIGHTMARE (5), ELITE (7) exist in GlobalEnums but are unused in DifficultyModifiers. These are dead code but harmless.

---

## Weapon Data (12 verified)

Three separate weapon databases exist with **no synchronization**:

1. `data/RulesReference/EquipmentItems.json` — Tabletop reference (12 weapons, rules-accurate)
2. `data/weapons.json` — Core rules compendium (37 weapons, uppercase traits)
3. `data/equipment_database.json` — Game-specific (10 weapons, balanced for gameplay)

### Key Stat Divergences

| Weapon | Rules Range/Shots/DMG | weapons.json | equipment_database.json |
|--------|----------------------|--------------|----------------------|
| Shotgun | 12/2/1 [Focused] | 12/2/1 [FOCUSED] | 12/2/3 [Spread, Knockback] |
| Sniper Rifle | 40/1/1 [Aimed] | 30/1/0 [] | 36/1/3 [Accurate, Scope] |
| LMG | 36/3/1 [Heavy] | 24/3/1 [HEAVY] | N/A |
| Plasma Rifle | 20/2/1 [Focused, Piercing] | 20/1/2 [CRITICAL] | N/A |

### Trait Naming Inconsistency
- Rules JSON: Title Case (`Pistol`, `Focused`, `Aimed`)
- weapons.json: UPPERCASE (`FOCUSED`, `MELEE`, `HEAVY`)
- equipment_database.json: Mixed (`Rapid Fire`, `Accurate`, `Knockback`)

**Resolution (Mar 21)**: Both `weapons.json` and `equipment_database.json` rewritten from Core Rules p.50. All 36 weapons matched exactly. Trait names normalized to Title Case per book (not UPPERCASE). Old invented weapons (Assault Rifle, Gauss Rifle, etc.) removed. This is a tabletop companion app — all data must match the book exactly.

---

## Campaign Structure (9 verified — all match)

The 9-phase campaign turn structure matches the RulesReference/Campaign.json:
- STORY, TRAVEL, UPKEEP, MISSION, POST_MISSION, ADVANCEMENT, TRADING, CHARACTER, RETIREMENT
- Mission types (Patron, Opportunity, Rival, Invasion) match
- Economy elements (Credits, Story Points, Reputation) match
- Victory conditions (Turns, Character, Story, Goals) match

---

## Mechanics Not Verifiable via JSON

The following categories have **no RulesReference JSON data** to cross-reference against:

- Loot tables and drop rates (14 mechanics)
- Post-battle injury/casualty tables (part of 49 campaign mechanics)
- Advancement XP costs and stat caps (part of 49 campaign mechanics)
- Specific battle event triggers and outcomes (8 mechanics)
- Compendium DLC mechanics beyond psionics/factions (35 mechanics)

These require the physical Five Parsecs from Home Core Rules book for true RULES_VERIFIED status.

---

## Data Files Audit Status (Mar 21)

| File | Status | Issue |
|------|--------|-------|
| `weapons.json` | **FIXED** | Rewritten from Core Rules p.50 (36 weapons) |
| `equipment_database.json` | **FIXED** | Weapons section rewritten from Core Rules p.50 |
| `armor.json` | **FIXED** | Rewritten with 9 Core Rules protective devices (pp.54-55): 5 armor + 4 screens |
| `implants.json` | **FIXED** | Rewritten with 11 Core Rules implants (p.55). MAX_IMPLANTS changed 3→2 |
| `consumables.json` | **NEW** | 6 Core Rules consumables (p.54) with exact book effects |
| `utility_devices.json` | **FIXED** | Rewritten with all 20 Core Rules utility devices (pp.56-57) |
| `onboard_items.json` | **NEW** | 19 Core Rules on-board items (pp.57-58) |
| `weapon_modifications.json` | **FIXED** | Rewritten with 8 gun mods + 5 gun sights (p.53) from book |
| `loot_tables.json` | **FIXED** | Full weapon/gear/odds subtables matching pp.131-133 D100 entries |
| `gear_database.json` | **NEEDS AUDIT** | Species data partially accurate, gear items unverified |
| `enemy_types.json` | **NEEDS AUDIT** | Unverified against Bestiary |
| `injury_table.json` | **NEEDS AUDIT** | Unverified against Core Rules injury table |
| `character_species.json` | **NEEDS AUDIT** | May duplicate/conflict with SpeciesList.json |

### Code Wiring Status (Mar 21)

| Code File | Status | Changes |
|-----------|--------|---------|
| `Character.gd` | **FIXED** | MAX_IMPLANTS=2, 11 book IMPLANT_TYPES, LOOT_TO_IMPLANT_MAP rewritten |
| `LootSystemConstants.gd` | **FIXED** | CONSUMABLE_ITEMS rewritten (6 book items), all subtable item lists updated |
| `EquipmentPickerDialog.gd` | **FIXED** | Default equipment updated to book-accurate items |
| `test_equipment_classes.gd` | **FIXED** | Implant tests rewritten for book-accurate types |
| `test_loot_gear_and_odds.gd` | **FIXED** | Validation lists updated for all 9 armor + 11 implants |
| `LootSystemHelper.gd` | **FIXED** | Item lists updated for consumables/implants |

### Compendium DLC Audit Status (Mar 21)

| Compendium Section | Code File | Status | Changes |
|--------------------|-----------|--------|---------|
| Species (Krag, Skulker) | `compendium_species.gd` | **VERIFIED** | Stats match book pp.14-18 |
| Advanced Training (5) | `compendium_equipment.gd` | **VERIFIED** | All 5 courses match book p.27 |
| Bot Upgrades (6) | `compendium_equipment.gd` | **FIXED** | Jump Module description corrected (Dash allowed, not forbidden) |
| New Ship Parts | `compendium_equipment.gd` | **FIXED** | Replaced 7 invented parts with 2 book components + 1 mod (p.29) |
| Psionic Equipment | `compendium_equipment.gd` | **FIXED** | Replaced 5 invented items with 3 book items (p.29) |
| Difficulty Toggles | `compendium_difficulty_toggles.gd` | **NOT AUDITED** | Needs verification against pp.34-36 |
| No-minis Combat | `compendium_no_minis.gd` | **NOT AUDITED** | Needs verification against pp.68-75 |
| Expanded Missions | `compendium_missions_expanded.gd` | **NOT AUDITED** | Needs verification against pp.76-88 |
| World Options | `compendium_world_options.gd` | **NOT AUDITED** | Needs verification |

## Recommendations

1. ~~**Fix species bugs (BUG-036/037/038)**~~ — BUG-037/038 FIXED. BUG-036 RESOLVED (not a bug)
2. ~~**Fix weapon data**~~ — DONE. All weapons match Core Rules p.50
3. ~~**Rewrite armor.json**~~ — DONE. 9 protective devices from pp.54-55
4. ~~**Expand loot_tables.json**~~ — DONE. Full D100 entries from pp.131-133
5. **Audit remaining data files** — enemy_types.json, injury_table.json, character_species.json
6. **Audit remaining Compendium data** — difficulty toggles, no-minis, expanded missions, world options
7. **Physical book review needed** for remaining ~137 mechanics
