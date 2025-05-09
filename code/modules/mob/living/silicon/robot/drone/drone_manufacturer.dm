/obj/machinery/drone_fabricator
	name = "drone fabricator"
	desc = "A large automated factory for producing maintenance drones."
	icon = 'icons/obj/machines/drone_fab.dmi'
	icon_state = "drone_fab_idle"
	density = TRUE
	anchored = TRUE
	use_power = IDLE_POWER_USE
	idle_power_usage = 20
	active_power_usage = 5000
	var/drone_progress = 0
	var/produce_drones = TRUE
	var/time_last_drone = 500


/obj/machinery/drone_fabricator/update_icon_state()
	if(stat & NOPOWER)
		icon_state = "drone_fab_nopower"
		return

	if(!produce_drones || (!drone_progress || drone_progress >= 100))
		icon_state = "drone_fab_idle"
		return

	icon_state = "drone_fab_active"


/obj/machinery/drone_fabricator/power_change(forced = FALSE)
	if(!..())
		return
	update_icon(UPDATE_ICON_STATE)


/obj/machinery/drone_fabricator/process()

	if(SSticker.current_state < GAME_STATE_PLAYING)
		return

	if((stat & NOPOWER) || !produce_drones)
		return

	if(drone_progress >= 100)
		if(icon_state != "drone_fab_idle")
			update_icon(UPDATE_ICON_STATE)
		return

	if(icon_state != "drone_fab_active")
		update_icon(UPDATE_ICON_STATE)
	var/elapsed = world.time - time_last_drone
	drone_progress = round((elapsed/CONFIG_GET(number/drone_build_time))*100)

	if(drone_progress >= 100)
		visible_message("\The [src] voices a strident beep, indicating a drone chassis is prepared.")

/obj/machinery/drone_fabricator/examine(mob/user)
	. = ..()
	if(produce_drones && drone_progress >= 100 && istype(user,/mob/dead) && CONFIG_GET(flag/allow_drone_spawn) && count_drones() < CONFIG_GET(number/max_maint_drones))
		. += "<span class='info'><br><b>A drone is prepared. Select 'Join As Drone' from the Ghost tab to spawn as a maintenance drone.</b></span>"

/obj/machinery/drone_fabricator/proc/count_drones()
	var/drones = 0
	for(var/mob/living/silicon/robot/drone/D in GLOB.silicon_mob_list)
		if(D.key && D.client)
			drones++
	return drones

/obj/machinery/drone_fabricator/proc/create_drone(var/client/player)

	if(stat & NOPOWER)
		return

	if(!produce_drones || !CONFIG_GET(flag/allow_drone_spawn) || count_drones() >= CONFIG_GET(number/max_maint_drones))
		return

	if(!player || !istype(player.mob,/mob/dead))
		return

	visible_message("\The [src] churns and grinds as it lurches into motion, disgorging a shiny new drone after a few moments.")
	flick("h_lathe_leave",src)

	time_last_drone = world.time
	var/mob/living/silicon/robot/drone/new_drone = new(get_turf(src))
	new_drone.transfer_personality(player)

	drone_progress = 0

/obj/machinery/drone_fabricator/attack_ghost(mob/dead/observer/user)
	user.become_drone()

/mob/dead/verb/join_as_drone()
	set category = "Ghost"
	set name = "Join As Drone"
	set desc = "If there is a powered, enabled fabricator in the game world with a prepared chassis, join as a maintenance drone."
	become_drone(src)

/mob/dead/proc/become_drone(mob/user)
	if(!(CONFIG_GET(flag/allow_drone_spawn)))
		to_chat(src, "<span class='warning'>That action is not currently permitted.</span>")
		return

	if(!src.stat)
		return

	if(usr != src)
		return 0 //something is terribly wrong

	if(jobban_isbanned(src,"nonhumandept") || jobban_isbanned(src,"Drone"))
		to_chat(usr, "<span class='warning'>You are banned from playing drones and cannot spawn as a drone.</span>")
		return

	if(!SSticker || SSticker.current_state < 3)
		to_chat(src, "<span class='warning'>You can't join as a drone before the game starts!</span>")
		return

	var/drone_age = 14 // 14 days to play as a drone
	var/player_age_check = check_client_age(usr.client, drone_age)
	if(player_age_check && CONFIG_GET(flag/use_age_restriction_for_antags))
		to_chat(usr, "<span class='warning'>This role is not yet available to you. You need to wait another [player_age_check] days.</span>")
		return

	var/pt_req = role_available_in_playtime(client, ROLE_DRONE)
	if(pt_req)
		var/pt_req_string = get_exp_format(pt_req)
		to_chat(usr, "<span class='warning'>This role is not yet available to you. Play another [pt_req_string] to unlock it.</span>")
		return

	var/deathtime = world.time - src.timeofdeath
	var/joinedasobserver = 0
	if(istype(src,/mob/dead/observer))
		var/mob/dead/observer/G = src
		if(cannotPossess(G))
			to_chat(usr, "<span class='warning'>Upon using the antagHUD you forfeited the ability to join the round.</span>")
			return
		if(G.started_as_observer == 1)
			joinedasobserver = 1

	var/deathtimeminutes = round(deathtime / 600)
	var/pluralcheck = "minute"
	if(deathtimeminutes == 0)
		pluralcheck = ""
	else if(deathtimeminutes == 1)
		pluralcheck = " [deathtimeminutes] minute and"
	else if(deathtimeminutes > 1)
		pluralcheck = " [deathtimeminutes] minutes and"
	var/deathtimeseconds = round((deathtime - deathtimeminutes * 600) / 10,1)

	if(deathtimeminutes < CONFIG_GET(number/respawn_delay_drone) && joinedasobserver == 0)
		to_chat(usr, "You have been dead for[pluralcheck] [deathtimeseconds] seconds.")
		to_chat(usr, "<span class='warning'>You must wait [CONFIG_GET(number/respawn_delay_drone)] minutes to respawn as a drone!</span>")
		return

	if(tgui_alert(usr, "Are you sure you want to respawn as a drone?", "Are you sure?", list("Yes", "No")) != "Yes")
		return

	for(var/obj/machinery/drone_fabricator/DF in GLOB.machines)
		if(DF.stat & NOPOWER || !DF.produce_drones)
			continue

		if(DF.count_drones() >= CONFIG_GET(number/max_maint_drones))
			to_chat(src, "<span class='warning'>There are too many active drones in the world for you to spawn.</span>")
			return

		if(DF.drone_progress >= 100)
			DF.create_drone(src.client)
			return

	to_chat(src, "<span class='warning'>There are no available drone spawn points, sorry.</span>")
