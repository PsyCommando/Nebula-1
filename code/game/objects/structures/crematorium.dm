/obj/machinery/crematorium
	name                      = "crematorium"
	desc                      = "A human incinerator. Works well on barbeque nights."
	icon                      = 'icons/obj/structures/crematorium.dmi'
	icon_state                = "crematorium_closed"
	density                   = TRUE
	anchored                  = TRUE
	waterproof                = FALSE
	active_power_usage        = 2.25 KILOWATTS
	uncreated_component_parts = list(
		/obj/item/stock_parts/power/apc/buildable,
		/obj/item/stock_parts/radio/receiver,
	)
	public_methods = list(
		/decl/public_access/public_method/crematorium_cremate,
	)
	stock_part_presets = list(
		/decl/stock_part_preset/radio/receiver/crematorium,
	)
	var/locked                = FALSE
	var/tmp/obj/structure/crematorium_tray/connected_tray
	var/static/list/forbidden_types = list(
		/obj/item/disk/nuclear,
	)
	var/atom/movable/currently_burning  //The thing currently being cremated on this tick
	var/time_done_burning     = 0       //The time when the current object is done burning

/obj/machinery/crematorium/Initialize(ml, _mat, _reinf_mat)
	. = ..()
	connected_tray = new /obj/structure/crematorium_tray(src)
	connected_tray.connected_crematorium = src

/obj/machinery/crematorium/Destroy()
	if(!QDELETED(connected_tray))
		QDEL_NULL(connected_tray)
	return ..()

/obj/machinery/crematorium/on_update_icon()
	if(is_open())
		icon_state = "crematorium_open"
	else if(use_power == POWER_USE_ACTIVE)
		icon_state = "crematorium_active"
	else if (contents.len > 1)
		icon_state = "crematorium_filled"
	else
		icon_state = "crematorium_closed"

/obj/machinery/crematorium/get_contained_external_atoms()
	. = ..()
	. -= connected_tray

/obj/machinery/crematorium/proc/is_open()
	return connected_tray.loc == src

/obj/machinery/crematorium/proc/open(mob/user)
	if(is_open())
		return
	
	var/turf/T = get_step(src, dir)
	if(user && (T.is_wall() || !T.CanPass(connected_tray,T)))
		to_chat(user, SPAN_WARNING("Something is in the way. You can't slide the tray open."))
		return

	connected_tray.forceMove(T)
	connected_tray.set_dir(dir)
	for(var/atom/movable/A in get_contained_external_atoms())
		A.dropInto(T)
	playsound(src, 'sound/items/Deconstruct.ogg', 50, 1)
	update_icon()
	return TRUE

/obj/machinery/crematorium/proc/close(mob/user)
	if(!is_open())
		return
	var/turf/T = get_turf(connected_tray)
	var/list/turf_contents = (T.contents - connected_tray)
	for(var/atom/movable/A in turf_contents)
		if(A.simulated && !A.anchored && !is_type_in_list(A, forbidden_types))
			A.forceMove(src)

	connected_tray.forceMove(src)
	playsound(src, 'sound/items/Deconstruct.ogg', 50, 1)
	update_icon()

	return TRUE

/obj/machinery/crematorium/physical_attack_hand(mob/user)
	if(locked)
		to_chat(user, SPAN_WARNING("\The [connected_tray] is locked shut."))
		return
	
	if(is_open())
		if(close(user))
			user.visible_message(SPAN_NOTICE("\The [user] slides \the [connected_tray] back in \the [src]."), SPAN_NOTICE("You slide \the [connected_tray] back into \the [src]."))
	else
		if(open(user))
			user.visible_message(SPAN_NOTICE("\The [user] slides out \the [connected_tray]."), SPAN_NOTICE("You slide out \the [connected_tray]."))
	return ..()

/obj/machinery/crematorium/attackby(obj/item/P, mob/user)
	if(istype(P, /obj/item/pen))
		var/new_label = sanitize_safe(input(user, "What would you like the label to be?", capitalize(name), null) as text|null, MAX_NAME_LEN)

		if((!Adjacent(user) || loc == user))
			return
		
		if(has_extension(src, /datum/extension/labels))
			var/datum/extension/labels/L = get_extension(src, /datum/extension/labels)
			if(!L.CanAttachLabel(user, new_label))
				return

		attach_label(user, P, new_label)
		return
	if(IS_CROWBAR(P) && (use_power == POWER_USE_ACTIVE) && !is_open())
		user.visible_message(SPAN_NOTICE("\The [user] is trying to pry open \the [src]'s tray."), SPAN_NOTICE("You attempt to pry open \the [src]'s tray."))
		if(do_mob(user, user, 5 SECONDS) && !QDELETED(user))
			user.visible_message(SPAN_NOTICE("\The [user] force open \the [src]'s tray!"), SPAN_NOTICE("You've forced open \the [src]'s tray!"))
			update_use_power(POWER_USE_IDLE)
			open(user)
		return 
	return ..()

/obj/machinery/crematorium/relaymove(mob/user)
	if(user.incapacitated())
		return
	if(locked)
		//Let the occupant attempt breaking out if its locked
		if(!prob(5))
			playsound(src, 'sound/effects/metalhit.ogg', 70, TRUE)
			to_chat(user, SPAN_NOTICE("You pound as hard as you can, but can't slide open \the [connected_tray]!"))
			user.audible_message("You hear pounding.") //Make sure only others hear it
			return
		else 
			visible_message(SPAN_NOTICE("\The [src]'s tray suddenly pop open!"))
			update_use_power(POWER_USE_IDLE) //Stop creamtion otherwise it won't open
	open(user)

/obj/machinery/crematorium/Process()
	if((stat & NOPOWER) || (stat & BROKEN) || (use_power != POWER_USE_ACTIVE))
		end_cremation()
		return PROCESS_KILL
	//Let cremation happen over several ticks
	do_cremate()

/**Called each ticks when cremating to burn down things over time. */
/obj/machinery/crematorium/proc/do_cremate()
	if(!currently_burning || (currently_burning.loc != src))
		var/atom/movable/AM
		var/has_candidates = FALSE
		for(AM in get_contained_external_atoms())
			if(!QDELETED(AM) && AM.is_burnable())
				has_candidates = TRUE
				break
		if(!AM || !has_candidates)
			end_cremation()
			return
		currently_burning = AM
		time_done_burning = (isliving(AM)? 30 SECONDS : 4 SECONDS) + REALTIMEOFDAY //Living things take longer

	if(isliving(currently_burning))
		var/mob/living/L = currently_burning

		//Godmode mobs stop everything. Cause there's no smart way to deal with that..
		if(L.status_flags & GODMODE)
			currently_burning = null
			end_cremation() 
			return

		//If they're not fully cremated yet, and they're conscious, let them scream and stuff
		if(REALTIMEOFDAY <= time_done_burning)
			if(L.stat != DEAD && L.stat != UNCONSCIOUS && prob(40))
				L.emote(pick("scream", "moan", "cough"))
				L.take_overall_damage(0, rand(1,5), "[src]") //Cause some minor burn damage while its going on, to seem actually threatning
				addtimer(CALLBACK(src, /obj/machinery/crematorium/proc/do_struggle_noises), 1 SECOND) //Do the knocking effects async
			return

		//Use death instead of dust, since dust waits before deleting the mob and plays an animation that nobody will ever see
		if(L.death(TRUE))
			if(round_is_spooky())
				playsound(src, pick('sound/effects/ghost.ogg', 'sound/effects/ghost2.ogg'), 10, 5)
			L.audible_message("[L]'s screams cease, as does any movement within the [src]. All that remains is a dull, empty silence.")

		if(L.ckey || L.last_ckey)
			admin_victim_log(L, "was cremated!")

		if(ishuman(L))
			var/obj/item/dirt = new /obj/item/remains/human(src)
			//Leave some evidences
			var/datum/extension/forensic_evidence/forensics = get_or_create_extension(dirt, /datum/extension/forensic_evidence)
			forensics.add_from_atom(/datum/forensics/trace_dna, L)
		else
			new /obj/effect/decal/cleanable/ash(src)

	else if(REALTIMEOFDAY <= time_done_burning)
		return //Skip until its time to burn for anything else. Also don't create ashes for anything else than mobs

	//Post-burning a thing
	currently_burning.dropInto()
	QDEL_NULL(currently_burning)

/**Emits knocking sounds and animate the machine, so it looks like someone is trying to break free. */
/obj/machinery/crematorium/proc/do_struggle_noises()
	var/pokesound = pick('sound/effects/bang.ogg', 'sound/effects/metalhit.ogg', 'sound/effects/magnetclamp.ogg')
	playsound(src, pokesound, 50, TRUE, 5)
	shake_animation(rand(1,5))
	sleep(5)
	playsound(src, pokesound, 50, TRUE, 5)

/**Begin the cremation process, if possible. And also play a sound. */
/obj/machinery/crematorium/proc/cremate(mob/user)
	if(inoperable() || (use_power == POWER_USE_ACTIVE) || is_open())
		return

	locked = TRUE
	update_use_power(POWER_USE_ACTIVE)
	playsound(src, 'sound/effects/flare.ogg', 90, FALSE)
	audible_message(SPAN_WARNING("You hear a roar as the [src] activates."))
	START_PROCESSING_MACHINE(src, MACHINERY_PROCESS_SELF)
	update_icon()

/**End the cremation state, unlocks the tray, and play a sound effect if neccessary. */
/obj/machinery/crematorium/proc/end_cremation()
	if(use_power == POWER_USE_ACTIVE)
		playsound(src, 'sound/effects/air_release.ogg', 50, 1)
		update_use_power(POWER_USE_IDLE)
		update_icon()
	locked = FALSE
	
/decl/public_access/public_method/crematorium_cremate
	name = "cremate"
	desc = "Ignite the crematorium."
	call_proc = /obj/machinery/crematorium/proc/cremate

/decl/stock_part_preset/radio/receiver/crematorium
	frequency = BUTTON_FREQ
	receive_and_call = list("button_active" = /decl/public_access/public_method/crematorium_cremate)

////////////////////////////////////////////////
// Crematorium Tray
////////////////////////////////////////////////
/obj/structure/crematorium_tray
	name       = "crematorium tray"
	desc       = "Apply body before burning."
	icon       = 'icons/obj/structures/crematorium.dmi'
	icon_state = "crematorium_tray"
	density    = TRUE
	anchored   = TRUE
	throwpass  = TRUE
	layer      = BELOW_OBJ_LAYER
	tool_interaction_flags = 0

	var/obj/machinery/crematorium/connected_crematorium

/obj/structure/crematorium_tray/Destroy()
	if(!QDELETED(connected_crematorium))
		QDEL_NULL(connected_crematorium)
	return ..()

/obj/structure/crematorium_tray/attack_hand(mob/user)
	if(Adjacent(user))
		connected_crematorium.attack_hand(user)
	return ..()

/obj/structure/crematorium_tray/receive_mouse_drop(atom/dropping, mob/user)
	. = ..()
	if(!. && (ismob(dropping) || istype(dropping, /obj/structure/closet/body_bag)))
		var/atom/movable/AM = dropping
		if(!AM.anchored)
			AM.forceMove(loc)
			if(user != dropping)
				user.visible_message(SPAN_NOTICE("\The [user] stuffs \the [dropping] onto \the [src]!"))
			return TRUE

//Don't let it be destroyed this way, it would be reaaally bad
/obj/structure/crematorium_tray/physically_destroyed(skip_qdel)
	SHOULD_CALL_PARENT(FALSE)
	return

////////////////////////////////////////////////
// Crematorium Button
////////////////////////////////////////////////
/obj/machinery/button/crematorium
	name = "crematorium igniter"
	desc = "Burn baby burn!"
	icon = 'icons/obj/power.dmi'
	icon_state = "crematorium_switch"
	initial_access = list(access_crematorium)

/obj/machinery/button/crematorium/on_update_icon()
	return
