# Zombie Counter HUD (T5 Rework)

This GSC script provides a sleek, real-time **Enemy Tracker** for Black Ops 1 (T5) Zombies. Ported and optimized from T6, it allows players to track the remaining zombie count, active hellhounds, and the number of enemies currently spawned on the map.

---

### Features

* **Real-Time Tracking:** Monitors remaining zombies and dogs, including those yet to spawn.
* **Dynamic HUD:** The interface automatically expands to show a "DOGS" row during hellhound rounds.
* **Low-Health Alerts:** The zombie counter changes color (to a reddish-orange) when 5 or fewer enemies remain.
* **Persistent Preferences:** Player toggle settings (on/off) are saved to `scriptdata/zc_prefs.txt` and persist across matches.
* **Polished Animations:** Features fade transitions and a "pulse" effect when numbers update for a professional feel.

---

### Installation

1.  **Locate your scripts folder:** Navigate to your T5 ZM installation directory.
2.  **Placement:** Drop `_zombie_counter_hud_t5_rework.gsc` into the `maps/` directory alongside your other `_zombiemode` scripts.
3.  **Integration:** Ensure your `_zombiemode.gsc` (or equivalent entry point) calls `init()` to start the monitor threads.

---

### Usage

Players can toggle the HUD individually while in-game using a simple chat command:

* **Toggle Command:** Type `.counter` in the game chat.
* **Visual Feedback:** The HUD will fade in or out based on your current preference.

---

### Technical Overview

* **HUD Elements:** Built using `newclienthudelem` to ensure individual player customization.
* **Enemy Enumeration:** Specifically designed for T5's AI system, using `GetAiSpeciesArray` to accurately count "axis" entities.
* **Performance:** Optimized with a 0.1-second update tick to maintain high accuracy without impacting server performance.

---

