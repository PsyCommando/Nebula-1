//////////////////////////////////////////////////////////////////////////
// Generic Attack
//////////////////////////////////////////////////////////////////////////

/**
	Generic attack proc for unarmed damage. Is mostly used by slimes and a few other cases.
	Should probably be considered mostly deprecated.
	- `user`: Inflicter of the attack.
	- `damage`: The amount of damages being dealt.
	- `attack_verb`: The attack verb to use.
	- `environment_smash`: Whether this attack can destroy structures.
 */
/atom/proc/attack_generic(mob/user, damage, attack_verb, environment_smash)
	return

//////////////////////////////////////////////////////////////////////////
// Item attack
//////////////////////////////////////////////////////////////////////////

/**
	Called when a mob uses an item on this atom.
	- `W`: The item that was used on this atom.
	- `user`: The mob that used this item on this atom.
	- `click_params`: The click parameters string passed by the "atom/Click" proc.
	- Returns: TRUE if the attack was processed, or FALSE if it didn't go through. Returning FALSE means the item's afterattack proc will be called.
 */
/atom/proc/attackby(obj/item/W, mob/user, click_params)
	return FALSE

//////////////////////////////////////////////////////////////////////////
// Unarmed Attacks
//////////////////////////////////////////////////////////////////////////

/**
	Called when a human-like mob clicks this atom.
	- `user`: The mob that touched us.
	- Returns: TRUE if the attack was processed, or FALSE if it didn't go through.
 */
/atom/proc/attack_hand(mob/user)
	SHOULD_CALL_PARENT(TRUE)
	if(handle_grab_interaction(user))
		return TRUE
	if(!LAZYLEN(climbers) || (user in climbers) || !user.check_dexterity(DEXTERITY_HOLD_ITEM, silent = TRUE))
		return FALSE
	user.visible_message(
		SPAN_DANGER("\The [user] shakes \the [src]!"),
		SPAN_DANGER("You shake \the [src]!"))
	object_shaken()
	return TRUE

/**
	Attack hand but for simple animals
	- `user`: The mob that touched this atom.
	- Returns: TRUE if the attack was processed, or FALSE if it didn't go through.
 */
/atom/proc/attack_animal(mob/user)
	return attack_hand_with_interaction_checks(user)

/**
	Called when an AI clicks this atom.
	- `user`: The mob that touched this atom.
	- Returns: TRUE if the attack was processed, or FALSE if it didn't go through.
 */
/atom/proc/attack_ai(mob/living/silicon/ai/user)
	return

/**
	Called when a robot mob clicks this atom.
	- `user`: The mob that touched this atom.
	- Returns: TRUE if the attack was processed, or FALSE if it didn't go through.
 */
/atom/proc/attack_robot(mob/user)
	return attack_ai(user)

/**
	Called when a ghost mob clicks this atom.
	- `user`: The mob that touched this atom.
	- Returns: TRUE if the attack was processed, or FALSE if it didn't go through.
 */
/atom/proc/attack_ghost(mob/observer/ghost/user)
	// Oh by the way this didn't work with old click code which is why clicking shit didn't spam you
	if(!istype(user))
		return
	if(user.client && user.client.inquisitive_ghost)
		user.examinate(src)
	return

/**
	Used to check for physical interactivity in case of nonstandard attack_hand calls.
	- `user`: The mob that touched this atom.
	- Returns: TRUE if the attack was processed, or FALSE if it didn't go through.
 */
/atom/proc/attack_hand_with_interaction_checks(mob/user)
	return CanPhysicallyInteract(user) && attack_hand(user)


//////////////////////////////////////////////////////////////////////////
// Grabbing
//////////////////////////////////////////////////////////////////////////

/**
	Handles mobs trying to grab this atom. This proc is specifically meant for grabbing non-mobs.
	- `user`: Mob trying to grab this atom.
	- Returns: TRUE if the interaction was processed, or FALSE if it didn't go through.
 */
/atom/proc/handle_grab_interaction(mob/user)
	return FALSE

/**
	Handle this atom being hit by a grab.

	Called by resolve_attackby()

	- `G`: The grab hitting this atom
	- Return: `TRUE` to skip attackby() and afterattack() or `FALSE`
*/
/atom/proc/grab_attack(obj/item/grab/G)
	return FALSE

//////////////////////////////////////////////////////////////////////////
// Throwing
//////////////////////////////////////////////////////////////////////////

/**
	Handle this atom being hit by a thrown atom

	- `AM`: The atom hitting this atom
	- `TT`: A datum wrapper for a thrown atom, containing important info
*/
/atom/proc/hitby(atom/movable/AM, datum/thrownthing/TT)
	SHOULD_CALL_PARENT(TRUE)
	//#TODO: Move this to someplace better?
	if(isliving(AM))
		var/mob/living/M = AM
		M.apply_damage(TT.speed*5, BRUTE)

//////////////////////////////////////////////////////////////////////////
// Projectiles
//////////////////////////////////////////////////////////////////////////

/**
	Handle a projectile `P` hitting this atom

	- `P`: The `/obj/item/projectile` hitting this atom
	- `def_zone`: The zone `P` is hitting
	- Return: Can be special PROJECTILE values (misc.dm) (Old return value was DEPRECATED by penetration system)
*/
/atom/proc/bullet_act(obj/item/projectile/P, def_zone)
	P.on_hit(src, 0, def_zone) //#REMOVEME: Unclear if ever called.
	return 0

//////////////////////////////////////////////////////////////////////////
// Other Acts
//////////////////////////////////////////////////////////////////////////

/**
	Handle an EMP affecting this atom

	- `severity`: Strength of the explosion ranging from 1 to 3. Higher is weaker
*/
/atom/proc/emp_act(severity)
	return

/**
	Handle an explosion of `severity` affecting this atom

	- `severity`: Strength of the explosion ranging from 1 to 3. Higher is weaker
	- Return: `TRUE` if severity is within range and exploding should continue, otherwise `FALSE`
*/
/atom/proc/explosion_act(severity)
	SHOULD_CALL_PARENT(TRUE)
	. = !currently_exploding && severity > 0 && severity <= 3
	if(.)
		currently_exploding = TRUE
		if(severity < 3)
			for(var/atom/movable/AM in get_contained_external_atoms())
				AM.explosion_act(severity + 1)
			try_detonate_reagents(severity)
		currently_exploding = FALSE

/**
	Handle a `user` attempting to emag this atom

	- `remaining_charges`: Used for nothing TODO: Fix this
	- `user`: The user attempting to emag this atom
	- `emag_source`: The source of the emag
	- Returns: 1 if successful, -1 if not, NO_EMAG_ACT if it cannot be emaged
*/
/atom/proc/emag_act(remaining_charges, mob/user, emag_source)
	return NO_EMAG_ACT

/**
	Handle this atom being exposed to fire

	- `air`: The gas_mixture for this loc
	- `exposed_temperature`: The temperature of the air
	- `exposed_volume`: The volume of the air
*/
/atom/proc/fire_act(datum/gas_mixture/air, exposed_temperature, exposed_volume)
	return

/**
	Handle this atom being exposed to lava. Calls qdel() by default
	- `air`: The gas volume that this atom was exposed to.
	- `temperature`: The temperature of the gas volume this atom was exposed to.
	- `pressure`: The pressure of the gas volume this atom was exposed to.
	- Returns: `TRUE` if qdel() was called, otherwise `FALSE`
*/
/atom/proc/lava_act(datum/gas_mixture/air, temperature, pressure)
	//#TODO: Use melt() or something instead of this
	visible_message(SPAN_DANGER("\The [src] sizzles and melts away, consumed by the lava!"))
	playsound(src, 'sound/effects/flare.ogg', 100, 3)
	qdel(src)
	return TRUE

/**
	Handles this atom being exposed to a singularity.
	- `S`: The singluarity affecting us.
	- `singularity_stage`: The current stage of the singularity.
	- Returns: The amount of energy the atom will provides the singularity, or 0. This value will make the singularity grow or shrink.
 */
/atom/proc/singularity_act(obj/effect/singularity/S, singularity_stage)
	return 0
