# Speedrun logger for T5 Zombies

Black Ops 1 counterpart of the T6 speedrun logger. Logs how long a game took to
reach milestone rounds (10, 20, 30, 40, 50, 70, 100) and to complete the map's
main easter egg, so stats.cukservers.net can show "fastest to round N" and
"fastest easter egg" boards per map and squad size.

## How it works

- The clock starts at the first `start_of_round` notify (round 1 beginning after
  the intro). A game that did not start at round 1 is not timed.
- Everyone present before round 2 is the roster; anyone joining from round 2
  onward ends timing for the game.
- Easter egg completion is detected from the notify the map's own quest script
  fires on the final step. Ascension has no dedicated notify, so its final step
  (`weapons_combined`) is used instead.

| Map | Notify | Board |
|---|---|---|
| Ascension | `weapons_combined` | Casimir Mechanism |
| Call of the Dead | `coast_easter_egg_achieved` | Ensemble Cast |
| Shangri-La | `temple_sidequest_achieved` | Time Travel Will Tell |
| Moon | `moon_sidequest_reveal_achieved` | Cryogenic Slumber Party |
| Moon | `moon_sidequest_big_bang_achieved` | Big Bang Theory |

Kino, Five, Nuketown and the World at War maps have no main quest, so they get
round-time boards only.

Each event appends one line to `scriptdata/speedrun.txt` beside
`highrounds.txt`:

```
<runId>|<mapname>|<kind>|<target>|<ms>|<players>|<id:name,id:name>|<port>
```

## Installation

Copy `T5Speedrun.gsc` into `raw/scripts/sp/` on the server alongside
`T5RoundSaverNew.gsc`. Plutonium runs it automatically at map load.

## Known issue

`SrCleanName` is killed by the engine's infinite-loop guard on some player
connects (see `potential infinite loop in script` in the console). It is
called from the roster update, so a run may occasionally be logged with an
unresolved name.
