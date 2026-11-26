# The Cinder League

A turn-based fantasy gladiator RPG. The single-player playtest runs through the Amber Ring, Iron Court, Glass Crucible, and Suncrest Bastion, with tournaments at levels 4, 8, 12, and 16.

## Install and run

1. Download the **Standard** [Godot 4.7.2 editor](https://godotengine.org/download/archive/4.7.2-stable/) for Linux, macOS, or Windows. Extract the download and open Godot.
2. Clone the repository with Git, or sign in to GitHub and choose **Code → Download ZIP** if you have access. Extract the ZIP if you downloaded it.
3. In Godot's Project Manager, choose **Import** and select [project.godot](project.godot) from the project folder. Open the project, wait for the assets to import, and press **F5** to play.

The editor includes GDScript, and the repository includes the game's assets. The editor is the only runtime dependency. Export templates are needed only to build standalone packages.

If Godot is on your PATH, you can also run these commands from the project folder. The first command imports the assets for a fresh checkout.

```bash
godot --headless --path . --import
godot --path .
```

## Build desktop releases

The current version is **Alpha 0.1**. Run **Desktop release** from the Actions tab to build Linux x86-64, Windows x86-64, and macOS Universal packages. The run uploads the three packages and their SHA-256 checksums as the `cinder-league-desktop` artifact. The Windows archive keeps the executable and its `.pck` together. The macOS app is ad-hoc signed and is unnotarized.

To publish Alpha 0.1, tag the commit containing the workflow and game assets, then push the tag. GitHub Actions publishes the packages as a prerelease after the tests and all three exports pass.

```bash
git tag v0.1-alpha
git push origin v0.1-alpha
```

On Linux, the same build script works with the matching Godot editor and export templates installed. Pass an output directory to use a location other than `dist/`.

```bash
bash tools/build-release.sh
```

## Play

Select **Play** on the title screen, then choose a save slot. Enter a name and assign the starting points for a new gladiator. New gladiators start with a dagger that deals 7 base damage. The weaponsmith sells the short sword for 15 gold. It deals 10 base damage. Click the buildings on the town map to open the **Armory**, **Weaponsmith**, **Magic shop**, or **Arena**. Select an armor slot and a piece to see the try-on and armor-point change before purchasing. The magic shop plays spell previews, including locked spells. Gear, potions, and spell uses are reset for each new bout. Ember Etching is equipped separately from your active spell.

Movement, weapon attacks, and defence are grouped around your fighter. Hover over an action or focus it with the keyboard to see what it does, what it costs, or why it's unavailable. Fighters start five spaces apart in new bouts. A step takes a turn and costs 2 stamina. A leap takes a turn and costs 6. Each Stamina point adds to your stamina pool and sleep recovery. Steps cover one space, or two at 5 Stamina. Leaps cover three spaces, or four at 10 Stamina. These distances apply in either direction. Hover over Stamina while assigning points to see your leap distance.

Once either fighter moves from their starting position, the sword button offers **Lunge** from up to two spaces outside weapon reach. This increases to three spaces at 5 Stamina. A lunge moves you into your weapon's normal reach and strikes at 20 percentage points below normal accuracy, with another 8 points off for the third space. It costs your weapon's usual stamina plus 7 and another 5 per space covered.

Within weapon reach, **Quick** attacks trade damage for accuracy and cost less stamina, **Normal** uses the weapon's usual stats, and **Power** attacks hit harder with lower accuracy and higher stamina cost. Each button shows damage and hit chance. The preview shows the rival's chance to block if hit and how much armor and health an ordinary unblocked hit would take. An unblocked Power hit pushes a surviving opponent back by one space, plus one more for every 12 Strength. In a death match, a fighter pushed past either edge falls into the pit and immediately loses. Regular bouts stop the shove at the edge.

Strength adds 1.23 weapon damage per point up to 12 Strength or a quarter of your assigned stat points, whichever is higher. Each Strength point above that threshold adds 0.2 damage. Hover over Strength when assigning points to see your damage and threshold.

The crests at each top corner show the fighter's current and maximum health, armor, and stamina. Armor absorbs damage before health. Sleep restores stamina and exposes you to attacks. The game announces and takes a sleep turn when exhaustion leaves you without another legal action. Taunt can deal damage or force an aggressive move. Spells are less accurate within reach of an opponent who has enough stamina to attack.

New bouts use a 30-space arena with a pit at each end. The camera follows the fight and pulls back when the fighters spread out. Steps, jumps, attack ranges, and knockback use the same distances at any window size. Saved bouts keep their original arena width.

The **Pack** shows remaining spell casts and, in death matches, healing potions. Every point of Magic adds 0.8 spell damage and reduces incoming spell damage by 0.35 before armor. Each spell starts with two casts, and every 10 Magic adds one cast. Each cast still costs the stamina shown in the Magic shop. At 30 Magic, use **Equip as reserve** to spend one of your bonus casts on a different spell. These rules apply to regular bouts and death matches. Spells can finish bouts from range, and a ranged hit against a full-health fighter in a regular bout leaves them with at least 20% health. A miss spends a cast, and sleeping only restores stamina.

Choose **Scout rival** in the arena to reveal a randomly generated opponent near your level. Compare your stats, equipment, and reach before choosing **Fight**. From level 4, some regular rivals are fast melee fighters who can leap into weapon reach on their first turn. You can go back to town or close the game and return to the same rival. A scouted tournament opponent stays in place while you fight regular bouts or buy gear. Your latest gear is used when you enter the ring.

At level 4, the Armory stocks the chainmail chest plate and iron-rimmed shield at 5 Defence. The other chainmail pieces arrive at level 5. Forked Lightning unlocks at level 4 in the Magic shop. Use spells to chip away at armor while the rival closes, then switch to a weapon when they can pressure your casts. A melee fighter can spend stamina to close the gap early, and a caster can retreat to stay outside weapon reach.

In a regular bout, a fighter below **20% health** kneels to yield. Losing costs up to 8 gold. At an arena's level cap, regular wins pay half gold and give no XP. You can keep earning gold for gear before entering the tournament. Beating the champion opens the next arena and grants enough XP for its opening level.

Amber Ring has one preliminary round before Idra Vale. Iron Court has two before Oren Voss. The Glass Crucible has three before Veyra Ashglass, a mobile mage. The Suncrest Bastion is a gilded mountain court with four rounds before Garran Stoneward, an armored defender. Preliminary builds are seeded for each tournament. The champions have fixed builds. **Fight to the death** commits you to the tournament until you win it or fall. A fatal Power attack with a blade severs the weapon arm. Fatal fire spells char the body, and fatal lightning spells leave a pile of ash. If you close the game between rounds, continuing the slot takes you to the next match. Rivals keep their appearance from scouting through the fight. The face-off screen lists their equipped gear and combat stats.

If you already won the Iron Court, continue your save to allocate your level-9 points and open the Glass Crucible. Its shops add the long-reaching Glass sabre, Prism Pop, and the first Glassguard pieces at level 9. Level 10 brings Pocket Anvil and heavier Glassguard pieces. Level 11 brings Bellringer and completes the armor set. Royal Tantrum unlocks at level 12.

If you already won the Glass Crucible, continue your save to allocate your level-13 points and open the Suncrest Bastion. Its shops add the Rampart blade, Dawnbolt, and Suncrest helmet and pants at level 13. The Suncrest chest plate and shield arrive at level 14. Gatebreaker and Suncrest boots arrive at level 15. Sunseal unlocks at level 16.

Use **Replace save** on an occupied slot to start a new gladiator. The game archives the previous save when you finish creating the replacement. Live careers are archived under `user://retired/`, and fallen gladiators under `user://fallen/`. The **Hall of Fame** on the title screen lists current and archived gladiators by tournaments won, level, and experience.

Shops show the price, requirements, and how gear changes your stats. In the magic shop, the play icon replays the spell preview. **Esc** goes back from shops, the arena, and unlocked face-off or results screens. On the title screen or in town, **Esc** opens the pause menu. From the results bar, **T** returns to town when available, and **N** scouts the next bout or tournament match. Change these keys under **Settings → Controls**. Choose **Windowed** or **Fullscreen** in **Settings**. The selected mode applies to every screen. Each shop and arena fight has its own track. Face-offs build tension, victories open with a fanfare, and defeats get a quieter cue. **Audio** has separate switches for title music, Town Square music, shop and arena music, and game sounds such as the shop bell and the crowd during fights.

Each slot autosaves independently, including resolved turns during a duel. Closing the game mid-bout resumes the same fight when you continue the slot. The winner celebrates in the arena while the bottom bar shows the result and animates any XP and gold changes. At the turn limit, the fighter with the higher percentage of health wins. The defender wins ties. Level-ups require assigning all earned points. After a regular defeat, you can return to town or scout a new rival.

## Armor sprites

Each set has a folder in [content/gear/armor](content/gear/armor) with its WebP textures and `armor.gd` definition. A player set's definition contains the shop items, armor points, and sprite placements. Start each item ID with the set folder name followed by an underscore. Place helmets, chest pieces, and shields relative to the head, spine, and off wrist. Pants and boot pairs map rows of the artwork to the base fighter's legs.

Rivals mix helmets, chest pieces, pants, boots, and shields from their own armor sets. Maintain at least as many rival sets as player sets. Each rival set defines its unlock level and its position in the seeded outfit roll. Later rivals favor recent sets and can still use earlier pieces. The player level and encounter seed determine the look. Armor points come from the rival's combat loadout, so changing its appearance leaves those points alone.

Each weapon folder in [content/gear/weapons](content/gear/weapons) contains `weapon.gd` with its shop and combat stats, plus separate `player.webp` and `rival.webp` sprites. Use hyphens in the folder name and underscores in the item ID. Record the grip and striking point in each sprite's pixel coordinates. The weapon listed on the face-off gives its name and reach for the bout.

Helmets wrap around the temples and cheeks. Leather and reinforced leather leave the base shirt visible at the neckline. Chainmail, Court, Glassguard, and Suncrest cover it with fitted collars. The Court rectangle, Glassguard kite, and Suncrest tower shield use the same off-hand grip as the round shields.

Court, Glassguard, and Suncrest chest pieces include weapon-arm protection. Separate upper-arm plates, bracers, and gauntlets follow the shoulder, elbow, and wrist, with fitted padding beneath the joints. Their `weapon_arm` placements map texture pixels to the base fighter's rest pose. Closed helmets hide the covered base head and hair while keeping the neck visible.

## Add an arena

Add a folder to [content/arenas](content/arenas) with `arena.json`, `backdrop.webp`, `backdrop-compact.webp`, and `fight.ogg`. The JSON defines the level cap, XP thresholds, rewards, rivals, and tournament rounds. Give it the next consecutive `order` value. Keep existing order values stable because campaign saves and seeded tournaments use them. Add gear under `content/gear/` as needed.

The [fight controller](game/combat/fight_screen.gd) receives a saved bout, runs each turn, and updates the arena and HUD. The [duel engine](game/combat/duel.gd) resolves moves and damage for both the game and the simulator. The [campaign](game/campaign/campaign.gd) owns save slots, rewards, and tournament progression. The [content catalog](game/catalog/content_catalog.gd) assembles the arena and gear definitions into the balance profile they use.

Use the same crop for the full-size and compact backdrop. The title and town have their own backdrop pairs under [game/screens](game/screens). The compact art is up to 1280 pixels wide and loads in windows with a longest edge of 1366 pixels or less. Wider windows use the full-size art, including 1080p, 1440p, and 4K. Godot scales the artwork to fit the viewport. Painted backdrops and fighter gear use Godot's lossy WebP texture import. Keep gear placement coordinates in the original sprite's pixel dimensions.

## Simulate

Open the pause menu from the title screen and choose **Settings** → **Simulator**. Choose fighter presets, level, seed, and number of bouts. Run regular bouts, death matches, or a campaign across all four arenas. A campaign seed reproduces the rival draws and fight rolls. The result includes a turn-by-turn trace of the first bout.

The same combat rules are available from a terminal. Matchup batches use regular bout rules by default. Add `--death-match` to use tournament combat rules. Standalone simulator matchups can end in a draw.

```bash
godot --headless --path . --script tools/simulate.gd -- --left=hybrid --right=mage --level=4 --bouts=20 --seed=42
godot --headless --path . --script tools/simulate.gd -- --campaign --left=weapon --bouts=75 --seed=42
```

Preset names are `weapon`, `guard`, `mage`, `skirmish`, `charisma`, `hybrid`, `all_attack`, and `brute`. The terminal outputs JSON after Godot's startup banner.

The Simulator also offers **Keepaway Mage**, **Melee Hunter**, and **Adaptive Hybrid**. Each uses the stats and gear of its original preset. Keepaway Mage looks for a safe retreat when pressured and spends casts while it has room. Melee Hunter adjusts its approach against an armed caster and budgets for follow-up swings. Adaptive Hybrid can switch between those tactics as the matchup changes. Select them for either side in a matchup or as the fighter in a campaign simulation. Their terminal names are `keepaway_mage`, `melee_hunter`, and `adaptive_hybrid`.

**Fast Melee** (`fast_melee`) uses the Melee Hunter tactics and puts more points into Stamina. At level 4, it trades 2 Vitality for 2 Stamina compared with Melee Hunter.

Pass `--scenario=/absolute/path/scenario.json` to supply either side's full stat spread, a loadout, an opening distance, or a sequence of moves. A loadout uses the IDs in the balance file. A qualifying loadout can set `reserve_spell` to a spell distinct from its main `spell` and use `cast_reserve` in the script. Once scripted moves finish, the chosen AI presets continue the bout.

```json
{
  "distance": 4,
  "left_stats": {
    "Attack": 2,
    "Strength": 2,
    "Defence": 2,
    "Magic": 2,
    "Vitality": 1,
    "Stamina": 1,
    "Charisma": 0
  },
  "left_loadout": {"weapon": "sword", "armor": {"chest": "leather_chest"}, "spell": "fireball", "potion": true},
  "actions": ["cast"]
}
```

## Review the balance

The supplied numbers are draft playtest values. Open **Playtest balance** from **Settings** on the title screen or from the simulator. A valid edit is saved to `user://balance.override.json` and used for subsequent bouts and simulator runs inside the game. Use **Load bundled draft into editor**, then **Apply and save profile**, to reset it. The bundled profile combines [balance.json](content/balance.json) with the arena and gear definitions. The terminal simulator uses this profile by default and accepts a complete override through `--balance=/absolute/path/balance.json`.

Item IDs, categories, and armor slots are stable so that existing saves can load across balance edits. A saved bout keeps its opening conditions, combat stats, and rewards. Previously recorded lunges are restored with their original cost and range. An older save that predates rule snapshots records the active profile when it first loads. Player stats, equipment, and campaign progress carry forward.

The [unarmored base](game/combat/rig/gladiator-base.png) has a bare head, plain clothes, and a free weapon hand. In combat, the pelvis, spine, neck, head, arms, and legs move independently. Weapon sprites follow the weapon hand and also appear in the Weaponsmith. Shields follow the off hand, and helmets follow the head.

Spell effects, icons, and cast sounds live under [content/spells](content/spells). Shared music, combat sounds, interface sounds and arena ambience live under [game/audio](game/audio). Archived artwork and art prompts are under [docs](docs).

The town, shop, and arena scores use instruments from Frank Wen's [FluidR3 SoundFont](docs/licenses/FluidR3-LICENSE.txt).


Run the content check and the save, duel, and UI regressions after importing the project.

```bash
godot --headless --path . --script tools/check_content.gd
godot --headless --path . --script tests/playtest.gd
```
