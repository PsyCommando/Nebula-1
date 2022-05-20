
//
// Solar Assembly - For construction of solar arrays.
//
/obj/item/solar_assembly
	name       = "solar panel assembly"
	desc       = "A solar panel assembly kit, allows constructions of a solar panel."
	icon       = 'icons/obj/power.dmi'
	icon_state = "sp_base"
	item_state = "electropack"
	w_class    = ITEM_SIZE_HUGE // Pretty big!
	anchored   = FALSE
	material   = /decl/material/solid/metal/aluminium

/obj/item/solar_assembly/attack_self(mob/user)
	. = ..()
	var/turf/T = get_turf(src)
	if(!T)
		return
	if(T.is_wall())
		to_chat(user, SPAN_WARNING("You cannot place \the [src] on walls."))
		return
	if(!T.is_plating())
		to_chat(user, SPAN_WARNING("You must place \the [src] on plating."))
		return

	visible_message(SPAN_NOTICE("\The [usr] installs \the [src]."))
	playsound(src.loc, 'sound/items/Deconstruct.ogg', 75, 1)
	new /obj/machinery/power/solar(T)
	user.drop_from_inventory(src)
	qdel(src)
