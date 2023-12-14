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
