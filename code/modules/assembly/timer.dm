/obj/item/assembly/timer
	name = "timer"
	desc = "Used to time things. Works well with contraptions which has to count down. Tick tock."
	icon_state = "timer"
	materials = list(MAT_METAL=500, MAT_GLASS=50)
	origin_tech = "magnets=1;engineering=1"

	secured = FALSE

	bomb_name = "time bomb"

	var/timing = FALSE
	var/time = 10
	var/repeat = FALSE
	var/set_time = 10
	var/mob/user // for logging


/obj/item/assembly/timer/Destroy()
	user = null
	return ..()

/obj/item/assembly/timer/examine(mob/user)
	. = ..()
	if(timing)
		. += span_notice("The timer is counting down from [time]!")
	else
		. += span_notice("The timer is set for [time] seconds.")


/obj/item/assembly/timer/activate()
	if(!..())
		return FALSE//Cooldown check
	timing = !timing
	update_icon()
	return FALSE


/obj/item/assembly/timer/toggle_secure()
	secured = !secured
	if(secured)
		START_PROCESSING(SSobj, src)
	else
		timing = FALSE
		STOP_PROCESSING(SSobj, src)
	update_icon()
	return secured


/obj/item/assembly/timer/proc/timer_end()
	if(!secured || cooldown > 0)
		return FALSE
	cooldown = 2
	pulse(FALSE, user)
	update_icon()
	if(loc)
		loc.visible_message("[bicon(src)] *beep* *beep*", "*beep* *beep*")
	addtimer(CALLBACK(src, PROC_REF(process_cooldown)), 10)


/obj/item/assembly/timer/process()
	if(timing && (time > 0))
		time -= 2 // 2 seconds per process()
	if(timing && time <= 0)
		timing = repeat
		timer_end()
		time = set_time


/obj/item/assembly/timer/update_overlays()
	. = ..()
	attached_overlays = list()
	if(timing)
		. += "timer_timing"
		attached_overlays += "timer_timing"
	holder?.update_icon()


/obj/item/assembly/timer/interact(mob/user)//TODO: Have this use the wires
	if(!secured)
		user.show_message(span_warning("The [name] is unsecured!"))
		return FALSE
	var/second = time % 60
	var/minute = (time - second) / 60
	var/set_second = set_time % 60
	var/set_minute = (set_time - set_second) / 60
	if(second < 10) second = "0[second]"
	if(set_second < 10) set_second = "0[set_second]"

	var/dat = {"
	<tt>
		<center><h2>Timing Unit</h2>
		[minute]:[second] <a href='byond://?src=[UID()];time=1'>[timing?"Stop":"Start"]</a> <a href='byond://?src=[UID()];reset=1'>Reset</a><br>
		Repeat: <a href='byond://?src=[UID()];repeat=1'>[repeat?"On":"Off"]</a><br>
		Timer set for
		<a href='byond://?src=[UID()];tp=-30'>-</a> <a href='byond://?src=[UID()];tp=-1'>-</a> [set_minute]:[set_second] <a href='byond://?src=[UID()];tp=1'>+</a> <a href='byond://?src=[UID()];tp=30'>+</a>
		</center>
	</tt>
	<br><br>
	<a href='byond://?src=[UID()];refresh=1'>Refresh</a>
	<br><br>
	<a href='byond://?src=[UID()];close=1'>Close</a>"}
	var/datum/browser/popup = new(user, "timer", name, 400, 400, src)
	popup.set_content(dat)
	popup.open()


/obj/item/assembly/timer/Topic(href, href_list)
	..()
	if(usr.incapacitated() || HAS_TRAIT(usr, TRAIT_HANDS_BLOCKED) || !in_range(loc, usr))
		close_window(usr, "timer")
		onclose(usr, "timer")
		return

	if(href_list["time"])
		timing = !timing
		user = usr
		if(timing && istype(holder, /obj/item/transfer_valve))
			investigate_log("[key_name_log(usr)] activated [src] attachment for [loc]", INVESTIGATE_BOMB)
			add_attack_logs(usr, holder, "activated [src] attachment on", ATKLOG_FEW)
		update_icon()
	if(href_list["reset"])
		time = set_time

	if(href_list["repeat"])
		repeat = !repeat

	if(href_list["tp"])
		var/tp = text2num(href_list["tp"])
		set_time += tp
		set_time = min(max(round(set_time), 6), 600)
		if(!timing)
			time = set_time

	if(href_list["close"])
		close_window(usr, "timer")
		return

	if(usr)
		attack_self(usr)
