/obj/item/transfer_valve
	icon = 'icons/obj/assemblies.dmi'
	name = "tank transfer valve"
	icon_state = "valve_1"
	item_state = "ttv"
	desc = "Regulates the transfer of air between two tanks"
	var/obj/item/tank/tank_one = null
	var/obj/item/tank/tank_two = null
	var/obj/item/assembly/attached_device = null
	var/mob/living/attacher = null
	var/valve_open = 0
	var/toggle = 1
	origin_tech = "materials=1;engineering=1"

/obj/item/transfer_valve/Destroy()
	QDEL_NULL(tank_one)
	QDEL_NULL(tank_two)
	QDEL_NULL(attached_device)
	attacher = null
	return ..()


/obj/item/transfer_valve/attackby(obj/item/I, mob/user, params)
	if(istype(I, /obj/item/tank))
		add_fingerprint(user)
		if(tank_one && tank_two)
			to_chat(user, span_warning("There are already two tanks attached, remove one first."))
			return ATTACK_CHAIN_PROCEED
		if(!user.drop_transfer_item_to_loc(I, src))
			return ..()
		to_chat(user,  span_notice("You attach the tank to the transfer valve."))
		if(tank_one)
			tank_two = I
		else
			tank_one = I
		if(I.w_class > w_class)
			w_class = I.w_class
		update_icon()
		SStgui.update_uis(src)
		return ATTACK_CHAIN_BLOCKED_ALL

	//TODO: Have this take an assemblyholder
	if(isassembly(I))
		add_fingerprint(user)
		var/obj/item/assembly/assembly = I
		if(attached_device)
			to_chat(user, span_warning("There is already [attached_device] attached to the valve, remove it first."))
			return ATTACK_CHAIN_PROCEED
		if(assembly.secured)
			to_chat(user, span_warning("The device should not be secured."))
			return ATTACK_CHAIN_PROCEED
		if(!user.drop_transfer_item_to_loc(assembly, src))
			return ..()
		attached_device = assembly
		to_chat(user, span_notice("You attach [assembly] to the valve controls and secure it."))
		assembly.holder = src
		assembly.toggle_secure()	//this calls update_icon(), which calls update_icon() on the holder (i.e. the bomb).
		if(isprox(assembly))
			AddComponent(/datum/component/proximity_monitor)
		investigate_log("[key_name_log(user)] attached [assembly] to a transfer valve.", INVESTIGATE_BOMB)
		add_attack_logs(user, src, "attached [assembly] to a transfer valve", ATKLOG_FEW)
		add_game_logs("attached [assembly] to a transfer valve.", user)
		attacher = user
		SStgui.update_uis(src) // update all UIs attached to src
		return ATTACK_CHAIN_BLOCKED_ALL

	return ..()


/obj/item/transfer_valve/HasProximity(atom/movable/AM)
	if(!attached_device)
		return
	attached_device.HasProximity(AM)

/obj/item/transfer_valve/hear_talk(mob/living/M, list/message_pieces)
	..()
	for(var/obj/O in contents)
		O.hear_talk(M, message_pieces)

/obj/item/transfer_valve/hear_message(mob/living/M, msg)
	..()
	for(var/obj/O in contents)
		O.hear_message(M, msg)

/obj/item/transfer_valve/attack_self(mob/user)
	ui_interact(user)

/obj/item/transfer_valve/ui_state(mob/user)
	return GLOB.inventory_state

/obj/item/transfer_valve/ui_interact(mob/user, datum/tgui/ui = null)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "TransferValve", name)
		ui.open()

/obj/item/transfer_valve/ui_data(mob/user)
	var/list/data = list()
	data["tank_one"] = tank_one ? tank_one.name : null
	data["tank_two"] = tank_two ? tank_two.name : null
	data["attached_device"] = attached_device ? attached_device.name : null
	data["valve"] = valve_open
	return data



/obj/item/transfer_valve/ui_act(action, params)
	if(..())
		return
	. = TRUE
	switch(action)
		if("tankone")
			if(tank_one)
				split_gases()
				valve_open = FALSE
				tank_one.forceMove_turf()
				usr?.put_in_hands(tank_one, ignore_anim = FALSE)
				tank_one = null
				update_icon()
				if((!tank_two || tank_two.w_class < WEIGHT_CLASS_BULKY) && (w_class > WEIGHT_CLASS_NORMAL))
					w_class = WEIGHT_CLASS_NORMAL
		if("tanktwo")
			if(tank_two)
				split_gases()
				valve_open = FALSE
				tank_two.forceMove_turf()
				usr?.put_in_hands(tank_two, ignore_anim = FALSE)
				tank_two = null
				update_icon()
				if((!tank_one || tank_one.w_class < WEIGHT_CLASS_BULKY) && (w_class > WEIGHT_CLASS_NORMAL))
					w_class = WEIGHT_CLASS_NORMAL
		if("toggle")
			toggle_valve(usr)
		if("device")
			if(attached_device)
				attached_device.attack_self(usr)
		if("remove_device")
			if(attached_device)
				attached_device.forceMove_turf()
				usr?.put_in_hands(attached_device, ignore_anim = FALSE)
				attached_device.holder = null
				attached_device = null
				qdel(GetComponent(/datum/component/proximity_monitor))
				update_icon()
		else
			. = FALSE
	if(.)
		update_icon()
		add_fingerprint(usr)


/obj/item/transfer_valve/proc/process_activation(obj/item/D, normal = TRUE, special = TRUE, mob/user)
	if(toggle)
		toggle = FALSE
		toggle_valve(user)
		addtimer(VARSET_CALLBACK(src, toggle, TRUE), 5 SECONDS)	// To stop a signal being spammed from a proxy sensor constantly going off or whatever


/obj/item/transfer_valve/update_icon_state()
	if(!tank_one && !tank_two && !attached_device)
		icon_state = "valve_1"
	else
		icon_state = "valve"


/obj/item/transfer_valve/update_overlays()
	. = ..()
	underlays.Cut()
	if(!tank_one && !tank_two && !attached_device)
		return
	if(tank_one)
		. += "[tank_one.icon_state]"
	if(tank_two)
		var/icon/J = new(icon, icon_state = "[tank_two.icon_state]")
		J.Shift(WEST, 13)
		underlays += J
	if(attached_device)
		. += "device"


/obj/item/transfer_valve/proc/merge_gases()
	tank_two.air_contents.volume += tank_one.air_contents.volume
	var/datum/gas_mixture/temp
	temp = tank_one.air_contents.remove_ratio(1)
	tank_two.air_contents.merge(temp)

/obj/item/transfer_valve/proc/split_gases()
	if(!valve_open || !tank_one || !tank_two)
		return
	var/ratio1 = tank_one.air_contents.volume/tank_two.air_contents.volume
	var/datum/gas_mixture/temp
	temp = tank_two.air_contents.remove_ratio(ratio1)
	tank_one.air_contents.merge(temp)
	tank_two.air_contents.volume -=  tank_one.air_contents.volume

	/*
	Exadv1: I know this isn't how it's going to work, but this was just to check
	it explodes properly when it gets a signal (and it does).
	*/

/obj/item/transfer_valve/proc/toggle_valve(mob/user)
	if(!valve_open && tank_one && tank_two)
		valve_open = TRUE
		var/turf/bombturf = get_turf(src)


		var/mob/mob = get_mob_by_key(src.fingerprintslast)

		investigate_log("Bomb valve opened with [attached_device ? attached_device : "no device"], attached by [key_name_log(attacher)]. Last touched by: [key_name_log(mob)][user ? ". Activated by [key_name_log(user)]" : null]", INVESTIGATE_BOMB)
		message_admins("Bomb valve opened at [ADMIN_COORDJMP(bombturf)] with [attached_device ? attached_device : "no device"], attached by [key_name_admin(attacher)]. Last touched by: [key_name_admin(mob)][user ? ". Activated by [key_name_admin(user)]" : null]")
		add_game_logs("Bomb valve opened at [AREACOORD(bombturf)] with [attached_device ? attached_device : "no device"], attached by [key_name_log(attacher)]. Last touched by: [key_name_log(mob)][user ? ". Activated by [key_name_log(user)]" : null]")
		if(user)
			add_attack_logs(user, src, "Bomb valve opened with [attached_device ? attached_device : "no device"], attached by [key_name_log(attacher)]. Last touched by: [key_name_log(mob)]", ATKLOG_FEW)
		merge_gases()
		addtimer(CALLBACK(src, PROC_REF(toggle_process)), 2 SECONDS)	// In case one tank bursts

	else if(valve_open && tank_one && tank_two)
		split_gases()
		valve_open = FALSE
		update_icon()


/obj/item/transfer_valve/proc/toggle_process()
	for(var/i in 1 to 5)
		update_icon()
		sleep(1 SECONDS)
	update_icon()


/obj/item/transfer_valve/blob_vore_act(obj/structure/blob/special/core/voring_core)
	obj_destruction(MELEE)

