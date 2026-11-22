# The Cinder League development plan

Build an original cartoon gladiator RPG for Linux, macOS, and Windows with Godot 4 and typed GDScript. The game has a five-arena single-player campaign and two-player versus. Two players can build max-level gladiators and fight on one computer or join a player-hosted match from any of the three desktop platforms.

The goal for combat is for tactics to decide fights between comparable builds. Positioning, stamina, and timing should let different builds win in different ways. The game will be free and open source, with standalone downloads and Steam as an optional distribution channel.

**Current playtest.** The Godot project implements the first two arenas through level 8, with the town, shops, three save slots, and a seeded simulator. See [play and simulation instructions](README.md). The remaining arenas and multiplayer are later milestones. The playtest numbers live in [balance.json](balance.json) and can be changed in the game.

Numbers marked **playtest values** are starting points. Draft gear names and later champion concepts can change. Each milestone ends with a check that tells us when we can move on.

- [0. Prove Godot, art, audio, and networking](#0-prove-godot-art-audio-and-networking)
- [1. Design the duel rules and battle UI](#1-design-the-duel-rules-and-battle-ui)
- [2. Build the simulator and balance combat](#2-build-the-simulator-and-balance-combat)
- [3. Build the playable first arena](#3-build-the-playable-first-arena)
- [4. Expand to five arenas](#4-expand-to-five-arenas)
- [5. Build local and network versus](#5-build-local-and-network-versus)

## 0. Prove Godot, art, audio, and networking

**Deliverable.** A small Godot project with one playable sample duel, a headless test using the same rules, a peer-hosted match, and export presets for all three desktop platforms.

**Verified so far.** Godot 4.7.2 is installed on the development Linux machine. The full editor imported a test project in headless mode. A temporary project replayed 1,000 seeded combat trials with identical outcomes. Two local Godot processes exchanged and confirmed a single host-resolved turn over ENet. The playable sample, art and audio, and packaged builds are the remaining Milestone 0 work.

### Project and rules

- Create the Godot project and use the installed Godot 4 editor. Install the matching export templates and record the engine version alongside the project.
- Write a small typed GDScript rules module. Give it a starting state, a turn action, and a seeded random source. Return the updated state and a result the UI, simulator, and network match can all read.
- For the sample duel, implement a few representative actions such as attacking, guarding, and casting one spell. Use temporary values for damage, health, and costs. Milestone 1 defines the full action set and combat rules.
- Add a development scene with two fighters, basic controls for taking a turn, readable health and turns, and a clear bout result.
- Add a headless command to replay a fixed sequence. Run it twice with the same seed. Compare the resulting turns, health, and winner. Use the same rules module in the playable scene.

### Art and audio proof

- Make one original cartoon fighter from illustrated 2D parts. Use ImageGen where it helps develop original art, then prepare the pieces with consistent attachment points for the body, hair, armor, and weapon. Prepare enough alternatives to demonstrate swapping each of the three.
- Animate one attack. Check that hair and armor stay aligned, the hand keeps hold of the weapon, and swapped gear reads at the size it appears in battle.
- Add one enchantment effect attached to the moving weapon and one spell effect with a sound cue. Trigger the animation, effect, and sound from the resolved action.
- Play the packaged Linux build and check the swaps, attack pose, enchantment motion, spell, and sound. Package the same art, animation, and audio for Windows and macOS.

### Peer-hosted networking proof

- Add a minimal LAN host and join flow using Godot's ENet peer. Run the host and client as two processes on the development machine. Let each player take turns and finish the same bout.
- Keep combat messages behind Godot's `MultiplayerPeer` interface. Use the same action and result messages for ENet and a future Steam Networking Sockets peer. Keep ENet available in the standalone build.
- Let the player hosting the session resolve the turns. Bind each connection to its fighter. Before applying a turn, check who submitted it, whose turn it is, the turn number, whether the move and target are valid, and whether the fighter can pay the cost.
- Test that an invalid or duplicate turn leaves health, stamina, and turn order intact. Check that both processes agree on the outcome and the next player after a valid turn.
- Use this model for casual matches, where one player controls the host. If we add Steam internet matches, use Steam's authenticated connections and relay support.

### Desktop exports and early verification

- Produce a Linux build, a Windows build, and a macOS app bundle from the development setup using Godot's export templates.
- Run the exported Linux build locally to check presentation and the local two-process match. Run the headless replay as part of the same check.
- Once hosted CI is available, run each exported build headlessly on its target OS. Use the same replay and a two-process ENet bout on each runner and compare results. GitHub Actions is an option for running these checks once the project has a hosted repository.
- Plan hands-on Windows and macOS graphics and audio checks and mixed-platform matches for the versus milestone with volunteer playtesters.

**Ready when** the packaged Linux duel plays with its art and audio, both local processes finish an ENet match and agree on the result, the same rules run headlessly, and Godot can produce packages for Linux, macOS, and Windows. Track hosted smoke tests once CI is available.

## 1. Design the duel rules and battle UI

**Deliverable.** A written ruleset, an action list, a battle UI sketch, and a worked duel we can follow from the first turn to the result. The simulator in Milestone 2 will implement and tune these rules.

### The player and progression

- The campaign starts with character creation. Pick an empty slot from three save slots, name your gladiator, choose skin color and hair, and freely distribute starting points across the seven stats. The first playtest gives every player the same 10 starting points, a basic weapon, and enough gold for the opening bouts.
- At every level-up, distribute all newly earned points and confirm before continuing. Test 10 points per level-up. Preview what each point buys, including changes to hit chance, damage, blocking, health, recovery, and gear eligibility. Confirmed choices are permanent.
- Players can spend each new batch on any combination of stats. A weapon fighter can invest later points in Magic and buy spells once eligible. Builds develop through stat choices, purchases, and tactics.

| Stat | What investing in it does |
| --- | --- |
| Attack | Increases the chance to land a weapon attack, the chance to crit, and the multiplier for a critical hit. |
| Strength | Increases weapon damage and qualifies the fighter to equip stronger weapons. |
| Defence | Improves the chance to block and qualifies the fighter to buy armor. Stronger pieces require more Defence. |
| Magic | Improves spell hit chance and damage. Higher Magic qualifies the fighter to buy stronger spells at the magic shop. |
| Vitality | Increases maximum health and health regenerated each turn. |
| Stamina | Increases the energy pool for movement, jumps, and attacks, and increases stamina recovered by sleeping. |
| Charisma | Increases gold earned from bouts and improves taunts. |

Use the same starting point budget to sketch a weapon fighter, a defensive fighter, a spellcaster, a stamina-heavy duelist, a charisma fighter, and a hybrid. Also sketch an all-Attack build to see where its lack of protection will put it under pressure.

### Turn flow and legal actions

- Decide how the first turn is chosen and when it passes. A useful starting rule to test is one action per turn. Write down when costs are paid, when regeneration happens, and how the game detects a finishing blow, a win, or a draw.
- Decide how distance works. The two options discussed are close, reach, and far bands, or positions along the arena floor. Use a worked example to check how weapon range, steps, jumps, and retreat feel under each model.
- For each action, specify when it is legal, what it costs, what result it produces, and how long any effect lasts. Use that definition in the UI, AI, and multiplayer validation.

| Action | Behavior to test |
| --- | --- |
| Move | Advance or retreat. Position and weapon reach determine which attacks become available. |
| Jump | Cover more ground than a step at a higher stamina cost. Test whether it creates useful openings for escape and pursuit. |
| Attack | Require weapon range and stamina. Use Attack for accuracy and crits, and Strength with the weapon's base damage for the hit. Work out how guarding, blocks, and armor interact with the result. |
| Guard | Give the fighter a defensive choice when they expect a hit. Decide when the protection applies and whether blocking is possible outside guard. |
| Sleep | Recover stamina while leaving the fighter open to the opponent's next move. Decide when the exposure ends. |
| Taunt | Require a minimum amount of **current stamina**. A taunt can provoke an attack or deal damage. Decide the threshold, the stamina cost, and what a provoked fighter can do when an attack is out of range or unavailable. Check this for both AI opponents and human opponents. |
| Use a potion | Apply the potion's effect and spend one allowed use. Decide how many potions a fighter can bring and when the uses reset. |
| Cast a spell | Apply the spell's range, costs, and effects. Use Magic for accuracy and damage. Decide how many spells a fighter can bring and when their uses reset. |

Armor pieces contribute armor points as their only combat effect. Decide how those points absorb damage, how a hit carries over to health, and when armor points reset. Weapons can differ in reach, damage, and stamina cost. Decide what happens when a fighter runs out of energy and which actions can get them back into the fight.

### Numbers to test

| Mechanic | First playtest target |
| --- | --- |
| Starting and level-up points | 10 points at creation and 10 at each level-up. |
| Crits | Try 2% crit chance and 1.10× damage at the first step, then 4% and 1.20×. On a 10-damage weapon, those crits deal 11 and 12 damage. Decide whether the multiplier scales with Attack investment or character level. |
| Blocks | Try an additional percentage point of block chance per Defence point. Test low and high investment and settle when a block can happen. |
| Starter magic | The spell you can buy at the start should do about as much damage per hit as the starter weapon you can buy. |
| Magic at later tiers | Compare a fighter who invests in Magic with one who splits the same total points between Attack and Strength. Compare whole bouts so misses, crits, weapons, costs, and spell limits all count. |
| Regeneration | Try a small per-turn heal at low Vitality, with 10 HP as an example. Tune scaling against incoming damage so a tank can survive longer and fights still end. |
| Taunt | Use about 80% of a comparable weapon or spell hit as a starting point for the damage outcome. Judge provoke separately and test how extra gold affects gearing up. |

### Battle UI sketch

- Lay out a compact battle menu with clear groups for movement, attacks, defense, items, spells, and recovery. Keep **Taunt** and **Sleep** visible and easy to reach.
- Show each fighter's health, armor, and stamina, whose turn it is, and the current distance. Show relevant costs, hit chance, or range before commitment once the rules for those actions are settled.
- Explain unavailable actions beside the choice. For example, show the minimum current stamina needed to taunt or why a weapon can't reach. Show the result of the previous move so a player can tell whether it missed, was blocked, hit armor, or damaged health.
- Use the same rules and outcome labels in campaign and versus. The campaign supplies an AI opponent, and versus supplies a second player.

**Ready when** we can step through a complete duel on paper, including an out-of-range attack, too little stamina to taunt, a block or crit, an exhausted potion, and a finishing blow. With the same builds, we should be able to show how a different tactical choice can change the result.

## 2. Build the simulator and balance combat

**Deliverable.** A repeatable headless simulator that can run one turn at a time, play batches of bouts, and run a short first-arena campaign using the rules that will ship with the game.

### Implement the combat rules

- Start with movement, reach, weapon attacks, misses, crits, armor, and blocks. Then add jump, sleep, taunt, a potion, and a spell. Check each action against the rules and worked examples from Milestone 1.
- Use one implementation for the simulator, campaign, and versus. Give AI and scripted fighters the same actions, costs, and constraints as players.
- Add a basic AI. Give prototype opponents recognizable tendencies, such as closing the gap, guarding, or waiting for a good spell opening. Test that the player has a response once they recognize the pattern.

### Run and interpret fights

- Let us set both fighters' stats, equipment, supplies, and starting position. Run either a scripted sequence, an AI bout, or batches of AI bouts. A seed and a turn trace should let us reproduce a surprising fight and inspect what happened.
- Record the matchup, seed, winner, turn count, actions, damage, misses, blocks, and resource changes. When a rule changes, replay the same test cases and compare the results.
- Test weapon, defensive, magic, stamina-heavy, charisma, hybrid, and all-Attack builds. Use comparable levels and gear budgets. Try different tactics with the same matchup across several seeds. A single favorable roll is a poor balance target.
- Check exhaustion, repeated jumps, sleep, guarding, repeated taunts, and high-Vitality regeneration. Make sure fighters have useful responses when their preferred action is unavailable and that defensive matches can finish.
- Use stand-in opponents to explore the fast bruiser and armor-breaker concepts. Check how the mage, tank, hybrid, and all-Attack builds respond. Champion assignments remain draft.

### Simulate opening progression

- Start a new fighter with the proposed points, gold, and basic weapon. Simulate levels 1–4, regular bout rewards, purchases, level-up choices, and a first tournament.
- Try separate paths through the same arena. Include a fighter who starts in melee and begins investing in Magic. Check when the fighter can afford and qualify for a useful spell, and how much Defence a specialist needs to buy useful protection.
- Tune starting gold, XP thresholds, bout rewards, shop prices, and eligibility so the chosen opening is fair. Check that a losing player has a way to recover by changing tactics, adjusting gear, or going back to train.
- Use the first champion's job as the difficulty baseline. It should be a straightforward and slightly challenging opponent for a level-4 fighter using gear available in the first arena.

**Ready when** we can run one matchup or a first-arena run quickly, replay any result by seed, and find multiple viable builds that can reach and beat the first champion by making good choices.

## 3. Build the playable first arena

**Deliverable.** A player can start a campaign through the real UI, fight from level 1 through level 4, buy and use upgrades, and defeat the first champion.

### Start, play, and upgrade

- Show three save slots. Selecting an empty slot opens character creation. Selecting a filled slot resumes that gladiator. Confirm the name, skin color, hair, and freely assigned starting stats before starting.
- Begin with the basic weapon and starting gold tested in Milestone 2. Add the first arena, one playable battle screen based on the Milestone 1 sketch, and a result screen that shows what the bout earned.
- Add equipment and magic shops and a loadout screen with the five armor slots. Leather is the first armor tier. Each level makes at least one new weapon, armor piece, or magic item purchasable. Show the price and requirements before purchase. Strength qualifies a fighter to equip a weapon, Defence qualifies them to buy armor, and Magic qualifies them to buy spells.
- Award gold and XP in regular bouts. On every level-up, show the allocation screen. Require the player to spend and confirm all new points before going back to the arena or shop.
- Open the first tournament at level 4. Use a short series of bouts and finish with a straightforward gladiator at roughly the power of a reasonably equipped level-4 player. Give the champion a modest difficulty increase that tests the basics across playstyles.
- Make original art for the arena, fighter, shop gear, and champion. Reuse the techniques proven in Milestone 0. Check that visible gear stays aligned in the required combat poses and readable during a fight.

### Save, retry, and recover

- Keep the three campaigns independent. Save the bout's result and any pending level-up after every win or loss, including tournament bouts. If the player leaves during an allocation, reopen the allocation screen on resume. Save again when the player confirms the points.
- Keep the start of the latest bout alongside its saved result. Retry restores the same opponent, gear, and starting supplies for that bout. A win on a retry after a loss advances the campaign. Earlier tournament wins stay recorded.
- Offer a practice replay after a win. Keep the campaign's earned XP, gold, and tournament progress at the original settled result. Verify that replaying a win pays out once in total.
- Let the player leave a failed bout to change the loadout or train. Define what a loss costs and how tournament retries carry forward. Check the player has a route back to the fight when gold or supplies run low.
- Test restarting the game after a win, after a loss, and with an unconfirmed level-up. Test resuming both regular and tournament bouts and switching between save slots.

**Ready when** a fresh player can create and resume separate gladiators, get through the opening bouts with the starter resources, spend gold and permanent stat points, retry and resume correctly, and defeat the first champion.

## 4. Expand to five arenas

**Deliverable.** A full level 1–20 campaign with five tournaments, gear and spell progression, and original art that gets more elaborate as the player advances.

| Arena | Character levels | Tournament opens | Champion direction |
| --- | --- | --- | --- |
| 1 | 1–4 | Level 4 | Straightforward gladiator with comparable strength to the player and a modest difficulty increase. |
| 2 | 5–8 | Level 8 | Draft concept for a head gladiator. |
| 3 | 9–12 | Level 12 | Draft concept for a mage. |
| 4 | 13–16 | Level 16 | Draft concept for a tank with low damage and high survivability. |
| 5 | 17–20 | Level 20 | Open. |

### Arenas and champions

- Winning each of the first four tournaments opens the next arena. The fifth tournament completes the campaign. Set XP behavior at tournament gates and define what the player sees when they qualify or unlock the next arena.
- Plan opponent builds, the champion, shop stock, XP, gold, and art for one arena at a time. Test that a player can afford useful upgrades through regular play at each tier.
- Explore contrasting boss tactics. A fast bruiser could pressure a mage by closing the gap and hitting hard, while a tank can outlast the pressure. An armor breaker could telegraph a once-per-bout move that strips current armor points, which matters more against armor-heavy builds. Try these in simulation before assigning them to a champion.
- Test all champions against melee, magic, defensive, charisma, and hybrid builds using gear available at that level. Each playstyle should have a way to win. Make a boss's signature move readable and give the player a chance to respond. Tough matchups should reward adapting tactics, equipment, or later point allocations.

### Equipment and visual progression

- Plan the shop stock across levels 1–20. Each level adds at least one weapon, armor piece, or magic item to buy. Character level determines when something appears in the shop. Its stat requirement determines who can use the weapon or buy the armor or spell.
- The five armor slots are a chest plate that covers the shoulders, shield, helmet, pants, and shoes. Within each set the chest plate contributes the most armor points, followed by the shield, then the helmet and pants at equal value, then the shoes.
- Give each full set more total armor points than the previous set. Runeweave can look light and still protect more than the knight set. Use the first arena simulation to set the actual armor point values and Defence thresholds.
- Pair each set with a weapon from the same visual tier. Develop the weapons, armor, enchantments, and spell effects from simple to increasingly dramatic while keeping each action readable in combat.

| Draft armor set | Matching weapon | Visual direction |
| --- | --- | --- |
| Leather, available at level 1 | Simple short sword | Stitched hide, plain steel, and simple shapes. |
| Chainmail | Iron mace | Visible links, reinforced edges, and a blunt iron head. |
| Knight | Knight's longsword | Polished plates, a crested helm, and a broad shield. |
| Runeweave light armor | Runed saber | Slim plates over woven cloth, etched lines, and subtle light. |
| Starforged armor | Starforged greatsword | Dramatic shapes, dark metal, and bright inlays. |

The set names and matching weapons are draft themes. Pick their unlock levels after testing the shop progression. Ensure that spell upgrades, weapons, and protective purchases arrive often enough to keep all of the intended builds progressing.

**Ready when** several different builds can play a fresh campaign from level 1 to 20, get useful upgrades at each arena, retry and resume around tournament gates, and complete all five tournaments.

## 5. Build local and network versus

**Deliverable.** Two players can create max-level gladiators and fight or rematch on one computer or over a mixed-platform network match, using the same combat rules as the campaign.

### Build and fight on one computer

- Make versus immediately available. Give each player a setup screen for a level-20 fighter. Use the same freely assignable point budget for both, with access to the unlocked gear pool and the same stat requirements and potion and spell limits.
- If we keep 10 points at creation and 10 per level-up, a level-20 build has 200 spendable points from those grants. Confirm the final cap budget after campaign balancing.
- Let players review their builds before fighting. Decide whether they can see each other's selections during setup. Make each turn handoff clear and show the last action and its result.
- Decide how to choose the first player and when to call a draw. Offer a rematch with the same builds and a return to setup. Check that the rematch starts with fresh combat state, gear condition, and supplies.
- Test oversized or invalid allocations, identical builds, extreme stat spreads, and potion-heavy and spell-heavy loadouts. Verify that both players are held to the same setup rules.

### Play over the network

- Add host and join to the real game using the peer-hosted approach from Milestone 0. Let the match host validate the two builds, loadouts, and every turn. Present the agreed result and related graphics and audio on both machines.
- Test a full match, an invalid or repeated turn, a disconnect, and a rematch. Check that the game gives the remaining player a clear result when the connection ends.
- Before release, arrange playtests with Windows and macOS users. Play Linux–Windows, Linux–macOS, and Windows–macOS matches. Check that both players agree on turns, health, and the winner, and that they see and hear the corresponding effects.
- If we release on Steam, test joining through Steam lobbies using the Steam networking peer and the same turn protocol. Decide how standalone players should connect across different networks if we add internet play there.

**Ready when** a fresh install can start, finish, and replay a versus match on one computer and across the planned desktop pairings, with both players seeing the same state and result.

## Decisions still to make

| When | Decisions |
| --- | --- |
| During the duel design | Turn order, distance model, action costs, accuracy and crit scaling, block timing, armor point behavior, regeneration timing, low-stamina behavior, taunt threshold, and provoke. |
| During the first arena simulation | Starting and level-up point budgets, starting gold and weapon, XP and gold rewards, shop requirements, tournament length, and the effect of a loss. |
| During the first graphical arena | Final proportions, palettes, fighter poses, attachment points, and the number of gear variants. |
| Before network release | Setup visibility, draw and disconnect behavior, and connection options for players on different networks. |
| After balancing the standard campaign | Consider a separate hardcore mode and decide what a loss would cost there. |
| Before public release | Choose the game's open-source license. Record credits and redistribution terms for the original game assets and dependencies, including Godot's license notice. Publish the source and standalone builds when ready. Decide whether to release on Steam as well. |

Keep the original Flash reference file local. The public releases contain our original game and assets we can redistribute.

Steam can offer the game as a free download to players. The Steam Direct fee is currently US$100 per app for the publisher. Confirm the current fee and terms when deciding whether to publish there. [Steam free games](https://partner.steamgames.com/doc/store/freetoplay) · [Steam Direct fee](https://partner.steamgames.com/doc/gettingstarted/appfee)
