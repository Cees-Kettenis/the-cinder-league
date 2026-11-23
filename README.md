# The Cinder League

A turn-based fantasy gladiator RPG. The single-player playtest starts in the Amber Ring and runs through its level-4 tournament. Winning it opens the Iron Court and its level-8 tournament.

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

## Play

Select **Play** on the title screen, then choose a save slot. Enter a name and assign the starting points for a new gladiator. New gladiators start with a dagger that deals 7 base damage. The weaponsmith sells the short sword for 15 gold. It deals 10 base damage. Click the buildings on the town map to open the **Armory**, **Weaponsmith**, **Magic shop**, or **Arena**. Select an armor slot and a piece to see the try-on and armor-point change before purchasing. The magic shop plays spell previews, including locked spells. Gear, potions, and spell uses are reset for each new bout. Ember Etching is equipped separately from your active spell.

Movement, weapon attacks, and defence are grouped around your fighter. Hover over an action or focus it with the keyboard to see what it does, what it costs, or why it's unavailable. Fighters start five spaces apart in new bouts. Step in or back one space for 2 stamina, or leap in either direction up to three spaces for 6 stamina. Each movement takes a turn. Once the gap is smaller than the starting distance, the sword button offers **Lunge** if you are one or two spaces outside weapon reach. It moves you into reach and strikes at lower accuracy. It costs your weapon's usual stamina plus 7 and another 5 per space covered.

Within weapon reach, **Quick** attacks trade damage for accuracy and cost less stamina, **Normal** uses the weapon's usual stats, and **Power** attacks hit harder with lower accuracy and higher stamina cost. Each button shows damage and hit chance. The preview shows the rival's chance to block if hit and how much armor and health an ordinary unblocked hit would take. An unblocked Power hit pushes a surviving opponent back by one space, plus one more for every 12 Strength. A fighter pushed past either edge falls into the pit and immediately loses.

The crests at each top corner show the fighter's current and maximum health, armor, and stamina. Armor absorbs damage before health. Sleep restores stamina and exposes you to attacks. The game announces and takes a sleep turn when exhaustion leaves you without another legal action. Taunt can deal damage or force an aggressive move. Spells are less accurate within reach of an opponent who has enough stamina to attack.

New bouts use a 30-space arena with a pit at each end. The camera follows the fight and pulls back when the fighters spread out. Steps, jumps, attack ranges, and knockback use the same distances at any window size. Saved bouts keep their original arena width.

The **Pack** appears when you bring a spell or potion into the arena and shows how many uses remain. Fireball and Lightning Strike have two casts per bout. The heavier spells have one. A miss spends a cast, and sleeping only restores stamina. Bring a weapon to follow up after casting.

Choose **Scout rival** in the arena to reveal a randomly generated opponent near your level. Compare your stats, equipment, and reach before choosing **Fight**. You can go back to town or close the game and return to the same rival. A scouted tournament opponent stays in place while you fight regular bouts or buy gear. Your latest gear is used when you enter the ring.

Losing a regular bout costs up to 8 gold. At an arena's level cap, regular wins pay half gold and give no XP. You can keep earning gold for gear before entering the tournament. Beating the champion opens the next arena and grants enough XP for its opening level.

Amber Ring has one preliminary round before Idra Vale. Iron Court has two before Oren Voss. Preliminary builds are seeded for each tournament. The two champions have fixed builds. Tournament rounds started from **Fight to the death** are fatal on defeat. Tournament bouts already in progress before this update can finish without the new death rule. Rivals keep their appearance from scouting through the fight and any replay. Their decorative armor leaves the equipment and stats on the face-off screen as the source for planning the fight.

Use **Replace save** on an occupied slot to start a new gladiator. The game archives the previous save when you finish creating the replacement. Live careers are archived under `user://retired/`, and fallen gladiators under `user://fallen/`. The **Hall of Fame** on the title screen lists current and archived gladiators by tournaments won, level, and experience.

Shops show the price, requirements, and how gear changes your stats. In the magic shop, the play icon replays the spell preview. Press **Esc** to return to town from shops, the arena, and the pre-fight or results screens. On the title screen or in town, **Esc** opens the pause menu. **Settings** controls the display mode. Each shop has its own music, and the pre-fight screen, Amber Ring, and Iron Court each have a theme. **Audio** has separate switches for title music, Town Square music, shop and arena music, and game sounds such as the shop bell and the crowd during fights.

Each slot autosaves independently, including resolved turns during a duel. Closing the game mid-bout resumes the same fight when you continue the slot. A fight ends in victory or defeat. At the turn limit, the fighter with the higher percentage of health wins. The defender wins ties. Level-ups require assigning all earned points. Retrying a regular bout restores its saved starting conditions. Practice replays carry no fees or risk to the gladiator and leave campaign progress intact.

## Simulate

Open the pause menu from the title screen and choose **Settings** → **Simulator**. Choose fighter presets, level, seed, and number of bouts. Run a matchup batch or a campaign across both arenas. A campaign seed reproduces the rival draws and fight rolls. The result includes a turn-by-turn trace of the first bout.

The same combat rules are available from a terminal. Standalone simulator matchups can end in a draw.

```bash
godot --headless --path . --script scripts/simulate.gd -- --left=hybrid --right=mage --level=4 --bouts=20 --seed=42
godot --headless --path . --script scripts/simulate.gd -- --campaign --left=weapon --bouts=75 --seed=42
```

Preset names are `weapon`, `guard`, `mage`, `skirmish`, `charisma`, `hybrid`, `all_attack`, and `brute`. The terminal outputs JSON after Godot's startup banner.

Pass `--scenario=/absolute/path/scenario.json` to supply either side's full stat spread, a loadout, an opening distance, or a sequence of moves. A loadout uses the IDs in the balance file. Once scripted moves finish, the chosen AI presets continue the bout.

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

The supplied numbers are draft playtest values. Open **Playtest balance** from **Settings** on the title screen or from the simulator. A valid edit is saved to `user://balance.override.json` and used for subsequent bouts and simulator runs inside the game. Use **Load bundled draft into editor**, then **Apply and save profile**, to reset it. The terminal simulator uses [balance.json](balance.json) by default and accepts a custom file through `--balance=/absolute/path/balance.json`.

Item IDs, categories, and armor slots are stable so that existing saves can load across balance edits. A saved bout keeps its opening conditions, combat stats, and rewards. Previously recorded lunges are restored with their original cost and range. An older save that predates rule snapshots records the active profile when it first loads. Player stats, equipment, and campaign progress carry forward.

The art in the `art/` folder uses the approved cartoon concepts and matching original arena backdrops generated with the built-in ImageGen tool. The [unarmored base](art/gladiator-base.png) uses the original gladiator as its reference, with a bare head, plain clothes, and a free weapon hand on transparent alpha. In combat, the pelvis, spine, neck, head, and both arms and legs move independently. Weapons from the [weapon sheet](art/weapons.png) follow the weapon hand and also appear in the Weaponsmith. Shields follow the off hand, and helmets follow the head. The sound effects in `audio/` are synthesized samples for the playtest.


Run the save, duel, and UI regressions after importing the project.

```bash
godot --headless --path . --script tests/playtest.gd
```
