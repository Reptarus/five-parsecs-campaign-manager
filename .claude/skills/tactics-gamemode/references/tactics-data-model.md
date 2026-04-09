# Tactics Data Model Reference

## TacticsCampaignCore (Resource — To Be Created)
- **class_name**: TacticsCampaignCore
- **extends**: Resource
- **SEPARATE from FiveParsecsCampaignCore, BugHuntCampaignCore, PlanetfallCampaignCore**
- Must follow the serialization contract: `to_dictionary()`/`from_dictionary()`/`save_to_file()`/`load_from_file()`
- `@export var campaign_type: String = "tactics"`
- `"campaign_type": "tactics"` at root AND in `meta` section of `to_dictionary()`

## Data Model Comparison

| Aspect | Tactics | Standard 5PFH | Bug Hunt | Planetfall |
|--------|---------|---------------|----------|-----------|
| Core class | `TacticsCampaignCore` | `FiveParsecsCampaignCore` | `BugHuntCampaignCore` | `PlanetfallCampaignCore` |
| Units | Army lists (squads, points-based) | Individual characters | Individual + grunts | Roster + grunts |
| Vehicles | Yes (bikes to heavy tanks) | No | No | No |
| Points | 500/750/1000 pts | No | No | No |
| Organization | Company/Platoon/Squad | Crew | Squad + fireteam | Colony roster |
| Turn structure | Operational campaign | 9-phase | 3-stage | 18-step |
| Training stat | Yes (new) | No | No | No |
| Kill Points | Yes (replaces wounds) | No | No | No |
| Play modes | Solo/GM/Versus | Solo | Solo | Solo |

## Army Building Rules

### Point Scales
- **500 pts**: Small game (~20 figures)
- **750 pts**: Standard game (~30 figures)
- **1000 pts**: Large game (~40+ figures)

### Composition Limits
- **Hero allowance**: 1 hero (Major/Epic character) per 375 pts of army total
- **Duplicate allowance**: Max 1 of any unit + 1 additional per 750 pts
- **Max single unit cost**: No single unit may exceed 35% of total army points
- **Squad size**: 4-5 soldiers + 1 sergeant per squad

### Company Organization
```
Company
├── HQ (1 required — Major or Epic character)
├── Platoons (1-3)
│   ├── Platoon HQ (Sergeant)
│   └── Squads (2-4 per platoon)
│       ├── 4-5 soldiers
│       └── 1 sergeant
├── Supports (0-2)
│   └── Vehicles, heavy weapons, specialists
└── Specialists (0-2)
    └── Snipers, medics, engineers, etc.
```

## Troop Profile Stats

| Stat | Description | Range |
|------|-------------|-------|
| Speed | Movement in inches | 3"-6" |
| Reactions | Initiative/alertness | 1-3 |
| Combat Skill | Weapons training bonus | +0 to +3 |
| Toughness | Damage resistance | 3-5 |
| Kill Points (KP) | Damage capacity (NEW) | 1-3 (characters), 2-8 (vehicles) |
| Savvy | Wits/tech aptitude | +0 to +2 |
| Training | Military competence (NEW) | +0 to +3 |

### Profile Tiers (per species)
1. **Civilian** — untrained (~5 pts)
2. **Military** — standard soldier (~10 pts)
3. **Sergeant / Minor Character** — squad leader (~15 pts)
4. **Major Character** — experienced officer (~20 pts)
5. **Epic Character** — elite hero (~30 pts)

## 14 Species Army Lists

### Major Powers (7)

| Species | Key Special Rules | Cost Range |
|---------|------------------|------------|
| Humans | Widely Skilled (+1 communication), Well Organized (lower Support arrival) | 5-30 |
| Ferals | Loping Run (+3" Dash), Keen Senses (+1 Observation) | 6-32 |
| Hulkers | Determined (+1 Morale), Powerful Swings, Short Tempered | 15-40 |
| Erekish (Precursors) | Premonition (6+ Save for individuals/sergeants) | 6-35 |
| K'Erin | Brawlers (2 close assault attacks), Disciplined (+1 Morale) | 8-35 |
| Soulless | Synthetic, Machine Learning, Hardened Network (3+ vs hacking). Flat 20pts | 20 |
| Converted/Horde | Synthetic/Mindless Assault OR Fearsome/Horde Tactics | 6-35 |

### Minor Powers (7)

| Species | Key Special Rules | Cost Range |
|---------|------------------|------------|
| Serian (Engineers) | Tech-savvy (reroll tech), Enviro-suits (immune gas/toxins) | 7-32 |
| Swift | Bonds of Inspiration, Winged (descend safely) | 6-32 |
| Keltrin (Skulkers) | Lurk (reroll Observation vs them), Ambush | 6-32 |
| Hakshan | Standard profile | 5-30 |
| Clones (The Many) | Mass Produced, Expendable | 8-40 |
| Ystrik (Manipulators) | Psionic abilities | 5-27 |
| Creatures | Various beast types (6 variants) | Varies |

## Vehicle Rules

### Vehicle Types
| Type | KP Range | Features |
|------|----------|---------|
| Bike | 2 | Fast, Open-Topped |
| APC | 4-5 | Transport (8-12), Armored |
| IFV | 4 | Transport (6), Armed, Armored |
| Light Tank | 5 | Armored, Turret |
| Medium Tank | 6 | Armored, Turret, Heavy Weapons |
| Heavy Tank | 8 | Armored, Turret, Heavy Weapons, Slow |
| Walker | 4-6 | All-Terrain, Armed |
| Combat Bot | 3-4 | Autonomous, Armed |

### Vehicle Properties
- **Transport(N)**: Can carry N infantry models
- **Open-Topped**: Passengers can shoot out, vulnerable to fire
- **Armored**: Saving throw vs damage
- **Turret**: 360-degree weapon arc
