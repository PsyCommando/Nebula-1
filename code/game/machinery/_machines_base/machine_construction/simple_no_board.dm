/**
 * State for things that are built from a starting frame, have no panel to open, require some components installed, and don't need a board.
  */
/decl/machine_construction/simple
	needs_board        = null
	visible_components = TRUE
	locked             = FALSE
	var/up_state
	var/down_state
	var/dismantled_state = /decl/machine_construction/simple/disassembled

/decl/machine_construction/simple/attackby(obj/item/I, mob/user, obj/machinery/machine)
	//We let the machine components handle attackby themselves
	if((. = ..()))
		return

	if(isWrench(I))
		return machine.part_removal(user)

	if(istype(I, /obj/item/stock_parts))
		return machine.part_insertion(user, I)

	if(istype(I, /obj/item/storage/part_replacer))
		return machine.part_replacement(user, I)

	if(isCrowbar(I))
		TRANSFER_STATE(dismantled_state)
		playsound(get_turf(machine), 'sound/items/Crowbar.ogg', 50, 1)
		to_chat(user, "You pry \the [machine] off \the [get_turf(src)]!")
		machine.dismantle()
		return

/decl/machine_construction/simple/mechanics_info()
	. = list()
	. += "Use a parts replacer to upgrade some parts."
	. += "Insert a new part to install it."
	. += "Remove installed parts with a wrench and/or wirecutters."
	. += "Use a crowbar to pry the frame off the floor."

/**
 * Fully functional state
 */
/decl/machine_construction/simple/assembled
	down_state = /decl/machine_construction/simple/waiting_component

/decl/machine_construction/simple/assembled/state_is_valid(obj/machinery/machine)
	return machine.anchored && (LAZYLEN(machine.missing_parts()) == 0)
	
/decl/machine_construction/simple/assembled/post_construct(obj/machinery/machine)
	if(LAZYLEN(machine.missing_parts()) > 0)
		try_change_state(machine, down_state) //We're missing parts so consider us not fully assembled
	machine.queue_icon_update()

/decl/machine_construction/simple/assembled/validate_state(obj/machinery/machine)
	. = ..()
	if(!.)
		try_change_state(machine, down_state)

/**
 * Machine still waiting for components. Non-functional.
 */
/decl/machine_construction/simple/waiting_component
	up_state   = /decl/machine_construction/simple/assembled
	down_state = /decl/machine_construction/simple/disassembled

/decl/machine_construction/simple/waiting_component/state_is_valid(obj/machinery/machine)
	return machine.anchored && (LAZYLEN(machine.missing_parts()) > 0)

/decl/machine_construction/simple/waiting_component/post_construct(obj/machinery/machine)
	if(LAZYLEN(machine.missing_parts()) == 0)
		try_change_state(machine, up_state) //We're missing parts so consider us not fully assembled
	machine.queue_icon_update()

/decl/machine_construction/simple/waiting_component/validate_state(obj/machinery/machine)
	. = ..()
	if(!.)
		try_change_state(machine, up_state)

/**
 * Stub disassembled state
 */
/decl/machine_construction/simple/disassembled

