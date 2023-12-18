// Accessors

/mob/proc/getBrainLoss()
	return 0

// Damage Interface



/mob/proc/apply_damage(var/damage = 0,var/damagetype = BRUTE, var/def_zone = null, var/damage_flags = 0, var/used_weapon = null, var/armor_pen, var/silent = FALSE)
	return
/mob/proc/get_blocked_ratio(def_zone, damage_type, damage_flags, armor_pen, damage)
	return

// Impacs

/mob/proc/standard_weapon_hit_effects(obj/item/I, mob/living/user, var/effective_force, var/hit_zone)
	return
/mob/proc/apply_effect(var/effect = 0,var/effecttype = STUN, var/blocked = 0)
	return

// Destruction

/mob/physically_destroyed(skip_qdel, no_debris, quiet)
	SHOULD_CALL_PARENT(FALSE)
	gib(, !no_debris)

// Misc Acts

/mob/explosion_act(severity)
	. = ..()
	if(QDELETED(src))
		return
	//#TODO: Turn severity to damage, so explosion protection and etc is actually used
	if(severity == 1)
		physically_destroyed(,, TRUE)
	else if(!is_blind())
		flash_eyes()
