/obj/item/gun/projectile/automatic/l6_saw
	name = "\improper L6 SAW"
	desc = "A heavily modified 5.56 light machine gun, designated 'L6 SAW'. Has 'Aussec Armoury - 2531' engraved on the receiver below the designation."
	icon_state = "l6closed100"
	item_state = "l6closedmag"
	w_class = WEIGHT_CLASS_HUGE
	slot_flags = 0
	origin_tech = "combat=6;engineering=3;syndicate=6"
	mag_type = /obj/item/ammo_box/magazine/mm556x45
	weapon_weight = WEAPON_HEAVY
	fire_sound = 'sound/weapons/gunshots/1mg2.ogg'
	magin_sound = 'sound/weapons/gun_interactions/lmg_magin.ogg'
	magout_sound = 'sound/weapons/gun_interactions/lmg_magout.ogg'
	var/cover_open = 0
	can_suppress = 0
	fire_delay = 1
	burst_size = 1
	actions_types = null

/obj/item/gun/projectile/automatic/l6_saw/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/automatic_fire, 0.2 SECONDS)

/obj/item/gun/projectile/automatic/l6_saw/attack_self(mob/user)
	cover_open = !cover_open
	balloon_alert(user, "крышка [cover_open ? "от" : "за"]крыта")
	playsound(src, cover_open ? 'sound/weapons/gun_interactions/sawopen.ogg' : 'sound/weapons/gun_interactions/sawclose.ogg', 50, 1)
	update_icon()


/obj/item/gun/projectile/automatic/l6_saw/update_icon_state()
	icon_state = "l6[cover_open ? "open" : "closed"][magazine ? CEILING(get_ammo(FALSE)/25, 1)*25 : "-empty"][suppressed ? "-suppressed" : ""]"
	item_state = "l6[cover_open ? "openmag" : "closedmag"]"


/obj/item/gun/projectile/automatic/l6_saw/can_shoot(mob/user)
	if(cover_open)
		balloon_alert(user, "крышка не закрыта!")
		return FALSE
	return ..()


/obj/item/gun/projectile/automatic/l6_saw/attack_hand(mob/user)
	if(loc != user)
		..()
		return	//let them pick it up
	if(!cover_open || (cover_open && !magazine))
		..()
	else if(cover_open && magazine)
		//drop the mag
		magazine.update_appearance(UPDATE_ICON | UPDATE_DESC)
		magazine.forceMove(drop_location())
		user.put_in_hands(magazine)
		magazine = null
		playsound(src, magout_sound, 50, 1)
		update_icon()
		balloon_alert(user, "магазин вынут")


/obj/item/gun/projectile/automatic/l6_saw/attackby(obj/item/I, mob/user, params)
	if(istype(I, mag_type) && !cover_open)
		balloon_alert(user, "крышка закрыта!")
		return ATTACK_CHAIN_PROCEED
	return ..()


//ammo//

/obj/projectile/bullet/saw
	damage = 45
	armour_penetration = 5

/obj/projectile/bullet/saw/weak
	damage = 30

/obj/projectile/bullet/saw/bleeding
	damage = 20
	armour_penetration = 0

/obj/projectile/bullet/saw/bleeding/on_hit(atom/target, blocked = 0, hit_zone)
	. = ..()
	if((blocked != 100) && iscarbon(target))
		var/mob/living/carbon/C = target
		C.bleed(35)

/obj/projectile/bullet/saw/hollow
	damage = 60
	armour_penetration = -10

/obj/projectile/bullet/saw/ap
	damage = 40
	armour_penetration = 75

/obj/projectile/bullet/saw/incen
	damage = 7
	armour_penetration = 0

/obj/projectile/bullet/saw/incen/Move(atom/newloc, direct = NONE, glide_size_override = 0, update_dir = TRUE)
	. = ..()
	var/turf/location = get_turf(src)
	if(location)
		new /obj/effect/hotspot(location)
		location.hotspot_expose(700, 50, 1)

/obj/projectile/bullet/saw/incen/on_hit(atom/target, blocked = 0)
	. = ..()
	if(iscarbon(target))
		var/mob/living/carbon/M = target
		M.adjust_fire_stacks(3)
		M.IgniteMob()

//magazines//

/obj/item/ammo_box/magazine/mm556x45
	name = "box magazine (5.56x45mm)"
	icon_state = "a762"
	origin_tech = "combat=2"
	ammo_type = /obj/item/ammo_casing/mm556x45/weak
	caliber = "mm55645"
	max_ammo = 100

/obj/item/ammo_box/magazine/mm556x45/bleeding
	name = "box magazine (Bleeding 5.56x45mm)"
	origin_tech = "combat=3"
	ammo_type = /obj/item/ammo_casing/mm556x45/bleeding

/obj/item/ammo_box/magazine/mm556x45/hollow
	name = "box magazine (Hollow-Point 5.56x45mm)"
	origin_tech = "combat=3"
	ammo_type = /obj/item/ammo_casing/mm556x45/hollow

/obj/item/ammo_box/magazine/mm556x45/ap
	name = "box magazine (Armor Penetrating 5.56x45mm)"
	origin_tech = "combat=4"
	ammo_type = /obj/item/ammo_casing/mm556x45/ap

/obj/item/ammo_box/magazine/mm556x45/incen
	name = "box magazine (Incendiary 5.56x45mm)"
	origin_tech = "combat=4"
	ammo_type = /obj/item/ammo_casing/mm556x45/incen

/obj/item/ammo_box/magazine/mm556x45/update_icon_state()
	icon_state = "a762-[round(ammo_count(), 20)]"

//casings//

/obj/item/ammo_casing/mm556x45
	desc = "A 556x45mm bullet casing."
	icon_state = "762-casing"
	caliber = "mm55645"
	projectile_type = /obj/projectile/bullet/saw
	muzzle_flash_strength = MUZZLE_FLASH_STRENGTH_STRONG
	muzzle_flash_range = MUZZLE_FLASH_RANGE_STRONG

/obj/item/ammo_casing/mm556x45/weak
	projectile_type = /obj/projectile/bullet/saw/weak

/obj/item/ammo_casing/mm556x45/bleeding
	desc = "A 556x45mm bullet casing with specialized inner-casing, that when it makes contact with a target, release tiny shrapnel to induce internal bleeding."
	icon_state = "762-casing"
	projectile_type = /obj/projectile/bullet/saw/bleeding

/obj/item/ammo_casing/mm556x45/hollow
	desc = "A 556x45mm bullet casing designed to cause more damage to unarmored targets."
	projectile_type = /obj/projectile/bullet/saw/hollow

/obj/item/ammo_casing/mm556x45/ap
	desc = "A 556x45mm bullet casing designed with a hardened-tipped core to help penetrate armored targets."
	projectile_type = /obj/projectile/bullet/saw/ap

/obj/item/ammo_casing/mm556x45/incen
	desc = "A 556x45mm bullet casing designed with a chemical-filled capsule on the tip that when bursted, reacts with the atmosphere to produce a fireball, engulfing the target in flames. "
	projectile_type = /obj/projectile/bullet/saw/incen
	muzzle_flash_color = LIGHT_COLOR_FIRE
