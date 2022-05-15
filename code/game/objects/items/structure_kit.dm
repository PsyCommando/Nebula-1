//Where can we place the kit
#define STRUCTURE_KIT_ON_FLOOR BITFLAG(1)
#define STRUCTURE_KIT_ON_WALL  BITFLAG(2)

/**
 * Data for structure kits
 */
/decl/structure_kit_type
	var/name                    //Name given to the kit
	var/result_name             //Name of the resulting item
	var/icon_prefix             //The prefix(first part of the icon state name) for the kit icon
	var/structure_path          //Path to the structure to be build from this kit
	var/kit_placement            = STRUCTURE_KIT_ON_FLOOR //Where can we place the kit
	var/list/contained_materials //List of materials the kit contains if we try to recycle the kit
	var/decl/material/material 
	var/decl/material/reinf_mat  
	var/list/required_skills     = list(SKILL_CONSTRUCTION, SKILL_NONE)//List of skill types and levels required to install this kit, first skill is the one considered the most important
	var/build_time               = 5 SECONDS //Base time taken to build
	var/build_time_modifier      = 1.0 //Modifier for relation between skill level and build time
	//Failure handling
	var/build_fail_chance        = 0   //Percent chances that the build may fail if skill is low
	var/build_nofail_skill       = SKILL_MAX //Skill level at which you can't fail anymore

/decl/structure_kit_type/Initialize()
	. = ..()
	if(!result_name)
		result_name = atom_info_repository.get_name_for(structure_path)
	if(!LAZYLEN(contained_materials))
		contained_materials = atom_info_repository.get_matter_for(structure_path)
	if(!material && LAZYLEN(contained_materials))
		material = get_key_by_index(contained_materials, 1)
		
/decl/structure_kit_type/proc/is_valid_turf(var/turf/target)
	if(kit_placement & STRUCTURE_KIT_ON_WALL && target.is_wall())
		return TRUE
	if(kit_placement & STRUCTURE_KIT_ON_FLOOR && target.is_floor())
		return TRUE
	return FALSE

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

/decl/structure_kit_type/proc/list_required_skills()
	if(!LAZYLEN(required_skills))
		return "None"
	. = list()
	for(var/skill in required_skills)
		var/decl/hierarchy/skill/S = GET_DECL(skill)
		if(!S)
			CRASH("Bad skill path in the required skill list!")
		. += "[S.skill_levels[required_skills[skill]]] in [S.name]"
	. = jointext(., ", ")

/decl/structure_kit_type/proc/install_direction(var/turf/target, var/mob/user)
	return user.dir

/decl/structure_kit_type/proc/wall_pixel_offset(var/place_dir)
	. = list(x = 0, y = 0)

/decl/structure_kit_type/proc/is_skilled_enough(var/mob/user)
	return LAZYLEN(required_skills) && istype(user?.skillset) && user.skillset.skill_check_multiple(required_skills)

/decl/structure_kit_type/proc/after_placing(var/obj/structure/placed, var/mob/user)
	return

/** 
 * Pre-fabricated furniture building kit
 * Use on a location to build the associated structure
 */
/obj/item/structure_kit
	name = "KEAI furniture kit"
	icon = 'icon/obj/items/structure_kit.dmi'
	//Its a big box
	w_class = ITEM_SIZE_LARGE
	slowdown_general = 1.5
	force = 5
	attack_cooldown = DEFAULT_ATTACK_COOLDOWN * 2
	base_parry_chance = 10
	material = /decl/material/solid/cardboard
	var/decl/structure_kit_type/kit //Initially the path to the structure kit type, then the actual decl of the kit

/obj/item/structure_kit/Initialize(ml, material_key, var/_kit_type = null)
	if(!kit && _kit_type)
		kit = _kit_type
	if(ispath(kit))
		kit = GET_DECL(kit)
	if(!istype(kit))
		log_warning("[src] structure kit doesn't have a proper kit type path or decl reference set on initialize! Destroying!")
		return INITIALIZE_HINT_QDEL
	. = ..()
	set_extension(atom, /datum/extension/scent/custom, "cinnamon rolls and meatballs", /decl/scent_intensity, SCENT_DESC_FRAGRANCE, 1)

/obj/item/structure_kit/create_matter()
	. = ..()
	if(LAZYLEN(kit.contained_materials))
		LAZYDISTINCTADD(matter, kit.contained_materials)

/obj/item/structure_kit/examine(mob/user, distance, infix, suffix)
	. = ..()
	to_chat(user, SPAN_NOTICE("\The [kit.name] contains everything you need to assemble \a [kit.result_name]. Even contains misc single use tools."))
	//Tell if skilled enough
	if(!kit.is_skilled_enough(user))
		to_chat(user, SPAN_WARNING("You are not skilled enough to install this kit."))
	to_chat(user, "The following skills are required to assemble this kit: [kit.list_required_skills()]")
	to_chat(user, kit.list_valid_turfs())

/obj/item/structure_kit/update_icon()
	. = ..()
	if(ispath(kit))
		kit = GET_DECL(kit) 
	if(!kit)
		initial(icon_state)
		return
	icon_state = kit.icon_prefix

/obj/item/structure_kit/afterattack(atom/target, mob/user, proximity_flag, click_parameters)
	. = ..()
	if(!proximity_flag || !isturf(target))
		return
	try_build(target, user)

/obj/item/structure_kit/attack_self(mob/user)
	. = ..()
	var/turf/T = get_turf(user)
	if(istype(T))
		try_build(target, user)

/obj/item/structure_kit/proc/create_result(var/turf/target, var/mob/user)
	var/obj/structure/S = new kit.structure_path(target, kit.material, kit.reinf_mat)
	S.set_dir(kit.install_direction(target, user))
	//Apply wall offset
	if(target.is_wall())
		var/list/offset = kit.wall_pixel_offset(S.dir)
		S.pixel_x = offset["x"]
		S.pixel_y = offset["y"]

/obj/item/structure_kit/proc/try_build(var/turf/target, var/mob/user)
	if(ispath(kit))
		kit = GET_DECL(kit)
	if(!kit)
		CRASH("Structure kit didn't have a valid kit specified!")
	
	//Test if skilled enough
	if(!kit.is_skilled_enough(user))
		to_chat(user, SPAN_NOTICE("You have no ideas how to assemble this."))
		return
	//Test if spot adequate
	if(!kit.is_valid_turf(target))
		to_chat(user, SPAN_WARNING("You cannot place \the [src] on \the [target]! [kit.list_valid_turfs()]"))
		return
	
	user.visible_message(SPAN_NOTICE("\The [user] begins assembling \a [kit.result_name]."), SPAN_NOTICE("You read the instructions and start assembling \the [kit.name]."))
	var/major_skill = locate() in required_skills
	if(user.do_skilled(kit.build_time, major_skill, target, kit.build_time_modifier))
		if(QDELETED(kit) || QDELETED(user))
			return
		if(kit.build_fail_chance && user.skill_fail_prob(major_skill, kit.build_fail_chance, kit.build_nofail_skill))
			user.visible_message(SPAN_WARNING("\The [user] fails to assemble the "), SPAN_WARNING("You're left with many more screws that expected. You've failed, and melancholy fills your heart.."))
			return
	user.visible_message(SPAN_NOTICE("\The [user] has finished assembling \a [kit.result_name]!"), SPAN_NOTICE("You finished assembling \the [kit.result_name]! All that with only [rand(1, 10)] screw(s) leftover!"))

	var/obj/structure/built = create_result(target, user) 
	kit.after_placing(built, user)
	built.update_icon()

	//drop the packaging materials
	for(var/path in matter)
		SSmaterials.create_object(path, get_turf(src), round(matter[path]/SHEET_MATERIAL_AMOUNT))
	qdel(src)
	return TRUE

///////////////////////////////////////////////
// Kit templates
///////////////////////////////////////////////
/decl/structure_kit_type/stairs
	name               = "stairs kit"
	icon_prefix        = "stairs"
	structure_path     = /obj/structure/stairs
	required_skills    = list(SKILL_CONSTRUCTION, SKILL_BASIC)//List of skill types and levels required to install this kit, first skill is the one considered the most important
	build_time         = 10 SECONDS //Base time taken to build
	build_fail_chance  = 2
	build_nofail_skill = SKILL_ADEPT

/obj/item/structure_kit/stairs
	kit = /decl/structure_kit_type/stairs