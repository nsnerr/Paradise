#define NO_EXTINGUISHER 0
#define NORMAL_EXTINGUISHER 1
#define MINI_EXTINGUISHER 2


/obj/structure/extinguisher_cabinet
	name = "extinguisher cabinet"
	desc = "A small wall mounted cabinet designed to hold a fire extinguisher."
	icon = 'icons/obj/closet.dmi'
	icon_state = "extinguisher_closed"
	anchored = TRUE
	density = FALSE
	max_integrity = 200
	integrity_failure = 50
	interaction_flags_click = NEED_HANDS | ALLOW_RESTING
	var/obj/item/extinguisher/has_extinguisher = null
	var/extinguishertype
	var/opened = FALSE
	var/material_drop = /obj/item/stack/sheet/metal

/obj/structure/extinguisher_cabinet/Initialize(mapload, direction = null)
	. = ..()
	if(direction)
		setDir(direction)
		set_pixel_offsets_from_dir(28, -28, 30, -30)
	switch(extinguishertype)
		if(NO_EXTINGUISHER)
			return
		if(MINI_EXTINGUISHER)
			has_extinguisher = new/obj/item/extinguisher/mini(src)
		else
			has_extinguisher = new/obj/item/extinguisher(src)
	update_icon(UPDATE_ICON_STATE)

/obj/structure/extinguisher_cabinet/examine(mob/user)
	. = ..()
	. += span_notice("Alt-click to [opened ? "close":"open"] it.")

/obj/structure/extinguisher_cabinet/click_alt(mob/living/user)
	playsound(loc, 'sound/machines/click.ogg', 15, TRUE, -3)
	opened = !opened
	update_icon(UPDATE_ICON_STATE)
	return CLICK_ACTION_SUCCESS

/obj/structure/extinguisher_cabinet/Destroy()
	QDEL_NULL(has_extinguisher)
	return ..()

/obj/structure/extinguisher_cabinet/ex_act(severity)
	if(has_extinguisher)
		has_extinguisher.ex_act(severity)
	..()

/obj/structure/extinguisher_cabinet/handle_atom_del(atom/A)
	if(A == has_extinguisher)
		has_extinguisher = null
		update_icon(UPDATE_ICON_STATE)


/obj/structure/extinguisher_cabinet/attackby(obj/item/I, mob/user, params)
	if(user.a_intent == INTENT_HARM || I.is_robot_module())
		return ..()

	if(istype(I, /obj/item/extinguisher))
		add_fingerprint(user)
		if(!opened)
			to_chat(user, span_warning("You need to open [src] first!"))
			return ATTACK_CHAIN_PROCEED
		if(has_extinguisher)
			to_chat(user, span_warning("The [name] already has [has_extinguisher]!"))
			return ATTACK_CHAIN_PROCEED
		if(!user.drop_transfer_item_to_loc(I, src))
			return ..()
		has_extinguisher = I
		update_icon(UPDATE_ICON_STATE)
		to_chat(user, span_notice("You place [I] into [src]."))
		return ATTACK_CHAIN_BLOCKED_ALL

	return ..()


/obj/structure/extinguisher_cabinet/welder_act(mob/user, obj/item/I)
	if(has_extinguisher)
		to_chat(user, "<span class='warning'>You need to remove the extinguisher before deconstructing [src]!</span>")
		return
	if(!opened)
		to_chat(user, "<span class='warning'>Open the cabinet before cutting it apart!</span>")
		return
	. = TRUE
	if(!I.tool_use_check(user, 0))
		return
	WELDER_ATTEMPT_SLICING_MESSAGE
	if(I.use_tool(src, user, 40, volume = I.tool_volume))
		WELDER_SLICING_SUCCESS_MESSAGE
		deconstruct(TRUE)

/obj/structure/extinguisher_cabinet/attack_hand(mob/user)
	if(isrobot(user) || isalien(user))
		to_chat(user, "<span class='notice'>You don't have the dexterity to do this!</span>")
		return
	if(ishuman(user))
		var/mob/living/carbon/human/H = user
		var/obj/item/organ/external/temp = H.bodyparts_by_name[BODY_ZONE_PRECISE_R_HAND]
		if(user.hand)
			temp = H.bodyparts_by_name[BODY_ZONE_PRECISE_L_HAND]
		if(temp && !temp.is_usable())
			to_chat(user, "<span class='notice'>You try to move your [temp.name], but cannot!")
			return
	add_fingerprint(user)
	if(has_extinguisher)
		if(icon_state == "extinguisher_closed")
			playsound(loc, 'sound/machines/click.ogg', 15, TRUE, -3)
		has_extinguisher.forceMove_turf()
		user.put_in_hands(has_extinguisher, ignore_anim = FALSE)
		to_chat(user, "<span class='notice'>You take [has_extinguisher] from [src].</span>")
		has_extinguisher = null
		opened = 1
	else
		playsound(loc, 'sound/machines/click.ogg', 15, TRUE, -3)
		opened = !opened
	update_icon(UPDATE_ICON_STATE)

/obj/structure/extinguisher_cabinet/attack_tk(mob/user)
	if(has_extinguisher)
		if(icon_state == "extinguisher_closed")
			playsound(loc, 'sound/machines/click.ogg', 15, TRUE, -3)
		has_extinguisher.loc = loc
		to_chat(user, "<span class='notice'>You telekinetically remove [has_extinguisher] from [src].</span>")
		has_extinguisher = null
		opened = 1
	else
		playsound(loc, 'sound/machines/click.ogg', 15, TRUE, -3)
		opened = !opened
	update_icon(UPDATE_ICON_STATE)

/obj/structure/extinguisher_cabinet/obj_break(damage_flag)
	if(!broken && !(obj_flags & NODECONSTRUCT))
		broken = 1
		opened = 1
		if(has_extinguisher)
			has_extinguisher.forceMove(loc)
			has_extinguisher = null
		update_icon(UPDATE_ICON_STATE)

/obj/structure/extinguisher_cabinet/deconstruct(disassembled = TRUE)
	if(!(obj_flags & NODECONSTRUCT))
		new /obj/item/stack/sheet/metal(loc)
		if(has_extinguisher)
			has_extinguisher.forceMove(loc)
			has_extinguisher = null
	qdel(src)

/obj/structure/extinguisher_cabinet/update_icon_state()
	if(!opened)
		icon_state = "extinguisher_closed"
		return
	if(has_extinguisher)
		if(istype(has_extinguisher, /obj/item/extinguisher/mini))
			icon_state = "extinguisher_mini"
		else
			icon_state = "extinguisher_full"
	else
		icon_state = "extinguisher_empty"

/obj/structure/extinguisher_cabinet/empty
	extinguishertype = NO_EXTINGUISHER

#undef NO_EXTINGUISHER
#undef NORMAL_EXTINGUISHER
#undef MINI_EXTINGUISHER
