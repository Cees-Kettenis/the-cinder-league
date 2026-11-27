# Testing

Run these commands from the repository root with the Standard [Godot editor](../install.md#run-from-source) on your PATH.

## Run the checks

```bash
godot --headless --path . --import
godot --headless --path . --script tools/check_content.gd
```

The content check validates the assembled balance and checks arena backdrops, music, gear texture references, and weapon grip points. Run it after adding content or changing resource paths.

The playtest suite exercises campaign saves, combat, and UI. It writes test careers and settings to Godot’s user data directory. On Linux, run it with a fresh temporary directory.

```bash
test_data=$(mktemp -d)
XDG_DATA_HOME="$test_data" godot --headless --path . --script tests/playtest.gd
```

For the same isolated checks on GitHub, use the [Desktop release workflow](desktop-builds.md#build-on-github). For manual play on any platform, use a throwaway save slot.

## Practice tournament rounds

Tournament practice is automatic when you run the game from the Godot editor or a debug export. After a defeat, **Next Match** scouts the same tournament round. Your gladiator survives and keeps their gold. Only a win advances the bracket. Release exports and campaign simulations use the standard tournament rules.

## Test a new arena

1. **Enter from the previous league.** Win the preceding tournament, or open a test save that finished it. Check the new arena unlocks, the correct point allocation appears, and a regular rival can be scouted at the opening level.
2. **Try the shop and regular bouts.** Check gear requirements, prices, and that purchases equip the expected item. Play a win and a loss. Verify the rewards, the loss fee, and that another rival can be scouted. At the arena cap, check the XP and gold rules before entering the tournament.
3. **Play the tournament.** Confirm the round order, champion, and result. Close and resume once during a bout and once between rounds. Check both the unlock after a win and the fallen-career path after a defeat in separate test saves.
4. **Test several styles.** Use melee, magic, and hybrid builds at the new cap, and include defensive or charisma builds when those tactics are affected. Record the seeds and loadouts. Use the [simulator](simulator.md) for repeatable batches and fight the champion in the campaign to check its specific tactics and gear. A standalone matchup uses preset fighters, so it cannot by itself establish the champion’s difficulty.
5. **Check the presentation.** Play at a compact and a larger window size. Verify the backdrop crop, camera, movement, weapon and armor alignment, audio transitions, and the results screen. Smoke-test a [desktop export](desktop-builds.md) when introducing or moving assets.

## Test shared code changes

| Changed area | Check |
| --- | --- |
| Turn rules or AI | Replay the same recorded actions and verify legal moves, stamina, and outcomes. Compare before and after with fixed seeds to explain balance changes. |
| Save data or catalog | Resume an unfinished bout from the current save version and check its turns, gear, and rewards. If the save version changes, verify that an earlier slot can be replaced. Inspect the new content in a packaged build when changing discovery or resource paths. |
| Fight screen, HUD, art, or audio | Play a full bout in the game. Confirm that actions unlock after the response, meters update on impact, and the result appears once. Check both window modes if layout changed. |
| Pages or screenshots | Preview the Markdown, follow the links, and check that the screenshots remain legible at README width. Keep screenshots under `docs/assets/`. |

When a check fails, include the relevant save state or [scenario](simulator.md#reproduce-a-matchup), seed, arena, and Godot version in the report.
