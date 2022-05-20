/datum/fabricator_recipe/engineering/solar_cell
	path = /obj/item/stock_parts/solar_cell

/obj/item/stock_parts/solar_cell
	name        = "solar cell"
	desc        = "Used in the construction of solar panels and sensors."
	icon_state  = "solar_cell"
	origin_tech = "{'materials':2}"
	material    = /decl/material/solid/fiberglass
	base_type   = /obj/item/stock_parts/solar_cell
	health      = 20
	rating      = 1

/obj/item/stock_parts/solar_cell/on_fail(obj/machinery/machine, damtype)
	. = ..()
	playsound(src, "shatter", 10, 1)
