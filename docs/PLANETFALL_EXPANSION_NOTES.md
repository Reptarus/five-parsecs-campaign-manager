# Five Parsecs From Home: Planetfall - Expansion Notes

**Status**: Pre-implementation research (pending Modiphius approval)
**Source**: Five Parsecs From Home - Planetfall [MUH084V044][OEF][2026-03-16]
**Full text extraction**: `docs/rules/planetfall_source.txt` (200 pages)
**Colony Sheet PDF**: `docs/Five_Parsecs_From_Home_Modiphius_Entertainment_Planetfall_MUH084V044OEF2026/`
**Last Updated**: 2026-03-30

---

## Executive Summary

Planetfall is a **colony-building adventure wargame** set in Unified Space. Players lead a crew tasked with growing and defending a colony on a dangerous new world. It shares the same combat engine as Five Parsecs From Home but replaces the spacefaring mercenary loop with a **planetary colonization campaign** featuring:

- **Colony management** (Integrity, Morale, Buildings, Research, Tech Tree)
- **Hex/grid map exploration** (6x6 to 10x10 sectors)
- **Three enemy types**: Animal Lifeforms (procedurally generated), Tactical Enemies (humanoid foes), and The Slyn (enigmatic aliens)
- **Milestone-driven progression** (7 milestones to reach End Game)
- **Four campaign endings**: Independence, Ascension, Loyalty, Isolation
- **Character transfer** between 5PFH, Bug Hunt, Tactics, and Planetfall

Key DNA shared with **Country Road Z**: The colony-under-siege gameplay loop, procedurally generated hostile creatures with evolution mechanics, milestone-based campaign pacing, and the "death spiral" colony integrity system.

---

## 1. Campaign Structure

### Campaign Turn Sequence (18 Steps)

Much larger than 5PFH's 9-phase turn. Grouped into three blocks:

#### PRE-BATTLE (Steps 1-6)
| Step | Name | Description |
|------|------|-------------|
| 1 | Recovery | Heal characters in Sick Bay (-1 turn each) |
| 2 | Repairs | Restore Colony Integrity (repair rate + Raw Materials) |
| 3 | Scout Reports | Scout Explore action + Scout Discovery table (D100) |
| 4 | Enemy Activity | Random Tactical Enemy action (D100: Patrol/Relocate/Occupy/Attack/Raid) |
| 5 | Colony Events | Random colony event (D100, 20 entries) |
| 6 | Mission Determination | Choose mission type based on available options |

#### BATTLE (Steps 7-8)
| Step | Name | Description |
|------|------|-------------|
| 7 | Lock and Load | Select characters + equipment for mission |
| 8 | Play Out Mission | Tabletop battle |

#### POST-BATTLE (Steps 9-18)
| Step | Name | Description |
|------|------|-------------|
| 9 | Injuries | D100 injury table for casualties |
| 10 | Experience Progression | XP awards + advancement (5 XP per roll, or point-buy) |
| 11 | Colony Morale Adjustments | -1 auto + -1 per casualty; Crisis check at -10 |
| 12 | Track Enemy Info & Mission Data | +1 Enemy Info per win; Mission Data processing |
| 13 | Replacements | 2D6 roll for new characters (1 + 1 per Milestone attempts/turn) |
| 14 | Research | Spend Research Points on Theories/Applications |
| 15 | Building | Spend Build Points on colony Buildings |
| 16 | Colony Integrity | Check for Integrity Failure if negative |
| 17 | Character Event | D100 roleplay event |
| 18 | Update Colony Tracking Sheet | Bookkeeping |

### Comparison to 5PFH Turn Phases
```
5PFH:        STORY -> TRAVEL -> UPKEEP -> MISSION -> POST_MISSION -> ADVANCEMENT -> TRADING -> CHARACTER -> RETIREMENT
Planetfall:  RECOVERY -> REPAIRS -> SCOUTS -> ENEMY_ACTIVITY -> COLONY_EVENTS -> MISSION_DETERMINATION ->
             LOCK_AND_LOAD -> PLAY_MISSION -> INJURIES -> XP -> MORALE -> TRACK_INFO -> REPLACEMENTS ->
             RESEARCH -> BUILDING -> INTEGRITY -> CHARACTER_EVENT -> UPDATE_SHEET
Bug Hunt:    SPECIAL_ASSIGNMENTS -> MISSION -> POST_BATTLE
```

---

## 2. Character System

### Classes (3 types, vs 5PFH's classless system)

| Class | Reactions | Speed | Combat | Toughness | Savvy | Special |
|-------|-----------|-------|--------|-----------|-------|---------|
| Scientist | 1 | 4" | +0 | 3 | +1 | Scientific Mind (reroll Savvy), Problem Solving (+1 Reaction die) |
| Scout | 1 | 5" | +0 | 3 | +0 | Flexible Combat Training (action before/after move), Jump Jets |
| Trooper | 2 | 4" | +1 | 3 | +0 | Trooper Armor (5+ Save), Intense Combat Training (2 actions) |
| Grunt | 2 | 4" | +0 | 3 | +0 | No progression, simplified casualty (D6: 1-2 dead, 3-6 ok) |
| Civvy | 1 | 4" | +0 | 3 | +0 | No abilities, civilian weapons only |
| Bot | 2 | 4" | +0 | 4 | +0 | 6+ Save, immune to psionic, no XP |

### Roster
- **Initial**: 8 characters (min 1 of each class) + 12 grunts + 1 bot
- **Max**: 10 characters (expandable via Expanded Living Facility building)
- **Weapon restrictions by class**: Civilian (all), Scout (Civilian+Scout), Trooper (Civilian+Trooper), Grunt (infantry rifle/LMG only)

### Character Stats (same as 5PFH)
- Reactions, Speed, Combat Skill, Toughness, Savvy
- **NO Luck stat** (replaced by Story Points at campaign level)
- **Loyalty system**: Disloyal / Committed / Loyal (affects endgame voting)

### Human Sub-species (p.19-20)
- **Feral**: Keen Senses (+1" detection), Impetuous (must assign 1s to them in Reaction)
- **Hulker**: Toughness 5, Poor Aim (always +0 shooting), Great Strength (no heavy penalty, fist +1 Damage)
- **Stalker**: Shift! (teleport 1D6" instead of normal move)
- **Soulless emissary**: Trooper only, 6+ Save, Toughness 4, +1 Savvy, no augmentations
- Max 1 Feral + 1 other sub-species

### Alien Characters
Can import aliens from 5PFH Core Rules or Compendium (K'Erin, Precursor, etc.)

### Character Backgrounds (experienced characters only, 4 of 8)
- **Motivations table** (D100, all characters)
- **Prior Experience table** (D100, experienced only — gives stat bonuses)
- **Notable Event table** (D100, experienced only — narrative flavor)

### Character Import/Export
- Characters can transfer between 5PFH, Bug Hunt, Tactics, and Planetfall
- Imported characters count against roster limit
- Export rules vary by ending (Independence/Ascension/Loyalty/Isolation)

---

## 3. Colony Management System (NEW - not in 5PFH)

### Colony Statistics (Colony Tracking Sheet)
| Stat | Starting Value | Purpose |
|------|---------------|---------|
| Colony Morale | 0 | Positive=good, negative=bad. -10 triggers Morale Incident |
| Colony Integrity | 0 | Damage buffer. Negative = Integrity Failure rolls |
| Build Points/Turn | 1 | Rate of BP generation |
| Research Points/Turn | 1 | Rate of RP generation |
| Story Points | 5 | Meta-currency for narrative control |
| Repair Capacity | 1 | Integrity points repaired per turn |
| Colony Defenses | 0 | D6 rolls vs colony damage (4+ negates 1 damage) |
| Raw Materials | 0 | Emergency repairs (up to 3/turn) + BP conversion |
| Grunts | 12 | Expendable soldiers |
| Augmentation Points | 0 | Genetic augmentation purchases |
| Ancient Signs | 0 | Track toward Ancient Sites |
| Enemy Information | 0 (per enemy) | Track toward Boss/Strongpoint discovery |
| Mission Data | 0 | Track toward Mission Data Breakthroughs |
| Calamity Points | 0 | Accumulate at Milestones, trigger Calamities |

### Colony Morale System
- Starts at 0. Positive = fine, Negative = trouble
- **Auto-decay**: -1 per turn + -1 per battle casualty
- **At -10 or worse**: Roll on Morale Incident table (D100)
- **Crisis**: At very negative levels, triggers Crisis state
  - Morale fixed at 0, all RP/BP/Raw Materials earn -1
  - 2D6 Crisis resolution roll each turn
  - Can lead to **campaign failure** (Unity takes over)

### Colony Integrity System
- Starts at 0. Buildings add to max Integrity
- Damage subtracts from Integrity (can go very negative)
- **Integrity Failure** (when negative): Roll 3D6 on Integrity Failure table
  - Results range from Morale loss to character death
- **Death Spiral**: At -10 or worse, failures cascade
- **Repairs**: Repair Capacity + Raw Materials (up to 3/turn)

### Colony Defenses
- Each defense = 1D6 roll when colony attacked
- 4-6 on each die negates 1 point of Colony Damage
- Sources: Drone turret network, Early warning system, Patrol base, Rapid response network

---

## 4. Research System (NEW)

### Structure
```
Theories (8 initial + 5 prerequisite-gated)
  └─ Applications (random unlock when RP spent)
       └─ Buildings, Weapons, Bonuses, Milestones
```

### Research Theories

| Theory | Cost (Theory/App) | Prerequisites | Key Outputs |
|--------|-------------------|---------------|-------------|
| Advanced Manufacturing | 2/2 | None | Tier 1 weapons prerequisite |
| AI Theories | 4/4 | None | AI-assisted school, Bot maintenance, Cybernetics |
| Environmental Research | 2/3 | None | Food production, Scout facilities, Remote sites |
| Genetic Advancement | 4/4 | None | Medical center, Augmentation Points |
| Infantry Equipment | 2/2 | None | 5 Tier 1 weapons + grunt upgrades |
| Military Doctrine | 3/3 | None | Early warning, MedEvac, Barracks |
| Social Theories | 3/3 | None | Frontier doctrines (Milestone), Morale boosts |
| Theoretical Physics | 4/3 | None | Galactic comms (Milestone), Research lab |
| Adapted Combat Gear | 2/2 | Infantry Equipment | 5 Tier 2 weapons |
| Environmental Adaptation | 3/3 | Environmental Research | Terraforming (Milestone), Augmentation |
| High Level Adaptation | 4/4 | Genetic Advancement | Genetic adaptation (Milestone) |
| Non-Linear Physics | 4/3 | Theoretical Physics | Academy, Colony shield, Scientific training |
| Psionic Engineering | 4/4 | Genetic Advancement | Psionic integration (Milestone) |

### Bio-Analysis Research
- Cost: 3 RP per lifeform
- Requires Hunt mission sample collection
- D6 table: Hit bonus, Brawling bonus, Critical hit, Weak spot, Disruption, Stagger

---

## 5. Buildings System (NEW)

### Building Mechanics
- **Build Points (BP)**: 1/turn base, increased by buildings/events
- **Raw Materials**: Convert 1 RM → 1 BP (up to 3/turn)
- **Construction**: Spread BP across turns, only 1 building at a time
- **Reclaiming**: Destroy building for half BP (rounded down) as Raw Materials
- **Prerequisite chain**: Many buildings require specific Research Applications

### Complete Buildings List (30+ buildings)

**No Prerequisites:**
- Advanced Manufacturing Plant (4 BP) — Tier 1 weapon prerequisite
- Civilian Market (4 BP) — +1 Story Point
- Drone Turret Network (6 BP) — +1 Colony Defense
- Expanded Living Facility (4 BP) — +2 roster slots
- Heavy Construction Site (8 BP) — +1 BP/turn
- Military Training Facility (5 BP) — +1 XP/turn for 1 character
- Militia Training Camp (4 BP) — Civvies get Reactions 2
- Patrol Base (4 BP) — +1 Colony Defense
- Protective Shelter (6 BP) — +2 Colony Integrity
- Resource Processing (8 BP) — +1 Raw Materials from any source
- Scout Drone Network (8 BP) — Reduce high Hazard levels, +1 Mission Data

**Milestone Buildings (grant 1 Milestone each):**
- Galactic Comms Relay (10 BP, Theoretical Physics)
- Frontier World Doctrines (from Social Theories)
- Integrated Post-Organic Demarcation (from Environmental Adaptation)
- Terraforming Control Center (from Environmental Adaptation)
- Genetic Adaptation Facility (from High Level Adaptation)
- Psionic Personality Integration (from Psionic Engineering)

---

## 6. Campaign Map System (NEW)

### Map Structure
- **Grid**: Default 6x6 (36 sectors), optional 6x10 (60) or 10x10 (100)
- **Home sector**: Colony location (1 sector, all buildings fit within)
- **Investigation Sites**: 10 initial + discoveries

### Sector States
| Symbol | State | Description |
|--------|-------|-------------|
| H | Home | Colony location |
| ? / I | Investigation | Interesting scan results, play Investigation Mission |
| R#/H# | Explored | Resource Level / Hazard Level assigned |
| Exploited | Used | Resources already extracted (Resource Level = 0) |
| Enemy color | Occupied | Controlled by Tactical Enemy, inaccessible |
| S | Strongpoint | Enemy HQ, must be assaulted |
| A | Ancient Sign | Potential Ancient Site |

### Scout Actions (Step 3)
- **Scout Explore**: Pick unexplored sector → 2D6 (take lowest) twice for Resource/Hazard levels
- **Scout Discovery**: D100 table (Routine/SOS/Scout Down!/Exploration report/etc.)
- **Process Enemy Information**: D6 ≤ Enemy Info count → locate Boss for Strike Mission

### No Travel Rules
Characters have vehicles, can reach any sector regardless of distance.

---

## 7. Enemy Systems

### Three Enemy Categories

#### A. Lifeforms (Procedurally Generated Wildlife)
Each Lifeform is rolled on multiple tables and recorded permanently:
1. **Mobility** (D100): Speed 5"/6"/7", partially airborne on 0s/5s
2. **Offensive** (D100 x2): Combat Skill +0/+1/+2, Strike Power +0/+1/+2 Damage
3. **Special Attacks** (D100, if either offensive roll ends in 0/5): Razor Claws, Eruption, Shoot, Spit, Overpower, Ferocity
4. **Defensive** (D100): Toughness 3-5, optional Armor/Dodge/Regeneration
5. **Kill Points** (D100): 0-3 KP
6. **Unique Ability** (D100): None/Pull/Jump/Teleport/Paralyze/Terror/Confuse/Hinder/Knock Down

**Campaign Lifeform Encounters Table**: D100 with 10 slots. Each slot filled permanently when first rolled.

#### B. Tactical Enemies (Humanoid Foes, 12 types)
| D100 | Type | Number | Speed | Combat | Tough | Panic | Special |
|------|------|--------|-------|--------|-------|-------|---------|
| 01-12 | Outlaws | 2D3+3 | 4" | +0 | 3 | 1-2 | Fragile discipline |
| 13-22 | Hostile Colonists | 1D3+5 | 4" | +0 | 3 | 1/1-2 | Variable motivation |
| 23-30 | Nomad Patrol | 1D3+5 | 6" | +0/+1 | 3/4 | 1-2 | Keen shots |
| 31-39 | Remnant Colonists | 1D6+3 | 4" | +0 | 3 | 1-3 | Blood-crazed |
| 40-49 | Renegades | 1D3+5 | 4" | +0 | 3/4 | 1-2 | Mob rules |
| 50-61 | Pirates (Inexperienced) | 1D3+6 | 4" | +0/+1 | 3 | 1-2 | Lack of tactics |
| 62-71 | Mysterious Raiders | 1D3+4 | 5" | +1 | 4 | 1 | Intense firepower |
| 72-78 | Pirates (Hardened) | 1D3+5 | 5" | +1 | 4 | 1 | Vacc suits (6+ Save) |
| 79-87 | Alien Raiders | 1D3+4 | 4" | +0/+1 | 4 | 1-2 | Slip sideways |
| 88-95 | K'Erin Landing Party | 1D3+4 | 4" | +1 | 4/5 | 1 | Paramilitary, Champion |
| 96-00 | Converted Recon Team | 1D3+4 | 4" | +1 | 4 | 0 | Fearless, Bolt-on armor |

Three Tactical Enemies appear during campaign (1 each at Milestones 1, 2, 5).

**Enemy Defeat Chain**: Collect 6 Enemy Information → Strike Mission (capture Boss) → Assault Mission (destroy Strongpoint) → Enemy eliminated, +5 Morale

#### C. The Slyn (Enigmatic Alien Threat)
- Profile: Speed 5", Combat +1, Toughness 4, Claws (Melee +1 Damage), Beam focus (18" range)
- Always deploy in **pairs** (linked by psionic bond)
- **Teleportation**: Each pair can teleport 2D6" in random direction
- **Cannot be permanently defeated** during campaign (only driven off at Milestone 4+)
- Encounter sizes: 6 or 8 (3-4 pairs)

#### D. Sleepers (Ancient Robot Defenders)
- Profile: Speed 5", Combat +1, Toughness 4
- 6+ Saving Throw (even vs armor-piercing), immune to Stun/Panic
- Weapons: Beam (12", 1 shot, Dmg 1) or Heavy beam (18", 2 shots, Dmg 1)
- **Rapid Fire**: After scoring a hit, fire with +1 shot next activation

---

## 8. Mission Types (13 types)

| Mission | Map Requirement | Table | Force | Slyn Risk | Key Mechanic |
|---------|----------------|-------|-------|-----------|--------------|
| Investigation | Investigation site | 3x3 | 4 chars | No | 4 Discovery markers, Contact system |
| Scouting | Unexplored sector | 2x2 | 2 chars | No | 6 Recon markers, determines Resource/Hazard |
| Exploration | Explored, not Exploited | 3x3 | 6 chars | 2D6: 2-4 | Objectives = Resource Value |
| Science | Resource ≥ 1 | 2x2 | 2 chars | No | 6 Science markers, RP rewards |
| Hunt | Within 4 sectors of colony | 3x3 | 6 (chars+grunts) | 2D6: 2-4 | Kill 2 lifeforms + transmit data |
| Patrol | Near colony | 3x3 | 6 (chars+grunts) | 2D6: 2-4 | 3 Objectives, Morale reward |
| Skirmish | Enemy-occupied sector | 3x3 | 6 (chars+grunts) | 2D6: 2-4 | Capture sector from enemy |
| Rescue | Per Scout Discovery | 3x3 | 6 (chars+grunts) | No | Rescue colonists, no Morale penalty for casualties |
| Scout Down! | Per Scout Discovery | 2x2 | 4 chars | No | Rescue downed scout |
| Pitched Battle | Forced by enemy Attack | 3x3 | 6 (chars+grunts) | No | Defend colony |
| Strike | Boss located | 3x3 | 6 (chars+grunts) | No | Capture enemy Boss |
| Assault | Strongpoint located | 3x3 | All available | No | Destroy enemy Strongpoint |
| Delve | Ancient Site located | Special | 4 chars | No | Multi-room dungeon crawl for artifacts |

---

## 9. Milestone System & Campaign Progression

### 7 Milestones Required for End Game
Each Milestone triggers:
- Lifeform Evolution (D100 table — 10 evolution types)
- +1 replacement recruitment
- Milestone-specific effects (new enemies, story points, augmentation points, etc.)

### Milestone Sources
- **Milestone Buildings**: Galactic Comms Relay, Frontier World Doctrines, Terraforming Control Center, Genetic Adaptation Facility, Psionic Personality Integration, Integrated Post-Organic Demarcation
- Additional milestone sources may come from Research Applications

### Lifeform Evolutions (triggered at each Milestone)
| D100 | Evolution | Effect |
|------|-----------|--------|
| 01-10 | Enhanced Profile | +1 Combat, +1" Speed, +1 Damage |
| 11-20 | Poison | Poison markers, D6 per marker (6 = casualty) |
| 21-30 | Spines | Extra hit on lost brawl |
| 31-40 | Duplication | D6: on 6, random lifeform duplicates |
| 41-50 | Dramatic Transformations | Random Unique Ability each battle |
| 51-60 | Summoning | D6: on 6, new Contact at random edge |
| 61-70 | Evasion | Dodge or damage reduction |
| 71-80 | Darts | 9" ranged attack, hit on 6 |
| 81-90 | Bigger Leaders | More pack leaders with more KP |
| 91-00 | Tougher Specimens | D6: on 5-6, +1 KP each specimen |

### Campaign End Game (4 endings)
| Ending | Cost | Prerequisite | Theme |
|--------|------|-------------|-------|
| Independence | 15 BP, 5 RP | Defeat 1+ Tactical Enemy Strongpoint | Break from Unity, risk war |
| Ascension | 5 BP, 15 RP | Defeat 1+ Tactical Enemy Strongpoint | Evolve into new species |
| Loyalty | 10 BP, 5 RP | Defeat 2 Tactical Enemy Strongpoints | Join Unity as full member |
| Isolation | 5 BP, 10 RP | Defeat 1+ Tactical Enemy Strongpoint | Become nomadic tribe |

### Calamities (8 types, triggered by Calamity Points at Milestones)
1. **Swarm Infestation** — Swarm aliens infest map sectors
2. **Environmental Risk** — Anomalous sectors, require Patrol missions to clear
3. **Enemy Super Weapon** — Tactical Enemy builds weapon (15 progress = 3D6 colony damage)
4. **Virus** — Characters accumulate Virus Points, need Hunt missions for cure
5. **Mega Predators** — Lifeforms get bonus KP, kill 5 enhanced lifeforms to end
6. **Wildlife Aggression** — Controller must be located and destroyed
7. **Robot Rampage** — Sleepers activate across all missions
8. **Slyn Assault** — Double Slyn interference checks, kill 30 to end

### Mission Data Breakthroughs (4 total)
1st: 2 Ancient Sites
2nd: 4 sectors explored + Resource +2
3rd: 2 new Investigation sites
4th: D100 for major discovery (Ancient Colony/Artificial Construction/Defense Network/etc.) — affects End Game bonuses

---

## 10. Armory

### Standard Weapons
| Weapon | Range | Shots | Damage | Traits |
|--------|-------|-------|--------|--------|
| Handgun | 6" | 1 | +0 | Civilian, Pistol |
| Colonial Shotgun | 8" | 1 | +1 | Civilian, Critical |
| Colony Rifle | 18" | 1 | +0 | Civilian |
| Scout Pistol | 9" | 1 | +0 | Scout, Pistol |
| Infantry Rifle | 24" | 1 | +0 | Grunt |
| Light Machine Gun | 36"/12" | 3/4 | +0 | Grunt, Cumbersome, Hail of Fire |
| Trooper Rifle | 30" | 1 | +0 | Trooper, AP Ammo |
| Assault Gun | 18" | 2 | +0 | Trooper |
| Flame Projector | 6" | Stream | +1 | Trooper, Stream, Burning |

### Tier 1 Weapons (require Advanced Manufacturing Plant)
| Weapon | Range | Shots | Damage | Traits |
|--------|-------|-------|--------|--------|
| Shard Pistol | 9" | 2 | +1 | Trooper, Focused, Pistol |
| Ripper Pistol | 9" | 2 | +0 | Scout, Pistol |
| Kill-Break Shotgun | 12" | 1 | +2 | Trooper, Knockback |
| Steady Rifle | 24" | 1 | +0 | Civilian, Stabilized |
| Carver Blade | Brawl | - | +2 | Civilian, Flexible, Melee |

### Tier 2 Weapons (require High-Tech Manufacturing Plant)
| Weapon | Range | Shots | Damage | Traits |
|--------|-------|-------|--------|--------|
| Bio-gun | 12" | Special | +1 | Trooper, Area |
| Mind-link Pistol | 9" | 1 | +0 | Scientist, Mind-link |
| Phase Rifle | 16" | 1 | +1 | Scout, Phased Fire |
| Dart Pistol | 9" | 1 | +1 | Civilian, Armor-piercing |
| Hyper-rifle | 16" | 1 | +1 | Trooper, Hyperfire |

### Grunt Upgrades (require specific Research/Buildings)
- Sharpshooter Sight: +1 to hit when stationary (military rifle only)
- Adapted Armor: 6+ Saving Throw
- Bolstered Survival Kit: Only 1 = permanent casualty
- Ammo Packs: Extra die to hit once per battle
- Side Arms: All grunts carry handgun
- Sergeant Weaponry: Fireteam leader gets blade

---

## 11. Genetic Augmentation System (NEW)

- **Augmentation Points**: Earned from Research, Milestones
- **8 augmentation types**: Boosted decision making, Boosted recovery, Claws, Enhanced mobility, Enhanced vision, Inherent protection, Mental links, Psionic cohesion
- Characters can receive augmentations by spending Augmentation Points

---

## 12. Battlefield Conditions System (NEW)

### Campaign Condition Table
- 10-slot table, filled as conditions are rolled
- Once filled, same condition recurs on that roll
- D100 Master Condition table with ~15 condition types

### Notable Conditions
- **Visibility Limits**: Variable/Fixed/Per-battle (1D6+8")
- **Shooting Penalties**: -1 in certain circumstances
- **Uncertain Terrain Features**: Hidden terrain
- **Unstable Terrain**: Collapses on D6=1
- **Shifting Terrain**: Moves 1D6" each round
- **Drifting Clouds**: 2" radius, block fire, may be toxic/corrosive
- **Resource Rich**: Extra Post-Mission Find roll
- **Confined Spaces**: Only 2 entry/exit points

---

## 13. Story Points (Meta-Currency)

Start with 5. Gain from character deaths, events, buildings.

### Spending Options
- Reroll any random table, pick either result
- Prevent Enemy Actions/Morale Incident/Integrity Failure roll
- Roll 2D6 (take highest) for RP/BP/Raw Materials combination
- Ignore post-battle injury
- **Narration**: Spend to change story direction (player-driven narrative control)

---

## 14. Key Differences from 5PFH

| Feature | 5PFH | Planetfall |
|---------|------|-----------|
| Setting | Spacefaring mercenary | Planetary colonist |
| Crew Size | 6-8 | 8-10 + 12 grunts + 1 bot |
| Classes | None (all equal) | 3 classes (Scientist/Scout/Trooper) |
| Turn Phases | 9 | 18 |
| Ship | Yes (hull/modules) | No (colony instead) |
| Patrons/Rivals | Yes | No (replaced by Tactical Enemies) |
| Trading | Yes (credits economy) | No (RP/BP/Raw Materials economy) |
| World Travel | Multi-planet | Single planet (map sectors) |
| Luck Stat | Yes | No (Story Points instead) |
| Colony Management | No | Yes (Integrity/Morale/Buildings/Research/Tech Tree) |
| Procedural Creatures | No | Yes (10-slot Lifeform table) |
| Map System | No | Yes (6x6 to 10x10 grid) |
| Milestone Progression | No | Yes (7 milestones → End Game) |
| Campaign Ending | Open-ended | 4 endings (Independence/Ascension/Loyalty/Isolation) |
| DLC/Compendium Content | Compendium species | Can import 5PFH aliens |
| Weapon Tiers | All available | Locked behind Research + Buildings |

---

## 15. Architectural Implications for FPCM

### New Systems Required
1. **ColonyManager** — Colony stats (Integrity, Morale, Defenses, etc.)
2. **ResearchManager** — Theory/Application tree, RP tracking
3. **BuildingManager** — Building construction, prerequisites, BP tracking
4. **CampaignMapManager** — Grid map, sector states, enemy occupation
5. **LifeformGenerator** — Procedural creature generation + evolution
6. **MilestoneTracker** — 7-milestone progression + effects
7. **CalamityManager** — Calamity events and resolution
8. **MissionDataTracker** — Mission Data breakthroughs
9. **PlanetfallTurnController** — 18-step turn sequence (vs 9-phase CampaignPhaseManager)
10. **PlanetfallCampaignCore** — Resource (like FiveParsecsCampaignCore / BugHuntCampaignCore)

### Reusable Systems (shared with 5PFH)
- **Combat engine**: Same core rules (Reactions, Shooting, Brawling, Damage, Panic)
- **TacticalBattleUI**: Reuse with `battle_mode: "planetfall"` (like Bug Hunt)
- **Character stats**: Same 5 stats (minus Luck), same advancement table
- **Injury table**: Similar D100 table
- **SceneRouter**: Add `planetfall_creation`, `planetfall_dashboard`, `planetfall_turn_controller`
- **GameState.load_campaign()**: Extend `_detect_campaign_type()` for PlanetfallCampaignCore
- **CharacterTransferService**: Already handles 5PFH ↔ Bug Hunt, extend for Planetfall

### Data Files Needed (JSON)
```
data/planetfall/
  ├── expedition_types.json          # D100 table (p.52)
  ├── scout_discovery.json           # D100 table (p.59)
  ├── enemy_activity.json            # D100 table (p.62)
  ├── colony_events.json             # D100 table (p.63-64)
  ├── battlefield_conditions.json    # D100 table (p.110-113)
  ├── character_backgrounds.json     # Motivations/Experience/Events (p.21-25)
  ├── character_roleplay_events.json # D100 table (p.72-74)
  ├── lifeform_generation.json       # All lifeform tables (p.146-150)
  ├── lifeform_evolutions.json       # D100 table (p.158-159)
  ├── tactical_enemies.json          # D100 table (p.150-152)
  ├── enemy_weapons.json             # Weapon profiles (p.151)
  ├── slyn_profile.json              # Slyn stats + rules (p.152-154)
  ├── sleeper_profile.json           # Sleeper stats + rules (p.154)
  ├── weapons.json                   # All weapon stats (p.76-80)
  ├── weapon_traits.json             # Trait definitions (p.78)
  ├── research_theories.json         # All theories + applications (p.92-96)
  ├── buildings.json                 # All buildings + costs + prereqs (p.98-106)
  ├── tech_tree.json                 # Dependency graph (from Colony Sheet)
  ├── augmentations.json             # 8 augmentation types (p.105)
  ├── injury_table.json              # D100 injury results (p.66)
  ├── advancement_table.json         # D100 advancement (p.67)
  ├── xp_costs.json                  # Point-buy XP costs (p.68)
  ├── replacement_table.json         # 2D6 table (p.69)
  ├── milestone_effects.json         # Per-milestone effects (p.156-160)
  ├── calamities.json                # 8 calamity types (p.165-170)
  ├── mission_data.json              # 4 breakthroughs (p.169-172)
  ├── post_mission_finds.json        # Finds table (p.134)
  ├── alien_artifacts.json           # Artifacts table (p.135-136)
  ├── morale_incidents.json          # D100 table (p.90)
  ├── integrity_failure.json         # 3D6 table (p.88)
  ├── endgame_tables.json            # All 4 ending resolution tables (p.160-164)
  ├── mission_templates.json         # 13 mission types (p.114-133)
  ├── grunt_upgrades.json            # 6 upgrade types (p.79)
  └── news_reports.json              # Flavor tables (p.74)
```

### UI Screens Needed
```
Planetfall Creation Flow:
  PlanetfallCreationUI (wizard)
    Step 1: Expedition Type (D100 roll)
    Step 2: Character Roster (8 chars + class selection)
    Step 3: Backgrounds (experienced chars)
    Step 4: Equipment Assignment
    Step 5: Map Generation (grid size + initial placements)
    Step 6: Final Review

Planetfall Dashboard:
  PlanetfallDashboard (colony overview)
    ├── Colony Stats Panel (Morale, Integrity, Defenses, etc.)
    ├── Roster Panel (8-10 characters + grunts + bot)
    ├── Map Panel (grid map with sector states)
    ├── Research Panel (tech tree visualization)
    ├── Buildings Panel (constructed + in-progress)
    └── Turn Phase Panel (18-step checklist)

Colony Tracking Sheet (digital version of paper sheet)
Tech Tree Visualization (from Colony Sheet PDF)
```

---

## 16. Cross-Game Compatibility Notes

### Character Transfer Rules (p.164)
- **Into Planetfall**: Imported chars count against 8-slot roster, bring all stats/items
- **Out of Planetfall → 5PFH**:
  - Loyalty ending: Free ship, no debt
  - Independence (won): Ship with 2D6 credits pre-paid
  - Independence (lost): 1 Rival (Enforcers/Bounty Hunters)
  - Isolation: 1 character gains +1 Luck
  - Ascension: 1 character gains psionic abilities
- **Artifact limit**: Each character can export only 1 artifact item
- **Profile increases**: All earned increases carry over

### Slyn Cross-Game Use
"The Slyn can be used in games of Five Parsecs from Home. Substitute any one entry on one of the encounter tables for the Slyn." (p.154)

---

## 17. Country Road Z DNA / Design Patterns

Planetfall shares several structural patterns with Country Road Z (zombie variant):

1. **Colony-under-siege loop**: Base management + field missions + escalating threats
2. **Procedural creature generation**: Random creature tables that persist across campaign
3. **Creature evolution**: Enemies get stronger at milestone boundaries
4. **Colony integrity/damage system**: Building HP that decays under attack
5. **Milestone-driven pacing**: Campaign progresses through achievement gates
6. **Death spiral mechanics**: Cascading failures when colony gets badly damaged
7. **Resource triple**: Three currencies (RP/BP/Raw Materials) for different colony aspects
8. **Calamity events**: Major crisis events that require special missions to resolve
9. **Campaign endings**: Multiple narrative conclusions with mechanical consequences

These patterns suggest a "colony survival" game template that could potentially be abstracted into a shared base system.
