/obj/effect/decal
	layer = DECAL_LAYER

/obj/effect/decal/fall_damage()
	return 0

/obj/effect/decal/is_burnable()
	return TRUE

/obj/effect/decal/lava_act(datum/gas_mixture/air, temperature, pressure)
	. = !throwing ? ..() : FALSE
