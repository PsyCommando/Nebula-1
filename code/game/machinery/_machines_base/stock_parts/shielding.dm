
//Components that soak damage before it reaches other components.
/obj/item/stock_parts/shielding
	base_type = /obj/item/stock_parts/shielding
	material_health_multiplier = 0.4
	var/list/protection_types	//types of damage it will soak

/obj/item/stock_parts/shielding/electric
	name = "fuse box"
	icon_state = "fusebox"
	desc = "A bloc of multi-use fuses, protecting the machine against the electrical current spikes."
	protection_types = list(ELECTROCUTE)
	material = /decl/material/solid/metal/steel
	matter = list(/decl/material/solid/fiberglass = MATTER_AMOUNT_REINFORCEMENT)

/obj/item/stock_parts/shielding/kinetic
	name = "internal armor"
	icon_state = "armor"
	desc = "Kinetic resistant armor plates to line the machine with."
	protection_types = list(BRUTE)
	material = /decl/material/solid/metal/steel

/obj/item/stock_parts/shielding/heat
	name = "heatsink"
	icon_state = "heatsink"
	desc = "Active cooling system protecting machinery against the high temperatures."
	protection_types = list(BURN)
	material = /decl/material/solid/metal/steel
	matter = list(/decl/material/solid/metal/aluminium = MATTER_AMOUNT_REINFORCEMENT)

/obj/item/stock_parts/shielding/frame
	name             = "frame"
	desc             = "The frame holding the machine together."
	protection_types = list(BRUTE, BURN)
	part_flags       = PART_FLAG_QDEL //No remove ever
	material_health_multiplier = 0.2 //Wish you could scale per damage type, to set basic electrocute resistance...

//The part takes on the material of the machine's frame
/obj/item/stock_parts/shielding/frame/on_install(obj/machinery/machine)
	. = ..()
	if(!machine.frame_type)
		return
	var/list/frmmat = atom_info_repository.get_matter_for(machine.frame_type)
	var/decl/material/M = GET_DECL(frmmat[1])
	if(M)
		set_material(M)
