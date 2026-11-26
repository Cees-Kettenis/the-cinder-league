# Contributing

Start with the [architecture](docs/contributing/architecture.md) to find the relevant code, the [design rules](docs/contributing/design-rules.md) for gameplay and art decisions, and the [testing guide](docs/contributing/testing.md) for the checks to run. If you’re adding a league, follow [Add an arena](docs/contributing/add-an-arena.md).

## Set up a checkout

Follow [Run from source](docs/install.md#run-from-source) to install the Standard Godot editor. Fork the repository, clone your fork, and create a branch for your change.

```bash
git clone https://github.com/YOUR_USERNAME/the-cinder-league.git
cd the-cinder-league
git switch -c my-change
godot --headless --path . --import
```

Open `project.godot` in Godot and press **F5**. Use a throwaway save when trying changes to progression or tournaments.

## Make and check a change

Keep each arena’s definition, backdrops, and music in its own folder. Put shared combat behavior in the existing duel engine so the game and simulator use the same rules. Explain save compatibility, seed behavior, or coordinate assumptions in code comments when a change depends on them.

Run the [content and playtest checks](docs/contributing/testing.md#run-the-checks) for gameplay or asset changes. For a new arena, also follow the [arena playtest](docs/contributing/testing.md#test-a-new-arena). Update the relevant guide when a control, rule, or authoring workflow changes. Keep documentation screenshots in `docs/assets/`.

## Submit a change

Open a pull request against `main`. Describe what a player or contributor will see, which checks you ran, and anything you couldn’t verify. For a balance change, include the relevant level, loadout, ruleset, and seeds. For a visual change, include a screenshot from the game.

For a bug report, include the game version, platform, steps to reproduce, and what you expected to happen. A combat seed or a small [simulator scenario](docs/contributing/simulator.md#reproduce-a-matchup) helps reproduce fight results.
