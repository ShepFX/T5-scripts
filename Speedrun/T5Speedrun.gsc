/**
 * Speedrun logger (T5 / Black Ops 1 Zombies).
 *
 * Appends one line to scriptdata/speedrun.txt (beside highrounds.txt) each
 * time a game reaches a milestone round or finishes the map's main easter egg,
 * with the game time it took. The website turns those lines into "fastest to
 * round N" and "fastest easter egg" boards per map and player count.
 *
 * File format - one line per event, appended, never rewritten:
 *     <runId>|<mapname>|<kind>|<target>|<ms>|<players>|<id:name,id:name>|<port>
 *
 *     runId    random id for this game, so the site can tell two games apart
 *     mapname  getDvar("mapname"), because one server can rotate several maps
 *     kind     "round" or "ee"
 *     target   the round reached, or the easter egg's token
 *     ms       milliseconds from the start of round 1 to the event
 *     players  squad size (see the roster rule below) - the board it goes on
 *
 * The clock starts at the first "start_of_round" notify, which is when round 1
 * actually begins after the intro, so every run on a map is measured the same
 * way. A game that did not begin at round 1 is not timed at all.
 *
 * Squad rules: everyone in the game before round 2 begins is the roster, and
 * the run is logged for that squad size with those names, even if some leave
 * before a milestone. A new player joining from round 2 onward ends timing for
 * that game - otherwise a solo run could land on the 2P board, or a three-man
 * carry to round 28 could be logged as a 1P time. A roster member who drops
 * and rejoins is still on the roster. Anyone who left during round 1 is
 * dropped from the round boards when round 2 begins, so a player who quits
 * early and is replaced does not turn a 4-man game into a 5P run.
 *
 * Easter eggs keep the round-1 leavers: round 1 can be stalled for as long as
 * a squad likes, so a helper could do every step but the last and leave before
 * round 2, putting a squad's egg on the solo board. An egg counts the round-1
 * leavers who stayed at least a minute, up to the 4 a server holds; a random
 * who joins and quits at once does not turn a solo egg into a 2P one.
 */

main() {
    level thread InitSpeedrun();
}

InitSpeedrun() {
    level.srFile = "scriptdata/speedrun.txt";
    level.srRunId = randomInt(1000000) + "-" + getTime();
    level.srMapToken = getDvar("mapname");

    level.srMilestones = [];
    level.srMilestones[level.srMilestones.size] = 10;
    level.srMilestones[level.srMilestones.size] = 20;
    level.srMilestones[level.srMilestones.size] = 30;
    level.srMilestones[level.srMilestones.size] = 40;
    level.srMilestones[level.srMilestones.size] = 50;
    level.srMilestones[level.srMilestones.size] = 70;
    level.srMilestones[level.srMilestones.size] = 100;

    SrWriteBootLineIfNew();

    level thread SrWaitForStart();
    level thread SrWatchRounds();

    // Main quest completion notifies, one per map. Only the current map's ever
    // fires; the rest sit idle until the game ends. Ascension has no notify of
    // its own, but flag_set() notifies the flag name and "weapons_combined" is
    // its final step.
    level thread SrWatchEE("weapons_combined",                  "casimir_mechanism");
    level thread SrWatchEE("coast_easter_egg_achieved",         "ensemble_cast");
    level thread SrWatchEE("temple_sidequest_achieved",         "time_travel_will_tell");
    level thread SrWatchEE("moon_sidequest_reveal_achieved",    "cryogenic_slumber_party");
    level thread SrWatchEE("moon_sidequest_big_bang_achieved",  "big_bang_theory");

    // Der Riese has no main quest; its easter egg is the Fly Trap - shoot the
    // fly trap with a Pack-a-Punched weapon, then find the three hidden items
    // (monkey bomb, Bowie knife bear, perk bear). Timed to the third item.
    level thread SrWatchFlytrap();

    // Song easter eggs, one per map, timed to the moment the song unlocks.
    level thread SrWatchSong();

    // Buyable ending on custom maps that have one (Stairway to Hell).
    level thread SrWatchBuyableEnding();
}

// Buyable endings on custom maps (T4 KFC, McDonalds and Stairway to Hell, BO1
// Stairway to Hell): a use trigger named "end_game" that deletes itself when the
// ending is bought, then ends the game. Timed to the purchase. Maps without one
// return at once.
SrWatchBuyableEnding() {
    trigs = getEntArray("end_game", "targetname");
    if (!isDefined(trigs) || trigs.size == 0)
        return;

    for (;;) {
        wait 0.05;
        for (i = 0; i < trigs.size; i++) {
            if (!isDefined(trigs[i])) {
                if (isDefined(level.srStart) && !isDefined(level.srInvalid))
                    SrLog("ee", "buyable_ending");
                return;
            }
        }
    }
}

SrWaitForStart() {
    level endon("end_game");

    level waittill("start_of_round");

    // A server that starts games above round 1 cannot be compared with one
    // that does not, so leave the run untimed.
    if (!isDefined(level.round_number) || level.round_number != 1)
        return;

    level.srRoster = [];
    level.srRosterLocked = false;
    level.srEggStay = 60000;   // ms a round-1 leaver must have stayed to count on an egg
    level.srStart = SrFirstControl();
}

// The run starts when the first player can actually play: their first move or
// button press after spawning, so time spent loading in or in the fade from
// black costs nothing. Standing still does not hold the clock for long: it
// starts 3 seconds after the first spawn at the latest, and never before
// round 1 began. The HUD clock reads level.srStart, so the two always match.
SrFirstControl() {
    level endon("end_game");

    spawned = 0;
    for (;;) {
        players = getplayers();
        for (i = 0; i < players.size; i++) {
            p = players[i];
            if (!isDefined(p) || !isDefined(p.sessionstate) || p.sessionstate != "playing")
                continue;
            if (spawned == 0)
                spawned = getTime();
            if (SrActing(p))
                return getTime();
        }
        if (spawned > 0 && getTime() - spawned >= 3000)
            return spawned + 3000;
        wait 0.05;
    }
}

// Moving along the ground (not just landing from the spawn drop) or pressing
// fire, aim, use, grenade or melee.
SrActing(p) {
    v = p getVelocity();
    if (v[0] * v[0] + v[1] * v[1] > 4)
        return true;
    return p attackButtonPressed() || p adsButtonPressed() || p useButtonPressed()
        || p fragButtonPressed() || p meleeButtonPressed();
}

SrWatchRounds() {
    level endon("end_game");

    lastRound = -1;
    sinceRoster = 0;

    for (;;) {
        wait 0.05;

        if (!isDefined(level.srStart) || isDefined(level.srInvalid))
            continue;

        // Once a second is plenty for the roster; scanning it 20 times a second
        // ran the name cleaner often enough to trip the engine's loop guard.
        // A round change scans immediately too, so the round-2 lock is exact.
        sinceRoster++;
        if (sinceRoster >= 20 || (isDefined(level.round_number) && level.round_number != lastRound)) {
            sinceRoster = 0;
            SrUpdateRoster();
        }

        if (!isDefined(level.round_number) || level.round_number == lastRound)
            continue;

        lastRound = level.round_number;

        if (lastRound >= 2 && !level.srRosterLocked) {
            SrPruneRoster();
            level.srRosterLocked = true;
        }

        if (SrIsMilestone(lastRound))
            SrLog("round", "" + lastRound);
    }
}

// Before round 2 anyone present joins the roster. After that a face that is
// not on it ends timing for this game.
SrUpdateRoster() {
    players = getplayers();
    for (i = 0; i < players.size; i++) {
        guid = "" + players[i] getGuid();
        slot = SrRosterIndex(guid);

        // A round-1 leaver back after round 2 counts as a new face, as before.
        if (slot < 0 || isDefined(level.srRoster[slot].gone)) {
            if (level.srRosterLocked) {
                level.srInvalid = true;
                iPrintLn("^3Speedrun timing ended - a new player joined after round 1");
                return;
            }
            slot = level.srRoster.size;
            level.srRoster[slot] = spawnStruct();
            level.srRoster[slot].guid = guid;
            level.srRoster[slot].since = getTime();
        }

        level.srRoster[slot].seen = getTime();

        // Keep the latest name and the IW4MAdmin id, which arrives a few
        // seconds after connecting, so a player who leaves is still credited.
        level.srRoster[slot].name = SrCachedName(players[i]);
        if (isDefined(players[i].persistentClientId))
            level.srRoster[slot].id = "" + players[i].persistentClientId;
        else if (!isDefined(level.srRoster[slot].id))
            level.srRoster[slot].id = guid;
    }
}

// Round 2 has begun: mark the roster members no longer in the game. They
// leave the round boards' squad but still count towards an easter egg.
SrPruneRoster() {
    players = getplayers();
    for (r = 0; r < level.srRoster.size; r++) {
        here = false;
        for (i = 0; i < players.size; i++) {
            if (isDefined(players[i]) && "" + players[i] getGuid() == level.srRoster[r].guid) {
                here = true;
                break;
            }
        }
        if (!here)
            level.srRoster[r].gone = true;
    }
}

// Who a line is credited to: the round boards skip the round-1 leavers, an
// easter egg keeps the ones who stayed long enough to have helped.
SrSquad(kind) {
    squad = [];
    for (i = 0; i < level.srRoster.size; i++) {
        m = level.srRoster[i];
        if (!isDefined(m.gone) || (kind == "ee" && m.seen - m.since >= level.srEggStay))
            squad[squad.size] = m;
    }
    return squad;
}

SrRosterIndex(guid) {
    for (i = 0; i < level.srRoster.size; i++) {
        if (level.srRoster[i].guid == guid)
            return i;
    }
    return -1;
}

SrWatchFlytrap() {
    level endon("end_game");

    if (getDvar("mapname") != "zombie_cod5_factory")
        return;

    // Each hidden item sets its own flag when found (hide_and_seek_target in
    // the map script), in any order; the egg is done when all three are set.
    for (;;) {
        wait 0.5;
        if (SrFlagSet("ee_exp_monkey") && SrFlagSet("ee_bowie_bear") && SrFlagSet("ee_perk_bear"))
            break;
    }

    if (isDefined(level.srStart) && !isDefined(level.srInvalid))
        SrLog("ee", "fly_trap");
}

SrWatchSong() {
    level endon("end_game");

    map = getDvar("mapname");

    // Ascension notifies the moment its song starts.
    if (map == "zombie_cosmodrome") {
        SrWatchEE("teddybear_music_started", "song_abracadavre");
        return;
    }

    token = SrSongToken(map);
    if (token == "")
        return;

    for (;;) {
        wait 0.5;
        if (SrSongUnlocked(map))
            break;
    }

    if (isDefined(level.srStart) && !isDefined(level.srInvalid))
        SrLog("ee", token);
}

SrSongToken(map) {
    if (map == "zombie_theater")        return "song_115";
    if (map == "zombie_pentagon")       return "song_wont_back_down";
    if (map == "zombie_coast")          return "song_not_ready_to_die";
    if (map == "zombie_temple")         return "song_pareidolia";
    if (map == "zombie_moon")           return "song_coming_home";
    if (map == "zombie_cod5_prototype") return "song_undone";
    if (map == "zombie_cod5_asylum")    return "song_lullaby_of_a_dead_man";
    if (map == "zombie_cod5_sumpf")     return "song_the_one";
    if (map == "zombie_cod5_factory")   return "song_beauty_of_annihilation";
    return "";
}

// What each map's song egg leaves behind when it unlocks.
SrSongUnlocked(map) {
    // Five: the third phone (the song itself starts 5 seconds later).
    if (map == "zombie_pentagon")
        return isDefined(level.phone_counter) && level.phone_counter >= 3;
    // Nacht: the third egg shot.
    if (map == "zombie_cod5_prototype")
        return isDefined(level.egg_damage_counter) && level.egg_damage_counter >= 3;
    // Verruckt and Shi No Numa keep no counter; on these two maps nothing but
    // the song egg ever sets music_override.
    if (map == "zombie_cod5_asylum" || map == "zombie_cod5_sumpf")
        return isDefined(level.music_override) && level.music_override;
    // Kino, Call of the Dead, Shangri-La, Moon, Der Riese: the third meteor.
    return isDefined(level.meteor_counter) && level.meteor_counter >= 3;
}

SrFlagSet(name) {
    return isDefined(level.flag) && isDefined(level.flag[name]) && level.flag[name];
}

SrWatchEE(notifyName, token) {
    level endon("end_game");

    level waittill(notifyName);

    if (isDefined(level.srStart) && !isDefined(level.srInvalid))
        SrLog("ee", token);
}

SrIsMilestone(rnd) {
    for (i = 0; i < level.srMilestones.size; i++) {
        if (level.srMilestones[i] == rnd)
            return true;
    }
    return false;
}

SrLog(kind, target) {
    elapsed = getTime() - level.srStart;
    SrUpdateRoster();
    if (isDefined(level.srInvalid))
        return;

    squad = SrSquad(kind);
    if (squad.size == 0)
        return;

    // A swap in round 1 can leave 5 names on an egg; it still goes on the 4P board.
    count = squad.size;
    if (count > 4)
        count = 4;

    line = level.srRunId + "|" + level.srMapToken + "|" + kind + "|" + target + "|"
         + elapsed + "|" + count + "|" + SrPlayerBlocks(squad) + "|"
         + getDvar("net_port");

    SrAppend(line);

    if (kind == "round")
        iPrintLn("^7Round " + target + " in ^2" + SrFormatTime(elapsed));
    else if (target == "buyable_ending")
        iPrintLn("^7Buyable ending in ^2" + SrFormatTime(elapsed));
    else
        iPrintLn("^7Easter egg done in ^2" + SrFormatTime(elapsed));
}

SrPlayerBlocks(squad) {
    blocks = "";
    for (i = 0; i < squad.size; i++) {
        block = squad[i].id + ":" + squad[i].name;

        if (blocks == "")
            blocks = block;
        else
            blocks = blocks + "," + block;
    }
    return blocks;
}

// Strip the characters the line format uses so a name can never break parsing.
// The character loop is the expensive part, so run it only when a player's
// name actually changes rather than on every scan.
//
// Black Ops zombies is built on single-player, where a player's name is
// .playername; .name is frequently not set at all, which is why runs used to
// be logged as "Player". Fall back to .name in case a build ever fills it, and
// keep the last good name rather than replacing it with a placeholder - the
// roster is rescanned every second, so a player who is still connecting is
// picked up on a later pass.
SrCachedName(player) {
    raw = undefined;
    if (isDefined(player.playername))
        raw = player.playername;
    else if (isDefined(player.name))
        raw = player.name;

    if (!isDefined(raw)) {
        if (isDefined(player.srNameClean))
            return player.srNameClean;
        return "Player";
    }

    if (isDefined(player.srNameRaw) && player.srNameRaw == raw && isDefined(player.srNameClean))
        return player.srNameClean;

    player.srNameRaw = raw;
    player.srNameClean = SrCleanName(raw);
    return player.srNameClean;
}

SrCleanName(name) {
    if (!isDefined(name))
        return "Player";

    out = "";
    for (i = 0; i < name.size; i++) {
        c = name[i];
        if (c != "|" && c != ":" && c != "," && c != ";")
            out += c;
    }
    if (out == "")
        return "Player";
    return out;
}

SrFormatTime(ms) {
    total = int(ms / 1000);
    h = int(total / 3600);
    m = int((total % 3600) / 60);
    s = total % 60;

    if (h > 0)
        return h + ":" + SrPad(m) + ":" + SrPad(s);
    return m + ":" + SrPad(s);
}

SrPad(n) {
    if (n < 10)
        return "0" + n;
    return "" + n;
}

// Writing a marker line the first time the file is created proves the append
// path works on this server before anyone reaches a milestone. The site
// ignores "boot" lines.
SrWriteBootLineIfNew() {
    file = fs_fopen(level.srFile, "read");
    if (isDefined(file) && file != 0) {
        fs_fclose(file);
        return;
    }
    SrAppend(level.srRunId + "|" + level.srMapToken + "|boot|0|0|0||" + getDvar("net_port"));
}

SrAppend(line) {
    file = fs_fopen(level.srFile, "append");
    if (isDefined(file) && file != 0) {
        fs_writeline(file, line);
        fs_fclose(file);
    }
}
