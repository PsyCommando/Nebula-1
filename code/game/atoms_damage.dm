//////////////////////////////////////////////////////////////////////////
// Accessors
//////////////////////////////////////////////////////////////////////////

/**
	Returns whether this atom is damaged.
 */
/atom/proc/is_damaged()
	return FALSE

/**
	Returns TRUE if this atom can take damage.
 */
/atom/proc/can_take_damage()
	return FALSE

/**
	Check if this atom may take damage from the specified damage type.
	- `damage_type`: The damage type to check vulnerability to.
	- `damage_flags`: The damage flags for the specified damage type.
	- `def_zone`: If applicable, the zone targeted by the damage.
	- Returns: TRUE if this atom is vulnerable to the given damage type and flags and zone.
 */
/atom/proc/is_vulnerable_to_damage_type(damage_type, damage_flags, def_zone)
	return can_take_damage()

/**
	Returns the percentage of "health" remaining for this atom.
 */
/atom/proc/get_percent_health()
	return 100

/**
	Returns the percentage of damage done to this atom.
 */
/atom/proc/get_percent_damages()
	return 0

//////////////////////////////////////////////////////////////////////////
//Damage Interface
//////////////////////////////////////////////////////////////////////////

/**
	Handles incoming damage dealt to this atom.
	- `amount`: Positive amount of damage dealt to this atom.
	- `damage_type`: The type of damage inflicted to this atom.
	- `damage_flags`: The damage flags of the damage inflicted to this atom.
	- `inflicter` : The atom that inflicted the damage. Or a string describing the source of the damage.
	- `armor_pen`: The armor penetration value of the damage dealt to this atom.
	- `def_zone`: *PLACEHOLDER DON'T REMOVE* The defensive zone targeted by the damage being dealt to this atom.
	- `quiet`: If TRUE this proc, and the procs it call will not print text to chat, or cause any effects/sounds.
	- Returns: The actual amount of damage dealt to this atom after modifiers and armor.
*/
/atom/proc/take_damage(amount, damage_type = BRUTE, damage_flags = 0, inflicter = null, armor_pen = 0, def_zone = null, quiet = FALSE)
	return 0

//////////////////////////////////////////////////////////////////////////
//Destruction
//////////////////////////////////////////////////////////////////////////

/**
	Handle the destruction of this atom, spilling it's contents by default

	- `skip_qdel`: If calling qdel() on this atom should be skipped.
	- `no_debris`: If TRUE no debris or contents will be dropped upon destruction.
	- `quiet`: If TRUE, no sound, effect, or text will be printed by this proc.
	- Return: Unknown, feel free to change this
*/
/atom/proc/physically_destroyed(skip_qdel, no_debris, quiet)
	SHOULD_CALL_PARENT(TRUE)
	if(!no_debris)
		dump_contents()
	if(!skip_qdel && !QDELETED(src))
		qdel(src)
	. = TRUE

/**
	Handle this atom being destroyed through melting
	- `skip_qdel`: If calling qdel() on this atom should be skipped.
	- `no_debris`: If TRUE no debris or contents will be dropped upon destruction.
	- `quiet`: If TRUE, no sound, effect, or text will be printed by this proc.
 */
/atom/proc/melt(skip_qdel, no_debris, quiet)
	SHOULD_CALL_PARENT(TRUE)
	if(!skip_qdel && !QDELETED(src))
		qdel(src)
