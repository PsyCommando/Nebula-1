/datum/fabricator_recipe/engineering/tracker_electronics
	path = /obj/item/stock_parts/circuitboard/tracker_electronics

// Tracker Electronic
/obj/item/stock_parts/circuitboard/tracker_electronics
	name           = "stellar tracker electronics"
	board_type     = "door" //As per tradition, it has the door icon
	build_path     = /obj/machinery/power/tracker
	req_components = list(
		/obj/item/stock_parts/solar_cell = 4,
	)

//Solar tracker
/**
 * Machine that tracks the sun and reports it's direction to itself.
 * Transmit angle updates only when the /datum/sun actually updates.
 */
/obj/machinery/power/tracker
	name             = "stellar tracker"
	desc             = "A star tracking device."
	icon             = 'icons/obj/power.dmi'
	icon_state       = "tracker"
	anchored         = TRUE
	density          = TRUE
	waterproof       = TRUE
	stat_immune      = NOSCREEN | NOINPUT | NOPOWER
	construct_state  = /decl/machine_construction/default/panel_closed 
	uncreated_component_parts = list(
		/obj/item/stock_parts/shielding/frame         = 1,
		/obj/item/stock_parts/radio/transmitter/basic = 1,
		/obj/item/stock_parts/power/terminal          = 1,
	)
	public_variables = list(
		/decl/public_access/public_variable/sun_angle,
	)
	stock_part_presets = list(
		/decl/stock_part_preset/terminal_setup                        = 1,
		/decl/stock_part_preset/radio/basic_transmitter/solar_tracker = 1,
		/decl/stock_part_preset/radio/receiver/solar_tracker          = 1,
	)
	var/last_sun_angle = 0 //Needed due to how vars are only transmitted on change

/obj/machinery/power/tracker/Initialize()
	. = ..()
	if(global.sun)
		events_repository.register(/decl/observ/sun_position_changed, global.sun, src, .proc/on_sun_position_changed)

/obj/machinery/power/tracker/Destroy()
	if(global.sun)
		events_repository.unregister(/decl/observ/sun_position_changed, global.sun, src, .proc/on_sun_position_changed)
	return ..()
	
/obj/machinery/power/tracker/proc/on_sun_position_changed(var/angle)
	if(stat & BROKEN || !powernet || !global.sun)
		return

	var/decl/public_access/public_variable/variable = GET_DECL(/decl/public_access/public_variable/sun_angle)
	variable.write_var(src, angle)

	//set icon dir to show sun illumination
	set_dir(turn(NORTH, -angle) - 22.5)	// 22.5 deg bias ensures, e.g. 67.5-112.5 is EAST
	queue_icon_update()

/obj/machinery/power/tracker/proc/solar_tracker_report_connected(var/obj/machinery/machine)
	if(!istype(machine))
		return
	//Grab the wired  powernet, not the wireless one
	var/obj/item/stock_parts/power/terminal/term = machine.get_component_of_type(/obj/item/stock_parts/power/terminal)
	if(!(term?.terminal) || (term.terminal.powernet != powernet))
		return
	
	var/obj/item/stock_parts/radio/transmitter/T = get_component_of_type(/obj/item/stock_parts/radio/transmitter)
	if(!istype(T))
		return
	T.queue_transmit(list("ACK" = src)) //Have to reply, so that the controller can tally up what's connected to it

///////////////////////////////////////////////
// Variables
///////////////////////////////////////////////
/decl/public_access/public_variable/sun_angle
	name          = "sun angle"
	desc          = "The angle of the nearest star from the tracker."
	can_write     = TRUE
	has_updates   = TRUE
	var_type      = IC_FORMAT_NUMBER
	expected_type = /obj/machinery/power/tracker

/decl/public_access/public_variable/sun_angle/access_var(obj/machinery/power/tracker/tracker)
	return last_sun_angle

/decl/public_access/public_variable/sun_angle/write_var(obj/machinery/power/tracker/tracker, new_value)
	. = ..()
	if(.)
		last_sun_angle = new_value

/decl/public_access/public_method/solar_tracker_report_connected
	name = "acknowledged"
	desc = "Called with the machine's reference when it acknowledges its connected to us."
	call_proc = /obj/machinery/power/tracker/proc/solar_tracker_report_connected

///////////////////////////////////////////////
// Presets
///////////////////////////////////////////////
/decl/stock_part_preset/radio/basic_transmitter/solar_tracker
	frequency = SOLARS_FREQ
	transmit_on_change = list(
		"set_tracker_sun_angle" = /decl/public_access/public_variable/sun_angle,
	)

/decl/stock_part_preset/radio/receiver/solar_tracker
	frequency = SOLARS_FREQ
	receive_and_call = list(
		"assuming_direct_control" = /decl/public_access/public_method/solar_tracker_report_connected,
	)