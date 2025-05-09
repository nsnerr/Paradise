/obj/projectile/energy
	name = "energy"
	icon_state = "spark"
	damage = 0
	hitsound = 'sound/weapons/tap.ogg'
	damage_type = BURN
	flag = "energy"
	reflectability = REFLECTABILITY_ENERGY

/obj/projectile/energy/electrode
	name = "electrode"
	icon_state = "spark"
	color = "#FFFF00"
	shockbull = TRUE
	nodamage = TRUE
	weaken = 0.2 SECONDS
	stamina = 15
	stutter = 8 SECONDS
	jitter = 30 SECONDS
	hitsound = 'sound/weapons/tase.ogg'
	range = 7
	//Damage will be handled on the MOB side, to prevent window shattering.

/obj/projectile/energy/electrode/on_hit(var/atom/target, var/blocked = 0)
	. = ..()
	if(!ismob(target) || blocked >= 100) //Fully blocked by mob or collided with dense object - burst into sparks!
		do_sparks(1, 1, src)
	else if(iscarbon(target))
		var/mob/living/carbon/C = target
		if(HAS_TRAIT(C, TRAIT_HULK))
			C.say(pick(";RAAAAAAAARGH!", ";HNNNNNNNNNGGGGGGH!", ";GWAAAAAAAARRRHHH!", "NNNNNNNNGGGGGGGGHH!", ";AAAAAAARRRGH!" ))
		else if(C.status_flags & CANWEAKEN)
			spawn(5)
				C.Jitter(jitter)

/obj/projectile/energy/electrode/on_range() //to ensure the bolt sparks when it reaches the end of its range if it didn't hit a target yet
	do_sparks(1, 1, src)
	..()

/obj/projectile/energy/electrode/dominator
	color = LIGHT_COLOR_LIGHT_CYAN

/obj/projectile/energy/electrode/advanced
	stun = 10 SECONDS
	weaken =  10 SECONDS

/obj/projectile/energy/declone
	name = "declone"
	icon_state = "declone"
	damage = 20
	hitsound = 'sound/weapons/plasma_cutter.ogg'
	damage_type = CLONE
	irradiate = 10
	impact_effect_type = /obj/effect/temp_visual/impact_effect/green_laser

/obj/projectile/energy/dart
	name = "dart"
	icon_state = "toxin"
	damage = 1
	damage_type = TOX
	weaken = 4 SECONDS
	stamina = 40
	range = 7
	shockbull = TRUE

/obj/projectile/energy/bolt
	name = "bolt"
	icon_state = "cbbolt"
	damage = 15
	hitsound = 'sound/weapons/pierce.ogg'
	damage_type = TOX
	stamina = 40
	nodamage = FALSE
	weaken = 3 SECONDS
	stutter = 2 SECONDS
	shockbull = TRUE

/obj/projectile/energy/bolt/on_hit(atom/target)
	. = ..()
	var/mob/living/simple_animal/hostile/carp/carp = target
	if(istype(carp))
		carp.gib()

/obj/projectile/energy/bolt/large
	damage = 20
	weaken = 0.1 SECONDS
	stamina = 30

/obj/projectile/energy/bolttoy
	name = "bolttoy"
	icon_state = "cbbolttoy"
	hitsound = 'sound/weapons/pierce.ogg'
	damage_type = STAMINA
	nodamage = TRUE
	weaken = 0.1 SECONDS
	stutter = 2 SECONDS
	shockbull = TRUE

/obj/projectile/energy/shock_revolver
	name = "shock bolt"
	icon_state = "purple_laser"
	impact_effect_type = /obj/effect/temp_visual/impact_effect/purple_laser

/obj/item/ammo_casing/energy/shock_revolver/ready_proj(atom/target, mob/living/user, quiet, zone_override = "")
	..()
	var/obj/projectile/energy/shock_revolver/P = BB
	spawn(1)
		P.chain = P.Beam(user,icon_state="purple_lightning",icon = 'icons/effects/effects.dmi',time=1000, maxdistance = 30)

/obj/projectile/energy/shock_revolver/on_hit(atom/target)
	. = ..()
	if(isliving(target))
		tesla_zap(src, 3, 10000)
	qdel(chain)

/obj/projectile/energy/toxplasma
	name = "toxin bolt"
	icon_state = "energy"
	damage = 20
	hitsound = 'sound/weapons/plasma_cutter.ogg'
	damage_type = TOX
	irradiate = 20

/obj/projectile/energy/weak_plasma
	name = "plasma bolt"
	icon_state = "plasma_light"
	damage = 20
	damage_type = BURN

/obj/projectile/energy/charged_plasma
	name = "charged plasma bolt"
	icon_state = "plasma_heavy"
	damage = 50
	damage_type = BURN
	armour_penetration = 10 // It can have a little armor pen, as a treat. Bigger than it looks, energy armor is often low.
	shield_buster = TRUE
	reflectability = REFLECTABILITY_NEVER //I will let eswords block it like a normal projectile, but it's not getting reflected, and eshields will take the hit hard.
