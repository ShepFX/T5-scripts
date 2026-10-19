/**
 * Game stats logger (T5 / Black Ops Zombies).
 *
 * Appends one line per player to scriptdata/gamestats.txt (beside speedrun.txt)
 * with what they did in the game: kills, headshots, downs, revives, bleed-outs
 * and points. A player's line is written when they leave, and for everyone
 * still in when the game ends, so every session is counted once.
 *
 * File format - one line per player session:
 *     <runId>|<mapname>|<round>|<reason>|<port>|<id>|<name>|<kills>|<headshots>|
 *     <downs>|<revives>|<bleedouts>|<points>|<joinRound>|<ms>|<box>|<perks>|<pap>|
 *     <powerups>|<powerupTypes>
 *
 *     runId      random id for this game (same idea as the speedrun log)
 *     round      the round when the line was written
 *     reason     "end" - still in when the game ended - or "left"
 *     id         IW4MAdmin client id (the GUID until IW4MAdmin has set it)
 *     bleedouts  times the player bled out and spectated until the next round
 *     points     total points earned this game, not what they had left
 *     joinRound  the round they joined in
 *     ms         time in the game
 *     box        mystery box spins they paid for (seen as chest_user being set)
 *     perks      perks they bought from a machine - free ones are not counted. Custom
 *                maps with their own perk scripts may not send "perk_bought", so
 *                perks gained (HasPerk going true) are counted too and used when
 *                the map sent nothing
 *     pap        weapons they took from Pack-a-Punch
 *     powerups   power-ups they picked up
 *     powerupTypes  the same by type, "nuke=2/full_ammo=1", empty when none
 *
 * A session with no kills that lasted under 30 seconds is not written, so
 * someone connecting and leaving straight away adds nothing.
 *
 * Same code as T4GameStats.gsc. A bled-out player turns spectator until the
 * next round, which is what is watched (the same way on every game), and game
 * over is the "end_game" notify or level.intermission, whichever comes first.
 */

main() {
    level thread InitGameStats();
}

InitGameStats() {
    level.gsFile = "scriptdata/gamestats.txt";
    level.gsRunId = randomInt(1000000) + "-" + getTime();
    level.gsMapToken = getDvar("mapname");
    level.gsSessions = [];

    level thread GsWatchPlayers();
    level thread GsWatchEnd();
    level thread GsWatchBoxes();
    level thread GsWatchDrops();
}

// New player entities get their own tracking thread. Polled rather than
// waiting on a connect notify, which not every map's scripts send.
GsWatchPlayers() {
    for (;;) {
        players = getplayers();
        for (i = 0; i < players.size; i++) {
            if (isDefined(players[i]) && !isDefined(players[i].gsSession))
                players[i] thread GsTrackPlayer();
        }
        wait 1;
    }
}

GsTrackPlayer() {
    session = spawnStruct();
    session.guid = "" + self getGuid();
    session.joinRound = GsRound();
    session.joinTime = getTime();
    session.bleedouts = 0;
    session.box = 0;
    session.perks = 0;
    session.perksGained = 0;
    session.freePerkAt = -100000;
    session.pap = 0;
    session.powerups = 0;
    session.powerupTypes = [];
    session.written = false;
    self.gsSession = session;
    level.gsSessions[level.gsSessions.size] = session;

    self thread GsWatchBleedouts(session);
    self thread GsWatchLeave(session);
    self thread GsWatchPerks(session);
    self thread GsWatchPerksHeld(session);
    self thread GsWatchPap(session);

    // Keep a copy of the numbers, so a player who drops is still logged with
    // what they had - their entity is gone by the time "disconnect" arrives.
    self endon("disconnect");
    for (;;) {
        GsSnapshotOf(self, session);
        wait 1;
    }
}

GsWatchBleedouts(session) {
    self endon("disconnect");

    last = "";
    for (;;) {
        state = "";
        if (isDefined(self.sessionstate))
            state = self.sessionstate;

        // Only "playing" to "spectator" counts: a player joining mid-round
        // starts as a spectator, and game over moves everyone to intermission.
        if (state == "spectator" && last == "playing" && !GsGameOver())
            session.bleedouts++;

        last = state;
        wait 0.25;
    }
}

// "perk_bought" is sent to the buyer only for a machine purchase, so free perks
// (the free perk power-up, the Quantum Bomb) are not counted.
GsWatchPerks(session) {
    self endon("disconnect");
    for (;;) {
        self waittill("perk_bought", perk);
        session.perks++;
    }
}

// Every perk a player gains, bought or not, minus the ones a free perk
// power-up they grabbed in the last 3 seconds gave them. A down takes perks
// away, so buying one back counts again, as it should. A spectator's HasPerk
// answers for the player they are watching, so only a player in the game
// counts; spectating clears what they held (bleeding out loses them anyway).
GsWatchPerksHeld(session) {
    self endon("disconnect");
    perks = [];
    perks[0] = "specialty_armorvest";
    perks[1] = "specialty_quickrevive";
    perks[2] = "specialty_fastreload";
    perks[3] = "specialty_rof";
    perks[4] = "specialty_longersprint";
    perks[5] = "specialty_flakjacket";
    perks[6] = "specialty_deadshot";
    perks[7] = "specialty_additionalprimaryweapon";
    held = [];
    for (i = 0; i < perks.size; i++)
        held[i] = false;
    for (;;) {
        wait 0.25;
        playing = isDefined(self.sessionstate) && self.sessionstate == "playing";
        for (i = 0; i < perks.size; i++) {
            has = false;
            if (playing)
                has = self HasPerk(perks[i]);
            if (has && !held[i] && getTime() - session.freePerkAt > 3000)
                session.perksGained++;
            held[i] = has;
        }
    }
}

GsWatchPap(session) {
    self endon("disconnect");
    for (;;) {
        self waittill("pap_taken");
        session.pap++;
    }
}

// A box spin: the chest's chest_user is set to whoever paid and cleared when
// the box closes, so each change from unset to set is one spin. Fire sale
// boxes are in level.chests too and count the same way.
GsWatchBoxes() {
    for (;;) {
        wait 0.1;
        if (!isDefined(level.chests))
            continue;
        for (i = 0; i < level.chests.size; i++) {
            chest = level.chests[i];
            if (!isDefined(chest))
                continue;
            if (!isDefined(chest.chest_user)) {
                chest.gsSpinSeen = undefined;
                continue;
            }
            if (isDefined(chest.gsSpinSeen))
                continue;
            chest.gsSpinSeen = true;
            if (isDefined(chest.chest_user.gsSession))
                chest.chest_user.gsSession.box++;
        }
    }
}

// Every dropped power-up is watched until someone grabs it or it goes. The
// game names the grabber (power_up_grab_player) before it hides it.
GsWatchDrops() {
    for (;;) {
        level waittill("powerup_dropped", powerup);
        if (isDefined(powerup))
            powerup thread GsWatchDrop();
    }
}

GsWatchDrop() {
    while (isDefined(self) && !isDefined(self.power_up_grab_player))
        wait 0.05;
    if (!isDefined(self))
        return;

    player = self.power_up_grab_player;
    if (!isDefined(player) || !isDefined(player.gsSession))
        return;
    name = "other";
    if (isDefined(self.powerup_name))
        name = GsCleanName(self.powerup_name);

    session = player.gsSession;
    session.powerups++;
    if (name == "free_perk")
        session.freePerkAt = getTime();
    if (!isDefined(session.powerupTypes[name]))
        session.powerupTypes[name] = 0;
    session.powerupTypes[name] = session.powerupTypes[name] + 1;
}

// The machine's "perk_bought" count where the map sends it, else perks gained.
GsPerks(session) {
    if (session.perks > 0)
        return session.perks;
    return session.perksGained;
}

GsPowerupTypes(session) {
    out = "";
    names = getArrayKeys(session.powerupTypes);
    for (i = 0; i < names.size; i++) {
        if (out != "")
            out += "/";
        out += names[i] + "=" + session.powerupTypes[names[i]];
    }
    return out;
}

GsWatchLeave(session) {
    self waittill("disconnect");
    if (!session.written && !GsGameOver())
        GsWrite(session, "left");
}

GsWatchEnd() {
    level thread GsEndNotify();
    while (!GsGameOver())
        wait 0.25;

    players = getplayers();
    for (i = 0; i < players.size; i++) {
        if (isDefined(players[i]) && isDefined(players[i].gsSession))
            GsSnapshotOf(players[i], players[i].gsSession);
    }
    for (i = 0; i < level.gsSessions.size; i++) {
        if (!level.gsSessions[i].written && !isDefined(level.gsSessions[i].left))
            GsWrite(level.gsSessions[i], "end");
    }
}

// Every Black Ops map notifies "end_game"; level.intermission is the backup.
GsEndNotify() {
    level waittill("end_game");
    level.gsEnded = true;
}

GsGameOver() {
    if (isDefined(level.gsEnded))
        return true;
    return isDefined(level.intermission) && level.intermission;
}

GsSnapshotOf(player, session) {
    name = undefined;
    if (isDefined(player.playername))
        name = player.playername;
    else if (isDefined(player.name))
        name = player.name;
    if (isDefined(name))
        session.name = GsCleanName(name);

    if (isDefined(player.persistentClientId))
        session.id = "" + player.persistentClientId;
    else if (!isDefined(session.id))
        session.id = session.guid;

    session.kills = GsNum(player.kills);
    session.headshots = GsNum(player.headshots);
    session.downs = GsNum(player.downs);
    session.revives = GsNum(player.revives);
    if (isDefined(player.score_total))
        session.points = GsNum(player.score_total);
    else
        session.points = GsNum(player.score);
    session.lastSeen = getTime();
}

GsWrite(session, reason) {
    session.written = true;
    if (reason == "left")
        session.left = true;

    if (!isDefined(session.lastSeen) || !isDefined(session.name))
        return;
    ms = session.lastSeen - session.joinTime;
    if (ms < 30000 && session.kills == 0)
        return;

    line = level.gsRunId + "|" + level.gsMapToken + "|" + GsRound() + "|" + reason + "|"
         + getDvar("net_port") + "|" + session.id + "|" + session.name + "|"
         + session.kills + "|" + session.headshots + "|" + session.downs + "|"
         + session.revives + "|" + session.bleedouts + "|" + session.points + "|"
         + session.joinRound + "|" + ms + "|" + session.box + "|" + GsPerks(session) + "|"
         + session.pap + "|" + session.powerups + "|" + GsPowerupTypes(session);

    file = fs_fopen(level.gsFile, "append");
    if (isDefined(file) && file != 0) {
        fs_writeline(file, line);
        fs_fclose(file);
    }
}

GsRound() {
    if (isDefined(level.round_number))
        return level.round_number;
    return 0;
}

GsNum(value) {
    if (isDefined(value))
        return int(value);
    return 0;
}

// Strip the characters the line format uses so a name can never break parsing.
// Bounded as well as tested - see SrCleanName in T5Speedrun.gsc.
GsCleanName(name) {
    out = "";
    for (i = 0; i < 64 && i < name.size; i++) {
        c = name[i];
        if (!isDefined(c))
            break;
        if (c != "|" && c != ":" && c != "," && c != ";")
            out += c;
    }
    if (out == "")
        return "Player";
    return out;
}
