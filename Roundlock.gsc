
#include common_scripts\utility;
#include maps\_utility;

init()
{
    executeCommand( "g_password \"\"" );
    level thread SetPasswordsOnRound( 35 );
    level.locked = false; 
}

setPasswordsOnRound( roundNumber )
{
    level endon( "disconnect" );

    while ( true ) 
    {
        level waittill( "between_round_over" );
        if ( level.round_number >= roundNumber )
        {
            level.locked = true; 
            pin = generateString();
            executeCommand("g_password " + pin);
            executeCommand("password " + pin);

            level thread messageRepeat( "^2Server is now locked. Use password ^1" + pin + " ^2to rejoin." );
            break;
        }
    }
}
messageRepeat( message )
{
    level endon( "disconnect" );
    
    while ( true )
    {
        iPrintLn( message );
        level waittill( "between_round_over" );
    }
}

generateString()
{
    str = "";

    for ( i = 0; i < 4; i++ )
    {
        str = str + randomInt( 10 );
    }

    return str;
}

