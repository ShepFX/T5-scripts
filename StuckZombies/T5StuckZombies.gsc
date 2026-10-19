// T5 ZM - Stuck zombie watchdog
//
// A zombie that stays in one spot for 3 minutes is respawned: removed without
// points or kill credit and put back into the round's queue, so it comes in
// again from a normal spawner. Zombies that move are never touched.
//
// Why: players were wedging the last zombies of a round into window barriers
// to stall the round and take breaks, dodging the AFK system's round-20 gate
// and cooldown. The game's own failsafe (round_spawn_failsafe in
// _zombiemode.gsc) misses them: it only compares positions 30 seconds apart,
// so a zombie jittering in place passes, and it skips any zombie that tore at
// a board in the last 8 seconds.
//
// "In one spot" = never more than SZ_RADIUS from where the watch started, so
// shuffling back and forth in a barrier still counts. Only ordinary zombies
// (animname "zombie") are watched - dogs, George, monkeys and other specials
// keep their own behaviour. The respawn is the game's own method: add one to
// level.zombie_total, then kill with no attacker.
//
// Every respawn is logged to games_*.log as STUCKZOMBIE;<map>;<round>;<pos>.

main()
{
    level thread _sz_boot();
}

init()
{
    level thread _sz_boot();
}

_sz_boot()
{
    if ( isdefined( level._sz_booted ) && level._sz_booted )
        return;
    level._sz_booted = true;

    level._sz_stuck_ms = 180000;   // 3 minutes in one spot
    level._sz_radius_sq = 128 * 128;

    level thread _sz_monitor();
}

_sz_monitor()
{
    level endon( "end_game" );

    for ( ;; )
    {
        wait 1;

        now = gettime();
        zombies = getaiarray( "axis" );
        for ( i = 0; i < zombies.size; i++ )
        {
            z = zombies[i];
            if ( !isdefined( z ) || !isalive( z ) )
                continue;
            if ( !isdefined( z.animname ) || z.animname != "zombie" )
                continue;

            // Still coming up out of the ground: not placed yet.
            if ( isdefined( z.in_the_ground ) && z.in_the_ground )
            {
                z._sz_anchor = undefined;
                continue;
            }

            if ( !isdefined( z._sz_anchor ) || distancesquared( z.origin, z._sz_anchor ) > level._sz_radius_sq )
            {
                z._sz_anchor = z.origin;
                z._sz_since = now;
                continue;
            }

            if ( now - z._sz_since >= level._sz_stuck_ms )
                z _sz_respawn();
        }
    }
}

_sz_respawn()
{
    self._sz_anchor = undefined;

    round = 0;
    if ( isdefined( level.round_number ) )
        round = level.round_number;
    logprint( "STUCKZOMBIE;" + getdvar( "mapname" ) + ";" + round + ";"
            + int( self.origin[0] ) + "," + int( self.origin[1] ) + "," + int( self.origin[2] ) + "\n" );
    iprintln( "^3A stuck zombie was respawned." );

    // Back into the round's queue, then removed - the game's own failsafe does
    // the same, so the round count and the spawner stay consistent.
    level.zombie_total++;
    self dodamage( self.health + 100, ( 0, 0, 0 ) );
}
