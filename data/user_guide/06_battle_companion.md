# Chapter 6: The Battle Companion

> **Quick Start** (for tabletop veterans)
> - The app is a **companion**, not a simulator — it gives text instructions for your physical tabletop
> - Three tracking tiers: Log Only (you track), Assisted (app suggests), Full Oracle (app resolves)
> - Slide-over drawers: Crew, Enemy Tracker, Battlefield Intel, Dice Roller, Battle Round Reference, Tracking, Mission Rules, Record Battle Result
> - To Hit: roll 1D6 plus Combat Skill; 3+ within 6" in the open, 5+ in range in the open, 6+ in range in Cover (Core Rules p.44)
> - Whether you Held the Field depends on how the battle ends (Core Rules p.115)

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

The full table companion — map, figure tracker, scenario rules, battle log. You roll every die yourself.

Best for:
- Experienced players who know the rules well
- Players who prefer to roll and decide everything at the table

What the app does:
- Shows the battlefield map, your crew and the enemy roster, and the mission's own rules
- Walks the battle round by round
- Keeps the dice roller, the Combat Calculator and the rules reference to hand
- Keeps the Battle Log, which goes into the campaign journal with the battle
- Records the result when you enter it

### Assisted

Adds the dice: reaction rolls, Seize the Initiative, end-of-round morale and condition checks, plus live objective tracking.

Best for:
- Players learning the rules
- Battles with many rules to keep track of

What the app does:
- Everything in Log Only, plus:
- Rolls the Reaction dice and Seize the Initiative
- Tracks enemy morale and Panic, and prompts the checks at the end of each round
- Tracks the mission objective as you play
- Shows the deployment conditions and resolves Battle Events when they are rolled

### Full Oracle

Adds an enemy AI oracle to the enemy tracker — reference, dice table or card draw. You still move the figures.

Best for:
- Solo players who want help deciding what the enemy does

What the app does:
- Everything in Assisted, plus an enemy oracle with three modes:
  - **Reference** shows each enemy's AI rules
  - **D6 Table** rolls the Compendium AI Variations (Compendium pp.42-43), and appears only when that option is on
  - **Card Oracle** draws a card and reads the enemy's action from its suit and rank

The core rules' enemy AI uses no dice (Core Rules p.42), and its instructions are shown at every tier. You still roll your own shots and move every figure.

You can raise the tier during a battle: tap the tier badge and pick a higher level. A tier cannot be lowered once the battle has started.

## The Battle Interface

The battle screen shows the battlefield, and the rest of its information sits in **slide-over drawers** that you open from the toolbar. Which drawers appear depends on your tracking tier and the mission:

- **Crew** - your deployed crew members, with their stats and status
- **Enemy Tracker** - the enemy roster, with each figure's type and status
- **Battlefield Intel** - the objective, visibility and terrain key
- **Dice Roller** - roll any dice combination; results are tracked
- **Battle Round Reference (Core Rules p.118)** - the round reference, with the cheat sheet and weapon tables
- **Tracking** - morale and panic tracking, victory progress and reaction dice
- **Mission Rules** - appears only when the mission has its own rules panel (stealth, street fight, salvage, No-Minis)
- **Record Battle Result** - where you enter the outcome when the battle ends

A **Battle Log** records what happens for the campaign journal.

## Combat Rules Quick Reference

### Basic Hit Resolution (Core Rules p.44)

1. Roll **1D6** per shot and add the firer's **Combat Skill**.
2. The target number depends on the shot:
   - Within 6" and in the open: **3+**
   - Within weapon range and in the open: **5+**
   - Within weapon range and in Cover: **6+**
   - Within 6" and in Cover: **5+** (errata v1.06 adds this row to the p.118 table)
3. If the modified score equals or exceeds the target number, the shot Hits.

### Resolving Hits (Core Rules p.46)

- Roll 1D6 and add the weapon's Damage. If the result equals or exceeds the target's **Toughness**, or is a natural 6, the target becomes a casualty.
- A lower roll pushes the target back 1" and Stuns it.
- A target with a Saving Throw (from armor or a screen) rolls 1D6 when it takes the Hit; a roll equal to or above the Saving Throw number negates the Hit, but the figure is still Stunned. See {{chapter:10}}.

### Holding the Field

Whether you Held the Field is set by how the battle ended (Core Rules p.115). It matters after the battle: it affects the Rival status roll, Battlefield Finds and the invasion check (Core Rules pp.119-121).

### Morale

Enemy morale is checked with Panic rolls (Core Rules p.114), which the Tracking drawer helps you keep at the Assisted tier and above. Some Battle Events change it (Core Rules p.116). There is no crew morale score in the rulebook.

## Battle Flow

A typical battle follows this sequence:

1. **Deployment** - place miniatures per the deployment conditions
2. **Rounds** - each round, resolve the reaction, quick action, enemy and slow action steps in order (Core Rules pp.40-41)
3. **Battle events** - optionally rolled at the end of round 2 and again at the end of round 4; no more are rolled (Core Rules p.116)
4. **Resolution** - the battle ends when the opposition is beaten, withdraws, or your crew leaves the field (Core Rules p.115)

## Tips for Battle

- **Use cover.** A target in Cover needs a 6+ to be hit at range, so position your crew behind terrain.
- **Focus fire.** Eliminating enemies reduces what they can do each round.
- **Use the Dice Roller.** Even if you roll physical dice, entering results into the app keeps accurate records for the campaign journal.

## What's Next?

- Battle over? See {{chapter:07}} — Post-Battle Sequence for loot, injuries, and XP
- Want to understand character combat stats? See {{chapter:09}} — Characters and Crew
