#include maps\_utility;
#include common_scripts\utility;

/*
	CUK fix: Moon "teleport between rounds = 24 zombie round" exploit (stock BO1 bug)

	Teleporting to No Man's Land between rounds runs zombie_moon_wasteland::nml_setup_round_spawner(),
	which saves the next round's zombie count as

		level.prev_round_zombies = [[ level.max_zombie_func ]]( level.zombie_vars["zombie_max_ai"] );

	max_zombie_func only scales the first five rounds down; it does not add the round / player
	multiplier that _zombiemode::round_spawning() adds. So from round 6 on the saved count is a flat
	24, and when the players return zombie_moon.gsc forces the round to those 24 zombies.

	After a between-rounds teleport this clears prev_round_zombies. zombie_moon.gsc only restores the
	saved count when it is not 0, so the round after returning keeps the full count round_spawning()
	calculated. Teleporting mid-round is unchanged: the zombies actually left are restored as before.
*/

main()
{
	if ( getdvar( "mapname" ) != "zombie_moon" )
		return;

	replaceFunc( getFunction( "maps/zombie_moon_wasteland", "nml_setup_round_spawner" ), ::nml_setup_round_spawner_fixed, -1 );
}

nml_setup_round_spawner_fixed()
{
	// same condition the stock function uses to decide it is between rounds
	between_rounds = false;
	if ( isdefined( level.round_number ) )
	{
		if ( flag( "between_rounds" ) )
			between_rounds = true;
	}

	func = getFunction( "maps/zombie_moon_wasteland", "nml_setup_round_spawner" );
	disableDetourOnce( func );
	self [[ func ]]();

	if ( between_rounds )
	{
		level.prev_round_zombies = 0;
		logprint( "CUKMOON;nml_between_rounds;round " + level.round_number + ";next round uses full count\n" );
	}
}
