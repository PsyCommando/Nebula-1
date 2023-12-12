/**
	Fall damage to apply for a height of a single z level.
 */
/atom/movable/proc/fall_damage() //#TODO: This should probably take into account velocity and etc
	return 0

//////////////////////////////////////////////////////////////////////////
//Unarmed Attacks
//////////////////////////////////////////////////////////////////////////

/atom/movable/attack_hand(mob/user)
	// Unbuckle anything buckled to us.
	if(!can_buckle || !buckled_mob || !user.check_dexterity(DEXTERITY_SIMPLE_MACHINES, TRUE))
		return ..()
	user_unbuckle_mob(user)
	return TRUE

//////////////////////////////////////////////////////////////////////////
//Item Attacks
//////////////////////////////////////////////////////////////////////////

/atom/movable/attackby(obj/item/W, mob/user, click_params)
	//Handle melee attacks.
	return bash(W,user) //#TODO: Will be changed in favor of using the mob callchain for melee weapons.

//////////////////////////////////////////////////////////////////////////
//Melee Attacks
//////////////////////////////////////////////////////////////////////////

/**
	(soon to be Deprecated)
	Handles incoming melee damage dealt to this atom.
	Not used by mobs.
	- `W`: The weapon used on this atom.
	- `user`: The user of the weapon inflicting damage to us.
	- Returns: TRUE if the attack was processed successfully. FALSE if the attack didn't go through.
	FALSE also triggers a call to the weapon's afterattack proc.
 */
/atom/movable/proc/bash(obj/item/W, mob/user)
	if(isliving(user) && user.a_intent == I_HELP)
		return FALSE
	if(W.item_flags & ITEM_FLAG_NO_BLUDGEON)
		return FALSE
	visible_message("<span class='danger'>[src] has been hit by [user] with [W].</span>")
	return TRUE

//////////////////////////////////////////////////////////////////////////
//Impacts
//////////////////////////////////////////////////////////////////////////

/atom/movable/hitby(atom/movable/AM, datum/thrownthing/TT)
	..()
	process_momentum(AM,TT)
	//Moved over from code\_helpers\atom_movables.dm
	if(density && prob(50))
		do_simple_ranged_interaction()

/**
	Called when src is thrown into hit_atom.
	- `hit_atom`: The atom being hit by this atom.
	- `TT`: The thrownthing datum containing all the data about the throwing state of this atom.
 */
/atom/movable/proc/throw_impact(atom/hit_atom, datum/thrownthing/TT)
	SHOULD_CALL_PARENT(TRUE)
	if(istype(hit_atom) && !QDELETED(hit_atom))
		hit_atom.hitby(src, TT)

/**
	Returns the type of bullet impact effect type to use for this atom.
 */
/atom/movable/proc/get_bullet_impact_effect_type()
	return BULLET_IMPACT_NONE

//////////////////////////////////////////////////////////////////////////
//Misc Acts
//////////////////////////////////////////////////////////////////////////

/atom/movable/singularity_act(obj/effect/singularity/S, singularity_stage)
	if(!simulated)
		return 0
	physically_destroyed()
	if(!QDELETED(src))
		qdel(src)
	return 2

/**
	Called when a door crushes this atom while it's obstructing it.
	- `crush_damage`: The amount of BRUTE damage to apply to this atom.
	- Returns: TRUE if the atom was crushed by/took damage from the door.
 */
/atom/movable/proc/airlock_crush(crush_damage)
	return FALSE

