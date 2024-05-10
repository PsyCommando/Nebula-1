/datum/daycycle
	abstract_type = /datum/daycycle
	var/list/suns = list(
		new /datum/sun
	)
	/// Unique string ID used to register a level with a daycycle.
	var/daycycle_id
	/// How long is a full day and night cycle?
	var/day_duration = 30 MINUTES
	/// How far are we into the current cycle?
	var/time_of_day = 0
	/// What world.time did we last update? Used to calculate time progression between ticks.
	var/last_update = 0
	/// What z-levels are affected by this daycycle? Used for mass updating ambience.
	var/list/levels_affected = list()
	/// What period of day are we sitting in as of our last update?
	var/datum/time_of_day/current_period
	/// Mappings of colour and power to % progression points throughout the cycle.
	/// Each entry must be arranged in order of earliest to latest.
	/// Null values on periods use the general level ambience instead.
	var/list/cycle_periods = list(
		new /datum/time_of_day/sunrise,
		new /datum/time_of_day/daytime,
		new /datum/time_of_day/sunset,
		new /datum/time_of_day/night
	)

/datum/daycycle/New(_cycle_id)
	daycycle_id = _cycle_id
	last_update = world.time
	current_period = cycle_periods[1]
	transition_daylight() // pre-populate our values.

/datum/daycycle/proc/add_level(level_z)
	levels_affected |= level_z
	var/datum/level_data/level = SSmapping.levels_by_z[level_z]
	if(level)
		level.update_turf_ambience()

/datum/daycycle/proc/remove_level(level_z)
	levels_affected -= level_z
	var/datum/level_data/level = SSmapping.levels_by_z[level_z]
	if(level)
		level.update_turf_ambience()

/datum/daycycle/proc/transition_daylight()

	time_of_day += world.time - last_update
	if(time_of_day >= day_duration)
		time_of_day -= day_duration

	var/datum/time_of_day/last_period = current_period
	var/progression_percentage = time_of_day / day_duration
	for(var/datum/time_of_day/period in cycle_periods)
		if(progression_percentage <= period.period)
			current_period = period
			break

	. = current_period != last_period && (current_period.color != last_period.color || current_period.power != last_period.power)
	if(. && current_period.announcement)
		for(var/mob/player in global.player_list)
			var/turf/T = get_turf(player)
			if((T.z in levels_affected) && T.is_outside())
				to_chat(player, SPAN_NOTICE(FONT_SMALL(current_period.announcement)))

/datum/daycycle/proc/tick()

	for(var/datum/sun/sun in suns)
		sun.calc_position()

	if(transition_daylight())
		for(var/level_z in levels_affected)
			var/datum/level_data/level = SSmapping.levels_by_z[level_z]
			if(level)
				level.update_turf_ambience()

/datum/daycycle/exoplanet/New()
	day_duration = rand(get_config_value(/decl/config/num/exoplanet_min_day_duration), get_config_value(/decl/config/num/exoplanet_max_day_duration)) MINUTES
	..()
