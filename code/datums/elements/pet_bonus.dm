/**
 * # Pet bonus element!
 *
 * Bespoke element that plays a fun message, sends a heart out, and gives a stronger mood bonus (which we don't have) when you pet this animal.
 * I may have been able to make this work for carbons, but it would have been interjecting on some help mode interactions anyways.
 */
/datum/element/pet_bonus
	element_flags = ELEMENT_BESPOKE|ELEMENT_DETACH_ON_HOST_DESTROY
	id_arg_index = 2

	///optional cute message to send when you pet your pet!
	var/emote_message
	///optional sound to play when your pet emotes
	var/emote_sound

/datum/element/pet_bonus/Attach(datum/target, emote_message, emote_sound = null)
	. = ..()
	if(!isliving(target))
		return ELEMENT_INCOMPATIBLE

	src.emote_message = emote_message
	src.emote_sound = emote_sound
	RegisterSignal(target, COMSIG_ATOM_ATTACK_HAND, PROC_REF(on_attack_hand))

/datum/element/pet_bonus/Detach(datum/target)
	. = ..()
	UnregisterSignal(target, COMSIG_ATOM_ATTACK_HAND)

/datum/element/pet_bonus/proc/on_attack_hand(mob/living/pet, mob/living/petter)
	SIGNAL_HANDLER

	if(pet.stat != CONSCIOUS || petter.a_intent != INTENT_HELP)
		return

	new /obj/effect/temp_visual/heart(pet.loc)
	if(emote_message && prob(33))
		pet.emote("me", EMOTE_VISIBLE, emote_message)
		if(emote_sound)
			playsound(get_turf(pet), emote_sound, 50, TRUE)
