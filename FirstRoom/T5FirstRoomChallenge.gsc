// T5 ZM - First Room Challenge
// Keeps wall weapons, the box and any perk in the start room usable, but locks
// every way out of it: doors, debris, Five's elevators, Ascension's lander and
// the power switch. Drop in raw/scripts/sp/ - Plutonium runs main() for us.
//
// BO1 has no custom_door_buy_check hook like BO2, so this simply keeps the buy
// triggers switched off. The game's own code can switch some of them back on
// (Five re-enables elevator buys every time a car arrives), so it re-applies
// once a second rather than once at map start.

#include common_scripts\utility;
#include maps\_utility;
#include maps\_zombiemode_utility;

main()
{
    init();
}

init()
{
    if ( isdefined( level.frc_initialized ) && level.frc_initialized )
        return;

    level.frc_initialized = true;
    level.frc_enabled = true;
    level.frc_hint = "^3First Room Challenge^7: locked";

    level thread frc_lock_loop();
    level thread frc_player_connect();

    println( "[FIRST ROOM] challenge initialized on " + getdvar( "mapname" ) );
}

frc_player_connect()
{
    level endon( "end_game" );
    level endon( "intermission" );

    for ( ;; )
    {
        level waittill( "connected", player );
        player thread frc_intro_message();
    }
}

frc_intro_message()
{
    self endon( "disconnect" );
    self waittill( "spawned_player" );
    wait 3;

    if ( isdefined( level.frc_enabled ) && level.frc_enabled )
        self iprintlnbold( "^3First Room Challenge^7: doors are locked, wall weapons allowed." );
}

frc_lock_loop()
{
    level endon( "end_game" );
    level endon( "intermission" );

    // Let the stock blocker / elevator / lander init finish first.
    wait 2;

    for ( ;; )
    {
        if ( isdefined( level.frc_enabled ) && level.frc_enabled )
            frc_lock_everything();

        wait 1;
    }
}

frc_lock_everything()
{
    // Standard room blockers (all maps)
    frc_lock_ents( getentarray( "zombie_door", "targetname" ) );
    frc_lock_ents( getentarray( "zombie_debris", "targetname" ) );

    // Power switch - unreachable from the first room on every map, but if a
    // map ever puts it in reach nothing beyond it should turn on.
    frc_lock_ents( getentarray( "use_elec_switch", "targetname" ) );

    // Five: elevator buy panels and call boxes
    frc_lock_ents( getentarray( "elevator1_buy", "script_noteworthy" ) );
    frc_lock_ents( getentarray( "elevator2_buy", "script_noteworthy" ) );
    frc_lock_ents( getentarray( "elevator1_call_box", "targetname" ) );
    frc_lock_ents( getentarray( "elevator2_call_box", "targetname" ) );

    // Ascension: lunar lander call boxes
    frc_lock_ents( getentarray( "zip_call_box", "targetname" ) );
}

frc_lock_ents( ents )
{
    if ( !isdefined( ents ) )
        return;

    for ( i = 0; i < ents.size; i++ )
        frc_lock_trigger( ents[i] );
}

frc_lock_trigger( ent )
{
    if ( !isdefined( ent ) )
        return;

    // Only touch it once per second if it is actually usable again; hint
    // updates are configstring writes and there is no need to spam them.
    if ( isdefined( ent.frc_locked ) && ent.frc_locked )
    {
        ent trigger_off();
        return;
    }

    ent.frc_locked = true;
    ent setcursorhint( "HINT_NOICON" );
    ent sethintstring( level.frc_hint );
    ent trigger_off();
}
