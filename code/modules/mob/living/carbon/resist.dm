/mob/living/carbon/process_resist()

	//drop && roll
	if(on_fire && !buckled)
		fire_stacks -= 1.2
		SET_STATUS_MAX(src, STAT_WEAK, 3)
		spin(32,2)
		visible_message(
			"<span class='danger'>[src] rolls on the floor, trying to put themselves out!</span>",
			"<span class='notice'>You stop, drop, and roll!</span>"
			)
		sleep(30)
		if(fire_stacks <= 0)
			visible_message(
				"<span class='danger'>[src] has successfully extinguished themselves!</span>",
				"<span class='notice'>You extinguish yourself.</span>"
				)
			ExtinguishMob()
		return TRUE

	if(istype(buckled, /obj/effect/vine))
		var/obj/effect/vine/V = buckled
		spawn() V.manual_unbuckle(src)
		return TRUE

	if(..())
		return TRUE

	if(get_equipped_item(slot_handcuffed_str))
		spawn() escape_handcuffs()

/mob/living/carbon/proc/get_cuff_breakout_mod()
	return istype(get_equipped_item(slot_gloves_str), /obj/item/clothing/gloves/rig)? 0.5 : 1.0

/mob/living/carbon/proc/escape_handcuffs()
	var/obj/item/handcuffs/cuffs = get_equipped_item(slot_handcuffed_str)
	//This line represent a significant buff to grabs...
	// We don't have to check the click cooldown because /mob/living/verb/resist() has done it for us, we can simply set the delay
	setClickCooldown(100)

	//This should never happen since its checked on equip, but the legacy code assumed cuffs could be of any type
	if(!istype(cuffs))
		CRASH("Was cuffed with invalid type ''[cuffs?.type]''")

	return cuffs.escape_handcuffs(src, get_cuff_breakout_mod())

/mob/living/carbon/human/can_break_cuffs()
	. = ..() || species.can_shred(src,1)

/mob/living/carbon/proc/get_special_resist_time()
	return 0

/mob/living/carbon/escape_buckle()
	var/unbuckle_time
	if(src.get_equipped_item(slot_handcuffed_str) && istype(src.buckled, /obj/effect/energy_net))
		var/obj/effect/energy_net/N = src.buckled
		N.escape_net(src) //super snowflake but is literally used NOWHERE ELSE.-Luke
		return

	if(!buckled) return
	if(!restrained())
		..()
	else
		setClickCooldown(100)
		unbuckle_time = max(0, (2 MINUTES) - get_special_resist_time())

		visible_message(
			"<span class='danger'>[src] attempts to unbuckle themself!</span>",
			"<span class='warning'>You attempt to unbuckle yourself. (This will take around [unbuckle_time / (1 SECOND)] second\s and you need to stand still)</span>", range = 2
			)

	if(unbuckle_time && buckled)
		var/stages = 2
		for(var/i = 1 to stages)
			if(!unbuckle_time || do_after(usr, unbuckle_time*0.5, incapacitation_flags = INCAPACITATION_DEFAULT & ~(INCAPACITATION_RESTRAINED | INCAPACITATION_BUCKLED_FULLY)))
				if(!buckled)
					return
				visible_message(
					SPAN_WARNING("\The [src] tries to unbuckle themself."),
					SPAN_WARNING("You try to unbuckle yourself ([i*100/stages]% done)."), range = 2
					)
			else
				if(!buckled)
					return
				visible_message(
					SPAN_WARNING("\The [src] stops trying to unbuckle themself."),
					SPAN_WARNING("You stop trying to unbuckle yourself."), range = 2
					)
				return
		visible_message(
			SPAN_DANGER("\The [src] manages to unbuckle themself!"),
			SPAN_NOTICE("You successfully unbuckle yourself."), range = 2
			)
		buckled.user_unbuckle_mob(src)
		return
