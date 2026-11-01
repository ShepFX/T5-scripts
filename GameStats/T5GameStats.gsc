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
 * Box spins and downs also go one line each to scriptdata/gameevents.txt (31 Oct 2026):
 *     <runId>|<mapname>|<round>|<port>|<id>|<name>|box|<weapon or "teddy">
 *     <runId>|<mapname>|<round>|<port>|<id>|<name>|down|<x>,<y>,<z>
 * A box line is the weapon the spin offered, taken or not; "teddy" moved the box.
 * Once per game: ...|0|-|map|<x0>,<y0>,<x1>,<y1>,<northYaw> - the minimap corners (only where a map has them).
 * Floor plans for the heatmaps (1 Nov 2026):
 *     ...|0|-|grid|<cx>,<cy>,<cz>,<n>;...   time spent per 64x64x128-unit cell, every 5 minutes
 *     ...|0|-|mark|<type>:<name>:<x>,<y>,<z>   perks, PaP, box spots and wall buys, once per game
 * Cells are offset by 65536 so they are never negative: cx = int((x + 65536) / 64).
 * Live radar (1 Nov 2026), BO1's stock maps only: every second, one line per player into the
 * game log in the format IW4MAdmin's Live Radar reads, the team field holding up, down or dead:
 *     LiveRadar;<guid hex>;<origin>;<angles>;<state>;0;0;0;none;<health>;<alive>;0
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
    level.gsEventFile = "scriptdata/gameevents.txt";
    level.gsRunId = randomInt(1000000) + "-" + getTime();
    level.gsMapToken = getDvar("mapname");
    level.gsSessions = [];

    level thread GsWatchPlayers();
    level thread GsWatchEnd();
    level thread GsWatchBoxes();
    level thread GsWatchBoxSpins();
    level thread GsLogMinimap();
    level thread GsFloorSample();
    level thread GsFloorFlush();
    level thread GsLogMarks();
    level thread GsRadar();
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
    self thread GsWatchDowns();

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

// Each spin ends with "randomization_done" on the chest's chest_origin, with the
// offered weapon in weapon_string; a teddy bear leaves it undefined
// (_zombiemode_weapons.gsc). chest_user is the player who paid.
GsWatchBoxSpins() {
    while (!isDefined(level.chests))
        wait 1;
    for (i = 0; i < level.chests.size; i++) {
        if (isDefined(level.chests[i]) && isDefined(level.chests[i].chest_origin))
            level.chests[i] thread GsWatchChest();
    }
}

GsWatchChest() {
    for (;;) {
        self.chest_origin waittill("randomization_done");
        user = self.chest_user;
        if (!isDefined(user) || !isPlayer(user))
            continue;
        weapon = "teddy";
        if (isDefined(self.chest_origin.weapon_string))
            weapon = self.chest_origin.weapon_string;
        GsEvent(user, "box", weapon);
    }
}

// player.downs counts every down; where the player was when it went up.
GsWatchDowns() {
    self endon("disconnect");
    last = GsNum(self.downs);
    for (;;) {
        wait 0.2;
        now = GsNum(self.downs);
        if (now > last)
            GsEvent(self, "down", int(self.origin[0]) + "," + int(self.origin[1]) + "," + int(self.origin[2]));
        last = now;
    }
}

// The two minimap_corner entities the compass is drawn between (_compass.gsc).
GsLogMinimap() {
    wait 5;
    corners = getEntArray("minimap_corner", "targetname");
    if (corners.size != 2)
        return;
    data = int(corners[0].origin[0]) + "," + int(corners[0].origin[1]) + ","
         + int(corners[1].origin[0]) + "," + int(corners[1].origin[1]) + "," + int(getNorthYaw());
    line = level.gsRunId + "|" + level.gsMapToken + "|" + GsRound() + "|" + getDvar("net_port") + "|0|-|map|" + data;
    file = fs_fopen(level.gsEventFile, "append");
    if (isDefined(file) && file != 0) {
        fs_writeline(file, line);
        fs_fclose(file);
    }
}

// Every 2 s, one count for the cell each playing player stands in.
GsFloorSample() {
    level.gsFloor = [];
    for (;;) {
        wait 2;
        if (GsGameOver())
            return;
        players = getplayers();
        for (i = 0; i < players.size; i++) {
            p = players[i];
            if (!isDefined(p) || !isDefined(p.sessionstate) || p.sessionstate != "playing")
                continue;
            key = int((p.origin[0] + 65536) / 64) + "," + int((p.origin[1] + 65536) / 64) + "," + int((p.origin[2] + 65536) / 128);
            if (!isDefined(level.gsFloor[key]))
                level.gsFloor[key] = 0;
            level.gsFloor[key] = level.gsFloor[key] + 1;
        }
    }
}

// Live radar lines, stock maps only. The guid goes out in hex because the radar plugin parses it that way.
GsRadar() {
    map = getDvar("mapname");
    stock = [];
    stock[0] = "zombie_theater"; stock[1] = "zombie_pentagon"; stock[2] = "zombie_cosmodrome"; stock[3] = "zombie_coast";
    stock[4] = "zombie_temple"; stock[5] = "zombie_moon"; stock[6] = "zombie_cod5_prototype"; stock[7] = "zombie_cod5_asylum";
    stock[8] = "zombie_cod5_sumpf"; stock[9] = "zombie_cod5_factory";
    found = false;
    for (i = 0; i < stock.size; i++)
        if (stock[i] == map)
            found = true;
    if (!found)
        return;
    for (;;) {
        wait 1;
        if (GsGameOver())
            return;
        players = getplayers();
        for (i = 0; i < players.size; i++) {
            p = players[i];
            if (!isDefined(p))
                continue;
            alive = isDefined(p.sessionstate) && p.sessionstate == "playing";
            state = "up";
            if (!alive)
                state = "dead";
            else if (isDefined(p.revivetrigger))
                state = "down";
            logPrint("LiveRadar;" + GsHex(p getGuid()) + ";" + p.origin + ";" + p getPlayerAngles() + ";" + state
                + ";0;0;0;none;" + GsNum(p.health) + ";" + GsNum(alive) + ";0\n");
        }
    }
}

GsHex(value) {
    n = int(value);
    if (n <= 0)
        return "0";
    digits = "0123456789abcdef";
    out = "";
    for (i = 0; i < 16 && n > 0; i++) {
        out = digits[n % 16] + out;
        n = int(n / 16);
    }
    return out;
}

// The counts go out every 5 minutes (and at game over), 40 cells a line.
GsFloorFlush() {
    for (;;) {
        for (t = 0; t < 300 && !GsGameOver(); t++)
            wait 1;
        cells = level.gsFloor;
        level.gsFloor = [];
        if (isDefined(cells)) {
            keys = getArrayKeys(cells);
            data = "";
            n = 0;
            for (i = 0; i < keys.size; i++) {
                if (n > 0)
                    data = data + ";";
                data = data + keys[i] + "," + cells[keys[i]];
                n++;
                if (n == 40 || i == keys.size - 1) {
                    GsLevelLine("grid", data);
                    data = "";
                    n = 0;
                }
            }
        }
        if (GsGameOver())
            return;
    }
}

// Where the perk machines, Pack-a-Punch, box spots and wall buys are.
GsLogMarks() {
    wait 10;
    vending = getEntArray("zombie_vending", "targetname");
    for (i = 0; i < vending.size; i++) {
        if (isDefined(vending[i].script_noteworthy))
            GsMark("perk", vending[i].script_noteworthy, vending[i].origin);
    }
    pap = getEntArray("zombie_vending_upgrade", "targetname");
    for (i = 0; i < pap.size; i++)
        GsMark("pap", "specialty_weapupgrade", pap[i].origin);
    for (t = 0; t < 1200 && !isDefined(level.chests); t++)
        wait 1;
    if (isDefined(level.chests)) {
        for (i = 0; i < level.chests.size; i++) {
            if (isDefined(level.chests[i]))
                GsMark("box", "box", level.chests[i].origin);
        }
    }
    wallbuys = getEntArray("weapon_upgrade", "targetname");
    for (i = 0; i < wallbuys.size; i++) {
        if (isDefined(wallbuys[i].zombie_weapon_upgrade))
            GsMark("wall", wallbuys[i].zombie_weapon_upgrade, wallbuys[i].origin);
    }
}

GsMark(type, name, origin) {
    GsLevelLine("mark", type + ":" + name + ":" + int(origin[0]) + "," + int(origin[1]) + "," + int(origin[2]));
}

GsLevelLine(type, data) {
    line = level.gsRunId + "|" + level.gsMapToken + "|" + GsRound() + "|" + getDvar("net_port") + "|0|-|" + type + "|" + data;
    file = fs_fopen(level.gsEventFile, "append");
    if (isDefined(file) && file != 0) {
        fs_writeline(file, line);
        fs_fclose(file);
    }
}

GsEvent(player, type, data) {
    if (GsGameOver())
        return;
    id = "" + player getGuid();
    if (isDefined(player.persistentClientId))
        id = "" + player.persistentClientId;
    name = "";
    if (isDefined(player.name))
        name = GsCleanName(player.name);
    line = level.gsRunId + "|" + level.gsMapToken + "|" + GsRound() + "|" + getDvar("net_port") + "|"
         + id + "|" + name + "|" + type + "|" + data;
    file = fs_fopen(level.gsEventFile, "append");
    if (isDefined(file) && file != 0) {
        fs_writeline(file, line);
        fs_fclose(file);
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
