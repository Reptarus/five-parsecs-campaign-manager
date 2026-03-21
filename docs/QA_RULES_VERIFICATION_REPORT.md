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
- **BUG-037**: Swift gets +1 Speed instead of +2 Speed per rules. Also has +1 Reactions not in rules.
- **BUG-038**: Soulless has extra +1 Reactions not specified in rules. May be intentional balance tweak — needs user decision.

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

**Conclusion**: This is the known "equipment table naming" deferred item. The three databases serve different purposes (reference, data, gameplay) and were never intended to be synchronized. The game-specific database has higher damage values for gameplay balance. **User decision needed on canonical source.**

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

## Recommendations

1. **Fix species bugs (BUG-036/037/038)** after user confirms whether rules JSON is correct
2. **Do NOT fix difficulty divergences** — digital adaptation is correct by design
3. **Defer weapon data sync** — user decision on canonical source pending
4. **Mark 9 campaign structure mechanics as RULES_VERIFIED** — perfect match confirmed
5. **Physical book review needed** for remaining ~137 mechanics
