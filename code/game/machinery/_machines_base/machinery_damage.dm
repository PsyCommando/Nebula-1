/obj/machinery/proc/take_damage(amount, damtype = BRUTE, silent = FALSE)
	//Let's not bother initializing all the components for nothing
	if(amount <= 0)
		return
	if(damtype != BRUTE && damtype != BURN && damtype != ELECTROCUTE)
		return
	if(!silent)
		var/hitsound = 'sound/weapons/smash.ogg'
		if(damtype == ELECTROCUTE)
			hitsound = "sparks"
		else if(damtype == BURN)
			hitsound = 'sound/items/Welder.ogg'
		playsound(src, hitsound, 10, 1)

	// Shielding components (armor/fuses) take first hit
	var/list/shielding = get_all_components_of_type(/obj/item/stock_parts/shielding)
	for(var/obj/item/stock_parts/shielding/soak in shielding)
		if(damtype in soak.protection_types)
			amount -= soak.take_damage(amount, damtype)
	if(amount <= 0)
		return

	// If some damage got past, next it's generic (non-circuitboard) components
	var/obj/item/stock_parts/victim = get_damageable_component(damtype)
	while(amount > 0 && victim)
		amount -= victim.take_damage(amount, damtype)
		victim = get_damageable_component(damtype)
	if(amount <= 0)
		return

	// And lastly hit the circuitboard
	victim = get_component_of_type(/obj/item/stock_parts/circuitboard)
	if(victim)
		victim.take_damage(amount, damtype)

/obj/machinery/proc/get_damageable_component(var/damage_type)
	var/list/victims = shuffle(component_parts)
	if(LAZYLEN(victims))
		for(var/obj/item/stock_parts/component in victims)
			// Circuitboards are handled separately
			if(istype(component, /obj/item/stock_parts/circuitboard))
				continue
			if(damage_type && (damage_type in component.ignore_damage_types))
				continue
			// Don't damage what can't be repaired
			if(!component.can_take_damage())
				continue
			if(component.is_functional())
				return component
	for(var/path in uncreated_component_parts)
		if(uncreated_component_parts[path])
			var/obj/item/stock_parts/component = path
			//Must be checked this way, since we don't have an instance to call component.can_take_damage() on.
			if(initial(component.max_health) != ITEM_HEALTH_NO_DAMAGE)
				return force_init_component(path)

/obj/machinery/proc/on_component_failure(var/obj/item/stock_parts/component)
	RefreshParts()
	update_icon()
	if(istype(component, /obj/item/stock_parts/power))
		power_change()

/obj/machinery/emp_act(severity)
	if(use_power && operable())
		new /obj/effect/temp_visual/emp_burst(loc)
		spark_at(loc, 4, FALSE, src)
		use_power_oneoff(7500/severity) //#TODO: Maybe use the active power usage value instead of a random power literal
		take_damage(100/severity, ELECTROCUTE, 0, "power spike")
	. = ..()

/obj/machinery/bash(obj/item/W, mob/user)
	//Add a lower damage threshold for machines
	if(!istype(W) || W.force <= 5)
		return FALSE
	. = ..()

// This is really pretty crap and should be overridden for specific machines.
/obj/machinery/fluid_act(var/datum/reagents/fluids)
	..()
	if(!waterproof && operable() && (fluids.total_volume > FLUID_DEEP))
		explosion_act(3)

/obj/machinery/attack_generic(var/mob/user, var/damage, var/attack_verb, var/environment_smash)
	if(environment_smash >= 1)
		damage = max(damage, 10)

	if(damage >= 10)
		visible_message(SPAN_DANGER("\The [user] [attack_verb] into \the [src]!"))
		take_damage(damage)
	else
		visible_message(SPAN_NOTICE("\The [user] bonks \the [src] harmlessly."))
	attack_animation(user)

