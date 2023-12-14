//////////////////////////////////////////////////////////////////////////
// Accessors
//////////////////////////////////////////////////////////////////////////

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

/**
	Returns the damage flags to apply when using this /obj to hit another.
 */
/obj/proc/damage_flags()
	. = 0
	if(has_edge(src))
		. |= DAM_EDGE
	if(is_sharp(src))
		. |= DAM_SHARP
		if(damtype == BURN)
			. |= DAM_LASER

/**
	Whether this /obj may embed in a wound when flung at a mob.
 */
/obj/proc/can_embed()
	return is_sharp(src)

/**
	Returns a text string to describe the current damage level of the item, or null if non-applicable.
 */
/obj/proc/get_examined_damage_string()
	if(!can_take_damage())
		return
	var/health_percent = get_percent_health()
	if(health_percent >= 100)
		return SPAN_NOTICE("It looks fully intact.")
	else if(health_percent > 75)
		return SPAN_NOTICE("It has a few cracks.")
	else if(health_percent > 50)
		return SPAN_WARNING("It looks slightly damaged.")
	else if(health_percent > 25)
		return SPAN_WARNING("It looks moderately damaged.")
	else
		return SPAN_DANGER("It looks heavily damaged.")

//////////////////////////////////////////////////////////////////////////
// Damage Interface
//////////////////////////////////////////////////////////////////////////

/obj/apply_health_change(difference = 0, damage_type, damage_flags, def_zone, quiet = FALSE)
	//!- We allow health changes without a damage type, so make sure we also check can_take_damage() first.
	if(!can_take_damage() || (damage_type && !is_vulnerable_to_damage_type(damage_type, damage_flags, def_zone)))
		return TRUE

	//Apply health change if there's any to apply.
	if(difference != 0)
		set_health(health + difference)

	//Abort if we're not dead
	if(health > 0)
		return TRUE

	//We're dead
	pick_destruction_proc(difference, damage_type, damage_flags, quiet)
	return FALSE

//////////////////////////////////////////////////////////////////////////
//Destruction
//////////////////////////////////////////////////////////////////////////

/obj/melt(skip_qdel, no_debris, quiet)
	if(!no_debris)
		if(length(matter))
			var/datum/gas_mixture/environment = loc?.return_air()
			for(var/mat in matter)
				var/decl/material/M = GET_DECL(mat)
				M.add_burn_product(environment, MOLES_PER_MATERIAL_UNIT(matter[mat]))
			matter = null
		new /obj/effect/decal/cleanable/molten_item(src)
	qdel(src)

/**
	Destruction proc for obj that are made of a brittle material
 */
/obj/proc/shatter(skip_qdel, no_debris, quiet)
	SHOULD_CALL_PARENT(TRUE)
	if(!skip_qdel && !QDELETED(src))
		qdel(src)