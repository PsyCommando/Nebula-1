#define SOLAR_MAX_DIST                     40
#define SOLAR_OCCLUSION_CHECK_RANGE_SPACE  20
#define SOLAR_OCCLUSION_CHECK_RANGE_PLANET 5
var/global/solar_gen_rate = 1500
var/global/list/solars_list

/**
 * Fake Solar Panel
 */
/obj/machinery/power/solar/fake
	uncreated_component_parts = null
	maximum_component_parts   = null
	required_parts            = null
	construct_state           = /decl/machine_construction/noninteractive

/obj/machinery/power/solar/fake/Process()
	return PROCESS_KILL

/**
 * Solar Panel
 */
/obj/machinery/power/solar
	name                      = "solar panel"
	desc                      = "A solar electrical generator."
	icon                      = 'icons/obj/power.dmi'
	icon_state                = "sp_base"
	anchored                  = TRUE
	density                   = TRUE
	idle_power_usage          = 0
	active_power_usage        = 0
	waterproof                = TRUE
	stat_immune               = NOSCREEN | NOINPUT | NOPOWER
	var/health                = 10
	var/maxHealth             = 10
	var/obscured              = 0     //Whether the panel is blocked from starlight
	var/sunfrac               = 0     //Cached solar exposure of the panel
	var/efficiency            = 1     //Cached solar energy conversion factor
	var/actual_angle          = 0     //Currently facing angle
	var/target_angle          = 0     //Target angle
	var/is_turning            = FALSE //Set by process when aligning the panel to the sun, so we can reduce unnecessary updates
	var/req_sheets            = 2     //Amount of glass sheets needed for the panel
	var/list/required_parts   = list(
		/obj/item/stock_parts/building_material = 1,
		/obj/item/stock_parts/solar_cell        = 2, //Since we don't use a board an we're built differently than everything else, we store our needed parts here
	)
	var/static/list/cached_overlays = list() //Contains frequently used overlays
	frame_type                = /obj/item/solar_assembly
	construct_state           = /decl/machine_construction/simple/assembled/solar
	uncreated_component_parts = list(
		/obj/item/stock_parts/power/terminal    = 1,
		/obj/item/stock_parts/shielding/frame   = 1,
		/obj/item/stock_parts/radio/receiver    = 1,
		/obj/item/stock_parts/radio/transmitter = 1,
	)

	maximum_component_parts   = list(
		/obj/item/stock_parts/building_material = 1,
		/obj/item/stock_parts/power/terminal    = 1, 
		/obj/item/stock_parts/solar_cell        = 2,
		/obj/item/stock_parts/shielding         = 2,
		/obj/item/stock_parts                   = 1,
	)

	public_variables = list(
		/decl/public_access/public_variable/target_solar_angle,
	)
	public_methods = list(
		/decl/public_access/public_method/solar_report_connected,
	)

	stock_part_presets = list(
		/decl/stock_part_preset/terminal_setup                = 1,
		/decl/stock_part_preset/radio/receiver/solar          = 1,
		/decl/stock_part_preset/radio/event_transmitter/solar = 1
	)

/obj/machinery/power/solar/Initialize()
	. = ..()
	LAZYDISTINCTADD(global.solars_list, src)
	if(global.sun)
		//Event only for updating occlusion. Targeting of the panels is done through the solar control.
		events_repository.register(/decl/observ/sun_position_changed, global.sun, src, /obj/machinery/power/solar/proc/on_sun_position_changed)

/obj/machinery/power/solar/Destroy()
	LAZYREMOVE(global.solars_list, src)
	if(global.sun)
		events_repository.unregister(/decl/observ/sun_position_changed, global.sun, src, /obj/machinery/power/solar/proc/on_sun_position_changed)
	return ..()

/obj/machinery/power/solar/RefreshParts()
	. = ..()
	update_efficiency()
	update_integrity()

/obj/machinery/power/solar/connect_to_network()
	if(!(. = ..()))
		return
	id_tag = "\ref[powernet]" //All solar devices on the same network have the network as id_tag
	
/obj/machinery/power/solar/disconnect_from_network()
	if(!(. = ..()))
		return
	report_disconnect()
	id_tag = null

/obj/machinery/power/solar/Process()
	if((stat & BROKEN) || !powernet)
		return

	//Turn to face the new angle
	if(round(actual_angle) != round(target_angle))
		is_turning = TRUE
		actual_angle = Interpolate(actual_angle, target_angle, 0.5) //in half increments so 2 ticks to turn
		queue_icon_update()
	else if(is_turning) //If we hit this, we were just moving, so update exposure, and stop turning
		update_solar_exposure() //Just do exposure here since its faster, and the sun will update occlusion later
		is_turning = FALSE
	 
	if(!global.sun || obscured)
		return
	generate_power(solar_gen_rate * sunfrac * efficiency)

/obj/machinery/power/solar/drain_power()
	return -1

/obj/machinery/power/solar/on_update_icon()
	..()
	overlays.Cut()
	if(!LAZYLEN(cached_overlays))
		cache_solar_panel_overlays()

	if(construct_state != /decl/machine_construction/simple/assembled/solar)
		return //No overlays if we're not complete!
	
	if(stat & BROKEN)
		overlays += cached_overlays["solar_panel-b"]
	else
		overlays += cached_overlays["solar_panel"] 
		set_dir(angle2dir(actual_angle))

/obj/machinery/power/solar/physically_destroyed(skip_qdel)
	//Drop bits of our glass panel
	var/obj/item/stock_parts/building_material/bmat = locate() in component_parts
	for(var/obj/item/stack/material/ST in bmat.materials)
		ST.material.place_shard(loc)
		ST.material.place_shard(loc)
	. = ..()

/**Cache the solar panel overlays */
/obj/machinery/power/solar/proc/cache_solar_panel_overlays()
	cached_overlays.Cut()
	cached_overlays["solar_panel-b"] = image('icons/obj/power.dmi', icon_state = "solar_panel-b", layer = ABOVE_HUMAN_LAYER)
	cached_overlays["solar_panel"]   = image('icons/obj/power.dmi', icon_state = "solar_panel",   layer = ABOVE_HUMAN_LAYER)

/obj/machinery/power/solar/proc/update_integrity()
	//Update HP based on glass pane
	var/obj/item/stock_parts/building_material/B = locate() in component_parts
	if(B)
		var/total_hp = 0
		var/total_sheets = 0
		for(var/obj/item/stack/material/ST in B.materials)
			var/decl/material/M = ST.get_material()
			if(M.opacity < 0.5)
				total_hp += M.integrity
				total_sheets += ST.amount

		var/obj/item/stock_parts/shielding/frame/F = get_component_of_type(/obj/item/stock_parts/shielding/frame)
		if(total_sheets > 0)
			var/avg_hp = total_hp / total_sheets
			F.max_health = (avg_hp/100) * initial(F.max_health)
			F.health     = (avg_hp/100) * initial(F.health)
		else
			F.max_health = initial(F.max_health)
			F.health     = between(0, F.health, F.max_health)

/obj/machinery/power/solar/proc/update_efficiency()
	//Update efficiency based on solar cells rating
	var/total_rating = 0
	var/nb_cells = 0
	for(var/obj/item/stock_parts/solar_cell/C in component_parts)
		total_rating += C.rating
		nb_cells++
	if(total_rating)
		efficiency = round(total_rating / nb_cells, 0.25) //Average the rating of all components

//calculates the fraction of the sunlight that the panel recieves
/obj/machinery/power/solar/proc/update_solar_exposure()
	if(!global.sun || obscured)
		sunfrac = 0
		return
	//find the smaller angle between the direction the panel is facing and the direction of the sun (the sign is not important here)
	var/p_angle = min(abs(actual_angle - global.sun.angle), 360 - abs(actual_angle - global.sun.angle))
	if(p_angle > 90)			// if facing more than 90deg from sun, zero output
		sunfrac = 0
		return
	sunfrac = cos(p_angle) ** 2
	//isn't the power recieved from the incoming light proportionnal to cos(p_angle) (Lambert's cosine law) rather than cos(p_angle)^2 ?

/**Callback proc for the /decl/observ/sun_position_changed event */
/obj/machinery/power/solar/proc/on_sun_position_changed(var/new_angle)
	update_occlusion()

/**
 * Trace towards sun to see if we're in shadow. 
 * Fairly expensive to run.
 */
/obj/machinery/power/solar/proc/update_occlusion()
	set waitfor = FALSE
	var/steps  = SOLAR_OCCLUSION_CHECK_RANGE_SPACE	// 20 steps is enough
	// On planets, we take fewer steps because the light is mostly up
	// Also, many planets barely have any spots with enough clear space around
	if(isturf(loc))
		var/obj/effect/overmap/visitable/sector/exoplanet/E = global.overmap_sectors["[loc.z]"]
		if(istype(E))
			steps = SOLAR_OCCLUSION_CHECK_RANGE_PLANET

	var/turf/T
	var/ax = x		// start at the solar panel
	var/ay = y
	for(var/i = 1 to steps)
		ax += global.sun.dx
		ay += global.sun.dy

		T = locate( round(ax,0.5),round(ay,0.5),z)

		if(!T || T.x == 1 || T.x == world.maxx || T.y == 1 || T.y == world.maxy) // not obscured if we reach the edge
			break

		if(T.opacity) // if we hit a solid turf, panel is obscured
			obscured = TRUE
			return

	obscured = FALSE // if hit the edge or stepped max times, not obscured
	update_solar_exposure()

/**Called when the controller ask this panel if its connected */
/obj/machinery/power/solar/proc/solar_report_connected(var/obj/machinery/machine)
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

/**Sends to the controller a message when its been disconnected from the net, or disabled. */
/obj/machinery/power/solar/proc/report_disconnect()
	var/obj/item/stock_parts/radio/transmitter/T = get_component_of_type(/obj/item/stock_parts/radio/transmitter)
	if(!istype(T))
		return
	T.queue_transmit(list("REM" = src))

/**For setting the target angle directly */
/obj/machinery/power/solar/proc/set_target_angle(var/new_angle)
	var/decl/public_access/public_variable/target_solar_angle/VA = GET_DECL(/decl/public_access/public_variable/target_solar_angle)
	VA.write_var(src, new_angle)

///////////////////////////////////////////////
// Public Access
///////////////////////////////////////////////

/**Var for receiving the desired angle the panels should turn to */
/decl/public_access/public_variable/target_solar_angle
	expected_type = /obj/machinery/power/solar
	name          = "target solar angle"
	desc          = "The angle the solar panel should turn to face."
	can_write     = TRUE
	has_updates   = TRUE
	var_type      = IC_FORMAT_NUMBER

/decl/public_access/public_variable/solar_angle/write_var(obj/machinery/power/solar/machine, new_value)
	. = ..()
	if(.)
		machine.target_angle = new_value

/decl/public_access/public_variable/solar_angle/access_var(obj/machinery/power/solar/machine)
	return machine.target_angle

/**Method called on connection request by external machines */
/decl/public_access/public_method/solar_report_connected
	name = "report connected"
	desc = "Report to the powernet's solar control that we're connected."
	call_proc = /obj/machinery/power/solar/proc/solar_report_connected

///////////////////////////////////////////////
// Presets
///////////////////////////////////////////////

/decl/stock_part_preset/radio/event_transmitter/solar
	frequency = SOLARS_FREQ

/decl/stock_part_preset/radio/receiver/solar
	frequency = SOLARS_FREQ
	receive_and_write = list(
		SOLAR_TOPIC_UPDATE_PANEL_ANGLE = /decl/public_access/public_variable/target_solar_angle,
	)
	receive_and_call = list(
		SOLAR_TOPIC_CONNECT = /decl/public_access/public_method/solar_report_connected,
	)

///////////////////////////////////////////////
// Construction state stuff
///////////////////////////////////////////////
/obj/machinery/power/solar/proc/check_material_has_suitable_glass(var/obj/item/stock_parts/building_material/bmat)
	if(bmat)
		var/nbvalid = 0
		var/list/bvals = bmat.building_cost()

		for(var/key in bvals)
			var/decl/material/M = GET_DECL(key)
			if(M && M.opacity < 0.5)
				nbvalid += bvals[key]

		if(nbvalid >= req_sheets)
			return TRUE
	return FALSE

/obj/machinery/power/solar/proc/list_missing_components()
	for(var/key in required_parts)
		var/list/found = get_all_components_of_type(key)
		var/nb_found = LAZYLEN(found)
		if(ispath(key, /obj/item/stock_parts/building_material))
			check_material_has_suitable_glass(locate(/obj/item/stock_parts/building_material) in found)
		if(nb_found < required_parts[key])
			LAZYSET(., key, (required_parts[key] - nb_found))

/**
 * Fully assembled and functional state.
*/
/decl/machine_construction/simple/assembled/solar
	down_state = /decl/machine_construction/simple/waiting_component

/decl/machine_construction/simple/assembled/solar/get_requirements(obj/machinery/power/solar/machine)
	. = ..()
	if(istype(machine))
		var/list/missing = machine.list_missing_components()
		LAZYDISTINCTADD(., missing)

/**
 * Wating for the missing components.
*/
/decl/machine_construction/simple/waiting_component/solar
	up_state   = /decl/machine_construction/simple/assembled
	down_state = /decl/machine_construction/simple/disassembled

/decl/machine_construction/simple/assembled/solar/get_requirements(obj/machinery/power/solar/machine)
	. = ..()
	if(istype(machine))
		var/list/missing = machine.list_missing_components()
		LAZYDISTINCTADD(., missing)
	