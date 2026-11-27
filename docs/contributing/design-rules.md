# Design rules

## Combat and progression

- Make range, stamina, and timing matter across melee, magic, defensive, charisma, and hybrid builds. Give players a way to respond to a champion’s strongest move through positioning, equipment, or a different action.
- Aim for roughly 60–70% wins for well-played builds in campaign playtests. Report regular bouts and tournament matches separately, by arena and build. Use the same seed range and comparable gear budgets when comparing changes. The target guides tuning and depends on the tactics used in the test. Report champion results separately and check that each champion qualifies for their intended gear.
- Regular bouts let a player earn gold, gain experience, and experiment. A defeat sends them back to town or to a new rival. A death match puts the career at stake. Players can close the game and continue an unfinished fight or tournament.
- Check shop costs and stat requirements against the gold and points a fighter can reasonably earn before each tournament.

## Magic and potions

Prepare two spell slots, plus one for every 10 points in Magic. Each slot holds a different spell and grants one cast per bout. The Magic shop groups spells under **Damage** and **Utility**. Either category can fill any slot.

| Arena | Damage spell | Utility spell |
| --- | --- | --- |
| Amber Ring | Fireball, a low-cost hit | Magic Shield, which absorbs part of the next hit before armor |
| Iron Court | Blue Hellfire, a short-range burst | Push, which doubles the gap and stops at the arena edge |
| Glass Crucible | Falling Ember, a long-range strike | Pull, which brings the rival to the adjacent space on their side |
| Suncrest Bastion | Pocket Anvil, a heavy hit at high stamina cost | Ember Etching, a ranked enchantment for the next few weapon hits |

Each arena adds one spell in each category. Buy a spell to prepare it in a slot. A prepared spell refreshes between bouts. Replacing or clearing it means buying it again to prepare it later. Show the replacement cost and which spell will be removed before the player confirms.

Apply +0.4 spell damage per Magic point to damage spells. Compare opening burst, utility casts, and win rates by build in regular bouts and tournaments. Preserve recorded spell rules in unfinished fights.

Let fighters bring one potion to each bout in its own pouch. A **Health Potion** restores 12 health plus half of Vitality, rounded down. An **Armor Potion** restores 30% of the armor the fighter started the bout with, rounded up. Cap both at the missing amount. The armor potion repairs worn gear, while Magic Shield adds protection before that gear takes damage.

## Art and equipment

- Give each arena its own backdrop and a readable floor and pit edge. Keep the action buttons, fighter silhouettes, and health crests legible against the scene.
- Give each weapon separate player and rival sprites. The renderer aligns their grip and striking points to the same combat pose. Both appearances use the weapon’s existing gameplay stats.
- Keep at least as many rival armor sets as player sets. Unlock rival looks by level and let enemies mix pieces across the available sets. The encounter seed determines the look. The combat loadout determines armor points.
- Keep each set’s placement data beside its art. The helmet follows the head, the chest follows the spine, and the shield follows the off hand. Pants and boots use rows mapped onto the legs. For articulated plate sleeves, fit the upper arm, bracer, and gauntlet to the shoulder, elbow, and wrist. Closed helmets cover the head and hair while leaving the neck visible.
- Keep source-pixel placement coordinates valid when changing a sprite. Check the weapon grip through a swing, the boots through a leap, and the shield during a block. See the [gear authoring guide](add-an-arena.md#add-gear).

## Music and sound

Keep town peaceful and shops cheerful. Give the face-off a more serious cue and each arena a distinct fight track that can sustain an intense bout. Victory should open with a celebratory fanfare. Defeat has its own quieter cue. Check the transitions into combat and back to the results screen with effects and music enabled.

See the [development plan](../plan.md) for proposed features and milestones.
