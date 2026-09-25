# CUKServers Black Ops (T5) zombie scripts

The GSC the CUKServers Black Ops (T5) servers actually run. Every file here was taken
from a live server, so what is in this repo is what is running.

Scripts install into `runtime/plutonium/storage/t5/raw/scripts/sp/` unless a folder's README says
otherwise; Plutonium runs them at map load.

## What is deployed where

Several files are named differently on the servers than in this repo. The
deployed name is the one that matters — that is the filename to copy to.

| In this repo | Deployed as | Running on |
| --- | --- | --- |
| `AFK/_zm_afk_t5zm.gsc` | `_zm_afk_t5zm.gsc` | 14 zombie servers |
| `AntiExploit/_zm_anti_exploit_t5.gsc` | `_zm_anti_exploit_t5.gsc` | 14 zombie servers |
| `FirstRoom/T5FirstRoomChallenge.gsc` | `T5FirstRoomChallenge.gsc` | t5sp-first |
| `GameStats/T5GameStats.gsc` | `T5GameStats.gsc` | 13 zombie servers |
| `LiveRound/T5LiveRound.gsc` | `T5LiveRound.gsc` | 14 zombie servers |
| `Roundlock.gsc` | `T5PostRoundLock.gsc` | 14 zombie servers |
| `RoundRecord/RoundRecordSaver.gsc` | `T5RoundSaverNew.gsc` | 14 zombie servers |
| `RunTimer/T5RunTimer.gsc` | `T5RunTimer.gsc` | 16 servers |
| `Speedrun/T5Speedrun.gsc` | `T5Speedrun.gsc` | 14 zombie servers |
| `ZombieCounter/_Zombie_counter.gsc` | `T5_Zombie_counter.gsc` | 14 zombie servers |

Last verified against the live servers on 2026-09-25.
