# Chapter 6: The Battle Companion

> **Quick Start** (for tabletop veterans)
> - The app is a **companion**, not a simulator — it gives text instructions for your physical tabletop
> - Three tracking tiers: Log Only (you track), Assisted (app suggests), Full Oracle (app resolves)
> - Tabbed interface: Crew, Enemies, Battle Log, Tracking, Tools, Reference, Setup
> - Hit threshold: 4+ on d6, modified by range, cover (-1), and deployment bonuses
> - Hold field at 3+ enemy casualties for bonus loot

## Overview

The Battle Companion is the app's combat assistance system. It's designed to work alongside your physical Five Parsecs from Home tabletop setup — miniatures, terrain, dice, and all. The app doesn't replace the tabletop experience; it enhances it by tracking state, rolling dice, enforcing rules, and providing reference information.

Think of it as a very capable assistant sitting next to you while you play, keeping track of everything so you can focus on tactical decisions and moving miniatures.

## Pre-Battle Setup

Before battle begins, the **Pre-Battle Screen** shows:

### Mission Information
- Mission type and objectives
- Difficulty rating
- Special conditions (night fighting, restricted equipment, etc.)

### Enemy Forces
- Number of enemies
- Enemy type and AI behavior
- Weapons and abilities
- Deployment position

### Battlefield Preview
- Terrain layout suggestion (4x4 sector grid)
- Terrain features: buildings, walls, rocks, trees, water, cover positions
- Deployment zones for your crew and enemies

### Crew Selection
Choose which crew members to deploy. Consider:
- **Injuries**: Wounded crew fight at reduced effectiveness
- **Equipment**: Match crew loadouts to the mission type
- **Balance**: Mix ranged and melee fighters for flexibility

Click **Confirm** to proceed to the battle.

## The Three Tracking Tiers

The Battle Companion operates at three levels of assistance. Choose the tier that matches how much help you want from the app.

### Log Only

**You do everything on the tabletop.** The app simply records what happens.

Best for:
- Experienced players who know the rules well
- Players who prefer full manual control
- Quick games where you don't need rule lookups

What the app does:
- Records combat results you enter
- Tracks turn count
- Maintains a battle log for the campaign journal

### Assisted

**The app suggests actions and reminds you of rules.** You still execute everything on the tabletop.

Best for:
- Players learning the rules
- Complex battles with many modifiers
- When you want rule reminders without full automation

What the app does:
- Everything in Log Only, plus:
- Suggests legal actions for each unit
- Calculates hit modifiers for you
- Reminds you of reaction opportunities
- Tracks morale and panic status
- Highlights when special rules apply

### Full Oracle

**The app resolves all mechanics.** You move miniatures and the app tells you what happens.

Best for:
- Solo players who want the app to handle bookkeeping
- New players learning the system
- When you want to focus purely on tactical decisions

What the app does:
- Everything in Assisted, plus:
- Rolls all dice automatically
- Resolves hits, damage, and saves
- Determines enemy AI behavior and movement
- Calculates optimal enemy actions
- Handles all morale checks

You can switch between tiers at any time during a battle.

## The Battle Interface

The Tactical Battle UI uses a tabbed layout with information organized into three columns:

### Left Tabs: Units

**Crew Content** — Your deployed crew members:
- Character cards with current health, weapon, and status
- Active/inactive indicators
- Quick action buttons

**Units Content** — Generic unit tracking for larger battles

**Enemies Content** — Enemy roster:
- Enemy type and stats
- Remaining health
- Active/eliminated status

### Center Tabs: Battle State

**Battle Log** — Running text log of everything that happens:
- Actions taken by each unit
- Dice rolls and results
- Casualties and morale events
- Automatically recorded for the campaign journal

**Tracking Content** — Combat state tracking:
- **Morale/Panic Tracker** — Monitors crew and enemy morale
- **Activation Tracker** — Shows which units have acted this round

**Events Content** — Battle event resolution:
- Dynamic events triggered at specific rounds (end of rounds 2 and 4)
- Environmental hazards
- Special conditions

### Right Tabs: Tools and Reference

**Tools Content**:
- **Dice Dashboard** — Roll any dice combination; results tracked
- **Combat Calculator** — Enter modifiers, get hit probability
- **Dual Input Roll** — For situations requiring two simultaneous rolls

**Reference Content**:
- **Weapon Tables** — Quick lookup for weapon stats (range, damage, special rules)
- **Cheat Sheet** — Core combat rules at a glance

**Setup Content**:
- **Pre-Battle Checklist** — Verify deployment is correct
- **Deployment Panel** — Review deployment conditions

## Combat Rules Quick Reference

### Basic Hit Resolution

1. Roll **1d6** per attack
2. Base hit threshold: **4+**
3. Apply modifiers:

| Modifier | Effect |
|----------|--------|
| Target in cover | -1 to hit |
| Aimed shot | +1 to hit |
| Ambush deployment | +2 to hit (first round) |
| Defensive position | +1 to hit |
| Long range | -1 to hit |

4. If hit, roll damage vs. target's Toughness
5. Target may get an armor save

### Armor Saves

- Subtract **1 per armor point** from the damage roll
- Light armor: 1 point
- Heavy armor: 2 points
- Powered armor: 3 points

### Hold Field

After battle, if you eliminated **3 or more enemies**, you "hold the field" and get bonus loot rolls in the post-battle phase.

### Morale

- Crew morale decreases when members are injured or killed
- Below 25 morale: crew suffers penalties
- Enemies have their own morale — they may flee when taking casualties

## Battle Flow

A typical battle follows this sequence:

1. **Deployment** — Place miniatures per deployment conditions
2. **Round 1** — Initiative, then alternating activations
3. **Rounds 2-6** — Combat continues; events may trigger at rounds 2 and 4
4. **Resolution** — When all enemies are eliminated, flee, or your crew retreats

Each round:
- Determine initiative order
- Activate units one at a time (alternating between sides)
- Each activation: move, shoot, or take a special action
- Reactions may trigger between activations (overwatch, counter-attacks)

## Tips for Battle

- **Use cover.** The -1 hit modifier for cover is significant — always position your crew behind terrain.
- **Focus fire.** Eliminating enemies reduces their actions per round. Don't spread damage around.
- **Watch your morale.** If morale gets low, consider tactical retreat over total party wipe.
- **Deploy smart.** Ambush deployment gives a massive +2 hit bonus in the first round.
- **Use the dice dashboard.** Even if you roll physical dice, entering results into the app keeps accurate records for the campaign journal.

## What's Next?

- Battle over? See {{chapter:07}} — Post-Battle Sequence for loot, injuries, and XP
- Want to understand character combat stats? See {{chapter:09}} — Characters and Crew
