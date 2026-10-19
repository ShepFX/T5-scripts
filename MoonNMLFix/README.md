# Moon No Man's Land round fix

Fixes a stock Black Ops 1 bug on Moon. Teleporting to No Man's Land between
rounds saves the next round's zombie count without the round and player
multipliers, so from round 6 on it is a flat 24. When the players come back, the
round is forced to those 24 zombies, which makes high rounds trivially short.

After a between-rounds teleport the script clears the saved count, so the round
after returning keeps its full zombie count. Teleporting mid-round is unchanged:
the zombies that were actually left are restored as before.

## Installation

Copy `shep_moon_nml_fix.gsc` to `storage/t5/raw/scripts/sp/`. It does nothing on
other maps.
