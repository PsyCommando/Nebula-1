//////////////////////////////////////////////////////////////////////////
// Accessors
//////////////////////////////////////////////////////////////////////////

/obj/is_damaged()
	return can_take_damage() && (health < max_health)

/obj/can_take_damage()
	return (health != ITEM_HEALTH_NO_DAMAGE) && (max_health != ITEM_HEALTH_NO_DAMAGE)

/obj/is_vulnerable_to_damage_type(damage_type, damage_flags)
	return can_take_damage() && ((damage_type == BRUTE) || (damage_type == BURN) || (damage_type == ELECTROCUTE) || (damage_type == IRRADIATE))

/obj/get_percent_health()
	return can_take_damage()? round((health * 100)/max_health, HEALTH_ROUNDING) : 100

/obj/get_percent_damages()
	//Clamp from 0 to 100 so health values larger than max_health don't return unhelpful numbers
	return clamp(100 - get_percent_health(), 0, 100)

/**
	Sets the current health for this object. Rounds and clamps the value. Does not trigger any health updates,
	since health updates need to know the cause of the health change to be handled properly.
	- `new_health`: The new health to set our health to.
	- `skip_update`: If TRUE, the proc won't cause a health update.
	- Returns: The actual difference between the old health, and the new value.
*/
/obj/proc/set_health(new_health, skip_update = FALSE)
	. = 0
	//Don't change this special value
	if(new_health != ITEM_HEALTH_NO_DAMAGE)
		if(max_health == ITEM_HEALTH_NO_DAMAGE)
			CRASH("Tried to change health of an invincible '[src]' to '[new_health]'!")
		new_health = clamp(round(new_health, HEALTH_ROUNDING), 0, max_health)
		if(!skip_update)
			update_health(health - new_health)
		. = health - new_health
	health = new_health

/**
	Sets the max_health for this object. Rounds and clamps the value and returns it.
 	- `new_max_health`: The new max_health to be set.
	- `update_health_mode`: An enum value to determine if we should update the current health, and in what way. (clamp to new max, or force set to new max)
	- `skip_update`: If TRUE, the proc won't cause a health update.
	- Returns: The new maximum health.
*/
/obj/proc/set_max_health(new_max_health, update_health_mode = MAX_HEALTH_UPDATE_RESET, skip_update = FALSE)
	//Don't change this special value
	if(new_max_health != ITEM_HEALTH_NO_DAMAGE)
		new_max_health = round(max(new_max_health, 0), HEALTH_ROUNDING)

	var/health_diff = abs(max_health - new_max_health)
	max_health = new_max_health
	switch(update_health_mode)
		if(MAX_HEALTH_UPDATE_RESET)
			set_health(max_health, skip_update)
		if(MAX_HEALTH_UPDATE_CLAMP)
			set_health(health, skip_update) //Is clamped in set_health
		if(MAX_HEALTH_UPDATE_ADD)
			set_health(health + health_diff, skip_update) //Is clamped in set_health
		else
			if(!skip_update)
				//Recheck health against max health even if we didn't touch the value
				update_health()
	return max_health

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
		return 0

	//Apply health change if there's any to apply.
	if(difference != 0)
		. = set_health(health + difference, FALSE)
		//Call update health manually so we can pass the damage type info and ensure the right destruction proc is picked.
		update_health(., damage_type, damage_flags, quiet)

/**
	Update the "health" state for this obj. And causes it to call a destruction proc if it falls below 0.
	- Returns: FALSE if the atom is destroyed. TRUE if it's still alive.
 */
/obj/proc/update_health(difference, last_damage_type, last_damage_flags = 0, quiet = FALSE)
	//Abort if we're not dead
	if(health > 0 || !can_take_damage())
		return TRUE
	//We're dead
	pick_destruction_proc(difference, damage_type, damage_flags, FALSE, quiet)
	return FALSE

//////////////////////////////////////////////////////////////////////////
//Destruction
//////////////////////////////////////////////////////////////////////////

/**
	Called when the atom's health reaches 0, and it's destroyed. Choses a destruction effect to run.
 */
/obj/proc/pick_destruction_proc(damage, damage_type, damage_flags, no_debris = FALSE, quiet = FALSE)
	switch(damage_type)
		if(BURN)
			melt(FALSE, no_debris, quiet)
		else
			physically_destroyed(FALSE, no_debris, quiet)

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