# Design rules

## Combat and progression

- Make range, stamina, and timing matter across melee, magic, defensive, charisma, and hybrid builds. Give players a way to respond to a champion’s strongest move through positioning, equipment, or a different action.
- Aim for roughly 60–70% wins for well-played builds in campaign playtests. Report regular bouts and tournament matches separately, by arena and build. Use the same seed range and comparable gear budgets when comparing changes. The target guides tuning and depends on the tactics used in the test.
- Regular bouts let a player earn gold, gain experience, and experiment. A defeat sends them back to town or to a new rival. A death match puts the career at stake. Players can close the game and continue an unfinished fight or tournament.
- Check shop costs and stat requirements against the gold and points a fighter can reasonably earn before each tournament.

## Art and equipment

- Give each arena its own backdrop and a readable floor and pit edge. Keep the action buttons, fighter silhouettes, and health crests legible against the scene.
- Give each weapon separate player and rival sprites. The renderer aligns their grip and striking points to the same combat pose. Both appearances use the weapon’s existing gameplay stats.
- Keep at least as many rival armor sets as player sets. Unlock rival looks by level and let enemies mix pieces across the available sets. The encounter seed determines the look. The combat loadout determines armor points.
- Keep each set’s placement data beside its art. The helmet follows the head, the chest follows the spine, and the shield follows the off hand. Pants and boots use rows mapped onto the legs. For articulated plate sleeves, fit the upper arm, bracer, and gauntlet to the shoulder, elbow, and wrist. Closed helmets cover the head and hair while leaving the neck visible.
- Keep source-pixel placement coordinates valid when changing a sprite. Check the weapon grip through a swing, the boots through a leap, and the shield during a block. See the [gear authoring guide](add-an-arena.md#add-gear).

## Music and sound

Keep town peaceful and shops cheerful. Give the face-off a more serious cue and each arena a distinct fight track that can sustain an intense bout. Victory should open with a celebratory fanfare. Defeat has its own quieter cue. Check the transitions into combat and back to the results screen with effects and music enabled.

See the [development plan](../plan.md) for proposed features and milestones.
