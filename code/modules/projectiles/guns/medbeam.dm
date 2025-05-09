/obj/item/gun/medbeam
	name = "Medical Beamgun"
	desc = "Передает целебные наниты своим сфокусированным лучом. Не скрещивайте лучи!"
	ru_names = list(
		NOMINATIVE = "Медицинская лучевая пушка",
		GENITIVE = "Медицинской лучевой пушки",
		DATIVE = "Медицинской лучевой пушке",
		ACCUSATIVE = "Медицинскую лучевую пушку",
		INSTRUMENTAL = "Медицинской лучевой пушкой",
		PREPOSITIONAL = "Медицинской лучевой пушке"
	)
	icon = 'icons/obj/chronos.dmi'
	icon_state = "chronogun"
	item_state = "chronogun"
	w_class = WEIGHT_CLASS_NORMAL
	weapon_weight = WEAPON_MEDIUM

	var/mob/living/current_target
	var/datum/beam/current_beam

	COOLDOWN_DECLARE(last_check)
	var/check_delay = 1 SECONDS

	var/max_range = 8

	var/active = FALSE
	var/mounted = FALSE


/obj/item/gun/medbeam/Initialize(mapload)
	. = ..()
	START_PROCESSING(SSobj, src)


/obj/item/gun/medbeam/Destroy()
	STOP_PROCESSING(SSobj, src)
	LoseTarget()
	return ..()


/obj/item/gun/medbeam/handle_suicide()
	return


/obj/item/gun/medbeam/dropped(mob/user, slot, silent = FALSE)
	. = ..()
	LoseTarget()


/obj/item/gun/medbeam/equipped(mob/user, slot, initial = FALSE)
	. = ..()
	LoseTarget()


/**
 * Proc that always is called when we want to end the beam and makes sure things are cleaned up, see beam_died()
 */
/obj/item/gun/medbeam/proc/LoseTarget()
	if(active)
		active = FALSE
		QDEL_NULL(current_beam)
		on_beam_release(current_target)

	current_target = null


/**
 * Proc that is only called when the beam fails due to something, so not when manually ended.
 * manual disconnection = LoseTarget, so it can silently end
 * automatic disconnection = beam_died, so we can give a warning message first
 */
/obj/item/gun/medbeam/proc/beam_died()
	SIGNAL_HANDLER

	if(active && isliving(loc))
		balloon_alert(loc, "контроль над лучом потерян")

	current_beam = null
	active = FALSE // skip qdelling the beam again if we're doing this proc
	LoseTarget()


/obj/item/gun/medbeam/process_fire(atom/target, mob/living/user, message = TRUE, params, zone_override, bonus_spread = 0)
	if(isliving(user))
		add_fingerprint(user)

	var/old_target = current_target
	if(old_target)
		LoseTarget()

	if(old_target == target || !isliving(target))
		return FALSE

	current_target = target
	active = TRUE
	current_beam = user.Beam(current_target, icon_state = "medbeam", time = 10 MINUTES, maxdistance = max_range, beam_type = /obj/effect/ebeam/medical)
	RegisterSignal(current_beam, COMSIG_QDELETING, PROC_REF(beam_died)) // this is a WAY better rangecheck than what was done before (process check)

	SSblackbox.record_feedback("tally", "gun_fired", 1, type)
	return TRUE

/obj/item/gun/medbeam/process()
	if(!mounted && !isliving(loc))
		LoseTarget()
		return

	if(!current_target)
		LoseTarget()
		return

	if(!COOLDOWN_FINISHED(src, last_check))
		return

	COOLDOWN_START(src, last_check, check_delay)

	if(!los_check(loc, current_target))
		QDEL_NULL(current_beam)//this will give the target lost message
		return

	if(current_target)
		on_beam_tick(current_target)


/obj/item/gun/medbeam/proc/los_check(atom/movable/user, mob/target)
	var/turf/user_turf = user.loc

	if(mounted)
		user_turf = get_turf(user)

	if(!istype(user_turf))
		return FALSE

	var/obj/dummy = new(user_turf)
	dummy.pass_flags |= (PASSTABLE | PASSGLASS | PASSGRILLE | PASSFENCE) // Grille/Glass so it can be used through common windows

	var/turf/previous_step = user_turf
	var/first_step = TRUE

	for(var/turf/next_step as anything in (get_line(user_turf, target) - user_turf))
		if(first_step)
			for(var/obj/blocker in user_turf)
				if(!blocker.density || !(blocker.flags & ON_BORDER))
					continue

				if(blocker.CanPass(dummy, get_dir(user_turf, next_step)))
					continue

				qdel(dummy)
				return FALSE // Could not leave the first turf.

			first_step = FALSE

		if(mounted && next_step == user_turf)
			continue // Mechs are dense and thus fail the check

		if(next_step.density)
			qdel(dummy)
			return FALSE

		for(var/atom/movable/movable as anything in next_step)
			if(!movable.CanPass(dummy, get_dir(next_step, previous_step)))
				qdel(dummy)
				return FALSE

		for(var/obj/effect/ebeam/medical/B in next_step)// Don't cross the str-beams!
			if(QDELETED(current_beam))
				break // We shouldn't be processing anymore.

			if(QDELETED(B))
				continue

			if(!B.owner)
				stack_trace("beam without an owner! [B]")
				continue

			if(B.owner.origin != current_beam.origin)
				next_step.visible_message(span_boldwarning("Лучи пересекаются и ПРОИСХОДИТ ВЗРЫВ!"))
				explosion(B.loc, heavy_impact_range = 3, light_impact_range = 5, flash_range = 8, cause = src)
				qdel(dummy)
				return FALSE

		previous_step = next_step

	qdel(dummy)
	return TRUE



/obj/item/gun/medbeam/proc/on_beam_hit(mob/living/target)
	return


/obj/item/gun/medbeam/proc/on_beam_tick(mob/living/carbon/human/target)
	var/prev_health = target.health
	target.heal_overall_damage(4, 4)
	var/bones_mended = FALSE

	if(ishuman(target))
		for(var/obj/item/organ/external/bodypart as anything in target.bodyparts)
			if(bodypart.has_fracture() && prob(10))
				bones_mended = TRUE
				bodypart.mend_fracture()

	if(target.health != prev_health || bones_mended)
		new /obj/effect/temp_visual/heal(get_turf(target), "#80F5FF")


/obj/item/gun/medbeam/proc/on_beam_release(mob/living/target)
	return

/obj/item/gun/medbeam/mech
	mounted = TRUE
