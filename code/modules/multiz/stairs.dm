/obj/structure/stairs
	name                   = "stairs"
	desc                   = "Stairs leading to another deck. Not too useful if the gravity goes out."
	icon                   = 'icons/obj/stairs.dmi'
	density                = FALSE
	opacity                = FALSE
	anchored               = TRUE
	layer                  = RUNE_LAYER
	material               = /decl/material/solid/metal/steel
	tool_interaction_flags = TOOL_INTERACTION_DECONSTRUCT
	parts_amount           = 1
	parts_type             = /obj/item/structure_kit/stairs
	var/stair_length       = WORLD_ICON_SIZE //Length of the stairs icon in pixels
	var/stair_width        = WORLD_ICON_SIZE //Width of the stairs icon in pixels

/obj/structure/stairs/Initialize(var/ml)
	for(var/turf/turf in locs)
		var/turf/above = GetAbove(turf)
		if(!istype(above))
			warning("Stair created without level above: ([loc.x], [loc.y], [loc.z])")
			return INITIALIZE_HINT_QDEL
		if(!above.is_open() && ml) //Only do that on map load plz
			above.ChangeTurf(/turf/simulated/open)
	. = ..()

/obj/structure/stairs/on_update_icon()
	. = ..()

	//Reset all to default
	bound_width  = initial(bound_width) //Bound is one tile per default
	bound_height = initial(bound_height)
	bound_x      = initial(bound_x)
	bound_y      = initial(bound_x)
	pixel_x      = initial(pixel_x)
	pixel_y      = initial(pixel_y)

	//Then tweak depending on direction
	switch(dir)
		if(NORTH)
			bound_width  = stair_width
			bound_height = stair_length
			//Offset it, so the lower corner left of the icon aligns with the lower left corner of the object bounds
			bound_y = -1 * (bound_height - WORLD_ICON_SIZE)
			pixel_y = -1 * (bound_height - WORLD_ICON_SIZE)

		if(SOUTH)
			bound_width  = stair_width
			bound_height = stair_length

		if(EAST)
			bound_width  = stair_length
			bound_height = stair_width
			//Offset it, so the lower corner left of the icon aligns with the lower left corner of the object bounds
			bound_x = -1 * (bound_width - WORLD_ICON_SIZE)
			pixel_x = -1 * (bound_width - WORLD_ICON_SIZE)

		if(WEST)
			bound_width  = stair_length
			bound_height = stair_width

/obj/structure/stairs/CheckExit(atom/movable/mover, turf/target)
	if((get_dir(loc, target) == dir) && (get_turf(mover) == loc))
		return FALSE
	return ..()

/obj/structure/stairs/Bumped(atom/movable/A)
	var/turf/target = get_step(GetAbove(A), dir)
	var/turf/source = get_turf(A)
	var/turf/above = GetAbove(A)
	if(above.CanZPass(source, UP) && target.Enter(A, src))
		A.forceMove(target)
		if(isliving(A))
			var/mob/living/L = A
			for(var/obj/item/grab/G in L.get_active_grabs())
				G.affecting.forceMove(target)
		if(ishuman(A))
			var/mob/living/carbon/human/H = A
			if(H.has_footsteps())
				playsound(source, 'sound/effects/stairs_step.ogg', 50)
				playsound(target, 'sound/effects/stairs_step.ogg', 50)
	else
		to_chat(A, SPAN_WARNING("Something blocks the path."))

/obj/structure/stairs/CanPass(obj/mover, turf/source, height, airflow)
	return airflow || !density

// type paths to make mapping easier.

/obj/structure/stairs/long
	icon = 'icons/obj/stairs_64.dmi'
	stair_length = 64

/obj/structure/stairs/long/north
	dir = NORTH

/obj/structure/stairs/long/east
	dir = EAST

/obj/structure/stairs/long/west
	dir = WEST
