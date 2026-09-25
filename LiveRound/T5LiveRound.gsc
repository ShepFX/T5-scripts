/**
 * Live round reporter (T5 / Black Ops 1 Zombies).
 *
 * Writes the round currently being played to scriptdata/currentround.txt so the
 * website can show a live round, and blanks the file when the game ends so a
 * finished game never keeps displaying.
 *
 * File format - a single line:
 *     <round>|<players>|<port>|<hostname>
 * An empty file means no game in progress.
 *
 * The port is what lets the website tie this file to the right server: folder
 * names and server names do not reliably match (t5sp-callofdead is
 * "[CUK] Call Of Dead [EU]"), but a port is unique. The hostname is a fallback
 * in case net_port cannot be read.
 *
 * The round is polled rather than hooked to a round-start notify on purpose:
 * notify names vary between stock and custom maps, but level.round_number is
 * present everywhere. Polling costs one comparison a second.
 */

main() {
    level thread InitLiveRound();
}

InitLiveRound() {
    level.liveRoundFile = "scriptdata/currentround.txt";

    // Mirrored into a dvar as well as the file: IW4MAdmin can read a dvar over
    // rcon on its normal poll, which is how the round reaches the webfront
    // server cards without waiting for a file to be read.
    level.liveRoundDvar = "cuk_round";
    setdvar( level.liveRoundDvar, "0" );

    // Seconds between refreshes when the round has not changed. The rewrite
    // keeps the file's modified time current, which is how the website tells a
    // live game from a file left behind by a server that crashed.
    level.liveRoundHeartbeat = 60;

    WriteLiveRound("");

    level thread MonitorLiveRound();
    level thread ClearLiveRoundOn("end_game");
    level thread ClearLiveRoundOn("game_ended");
}

MonitorLiveRound() {
    level endon("end_game");
    level endon("game_ended");

    lastRound = -1;
    sinceWrite = 0;

    for (;;) {
        wait 1;
        sinceWrite++;

        if (!isDefined(level.round_number))
            continue;

        if (level.round_number != lastRound || sinceWrite >= level.liveRoundHeartbeat) {
            lastRound = level.round_number;
            sinceWrite = 0;

            // mapname is included because one server can host several maps
            // (the stock rotation), and the website needs to know which map's
            // record to compare this round against.
            line = level.round_number + "|" + getplayers().size + "|"
                 + getDvar("net_port") + "|" + getDvar("sv_hostname") + "|"
                 + getDvar("mapname");

            WriteLiveRound(line);
            setdvar( level.liveRoundDvar, "" + level.round_number );
        }
    }
}

ClearLiveRoundOn(notifyName) {
    level waittill(notifyName);
    WriteLiveRound("");
    setdvar( level.liveRoundDvar, "0" );
}

WriteLiveRound(text) {
    file = fs_fopen(level.liveRoundFile, "write");
    if (isDefined(file) && file != 0) {
        fs_writeline(file, text);
        fs_fclose(file);
    }
}
