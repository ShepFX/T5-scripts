# First Room Challenge for T5 Zombies

Black Ops 1 (T5) counterpart of the T6 First Room Challenge. Players stay in the
starting room: wall weapons, the box and any perk machine in that room still
work, but nothing that opens the map up can be bought.

## What it locks

- `zombie_door` and `zombie_debris` buys on every map
- Five: both elevator buy panels and their call boxes
- Ascension: the lunar lander call boxes
- The power switch, as a safety net

BO1 has no door-buy hook like BO2's `level.custom_door_buy_check`, so the script
switches the buy triggers off and re-applies once a second, because the game
re-enables some of them itself (Five turns elevator buys back on whenever a car
arrives).

## Installation

Copy `T5FirstRoomChallenge.gsc` into `raw/scripts/sp/` on the server. Plutonium
runs `main()` automatically at map load; no include or call is needed.

Pair it with `T5RoundSaverNew.gsc` and the server keeps a separate record per
map and player count, so a first-room-only server can rotate Kino, Five,
Ascension, Shangri-La and the four WaW maps and track each one independently.
