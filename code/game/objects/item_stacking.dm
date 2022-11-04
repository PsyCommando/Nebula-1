/*
	Handling for allowing some object types to stack several instances of the same type in a mob's hands.
*/

///Temporary object meant to contain the contained objects
/obj/item/stackable_holder
	name              = "stack"
	item_flags        = ITEM_FLAG_NO_BLUDGEON
	w_class           = ITEM_SIZE_NO_CONTAINER
	max_health        = ITEM_HEALTH_NO_DAMAGE
	is_spawnable_type = FALSE
	pickup_sound      = null
	drop_sound        = null
	randpixel         = 0

	///Current maximum amount of things we can contain
	var/max_amount = 1
	///Current base type of items we accept
	var/expected_type = /obj/item //By default any items

/obj/item/stackable_holder/examine(mob/user, distance, infix, suffix)
	SHOULD_CALL_PARENT(FALSE)
	var/obj/item/I = get_first_item()
	if(!I)
		return
	to_chat(user, SPAN_INFO("There are [get_amount()] [I] in the [initial(name)]."))
	I.examine(user, distance, infix, suffix)

/obj/item/stackable_holder/dropped(mob/user)
	SHOULD_CALL_PARENT(FALSE)
	break_in_place()

//Handle retrieving something with our stack
/obj/item/stackable_holder/attack_hand(mob/user)
	if(loc == user)
		//Grab one of the things if in hands
		return take_thing(user)
	else
		return ..() //Handles pickup and etc

//Handle trying to place something into our stack.
/obj/item/stackable_holder/attackby(obj/item/W, mob/user)
	if(istype(W, type) && try_merge_with(W, user))
		return TRUE

	if(istype(W, expected_type) && (get_amount() < max_amount) && put_thing(W, user))
		return TRUE

/obj/item/stackable_holder/resolve_attackby(atom/A, mob/user, click_params)
	//If we can slap that on, go ahead
	if(istype(A, expected_type) && put_thing(A, user))
		return TRUE

	//Use the first item in the stack on whatever we're attacking. 
	var/obj/item/I = get_first_item()
	var/resolved = I.resolve_attackby(A, user, click_params)
	if(!resolved && !QDELETED(A) && !QDELETED(I))
		I.afterattack(A, user, TRUE, click_params)
	//It might have moved the item out of the stack, so do an update
	if(!QDELETED(src))
		update_state()


//Handle hitting something with our stack
// /obj/item/stackable_holder/afterattack(atom/target, mob/user, proximity_flag, click_parameters)
// 	if(!CanPhysicallyInteract(user) || !proximity_flag)
// 		return
// 	//Let the first 
// 	var/obj/item/I = get_first_item()
// 	. = I.afterattack(target, user, proximity_flag, click_parameters)
// 	//It might have moved the item out of the stack, so do an update
// 	if(!QDELETED(src))
// 		update_state()

/obj/item/stackable_holder/receive_mouse_drop(obj/item/dropping, mob/living/user)
	if(!user.Adjacent(dropping) && (dropping.loc != user))
		return
	if(istype(dropping, expected_type))
		return put_thing(dropping, user)
	else if(istype(dropping, type))
		return try_merge_with(dropping, user)
	return

//Mouse drop picks a single item and let it interact
/obj/item/stackable_holder/handle_mouse_drop(atom/over, mob/user)
	var/obj/item/I = get_first_item()
	if(I)
		. = I.handle_mouse_drop(over, user)
		//It might have moved the item out of the stack, so do an update
		if(!QDELETED(src))
			update_state()

///Handles the stack's contents being dropped in whatever appendage we're in.
/obj/item/stackable_holder/proc/break_in_place()
	if(ismob(loc))
		var/mob/holder = loc
		holder.unEquip(src, null) //Has to be removed from the hand first, so we can replace it with its contents
		//Normally we should only ever drop the last item we got this way. When there's one item left in the stack we're holding
		for(var/obj/item/I in contents)
			holder.put_in_active_hand(I)
	else 
		dump_contents()
	log_debug("[src] was deleted")
	qdel(src)
	return TRUE

///Attempt to remove an item from the stack. Returns the removed item.
/obj/item/stackable_holder/proc/take_thing(var/mob/user)
	var/len_contents = length(contents)
	if(len_contents <= 0)
		log_warning("[src] ([type]) was empty when used by mob '[user]'.")
		return 
	if(len_contents == 1)
		log_warning("[src] ([type]) had a single item in it when take_thing was called!. It should have been destroyed prior!")
		return
	
	var/obj/item/I = get_last_item()
	. = I
	if(user)
		user.put_in_active_hand(I)
		to_chat(user, SPAN_NOTICE("You take \the [I] from \the [src]."))
	else
		I.dropInto(get_turf(src))
	log_debug("removed [I] from [src]")
	update_state()

///Attempt to insert an item into the stack.
/obj/item/stackable_holder/proc/put_thing(var/obj/item/I, var/mob/user, var/skip_update_icon)
	var/len_contents = length(contents)
	if(len_contents >= max_amount)
		if(user)
			to_chat(user, SPAN_WARNING("Your hand is full!")) //#TODO: Find an easy way to change "hand" for whatever the critter uses.
		return
	if(istype(I, type))
		return try_merge_with(I, user)
	if(len_contents >= 1) //Accept anything when empty
		var/obj/item/thing = get_first_item()
		if(!thing.can_stack_with(I))
			return

	if(ismob(I.loc))
		var/mob/other = I.loc
		if(!other.unEquip(I, src))
			return
	else 
		I.forceMove(src)
	I.transfer_fingerprints_to(src)
	//If we're the first thing in, do additional setup
	if(len_contents == 0)
		expected_type = I.get_stackable_type()
		I.w_class = I.w_class
		update_max_amount()
	if(user)
		to_chat(user, SPAN_NOTICE("You add \the [I] to \the [src]."))
	log_debug("inserted [I] into [src]")
	update_state(TRUE, skip_update_icon) //No deleted on insert
	return TRUE

///Merge the stack in the arguments into this stack.
/obj/item/stackable_holder/proc/try_merge_with(var/obj/item/stackable_holder/S, var/mob/user)
	if(!ispath(S.expected_type, expected_type))
		if(user)
			to_chat(user, SPAN_WARNING("You can't mix together items of these types!"))
		return FALSE
	
	var/len_contents = length(contents)
	if((len_contents >= max_amount))
		if(user)
			to_chat(user, SPAN_WARNING("There's not enough room to add those!"))
		return FALSE

	//Merge as many as possible
	for(var/obj/item/O in S.contents)
		if(!put_thing(O))
			break
		
	S.update_state()

///Runs all the checks and updates that should be done after we add/remove an item from the stack.
/obj/item/stackable_holder/proc/update_state(var/skip_qdel, var/skip_icon)
	if(!skip_qdel)
		update_existence()
	if(QDELETED(src))
		return
	update_name()
	update_max_amount()
	if(!skip_icon)
		update_icon()
		update_held_icon()

///Checks and breaks the stack if it's empty or if there's only one item left.
/obj/item/stackable_holder/proc/update_existence()
	//If we're empty, or if there's only one item left, we break the stack.
	if(length(contents) <= 1)
		break_in_place()

///Updates the name depending on what's in it.
/obj/item/stackable_holder/proc/update_name()
	var/obj/item/I = get_first_item()
	if(I)
		SetName("[I] stack")

///Make sure the maximum amount stays up to date.
/obj/item/stackable_holder/proc/update_max_amount()
	var/len_contents = length(contents)
	if(len_contents < 1)
		max_amount = initial(max_amount)
		return
	var/obj/item/I = get_first_item()
	if(!istype(I))
		CRASH("Got bad contained item type for stackable_holder!")
	max_amount = max(I.can_stack_at_most(), len_contents)

/obj/item/stackable_holder/on_update_icon()
	SHOULD_CALL_PARENT(FALSE) //Don't do blood overlays and etc, since we're not a real item
	cut_overlays()
	var/cur_x = -16
	var/cur_y = 8
	var/image/new_icon = image(null)
	for(var/obj/item/I in contents)
		I.plane = HUD_PLANE //Won't generate the right icon otherwise
		I.reconsider_single_icon(TRUE)
		var/mutable_appearance/M = new(I)
		M.plane = FLOAT_PLANE
		//M.transform = matrix(0.8,0,0,0,0.8,0) //Make a bit smaller
		//If we ever go off limit pile them up 
		if(cur_x >= 16)
			cur_x = -16
		if(cur_y <= 0)
			cur_y = 8
		M.pixel_x = cur_x++
		M.pixel_y = cur_y--
		M.appearance_flags = RESET_ALPHA | RESET_COLOR
		new_icon.overlays += M
	new_icon.plane = FLOAT_PLANE
	//Align it to be centered on a 32x32 sprite
	new_icon.pixel_x = 8
	new_icon.pixel_y = -8
	add_overlay(new_icon)

///Returns the first item in the stack
/obj/item/stackable_holder/proc/get_first_item()
	return length(contents) ? contents[1] : null

///Returns the last item in the stack
/obj/item/stackable_holder/proc/get_last_item()
	return length(contents) ? contents[contents.len] : null

/obj/item/stackable_holder/proc/get_amount()
	return length(contents)

//
//
//
/obj/item/stackable_holder/get_alt_interactions(mob/user)
	. = ..()
	LAZYADD(., /decl/interaction_handler/stackable_holder_split)

/decl/interaction_handler/stackable_holder_split
	name = "Split Stack"
	expected_target_type = /obj/item/stackable_holder

/decl/interaction_handler/stackable_holder_split/is_possible(obj/item/stackable_holder/target, mob/user, obj/item/prop)
	return ..() && user.get_empty_hand_slot()

/decl/interaction_handler/stackable_holder_split/invoked(obj/item/stackable_holder/target, mob/user)
	var/amount_to_split = round(target.get_amount() / 2)
	var/obj/item/stackable_holder/newstack = new
	for(var/i = target.get_amount(); i < amount_to_split; i--)
		var/obj/item/I = target.contents[i]
		target.put_thing(I, null, TRUE)
	
	//Put in hands, then do update to ensure we got a coherent state
	user.put_in_hands(newstack)
	newstack.update_state()
	target.update_state()
	return TRUE
	

//
//
//

///Create a new stack in place from the stackable type if possible.
/obj/item/proc/create_stack_with(var/obj/item/I, var/mob/user)
	if(istype(I.loc, get_stack_type()) || istype(loc, get_stack_type()))
		return //never create a stack when one of them is in one already
	if(can_stack_with(I) && get_stack_type() && user.canUnEquip(src) && ((I.loc != user) || (I.loc == user && user.canUnEquip(I))))
		log_debug("creating stack!")
		var/stackable_type = get_stack_type()
		var/obj/item/stackable_holder/H = new stackable_type
		user.unEquip(src)
		user.put_in_active_hand(H)
		H.put_thing(src, skip_update_icon = TRUE)
		H.put_thing(I)
		to_chat(user, SPAN_NOTICE("You add \the [I] to \the [H]."))
		. = H
	return .

//Allow stacking stuff that doesn't do anything special during attackby and afterattack
/obj/item/afterattack(atom/target, mob/user, proximity_flag, click_parameters)
	if((. = ..()))
		return .
	//After attack check if whatever this is can stack
	return create_stack_with(target, user)

///Returns whether the item can be stacked with items of the given kind, that have the same stackable amount and w_class.
/obj/item/proc/can_stack_with(var/obj/item/I)
	return (get_stackable_type() == I.type) && (can_stack_at_most() == I.can_stack_at_most()) && (w_class == I.w_class)

///Returns the amount of things of this type that can be stacked together.
/obj/item/proc/can_stack_at_most()
	return ITEM_SIZE_MAX/w_class

///Returns what item types we can be stacked with.
/obj/item/proc/get_stackable_type()
	return type

///Returns the type of stack this item can be stacked into. Null means no stacking.
/obj/item/proc/get_stack_type()
	return


//
// TEST
//
/obj/item/ammo_casing/get_stack_type()
	return /obj/item/stackable_holder

/decl/hierarchy/outfit/job/engineering/chief_engineer
	backpack_contents = list(
		/obj/item/ammo_magazine/box/smallpistol = 1,
	)