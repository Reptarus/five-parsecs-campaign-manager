# Five Parsecs From Home: Tactics - Expansion Notes

**Status**: Pre-implementation research (pending Modiphius approval)
**Source**: Five Parsecs From Home - Tactics [MUH084V041]
**Full text extraction**: `docs/rules/tactics_source.txt` (212 pages)
**PDF location**: `docs/Five Parsecs From Home - Tactics.pdf`
**Last Updated**: 2026-03-30

---

## Executive Summary

Tactics is a **scenario-driven miniatures wargame** set in Unified Space — much closer to traditional wargames (OPR, WH40K) than the adventure game loop of 5PFH. It features:

- **Points-based army building** (500/750/1000 pts) with platoon/company organization
- **Squad-based combat** (4-5 soldiers per squad + sergeant) instead of individual characters
- **Vehicles**: Bikes, APCs, IFVs, Light/Medium/Heavy tanks, Walkers, Combat Bots
- **Full species army lists**: 7 Major Powers + 7 Minor Powers + 6 Creatures, each with complete profiles
- **Three play modes**: Solo (with AI system), GM-directed scenarios, Head-to-head pick-up games
- **Operational campaign system**: Map-based strategic layer with Army Strength, Cohesion, and Operational Zones
- **Story generation system**: D100 campaign events (reinforcements, betrayals, new characters, etc.)
- **Full cross-compatibility** with 5PFH character transfer rules

This is fundamentally a **different game type** from 5PFH/Bug Hunt/Planetfall. Those are adventure wargames (procedural solo campaigns with character progression). Tactics is a **traditional wargame with campaign support** (army lists, points, scenarios, vehicles, platoons).

---

## 1. Game Scale Comparison

| Feature | 5PFH | Bug Hunt | Planetfall | **Tactics** |
|---------|------|----------|-----------|-------------|
| Scale | Man-to-man skirmish | Man-to-man skirmish | Man-to-man skirmish | **Squad/Platoon/Company** |
| Typical Force | 6-8 individuals | 6 + fireteam | 6 + grunts | **20-40+ figures** |
| Vehicles | No | No | No | **Yes (bikes to heavy tanks)** |
| Points System | No | No | No | **Yes (500-1000 pts)** |
| Army Lists | No | No | No | **Yes (14 species)** |
| Play Style | Solo adventure | Solo adventure | Solo adventure | **Solo/GM/Versus** |
| Unit Organization | Individual characters | Individual + fireteam | Individual + grunts | **Squads (4-5 + sergeant)** |

---

## 2. Troop Profiles

### Profile Stats
Tactics uses the same base stats as 5PFH plus two additional ones:

| Stat | Description | Notes |
|------|-------------|-------|
| Speed | Movement in inches | Same as 5PFH |
| Reactions | Initiative/alertness | Same as 5PFH |
| Combat Skill | Weapons training bonus | Same as 5PFH |
| Toughness | Damage resistance | Same as 5PFH |
| Kill Points (KP) | Damage capacity | **Replaces "wounds"** — vehicles have 2-8 KP |
| Savvy | Wits/tech aptitude | Same as 5PFH |
| **Training** | **NEW** — Military competence | Used for tests, morale, and tactical actions |

### Profile Tiers (per species)
Each species has 5 profile tiers:
1. **Civilian** — untrained
2. **Military** — standard soldier
3. **Sergeant / Minor Character** — squad leader
4. **Major Character** — experienced officer
5. **Epic Character** — elite hero

### Human Profiles (reference)
| Tier | Speed | React | Combat | Tough | KP | Savvy | Training | Cost |
|------|-------|-------|--------|-------|-----|-------|----------|------|
| Civilian | 4" | 1 | +0 | 3 | 1 | +0 | +0 | 5 |
| Military | 4" | 2 | +1 | 3 | 1 | +0 | +1 | 10 |
| Sergeant/Minor | 4" | 2 | +1 | 3 | 2 | +0 | +1 | 15 |
| Major | 4" | 2 | +2 | 3 | 2 | +0 | +2 | 20 |
| Epic | 5" | 3 | +2 | 4 | 3 | +1 | +2 | 30 |

---

## 3. Species / Lifeforms (Army Lists)

### Major Powers (7)

| Species | Special Rules | Cost Range |
|---------|--------------|------------|
| **Humans** | Widely Skilled (+1 communication), Well Organized (lower Support arrival) | 5-30 |
| **Ferals** | Loping Run (+3" Dash), Keen Senses (+1 Observation) | 6-32 |
| **Hulkers** | Determined (+1 Morale), Powerful Swings (fist attacks), Short Tempered | 15-40 |
| **Erekish (Precursors)** | Premonition (6+ Save for individuals/sergeants) | 6-35 |
| **K'Erin** | Brawlers (2 close assault attacks), Disciplined (+1 Morale) | 8-35 |
| **The Soulless** | Synthetic, Machine Learning, Hardened Network (3+ vs hacking). Single profile for all. Standard cost: 20 | 20 (flat) |
| **The Converted** | Synthetic, Mindless Assault (no Morale, Dash into melee) | 10-35 |
| **The Horde** | Fearsome (Fear), Horde Tactics (merge squads), Uncaring (survive Morale fail) | 6-30 |

### Minor Powers (7)

| Species | Special Rules | Cost Range |
|---------|--------------|------------|
| **Serian (Engineers)** | Tech-savvy (reroll tech tests), Enviro-suits (immune to gas/toxins) | 7-32 |
| **The Swift** | Bonds of Inspiration (remove Suppression on 6s), Winged (descend safely) | 6-32 |
| **Keltrin (Skulkers)** | Lurk (reroll failed Observation vs Skulkers), Ambush | 6-32 |
| **Hakshan** | (standard profile, no notable special rules listed) | 5-30 |
| **Clones (The Many)** | Mass Produced, Expendable | 8-40 |
| **Ystrik (Manipulators)** | Psionic abilities | 5-27 |
| **Krag (Dwarves)** | Sturdy, Resilient | 5-30 |

### Creatures (6)

| Creature | Notes |
|----------|-------|
| The Swarm | Horde-type alien insects |
| Razor Lizard | Dangerous reptilian |
| Gene-dog | Engineered canine |
| Sand Runner | Desert predator |
| Krorg | Large beast |
| Brute Lizard | Heavy creature |

---

## 4. Combat Rules (vs 5PFH differences)

### Turn Structure
```
Battle Round:
  Phase 1: Initiative (D6 per unit, alternating activations)
  Phase 2: Activations (move/shoot/actions per unit)
  Phase 3: End Phase (morale, suppression cleanup)
```

### Key Mechanical Differences from 5PFH

| Mechanic | 5PFH | Tactics |
|----------|------|---------|
| Activation | Reaction Roll → Quick/Slow phases | **Initiative dice → alternating unit activations** |
| Suppression | Stun/Sprawl markers | **Suppression markers** (accumulate, reduce actions) |
| Morale | Panic range check | **Morale tests** with Exhaustion + Retreat rules |
| Close Combat | Brawling (D6 + Combat) | **Close Assault** (charge, defender fires, melee roll) |
| Saving Throws | Armor value check | **Saving Throw** (species/equipment specific, stackable) |
| Observation | Line of Sight only | **Observation Tests** (spot hidden enemies, D6 + modifiers) |
| Indirect Fire | N/A | **Full indirect fire rules** (off-map units, communications, deviation) |
| Overwatch | N/A | **Overwatch** (delayed activation to fire at moving enemies) |
| Flanking | N/A | **Flanking Fire** (+1 Hit bonus from side/rear) |
| Vehicles | N/A | **Full vehicle combat** (Toughness, turrets, transports, walkers) |
| Squad Coherency | N/A | **4" coherency** (squad must stay within distance) |
| Delaying | N/A | **Can delay activation** to act later in round |

### Damage Resolution
1. Roll to Hit: D6 + Combat Skill ≥ target number (modified by cover, range, movement)
2. Saving Throw: If applicable (armor, abilities), D6 ≥ threshold negates hit
3. Roll for Damage: D6 + Weapon Damage vs Toughness — exceed = 1 KP lost
4. KP = 0 → figure removed

### Suppression System
- Taking fire (even if no damage) can add Suppression markers
- Suppressed units: -1 to Hit, can't advance toward enemy
- Heavy suppression: Unit may only remove suppression or fall back
- Removed by: Activation action, Medic ability, or end of round

### Morale
- Test when: >50% casualties in squad, leader killed, Fear creatures nearby
- Roll: D6 + Training + modifiers
- Fail → Exhaustion (can't advance) or Retreat (fall back toward table edge)

---

## 5. Army Building System

### Organization Structure
```
Company (2-4 platoons)
  ├── Leaders (0-4 characters, max = platoon count)
  ├── Platoons (regular or armored)
  │   ├── Leader (1 character, any level)
  │   ├── Troops (2-5 squads)
  │   │   ├── Infantry (4 soldiers + sergeant, 27 pts base)
  │   │   ├── Recon (4 soldiers + sergeant, 23 pts base)
  │   │   └── Storm (4 soldiers + sergeant, 28 pts base)
  │   ├── Supports (0-4, fewer than troops)
  │   │   ├── Weapon Teams (3 soldiers + crewed weapon)
  │   │   └── Vehicles
  │   └── Specialists (0-2, one of each type)
  │       ├── Tech (repair/hack)
  │       ├── Sharpshooter (+1 to Hit)
  │       ├── Fire Section (2 soldiers + heavy weapon)
  │       ├── Comms (+1 communications/support calls)
  │       ├── Medic (remove Suppression)
  │       └── Scout (+2 Observation, +1" Speed)
  └── Supports (0-4, max = platoon count)
```

### Points Scale
| Game Size | Points | Typical Force |
|-----------|--------|---------------|
| Small/Learning | 500 | ~1 platoon |
| Standard | 750 | Sizable force |
| Large | 1000 | Full evening game |

### Mixed Armies
- Pick-up games: Max 2 faction types
- Scenario play: Any combination that makes narrative sense

---

## 6. Vehicle System

### Vehicle Categories

#### Light Vehicles
| Vehicle | Speed | Tough | KP | Crew | Cap | Cost | Weapons |
|---------|-------|-------|-----|------|-----|------|---------|
| Nomad Bike | 12" Wheeled | 6 | 2 | 1 | 0 | 15 | Unarmed (opt LMG +10) |
| Scouter | 16" Drifter | 5 | 2 | 1 | 0 | 35 | Forward LMG |
| Lancer | 12" Drifter | 5 | 2 | 1 | 0 | 30 | Forward plasma rifle |
| Frontier Trike | 10" Wheeled | 6 | 3 | 2 | 0 | 35 | LMG |
| Raider Trike | 15" Wheeled | 5 | 3 | 2 | 0 | 35 | LMG |

#### Fighting Vehicles
| Vehicle | Speed | Tough | KP | Crew | Cap | Cost | Main Weapon |
|---------|-------|-------|-----|------|-----|------|-------------|
| Armored Car | 9" Wheeled | 7 | 5 | 2 | 0 | 60 | 20mm autocannon |
| APC | 8" Tracked | 7 | 5 | 2 | 10 | 50 | LMG |
| APC (Grav) | 9" Drifter | 7 | 4 | 2 | 8 | 55 | LMG |
| IFV | 8" Tracked | 7 | 5 | 3 | 6 | 70 | 20mm autocannon |
| IFV (Grav) | 9" Drifter | 7 | 4 | 3 | 5 | 75 | 20mm autocannon |
| Light Tank | 8" Tracked | 8 | 6 | 4 | 0 | 100 | 40mm autocannon |
| Light Tank (Grav) | 7" Drifter | 8 | 6 | 4 | 0 | 115 | 40mm autocannon |
| Medium Tank | 7" Tracked | 9 | 7 | 4 | 0 | 140 | 100mm cannon |
| Medium Tank (Grav) | 8" Drifter | 9 | 6 | 4 | 0 | 150 | 100mm cannon |
| Heavy Tank | 6" Tracked | 10 | 8 | 5 | 0 | 200 | 100mm cannon |
| Light Walker | 5" Walker | 8 | 4 | 1 | 0 | 70 | 20mm + flame projector |
| Heavy Walker | 4" Walker | 8 | 5 | 1 | 0 | 100 | Pulse laser + LMG |

#### Heavy Combat Bots (AI-driven, no crew)
| Vehicle | Speed | Tough | KP | Cost | Weapons |
|---------|-------|-------|-----|------|---------|
| CIM-L "Demon" | 6" Walker | 7 | 9 | 35 | Hyper blaster |
| CIM-APP "Troll" | 4" Walker | 8 | 4 | 45 | 20mm autocannon |

### Vehicle Movement Types
- **Wheeled**: Standard movement, limited by terrain
- **Tracked**: Better terrain handling
- **Drifter (Grav)**: Hover vehicles, ignore some terrain
- **Walker**: Can traverse difficult terrain, special close assault rules

### Vehicle Combat
- **Firing from vehicles**: Turret (360°), Front mount (forward arc), Coaxial (with turret)
- **Firing at vehicles**: Hit → D6 + Damage vs Toughness → reduce KP
- **Vulnerable angles**: Side/rear shots easier
- **Target the Tracks!**: Optional called shot to immobilize
- **Transports**: Carry capacity, dismounting rules, firing ports

---

## 7. Weapons System

### Weapon Categories (6)

#### Melee Weapons
| Weapon | Damage | Traits | Cost |
|--------|--------|--------|------|
| Blade | 1 | Melee | 1 |
| Glare Sword | 1 | Melee, Elegant | 2 |
| Powered Claw | 3 | Melee, Clumsy, Piercing | 3 |
| Breaching Axe | 3 (x2 vs vehicles) | Melee, Clumsy, Knock Back | 4 |
| Suppression Maul | 0 | Melee, Stun | 1 |
| Ripper Sword | 2 | Melee, Piercing | 3 |

#### Grenades
| Weapon | Damage | Traits | Cost |
|--------|--------|--------|------|
| Frag | 0 | Area | 1 |
| Penetrator | 3 | Piercing, Knock Back | 2 |
| Jinx | 5 | Lock On, Destructive | 3 |
| Fog | - | Area, Gas, Fog | 1 |
| Cling-fire | 0 | Area, Burn | 2 |
| Shock | - | Area, Shock | 1 |

#### Sidearms
| Weapon | Range | Shots | Damage | Traits | Cost |
|--------|-------|-------|--------|--------|------|
| Service Pistol | 9" | 1 | 0 | Pistol | 1 |
| Hand Laser | 9" | 1 | 0 | Pistol, Snap Shot | 2 |
| Blast Pistol | 8" | 1 | 1 | Pistol | 2 |

#### Rifles
| Weapon | Range | Shots | Damage | Traits | Cost |
|--------|-------|-------|--------|--------|------|
| Military Rifle | 24" | 1 | 0 | - | 3 |
| Infantry Laser | 30" | 1 | 0 | Snap Shot | 4 |
| Precision Rifle | 36" | 1 | 1 | Critical, Sniping | 6 |
| Blaster | 18" | 1 | 1 | - | 3 |
| Shotgun | 12" | 1 | 0 | Critical | 2 |

#### Team Weapons
| Weapon | Range | Shots | Damage | Traits | Cost |
|--------|-------|-------|--------|--------|------|
| Light Machine Gun | 30" | 3 | 0 | Heavy, Team | 10 |
| Flak Gun | 12" | 2 | 1 | Focused, Shrapnel, Team | 5 |
| Grenade Launcher | 24" | - | - | Launcher, Heavy, Team | 10+grenades |
| Fury Rifle | 24" | 1 | 3(x2) | Heavy, Piercing, Knock Back, Team | 15 |
| Plasma Rifle | 20" | 2 | 1 | Focused, Piercing, Overheat, Team | 8 |
| Sniper Rifle | 40" | 1 | 1(x2) | Heavy, Piercing, Sniping, Team | 10 |
| Hyper Blaster | 24" | 3 | 1 | Overheat, Team | 14 |
| Flame Projector | 6" | Stream | 1 | Stream, Burn, Team | 6 |
| Fusion Rifle | 15" | 1 | 3(x2) | Piercing, Team | 10 |

#### Crewed Weapons
| Weapon | Range | Shots | Damage | Traits | Cost |
|--------|-------|-------|--------|--------|------|
| Laser Cannon | 48" | 1 | 5(x3) | Crewed | 35 |
| Pulse Laser | 36" | 2 | 4(x2) | Crewed | 35 |
| Anti-tank Laser | 60" | 1 | 6(x3) | Pin-point, Crewed | 45 |
| Anti-tank Missile | 12"-96" | 1 | 4(x4) | Min Range, Lock On, Crewed | 30 |
| 20mm Autocannon | 36" | 3 | 2 | Crewed | 20 |
| 40mm Autocannon | 48" | 2 | 3 | Crewed | 25 |
| Infantry Mortar | 12"-48" | 1 | 1 | Area, Indirect, Crewed | 15 |
| Heavy Plasma Gun | 24" | 1 | 4 | Area, Burn, Crewed | 20 |
| 75mm Cannon | 60" | 1 | - | Ammo Choice, Crewed | 45 |
| 100mm Cannon | 72" | 1 | - | Ammo Choice, Crewed | 55 |

### Weapon Trait Definitions (25 traits)
Area, Ammo Choice, Burn, Clumsy, Crewed, Critical, Destructive, Elegant, Focused, Fog, Gas, Heavy, Indirect, Knock Back, Launcher, Limited Supply, Lock On, Melee, Minimum Range, Overheat, Piercing, Pin-point, Pistol, Shock, Shrapnel, Snap Shot, Sniping, Stream, Stun, Team, Weak

---

## 8. AI / Solo Combat System

### AI Core Principles
- Lightweight guidelines-based system (not flowcharts)
- AI units try to: Take cover, shoot closest visible target, advance if safe
- **AI Roll**: D6 determines specific action from context-dependent options

### AI Battle Plan System
- Pre-game: Assign an overall battle plan to AI force
- Options: Aggressive, Defensive, Flanking, etc.
- Modifies AI unit behavior within the guidelines

### Solo Difficulty Adjustments
- Stronger Enemy Squads
- Heroic Activation (player gets bonus activations)
- Free Targeting
- Morale Failure Cap (prevents AI army from routing too fast)

### Random Enemy Forces
- System to generate opposition based on player force size
- Scales from small patrols to full platoons

---

## 9. Campaign System

### Three Campaign Subsystems

#### A. Operational System (Strategic Layer)
```
Map → Regions → Operational Zones → Army Strength → Combat Dice
```
- **Cohesion**: Faction will-to-fight (starts ~5, reaches 0 = defeat)
- **Army Strength**: Per-zone force level (D6-based)
- **Operational Turn** (8 steps):
  1. Play tabletop battles
  2. Apply Player Battle Points (PBP, 1 per win)
  3. Resolve Operational Combat (dice pool system)
  4. Operational Orders (D6 table: Construct Defense, Continued Offensive, New Offensive, etc.)
  5. Commando Raids (spend PBP to damage enemy Army Strength)
  6. Redeploy Forces
  7. Open new Zones, select new Focus
  8. Choose player commitments
- **Special Regions**: Defensible (+1 Combat Die), Critical (Cohesion impact), Urban (costly to lose)

#### B. Campaign Story Generation
- D100 story event table with 20+ event types
- Events include: Reinforcements, Critical Strike, New Character, Flashback, Balance Shifting, Shortfall, New Ally, Betrayal, Environmental Change, Political Events, etc.
- Each event has Player Effects + Operational Effects
- Pacing: Roll every 1-3 tabletop battles

#### C. Campaign Progression
- **Campaign Points (CP)**: Earned per battle
  - 1 CP per battle fought
  - +1 CP for victory
  - +1 CP for completing secondary objectives
- **Spending CP**:
  - Unit Upgrades (veteran skills)
  - Roster Changes (add/replace units)
  - Battle Advantages (one-time bonuses for next battle)
- **Unit Losses**: Simplified post-battle attrition system

### Veteran Skills
Squads, sergeants, individuals, and vehicles each have separate skill lists.
- Acquired through Campaign Progression or pick-up game rules (+10% cost)
- Examples: Covering Fire, Fire and Move, Hardened, Marksmen, Stealthy, Aggressive, etc.

---

## 10. Scenario System

### Four Scenario Types

| Scenario | Scale | Description |
|----------|-------|-------------|
| Skirmish | Small | Quick engagement, 2-3 squads per side |
| Battle | Medium | Standard engagement, full platoon |
| Grand Battle | Large | Multiple platoons, vehicles, heavy weapons |
| Evolving Objective | Variable | Objectives change during battle |

### Secondary Objectives (optional)
- Hold terrain feature, capture enemy leader, preserve specific unit, etc.
- Provide additional Victory Points and Campaign Progression bonuses

### 100 Scenario Seeds
- D100 table with creative scenario concepts
- Covers everything from ambushes to evacuations to alien encounters

### Victory Points
- Objective-based scoring system
- Different from 5PFH's binary win/lose

---

## 11. Special Rules & Scenario Components

### GM Toolkit (20+ components)
| Component | Description |
|-----------|-------------|
| Chemical Hazards | Toxic areas on battlefield |
| Communications | Comms tests for calling support |
| Concealed Units | Hidden deployment |
| Confusion | Fog of war effects |
| Construction | Building/repairing in-game |
| Dangerous Terrain | Terrain that damages units |
| Demolition | Destroying structures |
| Doors/Entrances | CQB rules |
| Dwindling Ammo | Ammunition tracking |
| Gas/Smoke Clouds | Area denial |
| Landmines | Mine placement and clearance |
| Limited Visibility | Reduced sight ranges |
| Negotiating | Non-combat resolution |
| Reinforcements | Mid-battle arrivals |
| Research | Science objectives during battle |
| Rivalries | Inter-unit tensions |
| Searching | Looking for items/intel |
| Securing Areas | Holding territory |
| Suspicion | Stealth/detection |
| Taming Beasts | Creature control |

### Battlefield Support System
- Off-map assets (artillery, air support, orbital strikes)
- D6 roll to call in support each round
- Types: Artillery barrage, Air strike, Medical evacuation, Reinforcement drop, Electronic warfare, Orbital bombardment

---

## 12. Character Conversion Rules (5PFH ↔ Tactics)

### Transfer Guidelines
| Stat | 5PFH → Tactics | Tactics → 5PFH |
|------|---------------|----------------|
| Reactions | Same | Same |
| Speed | Same | Same |
| Combat Skill | Capped at +2 | No change |
| Toughness | Capped at 5 | No change |
| Savvy | Same | Same |
| Training | +1 (or +2 if military background) | N/A |
| KP/Luck | Each Luck → 1 KP | Each KP after 1st → 1 Luck |

### Combining Games
- 5PFH crew act as individual characters in Tactics
- Tactics squads become individual figures in 5PFH
- Injury rolls and XP awarded normally to crew in Tactics battles
- Can integrate a 5PFH campaign with Tactics grand battles

---

## 13. Architecture: Tabletop Companion on Musica Tactica Scaffold

### Data Integrity Rule

> **The 5PFH Tactics rulebook is the CANONICAL AUTHORITY for all Tactics game mechanics.** Every stat, points cost, weapon profile, species ability, and army organization rule MUST come from the Tactics PDF (`docs/rules/tactics_source.txt`). The Musica Tactica codebase provides structural patterns only — never copy AoF game values into the Tactics companion. Same data integrity workflow as FPCM: extract from book → store in JSON → wire to consumers → cite page numbers in commits.

### Approach: Tabletop Companion App

The Tactics companion is a **tabletop manager** — same philosophy as FPCM (companion assistant for physical tabletop play, not a video game or tactical simulator). It is built on the **Musica Tactica GDScript foundation** (`c:\Users\admin\Desktop\tacticaprototype1\`), which already implements the right game paradigm: squad-based wargaming with points, army lists, alternating activations, and campaign progression.

**Musica Tactica provides the structural scaffold** (Resource class shapes, validation patterns, activation state machines, campaign persistence). All game data values — stats, weapons, points costs, species profiles, army org rules — come exclusively from the Tactics rulebook.

### Companion Features (to build)

| Feature | Description |
|---------|-------------|
| **Army Builder** | Points calculator (500/750/1000), squad configuration, weapon selection, platoon/company org validation, printable unit cards |
| **Battle Tracker** | Activation checklist (who's acted this round), round counter, suppression/morale markers per unit, KP tracking |
| **Dice Roller + Resolver** | Rules-accurate hit/damage/save resolution with all modifiers (cover, flanking, height, etc.), result display |
| **Quick Reference** | Weapon stats lookup, trait definitions, species abilities, vehicle profiles — searchable |
| **Campaign Tracker** | Operational map with regions/zones, Cohesion/Army Strength tracking, story event generation, CP spending |
| **Roster Manager** | Persistent army roster across campaign, veteran skill tracking, unit losses between battles |
| **Scenario Generator** | Random scenario type, deployment method, objectives, battlefield conditions, secondary objectives |
| **Character Transfer** | Convert 5PFH characters ↔ Tactics profiles per appendix rules (p.184) — bridges FPCM and Tactics companion |

### What the Tactica Scaffold Provides vs What Changes

**Scaffold (keep structure, replace content with Tactics rulebook data):**

| Tactica System | Tactics Companion Use | What Changes |
|---|---|---|
| `UnitProfile.gd` Resource shape | Squad/unit data model | Fields: `quality`/`defense` → `reactions`/`combat_skill`/`toughness`/`kp`/`savvy`/`training` (p.26) |
| `WeaponProfile.gd` Resource shape | Weapon data model | Fields: `attacks`/`ap` → `range`/`shots`/`damage`/`traits` (p.174-179) |
| `SpecialRule.gd` Resource shape | Species abilities + veteran skills | Content from Tactics rulebook (p.47-50, 150-151) |
| `ArmyCompositionValidator` | Points validation + org rules | Rules: AoF hero-per-375 → Tactics platoon org: 2-5 troops, 0-4 supports, 0-2 specialists (p.136-137) |
| `ArmyList` Resource | Army roster persistence | Same pattern, different constraints |
| `ActivationManager` | Turn/activation tracking | Token bag → initiative dice alternating activations (p.28-29) |
| `CampaignManager` | Campaign progression state | AoF XP/leveling → CP/veteran skills (p.108-110) |
| `MissionGenerator` + modifiers | Scenario generation | Swap AoF missions for Tactics scenario types (p.76-90) + GM components (p.121-133) |
| Army book JSON format | Species army data | 17 AoF fantasy factions → 14 Unified Space species (p.154-173) |
| `PreBattleSetup` / `PostBattleResults` scene flow | Pre/post-battle UI flow | Same UX pattern, different data |
| `SceneManager` routing | Scene transitions | Same pattern |
| `Faction.gd` Resource | Species faction data | Swap fantasy factions for Unified Space species |

**Strip (video game layer, not needed for tabletop companion):**
- `BattlefieldManager` grid/terrain/spawning — physical tabletop handles this
- `TacticalUnit` CharacterBody3D — no 3D unit representation, just data cards
- HD-2D visual pipeline (SpriteMeshBaker, SquadFormations, sprite sheets) — no rendering
- `SelectionManager` raycasting — no click-to-select on 3D scene
- `LineOfSightManager` — player handles LOS on physical table
- `GameStateMachine` phase transitions — replaced by checklist/tracker UI
- AI behavior trees (`TacticalAIBrain`, `bt_tasks/`) — player uses rulebook AI tables, companion just references them
- Cutscene/screenplay system — not applicable
- `OctagonalCameraController` — no 3D camera

### New Data Files Needed (JSON)
All values extracted from Tactics rulebook with page citations:
```
data/tactics/
  ├── species_profiles.json        # 14+ species, 5 tiers each (p.154-173)
  ├── weapons_melee.json           # 6 melee weapons (p.177)
  ├── weapons_grenades.json        # 6 grenade types (p.177)
  ├── weapons_sidearms.json        # 3 sidearms (p.177)
  ├── weapons_rifles.json          # 5 rifle types (p.178)
  ├── weapons_team.json            # 9 team weapons (p.178)
  ├── weapons_crewed.json          # 10 crewed weapons (p.179)
  ├── weapon_traits.json           # 25+ trait definitions (p.174-175)
  ├── vehicles_light.json          # 5 light vehicles (p.145)
  ├── vehicles_fighting.json       # 12 fighting vehicles (p.146-148)
  ├── vehicles_bots.json           # 2 combat bots (p.149)
  ├── squad_types.json             # Infantry/Recon/Storm + alternatives (p.139-142)
  ├── specialist_types.json        # Tech/Sharpshooter/Fire Section/etc. (p.140-142)
  ├── veteran_skills.json          # Per unit-type skill lists (p.150-153)
  ├── scenario_seeds.json          # 100 scenario seeds (p.86-90)
  ├── story_events.json            # D100 campaign story events (p.104-106)
  ├── operational_orders.json      # D6 operational orders table (p.100)
  ├── support_types.json           # Battlefield support options (p.67-70)
  ├── powered_armor.json           # Armor types and saves (p.179)
  ├── creatures.json               # 6 creature profiles (p.170-173)
  ├── secondary_objectives.json    # Optional objective types (p.84-85)
  ├── character_conversion.json    # Transfer rules data (p.184)
  ├── points_master.json           # Master points costs table (p.180-183)
  └── scenario_components.json     # 20+ GM toolkit components (p.121-133)
```

---

## 14. Key Differences Summary: All Four Games

| Aspect | 5PFH | Bug Hunt | Planetfall | Tactics |
|--------|------|----------|-----------|---------|
| Campaign Type | Open-ended adventure | Military operation | Colony building | War campaign |
| Unit Scale | Individual | Individual + fireteam | Individual + grunts | Squad (4-5) |
| Vehicles | None | None | None | Full (bikes to tanks) |
| Points System | None | None | None | 500-1000 pts |
| Economy | Credits | None | RP/BP/Raw Materials | Campaign Points |
| Map | Multi-planet | None | 6x6 grid (single planet) | Operational regions |
| Character Progression | XP → abilities | None for grunts | XP → stat increases | CP → veteran skills |
| Enemies | Generated tables | Bug Hunt bestiary | Procedural lifeforms | Army lists |
| Combat Engine | 5PFH core | 5PFH core | 5PFH core (modified) | **Expanded 5PFH** (suppression, vehicles, squads) |
| Play Modes | Solo | Solo | Solo/Co-op/GM | Solo/Versus/GM |
| Turn Structure | 9-phase campaign | 3-stage campaign | 18-step campaign | 8-step operational |

---

## 15. Musica Tactica Scaffold Assessment

### Why Tactica Is the Right Foundation

Musica Tactica (`c:\Users\admin\Desktop\tacticaprototype1\`) is a Godot 4.6 tactical RPG implementing OPR Age of Fantasy rules. While the **rules content** is entirely different (AoF fantasy vs 5PFH sci-fi), the **structural patterns** are a near-1:1 match for what the Tactics companion needs:

| Paradigm | Musica Tactica | Tactics Companion |
| -------- | -------------- | ----------------- |
| Unit scale | Squads (5-20 models) | Squads (4-5 + sergeant) |
| Points system | Yes (AoF points) | Yes (500/750/1000 pts) |
| Army org | AoF hero/troop/support slots | Platoon: leader/troops/supports/specialists |
| Activation | Alternating (token bag) | Alternating (initiative dice) |
| Combat resolution | Quality roll → defense roll → wounds | Hit roll → save → damage vs toughness → KP |
| Morale | Shaken/Routed | Suppression/Exhaustion/Retreat |
| Unit types | Infantry/Cavalry/Vehicle/Monster/Hero | Infantry squads/Characters/Vehicles |
| Campaign | XP → leveling, casualties, recruitment | CP → veteran skills, unit losses, roster changes |
| Army data | 17 faction JSONs | 14 species JSONs |
| Scenarios | Mission generator + 80 modifiers | 4 scenario types + 100 seeds + 20 GM components |

### What Transfers Directly (276 GDScript files in Tactica)
- **Resource class architecture**: `UnitProfile`, `WeaponProfile`, `SpecialRule`, `Faction`, `ArmyList`, `CampaignState`, `CampaignUnit` — same shapes, different field names and values
- **Validation logic**: `ArmyCompositionValidator` pattern (points budget, unit limits, org rules)
- **State management**: `CampaignManager` lifecycle (start/save/load/advance/process post-battle)
- **Scene flow**: Title → PreBattleSetup → Battle (tracker) → PostBattleResults → Campaign
- **SceneManager routing**: Same key-based navigation pattern

### What Does NOT Transfer
- All AoF game values (quality targets, defense values, weapon stats, points costs, special rule effects)
- 3D rendering pipeline (Sprite3D, SpriteMeshBaker, formations, camera)
- Behavior tree AI (replaced by reference tables in companion)
- Grid/battlefield spatial systems (physical tabletop handles this)
- Cutscene/screenplay system

### Key Stat Mapping Reference (AoF → Tactics Rulebook)
| AoF Concept | Tactics Rulebook Equivalent | Page |
| ----------- | --------------------------- | ---- |
| Quality (2-6, roll to hit) | D6 + Combat Skill vs target | p.36 |
| Defense (2-6, roll to save) | Saving Throw (species/armor dependent) | p.38 |
| Wounds per model | Kill Points (KP) | p.26 |
| Tough(N) special rule | Toughness stat | p.26 |
| Morale (quality-based) | Morale test: D6 + Training + modifiers | p.46 |
| Hero/Champion | Character (minor/major/epic) | p.138 |
| Points per model | Points per figure (Master table p.180) | p.135 |
| Army special rules | Species special rules | p.154-173 |
