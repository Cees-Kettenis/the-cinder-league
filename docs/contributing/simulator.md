# Simulator and balance profiles

The simulator uses the same duel rules as the playable fight. Open pause on the title screen, then choose **Settings → Simulator** to pick fighter presets, a level, seed, and number of bouts. Run regular bouts, death matches, or a campaign. The results include a turn-by-turn trace for the first bout.

## Run a matchup or campaign

From the repository root:

```bash
godot --headless --path . --script tools/simulate.gd -- --left=hybrid --right=mage --level=4 --bouts=20 --seed=42
godot --headless --path . --script tools/simulate.gd -- --left=weapon --right=guard --level=16 --bouts=100 --seed=42 --death-match
godot --headless --path . --script tools/simulate.gd -- --campaign --left=weapon --bouts=75 --seed=42
```

The terminal outputs JSON after Godot’s startup banner. Matchup batches advance through consecutive seeds. They use regular rules by default, with a possible draw at the turn limit. A campaign reproduces the rival draws, shop choices, and fight rolls for the selected seed and player strategy. Each campaign row records whether it was a tournament match and the career’s arena after settlement.

| Preset | When to use it |
| --- | --- |
| `weapon`, `guard`, `mage`, `skirmish`, `charisma`, `hybrid`, `all_attack`, `brute` | Compare standard builds at the same level. |
| `keepaway_mage` | Exercise a mage who retreats when pressed. |
| `melee_hunter` | Exercise a weapon fighter who closes on casters and budgets stamina for follow-up swings. |
| `adaptive_hybrid` | Exercise a hybrid who switches tactics as the matchup changes. |
| `fast_melee` | Exercise the hunter tactics with more Stamina. At level 4 this trades two Vitality for two Stamina compared with Melee Hunter. |

A matchup with `--death-match` applies tournament combat rules to the chosen builds. Use a campaign or a live test career to face a particular arena champion.

## Reproduce a matchup

Save a scenario as JSON. Give either fighter a stat spread or a loadout, set the opening distance, or script some moves. After the scripted turns, the selected AI presets continue. List each prepared spell once in `spells`. An empty string leaves that slot empty. Script a cast with `cast_slot_0` for the first slot, `cast_slot_1` for the second, and so on. Set `draught` to `potion` or `armor_potion` to fill the potion pouch. Older scenarios with `spell` and `reserve_spell` still accept `cast` and `cast_reserve`.

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
  "left_loadout": {
    "weapon": "sword",
    "armor": {"chest": "leather_chest"},
    "spells": ["fireball", "magic_shield"]
  },
  "actions": ["cast_slot_0"]
}
```

```bash
godot --headless --path . --script tools/simulate.gd -- --level=1 --bouts=1 --seed=42 --scenario=/absolute/path/scenario.json
```

Keep the seed, level, loadout, and ruleset when reporting a matchup. See [Testing](testing.md#test-a-new-arena) for the arena playtest.

## Change the balance profile

Open **Playtest balance** from Settings or the simulator. **Apply and save profile** validates the draft and stores it at `user://balance.override.json`. To restore the bundled values, choose **Load bundled draft into editor**, then apply it.

The bundled profile combines [shared rules](../../content/balance.json) with arena and gear definitions. To test a complete override from the terminal, pass `--balance=/absolute/path/balance.json`. The simulator uses the bundled profile by default. Balance edits apply to new bouts. Existing bouts keep the rules, equipment, seed, and rewards recorded at entry.
