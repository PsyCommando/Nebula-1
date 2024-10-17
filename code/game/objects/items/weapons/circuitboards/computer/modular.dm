/obj/item/stock_parts/circuitboard/modular_computer
	name = "general-purpose computer motherboard"
	build_path = /obj/machinery/computer/modular
	req_components = list(
		/obj/item/stock_parts/computer/processor_unit = 1,
		/obj/item/stock_parts/console_screen = 1,
		/obj/item/stock_parts/keyboard = 1,
	)
	//This shouldn't add additional spawn components that some of the presets might want to add themselves in their uncreated_components list.
	// Otherwise the parts gets duplicated on init.
	var/emagged

/obj/item/stock_parts/circuitboard/modular_computer/emag_act(var/remaining_charges, var/mob/user)
	if(emagged)
		return ..()
	else
		emagged = TRUE
		to_chat(user, "<span class='warning'>You disable the factory safeties on \the [src].</span>")
