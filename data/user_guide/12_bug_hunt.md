# Chapter 12: Bug Hunt Mode

> **Quick Start** (for tabletop veterans)
> - Standalone military variant from the Compendium — NOT part of standard Five Parsecs
> - 4-step creation wizard: Regiment Config, Squad, Equipment, Review
> - 3-stage turn: Special Assignments, Mission, Post-Battle (vs 9-phase standard)
> - No ship, no patrons, no world exploration — pure squad-based combat
> - Character transfer between 5PFH and Bug Hunt via CharacterTransferService

## Overview

Bug Hunt is a standalone military campaign variant from the Compendium. It offers a streamlined, combat-focused experience where you lead a military squad against alien threats. If the standard Five Parsecs campaign is a crew-driven space opera, Bug Hunt is a tight, tactical military thriller.

Bug Hunt has its own campaign creation, turn structure, and progression system. It's a separate game mode — you access it from the Main Menu, not from within a standard campaign.

**Unlocking**: Bug Hunt is sold separately from the three Compendium packs, with its own card under **Game Modes** on the Store screen. In an alpha build the Main Menu button shows a "coming in a later release" note instead of opening the mode. See {{chapter:01}} and {{chapter:13}}.

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
- **Co-op Campaign Map** — only on a campaign created as co-op: the shared sector map, its Support pool and the end of the operational turn. See {{chapter:19}}.

## The 3-Stage Turn

### Stage 1: Special Assignments

Assign your main characters to between-mission activities:

- Training and skill development
- Morale-boosting activities
- Equipment maintenance
- Intel gathering

This is the Bug Hunt equivalent of the World Phase, but much simpler — no upkeep costs, no patron management, no world traits.

### Stage 2: Mission

Set the mission up on the Mission screen, then fight it on the battle screen.

- **Objectives** come from the Bug Hunt objective table (Compendium p.185): Patrol, Scout, Secure, Retrieve, Beacon and Hack.
- **Combat teams.** Choose how your grunts split into combat teams of 2-4 (p.173). The app keeps the split for the next mission. Main characters always act alone.

The battle screen is the one a standard campaign uses, set to Bug Hunt's rules:

- **Reaction dice.** Each main character rolls one die, and each combat team rolls one die for all its members (p.173). The result lists each team beside the characters.
- **No morale.** The morale tracker is hidden, and the standard campaign's Battle Events are not rolled.
- **Hits.** When you resolve a hit, a roll equal to the target's Toughness Wounds it, and a second Wound makes it a casualty (p.178).
- **Reference tab.** It holds the Bug Hunt combat rules and the p.179 weapon table, not the Core Rules sheet.
- **Tools tab.** It keeps the dice roller and the Combat Calculator, which follows Bug Hunt's hit table. The Character Quick Roll and the Brawl Resolver work Core Rules maths, so a Bug Hunt battle does not offer them.

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
- On the Bug Hunt dashboard, press **Enlist from 5PFH**
- Select a character from your standard campaign
- Character undergoes an **enlistment roll** to join the military squad
- Stats and skills carry over
- Equipment may change to military standard

### Transferring from Bug Hunt
- On the Bug Hunt dashboard, press **Muster Out to 5PFH**. A transfer file is written, and the standard campaign picks it up the next time you open its dashboard
- Select a main character from your Bug Hunt campaign
- Character returns to civilian life
- Military experience carries over as stat bonuses

### Important Notes
- Transfer is between saved campaigns — both must exist
- Grunts cannot be transferred (they're expendable by design)
- The character is removed from the campaign they left once they have arrived in the new one, so they exist in one campaign at a time

## Tips for Bug Hunt

- **Protect your main characters.** Grunts are replaceable; main characters are not.
- **Spend reputation wisely.** It's tempting to reroll every bad result, but reputation is hard to earn back.
- **Use grunts as shields.** Position them to absorb enemy fire while main characters take key shots.
- **Save Movie Magic for emergencies.** One-time abilities are most valuable when things go very wrong.
- **Keep combat teams in formation.** A team in formation gets the p.173 formation bonus on its Reaction roll, and the battle screen says when that bonus would let it act Quick.

## What's Next?

- For standard campaign play: {{chapter:04}} — Campaign Turn Structure
- For character stats and species: {{chapter:09}} — Characters and Crew
- To play Bug Hunt with several players on one shared map: {{chapter:19}} — Co-op Campaign
- For DLC details: {{chapter:13}} — DLC and Expansion Content
