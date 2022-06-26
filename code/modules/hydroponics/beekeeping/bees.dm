/datum/bee_queen
	var/duration_lifespan
	var/duration_gestation
	var/duration_gestation

/datum/bee_colony
	var/worked_pool
	var/larva_pool
	var/gestating_eggs
	var/gestating_workers
	
	var/datum/bee_queen
	var/decl/bee_species/bee_species
	var/obj/structure/beehive/hive


/datum/bee_colony/proc/split()

/datum/bee_colony/proc/add_queen(var/datum/_bee_queen)

/datum/bee_colony/proc/rem_queen()

/datum/bee_colony/proc/add_workers(var/amount = 1)

/datum/bee_colony/proc/rem_workers(var/amount = 1)

/datum/bee_colony/proc/settle_hive(var/obj/structure/beehive/_hive)

//
// Updating
//

/datum/bee_colony/proc/update_colony_scavenging()

/datum/bee_colony/proc/update_colony_production()

/datum/bee_colony/proc/update_colony_bees()
