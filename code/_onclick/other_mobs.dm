/mob/proc/attack_empty_hand()
	return

/mob/living/carbon/human/RestrainedClickOn(var/atom/A)
	return

/mob/living/CtrlClickOn(var/atom/A)
	. = ..()
	if(!. && a_intent == I_GRAB && length(available_maneuvers))
		. = perform_maneuver(prepared_maneuver || available_maneuvers[1], A)


/mob/living/carbon/human/RangedAttack(var/atom/A, var/params)
	//Climbing up open spaces
	if(isturf(loc) && bound_overlay && !is_physically_disabled() && istype(A) && A.can_climb_from_below(src))
		return climb_up(A)

	var/obj/item/clothing/gloves/G = get_equipped_item(slot_gloves_str)
	if(istype(G) && G.Touch(A,0)) // for magic gloves
		return TRUE

	. = ..()

/mob/living/RestrainedClickOn(var/atom/A)
	return

/*
	Aliens
*/

/mob/living/carbon/alien/RestrainedClickOn(var/atom/A)
	return

/mob/living/carbon/alien/UnarmedAttack(var/atom/A, var/proximity)

	if(!..())
		return 0

	setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
	A.attack_generic(src,rand(5,6),"bites")

/*
	New Players:
	Have no reason to click on anything at all.
*/
/mob/new_player/ClickOn()
	return

/*
	Animals
*/
/mob/living/simple_animal/UnarmedAttack(var/atom/A, var/proximity)

	if(!..())
		return

	setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
	if(isliving(A))
		if(a_intent == I_HELP || !get_natural_weapon())
			custom_emote(1,"[friendly] [A]!")
			return
		if(ckey)
			admin_attack_log(src, A, "Has attacked its victim.", "Has been attacked by its attacker.")
	if(a_intent == I_HELP)
		A.attack_animal(src)
	else
		var/attacking_with = get_natural_weapon()
		if(attacking_with)
			A.attackby(attacking_with, src)
