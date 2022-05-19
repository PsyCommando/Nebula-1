//Where can we place the kit
#define STRUCTURE_KIT_ON_FLOOR  BITFLAG(1) //Whether we can build the kit on a floor turf.
#define STRUCTURE_KIT_ON_WALL   BITFLAG(2) //Whether we can build the kit on a wall turf.
#define STRUCTURE_KIT_SAME_TURF BITFLAG(3) //Whether we allow placing the kit on the same turf we're standing on

/**
 * Data for structure kits
 */
/decl/structure_kit_type
	var/name                    //Name given to the kit
	var/result_name             //Name of the resulting item
	var/icon_prefix             //The prefix(first part of the icon state name) for the kit icon
	var/structure_path          //Path to the structure to be build from this kit
	var/kit_placement            = STRUCTURE_KIT_ON_FLOOR //Where can we place the kit
	var/decl/material/material   //Primary material used to create the object
	var/decl/material/reinf_mat  //Secondary material used to create the object
	var/list/required_skills     = list(SKILL_CONSTRUCTION = SKILL_NONE)//List of skill types and levels required to install this kit, first skill is the one considered the most important
	var/build_time               = 5 SECONDS //Base time taken to build
	var/build_time_modifier      = 1.0 //Modifier for relation between skill level and build time
	//Failure handling
	var/build_fail_chance        = 0   //Percent chances that the build may fail if skill is low
	var/build_nofail_skill       = SKILL_MAX //Skill level at which you can't fail anymore

/decl/structure_kit_type/Initialize()
	. = ..()
	if(!result_name)
		result_name = atom_info_repository.get_name_for(structure_path)

/**Returns a list of materials with an amount for the whole kit */
/decl/structure_kit_type/proc/get_contained_materials()
	. = atom_info_repository.get_matter_for(structure_path)
	if(!material && LAZYLEN(.))
		material = get_key_by_index(., 1)

/**Returns whether the turf T is suitable to place the kit on.*/
/decl/structure_kit_type/proc/is_valid_turf(var/turf/T, var/mob/user)
	if(!(kit_placement & STRUCTURE_KIT_SAME_TURF) && (get_turf(src) == T))
		return FALSE
	if(kit_placement & STRUCTURE_KIT_ON_WALL && T.is_wall())
		return TRUE
	if(kit_placement & STRUCTURE_KIT_ON_FLOOR && T.is_floor())
		return TRUE
	return FALSE

/**Returns a string naming the kinds of turfs this kit can be assembled on. */
/decl/structure_kit_type/proc/list_valid_turfs()
	if(!kit_placement)
		CRASH("Structure kit '[src]' has no placement flag set!")

	var/valid = ""
	if(kit_placement & STRUCTURE_KIT_ON_WALL)
		valid += "walls"
	if(kit_placement & STRUCTURE_KIT_ON_FLOOR)
		if(length(valid) > 0)
			valid += ", and "
		valid += "floors"
	return "\The [name] can only be placed on [valid]."

/**Returns a string listing the names and level of the required minmum skills to build the kit. */
/decl/structure_kit_type/proc/list_required_skills()
	if(!LAZYLEN(required_skills))
		return "None"
	var/list/lines = list()
	for(var/skill in required_skills)
		var/decl/hierarchy/skill/S = GET_DECL(skill)
		if(!S)
			CRASH("Bad skill path in the required skill list!")
		lines += "[S.levels[required_skills[skill]]] in [S.name]"
	return jointext(lines, ", ")

/**Returns the direction the assembled object should be facing. */
/decl/structure_kit_type/proc/install_direction(var/turf/target, var/mob/user)
	return user.dir

/**Returns the x,y offset to apply to object if built on a wall turf. */
/decl/structure_kit_type/proc/wall_pixel_offset(var/place_dir)
	. = list("x" = 0, "y" = 0)

/**Returns whether the user has the minimum required skills to assemble this kit. */
/decl/structure_kit_type/proc/is_skilled_enough(var/mob/user)
	return LAZYLEN(required_skills) && user.skill_check_multiple(required_skills)

/**This is called immediately, after placing the object S, on turf T, by user. */
/decl/structure_kit_type/proc/after_placing(var/turf/T, var/obj/structure/S, var/mob/user)
	//Apply wall offset
	if(T.is_wall())
		var/list/offset = wall_pixel_offset(S.dir)
		S.pixel_x = offset["x"]
		S.pixel_y = offset["y"]

/** 
 * Pre-fabricated furniture building kit
 * Use on a location to build the associated structure
 */
/obj/item/structure_kit
	name              = "KEAI furniture kit"
	icon              = 'icons/obj/items/structure_kit.dmi'
	w_class           = ITEM_SIZE_LARGE
	slowdown_general  = 1.5
	attack_cooldown   = DEFAULT_ATTACK_COOLDOWN * 2
	force             = 5
	base_parry_chance = 10
	var/decl/structure_kit_type/kit //Initially the path to the structure kit type, then the actual decl of the kit
	var/currently_building = FALSE  //Whether we're currently attempting to build with the kit, to prevent building multiple times at once

/obj/item/structure_kit/Initialize(ml, material_key, var/_kit_type = null)
	if(!kit && _kit_type)
		kit = _kit_type
	if(ispath(kit))
		kit = GET_DECL(kit)
	if(!istype(kit))
		log_warning("[src] structure kit doesn't have a proper kit type path or decl reference set on initialize! Destroying!")
		return INITIALIZE_HINT_QDEL
	. = ..()
	set_extension(src, /datum/extension/scent/custom, "cinnamon rolls and meatballs", /decl/scent_intensity, SCENT_DESC_FRAGRANCE, 1)

/obj/item/structure_kit/create_matter()
	. = ..()
	//Add the actual materials of the assembled object
	var/list/contained_materials = kit.get_contained_materials()
	if(LAZYLEN(contained_materials))
		LAZYDISTINCTADD(matter, contained_materials)

/obj/item/structure_kit/examine(mob/user, distance, infix, suffix)
	. = ..()
	to_chat(user, SPAN_NOTICE("\The [kit.name] contains everything you need to assemble \a [kit.result_name]."))
	//Tell if skilled enough
	if(!kit.is_skilled_enough(user))
		to_chat(user, SPAN_WARNING("You are not skilled enough to install this kit."))
	to_chat(user, "The following skills are required to assemble this kit: [kit.list_required_skills()]")
	to_chat(user, kit.list_valid_turfs())

/obj/item/structure_kit/update_icon()
	. = ..()
	icon_state = kit.icon_prefix

/obj/item/structure_kit/afterattack(atom/target, mob/user, proximity_flag, click_parameters)
	. = ..()
	if(currently_building || !proximity_flag || !isturf(target))
		return
	try_build(target, user)

/**Creates the resulting object on turf T. */
/obj/item/structure_kit/proc/create_result(var/turf/T, var/mob/user)
	var/obj/structure/S = new kit.structure_path(T, kit.material, kit.reinf_mat)
	S.set_dir(kit.install_direction(T, user))
	kit.after_placing(T, S, user)
	S.update_icon()
	return S

/**Check and tell the user whether they can build the kit on turf T */
/obj/item/structure_kit/proc/validate_build(var/turf/T, var/mob/user)
	if(!kit)
		CRASH("Structure kit didn't have a valid kit specified!")
	
	//Test if skilled enough
	if(!kit.is_skilled_enough(user))
		to_chat(user, SPAN_NOTICE("You have no ideas how to assemble this..."))
		return FALSE

	//Test if spot adequate
	if(!kit.is_valid_turf(T, user))
		to_chat(user, SPAN_WARNING("You cannot assemble \the [src] on \the [T]! [kit.list_valid_turfs()]"))
		return FALSE

	return TRUE

/**Attempt to build the kit on turf T. Returns TRUE if succesful. */
/obj/item/structure_kit/proc/try_build(var/turf/T, var/mob/user)
	. = FALSE
	if(!validate_build(T, user))
		return

	var/major_skill = get_key_by_index(kit.required_skills, 1) //Grab first skill, since it should be the main one

	currently_building = TRUE
	user.visible_message(SPAN_NOTICE("\The [user] begins assembling \a [kit.result_name]."), SPAN_NOTICE("You read the instructions and start assembling \the [kit.name]."))
	
	if(user.do_skilled(kit.build_time, major_skill, T, kit.build_time_modifier) && !(QDELETED(kit) || QDELETED(user)))
		if(kit.build_fail_chance && user.skill_fail_prob(major_skill, kit.build_fail_chance, kit.build_nofail_skill))
			user.visible_message(SPAN_WARNING("\The [user] fails to assemble the "), SPAN_WARNING("You're left with many more screws that expected. You've failed, and melancholy fills your heart.."))
		else
			user.visible_message(SPAN_NOTICE("\The [user] has finished assembling \a [kit.result_name]!"), SPAN_NOTICE("You finished assembling \the [kit.result_name]! All that with only [rand(1, 10)] screw(s) leftover!"))
			user.unEquip(src)
			create_result(T, user) 
			qdel(src)
			. = TRUE
	currently_building = FALSE

///////////////////////////////////////////////
// Kit templates
///////////////////////////////////////////////

//Stairs kit
/decl/structure_kit_type/stairs
	name               = "stairs kit"
	icon_prefix        = "stairs"
	structure_path     = /obj/structure/stairs
	required_skills    = list(SKILL_CONSTRUCTION = SKILL_BASIC)//List of skill types and levels required to install this kit, first skill is the one considered the most important
	build_time         = 15 SECONDS //Base time taken to build
	build_fail_chance  = 2 //%
	build_nofail_skill = SKILL_ADEPT

/obj/item/structure_kit/stairs
	kit = /decl/structure_kit_type/stairs

//Ladder kit
/decl/structure_kit_type/ladder
	name               = "ladder kit"
	icon_prefix        = "ladder"
	structure_path     = /obj/structure/ladder
	required_skills    = list(SKILL_CONSTRUCTION = SKILL_BASIC)//List of skill types and levels required to install this kit, first skill is the one considered the most important
	build_time         = 15 SECONDS //Base time taken to build
	build_fail_chance  = 2 //%
	build_nofail_skill = SKILL_ADEPT

/obj/item/structure_kit/ladder
	kit = /decl/structure_kit_type/ladder