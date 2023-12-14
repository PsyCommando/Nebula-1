/**
	Returns whether this object is damaged.
 */
/obj/is_damaged()
	return can_take_damage() && (health < max_health)

/**
	Returns TRUE if this object can take damage.
 */
/obj/an_take_damage()
	return (health != ITEM_HEALTH_NO_DAMAGE) && (max_health != ITEM_HEALTH_NO_DAMAGE)

/**
	Returns the percentage of health remaining for this object.
 */
/obj/get_percent_health()
	return can_take_damage()? round((health * 100)/max_health, HEALTH_ROUNDING) : 100

/**
	Returns the percentage of damage done to this object.
 */
/obj/get_percent_damages()
	//Clamp from 0 to 100 so health values larger than max_health don't return unhelpful numbers
	return clamp(100 - get_percent_health(), 0, 100)

//////////////////////////////////////////////////////////////////////////
//Impacts
//////////////////////////////////////////////////////////////////////////

/obj/hitby(atom/movable/AM, datum/thrownthing/TT)
	..()
	if(!anchored)
		step(src, AM.last_move)

