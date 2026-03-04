# Chapter 4: Campaign Turn Structure

> **Quick Start** (for tabletop veterans)
> - Each turn follows 9 phases: Story, Travel, World (6 sub-steps), Battle Setup, Battle, Battle Resolution, Post-Battle (14 steps), Advancement, Trading, Character, End
> - The Turn Controller walks you through each phase with a panel UI
> - Phases auto-advance when you complete each one — no need to track manually
> - The World Phase contains the bulk of between-battle decisions (upkeep, crew tasks, jobs, equipment, rumors, mission prep)

## Overview

A campaign turn represents one period of activity for your crew. Each turn, you'll travel (or stay put), manage your crew, take on a mission, fight a battle, and deal with the aftermath. The app walks you through every phase in order.

The **Campaign Turn Controller** is the screen that manages this flow. It presents a panel for each phase, advancing automatically as you complete each one. You can't skip phases, but some phases resolve quickly if there's nothing to decide.

## The Nine Phases

Here's the complete turn structure at a glance:

| Phase | What Happens | Your Role |
|-------|-------------|-----------|
| **Story** | A narrative event plays out | Read and respond |
| **Travel** | Decide whether to move to a new world | Choose destination |
| **World** | Manage your crew, find jobs, prepare for battle | Many decisions (6 sub-steps) |
| **Battle Setup** | Battlefield and enemies are generated | Review setup |
| **Battle** | Fight the mission on your tabletop | Execute combat |
| **Battle Resolution** | Victory or defeat is determined | Review outcome |
| **Post-Battle** | Resolve loot, injuries, XP, events (14 steps) | Review and choose |
| **Advancement** | Spend XP on stat upgrades | Choose upgrades |
| **Trading** | Buy and sell equipment | Manage inventory |
| **Character** | Personal crew events resolve | Read and respond |
| **End** | Turn wraps up, victory check | Continue or end |

### Story Phase

A random story event occurs based on your campaign's narrative state. You'll read the event description and any choices it presents. Story events can:

- Grant or remove story points
- Start new quest chains
- Affect crew morale
- Introduce new patrons or rivals

Some events are purely narrative; others require dice rolls with mechanical consequences.

### Travel Phase

You decide whether to stay on your current world or travel to a new one.

**Staying** is free — you continue operating on the same world.

**Traveling** costs credits:
- **Starship travel**: 5 credits (using your own ship)
- **Commercial passage**: 1 credit per crew member

If you travel, you may encounter a **travel event** (rolled on a D100 table) — things like asteroid fields, pirates, navigation trouble, or discovered wrecks.

If your current world is under **invasion**, you may need to flee (roll 2d6, need 8+ to escape).

See {{chapter:05}} for full travel details.

### World Phase (6 Sub-Steps)

The World Phase is where most of your between-battle decisions happen. It contains six sub-steps:

1. **Upkeep** — Pay maintenance costs (1 credit per crew member per turn, plus ship costs)
2. **Crew Tasks** — Assign each crew member a task: guard ship, repair, scout, seek patrons, train, rest, etc.
3. **Job Offers** — Review available patron missions with rewards and difficulty ratings
4. **Assign Equipment** — Redistribute weapons and gear among your crew
5. **Resolve Rumors** — Follow up on leads that may start quests
6. **Mission Prep** — Choose which battle to undertake (or skip this turn)

See {{chapter:05}} for detailed guidance on each sub-step.

### Battle Setup

Once you've chosen a mission, the app generates the battlefield:

- **Terrain layout** — A 4x4 sector grid with terrain features (buildings, walls, rocks, trees, cover)
- **Enemy forces** — Generated based on mission type and difficulty
- **Deployment conditions** — Where your crew starts (standard, ambush, surrounded, etc.)
- **Objectives** — What you need to accomplish

You'll review this setup and select which crew members to deploy. See {{chapter:06}} for battle details.

### Battle

The battle phase uses the **Battle Companion** — a tabletop assistant that helps you run combat on your physical playing surface. The companion provides text instructions, tracks activations, and handles dice rolls.

Three tracking tiers are available:
- **Log Only** — You run everything on the tabletop; the app just records results
- **Assisted** — The app suggests actions and reminds you of rules
- **Full Oracle** — The app resolves all mechanics, you just move miniatures

See {{chapter:06}} for the complete battle system guide.

### Battle Resolution

After battle, the app determines the outcome:

- **Victory** — Your crew eliminated enough enemies or completed the objective
- **Defeat** — Your crew was forced to retreat or suffered too many casualties
- **Hold Field** — You eliminated 3+ enemies and can search the battlefield for bonus loot

### Post-Battle Sequence (14 Steps)

The most detailed phase — 14 sequential steps resolve everything that happens after a fight:

1. Resolve rival status
2. Resolve patron status
3. Determine quest progress
4. Get paid (base + danger + difficulty bonus)
5. Battlefield finds
6. Check for invasion
7. Gather loot
8. Determine injuries (D100 injury table)
9. Experience and upgrades
10. Advanced training
11. Purchase items
12. Campaign event
13. Character event
14. Galactic war check

See {{chapter:07}} for full details on each step.

### Advancement Phase

Spend accumulated XP to improve your crew:

- Each stat costs XP to increase (costs scale upward)
- Bots and Precursors use credits instead of XP
- Special training unlocks new abilities

See {{chapter:08}} for advancement details.

### Trading Phase

Buy and sell equipment at the local marketplace:

- Available inventory depends on the world's tech level
- Damaged equipment sells at reduced prices
- You can repair damaged gear for a cost

See {{chapter:08}} for trading details.

### Character Phase

Personal events for individual crew members:

- Development opportunities (new skills, contacts)
- Complications (addictions, rivals, romantic entanglements)
- These events add narrative flavor and mechanical consequences

### End Phase

The turn wraps up:

- Victory conditions are checked against your progress
- If any condition is met, your campaign is won
- Otherwise, the turn counter advances and a new turn begins
- You can choose to end the campaign at any time, even without meeting a victory condition

## Turn Flow Tips

- **Save before risky phases.** The app auto-saves at turn start, but manual saves before battles are wise.
- **Don't skip the World Phase.** Crew task assignments and equipment management matter more than you'd think.
- **Read event text carefully.** Story and character events often present choices that affect future turns.
- **Track your victory progress.** The End Phase summary shows how close you are to winning.

## What's Next?

- For Travel and World Phase details: {{chapter:05}}
- For the Battle Companion system: {{chapter:06}}
- For Post-Battle resolution: {{chapter:07}}
