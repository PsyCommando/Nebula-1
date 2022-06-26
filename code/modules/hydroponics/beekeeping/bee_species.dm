////////////////////////////////////////////////////////////////
//
////////////////////////////////////////////////////////////////
#define BEE_GENES_FLAGS_READONLY BITFLAG(0) //Immutable genes are marked with this flag.
#define BEE_GENES_FLAGS_TRIGGER  BITFLAG(1) //Genes that have an activation trigger instead of being passive are marked with this. Will call should_trigger() proc.
#define BEE_GENES_FLAGS_UPDATES  BITFLAG(2) //Genes that update effects over time have this flag set. Will call update() proc.


////////////////////////////////////////////////////////////////
// Bee Genes
////////////////////////////////////////////////////////////////
/decl/bee_gene
	var/name
	var/desc
	var/gene_flags = 0
	var/enforced_value_type

/decl/bee_gene/proc/should_trigger(var/datum/bee_colony/colony)
	return TRUE

/decl/bee_gene/proc/activate(var/datum/bee_colony/colony)
	return TRUE

/decl/bee_gene/proc/update(var/datum/bee_colony/colony)
	return FALSE

/decl/bee_gene/proc/deactivate(var/datum/bee_colony/colony)
	return TRUE

/decl/bee_gene/proc/create_value(...)
	return new enforced_value_type(args)

/decl/bee_gene/proc/set_value(var/data, var/value)
	if(enforced_value_type && !istype(value, enforced_value_type))
		CRASH("Passed an unexpected data type!")
	target = data
	return TRUE

/decl/bee_gene/proc/get_value(var/data)
	return data

/decl/bee_gene/proc/destroy_value(var/data)
	if(islist(data))
		QDEL_NULL_LIST(data)
	else if(istype(data, /datum/bee_gene_data))
		QDEL_NULL(data)
	return TRUE

/decl/bee_gene/proc/mutate(var/data)
	if(!enforced_value_type)
		return rand(0, 100) * 0.001

/decl/bee_gene/proc/inherit(var/decl/bee_gene/parent, var/data)
	return data

////////////////////////////////////////////////////////////////
// Bee Genes Definition
////////////////////////////////////////////////////////////////
/decl/bee_gene/population_factor
	name = "population factor"
	desc = "Affects the maximum population a bee colony may sustain."

/decl/bee_gene/gestation_time_factor
	name = "gestation time factor"
	desc = "Affects the gestation period for a bee colony."

/decl/bee_gene/product
	name = "product type"
	desc = "Specifies a product type a bee colony produces."
	enforced_value_type = /datum/bee_gene_data/product

/decl/bee_gene/construction_material
	name = "construction material type"
	desc = "Specifies a type of material the bees uses to build their honeycombs."
	enforced_value_type = /datum/bee_gene_data/construction_material

/decl/bee_gene/food
	name = "food type"
	desc = "Specifies a food type a bee colony consumes."
	enforced_value_type = /datum/bee_gene_data/food

/decl/bee_gene/aggresiveness
	name = "aggressiveness"
	desc = "Affects how aggressive a bee colony is towards other life forms."
	enforced_value_type = /datum/bee_gene_data/aggressiveness

/decl/bee_gene/environment_resilience
	name = "environmental resilience factor"
	desc = "Affects how resilient a bee colony is to atmospheric changes."

////////////////////////////////////////////////////////////////
// Bee Genes Data Definition
////////////////////////////////////////////////////////////////
/datum/bee_gene_data/product
	var/product_type
	var/product_to_food_ratio = 1.0
/datum/bee_gene_data/product/New(var/_product_type, var/_product_to_food_ratio)
	. = ..()
	product_type = _product_type
	product_to_food_ratio = _product_to_food_ratio

/datum/bee_gene_data/food
	var/food_type
	var/food_priority = 100 //1 to more. Higher numbers is lower priority
/datum/bee_gene_data/food/New(var/_food_type, var/_food_priority)
	. = ..()
	food_type = _food_type
	food_priority = food_priority

/datum/bee_gene_data/aggressiveness
	var/attack_chance = 0
/datum/bee_gene_data/aggressiveness/New(var/_attack_chance)
	. = ..()
	attack_chance = _attack_chance
	
/datum/bee_gene_data/construction_material
	var/decl/material/mat
/datum/bee_gene_data/construction_material/New(var/material_key)
	. = ..()
	if(istype(material_key, /decl/material))
		mat = material_key
	else if(ispath(material_key))
		mat = GET_DECL(material_key)

/datum/bee_gene_data/environment_resilience
	var/min_temp = T0C + 5
	var/max_temp = T0C + 60
	var/min_pressure = 15 KILOPASCALS
	var/max_pressure = 200 KILOPASCALS
	var/list/min_req_gases_ratios = list(
		
	)
	var/list/max_req_gases_ratios = list(

	)

////////////////////////////////////////////////////////////////
// Bee Species Information
////////////////////////////////////////////////////////////////
/datum/bee_species
	var/name         = "apis"
	var/display_name = "honeybee"
	var/description  = "Bees."

	//Hive data
	var/tmp/base_max_workers          = 100
	var/tmp/base_max_larvaes          = 25
	var/tmp/base_max_eggs             = 25
	var/tmp/base_gestation_duration   = 10 MINUTES
	var/tmp/base_larva_state_duration =  5 MINUTES
	var/tmp/base_queen_bee_lifespan   =  1 HOUR
	var/tmp/base_worker_bee_lifespan  = 30 MINUTES

	//Production
	/**Possible pollination targets for these bees. Assoc list of a type to a percentage weight. */
	var/tmp/list/scavenging_targets = list( //Atom the bees will scavenge on the map for nourishment + provide buffs
		/obj/machinery/portable_atmospherics/hydroponics = 0.80,
		/obj/structure/flora/pottedplant                 = 0.30,
	)
	var/decl/material/construction_material = /decl/material/solid/wax/bees
	var/list/genes

/**Returns the initial genes of the species. */
/datum/bee_species/proc/get_initial_genes()
	return genes

////////////////////////////////////////////////////////////////
// Species
////////////////////////////////////////////////////////////////
/datum/bee_species/western_honeybee
	name         = "apis mellifera"
	display_name = "western honeybee"
	description  = "The most common honey bee species back on Earth."

/datum/bee_species/western_honeybee/New()
	. = ..()
	if(!length(genes))
		genes = get_initial_genes()

/datum/bee_species/western_honeybee/get_initial_genes()
	. = ..()
	LAZYSET(., /decl/bee_gene/population_factor,     1.0)
	LAZYSET(., /decl/bee_gene/gestation_time_factor, 1.0)
	LAZYSET(., /decl/bee_gene/construction_material, new /datum/bee_gene_data/construction_material(/decl/material/solid/wax/bees))
	LAZYSET(., /decl/bee_gene/product,               new /datum/bee_gene_data/product(/decl/material/liquid/nutriment/honey,       0.75))
	LAZYSET(., /decl/bee_gene/product,               new /datum/bee_gene_data/product(/decl/material/liquid/nutriment/royal_jelly, 0.25))
	LAZYSET(., /decl/bee_gene/food,                  new /datum/bee_gene_data/product(/decl/material/liquid/nutriment/pollen,      2))
	LAZYSET(., /decl/bee_gene/food,                  new /datum/bee_gene_data/product(/decl/material/liquid/nutriment/honey,       1))
	LAZYSET(., /decl/bee_gene/aggresiveness,         new /datum/bee_gene_data/aggressiveness(0))
