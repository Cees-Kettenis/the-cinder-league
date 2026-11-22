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

Choose a save slot, enter a name, and assign the starting points. From town you can enter the **Armory**, **Weaponsmith**, **Magic shop**, or **Arena**. Select an armor slot and a piece to see the try-on and armor-point change before purchasing. The magic shop plays spell previews, including locked spells. Gear, potions, and spell uses are reset for each new bout. Ember Etching is equipped separately from your active spell.

During a duel select an action. Its stamina cost, hit chance, or reason it is unavailable appears on the button. Movement changes the distance along a short arena floor. Armor absorbs damage before health. Sleep restores stamina and exposes you to attacks. Taunt needs the displayed amount of current stamina and can deal damage or force an aggressive move.

The arena menu shows the next opponent and the gold and XP available for a win. Watch your XP toward the next level in town, at the arena, and after each bout. Shops show how a purchase changes your stats and confirm the amount of gold spent. Use **Replay spell preview** in the magic shop to hear the spell. The **Sound on** control at the top of each screen toggles game sounds.

Each slot autosaves independently. Level-ups require assigning all available points. Retrying restores the saved beginning of a bout. Practice replays leave campaign rewards and tournament progress at their saved values.

## Simulate

Open **Simulator** from the title screen. Choose fighter presets, level, seed, and number of bouts. Run a matchup batch or a campaign across both arenas. The result includes a turn-by-turn trace of the first bout.

The same rules are available from a terminal.

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

The supplied numbers are draft playtest values. Open **Playtest balance** to edit and apply them. A valid edit is saved to `user://balance.override.json` and used for subsequent bouts and simulator runs inside the game. Use **Load bundled draft into editor**, then **Apply and save profile**, to reset it. The terminal simulator uses [balance.json](balance.json) by default and accepts a custom file through `--balance=/absolute/path/balance.json`.

Item IDs, categories, and armor slots are stable so that existing saves can load across balance edits. An already-started bout keeps its stored opponent and loadout.

The art in the `art/` folder uses the approved cartoon concepts and matching original arena backdrops generated with the built-in ImageGen tool. Idle and try-on poses layer equipment per slot. The combat poses include leather, chainmail with an iron mace, and a hooded spellcaster. Mixed gear uses movement and recoil over the equipped look. The sound effects in `audio/` are synthesized samples for the playtest.

The two additional pose-sheet edits used [motion.png](art/motion.png) as the layout reference. The [chainmail sheet](art/motion-mail.png) uses the steel cap, mail tunic, blue cloth, bronze trim, and iron mace from [mail.png](art/mail.png). The [mage sheet](art/motion-mage.png) uses a plum hood, teal wool, and a talisman shield. Both retain the eight frame positions, poses, feet baselines, and transparent background of the reference.
