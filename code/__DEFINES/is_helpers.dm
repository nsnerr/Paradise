// simple is_type and similar inline helpers
#define in_range(source, user) (get_dist(source, user) <= 1 && (get_step(source, 0)?:z) == (get_step(user, 0)?:z))

/// Within given range, but not counting z-levels
#define IN_GIVEN_RANGE(source, other, given_range) (get_dist(source, other) <= given_range && (get_step(source, 0)?:z) == (get_step(other, 0)?:z))

// Atoms
#define isatom(A) (isloc(A))

#define isdatum(thing) (istype(thing, /datum))

#define is_screen_atom(A) istype(A, /atom/movable/screen)

#define isweakref(D) (istype(D, /datum/weakref))

// Mobs

#define ismegafauna(A) istype(A, /mob/living/simple_animal/hostile/megafauna)

#define isliving(A) (istype(A, /mob/living))

#define isbrain(A) (istype(A, /mob/living/carbon/brain))

// basic mobs
#define isbasicmob(A) (istype(A, /mob/living/basic))

// Carbon mobs
#define iscarbon(A) (istype(A, /mob/living/carbon))

#define ishuman(A) (istype(A, /mob/living/carbon/human))

#define isalien(A) (istype(A, /mob/living/carbon/alien))

#define isdevil(A) (istype(A, /mob/living/carbon/true_devil))

#define islarva(A) (istype(A, /mob/living/carbon/alien/larva))

#define isalienadult(A) (istype(A, /mob/living/carbon/alien/humanoid))

#define isalienhunter(A) (istype(A, /mob/living/carbon/alien/humanoid/hunter))

#define isaliensentinel(A) (istype(A, /mob/living/carbon/alien/humanoid/sentinel))

#define isalienqueen(A) (istype(A, /mob/living/carbon/alien/humanoid/queen))
#define isfacehugger(A) (istype(A, /mob/living/simple_animal/hostile/facehugger))
#define isfacehugger_mask(A) (istype(A, /obj/item/clothing/mask/facehugger) && !istype(A, /obj/item/clothing/mask/facehugger/toy))

// Simple animals
// #define issimple_animal(A) (istype(A, /mob/living/simple_animal)) use isanimal(A) instead

#define isshade(A) (istype(A, /mob/living/simple_animal/shade))

#define isconstruct(A) (istype(A, /mob/living/simple_animal/hostile/construct))

#define isslime(A) (istype((A), /mob/living/simple_animal/slime))

#define ispulsedemon(A) (istype(A, /mob/living/simple_animal/demon/pulse_demon))

#define isvampireanimal(A) (istype((A), /mob/living/simple_animal/hostile/vampire))

// Objects
#define isobj(A) istype(A, /obj) //override the byond proc because it returns true on children of /atom/movable that aren't objs

#define isitem(A) (istype(A, /obj/item))

#define isstack(A) (istype(A, /obj/item/stack))

#define isstorage(A) (istype(A, /obj/item/storage))

#define isgrenade(A) (istype(A, /obj/item/grenade))

#define issupplypod(A) (istype(A, /obj/structure/closet/supplypod))

#define isammocasing(A) (istype(A, /obj/item/ammo_casing))

#define ismachinery(A) (istype(A, /obj/machinery))

#define isapc(A) (istype(A, /obj/machinery/power/apc))

#define ismecha(A) (istype(A, /obj/mecha))

#define isvampirecoffin(A) (istype(A, /obj/structure/closet/coffin/vampire))

#define isspacepod(A) (istype(A, /obj/spacepod))

#define iseffect(A) (istype(A, /obj/effect))

#define isvehicle(A) (istype(A, /obj/vehicle))

#define isprojectile(A) (istype(A, /obj/projectile))

#define isgun(A) (istype(A, /obj/item/gun))

#define is_pen(W) (istype(W, /obj/item/pen))

#define is_pda(W) (istype(W, /obj/item/pda))

#define isradio(A) istype(A, /obj/item/radio)

#define isflower(A) istype(A, /obj/item/twohanded/required/kirbyplants)

#define isclothing(A) (istype(A, /obj/item/clothing))

#define is_internal_organ(A) istype(A, /obj/item/organ/internal)

#define	is_organ(A)			istype((A), /obj/item/organ)

GLOBAL_LIST_INIT(pointed_types, typecacheof(list(
	/obj/item/pen,
	/obj/item/screwdriver,
	/obj/item/reagent_containers/syringe,
	/obj/item/kitchen/utensil/fork)))

#define is_pointed(W) (is_type_in_typecache(W, GLOB.pointed_types))

GLOBAL_LIST_INIT(glass_sheet_types, typecacheof(list(
	/obj/item/stack/sheet/glass,
	/obj/item/stack/sheet/rglass,
	/obj/item/stack/sheet/plasmaglass,
	/obj/item/stack/sheet/plasmarglass,
	/obj/item/stack/sheet/titaniumglass,
	/obj/item/stack/sheet/plastitaniumglass,
	/obj/item/stack/sheet/abductorglass)))

#define is_glass_sheet(O) (is_type_in_typecache(O, GLOB.glass_sheet_types))

// Assembly
#define isassembly(O) (istype(O, /obj/item/assembly))
#define isigniter(O) (istype(O, /obj/item/assembly/igniter))
#define isinfared(O) (istype(O, /obj/item/assembly/infra))
#define isprox(O) (istype(O, /obj/item/assembly/prox_sensor))
#define issignaler(O) (istype(O, /obj/item/assembly/signaler))
#define istimer(O) (istype(O, /obj/item/assembly/timer))


//Turfs
#define issimulatedturf(A) istype(A, /turf/simulated)

#define isspaceturf(A) istype(A, /turf/space)

#define isopenspaceturf(A) (istype(A, /turf/simulated/openspace) || istype(A, /turf/space/openspace))

#define is_space_or_openspace(A) (isopenspaceturf(A) || isspaceturf(A))

#define isfloorturf(A) istype(A, /turf/simulated/floor)

#define iswallturf(A) istype(A, /turf/simulated/wall)

#define isreinforcedwallturf(A) istype(A, /turf/simulated/wall/r_wall)

#define ismineralturf(A) istype(A, /turf/simulated/mineral)

#define isancientturf(A) istype(A, /turf/simulated/mineral/ancient)

#define islava(A) (istype(A, /turf/simulated/floor/lava))

#define ischasm(A) (istype(A, /turf/simulated/floor/chasm))

#define issingularity(atom) (istype(atom, /obj/singularity))

//Structures
#define isstructure(A) (istype(A, /obj/structure))
#define istable(A) (istype(A, /obj/structure/table))

// Misc
#define isclient(A) istype(A, /client)

#define ispill(A) istype(A, /obj/item/reagent_containers/food/pill)

GLOBAL_LIST_INIT(turfs_without_ground, typecacheof(list(
	/turf/space,
	/turf/simulated/floor/chasm,
	/turf/simulated/openspace,
)))

#define isgroundlessturf(A) (is_type_in_typecache(A, GLOB.turfs_without_ground))


#define is_ventcrawler(A) (HAS_TRAIT(A, TRAIT_VENTCRAWLER_NUDE) || HAS_TRAIT(A, TRAIT_VENTCRAWLER_ALWAYS) || HAS_TRAIT(A, TRAIT_VENTCRAWLER_ITEM_BASED) || HAS_TRAIT(A, TRAIT_VENTCRAWLER_ALIEN))

#define is_multi_tile_object(atom) (atom.bound_width > world.icon_size || atom.bound_height > world.icon_size)
