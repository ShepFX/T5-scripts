# Run timer

Shows how long the current game has been running — the figure the speedrun
boards rank runs on — and, after each round, that round's split.

The panel carries the run clock and nothing else. When a round ends, a split
row drops in underneath showing the round number and how long it took, stays
for six seconds, then retracts again so only the run clock is left.

```
┌──────────────┐
│ RUN          │
│ TOTAL  14:07 │
├──────────────┤   ← appears for 6s after each round, then hides
│ R12     1:48 │
└──────────────┘
```

## Where it sits

Directly below the enemy counter, and it moves down 14 further while the
counter is grown for its dog row. On a server with no counter it takes the top
slot instead. It works this out by reading the counter's own state, so the
counter never has to know this script exists.

## Rounds

The round is polled once a second from `level.round_number` rather than hooked
to a round-start notify: notify names vary between stock and custom maps, but
`level.round_number` is present everywhere. The run clock starts at the first
round and is never reset, so it keeps counting across every round of the game.

The clock text is written server-side once a second, and only when it has
actually changed and the panel is on screen. BO1 has no confirmed client-side
counting HUD call, so this is the portable way to do it.

## Usage

- **`.timer`** in chat hides or shows the panel. It is on by default.

## Installation

Copy `T5RunTimer.gsc` into `raw/scripts/sp/`. Plutonium runs it at map load —
it defines both `main()` and `init()` (Plutonium calls both) and guards against
being started twice.
