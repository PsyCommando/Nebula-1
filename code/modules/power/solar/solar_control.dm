#define SOLAR_CONTROL_TRACKING_OFF   0 //No auto tracking, no timed tracking
#define SOLAR_CONTROL_TRACKING_TIMED 1 //Timed tracking only
#define SOLAR_CONTROL_TRACKING_AUTO  2 //Automated tracking using tracker

/obj/item/stock_parts/circuitboard/solar_control
	name        = "circuitboard (solar control console)"
	board_type  = "computer"
	build_path  = /obj/machinery/computer/solar_control
	origin_tech = "{'programming':2,'powerstorage':2}"

/**
 * Solar Control Computer
*/
/obj/machinery/computer/solar_control
	name               = "solar panel console"
	desc               = "A controller for solar panel arrays."
	icon_keyboard      = "power_key"
	icon_screen        = "solar_screen"
	light_color        = "#C6B227"
	use_power          = POWER_USE_IDLE
	idle_power_usage   = 0.25 KILOWATTS
	active_power_usage = 0.25 KILOWATTS
	base_type          = /obj/machinery/computer/solar_control
	frame_type         = /obj/machinery/constructable_frame/computerframe
	uncreated_component_parts = list(
		/obj/item/stock_parts/shielding/frame         = 1,
		/obj/item/stock_parts/power/terminal          = 1, //For controlling solars on the network
		/obj/item/stock_parts/radio/receiver          = 1,
		/obj/item/stock_parts/radio/transmitter/basic = 1,
		/obj/item/stock_parts/power/apc               = 1, //Aux power sources
		/obj/item/stock_parts/power/battery           = 1, //Aux power sources
	)
	stock_part_presets = list(
		/decl/stock_part_preset/terminal_setup                        = 1,
		/decl/stock_part_preset/radio/receiver/solar_control          = 1,
		/decl/stock_part_preset/radio/basic_transmitter/solar_control = 1,
	)
	public_methods = list(
		/decl/public_access/public_method/solar_control_ack,
		/decl/public_access/public_method/solar_control_rem,
	)
	public_variables = list(
		/decl/public_access/public_variable/solar_control_requested_angle,
	)

	var/current_angle     = 0                           //The angle the controller is asking solar panels to be facing
	var/target_angle      = 0                           // target angle in manual tracking (since it updates every game minute)
	var/gen               = 0                           //Power generated this tick
	var/lastgen           = 0                           //Power generated last tick
	var/track_mode        = SOLAR_CONTROL_TRACKING_OFF  // 0= off  1=timed  2=auto (tracker)
	var/track_rate        = 60 SECONDS                  //Delay between tracking updates
	var/next_timed_update = 0                           // time for a panel to rotate of 1° in manual tracking
	var/nb_panels         = 0                           //Panels that answered the last roll call
	var/has_tracker       = 0                           //Whether a tracker answered the last roll call. 

// Used for mapping in solar array which automatically starts itself (telecomms, for example)
/obj/machinery/computer/solar_control/autostart
	track_mode = SOLAR_CONTROL_TRACKING_AUTO

/obj/machinery/computer/solar_control/drain_power()
	return -1

//search for unconnected panels and trackers in the computer powernet and connect them
/obj/machinery/computer/solar_control/proc/search_for_connected()
	nb_panels = 0
	var/obj/item/stock_parts/power/terminal/term = get_component_of_type(/obj/item/stock_parts/power/terminal)
	if(!term?.terminal)
		return
	//Set our id tag to our current power net so we're visible to other solar devices on the powernet
	id_tag = "\ref[term.terminal.powernet]"

	var/obj/item/stock_parts/radio/transmitter/trans = get_component_of_type(/obj/item/stock_parts/radio/transmitter)
	if(!trans)
		return
	//Tell the other solar machines on the network we're taking control
	trans.queue_transmit(list("assuming_direct_control" = src))

/obj/machinery/computer/solar_control/interface_interact(mob/user)
	ui_interact(user)
	return TRUE

/obj/machinery/computer/solar_control/ui_data(mob/user, ui_key)
	. = ..()
	.["last_power_gen"]    = round(lastgen)
	.["sun_angle"]         = global.sun.angle
	.["sun_angle_txt"]     = angle2text(global.sun.angle)
	.["current_angle"]     = current_angle
	.["current_angle_txt"] = angle2text(current_angle)
	.["tracking_mode"]     = track_mode
	.["tracking_rate"]     = track_rate
	.["nb_panels"]         = nb_panels
	.["has_tracker"]       = has_tracker

/obj/machinery/computer/solar_control/ui_interact(mob/user, ui_key, datum/nanoui/ui, force_open)
	var/list/data = ui_data(user, ui_key)
	ui = SSnano.try_update_ui(user, src, ui_key, ui, data, force_open)
	if (!ui)
		ui = new(user, src, ui_key, "solar_control.tmpl", "Solar Panel Control", 480, 410, state = global.physical_topic_state)
		ui.set_initial_data(data)
		ui.open()
		ui.set_auto_update(TRUE)

/**Used for updating the time of the next timed tracking update */
/obj/machinery/computer/solar_control/proc/schedule_next_tracking_update()
	if(!track_rate)
		return
	next_timed_update = REALTIMEOFDAY + ((1 HOUR) / abs(track_rate))

/obj/machinery/computer/solar_control/proc/set_rate_control(var/_cur_angle, var/_tgt_angle)
	if(!isnull(_cur_angle))
		var/new_target_angle = dd_range( 0, 359,(360 + current_angle + _cur_angle) % 360 ) //#TODO: Sort out this math nightmare
		if(track_mode == SOLAR_CONTROL_TRACKING_AUTO) //manual update, so losing auto-tracking
			set_track_mode(SOLAR_CONTROL_TRACKING_OFF)
		var/decl/public_access/public_variable/solar_control_requested_angle/TA = GET_DECL(/decl/public_access/public_variable/solar_control_requested_angle)
		TA.write_var(src, new_target_angle)

	if(!isnull(_tgt_angle))
		track_rate = dd_range( -7200, 7200, track_rate + _tgt_angle)
		schedule_next_tracking_update()

/obj/machinery/computer/solar_control/proc/set_track_mode(var/new_mode)
	track_mode = new_mode
	if(track_mode == SOLAR_CONTROL_TRACKING_AUTO && has_tracker)
		var/decl/public_access/public_variable/solar_control_requested_angle/TA = GET_DECL(/decl/public_access/public_variable/solar_control_requested_angle)
		TA.write_var(src, current_angle)
		next_timed_update = -1

	else if (track_mode == SOLAR_CONTROL_TRACKING_TIMED) //begin manual tracking
		var/decl/public_access/public_variable/solar_control_requested_angle/TA = GET_DECL(/decl/public_access/public_variable/solar_control_requested_angle)
		TA.write_var(src, current_angle)
		schedule_next_tracking_update()
	
	else
		next_timed_update = -1
		
/obj/machinery/computer/solar_control/Topic(href, href_list)
	. = ..()
	if(href_list["close"] )
		SSnano.close_user_uis(usr, src, "main")
		return

	if(href_list["rate_control"])
		set_rate_control(href_list["current_angle"] ? text2num(href_list["current_angle"]) : null, href_list["target_angle"] ? text2num(href_list["target_angle"]) : null )

	if(href_list["track_mode"])
		set_track_mode(text2num(href_list["track_mode"]))

	if(href_list["search_connected"])
		search_for_connected()
		if(has_tracker && track_mode == SOLAR_CONTROL_TRACKING_AUTO)
			has_tracker.set_angle(global.sun.angle)
		src.set_panels(current_angle)

	interact(usr)
	return 1

/obj/machinery/computer/solar_control/Process()
	lastgen = gen
	gen = 0

	if(stat & (NOPOWER | BROKEN))
		return

	if( track_mode == SOLAR_CONTROL_TRACKING_TIMED && \
		track_rate &&\
		next_timed_update >= 0 &&\
		next_timed_update <= REALTIMEOFDAY)
			target_angle = ((target_angle + (track_rate / abs(track_rate))) + 360) % 360
			current_angle = target_angle
			schedule_next_tracking_update() //reset the counter for the next 1°

/obj/machinery/computer/solar_control/proc/acknowledge_connection(var/obj/machinery/power/solar/P)
	if(istype(P))
		nb_panels++ //Tally up connected panels
		P.set_target_angle(current_angle)//Transmit them the angle as gift
	if(istype(P, /obj/machinery/power/tracker))
		has_tracker++ //Report if we got a tracker

/obj/machinery/computer/solar_control/proc/acknowledge_disconnection(var/obj/machinery/power/solar/P)
	if(istype(P))
		nb_panels = max(0, nb_panels - 1) //Tally up connected panels
		P.set_target_angle(current_angle) //Update their angle on connect directly
	if(istype(P, /obj/machinery/power/tracker))
		has_tracker = max(0, has_tracker - 1) //Report if we got a tracker

///////////////////////////////////////////////
// Public Access
///////////////////////////////////////////////

/**Var for the controller to transmit the desired angle to panels */
/decl/public_access/public_variable/solar_control_requested_angle
	expected_type = /obj/machinery/computer/solar_control
	name          = "control requested angle"
	desc          = "The angle the controller wants the panels to currently face."
	can_write     = TRUE
	has_updates   = TRUE
	var_type      = IC_FORMAT_NUMBER

/decl/public_access/public_variable/solar_control_requested_angle/write_var(obj/machinery/computer/solar_control/machine, new_value)
	if(!(. = ..()))
		return
	machine.current_angle = new_value

/decl/public_access/public_variable/solar_control_requested_angle/access_var(obj/machinery/computer/solar_control/machine)
	return machine.current_angle

/**Var for tracker to report angle changes to the controller */
// decl/public_access/public_variable/solar_control_tracker_angle
// 	expected_type = /obj/machinery/computer/solar_control
// 	name = "solar angle tracker"
// 	desc = "The solar angle reported by the solar tracker if present."
// 	can_write = TRUE
// 	has_updates = TRUE
// 	var_type = IC_FORMAT_NUMBER

// decl/public_access/public_variable/solar_control_tracker_angle/write_var(obj/machinery/computer/solar_control/machine, new_value)
// 	if(tracking_mode != SOLAR_CONTROL_TRACKING_AUTO)
// 		return //Must ignore when not in auto mode
// 	if(!(. = ..()))
// 		return
// 	machine.current_angle = new_value

/**Method for solar machinery to report to the controller after they get pinged by the controller */
/decl/public_access/public_method/solar_control_ack
	name      = "acknowledged"
	desc      = "Called with the machine's reference when it acknowledges its connected to us."
	call_proc = /obj/machinery/computer/solar/proc/acknowledge_connection

/decl/public_access/public_method/solar_control_rem
	name      = "removed"
	desc      = "Called with the machine's reference when it has to disconnect from us for any reasons."
	call_proc = /obj/machinery/computer/solar/proc/acknowledge_disconnection

///////////////////////////////////////////////
// Presets
///////////////////////////////////////////////
/decl/stock_part_preset/radio/receiver/solar_control
	frequency        = SOLARS_FREQ
	receive_and_call = list(
		"ACK" = /decl/public_access/public_method/solar_control_ack, //Received whenever a device on the net returns our calls
		"REM" = /decl/public_access/public_method/solar_control_rem, //Received whenever a device on the net is disavled 
	)
	receive_and_write = list(
		"set_tracker_sun_angle" = /decl/public_access/public_variable/solar_control_requested_angle, //Write the received tracker angle in this var
	)

/decl/stock_part_preset/radio/basic_transmitter/solar_control
	frequency          = SOLARS_FREQ
	transmit_on_change = list(
		"set_solar_panel_angle" = /decl/public_access/public_variable/solar_control_requested_angle, //Emit this var when it changes
	)

#undef SOLAR_CONTROL_TRACKING_OFF
#undef SOLAR_CONTROL_TRACKING_TIMED
#undef SOLAR_CONTROL_TRACKING_AUTO