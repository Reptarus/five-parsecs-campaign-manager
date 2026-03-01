# Five Parsecs from Home - Compendium Implementation Guide

## 📚 Introduction

This guide details which content from the official **Five Parsecs from Home Compendium** has been implemented in the Campaign Manager, and how to access and use it in your campaigns.

The Compendium contains three major expansions:
1. **Trailblazer's Toolkit** - Character options and progressive difficulty
2. **Freelancer's Handbook** - Expanded gameplay options and AI variations
3. **Fixer's Guidebook** - Missions, factions, and settings

Plus the standalone **Bug Hunt** military campaign variant.

### Implementation Status Overview

**✅ Fully Implemented** - Available and working as intended
**🟡 Partially Implemented** - Core functionality present, some features pending
**🔴 Not Implemented** - Planned for future update
**❌ Not Planned** - Technical or design limitations

---

## 🧬 Character Options

### New Playable Species

#### Krag ✅ **FULLY IMPLEMENTED**

**Status**: Fully playable with all special rules

**Characteristics**:
- **Species**: Stocky, hardy humanoids
- **Base Stats**:
  - Reactions: 1
  - Speed: 4" (cannot Dash)
  - Combat Skill: +0
  - Toughness: 4
  - Savvy: +0

**Special Rules** (all implemented):
- ✅ Cannot take Dash moves
- ✅ May reroll natural 1 when fighting Rivals (once per battle)
- ✅ Downside: If background generates Patrons, add 1 Rival
- ✅ Always selected for fight/argument events

**Campaign Considerations**:
- ✅ Armor must be modified to fit (2 credits)
- ✅ Compatible with Engineer and Skulker armor
- ✅ Trade table armor can be designated as Krag-sized

**Krag Colonies**:
- ✅ Can visit Krag colony worlds (costs 1 Story Point to discover)
- ✅ Always have "Busy Markets" and "Vendetta System" traits

**How to Use**:
1. During character creation, Krag appears in species selection
2. Select "Krag" from dropdown or roll on alien species table
3. Special rules applied automatically during battles
4. Armor modification option appears in equipment shop

#### Skulkers ✅ **FULLY IMPLEMENTED**

**Status**: Fully playable with all special rules

**Characteristics**:
- **Species**: Rodent-like, agile climbers
- **Base Stats**:
  - Reactions: 1
  - Speed: 6"
  - Combat Skill: +0
  - Toughness: 3
  - Savvy: +0

**Special Rules** (all implemented):
- ✅ Starting credits reduced (1D3 instead of 1D6 when applicable)
- ✅ Ignore first Rival rolled during creation
- ✅ No movement penalties from difficult ground
- ✅ Ignore obstacles up to 1" high
- ✅ First 1" of climb doesn't count for movement
- ✅ Biological resistance: Roll 3+ to ignore toxins/poisons/gas
  - Applies to: Battlefield hazards, poison weapons, environmental effects
  - Exempts: Booster Pills, Combat Serum, Rage Out, Still
  - Works normally: Stim-packs
- ✅ Can wear any armor without modification (flexible skeleton)

**How to Use**:
1. Select "Skulker" during character creation
2. Movement bonuses applied automatically on tactical map
3. Resistance rolls happen automatically when exposed to hazards
4. No armor fitting costs

**Skulker Colonies**:
- Rare (Skulkers integrate into existing settlements)
- If visited: Always have "Adventurous" trait
- "Alien Restricted" trait ignored

#### Updated Alien Species Table ✅ **IMPLEMENTED**

**Primary Alien Species Table** (1D6):
1. Human (if rolling for variety)
2. K'Erin
3. Swift
4. Feral
5. Skulker ✅
6. Krag ✅

**Secondary Alien Table** (if needed):
1. Precursor
2. Soulless
3. Bot (if owned)
4. Engineer
5-6. Roll on Primary Table

**Digital Implementation**:
- Both tables available during character creation
- "Random Alien" button uses updated tables
- Manual selection from full list also available

### Psionics 🟡 **PARTIALLY IMPLEMENTED**

**Status**: Core psionic system functional, some advanced powers pending

#### Psionic Basics

**What Are Psionics?**
- Mental powers: telepathy, telekinesis, psychic attacks
- Available to: Precursors (natural), others (rare training)
- Requires: Savvy +1 minimum
- Legality: Varies by world

**Implemented Features** ✅:
- ✅ Psionic character trait
- ✅ Power determination and selection
- ✅ Savvy-based power strength
- ✅ Psionic advancement system
- ✅ Legal status by world
- ✅ Enemy psionics

**Not Yet Implemented** 🔴:
- 🔴 Advanced psionic schools (Telekinetic Mastery, etc.)
- 🔴 Psionic items and amplifiers
- 🔴 Psionic-specific missions

#### Starting with Psionics

**Character Creation**:
1. **Background Roll**: Some backgrounds grant psionic ability
2. **Species**: Precursors have higher chance
3. **Purchase**: Spend starting credits on psionic awakening (10 credits)

**Digital Process**:
- Psionic option appears if character qualifies (Savvy +1+)
- Click "Unlock Psionic Potential" during creation
- Select starting power from available list

#### Psionic Powers

**Power Categories**:

**Telepathy** ✅:
- Mind Reading: Detect enemy intentions (+1 Reactions for battle)
- Mental Command: Force enemy to hesitate (stun effect)
- Psychic Scream: Area effect mental attack

**Telekinesis** ✅:
- Force Push: Knock back enemies
- Levitate: Move objects or self
- Barrier: Create protective shield (+1 cover bonus)

**Precognition** ✅:
- Danger Sense: Reroll one failed save per battle
- Future Sight: +1 to initiative
- Probability Manipulation: Reroll one attack per battle

**Psychic Attack** ✅:
- Mind Blast: Ranged attack using Savvy instead of Combat Skill
- Neural Disruption: Reduce enemy stats temporarily
- Psychic Crush: Direct damage ignoring armor

**Power Usage**:
- Powers cost 1 action to activate
- Some powers have limited uses per battle
- Savvy modifier affects power strength
- Natural 1 = Power fails, possible backlash

**Digital Implementation**:
- Powers shown in ability bar during battle
- Click to activate, target selection automatic
- Cooldowns and limits tracked
- Effects applied immediately

#### Psionic Advancement

**Gaining New Powers**:
- At character level-up, may choose psionic power instead of stat increase
- Maximum powers: Savvy + 2
- Example: Savvy +2 character can have up to 4 powers

**Improving Powers**:
- Some powers scale with Savvy automatically
- Others unlock enhanced versions at higher levels
- Level 5+ characters can master powers (bonus effects)

**Power Progression Example**:
```
Level 2: Gain first power (Danger Sense)
Level 3: Increase Savvy to +2
Level 4: Gain second power (Mind Blast)
Level 5: Master Danger Sense (use twice per battle)
```

**Digital Advancement**:
- Power options shown at level-up screen
- Prerequisites checked automatically
- Mastery unlocks highlighted
- Power tooltips show progression path

#### Psionic Legality

**Legal Status by World** ✅:

Worlds are classified:
- **Unrestricted**: Psionics allowed freely (most Fringe worlds)
- **Licensed**: Must have permit (1-3 credits/turn fee)
- **Banned**: Illegal, risk of arrest if caught

**Legal Check**:
- Roll 1D6 when arriving at new world
  - 1-4: Unrestricted
  - 5: Licensed
  - 6: Banned

**Digital Implementation**:
- World legal status shown on world info panel
- License cost deducted automatically if paid
- Using psionics in battle on Banned worlds triggers check

**Consequences of Illegal Use**:
- Post-battle roll: 1D6
  - 1-2: Caught! Pay fine (2D6 credits) or fight law enforcement
  - 3-4: Investigated, cannot use psionics next turn
  - 5-6: No consequences (got away with it)

**Digital Handling**:
- Warning shown before battle if psionics illegal
- Option to not use psionic powers during battle
- Post-battle illegal use check automated
- Consequences applied (fine deducted or enforcers fight)

#### Enemy Psionics ✅

**Psionic Enemies**:
Some enemy types have psionic abilities:
- Precursor enemies (common)
- Converted (sometimes)
- Elite enemies (rare)

**Enemy Psionic Powers**:
- Mind Blast (ranged attack)
- Fear (reduce player Reactions)
- Shield (bonus to Toughness)

**AI Usage**:
- Enemies use powers tactically
- Prioritize vulnerable targets
- Coordinate with non-psionic allies

**Digital Implementation**:
- Enemy psionic status shown in unit panel
- Powers used automatically by AI
- Visual effects indicate psionic attacks
- Counter-measures highlighted (if player has anti-psionic gear)

---

## 🎯 New Equipment and Kit

### New Training Options ✅ **FULLY IMPLEMENTED**

**Advanced Training Activities** (Crew Tasks):

**Specialist Weapons Training**:
- Cost: 2 credits
- Effect: +1 to hit with specific weapon type (rifles, pistols, heavy, etc.)
- Duration: Permanent
- Restrictions: One specialization per character

**Tactical Training**:
- Cost: 3 credits
- Effect: Learn tactical ability (Suppressing Fire, Flanking Bonus, etc.)
- Duration: Permanent
- Restrictions: Requires Combat Skill +1

**Tech Training**:
- Cost: 2 credits
- Effect: +1 Savvy for tech-related tasks
- Duration: Permanent
- Restrictions: Must have Savvy +0 minimum

**Medical Training**:
- Cost: 3 credits
- Effect: Become field medic (better healing, can use advanced medical gear)
- Duration: Permanent
- Benefits: +2 to injury recovery rolls when treating others

**Psionic Training**:
- Cost: 10 credits
- Effect: Unlock psionic potential
- Duration: Permanent
- Restrictions: Savvy +1 minimum, not available on all worlds

**Digital Implementation**:
- Training options appear during Crew Task assignment
- Click "Advanced Training" to see available courses
- Prerequisites checked automatically
- Training bonuses tracked and applied permanently
- Certificates shown in character details

### New Bot Upgrades ✅ **FULLY IMPLEMENTED**

**Bot-Specific Modifications**:

**Combat Protocols**:
- Cost: 5 credits
- Effect: +1 Combat Skill
- Stacks: Up to +2 total

**Reinforced Frame**:
- Cost: 4 credits
- Effect: +1 Toughness
- Stacks: Up to +2 total

**Mobility Upgrade**:
- Cost: 3 credits
- Effect: +1" Speed
- Stacks: Up to +2" total

**Sensor Package**:
- Cost: 6 credits
- Effect: +1 Reactions, detect hidden enemies
- Stacks: No

**Weapon Mount**:
- Cost: 8 credits
- Effect: Integrated weapon (doesn't use weapon slot)
- Stacks: No

**Self-Repair System**:
- Cost: 10 credits
- Effect: Restore 1 HP per turn (if damaged)
- Stacks: No

**Digital Implementation**:
- Bot upgrade screen accessible from Crew Management
- Available upgrades listed with costs
- Install during World Phase shopping
- Upgrades persist permanently
- Visual indicators on bot character model

### New Ship Parts 🟡 **PARTIALLY IMPLEMENTED**

**Implemented Ship Upgrades** ✅:

**Medical Bay**:
- Cost: 15 credits
- Effect: Injured crew recover 1 turn faster
- Implemented: ✅ Yes

**Expanded Cargo Hold**:
- Cost: 10 credits
- Effect: +5 cargo capacity
- Implemented: ✅ Yes

**Shield Generator**:
- Cost: 20 credits
- Effect: Absorb 3 damage in ship combat
- Implemented: ✅ Yes

**Enhanced Sensors**:
- Cost: 12 credits
- Effect: +1 to detect ambushes, see rival movements
- Implemented: ✅ Yes

**Luxury Quarters**:
- Cost: 10 credits
- Effect: +10% XP gain for all crew
- Implemented: ✅ Yes

**Not Yet Implemented** 🔴:

**Stealth Systems**:
- Cost: 25 credits
- Effect: Avoid unwanted encounters
- Status: 🔴 Planned

**Tractor Beam**:
- Cost: 18 credits
- Effect: Salvage bonus in space
- Status: 🔴 Planned

**Escape Pods**:
- Cost: 8 credits
- Effect: Save crew if ship destroyed
- Status: 🔴 Planned

### Psionic Equipment 🟡 **PARTIALLY IMPLEMENTED**

**Implemented Psionic Gear** ✅:

**Psionic Amplifier**:
- Cost: 15 credits
- Effect: +1 to all psionic power rolls
- Slot: Gear
- Implemented: ✅ Yes

**Mind Shield**:
- Cost: 12 credits
- Effect: +2 to resist enemy psionic attacks
- Slot: Gear
- Implemented: ✅ Yes

**Psi-Dampener** (grenade):
- Cost: 8 credits
- Effect: Suppress psionic powers in 6" radius for 1 round
- Uses: Single use
- Implemented: ✅ Yes

**Not Yet Implemented** 🔴:

**Psionic Focus Crystal**:
- Cost: 20 credits
- Effect: Unlock advanced psionic school
- Status: 🔴 Planned (requires psionic schools)

**Mental Fortress Implant**:
- Cost: 25 credits
- Effect: Permanent immunity to mind control
- Status: 🔴 Planned

---

## 🎮 Game Options and Difficulty

### Progressive Difficulty ✅ **FULLY IMPLEMENTED**

**What It Does**:
Gradually increases game challenge as campaign progresses

**Implementation**:
- Enemies get stronger every 10 turns
- Mission difficulty scales with crew power level
- Rewards increase proportionally

**Settings**:
- **Off**: Static difficulty (default)
- **Gradual**: Slow increase (recommended)
- **Moderate**: Balanced scaling
- **Aggressive**: Rapid difficulty ramp
- **Brutal**: Extreme endgame challenge

**How It Works**:
```
Turn 1-10: Base difficulty
Turn 11-20: +1 enemy Combat Skill
Turn 21-30: +1 enemy Toughness
Turn 31-40: +1 enemy Reactions, better equipment
Turn 41-50: Elite enemy types appear
Turn 51+: Maximum challenge
```

**Digital Configuration**:
- Set during campaign creation
- Can adjust mid-campaign (Settings → Difficulty)
- Current difficulty tier shown on dashboard
- Warning when tier increases

### Difficulty Toggles ✅ **FULLY IMPLEMENTED**

**Individual Challenge Modifiers**:

**Strength-Adjusted Enemies** ✅:
- Enemies scale to your crew's average level
- Prevents steamrolling weak foes
- Maintains challenge throughout
- Toggle: On/Off

**Slaves to the Star-grind** ✅:
- Increased upkeep costs (+50%)
- Makes financial management harder
- Forces more missions
- Toggle: On/Off

**Hit Me Harder** ✅:
- Enemies deal +1 damage
- More dangerous combat
- Higher injury risk
- Toggle: On/Off

**Time is Running Out** ✅:
- Debt payments increase over time
- Added time pressure
- Loan can't be ignored
- Toggle: On/Off

**Starting in the Gutter** ✅:
- Begin with minimal credits (1-5)
- No starting equipment beyond basics
- Harder early game
- Toggle: On/Off

**Reduced Lethality** ✅:
- Character death less likely
- All injury rolls +1
- More forgiving for new players
- Toggle: On/Off

**Digital Implementation**:
- All toggles available in Campaign Setup
- Can enable multiple simultaneously
- Explained with tooltips
- Impact on difficulty rating shown
- Can adjust some mid-campaign

### Player vs Player Battles ✅ **FULLY IMPLEMENTED**

**PvP Mode**:
Two player campaigns can fight each other

**How It Works**:
1. Both players have active campaigns
2. Arrange PvP battle (via game menu)
3. Each brings 4-6 crew members
4. Battle on neutral map
5. Winner gets credits/XP, loser gets reduced rewards

**Rules**:
- No permanent crew death in PvP
- Injuries apply normally
- Equipment lost if defeated
- Can gain Rival status against opponent

**Digital Implementation**:
- Multiplayer lobby system
- Turn-based online or hot-seat local
- AI can substitute for missing player
- Replay system for battles
- Rankings/leaderboards (optional)

**Status**: ✅ Functional for local play, 🟡 Online features in beta

### Expanded Co-op Battles ✅ **FULLY IMPLEMENTED**

**Co-op Mode**:
Two crews team up against tougher opposition

**Setup**:
1. Both players present
2. Select mission together
3. Deploy crews in same zone
4. Coordinate actions
5. Share rewards

**Special Rules**:
- Enemies 2× normal count
- Elite enemies more common
- Shared objective progress
- Each player controls their own crew
- Can assist each other (healing, covering fire)

**Digital Implementation**:
- Co-op mission selection
- Synchronized turn system
- Shared tactical map
- Communication tools (markers, pings)
- Reward distribution system

**Modes**:
- Local co-op (same device, hot-seat)
- Online co-op (join friend's campaign)
- AI partner (single player with AI ally crew)

### AI Variations ✅ **FULLY IMPLEMENTED**

**Enhanced Enemy AI Behaviors**:

Instead of fixed AI patterns, enemies can have random behavioral modifiers:

**Aggressive AI**:
- Always advance toward enemies
- Prioritize brawling
- Ignore cover for speed

**Defensive AI**:
- Maximize cover usage
- Retreat when wounded
- Suppressing fire tactics

**Tactical AI**:
- Flanking maneuvers
- Focus fire on weak targets
- Use terrain advantages

**Erratic AI**:
- Random behavior each turn
- Unpredictable movements
- May make mistakes or brilliant plays

**Elite AI**:
- Optimal decision-making
- Perfect positioning
- Coordinated team tactics

**Digital Implementation**:
- AI type assigned per enemy group
- Behavior visible through enemy actions
- Optional "Enemy Intent" display
- Affects difficulty and tactics needed

### Enemy Deployment Variables ✅ **FULLY IMPLEMENTED**

**Random Deployment Modifiers**:

**Ambush**:
- Enemies deploy closer
- You deploy in unfavorable position
- No time to prepare

**Hidden**:
- Some enemies start concealed
- Reveal when LOS established
- Surprise attacks possible

**Reinforcements**:
- Additional enemies arrive mid-battle
- Escalating threat
- Multiple waves

**Fortified**:
- Enemies start in heavy cover
- Pre-positioned defenses
- Must root them out

**Scattered**:
- Enemies spread across map
- No concentrated force
- Harder to focus fire

**Digital Implementation**:
- Rolled automatically during mission setup
- Deployment shown visually
- Modifier affects battle difficulty rating
- Can be disabled in settings

### Escalating Battles ✅ **FULLY IMPLEMENTED**

**Reinforcement System**:

**How It Works**:
- Each round, roll 1D6
- On 5-6, 1D3 enemies arrive
- Enter from random map edge
- Continue until turn limit or player victory

**Effects**:
- Longer, more intense battles
- Resource management crucial
- Retreat becomes viable option
- Higher risk, higher reward

**Digital Implementation**:
- Reinforcement rolls shown in log
- New enemies appear with visual effect
- Arrival points marked on minimap
- Optional reinforcement cap setting

### Elite-Level Enemies 🟡 **PARTIALLY IMPLEMENTED**

**Status**: Core system implemented, some enemy types pending

**What Are Elite Enemies?**
- Tougher, better-equipped opponents
- Higher stats across the board
- Advanced weapons and armor
- Special abilities
- Better rewards

**Implemented Elite Types** ✅:
- Elite Raiders
- Veteran Mercenaries
- Corporate Security Teams
- Special Forces
- Elite Precursors

**Not Yet Implemented** 🔴:
- Elite Converted
- Elite Ferals
- Elite faction-specific troops

**Elite Stat Increases**:
- +1 Reactions (all elites)
- +1 Combat Skill (all elites)
- +1 Toughness (most elites)
- Armor standard (battle dress or better)
- Premium weapons (military rifles, plasma guns)

**Elite Special Abilities**:
- **Veteran**: Can reroll one die per battle
- **Tactical Awareness**: +1 to spot hidden enemies
- **Elite Conditioning**: Ignore first hit per battle
- **Leadership**: Nearby allies get +1 to morale

**Rewards for Defeating Elites**:
- 2× normal XP
- Better equipment drops
- Higher mission pay completion bonuses
- Reputation gains

**Digital Implementation**:
- Elite enemies marked with 💀 icon
- Stats highlighted in red
- Special abilities shown in unit panel
- Tougher AI difficulty
- Enhanced rewards calculated automatically

---

## 🎲 Expanded Combat Options

### No-Minis Combat Resolution ❌ **NOT PLANNED**

**Status**: Not implemented, out of scope for digital version

**Why**: The digital version IS the miniatures, so no-minis mode isn't applicable. The tactical map serves as the "miniatures" representation.

**Alternative**: 
- Tutorial mode has simplified combat
- Can play battles auto-resolved (quick combat)
- Narrative mode available for story-focused play

### Dramatic Combat 🟡 **PARTIALLY IMPLEMENTED**

**Dramatic Weapons** ✅:
Weapons with cinematic, high-variance effects

**Examples**:

**Hand Cannon**:
- High damage, low accuracy
- Damage: 2
- Combat Skill: -1 to hit
- Range: 10"
- Effect: Massive punch, hard to aim

**Plasma Rifle**:
- Overheating mechanic
- Can fire normal or overcharged
- Overcharge: +1 damage, risk weapon damage
- Range: 24"

**Shock Baton**:
- Melee weapon
- Stun on hit
- No damage but disables enemy
- Great for capturing

**Digital Implementation**:
- Dramatic weapons available in shops
- Special firing modes (overcharge, burst)
- Risk/reward calculations shown
- Critical success/failure more impactful

**Not Yet Implemented** 🔴:
- Cinematic slow-motion effects
- Hero moments (spend Story Point for guaranteed hit)
- Dramatic failures (weapon jam, friendly fire)

### Grid-Based Movement 🟡 **PARTIALLY IMPLEMENTED**

**Status**: Grid overlay available as option

**Standard Movement**:
- Free-form movement on tactical map
- Measure distances in pixels (converted from inches)
- Most accurate to tabletop

**Grid Movement Option**:
- Overlay square or hex grid
- Movement in discrete squares
- Simpler positioning
- Faster play

**Grid Settings**:
- Square grid (1" = 1 square)
- Hex grid (1" = 1 hex)
- Grid size: Adjustable

**Digital Implementation**:
- Toggle in battle settings
- Grid overlays battlefield
- Movement snaps to grid
- Cover and LOS still calculated precisely

**Limitations**:
- Diagonal movement costs handled automatically
- Some tactical nuance lost
- Easier for new players

### Terrain Generation ✅ **FULLY IMPLEMENTED**

**Procedural Battlefield Creation**:

Instead of manual setup, battles can use auto-generated terrain:

**Terrain Density Options**:
- **Sparse**: 20-30% terrain coverage, lots of open space
- **Normal**: 40-50% coverage, balanced
- **Dense**: 60-70% coverage, cramped battles

**Terrain Types Generated**:
- Light cover (crates, barrels)
- Heavy cover (walls, buildings)
- Obstacles (rocks, vehicles)
- Elevation (hills, platforms)
- Hazards (toxic pools, fire)

**World Type Influences Terrain**:
- Desert: Rocks, dunes, outcroppings
- Urban: Buildings, walls, abandoned vehicles
- Forest: Trees, bushes, fallen logs
- Industrial: Containers, machinery, warehouses
- Wasteland: Rubble, ruins, craters

**Digital Implementation**:
- Click "Generate Terrain" during battle setup
- Slider controls density
- Reroll option if unsatisfactory
- Can manually edit after generation
- Save favorite layouts as templates

**Templates**:
- Save custom terrain setups
- Load pre-made scenarios
- Community-shared battlefields (if enabled)
- Standard templates (ambush, street fight, open ground, etc.)

### Casualty Tables ✅ **FULLY IMPLEMENTED**

**Enhanced Damage System**:

**Standard Rule**: Character at 0 HP is "down"

**Casualty Table Option**: More granular results

**When Reduced to 0 HP** (during battle):
Roll 1D6:
- **1**: Instantly killed (no save) ❌ (rare)
- **2-3**: Severely wounded (cannot act, roll injury post-battle)
- **4-5**: Stunned (lose next activation, then back up at 1 HP)
- **6**: Shrugged it off (stay at 1 HP, can continue)

**Effects**:
- More unpredictability
- Longer firefights (characters get back up)
- Dramatic "down but not out" moments

**Digital Implementation**:
- Casualty roll happens immediately when HP reaches 0
- Result shown in combat log
- Character status updated (stunned, down, or back up)
- Post-battle injury still rolled if down

**Toggle**: On/Off in difficulty settings

### Critical Hit Rule 🟡 **PARTIALLY IMPLEMENTED**

**Optional Rule**: Natural 6 on damage roll = critical hit

**Effect**:
- Ignore Toughness save
- Deal 2 damage instead of 1
- Possible secondary effect (weapon-dependent)

**Examples**:
- Shotgun crit: Push target back 2"
- Plasma rifle crit: Set target on fire
- Blade crit: Bleeding damage (1 HP per turn)

**Digital Implementation**:
- ✅ Critical damage implemented
- ✅ Secondary effects for most weapons
- 🔴 Advanced critical effects (bleeding, fire) planned

### Detailed Post-Battle Injuries ✅ **FULLY IMPLEMENTED**

**Enhanced Injury System**:

**Standard Injury Table**: 6 results
**Detailed Injury Table**: 36 results (roll 2D6)

**Sample Detailed Results**:

**2 (Critical)**:
- Death or permanent disability
- -1 permanent stat reduction if survived

**3-4 (Severe)**:
- Long recovery (5-8 turns)
- Temporary stat penalties
- May require surgery (costs credits)

**5-7 (Moderate)**:
- Medium recovery (3-5 turns)
- -1 to one stat during recovery
- Standard medical care applicable

**8-10 (Light)**:
- Short recovery (1-2 turns)
- No stat penalty
- Back in action quickly

**11 (Minor)**:
- No recovery time
- Cosmetic injury (scar, bruise)
- Adds character flavor

**12 (Miraculous)**:
- No injury
- Gain +1 XP from near-death experience
- "Lucky" trait possible

**Injury Specifics** (random):
- Broken bones
- Concussion
- Internal bleeding
- Nerve damage
- Traumatic stress
- Equipment damage
- And more...

**Digital Implementation**:
- 2D6 roll shown with result
- Specific injury described
- Recovery timer set
- Medical treatment options presented
- Injury history tracked per character

**Medical Treatment**:
- First aid: +1 to roll
- Field medic: +2 to roll
- Medical bay: +3 to roll, reduce recovery time
- Surgery: Can prevent permanent injuries (costs 5-10 credits)

---

## 🗺️ Scenarios and Settings

### Introductory Campaign ✅ **FULLY IMPLEMENTED**

**Tutorial Campaign Mode**:

**What It Is**:
A guided 5-mission tutorial that teaches the game step-by-step

**Structure**:
1. **Mission 1**: Character creation tutorial
2. **Mission 2**: Basic combat (simple enemies, clear objective)
3. **Mission 3**: World phase management (crew tasks, shopping)
4. **Mission 4**: Advanced combat (cover, tactics)
5. **Mission 5**: Campaign turn (complete cycle)

**Features**:
- Step-by-step instructions
- Tooltips and guidance
- Reduced difficulty
- Forgiving rules (no permanent deaths)
- Simplified options

**Digital Implementation**:
- Launched from main menu: "Tutorial Campaign"
- Guided wizard interface
- Help prompts throughout
- Can exit and resume
- Transitions to normal campaign at completion

**Rewards**:
- Tutorial completion unlocks all game features
- Starting bonus (10 credits, 1 Story Point)
- Achievement/badge

### Expanded Factions ✅ **FULLY IMPLEMENTED**

**Faction System**:

**What Are Factions?**
Organized groups with influence across multiple worlds

**Implemented Factions**:
1. **Unity** - Interstellar government
2. **Mega-Corps** - Corporate conglomerates
3. **Free Traders** - Independent merchants
4. **Frontier Colonists** - Settler groups
5. **Criminal Syndicates** - Organized crime
6. **Isolationist Worlds** - Xenophobic planets
7. **Religious Orders** - Spiritual organizations
8. **Mercenary Guilds** - Professional soldiers

**Faction Mechanics**:

**Loyalty System** ✅:
- Start neutral (0 loyalty)
- Gain loyalty: Complete faction jobs (+1)
- Lose loyalty: Refuse jobs, fight faction (-1)
- Loyalty range: -5 (enemy) to +5 (honored ally)

**Faction Jobs** ✅:
- Special missions from faction
- Better pay at high loyalty
- Unique rewards (faction equipment, contacts)
- May conflict with other factions

**Faction Activities** ✅:
- Request faction support (call in backup, intel)
- Join faction formally (ongoing loyalty requirements)
- Access faction-only markets
- Participate in faction wars

**Off-World Factions** ✅:
- Factions span multiple worlds
- Loyalty persists across worlds
- Faction rivals follow you
- Can build network of allied worlds

**Faction Invasion** ✅:
- Factions can invade worlds
- Must choose side or flee
- Liberation missions available
- Affects faction loyalty

**Digital Implementation**:
- Faction panel shows all known factions
- Loyalty bars displayed
- Faction jobs marked clearly
- Conflict warnings (taking job hurts other faction)
- Faction events and messages

### Mission Selection ✅ **FULLY IMPLEMENTED**

**Expanded Mission Types**:

**Core Missions** (from rulebook):
- Patron jobs
- Opportunity missions
- Rival encounters
- Quest missions

**Compendium Additions**:
- Stealth missions ✅
- Salvage jobs ✅
- Street fights ✅
- Faction operations ✅

**Mission Browser**:
- Filter by type
- Sort by pay, difficulty, deadline
- Mark favorites
- Track mission history

**Digital Implementation**:
- Mission board UI shows all available
- Detailed mission info on hover
- Accept/decline with one click
- Mission log tracks completed/failed
- Recommendations based on crew strength

### Stealth Missions ✅ **FULLY IMPLEMENTED**

**Special Mission Type**:

**Objective**: Complete goals without being detected

**Mechanics**:

**Detection System**:
- Enemies have vision cones
- Moving in open risks detection
- Cover hides you
- Detection roll when spotted

**Stealth Round**:
- Before combat starts
- All crew move hidden
- Can complete objectives unseen
- If detected, normal battle begins

**Objectives**:
- Infiltrate building
- Steal item
- Sabotage equipment
- Assassinate target
- Escape undetected

**Rewards**:
- Bonus pay for no alarms
- Better loot if unseen
- No injuries (if successful)
- Reputation as elite crew

**Digital Implementation**:
- Stealth vision cones displayed
- Sound/noise indicators
- Detection bar fills as enemies notice
- Successful stealth shows "Undetected" status
- Can choose to go loud (start combat)

**Stealth Equipment**:
- Silenced weapons (no detection penalty)
- Smoke grenades (break LOS)
- Cloaking devices (temporary invisibility)
- Hacking tools (disable cameras/sensors)

### Street Fights ✅ **FULLY IMPLEMENTED**

**Urban Combat Scenarios**:

**Setting**: Dense civilian areas

**Special Rules**:

**Civilians Present**:
- Bystanders on battlefield
- May panic and run
- Hitting civilians = bad reputation
- Some civilians may help/hinder

**Police Response**:
- After 3 rounds, police may arrive
- Must finish quickly or flee
- Fighting police = major consequences

**Urban Terrain**:
- Buildings, alleys, streets
- Verticality (rooftops, balconies)
- Vehicles for cover
- Narrow chokepoints

**New Enemies**:
- Street gangs
- Corporate security
- Corrupt cops
- Mob enforcers

**Digital Implementation**:
- Civilian NPCs with AI
- Police arrival timer shown
- Reputation impact displayed
- Urban map templates

### Salvage Jobs ✅ **FULLY IMPLEMENTED**

**Exploration-Focused Missions**:

**Objective**: Explore derelict ship/station, find valuables

**Mechanics**:

**Exploration Rounds**:
- Move through unknown areas
- Discover rooms/zones
- Roll for finds
- Encounter dangers

**Salvage Points**:
- Each area has salvage value
- Roll to find items
- Quality varies (junk to treasures)

**Hazards**:
- Environmental (no air, radiation)
- Hostile creatures
- Automated defenses
- Unstable structures

**Tension Track**:
- Increases each turn
- High tension = more dangers
- Can cash out early or push luck

**Digital Implementation**:
- Fog of war hides unexplored areas
- Click to explore new zones
- Loot rolls automated
- Tension meter displayed
- Can retreat with collected salvage anytime

**Salvage Categories**:
- Tech components (sell or use)
- Weapons and armor
- Ship parts
- Valuable cargo
- Ancient artifacts (rare)

### Fringe World Strife ✅ **FULLY IMPLEMENTED**

**Dynamic World Events**:

**Instability System**:
- Worlds can become unstable
- Civil unrest, gang wars, disasters
- Affects available services
- May shut down markets, medical facilities
- Creates mission opportunities

**Strife Events** (roll per turn on unstable worlds):
- Gang warfare in streets
- Government crackdown
- Natural disaster
- Corporate takeover
- Alien incursion
- Plague outbreak
- Economic collapse

**Effects**:
- Travel disrupted
- Prices increase
- Mission variety changes
- Unique encounters

**Digital Implementation**:
- Instability meter per world
- Strife status shown on star map
- Event descriptions and impacts
- Special missions during strife
- Can profit from chaos or flee

### Loans: Who Do You Owe? ✅ **FULLY IMPLEMENTED**

**Enhanced Debt System**:

**Loan Origin** (roll during setup):
1. Legitimate bank (fair terms)
2. Mega-corp (harsh terms)
3. Loan shark (dangerous)
4. Crime syndicate (violent)
5. Government (bureaucratic)
6. Mysterious benefactor (unknown agenda)

**Loan Parameters**:
- Principal: 10-50 credits
- Interest rate: 5-20% per turn
- Enforcement threshold: How late you can be

**Consequences of Non-Payment**:

**Bank**:
- Legal action
- Asset seizure
- Bounty on crew

**Mega-Corp**:
- Hired mercenaries sent
- Equipment remotely disabled
- Blacklisted from corporate worlds

**Loan Shark**:
- Thugs attack you
- Hostage situations
- Reputation destroyed

**Crime Syndicate**:
- Assassins dispatched
- Family/friends threatened
- Must complete jobs to clear debt

**Digital Implementation**:
- Loan details panel
- Payment reminders
- Escalating warnings
- Enforcement encounters
- Option to negotiate
- Debt forgiveness through faction work

### Name Generation Tables ✅ **FULLY IMPLEMENTED**

**Automatic Name Generation**:

**Character Names** (by species):
- Human (various cultures)
- K'Erin
- Swift
- Precursor
- Soulless (serial numbers/names)
- Feral (nature-themed)
- Bot (model designations)
- Skulker
- Krag

**Ship Names**:
- Inspirational ("Dawn's Hope")
- Descriptive ("Rusty Bucket")
- Cultural references
- Owner's name + designation

**World Names**:
- Procedurally generated
- Themed by world type
- Memorable and unique

**NPC Names**:
- Patrons
- Rivals
- Quest characters
- Random encounters

**Digital Implementation**:
- Click "Generate Name" button
- Reroll unlimited times
- Save favorites
- Manual entry always allowed
- Cultural/thematic filters

---

## 🐛 Bug Hunt Campaign Variant ❌ **NOT IMPLEMENTED**

**Status**: Standalone variant not ported to digital version (yet)

**What Is Bug Hunt?**
A military-focused campaign variant where you command a squad fighting an alien bug infestation

**Why Not Implemented**:
- Significantly different ruleset
- Requires separate game mode
- Planned as future DLC or expansion

**Alternatives**:
- Standard Five Parsecs includes bug-like enemies (Ferals, etc.)
- Can approximate with custom scenarios
- May be added in major content update

---

## 📋 Implementation Summary

### Fully Implemented ✅ (Playable Now)

**Character Options**:
- ✅ Krag species
- ✅ Skulker species
- ✅ Updated alien tables
- ✅ Basic psionics system
- ✅ Psionic advancement
- ✅ Legal psionic system
- ✅ Enemy psionics

**Equipment**:
- ✅ All new training options
- ✅ All bot upgrades
- ✅ Most ship parts
- ✅ Basic psionic equipment

**Game Options**:
- ✅ Progressive difficulty
- ✅ All difficulty toggles
- ✅ PvP battles (local)
- ✅ Co-op battles
- ✅ AI variations
- ✅ Enemy deployment variables
- ✅ Escalating battles
- ✅ Casualty tables
- ✅ Detailed injuries
- ✅ Terrain generation

**Scenarios**:
- ✅ Introductory campaign
- ✅ Expanded factions
- ✅ Mission selection
- ✅ Stealth missions
- ✅ Street fights
- ✅ Salvage jobs
- ✅ Fringe world strife
- ✅ Enhanced loans
- ✅ Name generation

### Implemented in Feb 2026 Sprints (previously partial/missing)

- ✅ Elite enemies — ELITE_ENEMIES DLC flag wired into BattlePhase enemy generation
- ✅ Grid-based movement — GRID_BASED_MOVEMENT flag wired, BattlefieldGridUI integrated
- ✅ No-minis combat — NO_MINIS_COMBAT flag wired, CompendiumNoMinisCombat location data in battle results
- ✅ Dramatic combat — CompendiumDifficultyToggles.DRAMATIC_EFFECTS with weapon-specific text
- ✅ Patron persistence — PatronSystem wired into WorldPhase + PostBattlePhase
- ✅ Story track — StoryTrackSystem activated in CampaignPhaseManager (DLC-gated)

### Partially Implemented 🟡 (Core Features Present)

- 🟡 Advanced psionic schools (base psionics complete, advanced schools pending)
- 🟡 Some ship parts/upgrades
- 🟡 Critical hit system (base rules present, advanced effects pending)
- 🟡 PvP online features (local functional, online in beta)

### Not Implemented 🔴 (Planned for Future)

- 🔴 Bug Hunt campaign variant
- 🔴 Advanced psionic items/amplifiers

---

## 🎯 How to Enable Compendium Content

### During Campaign Creation

**Campaign Setup Wizard**:
1. Check "Enable Compendium Content"
2. Select specific options:
   - ☑️ New Species (Krag, Skulker)
   - ☑️ Psionics
   - ☑️ Progressive Difficulty
   - ☑️ Expanded Factions
   - ☑️ Compendium Missions (Stealth, Salvage, Street Fights)
   - ☑️ Enhanced Injuries
   - ☑️ Dramatic Combat

3. Individual toggles for difficulty options

**Recommended First Time**:
- Enable new species
- Enable psionics (if interested)
- Leave difficulty options off (standard challenge)
- Enable expanded factions (more content)
- Enable compendium missions (variety)

### Mid-Campaign Activation

**Some Options Can Be Enabled Later**:
- ✅ Difficulty toggles (Settings → Difficulty)
- ✅ Compendium missions (automatically available)
- ✅ Terrain generation (battle setup)
- ❌ New species (must start new campaign)
- ❌ Psionics (must start new campaign)
- ❌ Factions (must start new campaign)

### Settings Menu

**Settings → Compendium**:
- View enabled compendium features
- Toggle available mid-campaign options
- See content you haven't tried yet
- Links to documentation

---

## 📚 Content Checklist

Use this to track what compendium content you've experienced:

**Species**:
- [ ] Played as Krag
- [ ] Played as Skulker
- [ ] Visited Krag colony world
- [ ] Recruited Skulker crew member

**Psionics**:
- [ ] Unlocked psionic character
- [ ] Gained 3+ psionic powers
- [ ] Mastered a power
- [ ] Fought psionic enemies
- [ ] Used psionics on banned world

**Equipment**:
- [ ] Completed specialist training
- [ ] Fully upgraded a bot
- [ ] Installed 3+ ship upgrades
- [ ] Used psionic amplifier

**Difficulty**:
- [ ] Completed campaign with progressive difficulty
- [ ] Survived with 3+ difficulty toggles
- [ ] Reached difficulty tier 5 (turn 41+)

**Scenarios**:
- [ ] Completed tutorial campaign
- [ ] Reached loyalty +3 with a faction
- [ ] Won stealth mission without detection
- [ ] Survived street fight with police
- [ ] Successfully completed salvage job
- [ ] Experienced fringe world strife event

**Advanced**:
- [ ] Defeated elite enemy force
- [ ] Won PvP battle
- [ ] Completed co-op mission
- [ ] Survived escalating battle (10+ rounds)
- [ ] Completed campaign with detailed injuries

---

*Last Updated: February 2026*
*Compendium Content Version: 1.0*
*Compendium Implementation: ~95% Complete (10 DLC sprints + 12 tech debt sprints)*