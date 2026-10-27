# Chapter 12: Bug Hunt Mode

> **Quick Start** (for tabletop veterans)
> - Standalone military variant from the Compendium — NOT part of standard Five Parsecs
> - 4-step creation wizard: Regiment Config, Squad, Equipment, Review
> - 3-stage turn: Special Assignments, Mission, Post-Battle (vs 9-phase standard)
> - No ship, no patrons, no world exploration — pure squad-based combat
> - Character transfer between 5PFH and Bug Hunt via CharacterTransferService

## Overview

Bug Hunt is a standalone military campaign variant included in the Compendium DLC. It offers a streamlined, combat-focused experience where you lead a military squad against alien threats. If the standard Five Parsecs campaign is a crew-driven space opera, Bug Hunt is a tight, tactical military thriller.

Bug Hunt has its own campaign creation, turn structure, and progression system. It's a separate game mode — you access it from the Main Menu, not from within a standard campaign.

**Requires**: Compendium DLC (Fixer's Guidebook or complete Compendium pack)

## Key Differences from Standard Campaign

| Aspect | Standard Five Parsecs | Bug Hunt |
|--------|----------------------|----------|
| Campaign structure | 9-phase turn | 3-stage turn |
| Crew type | Mixed civilian crew | Military squad |
| Ship | Yes (travel, storage) | No |
| Patrons / Rivals | Yes | No |
| World exploration | Yes | No |
| Unit types | Crew members only | Main Characters + Grunts |
| Progression | XP + Credits | Mission-based |
| Special resource | Story Points | Reputation + Movie Magic |
| Save format | Standard campaign JSON | Separate Bug Hunt JSON |

## Creating a Bug Hunt Campaign

### Step 1: Regiment Configuration

- **Regiment Name** — Name your military unit
- **Difficulty** — Affects enemy strength and mission rewards
- **Campaign Escalation** — Toggle increasing difficulty over time

### Step 2: Squad Creation

Your squad has two types of members:

**Main Characters** (3-4):
- Full stat blocks (same six stats as standard 5PFH characters)
- Gain experience and advance
- Can be transferred to/from standard campaigns

**Grunts** (expendable pool):
- Simplified stat blocks
- No individual advancement
- Replenished between missions
- Casualties are expected

### Step 3: Equipment

- Distribute military-grade equipment across your squad
- Bug Hunt uses a separate equipment pool from standard campaigns
- Grunts receive standard-issue loadouts

### Step 4: Review and Start

Review your regiment setup and launch the campaign. The app creates a Bug Hunt save file and opens the Bug Hunt Dashboard.

## The Bug Hunt Dashboard

Your command center between missions:

- **Regiment Info** — Name, reputation, turn count
- **Squad Roster** — Main characters with stats and equipment
- **Grunt Pool** — Available expendable soldiers
- **Reputation** — Expendable resource for rerolls and bonuses
- **Movie Magic** — 10 one-time special abilities

## The 3-Stage Turn

### Stage 1: Special Assignments

Assign your main characters to between-mission activities:

- Training and skill development
- Morale-boosting activities
- Equipment maintenance
- Intel gathering

This is the Bug Hunt equivalent of the World Phase, but much simpler — no upkeep costs, no patron management, no world traits.

### Stage 2: Mission

Select and execute a combat mission:

- **Mission types**: Hold position, retrieve item, assassination, area sweep, escort, demolition
- **Enemy types**: Bug creatures with unique AI behaviors
- **Terrain**: Military bunkers, alien hives, derelict ships, wilderness outposts

The battle uses the same **TacticalBattleUI** as standard campaigns, but in `bug_hunt` mode:
- Morale tracker is hidden (Bug Hunt uses its own system)
- Contact Marker Panel is added (tracking detected threats)
- Standard battle features otherwise function the same

### Stage 3: Post-Battle

Resolve the aftermath:

- **Casualties** — Check main character injuries and grunt losses
- **Sick Bay** — Injured characters enter recovery
- **Loot** — Mission-specific rewards
- **Reputation** — Gained or lost based on performance
- **Movie Magic** — May earn additional one-time abilities

## Reputation

Reputation is a currency unique to Bug Hunt:

- Earned through successful missions
- Lost through failures and heavy casualties
- Can be **spent** for tactical advantages:
  - Reroll a critical dice result
  - Call in reinforcements
  - Request better equipment

## Movie Magic

10 special one-time abilities available to your squad:

These powerful abilities can turn the tide of a difficult battle but can only be used once per campaign. Use them wisely — saving them for truly desperate situations is often the best strategy.

## Character Transfer

The **CharacterTransferService** allows bidirectional character transfer between standard Five Parsecs campaigns and Bug Hunt:

### Transferring to Bug Hunt
- Select a character from your standard campaign
- Character undergoes an **enlistment roll** to join the military squad
- Stats and skills carry over
- Equipment may change to military standard

### Transferring from Bug Hunt
- Select a main character from your Bug Hunt campaign
- Character returns to civilian life
- Military experience carries over as stat bonuses

### Important Notes
- Transfer is between saved campaigns — both must exist
- Grunts cannot be transferred (they're expendable by design)
- Transfer creates a copy — the original remains in their campaign

## Tips for Bug Hunt

- **Protect your main characters.** Grunts are replaceable; main characters are not.
- **Spend reputation wisely.** It's tempting to reroll every bad result, but reputation is hard to earn back.
- **Use grunts as shields.** Position them to absorb enemy fire while main characters take key shots.
- **Save Movie Magic for emergencies.** One-time abilities are most valuable when things go very wrong.
- **Build combat teams.** Organize your squad into fire teams for better tactical coordination.

## What's Next?

- For standard campaign play: {{chapter:04}} — Campaign Turn Structure
- For character stats and species: {{chapter:09}} — Characters and Crew
- For DLC details: {{chapter:13}} — DLC and Expansion Content
