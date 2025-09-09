#include common_scripts\utility;
#include maps\_utility;

main()
{
    level thread setPasswordsOnRound(20);
    level.locked = false;

    
    level thread resetPasswordOnEnd();
}

setPasswordsOnRound(roundNumber)
{
    level endon("disconnect");

    while (true)
    {
        level waittill("between_round_over");
        if (level.round_number >= roundNumber)
        {
            level.locked = true;
            pin = generateString();
            setDvar("g_password", pin);
            setDvar("password", pin);

            level thread messageRepeat("^2Server is now locked. Use password ^1" + pin + " ^2to rejoin.");
            break;
        }
    }
}

messageRepeat(message)
{
    level endon("disconnect");

    while (true)
    {
        iPrintLn(message);
        level waittill("between_round_over");
    }
}

generateString()
{
    str = "";

    for (i = 0; i < 4; i++)
    {
        str = str + randomInt(10);
    }

    return str;
}

resetPasswordOnEnd()
{
    level endon("disconnect");

    
    level waittill("end_game");

    
    setDvar("g_password", "");
    setDvar("password", "");
    iPrintLn("^2Server password has been cleared.");
}
