# AFK System — Plutonium T5ZM (Black Ops 1 Zombies)

A server-side AFK system for **Plutonium Black Ops 1 Zombies** written in GSC. Lets players go AFK mid-game without holding the lobby hostage — the round freezes while everyone is AFK and resumes automatically when someone comes back.

---

## Features

- **`.afk` chat command** — type `.afk` in global or team chat to toggle AFK mode
- **Round freeze** — zombie spawning pauses when all active players are AFK, and resumes when someone returns
- **Position lock** — player is teleported to spawn and locked in place; jump-spam and movement are nullified
- **Godmode + AI ignore** — zombies will not target or damage the AFK player
- **Score lock** — score is preserved for the duration of AFK
- **Invulnerability grace period** — 30 seconds of invulnerability after returning to give you time to get your bearings
- **Activation delay** — 60-second countdown before AFK activates, cancellable by typing `.afk` again or taking damage
- **HUD overlay** — AFK label and live countdown timer displayed on screen
- **Round gate** — only available from round 20 onwards
- **Cooldown** — 2-hour cooldown between uses per player

---

## Installation

1. Navigate to your Plutonium T5 storage folder:
   ```
   %localappdata%\Plutonium\storage\t5\raw\scripts\sp
   ```
   > If the `raw\scripts\sp` folders don't exist, create them.

2. Drop `_zm_afk_t5zm.gsc` into that folder.

3. Start the game — the script loads automatically. No restart needed between map changes.

---

## Usage

| Action | Command |
|---|---|
| Toggle AFK on | Type `.afk` in chat |
| Cancel activation countdown | Type `.afk` again during the 60s delay |
| Deactivate AFK | Type `.afk` again while AFK |

AFK will also **auto-deactivate** when the 15-minute timer expires.

---

## Configuration

All settings are at the top of `init()` and are easy to adjust:

```gsc
level.afk_system.min_round           = 20;       // Minimum round to use AFK
level.afk_system.cooldown_ms         = 7200000;  // Cooldown between uses (ms) — default 2 hours
level.afk_system.duration_s          = 900;      // Max AFK duration in seconds — default 15 min
level.afk_system.activation_delay_s  = 60;       // Countdown before AFK activates — default 60s
```

---

## Debug HUD

A per-player debug overlay is included but disabled by default. To enable it, open the script and uncomment this line in `init()`:

```gsc
// level thread debug_hud_monitor();
```

This displays a live readout of each player's AFK state, cooldown, round number, zombie counts, and freeze status in the top-left corner of the screen.

---

## Requirements

- [Plutonium](https://plutonium.pw) — Black Ops 1 (T5ZM)
- No other dependencies — the script is fully self-contained

---

## Compatibility

Tested on Plutonium T5ZM. This script is **not compatible** with T4 (World at War) or T6 (Black Ops 2) without modification.

> If you're looking for the original T4 version this was ported from, see `_zm_afk_t4.gsc`.

---

## How Round Freeze Works

When the last active (non-AFK) player goes AFK:
- Zombie spawning is halted by setting `zombie_max_ai` to `0`
- The zombie queue counter is preserved so the round doesn't skip
- A "Round paused" message broadcasts to all players

When any player returns from AFK:
- `zombie_max_ai` is restored to its previous value
- The zombie queue is recalculated accounting for any zombies that may have died during the freeze (traps, environmental damage)
- A "Round resumed" message broadcasts to all players
