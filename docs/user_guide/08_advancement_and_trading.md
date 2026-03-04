# Chapter 8: Advancement and Trading

> **Quick Start** (for tabletop veterans)
> - Stat upgrade costs: Combat/Reaction 7 XP, Speed/Savvy 5 XP, Toughness 6 XP, Luck 10 XP
> - Bots/Precursors use credits instead of XP (same cost structure)
> - Skill training: 15-20 credits, requires multiple turns of Train crew task first
> - Trading: buy at full price, sell at 50% (damaged items sell at 25%)
> - Available marketplace inventory depends on world tech level

## Overview

Advancement and Trading are the two phases where you invest in your crew's long-term growth. Advancement lets you spend XP on stat improvements and new skills. Trading lets you buy and sell equipment to keep your crew well-armed.

## The Advancement Phase

### Spending XP

Each stat has a per-point upgrade cost:

| Stat | Cost per +1 | Max (Human) |
|------|------------|-------------|
| Combat | 7 XP | 5 |
| Reaction | 7 XP | 6 |
| Speed | 5 XP | 8 |
| Savvy | 5 XP | 5 |
| Toughness | 6 XP | 6 |
| Luck | 10 XP | 3 |

**Maximum stats** vary by species. Bots have higher Toughness caps (8) but no Luck. See {{chapter:09}} for species-specific limits.

### Bot and Precursor Upgrades

Bots and Precursors don't use XP. Instead, they upgrade using **credits**:

| Upgrade | Cost |
|---------|------|
| Combat Module | 10-15 credits |
| Reflex Enhancer | 10-15 credits |
| Armor Plating | 15-20 credits |
| Speed Actuator | 10-15 credits |

These upgrades are purchased during the Advancement Phase just like XP spending.

### Skill Training

Skills provide permanent bonuses. Available skills:

| Skill | Benefit |
|-------|---------|
| Pilot | Better travel events, ship handling |
| Mechanic | Ship repair efficiency, jury-rigging |
| Medical | Injury treatment, recovery speed |
| Merchant | Better trade prices, deal-finding |
| Security | Guard effectiveness, trap detection |
| Broker | Patron job bonuses, negotiation |
| Bot Tech | Bot repair and modification |

Training requirements:
1. Assign the crew member to the **Train** task during multiple World Phases
2. Accumulate enough training points
3. Pay 15-20 credits for the skill
4. **Soulless characters cannot train** (species restriction)

### Decision Guidance

- **Luck is the most expensive stat** (10 XP) but extremely powerful — rerolls save lives
- **Combat and Reaction** are the most impactful combat stats — prioritize for frontline fighters
- **Savvy** helps with non-combat tasks and events
- **Save XP for big upgrades** rather than spending 1-2 XP on minor gains each turn
- **Skills compound over time** — investing in Medical early saves credits on injury treatment later

## The Trading Phase

### Buying Equipment

The marketplace offers weapons, armor, and gear. Available inventory depends on:

- **World tech level** (0-12) — Higher tech = better equipment available
- **Random availability** — Not everything is available every turn
- **Special items** — Some equipment only appears through events or quests

Browse the marketplace, compare equipment stats, and purchase what you need.

### Selling Equipment

Sell unwanted or duplicate gear:

| Condition | Sale Price |
|-----------|-----------|
| Good condition | 50% of full price |
| Damaged | 25% of full price |
| Heavily damaged | 10% of full price |

The app calculates sell prices automatically using the `EquipmentManager.get_sell_value()` system.

### Equipment Repair

Damaged equipment can be repaired:
- Repair cost varies by item type and damage severity
- Repairing is usually cheaper than buying a replacement
- Severely damaged items may not be worth repairing

### Trading Tips

- **Sell duplicates.** You don't need three of the same weapon — sell extras for credits.
- **Check tech level before buying.** High-tech worlds have better equipment but higher prices.
- **Repair before selling.** Repairing damaged gear first often nets you more than selling it as-is.
- **Keep a rainy-day fund.** Don't spend all credits on equipment — upkeep costs come next turn.

## What's Next?

- For character details and species: {{chapter:09}} — Characters and Crew
- For equipment types and stats: {{chapter:10}} — Equipment and Weapons
