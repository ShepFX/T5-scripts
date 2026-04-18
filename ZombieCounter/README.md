# T5 ZM - Enemy Counter (Ported from T6)

This script provides a clean, real-time **HUD Overlay** for Black Ops 1 (T5) Zombies that tracks the remaining enemy count, currently spawned enemies, and Hellhound-specific counts during dog rounds.

## Features
* **Real-time Tracking:** Updates every 0.1 seconds to show exactly how many zombies are left in the round.
* **Dynamic HUD:** The interface expands automatically when a Dog Round begins to show the Hellhound counter.
* **Visual Cues:** * **Pulse Animation:** Text scales up briefly when a kill is confirmed.
    * **Critical Alert:** The "Zombies" text turns **orange/red** when 5 or fewer enemies remain.
* **Optimized for T5:** Specifically handles the lack of `get_round_enemy_array()` by enumerating axis AI directly.

---

## Installation

1. Locate your Black Ops 1 installation or your specific map folder.
2. Navigate to the `maps/` directory.
3. Save the script provided below as a `.gsc` file (e.g., `_zombie_counter.gsc`).
4. To call the script, ensure your main map GSC (e.g., `_zombiemode.gsc` or your custom map GSC) includes the following line in the `main()` function:
   `thread maps\_zombie_counter::init();`

