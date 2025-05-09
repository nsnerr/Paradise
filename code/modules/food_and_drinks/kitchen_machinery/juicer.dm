
/obj/machinery/juicer
	name = "Juicer"
	icon = 'icons/obj/kitchen.dmi'
	icon_state = "juicer1"
	layer = 2.9
	density = TRUE
	anchored = FALSE
	use_power = IDLE_POWER_USE
	idle_power_usage = 5
	active_power_usage = 100
	pass_flags = PASSTABLE
	var/obj/item/reagent_containers/beaker = null
	var/global/list/allowed_items = list (
		/obj/item/reagent_containers/food/snacks/grown/tomato  = "tomatojuice",
		/obj/item/reagent_containers/food/snacks/grown/carrot  = "carrotjuice",
		/obj/item/reagent_containers/food/snacks/grown/grapes = "grapejuice",
		/obj/item/reagent_containers/food/snacks/grown/grapes/green = "grapejuice",
		/obj/item/reagent_containers/food/snacks/grown/banana  = "banana",
		/obj/item/reagent_containers/food/snacks/grown/potato = "potato",
		/obj/item/reagent_containers/food/snacks/grown/citrus/lemon = "lemonjuice",
		/obj/item/reagent_containers/food/snacks/grown/citrus/orange = "orangejuice",
		/obj/item/reagent_containers/food/snacks/grown/citrus/lime = "limejuice",
		/obj/item/reagent_containers/food/snacks/grown/watermelon = "watermelonjuice",
		/obj/item/reagent_containers/food/snacks/watermelonslice = "watermelonjuice",
		/obj/item/reagent_containers/food/snacks/grown/berries/poison = "poisonberryjuice",
		/obj/item/reagent_containers/food/snacks/grown/berries = "berryjuice",
		/obj/item/reagent_containers/food/snacks/grown/pumpkin = "pumpkinjuice",
		/obj/item/reagent_containers/food/snacks/grown/blumpkin = "blumpkinjuice",
		/obj/item/reagent_containers/food/snacks/grown/pineapple = "pineapplejuice",
		/obj/item/reagent_containers/food/snacks/grown/peaslaugh = "laughsyrup"
	)

/obj/machinery/juicer/New()
	. = ..()
	beaker = new /obj/item/reagent_containers/glass/beaker/large(src)

/obj/machinery/juicer/update_icon_state()
	icon_state = "juicer"+num2text(!isnull(beaker))


/obj/machinery/juicer/attackby(obj/item/I, mob/user, params)
	if(user.a_intent == INTENT_HARM)
		return ..()

	add_fingerprint(user)
	if(istype(I, /obj/item/reagent_containers/glass) || istype(I, /obj/item/reagent_containers/food/drinks/drinkingglass))
		if(beaker)
			to_chat(user, span_warning("The [beaker.name] is already inside [src]."))
			return ATTACK_CHAIN_PROCEED
		if(!user.drop_transfer_item_to_loc(I, src))
			return ..()
		beaker = I
		verbs += /obj/machinery/juicer/verb/detach
		update_icon(UPDATE_ICON_STATE)
		updateUsrDialog()
		return ATTACK_CHAIN_BLOCKED_ALL

	if(!is_type_in_list(I, allowed_items))
		to_chat(user, span_warning("It doesn't look like [I.name] contains any juice."))
		return ATTACK_CHAIN_PROCEED

	if(!user.drop_transfer_item_to_loc(I, src))
		return ..()

	updateUsrDialog()
	return ATTACK_CHAIN_BLOCKED_ALL


/obj/machinery/juicer/attack_ai(mob/user)
	return 0

/obj/machinery/juicer/attack_hand(mob/user)
	if(..())
		return TRUE

	add_fingerprint(user)
	user.set_machine(src)
	interact(user)

/obj/machinery/juicer/interact(mob/user) // The microwave Menu
	var/is_chamber_empty = 0
	var/is_beaker_ready = 0
	var/processing_chamber = ""
	var/beaker_contents = ""

	for(var/i in allowed_items)
		for(var/obj/item/O in contents)
			if(!istype(O,i))
				continue
			processing_chamber+= "some <b>[O]</b><br>"
			break
	if(!processing_chamber)
		is_chamber_empty = 1
		processing_chamber = "Nothing."
	if(!beaker)
		beaker_contents = "\The [src] has no beaker attached."
	else if(!beaker.reagents.total_volume)
		beaker_contents = "\The [src]  has attached an empty beaker."
		is_beaker_ready = 1
	else if(beaker.reagents.total_volume < beaker.reagents.maximum_volume)
		beaker_contents = "\The [src]  has attached a beaker with something."
		is_beaker_ready = 1
	else
		beaker_contents = "\The [src]  has attached a beaker and beaker is full!"

	var/dat = {"<meta charset="UTF-8">
<b>Processing chamber contains:</b><br>
[processing_chamber]<br>
[beaker_contents]<hr>
"}
	if(is_beaker_ready && !is_chamber_empty && !(stat & (NOPOWER|BROKEN)))
		dat += "<a href='byond://?src=[UID()];action=juice'>Turn on!<br>"
	if(beaker)
		dat += "<a href='byond://?src=[UID()];action=detach'>Detach a beaker!<br>"
	var/datum/browser/popup = new(user, "juicer", name, 400, 400)
	popup.set_content(dat)
	popup.open(0)
	onclose(user, "juicer")
	return


/obj/machinery/juicer/Topic(href, href_list)
	if(..())
		return
	usr.set_machine(src)
	switch(href_list["action"])
		if("juice")
			juice()

		if("detach")
			detach()
	updateUsrDialog()
	return

/obj/machinery/juicer/verb/detach()
	set category = "Object"
	set name = "Detach Beaker from the juicer"
	set src in oview(1)
	if(usr.stat != 0)
		return
	if(!beaker)
		return
	verbs -= /obj/machinery/juicer/verb/detach
	beaker.forceMove(loc)
	beaker = null
	update_icon(UPDATE_ICON_STATE)

/obj/machinery/juicer/proc/get_juice_id(obj/item/reagent_containers/food/snacks/grown/O)
	for (var/i in allowed_items)
		if (istype(O, i))
			return allowed_items[i]

/obj/machinery/juicer/proc/get_juice_amount(obj/item/reagent_containers/food/snacks/grown/O)
	if(!istype(O) || !O.seed)
		return 5
	else if (O.seed.potency == -1)
		return 5
	else
		return round(5*sqrt(O.seed.potency))

/obj/machinery/juicer/proc/juice()
	power_change() //it is a portable machine
	if(stat & (NOPOWER|BROKEN))
		return
	if(!beaker || beaker.reagents.total_volume >= beaker.reagents.maximum_volume)
		return
	playsound(loc, 'sound/machines/juicer.ogg', 50, 1)
	for(var/obj/item/reagent_containers/food/snacks/O in contents)
		var/r_id = get_juice_id(O)
		beaker.reagents.add_reagent(r_id,get_juice_amount(O))
		qdel(O)
		if(beaker.reagents.total_volume >= beaker.reagents.maximum_volume)
			break

/obj/structure/closet/crate/juice/populate_contents()
	new/obj/machinery/juicer(src)
	new/obj/item/reagent_containers/food/snacks/grown/tomato(src)
	new/obj/item/reagent_containers/food/snacks/grown/carrot(src)
	new/obj/item/reagent_containers/food/snacks/grown/berries(src)
	new/obj/item/reagent_containers/food/snacks/grown/banana(src)
	new/obj/item/reagent_containers/food/snacks/grown/grapes(src)
	new/obj/item/reagent_containers/food/snacks/grown/tomato(src)
	new/obj/item/reagent_containers/food/snacks/grown/carrot(src)
	new/obj/item/reagent_containers/food/snacks/grown/berries(src)
	new/obj/item/reagent_containers/food/snacks/grown/banana(src)
	new/obj/item/reagent_containers/food/snacks/grown/grapes(src)
	new/obj/item/reagent_containers/food/snacks/grown/tomato(src)
	new/obj/item/reagent_containers/food/snacks/grown/carrot(src)
	new/obj/item/reagent_containers/food/snacks/grown/berries(src)
	new/obj/item/reagent_containers/food/snacks/grown/banana(src)
	new/obj/item/reagent_containers/food/snacks/grown/grapes(src)
	new/obj/item/reagent_containers/food/snacks/grown/pineapple(src)
