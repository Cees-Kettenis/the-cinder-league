# Add an arena

Start with a working arena such as [Suncrest Bastion](../../content/arenas/suncrest-bastion/arena.json). Create a new folder in [content/arenas](../../content/arenas/) with a short, lowercase, hyphenated name.

```text
content/arenas/your-arena/
  arena.json
  backdrop.webp
  backdrop-compact.webp
  fight.ogg
```

## Define the league

1. Set `order` to the next zero-based index. Suncrest Bastion is order 3, so the next arena is order 4. Existing saves depend on the earlier indexes.
2. Set the arena’s name, description, level cap, gold, XP, and rival gear unlock level in `balance`. The opening level is one above the preceding cap. Supply one increasing value in `xp_levels` for every level in the new arena. For a level 17–20 league, that means four values, each above the existing level 16 threshold.
3. Add regular `opponents` and ordered `tournament` rounds. Include a regular rival available at the opening level. Each opponent has a `name` and a `style`. Use `point_multiplier` for a deliberate change in difficulty and `tactics` when a build should fight with a different strategy. Mark the champion with `boss: true`. Champions can specify a complete `stats` allocation.
4. Add the two backdrops and the fight track with the filenames above. Use the same composition and crop for both backdrops. The compact version is up to 1280 pixels wide and is used when the window’s longest edge is 1366 pixels or less. Larger windows use the full-size artwork, scaled to fit.

The content catalog discovers the folder by convention. The arena file holds its own enemies and progression values, and shared move rules live in [the balance file](../../content/balance.json).

For background movement, add an optional `ambience.gd` beside the backdrops. The [Glass Crucible layout](../../content/arenas/glass-crucible/ambience.gd) shows how to place cloth, flames, lamp glows, and spectator routes using coordinates measured on the painting at 1,000 pixels wide. Keep cloth rectangles inside the fabric and set walkway endpoints along the top of a railing. Check the anchors in the arena lobby and with the fight camera panned to each side.

For curved fabric, trace the top and bottom of each drape using the `DRAPES` columns in the [Suncrest Bastion layout](../../content/arenas/suncrest-bastion/ambience.gd).

## Add gear

- In [content/gear/armor](../../content/gear/armor/), put each set’s textures beside its `armor.gd`. For player gear, start the item ID with the set folder name and an underscore. The [Court set](../../content/gear/armor/court/armor.gd) shows both shop stats and fitted armor layers. For a rival look, set `RIVAL_LEVEL` and `RIVAL_ORDER`. Keep the order of existing sets stable for seeded looks.
- In [content/gear/weapons](../../content/gear/weapons/), use a hyphenated folder and the corresponding underscore item ID. Include `weapon.gd`, `player.webp`, and `rival.webp`. Specify the grip and striking point in source-sprite pixels. The [Glass sabre](../../content/gear/weapons/glass-sabre/weapon.gd) also shows how to set a different resting pose.
- Assign new shop items a level and stat requirement that match the intended league. Check that a fighter can buy and equip useful upgrades on reaching the cap. See the [design rules](design-rules.md) for art, combat, and audio decisions.

Run the [content checks and arena playtest](testing.md#test-a-new-arena) before submitting the change. Add any guide screenshots under `docs/assets/`.
