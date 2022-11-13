/obj/item/handcuffs
	name = "handcuffs"
	desc = "Use this to keep prisoners in line."
	gender = PLURAL
	icon = 'icons/obj/items/handcuffs.dmi'
	icon_state = ICON_STATE_WORLD
	obj_flags = OBJ_FLAG_CONDUCTIBLE
	slot_flags = SLOT_LOWER_BODY
	throwforce = 5
	w_class = ITEM_SIZE_SMALL
	throw_speed = 2
	throw_range = 5
	origin_tech = "{'materials':1}"
	material = /decl/material/solid/metal/steel
	var/elastic
	var/dispenser = FALSE //#TODO: Probably should make the cuffs dispenser a standalone item for borgs?
	var/breakouttime = 2 MINUTES //Deciseconds = 120s = 2 minutes
	var/breakout_wear = FALSE //Whether the cuffs will take wear damage and allow breaking out of off.
	var/cuff_sound = 'sound/weapons/handcuffs.ogg'
	var/cuff_type = "handcuffs"

/obj/item/handcuffs/Destroy()
	var/obj/item/clothing/shoes/S = loc
	if(S && !QDELETED(S))
		S.remove_cuffs()
	. = ..()

/obj/item/handcuffs/physically_destroyed(skip_qdel, no_debris, quiet)
	if(!quiet && istype(loc, /obj/item/clothing/shoes))
		loc.visible_message(SPAN_WARNING("\The [src] attached to \the [loc] snap and fall away!"), range = 1)
	. = ..()

/obj/item/handcuffs/attack(var/mob/living/carbon/C, var/mob/living/user)
	if(!user.check_dexterity(DEXTERITY_COMPLEX_TOOLS))
		return

	if ((MUTATION_CLUMSY in user.mutations) && prob(50))
		to_chat(user, SPAN_WARNING("Uh ... how do those things work?!"))
		place_handcuffs(user, user)
		return

	// only carbons can be cuffed
	if(istype(C))
		if(!C.get_equipped_item(slot_handcuffed_str))
			if (C == user)
				return place_handcuffs(user, user)

			//check for an aggressive grab (or robutts)
			if(C.has_danger_grab(user))
				return place_handcuffs(C, user)
			else
				to_chat(user, SPAN_DANGER("You need to have a firm grip on [C] before you can put \the [src] on!"))
		else
			to_chat(user, SPAN_WARNING("\The [C] is already handcuffed!"))
		return FALSE
	return ..()

/obj/item/handcuffs/proc/place_handcuffs(var/mob/living/carbon/target, var/mob/user)
	playsound(src.loc, cuff_sound, 30, 1, -2)

	var/mob/living/carbon/human/H = target
	if(!istype(H))
		return FALSE

	if (!H.has_organ_for_slot(slot_handcuffed_str))
		to_chat(user, SPAN_DANGER("\The [H] needs at least two wrists before you can cuff them together!"))
		return FALSE

	var/obj/item/gloves = H.get_equipped_item(slot_gloves_str)
	if((gloves && (gloves.item_flags & ITEM_FLAG_NOCUFFS)) && !elastic)
		to_chat(user, SPAN_DANGER("\The [src] won't fit around \the [gloves]!"))
		return FALSE

	user.visible_message(SPAN_DANGER("\The [user] is attempting to put [cuff_type] on \the [H]!"))

	if(!do_after(user,30, target))
		return FALSE

	if(!target.has_danger_grab(user)) // victim may have resisted out of the grab in the meantime
		return FALSE

	var/obj/item/handcuffs/cuffs = src
	if(dispenser)
		cuffs = new(get_turf(user))
	else if(!user.unEquip(cuffs))
		return FALSE

	admin_attack_log(user, H, "Attempted to handcuff the victim", "Was target of an attempted handcuff", "attempted to handcuff")
	SSstatistics.add_field_details("handcuffs","H")

	user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
	user.do_attack_animation(H)

	user.visible_message(SPAN_DANGER("\The [user] has put [cuff_type] on \the [H]!"))

	// Apply cuffs.
	target.equip_to_slot(cuffs, slot_handcuffed_str)
	return TRUE

/obj/item/handcuffs/proc/escape_handcuffs(var/mob/living/carbon/C, var/breakout_time_modifier = 1.0)
	if(C.can_break_cuffs()) //Don't want to do a lot of logic gating here.
		return break_handcuffs(C)
	var/timebreak = breakouttime * max(0.25, breakout_time_modifier) //minimum is 1/4th of the time

	C.visible_message(
		SPAN_DANGER("\The [C] attempts to remove \the [src]!"),
		SPAN_WARNING("You attempt to remove \the [src] (This will take around [timebreak / (1 SECOND)] second\s and you need to stand still)."),
		range = 2
		)

	var/stages = 4
	for(var/i = 1 to stages)
		if(do_after(C, timebreak * 0.25, incapacitation_flags = INCAPACITATION_DEFAULT & ~INCAPACITATION_RESTRAINED))
			if(QDELETED(C) || QDELETED(src) || (C.get_equipped_item(slot_handcuffed_str) != src) || C.buckled)
				return FALSE
			C.visible_message(
				SPAN_WARNING("\The [C] fiddles with \the [src]."),
				SPAN_WARNING("You try to slip free of \the [src] ([i*100/stages]% done)."),
				range = 2
				)
		else
			if(QDELETED(C) || QDELETED(src) || (C.get_equipped_item(slot_handcuffed_str) != src) || C.buckled)
				return FALSE
			C.visible_message(
				SPAN_WARNING("\The [C] stops fiddling with \the [src]."),
				SPAN_WARNING("You stop trying to slip free of \the [src]."),
				range = 2
				)
			return FALSE
		if(QDELETED(C) || QDELETED(src) || (C.get_equipped_item(slot_handcuffed_str) != src) || C.buckled)
			return FALSE

	if(breakout_wear && can_take_damage() && (health > 0)) // Improvised cuffs can break because their health is > 0
		take_damage(max_health / 2)
		if(QDELETED(src))
			C.visible_message(
				SPAN_DANGER("\The [C] manages to remove \the [src], breaking them!"),
				SPAN_NOTICE("You successfully remove \the [src], breaking them!"),
				range = 2
				)
			if(C.buckled && C.buckled.buckle_require_restraints)
				C.buckled.unbuckle_mob()
			C.update_inv_handcuffed()
			return TRUE

	visible_message(
		SPAN_WARNING("\The [C] manages to remove \the [src]!"),
		SPAN_NOTICE("You successfully remove \the [src]!"),
		range = 2
		)
	C.drop_from_inventory(src)
	return TRUE

/obj/item/handcuffs/proc/break_handcuffs(var/mob/living/carbon/C)
	C.visible_message(
		SPAN_DANGER("[C] is trying to break \the [src]!"),
		SPAN_WARNING("You attempt to break your [src]. (This will take around 5 seconds and you need to stand still)"),
		range = 2
		)

	if(do_after(C, 5 SECONDS, incapacitation_flags = INCAPACITATION_DEFAULT & ~INCAPACITATION_RESTRAINED))
		if(QDELETED(C) || QDELETED(src) || (C.get_equipped_item(slot_handcuffed_str) != src) || C.buckled)
			return FALSE

		C.visible_message(
			SPAN_DANGER("[C] manages to break \the [src]!"),
			SPAN_WARNING("You successfully break your [src]."),
			range = 2
		)

		C.unEquip(src)
		physically_destroyed()
		if(C.buckled && C.buckled.buckle_require_restraints)
			C.buckled.unbuckle_mob()
		return TRUE
	return FALSE

var/global/last_chew = 0 //#FIXME: Its funny how only one person in the world can chew their restraints every 2.6 seconds
/mob/living/carbon/human/RestrainedClickOn(var/atom/A)
	if (A != src) return ..()
	if (last_chew + 26 > world.time) return

	var/mob/living/carbon/human/H = A
	if (!H.get_equipped_item(slot_handcuffed_str)) return
	if (H.a_intent != I_HURT) return
	if (H.zone_sel.selecting != BP_MOUTH) return
	if (H.get_equipped_item(slot_wear_mask_str)) return
	if (istype(H.get_equipped_item(slot_wear_suit_str), /obj/item/clothing/suit/straight_jacket)) return

	var/obj/item/organ/external/O = GET_EXTERNAL_ORGAN(H, H.get_active_held_item_slot())
	if (!O) return

	var/decl/pronouns/G = H.get_pronouns()
	H.visible_message( \
		SPAN_DANGER("\The [H] chews on [G.his] [O.name]"), \
		SPAN_DANGER("You chew on your [O.name]!"))
	admin_attacker_log(H, "chewed on their [O.name]!")

	O.take_external_damage(3,0, DAM_SHARP|DAM_EDGE ,"teeth marks")

	last_chew = world.time

////////////////////////////////////////////////////////////////
// Hancuffs - Cable Coils
////////////////////////////////////////////////////////////////
/obj/item/handcuffs/cable
	name = "cable restraints"
	desc = "Looks like some cables tied together. Could be used to tie something up."
	icon = 'icons/obj/items/handcuffs_cable.dmi'
	breakouttime = 30 SECONDS //Deciseconds = 30s
	cuff_sound = 'sound/weapons/cablecuff.ogg'
	cuff_type = "cable restraints"
	elastic = TRUE
	max_health = 75
	material = /decl/material/solid/plastic

/obj/item/handcuffs/cable/red
	color = COLOR_MAROON

/obj/item/handcuffs/cable/yellow
	color = COLOR_AMBER

/obj/item/handcuffs/cable/blue
	color = COLOR_CYAN_BLUE

/obj/item/handcuffs/cable/green
	color = COLOR_GREEN

/obj/item/handcuffs/cable/pink
	color = COLOR_PURPLE

/obj/item/handcuffs/cable/orange
	color = COLOR_ORANGE

/obj/item/handcuffs/cable/cyan
	color = COLOR_SKY_BLUE

/obj/item/handcuffs/cable/white
	color = COLOR_SILVER

/obj/item/handcuffs/cyborg
	dispenser = TRUE

////////////////////////////////////////////////////////////////
// Hancuffs - Tape Restraints
////////////////////////////////////////////////////////////////
/obj/item/handcuffs/cable/tape
	name = "tape restraints"
	desc = "DIY!"
	icon_state = "tape_cross"
	item_state = null
	icon = 'icons/obj/bureaucracy.dmi'
	breakouttime = 20 SECONDS
	cuff_type = "duct tape"
	max_health = 50
	material = /decl/material/solid/plastic