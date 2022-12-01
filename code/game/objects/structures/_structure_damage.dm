/obj/structure/take_damage(amount, damage_type = BRUTE, damage_flags = 0, inflicter = null, armor_pen = 0, target_zone = null, quiet = FALSE)
	if(material && material.is_brittle())
		if(!reinf_material)
			amount *= STRUCTURE_BRITTLE_MATERIAL_DAMAGE_MULTIPLIER
		else if(reinf_material.is_brittle())
			amount *= STRUCTURE_BRITTLE_MATERIAL_DAMAGE_MULTIPLIER

	. = ..(amount, damage_type, damage_flags, inflicter, armor_pen, target_zone, quiet)

	if(. > 0 && !quiet)
		show_damage_message(health / max_health)

//#TODO: Might need to eventually handle evironment smash as an attack instead of as a boolean check

/obj/structure/proc/show_damage_message(var/perc)
	if(perc > 0.75)
		return
	if(perc <= 0.25 && last_damage_message < 0.25)
		visible_message(SPAN_DANGER("\The [src] looks like it's about to break!"))
		last_damage_message = 0.25
	else if(perc <= 0.5 && last_damage_message < 0.5)
		visible_message(SPAN_WARNING("\The [src] looks seriously damaged!"))
		last_damage_message = 0.5
	else if(perc <= 0.75 && last_damage_message < 0.75)
		visible_message(SPAN_WARNING("\The [src] is showing some damage!"))
		last_damage_message = 0.75

/obj/structure/physically_destroyed(var/skip_qdel)
	if(..(TRUE))
		return dismantle() //#FIXME: This might not be generic enough?
///Whether the structure can be repaired. Also tells the user the reason it cannot be.
/obj/structure/proc/can_repair(var/mob/user)
	if(health >= max_health)
		if(user)
			to_chat(user, SPAN_NOTICE("\The [src] does not need repairs."))
		return FALSE
	return TRUE

/obj/structure/proc/can_repair_with(var/obj/item/tool)
	. = istype(tool, /obj/item/stack/material) && tool.get_material_type() == get_material_type()

/obj/structure/proc/handle_repair(mob/user, obj/item/tool)
	var/obj/item/stack/stack = tool
	var/amount_needed = CEILING((max_health - health)/DOOR_REPAIR_AMOUNT)
	var/used = min(amount_needed, stack.amount)
	if(used)
		to_chat(user, SPAN_NOTICE("You fit [used] [stack.singular_name]\s to damaged areas of \the [src]."))
		stack.use(used)
		last_damage_message = null
		heal(used * DOOR_REPAIR_AMOUNT)
