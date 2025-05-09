/*
	New methods:
	pulse - sends a pulse into a wire for hacking purposes
	cut - cuts a wire and makes any necessary state changes
	mend - mends a wire and makes any necessary state changes
	canAIControl - 1 if the AI can control the airlock, 0 if not (then check canAIHack to see if it can hack in)
	canAIHack - 1 if the AI can hack into the airlock to recover control, 0 if not. Also returns 0 if the AI does not *need* to hack it.
	arePowerSystemsOn - 1 if the main or backup power are functioning, 0 if not.
	requiresIDs - 1 if the airlock is requiring IDs, 0 if not
	isAllPowerCut - 1 if the main and backup power both have cut wires.
	regainMainPower - handles the effect of main power coming back on.
	loseMainPower - handles the effect of main power going offline. Usually (if one isn't already running) spawn a thread to count down how long it will be offline - counting down won't happen if main power was completely cut along with backup power, though, the thread will just sleep.
	loseBackupPower - handles the effect of backup power going offline.
	regainBackupPower - handles the effect of main power coming back on.
	shock - has a chance of electrocuting its target.
*/


// Wires for the airlock are located in the datum folder, inside the wires datum folder.

#define AIRLOCK_CLOSED	1
#define AIRLOCK_CLOSING	2
#define AIRLOCK_OPEN	3
#define AIRLOCK_OPENING	4
#define AIRLOCK_DENY	5
#define AIRLOCK_EMAG	6

#define AIRLOCK_SECURITY_NONE			0 //Normal airlock				//Wires are not secured
#define AIRLOCK_SECURITY_METAL			1 //Medium security airlock		//There is a simple metal over wires (use welder)
#define AIRLOCK_SECURITY_PLASTEEL_I_S	2 								//Sliced inner plating (use crowbar), jumps to 0
#define AIRLOCK_SECURITY_PLASTEEL_I		3 								//Removed outer plating, second layer here (use welder)
#define AIRLOCK_SECURITY_PLASTEEL_O_S	4 								//Sliced outer plating (use crowbar)
#define AIRLOCK_SECURITY_PLASTEEL_O		5 								//There is first layer of plasteel (use welder)
#define AIRLOCK_SECURITY_PLASTEEL		6 //Max security airlock		//Fully secured wires (use wirecutters to remove grille, that is electrified)

#define AIRLOCK_INTEGRITY_N			 300 // Normal airlock integrity
#define AIRLOCK_INTEGRITY_MULTIPLIER 1.5 // How much reinforced doors health increases
#define AIRLOCK_DAMAGE_DEFLECTION_N  21  // Normal airlock damage deflection
#define AIRLOCK_DAMAGE_DEFLECTION_R  30  // Reinforced airlock damage deflection

#define UI_GREEN 2
#define UI_ORANGE 1
#define UI_RED 0

GLOBAL_LIST_EMPTY(restricted_door_tags)
GLOBAL_LIST_EMPTY(airlock_overlays)
GLOBAL_LIST_EMPTY(airlock_emissive_underlays)

/obj/machinery/door/airlock
	name = "airlock"
	icon = 'icons/obj/doors/airlocks/station/public.dmi'
	icon_state = "closed"
	anchored = TRUE
	max_integrity = 300
	integrity_failure = 70
	damage_deflection = AIRLOCK_DAMAGE_DEFLECTION_N
	autoclose = TRUE
	explosion_block = 1
	assemblytype = /obj/structure/door_assembly
	siemens_strength = 1
	smoothing_groups = SMOOTH_GROUP_AIRLOCK
	interaction_flags_click = ALLOW_SILICON_REACH

	var/security_level = 0 //How much are wires secured
	var/aiControlDisabled = AICONTROLDISABLED_OFF
	var/hackProof = FALSE // if TRUE, this door can't be hacked by the AI
	var/electrified_until = 0	// World time when the door is no longer electrified. -1 if it is permanently electrified until someone fixes it.
	var/main_power_lost_until = 0	 //World time when main power is restored.
	var/backup_power_lost_until = -1 //World time when backup power is restored.
	var/electrified_timer
	var/main_power_timer
	var/backup_power_timer
	var/spawnPowerRestoreRunning = 0
	var/lights = TRUE // bolt lights show by default
	var/datum/wires/airlock/wires
	var/aiDisabledIdScanner = FALSE
	var/aiHacking = FALSE
	var/obj/machinery/door/airlock/closeOther
	var/closeOtherId
	var/lockdownbyai = FALSE
	var/justzap = FALSE
	var/obj/item/airlock_electronics/airlock_electronics
	var/obj/item/access_control/access_electronics
	var/has_access_electronics = TRUE
	var/shockCooldown = FALSE //Prevents multiple shocks from happening
	var/obj/item/note //Any papers pinned to the airlock
	var/previous_airlock = /obj/structure/door_assembly //what airlock assembly mineral plating was applied to
	var/airlock_material //material of inner filling; if its an airlock with glass, this should be set to "glass"
	var/overlays_file = 'icons/obj/doors/airlocks/station/overlays.dmi'
	var/note_overlay_file = 'icons/obj/doors/airlocks/station/overlays.dmi' //Used for papers and photos pinned to the airlock
	var/normal_integrity = AIRLOCK_INTEGRITY_N
	var/paintable = TRUE // If the airlock type can be painted with an airlock painter
	var/id //ID for tint controlle

	var/mutable_appearance/old_buttons_underlay
	var/mutable_appearance/old_lights_underlay
	var/mutable_appearance/old_damag_underlay
	var/mutable_appearance/old_sparks_underlay

	var/doorOpen = 'sound/machines/airlock_open.ogg'
	var/doorClose = 'sound/machines/airlock_close.ogg'
	var/doorDeni = 'sound/machines/deniedbeep.ogg' // i'm thinkin' Deni's
	var/boltUp = 'sound/machines/boltsup.ogg'
	var/boltDown = 'sound/machines/boltsdown.ogg'
	var/is_special = FALSE

/obj/machinery/door/airlock/welded
	welded = TRUE
/*
About the new airlock wires panel:
*	An airlock wire dialog can be accessed by the normal way or by using wirecutters or a multitool on the door while the wire-panel is open. This would show the following wires, which you can either wirecut/mend or send a multitool pulse through. There are 9 wires.
*		one wire from the ID scanner. Sending a pulse through this flashes the red light on the door (if the door has power). If you cut this wire, the door will stop recognizing valid IDs. (If the door has 0000 access, it still opens and closes, though)
*		two wires for power. Sending a pulse through either one causes a breaker to trip, disabling the door for 10 seconds if backup power is connected, or 1 minute if not (or until backup power comes back on, whichever is shorter). Cutting either one disables the main door power, but unless backup power is also cut, the backup power re-powers the door in 10 seconds. While unpowered, the door may be open, but bolts-raising will not work. Cutting these wires may electrocute the user.
*		one wire for door bolts. Sending a pulse through this drops door bolts (whether the door is powered or not) or raises them (if it is). Cutting this wire also drops the door bolts, and mending it does not raise them. If the wire is cut, trying to raise the door bolts will not work.
*		two wires for backup power. Sending a pulse through either one causes a breaker to trip, but this does not disable it unless main power is down too (in which case it is disabled for 1 minute or however long it takes main power to come back, whichever is shorter). Cutting either one disables the backup door power (allowing it to be crowbarred open, but disabling bolts-raising), but may electocute the user.
*		one wire for opening the door. Sending a pulse through this while the door has power makes it open the door if no access is required.
*		one wire for AI control. Sending a pulse through this blocks AI control for a second or so (which is enough to see the AI control light on the panel dialog go off and back on again). Cutting this prevents the AI from controlling the door unless it has hacked the door through the power connection (which takes about a minute). If both main and backup power are cut, as well as this wire, then the AI cannot operate or hack the door at all.
*		one wire for electrifying the door. Sending a pulse through this electrifies the door for 30 seconds. Cutting this wire electrifies the door, so that the next person to touch the door without insulated gloves gets electrocuted. (Currently it is also STAYING electrified until someone mends the wire)
*		one wire for controling door safetys.  When active, door does not close on someone.  When cut, door will ruin someone's shit.  When pulsed, door will immedately ruin someone's shit.
*		one wire for controlling door speed.  When active, dor closes at normal rate.  When cut, door does not close manually.  When pulsed, door attempts to close every tick.
*/
// You can find code for the airlock wires in the wire datum folder.

/obj/machinery/door/airlock/New()
	..()
	wires = new(src)
	if(SSradio)
		set_frequency(frequency)

/*
 * reimp, imitate an access denied event.
 */
/obj/machinery/door/airlock/flicker()
	if(density && !operating && arePowerSystemsOn())
		INVOKE_ASYNC(src, PROC_REF(do_animate), "deny")
		return TRUE

	return FALSE

/obj/machinery/door/airlock/Initialize(mapload)
	. = ..()
	if(frequency)
		set_frequency(frequency)

	if(mapload && id_tag && !(id_tag in GLOB.restricted_door_tags))
		// Players won't be allowed to create new buttons that open roundstart doors
		GLOB.restricted_door_tags += id_tag

	if(closeOtherId)
		addtimer(CALLBACK(src, PROC_REF(update_other_id)), 0.5 SECONDS)

	if(glass)
		airlock_material = "glass"

	if(security_level > AIRLOCK_SECURITY_METAL)
		obj_integrity = normal_integrity * AIRLOCK_INTEGRITY_MULTIPLIER
		max_integrity = normal_integrity * AIRLOCK_INTEGRITY_MULTIPLIER
	else
		obj_integrity = normal_integrity
		max_integrity = normal_integrity

	if(damage_deflection == AIRLOCK_DAMAGE_DEFLECTION_N && security_level > AIRLOCK_SECURITY_METAL)
		damage_deflection = AIRLOCK_DAMAGE_DEFLECTION_R

	update_icon()

// Remove shielding to prevent metal/plasteel duplication
/obj/machinery/door/airlock/proc/remove_shielding()
	security_level = AIRLOCK_SECURITY_NONE
	modify_max_integrity(normal_integrity)
	damage_deflection = AIRLOCK_DAMAGE_DEFLECTION_N

/obj/machinery/door/airlock/proc/update_other_id()
	for(var/obj/machinery/door/airlock/airlock in GLOB.airlocks)
		if(airlock.closeOtherId == closeOtherId && airlock != src)
			closeOther = airlock
			break

/obj/machinery/door/airlock/Destroy()
	SStgui.close_uis(wires)
	QDEL_NULL(airlock_electronics)
	QDEL_NULL(access_electronics)
	QDEL_NULL(wires)
	QDEL_NULL(note)
	if(main_power_timer)
		deltimer(main_power_timer)
		main_power_timer = null
	if(backup_power_timer)
		deltimer(backup_power_timer)
		backup_power_timer = null
	if(electrified_timer)
		deltimer(electrified_timer)
		electrified_timer = null
	if(SSradio)
		SSradio.remove_object(src, frequency)
	radio_connection = null
	return ..()

/obj/machinery/door/airlock/handle_atom_del(atom/A)
	if(A == note)
		note = null
		update_icon()


/obj/machinery/door/airlock/bumpopen(mob/living/user) //Airlocks now zap you when you 'bump' them open when they're electrified. --NeoFite
	if(!issilicon(user))
		if(isElectrified())
			if(justzap)
				return
			if(shock(user, 100))
				justzap = TRUE
				addtimer(VARSET_CALLBACK(src, justzap, FALSE), 1 SECONDS)
				return
		else if(!operating && user.AmountHallucinate() > 50 SECONDS && prob(10) && user.electrocute_act(50, "шлюза", flags = SHOCK_ILLUSION))
			return
	return ..()


/obj/machinery/door/airlock/proc/isElectrified()
	if(electrified_until != 0)
		return TRUE
	return FALSE

/obj/machinery/door/airlock/proc/canAIControl()
	return ((aiControlDisabled != AICONTROLDISABLED_ON) && (!isAllPowerLoss()))

/obj/machinery/door/airlock/proc/canAIHack()
	return ((aiControlDisabled == AICONTROLDISABLED_ON) && (!hackProof) && (!isAllPowerLoss()))

/obj/machinery/door/airlock/proc/arePowerSystemsOn()
	if(stat & (NOPOWER|BROKEN))
		return FALSE
	return (main_power_lost_until==0 || backup_power_lost_until==0)

/obj/machinery/door/airlock/requiresID()
	return !(wires.is_cut(WIRE_IDSCAN) || aiDisabledIdScanner)

/obj/machinery/door/airlock/proc/isAllPowerLoss()
	if(stat & (NOPOWER|BROKEN))
		return TRUE
	if(wires.is_cut(WIRE_MAIN_POWER1) && wires.is_cut(WIRE_BACKUP_POWER1))
		return TRUE
	return FALSE

/obj/machinery/door/airlock/proc/loseMainPower()
	main_power_lost_until = wires.is_cut(WIRE_MAIN_POWER1) ? -1 : world.time + 60 SECONDS
	if(main_power_lost_until > 0)
		main_power_timer = addtimer(CALLBACK(src, PROC_REF(regainMainPower)), 60 SECONDS, TIMER_UNIQUE | TIMER_STOPPABLE)
	// If backup power is permanently disabled then activate in 10 seconds if possible, otherwise it's already enabled or a timer is already running
	if(backup_power_lost_until == -1 && !wires.is_cut(WIRE_BACKUP_POWER1))
		backup_power_lost_until = world.time + 10 SECONDS
		backup_power_timer = addtimer(CALLBACK(src, PROC_REF(regainBackupPower)), 10 SECONDS, TIMER_UNIQUE | TIMER_STOPPABLE)
	// Disable electricity if required
	if(electrified_until && isAllPowerLoss())
		electrify(0)

/obj/machinery/door/airlock/proc/loseBackupPower()
	backup_power_lost_until = wires.is_cut(WIRE_BACKUP_POWER1) ? -1 : world.time + 60 SECONDS
	if(backup_power_lost_until > 0)
		backup_power_timer = addtimer(CALLBACK(src, PROC_REF(regainBackupPower)), 60 SECONDS, TIMER_UNIQUE | TIMER_STOPPABLE)

	// Disable electricity if required
	if(electrified_until && isAllPowerLoss())
		electrify(0)

/obj/machinery/door/airlock/proc/regainMainPower()
	main_power_timer = null

	if(!wires.is_cut(WIRE_MAIN_POWER1))
		main_power_lost_until = 0
		// If backup power is currently active then disable, otherwise let it count down and disable itself later
		if(!backup_power_lost_until)
			backup_power_lost_until = -1
		update_icon()

/obj/machinery/door/airlock/proc/regainBackupPower()
	backup_power_timer = null

	if(!wires.is_cut(WIRE_BACKUP_POWER1))
		// Restore backup power only if main power is offline, otherwise permanently disable
		backup_power_lost_until = main_power_lost_until == 0 ? -1 : 0
		update_icon()

/obj/machinery/door/airlock/proc/electrify(duration, mob/user = usr, feedback = FALSE)
	if(electrified_timer)
		deltimer(electrified_timer)
		electrified_timer = null

	var/message = ""
	if(wires.is_cut(WIRE_ELECTRIFY) && arePowerSystemsOn())
		message = text("The electrification wire is cut - Door permanently electrified.")
		electrified_until = -1
	else if(duration && !arePowerSystemsOn())
		message = text("The door is unpowered - Cannot electrify the door.")
		electrified_until = 0
	else if(!duration && electrified_until != 0)
		message = "The door is now un-electrified."
		electrified_until = 0
	else if(duration)	//electrify door for the given duration seconds
		if(user)
			shockedby += text("\[[time_stamp()]\] - [user](ckey:[user.ckey])")
			add_attack_logs(user, src, "Electrified", ATKLOG_ALL)
		else
			shockedby += text("\[[time_stamp()]\] - EMP)")
		message = "The door is now electrified [duration == -1 ? "permanently" : "for [duration] second\s"]."
		electrified_until = duration == -1 ? -1 : world.time + duration SECONDS
		if(duration != -1)
			electrified_timer = addtimer(CALLBACK(src, PROC_REF(electrify), 0), duration SECONDS, TIMER_UNIQUE | TIMER_STOPPABLE)
	if(feedback && message)
		to_chat(user, message)

// shock user with probability prb (if all connections & power are working)
// returns 1 if shocked, 0 otherwise
// The preceding comment was borrowed from the grille's shock script
/obj/machinery/door/airlock/shock(mob/living/user, prb)
	if(!istype(user) || !arePowerSystemsOn())
		return FALSE
	if(shockCooldown > world.time)
		return FALSE	//Already shocked someone recently?
	if(..())
		shockCooldown = world.time + 10
		return TRUE
	else
		return FALSE

//Checks if the user can get shocked and shocks him if it can. Returns TRUE if it happened
/obj/machinery/door/airlock/proc/shock_user(mob/user, prob)
	return (!issilicon(user) && isElectrified() && shock(user, prob))


/obj/machinery/door/airlock/update_icon(state = NONE, override = FALSE)
	if(operating && !override)
		return

	icon_state = density ? "closed" : "open"
	switch(state)
		if(NONE)
			if(density)
				state = AIRLOCK_CLOSED
			else
				state = AIRLOCK_OPEN
		if(AIRLOCK_DENY, AIRLOCK_OPENING, AIRLOCK_CLOSING, AIRLOCK_EMAG)
			icon_state = "nonexistenticonstate" //MADNESS

	. = ..(UPDATE_ICON_STATE) // Sent after the icon_state is changed

	set_airlock_overlays(state)
	SSdemo.mark_dirty(src)

/obj/machinery/door/airlock/update_icon_state()
	return


/obj/machinery/door/airlock/proc/set_airlock_overlays(state)
	var/image/frame_overlay
	var/image/filling_overlay
	var/image/lights_overlay
	var/image/panel_overlay
	var/image/weld_overlay
	var/image/damag_overlay
	var/image/sparks_overlay
	var/image/note_overlay
	var/notetype = note_type()
	var/mutable_appearance/buttons_underlay
	var/mutable_appearance/lights_underlay
	var/mutable_appearance/damag_underlay
	var/mutable_appearance/sparks_underlay
	switch(state)
		if(AIRLOCK_CLOSED)
			frame_overlay = get_airlock_overlay("closed", icon)
			buttons_underlay = get_airlock_emissive_underlay("closed_lightmask", overlays_file, src)
			if(airlock_material)
				filling_overlay = get_airlock_overlay("[airlock_material]_closed", overlays_file)
			else
				filling_overlay = get_airlock_overlay("fill_closed", icon)
			if(panel_open)
				buttons_underlay = null
				if(security_level)
					panel_overlay = get_airlock_overlay("panel_closed_protected", overlays_file)
				else
					panel_overlay = get_airlock_overlay("panel_closed", overlays_file)
			if(welded)
				weld_overlay = get_airlock_overlay("welded", overlays_file)
			if(obj_integrity <integrity_failure)
				damag_overlay = get_airlock_overlay("sparks_broken", overlays_file)
				damag_underlay = get_airlock_emissive_underlay( "sparks_broken_lightmask", overlays_file, src)
			else if(obj_integrity < (0.75 * max_integrity))
				damag_overlay = get_airlock_overlay("sparks_damaged", overlays_file)
				damag_underlay = get_airlock_emissive_underlay("sparks_damaged_lightmask", overlays_file, src)
			if(lights && arePowerSystemsOn())
				if(locked)
					lights_overlay = get_airlock_overlay("lights_bolts", overlays_file)
					lights_underlay = get_airlock_emissive_underlay("lights_bolts_lightmask", overlays_file, src)
				else if(emergency)
					lights_overlay = get_airlock_overlay("lights_emergency", overlays_file)
					lights_underlay = get_airlock_emissive_underlay("lights_emergency_lightmask", overlays_file, src)
			if(note)
				note_overlay = get_airlock_overlay(notetype, note_overlay_file)
				note_overlay.layer = layer + 0.1

		if(AIRLOCK_DENY)
			if(!arePowerSystemsOn())
				return
			frame_overlay = get_airlock_overlay("closed", icon)
			if(airlock_material)
				filling_overlay = get_airlock_overlay("[airlock_material]_closed", overlays_file)
			else
				filling_overlay = get_airlock_overlay("fill_closed", icon)
			if(panel_open)
				buttons_underlay = null
				if(security_level)
					panel_overlay = get_airlock_overlay("panel_closed_protected", overlays_file)
				else
					panel_overlay = get_airlock_overlay("panel_closed", overlays_file)
			if(obj_integrity <integrity_failure)
				damag_overlay = get_airlock_overlay("sparks_broken", overlays_file)
				damag_underlay = get_airlock_emissive_underlay( "sparks_broken_lightmask", overlays_file, src)
			else if(obj_integrity < (0.75 * max_integrity))
				damag_overlay = get_airlock_overlay("sparks_damaged", overlays_file)
				damag_underlay = get_airlock_emissive_underlay("sparks_damaged_lightmask", overlays_file, src)
			if(welded)
				weld_overlay = get_airlock_overlay("welded", overlays_file)
			lights_overlay = get_airlock_overlay("lights_denied", overlays_file)
			lights_underlay = get_airlock_emissive_underlay("lights_denied_lightmask", overlays_file, src)
			if(note)
				note_overlay = get_airlock_overlay(notetype, note_overlay_file)

		if(AIRLOCK_EMAG)
			frame_overlay = get_airlock_overlay("closed", icon)
			buttons_underlay = get_airlock_emissive_underlay("closed_lightmask", overlays_file, src)
			sparks_overlay = get_airlock_overlay("sparks", overlays_file)
			sparks_underlay = get_airlock_emissive_underlay("sparks_lightmask", overlays_file, src)
			if(airlock_material)
				filling_overlay = get_airlock_overlay("[airlock_material]_closed", overlays_file)
			else
				filling_overlay = get_airlock_overlay("fill_closed", icon)
			if(panel_open)
				buttons_underlay = null
				if(security_level)
					panel_overlay = get_airlock_overlay("panel_closed_protected", overlays_file)
				else
					panel_overlay = get_airlock_overlay("panel_closed", overlays_file)
			if(obj_integrity <integrity_failure)
				damag_overlay = get_airlock_overlay("sparks_broken", overlays_file)
				damag_underlay = get_airlock_emissive_underlay( "sparks_broken_lightmask", overlays_file, src)
			else if(obj_integrity < (0.75 * max_integrity))
				damag_overlay = get_airlock_overlay("sparks_damaged", overlays_file)
				damag_underlay = get_airlock_emissive_underlay("sparks_damaged_lightmask", overlays_file, src)
			if(welded)
				weld_overlay = get_airlock_overlay("welded", overlays_file)
			if(note)
				note_overlay = get_airlock_overlay(notetype, note_overlay_file)

		if(AIRLOCK_CLOSING)
			frame_overlay = get_airlock_overlay("closing", icon)
			buttons_underlay = get_airlock_emissive_underlay("closing_lightmask", overlays_file, src)
			if(airlock_material)
				filling_overlay = get_airlock_overlay("[airlock_material]_closing", overlays_file)
			else
				filling_overlay = get_airlock_overlay("fill_closing", icon)
			if(lights && arePowerSystemsOn())
				lights_overlay = get_airlock_overlay("lights_closing", overlays_file)
				lights_underlay = get_airlock_emissive_underlay("lights_closing_lightmask", overlays_file, src)
			if(panel_open)
				buttons_underlay = null
				if(security_level)
					panel_overlay = get_airlock_overlay("panel_closing_protected", overlays_file)
				else
					panel_overlay = get_airlock_overlay("panel_closing", overlays_file)
			if(note)
				note_overlay = get_airlock_overlay("[notetype]_closing", note_overlay_file)

		if(AIRLOCK_OPEN)
			frame_overlay = get_airlock_overlay("open", icon)
			if(airlock_material)
				filling_overlay = get_airlock_overlay("[airlock_material]_open", overlays_file)
			else
				filling_overlay = get_airlock_overlay("fill_open", icon)
			if(panel_open)
				if(security_level)
					panel_overlay = get_airlock_overlay("panel_open_protected", overlays_file)
				else
					panel_overlay = get_airlock_overlay("panel_open", overlays_file)
			if(obj_integrity < (0.75 * max_integrity))
				damag_overlay = get_airlock_overlay("sparks_open", overlays_file)
				damag_underlay = get_airlock_emissive_underlay("sparks_open_lightmask", overlays_file, src)
			if(note)
				note_overlay = get_airlock_overlay("[notetype]_open", note_overlay_file)

		if(AIRLOCK_OPENING)
			frame_overlay = get_airlock_overlay("opening", icon)
			buttons_underlay = get_airlock_emissive_underlay("opening_lightmask", overlays_file, src)
			if(airlock_material)
				filling_overlay = get_airlock_overlay("[airlock_material]_opening", overlays_file)
			else
				filling_overlay = get_airlock_overlay("fill_opening", icon)
			if(lights && arePowerSystemsOn())
				lights_overlay = get_airlock_overlay("lights_opening", overlays_file)
				lights_underlay = get_airlock_emissive_underlay("lights_opening_lightmask", overlays_file, src)
			if(panel_open)
				buttons_underlay = null
				if(security_level)
					panel_overlay = get_airlock_overlay("panel_opening_protected", overlays_file)
				else
					panel_overlay = get_airlock_overlay("panel_opening", overlays_file)
			if(note)
				note_overlay = get_airlock_overlay("[notetype]_opening", note_overlay_file)

	cut_overlays()

	add_overlay(list(
		frame_overlay,
		filling_overlay,
		lights_overlay,
		panel_overlay,
		weld_overlay,
		sparks_overlay,
		damag_overlay,
		note_overlay,
	))

	add_overlay(check_unres())

	//EMISSIVE ICONS
	if(buttons_underlay != old_buttons_underlay)
		underlays -= old_buttons_underlay
		underlays += buttons_underlay
		old_buttons_underlay = buttons_underlay
	if(lights_underlay != old_lights_underlay)
		underlays -= old_lights_underlay
		underlays += lights_underlay
		old_lights_underlay = lights_underlay
	if(damag_underlay != old_damag_underlay)
		underlays -= old_damag_underlay
		underlays += damag_underlay
		old_damag_underlay = damag_underlay
	if(sparks_underlay != old_sparks_underlay)
		underlays -= old_sparks_underlay
		underlays += sparks_underlay
		old_sparks_underlay = sparks_underlay


/proc/get_airlock_overlay(icon_state, icon_file)
	var/iconkey = "[icon_state][icon_file]"
	if(GLOB.airlock_overlays[iconkey])
		return GLOB.airlock_overlays[iconkey]
	GLOB.airlock_overlays[iconkey] = image(icon_file, icon_state)
	return GLOB.airlock_overlays[iconkey]


/proc/get_airlock_emissive_underlay(icon_state, icon_file, atom/offset_spokesman)
	var/turf/our_turf = get_turf(offset_spokesman)
	var/iconkey = "[icon_state][icon_file][GET_TURF_PLANE_OFFSET(our_turf)]"
	if(GLOB.airlock_emissive_underlays[iconkey])
		return GLOB.airlock_emissive_underlays[iconkey]
	GLOB.airlock_emissive_underlays[iconkey] = emissive_appearance(icon_file, icon_state, offset_spokesman = offset_spokesman)
	return GLOB.airlock_emissive_underlays[iconkey]


/obj/machinery/door/airlock/do_animate(animation)
	switch(animation)
		if("opening")
			update_icon(AIRLOCK_OPENING)
		if("closing")
			update_icon(AIRLOCK_CLOSING)
		if("deny")
			if(arePowerSystemsOn())
				update_icon(AIRLOCK_DENY)
				playsound(src, doorDeni, 50, FALSE, 3)
				sleep(6)
				update_icon(AIRLOCK_CLOSED)


/// Called when a player uses an airlock painter on this airlock
/obj/machinery/door/airlock/proc/change_paintjob(obj/item/airlock_painter/painter, mob/user)
	if((!in_range(src, user) && loc != user)) // user should be adjacent to the airlock.
		return

	if(!painter.paint_setting)
		to_chat(user, span_warning("You need to select a paintjob first."))
		return

	if(!paintable)
		to_chat(user, span_warning("This type of airlock cannot be painted."))
		return

	var/obj/machinery/door/airlock/airlock = painter.available_paint_jobs["[painter.paint_setting]"] // get the airlock type path associated with the airlock name the user just chose
	var/obj/structure/door_assembly/assembly = initial(airlock.assemblytype)

	if(assemblytype == assembly)
		to_chat(user, span_notice("This airlock is already painted [painter.paint_setting]!"))
		return

	if(airlock_material == "glass" && initial(assembly.noglass)) // prevents painting glass airlocks with a paint job that doesn't have a glass version, such as the freezer
		to_chat(user, span_warning("This paint job can only be applied to non-glass airlocks."))
		return

	if(do_after(user, 2 SECONDS, src))
		// applies the user-chosen airlock's icon, overlays and assemblytype to the src airlock
		painter.paint(user)
		icon = initial(airlock.icon)
		overlays_file = initial(airlock.overlays_file)
		assemblytype = initial(airlock.assemblytype)
		update_icon()


/obj/machinery/door/airlock/examine(mob/user)
	. = ..()
	if(emagged)
		. += span_warning("Its access panel is smoking slightly.")
	if(HAS_TRAIT(src, TRAIT_CMAGGED))
		. += span_warning("The access panel is coated in yellow ooze...")
	if(note)
		if(!in_range(user, src))
			. += span_notice("There's a [note.name] pinned to the front. You can't [note_type() == "note" ? "read" : "see"] it from here.")
		else
			. += span_notice("There's a [note.name] pinned to the front...")
			note.examine(user)
			. += span_notice("Use an empty hand on the airlock on grab mode to remove [note.name].")

	if(panel_open)
		switch(security_level)
			if(AIRLOCK_SECURITY_NONE)
				. += span_notice("Its wires are exposed!")
			if(AIRLOCK_SECURITY_METAL)
				. += span_notice("Its wires are hidden behind a welded metal cover.")
			if(AIRLOCK_SECURITY_PLASTEEL_I_S)
				. += span_notice("There is some shredded plasteel inside.")
			if(AIRLOCK_SECURITY_PLASTEEL_I)
				. += span_notice("Its wires are behind an inner layer of plasteel.")
			if(AIRLOCK_SECURITY_PLASTEEL_O_S)
				. += span_notice("There is some shredded plasteel inside.")
			if(AIRLOCK_SECURITY_PLASTEEL_O)
				. += span_notice("There is a welded plasteel cover hiding its wires.")
			if(AIRLOCK_SECURITY_PLASTEEL)
				. += span_notice("There is a protective grille over its panel.")
	else if(security_level)
		if(security_level == AIRLOCK_SECURITY_METAL)
			. += span_notice("It looks a bit stronger.")
		else
			. += span_notice("It looks very robust.")

/obj/machinery/door/airlock/attack_ghost(mob/user)
	if(panel_open)
		wires.Interact(user)
	ui_interact(user)

/obj/machinery/door/airlock/attack_ai(mob/user)
	ui_interact(user)

/obj/machinery/door/airlock/ui_interact(mob/user, datum/tgui/ui = null)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "AiAirlock", name)
		ui.open()


/obj/machinery/door/airlock/ui_data(mob/user)
	var/list/data = list()

	var/list/power = list()
	power["main"] = main_power_lost_until ? UI_RED : UI_GREEN
	power["main_timeleft"] = max(main_power_lost_until - world.time, 0) / 10
	power["backup"] = backup_power_lost_until ? UI_RED : UI_GREEN
	power["backup_timeleft"] = max(backup_power_lost_until - world.time, 0) / 10
	data["power"] = power
	if(electrified_until == -1)
		data["shock"] = UI_RED
	else if(electrified_until > 0)
		data["shock"] = UI_ORANGE
	else
		data["shock"] = UI_GREEN

	data["shock_timeleft"] = max(electrified_until - world.time, 0) / 10
	data["id_scanner"] = !aiDisabledIdScanner
	data["emergency"] = emergency // access
	data["locked"] = locked // bolted
	data["lights"] = lights // bolt lights
	data["safe"] = safe // safeties
	data["speed"] = normalspeed // safe speed
	data["welded"] = welded // welded
	data["opened"] = !density // opened

	var/list/wire = list()
	wire["main_power"] = !wires.is_cut(WIRE_MAIN_POWER1)
	wire["backup_power"] = !wires.is_cut(WIRE_BACKUP_POWER1)
	wire["shock"] = !wires.is_cut(WIRE_ELECTRIFY)
	wire["id_scanner"] = !wires.is_cut(WIRE_IDSCAN)
	wire["bolts"] = !wires.is_cut(WIRE_DOOR_BOLTS)
	wire["lights"] = !wires.is_cut(WIRE_BOLT_LIGHT)
	wire["safe"] = !wires.is_cut(WIRE_SAFETY)
	wire["timing"] = !wires.is_cut(WIRE_SPEED)

	data["wires"] = wire
	return data

/obj/machinery/door/airlock/ui_status(mob/user, datum/ui_state/state)
	if((aiControlDisabled == AICONTROLDISABLED_ON) && (isAI(user) || isrobot(user)))
		to_chat(user, span_warning("AI control for \the [src] interface has been disabled."))
		if(!canAIControl() && canAIHack())
			hack(user)
		return UI_CLOSE
	. = ..()

/obj/machinery/door/airlock/proc/hack(mob/user)
	set waitfor = 0
	if(!aiHacking)
		aiHacking = TRUE
		to_chat(user, "Airlock AI control has been blocked. Beginning fault-detection.")
		sleep(50)
		if(canAIControl())
			to_chat(user, "Alert cancelled. Airlock control has been restored without our assistance.")
			aiHacking = FALSE
			return
		else if(!canAIHack())
			to_chat(user, "Connection lost! Unable to hack airlock.")
			aiHacking = FALSE
			return
		to_chat(user, "Fault confirmed: airlock control wire disabled or cut.")
		sleep(20)
		to_chat(user, "Attempting to hack into airlock. This may take some time.")
		sleep(200)
		if(canAIControl())
			to_chat(user, "Alert cancelled. Airlock control has been restored without our assistance.")
			aiHacking = FALSE
			return
		else if(!canAIHack())
			to_chat(user, "Connection lost! Unable to hack airlock.")
			aiHacking = FALSE
			return
		to_chat(user, "Upload access confirmed. Loading control program into airlock software.")
		sleep(170)
		if(canAIControl())
			to_chat(user, "Alert cancelled. Airlock control has been restored without our assistance.")
			aiHacking = FALSE
			return
		else if(!canAIHack())
			to_chat(user, "Connection lost! Unable to hack airlock.")
			aiHacking = FALSE
			return
		to_chat(user, "Transfer complete. Forcing airlock to execute program.")
		sleep(50)
		//disable blocked control
		aiControlDisabled = AICONTROLDISABLED_BYPASS
		to_chat(user, "Receiving control information from airlock.")
		sleep(10)
		//bring up airlock dialog
		aiHacking = FALSE
		if(user)
			attack_ai(user)

/obj/machinery/door/proc/check_unres() //unrestricted sides. This overlay indicates which directions the player can access even without an ID
	if(hasPower() && unres_sides)
		. = list()
		set_light(l_range = 1, l_power = 1, l_color = "#00FF00", l_on = TRUE)
		if(unres_sides & NORTH)
			var/image/I = image(icon='icons/obj/doors/airlocks/station/overlays.dmi', icon_state="unres_n") //layer=src.layer+1
			I.pixel_y = 32
			. += I
		if(unres_sides & SOUTH)
			var/image/I = image(icon='icons/obj/doors/airlocks/station/overlays.dmi', icon_state="unres_s") //layer=src.layer+1
			I.pixel_y = -32
			. += I
		if(unres_sides & EAST)
			var/image/I = image(icon='icons/obj/doors/airlocks/station/overlays.dmi', icon_state="unres_e") //layer=src.layer+1
			I.pixel_x = 32
			. += I
		if(unres_sides & WEST)
			var/image/I = image(icon='icons/obj/doors/airlocks/station/overlays.dmi', icon_state="unres_w") //layer=src.layer+1
			I.pixel_x = -32
			. += I


/obj/machinery/door/airlock/CanAllowThrough(atom/movable/mover, border_dir)
	. = ..()
	if(isElectrified() && density && isitem(mover) && (mover.flags & CONDUCT))
		do_sparks(5, TRUE, src)


/obj/machinery/door/airlock/attack_animal(mob/user)
	. = ..()
	if(isElectrified())
		shock(user, 100)
		return .

	if(!istype(user, /mob/living/simple_animal/hostile/gorilla) || !density || operating || locked || welded || arePowerSystemsOn())
		return .


	open(TRUE)
	user.visible_message(
		span_warning("[user] grabs the door with both hands and opens it with ease!"),
		span_notice("You easily open depowered door."),
		span_italics("You hear groaning metal..."),
	)


/obj/machinery/door/airlock/attack_animal(mob/user)
	. = ..()
	if(istype(user, /mob/living/simple_animal/hulk))
		var/mob/living/simple_animal/hulk/H = user
		H.attack_hulk(src)

/obj/machinery/door/airlock/attack_hand(mob/living/carbon/human/user)
	SEND_SIGNAL(src, COMSIG_ATOM_ATTACK_HAND, user)
	if(shock_user(user, 100))
		add_fingerprint(user)
		return

	if(headbutt_airlock(user))
		add_fingerprint(user)
		return // Smack that head against that airlock
	if(user.a_intent == INTENT_HARM && ishuman(user) && (user.dna.species.obj_damage + user.physiology.punch_obj_damage > 0))
		add_fingerprint(user)
		user.changeNext_move(CLICK_CD_MELEE)
		attack_generic(user, user.dna.species.obj_damage + user.physiology.punch_obj_damage)
		return
	if(remove_airlock_note(user, FALSE))
		add_fingerprint(user)
		return
	if(panel_open)
		if(security_level)
			to_chat(user, span_warning("Wires are protected!"))
			return
		add_fingerprint(user)
		wires.Interact(user)
	else
		..()


//Checks if the user can headbutt the airlock and does it if it can. Returns TRUE if it happened
/obj/machinery/door/airlock/proc/headbutt_airlock(mob/user)
	if(ishuman(user) && prob(40) && density)
		var/mob/living/carbon/human/H = user
		if(H.getBrainLoss() >= 60 && Adjacent(user))
			playsound(loc, 'sound/effects/bang.ogg', 25, 1)
			if(!istype(H.head, /obj/item/clothing/head/helmet))
				visible_message(span_warning("[user] headbutts the airlock."))
				H.Weaken(10 SECONDS)
				H.apply_damage(10, def_zone = BODY_ZONE_HEAD)
			else
				visible_message(span_warning("[user] headbutts the airlock. Good thing [user.p_theyre()] wearing a helmet."))
			return TRUE
	return FALSE

//For the tools being used on the door. Since you don't want to call the attack_hand method if you're using hands. That would be silly
//Also it's a bit inconsistent that when you access the panel you headbutt it. But not while crowbarring
//Try to interact with the panel. If the user can't it'll try activating the door
/obj/machinery/door/airlock/proc/interact_with_panel(mob/user)
	if(shock_user(user, 100))
		return

	if(panel_open)
		if(security_level)
			to_chat(user, span_warning("Wires are protected!"))
			return
		wires.Interact(user)
	else
		try_to_activate_door(user)

/obj/machinery/door/airlock/proc/ai_control_check(mob/user)
	if(!issilicon(user))
		return TRUE
	if(ispulsedemon(user))
		return TRUE
	if(emagged || HAS_TRAIT(src, TRAIT_CMAGGED))
		to_chat(user, span_warning("Unable to interface: Internal error."))
		return FALSE
	if(!canAIControl())
		if(canAIHack())
			hack(user)
		else
			if(isAllPowerLoss())
				to_chat(user, span_warning("Unable to interface: Connection timed out."))
			else
				to_chat(user, span_warning("Unable to interface: Connection refused."))
		return FALSE
	return TRUE

/obj/machinery/door/airlock/ui_act(action, params)
	if(..())
		return
	if(!issilicon(usr) && !usr.can_admin_interact() && !usr.has_unlimited_silicon_privilege)
		to_chat(usr, span_warning("Access denied. Only silicons may use this interface."))
		return
	if(!ai_control_check(usr))
		return
	. = TRUE
	switch(action)
		if("disrupt-main")
			if(!main_power_lost_until)
				loseMainPower()
				update_icon()
			else
				to_chat(usr, span_warning("Main power is already offline."))
				. = FALSE
		if("disrupt-backup")
			if(!backup_power_lost_until)
				loseBackupPower()
				update_icon()
			else
				to_chat(usr, span_warning("Backup power is already offline."))
		if("shock-restore")
			electrify(0, usr, TRUE)
		if("shock-temp")
			if(wires.is_cut(WIRE_ELECTRIFY))
				to_chat(usr, span_warning("The electrification wire is cut - Door permanently electrified."))
				. = FALSE
			else
				//electrify door for 30 seconds
				electrify(30, usr, TRUE)
		if("shock-perm")
			if(wires.is_cut(WIRE_ELECTRIFY))
				to_chat(usr, span_warning("The electrification wire is cut - Cannot electrify the door."))
				. = FALSE
			else
				electrify(-1, usr, TRUE)
		if("idscan-toggle")
			if(wires.is_cut(WIRE_IDSCAN))
				to_chat(usr, span_warning("The IdScan wire has been cut - IdScan feature permanently disabled."))
				. = FALSE
			else if(aiDisabledIdScanner)
				aiDisabledIdScanner = FALSE
				to_chat(usr, span_notice("IdScan feature has been enabled."))
			else
				aiDisabledIdScanner = TRUE
				to_chat(usr, span_notice("IdScan feature has been disabled."))
		if("emergency-toggle")
			toggle_emergency_status(usr)
		if("bolt-toggle")
			toggle_bolt(usr)
		if("light-toggle")
			toggle_light(usr)
		if("safe-toggle")
			if(wires.is_cut(WIRE_SAFETY))
				to_chat(usr, span_warning("The safety wire is cut - Cannot secure the door."))
			else if(safe)
				safe = FALSE
				to_chat(usr, span_notice("The door safeties have been disabled."))
			else
				safe = TRUE
				to_chat(usr, span_notice("The door safeties have been enabled."))
		if("speed-toggle")
			if(wires.is_cut(WIRE_SPEED))
				to_chat(usr, span_warning("The timing wire is cut - Cannot alter timing."))
			else if(normalspeed)
				normalspeed = FALSE
			else
				normalspeed = TRUE
		if("open-close")
			open_close(usr)
		else
			. = FALSE

/obj/machinery/door/airlock/proc/open_close(mob/user)
	if(welded)
		to_chat(user, span_warning("The airlock has been welded shut!"))
		return FALSE
	else if(locked)
		to_chat(user, span_warning("The door bolts are down!"))
		return FALSE
	else if(density)
		return open()
	else
		return close()

/obj/machinery/door/airlock/proc/toggle_light(mob/user)
	if(wires.is_cut(WIRE_BOLT_LIGHT))
		to_chat(user, span_warning("The bolt lights wire has been cut - The door bolt lights are permanently disabled."))
	else if(lights)
		lights = FALSE
		to_chat(user, span_notice("The door bolt lights have been disabled."))
	else if(!lights)
		lights = TRUE
		to_chat(user, span_notice("The door bolt lights have been enabled."))
	update_icon()

/obj/machinery/door/airlock/proc/toggle_bolt(mob/user)
	if(wires.is_cut(WIRE_DOOR_BOLTS))
		to_chat(user, span_warning("The door bolt control wire has been cut - Door bolts permanently dropped."))
		return

	if(unlock()) // Trying to unbolt
		to_chat(user, span_notice("The door bolts have been raised."))
		return

	if(lock()) // Trying to bolt
		to_chat(user, span_notice("The door bolts have been dropped."))
		add_misc_logs(user, "Bolted [src]")
		add_hiddenprint(user)

/obj/machinery/door/airlock/proc/toggle_emergency_status(mob/user)
	emergency = !emergency
	if(emergency)
		to_chat(user, span_notice("Emergency access has been enabled."))
	else
		to_chat(user, span_notice("Emergency access has been disabled."))
	update_icon()


/obj/machinery/door/airlock/attackby(obj/item/I, mob/user, params)
	if(!headbutt_shock_check(user))
		add_fingerprint(user)
		return ATTACK_CHAIN_BLOCKED_ALL

	if(user.a_intent == INTENT_HARM)
		return ..()

	if(panel_open && security_level == AIRLOCK_SECURITY_NONE)
		if(istype(I, /obj/item/stack/sheet/metal))
			add_fingerprint(user)
			var/obj/item/stack/sheet/metal/metal = I
			if(metal.get_amount() < 2)
				to_chat(user, span_warning("You need at least two metal sheets to reinforce [src]."))
				return ATTACK_CHAIN_PROCEED
			to_chat(user, span_notice("You start reinforcing [src]..."))
			if(!do_after(user, 2 SECONDS * metal.toolspeed, src, category = DA_CAT_TOOL) || security_level != AIRLOCK_SECURITY_NONE || !panel_open || QDELETED(metal))
				return ATTACK_CHAIN_PROCEED
			if(!metal.use(2))
				to_chat(user, span_warning("At some point during construction you lost some metal. Make sure you have two metal sheets before trying again."))
				return ATTACK_CHAIN_PROCEED
			user.visible_message(
				span_notice("[user] reinforces [src] with metal."),
				span_notice("You reinforce [src] with metal."),
			)
			security_level = AIRLOCK_SECURITY_METAL
			update_icon()
			return ATTACK_CHAIN_PROCEED_SUCCESS

		if(istype(I, /obj/item/stack/sheet/plasteel))
			add_fingerprint(user)
			var/obj/item/stack/sheet/plasteel/plasteel = I
			if(plasteel.get_amount() < 2)
				to_chat(user, span_warning("You need at least two plasteel sheets to reinforce [src]."))
				return ATTACK_CHAIN_PROCEED
			to_chat(user, span_notice("You start reinforcing [src]..."))
			if(!do_after(user, 2 SECONDS * plasteel.toolspeed, src, category = DA_CAT_TOOL) || security_level != AIRLOCK_SECURITY_NONE || !panel_open || QDELETED(plasteel))
				return ATTACK_CHAIN_PROCEED
			if(!plasteel.use(2))
				to_chat(user, span_warning("At some point during construction you lost some plasteel. Make sure you have two plasteel sheets before trying again."))
				return ATTACK_CHAIN_PROCEED
			user.visible_message(
				span_notice("[user] reinforces [src] with plasteel."),
				span_notice("You reinforce [src] with plasteel."),
			)
			security_level = AIRLOCK_SECURITY_PLASTEEL
			modify_max_integrity(normal_integrity * AIRLOCK_INTEGRITY_MULTIPLIER)
			damage_deflection = AIRLOCK_DAMAGE_DEFLECTION_R
			update_icon()
			return ATTACK_CHAIN_PROCEED_SUCCESS

	if(issignaler(I))
		add_fingerprint(user)
		interact_with_panel(user)
		return ATTACK_CHAIN_BLOCKED_ALL

	if(istype(I, /obj/item/paper) || istype(I, /obj/item/photo))
		add_fingerprint(user)
		if(note)
			to_chat(user, span_warning("There's already something pinned to this airlock! Use wirecutters or your hands to remove it."))
			return ATTACK_CHAIN_PROCEED
		if(!user.drop_transfer_item_to_loc(I, src))
			return ..()
		add_misc_logs(user, "put [I] on", src)
		user.visible_message(
			span_notice("[user] pins [I] to [src]."),
			span_notice("You pin [I] to [src]."),
		)
		note = I
		update_icon()
		return ATTACK_CHAIN_BLOCKED_ALL

	if(istype(I, /obj/item/airlock_painter))
		add_fingerprint(user)
		change_paintjob(I, user)
		return ATTACK_CHAIN_BLOCKED_ALL

	return ..()


/obj/machinery/door/airlock/screwdriver_act(mob/user, obj/item/I)
	if(!headbutt_shock_check(user))
		return
	if(user.a_intent == INTENT_HARM)
		return
	. = TRUE
	if(!I.use_tool(src, user, 0, volume = I.tool_volume))
		return
	panel_open = !panel_open
	to_chat(user, span_notice("You [panel_open ? "open":"close"] [src]'s maintenance panel."))
	update_icon()

/obj/machinery/door/airlock/crowbar_act(mob/user, obj/item/I)
	if(!headbutt_shock_check(user))
		return
	if(user.a_intent == INTENT_HARM)
		return
	. = TRUE
	if(!I.use_tool(src, user, 0, volume = 0))
		return
	if(panel_open && security_level == AIRLOCK_SECURITY_PLASTEEL_I_S)
		to_chat(user, span_notice("You start removing the inner layer of shielding..."))
		if(I.use_tool(src, user, 40, volume = I.tool_volume))
			if(!panel_open || security_level != AIRLOCK_SECURITY_PLASTEEL_I_S)
				return
			user.visible_message(span_notice("[user] remove \the [src]'s shielding."),
								span_notice("You remove \the [src]'s inner shielding."))
			security_level = AIRLOCK_SECURITY_NONE
			modify_max_integrity(normal_integrity)
			damage_deflection = AIRLOCK_DAMAGE_DEFLECTION_N
			spawn_atom_to_turf(/obj/item/stack/sheet/plasteel, user.loc, 1)
			update_icon()
	else if(panel_open && security_level == AIRLOCK_SECURITY_PLASTEEL_O_S)
		to_chat(user, span_notice("You start removing outer layer of shielding..."))
		if(I.use_tool(src, user, 40, volume = I.tool_volume))
			if(!panel_open || security_level != AIRLOCK_SECURITY_PLASTEEL_O_S)
				return
			user.visible_message(span_notice("[user] remove \the [src]'s shielding."),
								span_notice("You remove \the [src]'s shielding."))
			security_level = AIRLOCK_SECURITY_PLASTEEL_I
			spawn_atom_to_turf(/obj/item/stack/sheet/plasteel, user.loc, 1)
	else
		try_to_crowbar(user, I)

/obj/machinery/door/airlock/wirecutter_act(mob/user, obj/item/I)
	if(!headbutt_shock_check(user))
		return

	if(!panel_open)
		if(note)
			return remove_airlock_note(user, TRUE)
		// Can't do much else with the panel closed.
		return FALSE

	. = TRUE
	if(!I.tool_start_check(src, user, 0))
		return
	if(security_level == AIRLOCK_SECURITY_PLASTEEL)
		if(arePowerSystemsOn() && shock(user, 60)) // Protective grille of wiring is electrified
			return
		to_chat(user, span_notice("You start cutting through the outer grille."))
		if(I.use_tool(src, user, 10, volume = I.tool_volume))
			if(!panel_open || security_level != AIRLOCK_SECURITY_PLASTEEL)
				return
			user.visible_message(span_notice("[user] cut through \the [src]'s outer grille."),
								span_notice("You cut through \the [src]'s outer grille."))
			security_level = AIRLOCK_SECURITY_PLASTEEL_O
		return
	interact_with_panel(user)

/obj/machinery/door/airlock/multitool_act(mob/user, obj/item/I)
	if(!headbutt_shock_check(user))
		return
	. = TRUE
	if(!I.use_tool(src, user, 0, volume = I.tool_volume))
		return
	interact_with_panel(user)

/obj/machinery/door/airlock/wrench_act(mob/user, obj/item/I)
	if(!headbutt_shock_check(user))
		return
	. = TRUE
	if(!I.tool_use_check(user, 0))
		return
	if(!panel_open||!locked||emagged)
		to_chat(user, span_notice("You can't reach bolt reducer."))
		return
	if(isAllPowerLoss())
		to_chat(user, span_notice("You start wrenching bolt reducer."))
		if(I.use_tool(src, user, 300, volume = I.tool_volume))
			user.visible_message(span_notice("[user] raise \the [src]'s bolt manually."),
								span_notice("You raise \the [src]'s bolt manually."))
			unlock(TRUE)
		return

/obj/machinery/door/airlock/welder_act(mob/user, obj/item/I) //This is god awful but I don't care
	if(!headbutt_shock_check(user))
		return
	. = TRUE
	if(!I.tool_use_check(user, 0))
		return
	if(panel_open) // panel should be open before we try to slice out any shielding.
		switch(security_level)
			if(AIRLOCK_SECURITY_METAL)
				to_chat(user, span_notice("You begin cutting the panel's shielding..."))
				if(!I.use_tool(src, user, 4 SECONDS, volume = I.tool_volume))
					return
				visible_message(span_notice("[user] cuts through \the [src]'s shielding."),
					span_notice("You cut through \the [src]'s shielding."),
					span_italics("You hear welding."))
				security_level = AIRLOCK_SECURITY_NONE
				spawn_atom_to_turf(/obj/item/stack/sheet/metal, user.loc, 2)
			if(AIRLOCK_SECURITY_PLASTEEL_O)
				to_chat(user, span_notice("You begin cutting the outer layer of shielding..."))
				if(!I.use_tool(src, user, 4 SECONDS, volume = I.tool_volume))
					return
				visible_message(span_notice("[user] cuts through \the [src]'s shielding."),
					span_notice("You cut through \the [src]'s shielding."),
					span_italics("You hear welding."))
				security_level = AIRLOCK_SECURITY_PLASTEEL_O_S
			if(AIRLOCK_SECURITY_PLASTEEL_I)
				to_chat(user, span_notice("You begin cutting the inner layer of shielding..."))
				if(!I.use_tool(src, user, 4 SECONDS, volume = I.tool_volume))
					return
				user.visible_message(span_notice("[user] cuts through \the [src]'s shielding."),
					span_notice("You cut through \the [src]'s shielding."),
					span_italics("You hear welding."))
				security_level = AIRLOCK_SECURITY_PLASTEEL_I_S
	else
		if(user.a_intent != INTENT_HELP)
			user.visible_message(span_notice("[user] is [welded ? "unwelding":"welding"] the airlock."), \
				span_notice("You begin [welded ? "unwelding":"welding"] the airlock..."), \
				span_italics("You hear welding."))

			if(I.use_tool(src, user, 4 SECONDS, volume = I.tool_volume, extra_checks = CALLBACK(src, PROC_REF(weld_checks), I, user)))
				if(!density && !welded)
					return
				welded = !welded
				user.visible_message(span_notice("[user.name] has [welded? "welded shut":"unwelded"] [src]."), \
					span_notice("You [welded ? "weld the airlock shut":"unweld the airlock"]."))
				update_icon()
		else if(obj_integrity < max_integrity)
			user.visible_message(span_notice("[user] is welding the airlock."), \
				span_notice("You begin repairing the airlock..."), \
				span_italics("You hear welding."))
			if(I.use_tool(src, user, 4 SECONDS, volume = I.tool_volume, extra_checks = CALLBACK(src, PROC_REF(weld_checks), I, user)))
				obj_integrity = max_integrity
				stat &= ~BROKEN
				user.visible_message(span_notice("[user.name] has repaired [src]."), \
					span_notice("You finish repairing the airlock."))
			update_icon()
		else
			to_chat(user, span_notice("The airlock doesn't need repairing."))
	update_icon()

/obj/machinery/door/airlock/proc/weld_checks(obj/item/I, mob/user)
	return !operating && density && user && I && I.tool_use_check() && user.loc

/obj/machinery/door/airlock/proc/headbutt_shock_check(mob/user)
	if(shock_user(user, 75))
		return
	if(headbutt_airlock(user))//See if the user headbutts the airlock
		return
	return TRUE

/obj/machinery/door/airlock/try_to_crowbar(mob/living/user, obj/item/I)
	if(operating)
		return

	if(I.tool_behaviour == TOOL_CROWBAR && I.tool_use_check(user, 0) && panel_open && (emagged || (density && welded && !operating && !arePowerSystemsOn() && !locked)))
		user.visible_message("[user] removes the electronics from the airlock assembly.", \
							 span_notice("You start to remove electronics from the airlock assembly..."))
		if(I.use_tool(src, user, 4 SECONDS, volume = I.tool_volume))
			deconstruct(TRUE, user)
		return

	if(welded)
		to_chat(user, span_warning("[src] is welded shut!"))
		return

	if(locked)
		to_chat(user, span_warning("The airlock's bolts prevent it from being forced!"))
		return

	if(!arePowerSystemsOn())
		spawn(0)
			if(density)
				open(TRUE)
			else
				close(TRUE)
		return

	if(!density)//already open
		return

	if(istype(I, /obj/item/twohanded/fireaxe)) //let's make this more specific //FUCK YOU
		var/obj/item/twohanded/fireaxe/F = I
		if(!F.wielded)
			to_chat(user, span_warning("You need to be wielding the fire axe to do that!"))
			return
		playsound(src, 'sound/machines/airlock_alien_prying.ogg', 100, 1) //is it aliens or just the CE being a dick?
		if(do_after(user, 5 SECONDS, src, max_interact_count = 1, category = DA_CAT_TOOL) && !open(TRUE) && density)
			to_chat(user, span_warning("Despite your attempts, [src] refuses to open."))
		return

	if(istype(I, /obj/item/mecha_parts/mecha_equipment/medical/rescue_jaw))
		playsound(src, 'sound/machines/airlock_force_open.ogg', 100, 1) //scary
		if(do_after(user, 4 SECONDS, src, max_interact_count = 1, category = DA_CAT_TOOL) && !open(TRUE) && density) // faster because of ITS A MECH
			to_chat(user, span_warning("Despite your attempts, [src] refuses to open."))
		return

	if(isElectrified())
		shock(user, 100)//it's like sticking a forck in a power socket
		return

	if(!ispowertool(I))
		to_chat(user, span_warning("The airlock's motors resist your efforts to force it!"))
		return

	playsound(src, 'sound/machines/airlock_alien_prying.ogg', 100, 1) //is it aliens or just the CE being a dick?
	if(do_after(user, 5 SECONDS, src, max_interact_count = 1, category = DA_CAT_TOOL) && !open(TRUE) && density)
		to_chat(user, span_warning("Despite your attempts, [src] refuses to open."))


/obj/machinery/door/airlock/open(forced = 0)
	set waitfor = FALSE

	if(operating || welded || locked || emagged)
		return FALSE
	if(!forced && (!arePowerSystemsOn() || wires.is_cut(WIRE_OPEN_DOOR)))
		return FALSE
	use_power(360)	//360 W seems much more appropriate for an actuator moving an industrial door capable of crushing people
	if(forced)
		playsound(loc, 'sound/machines/airlockforced.ogg', 30, TRUE)
	else
		playsound(loc, doorOpen, 30, TRUE)
	if(istype(closeOther, /obj/machinery/door/airlock) && !closeOther.density)
		closeOther.close()

	if(autoclose)
		autoclose_in(normalspeed ? auto_close_time : auto_close_time_dangerous)

	if(!density)
		return TRUE

	operating = DOOR_OPENING
	update_icon(AIRLOCK_OPENING, TRUE)
	sleep(1)
	set_opacity(FALSE)
	update_freelook_sight()
	sleep(4)
	set_density(FALSE)
	air_update_turf(TRUE)
	sleep(1)
	layer = OPEN_DOOR_LAYER
	update_icon(AIRLOCK_OPEN, TRUE)
	operating = NONE
	return TRUE


/obj/machinery/door/airlock/close(forced = 0, override = FALSE)
	set waitfor = FALSE

	if((operating && !override) || welded || locked || emagged)
		return FALSE
	if(density)
		return TRUE
	//despite the name, this wire is for general door control.
	//Bolts are already covered by the check for locked, above
	if(!forced && (!arePowerSystemsOn() || wires.is_cut(WIRE_OPEN_DOOR)))
		return FALSE
	if(safe)
		for(var/turf/check_turf in locs)
			for(var/atom/movable/check in check_turf)
				if(check.density && check != src) //something is blocking the door
					autoclose_in(6 SECONDS)
					return FALSE

	use_power(360)	//360 W seems much more appropriate for an actuator moving an industrial door capable of crushing people
	if(forced)
		playsound(loc, 'sound/machines/airlock_force_close.ogg', 30, TRUE)
	else
		playsound(loc, doorClose, 30, TRUE)
	var/obj/structure/window/killthis = (locate(/obj/structure/window) in get_turf(src))
	if(killthis)
		killthis.ex_act(EXPLODE_HEAVY)//Smashin windows

	operating = DOOR_CLOSING
	update_icon(AIRLOCK_CLOSING, TRUE)
	layer = CLOSED_DOOR_LAYER
	if(!override)
		sleep(1)
	set_density(TRUE)
	air_update_turf(TRUE)
	if(!override)
		sleep(4)
	if(!safe)
		crush()
	if(visible && !glass)
		set_opacity(TRUE)
	update_freelook_sight()
	sleep(1)
	update_icon(AIRLOCK_CLOSED, TRUE)
	operating = NONE
	if(safe)
		CheckForMobs()
	return TRUE


/obj/machinery/door/airlock/lock(forced = FALSE)
	if(locked)
		return FALSE

	if(operating && !forced)
		return FALSE

	locked = TRUE
	playsound(src, boltDown, 30, FALSE, 3)
	update_icon()
	return TRUE


/obj/machinery/door/airlock/unlock(forced = FALSE)
	if(!locked)
		return FALSE

	if(!forced && (operating || !arePowerSystemsOn() || wires.is_cut(WIRE_DOOR_BOLTS)))
		return FALSE

	locked = FALSE
	playsound(src, boltUp, 30, FALSE, 3)
	update_icon()
	return TRUE


/obj/machinery/door/airlock/CanAStarPass(to_dir, datum/can_pass_info/pass_info)
	//Airlock is passable if it is open (!density), bot has access, and is not bolted shut or powered off)
	return !density || (check_access_list(pass_info.access) && !locked && arePowerSystemsOn() && !pass_info.no_id)


/obj/machinery/door/airlock/emag_act(mob/user)
	if(!hackable)
		if(user)
			to_chat(user, span_notice("The electronic systems in this door are far too advanced for your primitive hacking peripherals."))
		return
	if(!operating && density && arePowerSystemsOn() && !emagged)
		add_attack_logs(user, src, "emagged ([locked ? "bolted" : "not bolted"])")
		operating = DOOR_MALF
		update_icon(AIRLOCK_EMAG, TRUE)
		sleep(6)
		if(QDELETED(src))
			return
		operating = NONE
		if(!open())
			update_icon(AIRLOCK_CLOSED, TRUE)
		emagged = TRUE
		return TRUE


/obj/machinery/door/airlock/cmag_act(mob/user)
	set waitfor = FALSE
	if(operating || HAS_TRAIT(src, TRAIT_CMAGGED) || !density || !arePowerSystemsOn() || emagged)
		return
	operating = DOOR_MALF
	update_icon(AIRLOCK_EMAG, TRUE)
	sleep(6)
	if(QDELETED(src))
		return
	operating = NONE
	update_icon(AIRLOCK_CLOSED, TRUE)
	ADD_TRAIT(src, TRAIT_CMAGGED, CMAGGED)
	return TRUE


/obj/machinery/door/airlock/emp_act(severity)
	. = ..()
	if(prob(20 / severity))
		open()
	if(prob(40 / severity))
		var/duration = world.time + (30 / severity) SECONDS
		if(duration > electrified_until)
			electrify(duration)


/obj/machinery/door/airlock/attack_alien(mob/living/carbon/alien/humanoid/user)
	add_fingerprint(user)
	if(isElectrified())
		shock(user, 100) //Mmm, fried xeno!
		return

	if(operating)
		return

	if(locked || welded)
		return ..()

	var/is_opening = density
	if(allowed(user))
		if(is_opening)
			open(TRUE)
		else
			close(TRUE)
		return

	var/time_to_action = 0.2 SECONDS
	if(arePowerSystemsOn())
		time_to_action = user.time_to_open_doors
		if(time_to_action > 3 SECONDS)
			playsound(src, 'sound/machines/airlock_alien_prying.ogg', 100, TRUE)

	user.visible_message(span_warning("[user] begins prying [is_opening ? "open":"close"] [src]."),\
						span_noticealien("You begin digging your claws into [src] with all your might!"),\
						span_warning("You hear groaning metal..."))

	if(do_after(user, time_to_action, src))
		var/returns = is_opening ? open(TRUE) : close(TRUE)
		if(!returns) //The airlock is still closed, but something prevented it opening. (Another player noticed and bolted/welded the airlock in time!)
			to_chat(user, span_warning("Despite your efforts, [src] managed to resist your attempts!"))


/obj/machinery/door/airlock/power_change(forced = FALSE) //putting this is obj/machinery/door itself makes non-airlock doors turn invisible for some reason
	..()
	if(stat & NOPOWER)
		// If we lost power, disable electrification
		// Keeping door lights on, runs on internal battery or something.
		electrified_until = 0
	update_icon()

/obj/machinery/door/airlock/proc/prison_open()
	if(emagged)
		return
	if(arePowerSystemsOn())
		unlock()
		open()
		lock()

/obj/machinery/door/airlock/hostile_lockdown(mob/origin)
	// Must be powered and have working AI wire.
	if(canAIControl(src) && !stat)
		locked = FALSE //For airlocks that were bolted open.
		safe = FALSE //DOOR CRUSH
		close()
		lock() //Bolt it!
		electrified_until = -1  //Shock it!
		if(origin)
			shockedby += "\[[time_stamp()]\][origin](ckey:[origin.ckey])"

/obj/machinery/door/airlock/disable_lockdown()
	// Must be powered and have working AI wire.
	if(canAIControl(src) && !stat)
		unlock()
		electrified_until = 0
		open()
		safe = TRUE

/obj/machinery/door/airlock/obj_break(damage_flag)
	if(!(flags & BROKEN) && !(obj_flags & NODECONSTRUCT))
		stat |= BROKEN
		if(!panel_open)
			panel_open = TRUE
		wires.cut_all()
		update_icon()

/obj/machinery/door/airlock/take_damage(damage_amount, damage_type = BRUTE, damage_flag = 0, sound_effect = 1, attack_dir)
	. = ..()
	if(obj_integrity < (0.75 * max_integrity))
		update_icon()

/obj/machinery/door/airlock/deconstruct(disassembled = TRUE, mob/user)
	if(!(obj_flags & NODECONSTRUCT))
		var/obj/structure/door_assembly/DA
		if(assemblytype)
			DA = new assemblytype(loc)
		else
			DA = new /obj/structure/door_assembly(loc)
			//If you come across a null assemblytype, it will produce the default assembly instead of disintegrating.
		DA.heat_proof_finished = heat_proof //tracks whether there's rglass in
		DA.set_anchored(TRUE)
		DA.glass = src.glass
		DA.state = AIRLOCK_ASSEMBLY_NEEDS_ELECTRONICS
		DA.created_name = name
		DA.previous_assembly = previous_airlock
		DA.update_name()
		DA.update_icon()

		if(!disassembled)
			if(DA)
				DA.obj_integrity = DA.max_integrity * 0.5
		if(user)
			to_chat(user, span_notice("You remove the airlock electronics."))

		if(!airlock_electronics)
			airlock_electronics = new /obj/item/airlock_electronics(loc)
			airlock_electronics.id = id_tag
		else
			airlock_electronics.forceMove(loc)
		if(emagged)
			airlock_electronics.icon_state = "door_electronics_smoked"
		airlock_electronics = null

		if(has_access_electronics)
			if(!access_electronics)
				build_access_electronics()
			access_electronics.forceMove(loc)
			if(emagged)
				access_electronics.emag_act()
			access_electronics = null

	qdel(src)

/obj/machinery/door/airlock/proc/build_access_electronics()
	access_electronics = new(src)
	access_electronics.selected_accesses = length(req_access) ? req_access : list()
	access_electronics.one_access = check_one_access

/obj/machinery/door/airlock/proc/note_type() //Returns a string representing the type of note pinned to this airlock
	if(!note)
		return
	if(istype(note, /obj/item/paper))
		var/obj/item/paper/pinned_paper = note
		if(pinned_paper.info)
			return "note_words"
		else
			return "note"
	if(istype(note, /obj/item/photo))
		return "photo"

//Removes the current note on the door if any. Returns if a note is removed
/obj/machinery/door/airlock/proc/remove_airlock_note(mob/user, wirecutters_used = TRUE)
	if(!note)
		return FALSE

	if(!wirecutters_used)
		if (ishuman(user) && (user.a_intent == INTENT_GRAB)) //grab that note
			user.visible_message(span_notice("[user] removes [note] from [src]."), span_notice("You remove [note] from [src]."))
			playsound(src, 'sound/items/poster_ripped.ogg', 50, 1)
		else
			return FALSE
	else
		user.visible_message(span_notice("[user] cuts down [note] from [src]."), span_notice("You remove [note] from [src]."))
		playsound(src, 'sound/items/wirecutter.ogg', 50, 1)
	note.add_fingerprint(user)
	add_misc_logs(user, "removed [note] from", src)
	note.forceMove_turf()
	user.put_in_hands(note, ignore_anim = FALSE)
	note = null
	update_icon()
	return TRUE

/obj/machinery/door/airlock/narsie_act(weak = FALSE)
	var/turf/T = get_turf(src)
	var/runed = prob(20)
	var/obj/machinery/door/airlock/cult/A
	if(weak)
		A = new/obj/machinery/door/airlock/cult/weak(T)
	else
		if(glass)
			if(runed)
				A = new/obj/machinery/door/airlock/cult/glass(T)
			else
				A = new/obj/machinery/door/airlock/cult/unruned/glass(T)
		else
			if(runed)
				A = new/obj/machinery/door/airlock/cult(T)
			else
				A = new/obj/machinery/door/airlock/cult/unruned(T)
	A.name = name
	A.stealth_icon = icon
	A.stealth_overlays = overlays_file
	A.stealth_opacity = opacity
	A.stealth_glass = glass
	A.stealth_airlock_material = airlock_material
	qdel(src)

/obj/machinery/door/airlock/ratvar_act(weak = FALSE)
	var/obj/machinery/door/airlock/clockwork/A
	if(weak)
		A = new/obj/machinery/door/airlock/clockwork/weak(get_turf(src))
	else
		if(glass)
			A = new/obj/machinery/door/airlock/clockwork/glass(get_turf(src))
		else
			A = new/obj/machinery/door/airlock/clockwork(get_turf(src))
	A.name = name
	qdel(src)

/obj/machinery/door/airlock/rcd_deconstruct_act(mob/user, obj/item/rcd/our_rcd)
	. = ..()
	if(our_rcd.checkResource(20, user))
		to_chat(user, "Deconstructing airlock...")
		playsound(get_turf(our_rcd), 'sound/machines/click.ogg', 50, 1)
		if(do_after(user, 5 SECONDS * our_rcd.toolspeed, src, category = DA_CAT_TOOL))
			if(!our_rcd.useResource(20, user))
				return RCD_ACT_FAILED
			playsound(get_turf(our_rcd), our_rcd.usesound, 50, 1)
			add_attack_logs(user, src, "Deconstructed airlock with RCD")
			qdel(src)
			return RCD_ACT_SUCCESSFULL
		to_chat(user, span_warning("ERROR! Deconstruction interrupted!"))
		return RCD_ACT_FAILED
	to_chat(user, span_warning("ERROR! Not enough matter in unit to deconstruct this airlock!"))
	playsound(get_turf(our_rcd), 'sound/machines/click.ogg', 50, 1)
	return RCD_ACT_FAILED

/obj/machinery/door/airlock/proc/ai_control_callback()
	if(aiControlDisabled == AICONTROLDISABLED_ON)
		aiControlDisabled = AICONTROLDISABLED_OFF
	else if(aiControlDisabled == AICONTROLDISABLED_BYPASS)
		aiControlDisabled = AICONTROLDISABLED_PERMA

#undef AIRLOCK_CLOSED
#undef AIRLOCK_CLOSING
#undef AIRLOCK_OPEN
#undef AIRLOCK_OPENING
#undef AIRLOCK_DENY
#undef AIRLOCK_EMAG

#undef AIRLOCK_SECURITY_NONE
#undef AIRLOCK_SECURITY_METAL
#undef AIRLOCK_SECURITY_PLASTEEL_I_S
#undef AIRLOCK_SECURITY_PLASTEEL_I
#undef AIRLOCK_SECURITY_PLASTEEL_O_S
#undef AIRLOCK_SECURITY_PLASTEEL_O
#undef AIRLOCK_SECURITY_PLASTEEL

#undef AIRLOCK_INTEGRITY_N
#undef AIRLOCK_INTEGRITY_MULTIPLIER
#undef AIRLOCK_DAMAGE_DEFLECTION_N
#undef AIRLOCK_DAMAGE_DEFLECTION_R

#undef UI_GREEN
#undef UI_ORANGE
#undef UI_RED
