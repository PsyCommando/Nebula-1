//////////////////////////////////////////////////////////////////////////
// Accessors
//////////////////////////////////////////////////////////////////////////

/**
	Fall damage to apply for a height of a single z level.
 */
/atom/movable/proc/fall_damage() //#TODO: This should probably take into account velocity and etc
	return 0

//////////////////////////////////////////////////////////////////////////
// Unarmed Attacks
//////////////////////////////////////////////////////////////////////////

/atom/movable/attack_hand(mob/user)
	// Unbuckle anything buckled to us.
	if(!can_buckle || !buckled_mob || !user.check_dexterity(DEXTERITY_SIMPLE_MACHINES, TRUE))
		return ..()
	user_unbuckle_mob(user)
	return TRUE

//////////////////////////////////////////////////////////////////////////
// Item Attacks
//////////////////////////////////////////////////////////////////////////

/atom/movable/attackby(obj/item/W, mob/user, click_params)
	//Handle melee attacks.
	return bash(W,user) //#TODO: Will be changed in favor of using the mob callchain for melee weapons.

//////////////////////////////////////////////////////////////////////////
// Melee Attacks
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
	//#TODO: Remove this in favor of the mob callchain for melee damages
	if(isliving(user) && user.a_intent == I_HELP)
		return FALSE
	if(W.item_flags & ITEM_FLAG_NO_BLUDGEON)
		return FALSE
	visible_message("<span class='danger'>[src] has been hit by [user] with [W].</span>")
	return TRUE

//////////////////////////////////////////////////////////////////////////
// Impacts
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
// Misc Acts
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

//////////////////////////////////////////////////////////////////////////
// Damage Interface
//////////////////////////////////////////////////////////////////////////

/**
	Handles incoming damage dealt to this atom.
	- `amount`: Positive amount of damage dealt to this atom.
	- `damage_type`: The type of damage inflicted to this atom.
	- `damage_flags`: The damage flags of the damage inflicted to this atom.
	- `inflicter` : A reference to the atom that inflicted the damage. Or a string describing the source of the damage.
	- `armor_pen`: The armor penetration value of the damage dealt to this atom.
	- `def_zone`: *PLACEHOLDER DON'T REMOVE* The defensive zone targeted by the damage being dealt to this atom.
	- `quiet`: If TRUE this proc, and the procs it call will not print text to chat, or cause any effects/sounds.
	- Returns: The actual amount of damage dealt to this atom after modifiers and armor.
*/
/atom/movable/take_damage(amount = 0, damage_type = BRUTE, damage_flags = 0, inflicter = null, armor_pen = 0, def_zone = null, quiet = FALSE)
	if(amount == 0 || !is_vulnerable_to_damage_type(damage_type, damage_flags, def_zone)) // This object does not take damage.
		return 0 //Must return a number
	//Sanity crash!
	if(amount < 0)
		CRASH("'[type]'/take_damage proc was called with negative damage.") //Negative damage are an implementation issue.

	//Apply damage modifiers
	var/list/modified_parameters = modify_incoming_damage(amount, damage_type, damage_flags, inflicter, armor_pen, def_zone, quiet)
	if(length(modified_parameters))
		//Its possible the implementation changes down the chain, and also some parameter may be ommited if unmodified.
		//#TODO: Would be much simpler if all this was contained in a datum or something.
		var/new_ammount = modified_parameters["amount"]
		var/new_dtype   = modified_parameters["damage_type"]
		var/new_dflags  = modified_parameters["damage_flags"]
		var/new_pen     = modified_parameters["armor_pen"]
		var/new_zone    = modified_parameters["def_zone"]
		amount       = isnull(new_ammount)? amount      : new_ammount
		damage_type  = isnull(new_dtype)?   damage_type : new_dtype
		damage_flags = isnull(new_dflags)?  damage_flags: new_dflags
		armor_pen    = isnull(new_pen)?     armor_pen   : new_pen
		def_zone     = isnull(new_zone)?    def_zone    : new_zone

	//Deal the actual damage we suffered
	if(amount <= 0)
		return 0 //must return a number
	apply_health_change(-1 * amount, damage_type, damage_flags, inflicter, def_zone, quiet)
	return amount

/**
	Applies incoming healing effects, such as repairing or healing a mob's bits and parts.
	- `amount`: Positive amount of healing done to this atom.
	- `damage_type`: The type of damage to be healed on this atom, or null for no specific damage type.
	- `damage_flags`: The damage flags of the damage type healed on this atom, or 0/null.
	- `inflicter` : A reference to the atom that healed us, or a descriptive string.
	- `def_zone`: If applicable the targeted zone on this atom to receive healing, or null. Null will apply healing to all the zones.
	- `quiet`: If TRUE this proc, and the procs it call will not print text to chat, or cause any effects/sounds.
	- Returns: The amount of actual healing done.
 */
/atom/movable/proc/heal(amount = 0, damage_type = null, damage_flags = 0, inflicter, def_zone = null, quiet = FALSE)
	if(amount == 0 || (damage_type && !is_vulnerable_to_damage_type(damage_type, damage_flags, def_zone))) // This object does not take damage.
		return 0 //Must return a number
	//Sanity crash!
	if(amount < 0)
		CRASH("'[type]'/heal proc was called with negative healing.") //Negative amounts are an implementation issue.
	return apply_health_change(amount, damage_type, damage_flags, inflicter, def_zone, quiet)

/**
	Applies incoming damage modifiers to the parameters it receives, and returns a list with the modified values.
	- `amount`: Amount of damage being dealt.
	- `damage_type`: Damage type of the damage being dealt.
	- `damage_flags`: Damage flags for the damage type of the damage being dealt.
	- `inflicter`: A descriptive string, or a reference to the atom that inflicted the damage.
	- `armor_pen`: The armor penetration value of the damage being dealt.
	- `def_zone`: If applicable, the locational damage location where the damage is being applied.
	- `quiet`: If TRUE this proc, and the procs it call will not print text to chat, or cause any effects/sounds.
	- Returns: Either null, or a list of each parameters passed to this proc whose value was changed. Key is parameter name, value is the new value of the parameter.
 */
/atom/movable/proc/modify_incoming_damage(amount = 0, damage_type, damage_flags, inflicter, armor_pen, def_zone, quiet = FALSE)
	if(amount <= 0)
		return //Don't create a new list for nothing

	//Apply armors
	var/list/armors = get_armors_by_zone(def_zone, damage_type, damage_flags)
	for(var/datum/extension/armor/A in armors)
		if(!istype(A))
			continue
		var/list/dam_after_armor = A.apply_damage_modifications(amount, damage_type, damage_flags, isliving(src)? src : null, armor_pen, quiet)
		if(dam_after_armor[1] != amount)
			LAZYSET(., "amount", dam_after_armor[1])
		if(dam_after_armor[2] != damage_type)
			LAZYSET(., "damage_type", dam_after_armor[2])
		if(dam_after_armor[3] != damage_flags)
			LAZYSET(., "damage_flags", dam_after_armor[3])
		if(dam_after_armor[5] != armor_pen)
			LAZYSET(., "armor_pen", dam_after_armor[5])

/**
	Obtain a list of armors to apply to damage inflicted to a particular zone. By default applies only the main armor datum.
	- `def_zone`: If applicable, the locational damage location where the damage is being applied.
	- `damage_type`: Damage type of the damage being dealt.
	- `damage_flags`: Damage flags for the damage type of the damage being dealt.
	- Returns: A list of armors to apply to the damage for the given def_zone. Or null.
 */
/atom/movable/proc/get_armors_by_zone(def_zone, damage_type, damage_flags)
	var/base_armor = get_extension(src, /datum/extension/armor)
	if(base_armor)
		LAZYADD(., base_armor)

/**
	Abstract handling for health changes, and health checking.
	Essentially, unlike set_health, keeps track of the damage type, def zone, and the damage/gain applied.
	So things that keep track of damage amounts can do what they want here. (AKA mobs)

	- `difference`: The signed value to add to the current "health"/damage counter.
	- `damage_type`: Damage type of the damage being dealt.
	- `damage_flags`: Damage flags for the damage type of the damage being dealt.
	- `inflicter`: A descriptive string, or a reference to the atom that inflicted the health change.
	- `def_zone`: If applicable, the locational damage location where the damage is being applied.
	- `quiet`: If TRUE this proc, and the procs it call will not print text to chat, or cause any effects/sounds.
	- Returns: The actual amount our "health" was changed by.
 */
/atom/movable/proc/apply_health_change(difference = 0, damage_type = BRUTE, damage_flags = 0, inflicter = null, def_zone = null, quiet = FALSE)
	return 0
