//ICE CREAM MACHINE
//Code made by Sawu at Sawu-Station.

/obj/machinery/icemachine
	name = "\improper Cream-Master Deluxe"
	density = TRUE
	anchored = TRUE
	icon = 'icons/obj/machines/cooking_machines.dmi'
	icon_state = "icecream_vat"
	use_power = IDLE_POWER_USE
	max_integrity = 300
	idle_power_usage = 20
	var/obj/item/reagent_containers/glass/beaker = null
	var/useramount = 15	//Last used amount


/obj/machinery/icemachine/proc/generate_name(reagent_name)
	var/name_prefix = pick("Mr.","Mrs.","Super","Happy","Whippy")
	var/name_suffix = pick(" Whippy "," Slappy "," Creamy "," Dippy "," Swirly "," Swirl ")
	var/cone_name = null	//Heart failure prevention.
	cone_name += name_prefix
	cone_name += name_suffix
	cone_name += "[reagent_name]"
	return cone_name


/obj/machinery/icemachine/Initialize(mapload)
	. = ..()
	create_reagents(500)


/obj/machinery/icemachine/attackby(obj/item/I, mob/user, params)
	if(user.a_intent == INTENT_HARM)
		return ..()

	if(istype(I, /obj/item/reagent_containers/glass))
		add_fingerprint(user)
		if(beaker)
			to_chat(user, span_warning("The [beaker.name] is already inside [src]."))
			return ATTACK_CHAIN_PROCEED
		if(!user.drop_transfer_item_to_loc(I, src))
			return ..()
		beaker = I
		to_chat(user, span_notice("You have inserted [I] into [src]."))
		updateUsrDialog()
		return ATTACK_CHAIN_BLOCKED_ALL

	if(istype(I, /obj/item/reagent_containers/food/snacks/icecream))
		add_fingerprint(user)
		if(I.reagents.has_reagent("sprinkles"))
			to_chat(user, span_warning("The [I.name] already has some sprinkles."))
			return ATTACK_CHAIN_PROCEED
		to_chat(user, span_notice("You have added sprinkles to [I]."))
		if(I.reagents.total_volume > 29)
			I.reagents.remove_any(1)
		I.reagents.add_reagent("sprinkles", 1)
		I.name += " with sprinkles"
		I.desc += " Flavored with sprinkles."
		return ATTACK_CHAIN_PROCEED_SUCCESS

	return ..()


/obj/machinery/icemachine/proc/validexchange(reag)
	if(reag == "sprinkles" | reag == "cola" | reag == "kahlua" | reag == "dr_gibb" | reag == "vodka" | reag == "space_up" | reag == "rum" | reag == "spacemountainwind" | reag == "gin" | reag == "cream" | reag == "water")
		return 1
	else
		if(reagents.total_volume < 500)
			to_chat(usr, "<span class='notice'>[src] vibrates for a moment, apparently accepting the unknown liquid.</span>")
			playsound(loc, 'sound/machines/twobeep.ogg', 10, 1)
		return 1


/obj/machinery/icemachine/Topic(href, href_list)
	if(..()) return

	add_fingerprint(usr)
	usr.set_machine(src)

	if(href_list["close"])
		close_window(usr, "cream_master")
		usr.unset_machine()
		return

	var/obj/item/reagent_containers/glass/A = null
	var/datum/reagents/R = null

	if(beaker)
		A = beaker
		R = A.reagents

	if(href_list["add"])
		if(href_list["amount"])
			var/id = href_list["add"]
			var/amount = text2num(href_list["amount"])
			if(validexchange(id))
				R.trans_id_to(src, id, amount)

	else if(href_list["remove"])
		if(href_list["amount"])
			var/id = href_list["remove"]
			var/amount = text2num(href_list["amount"])
			if(beaker == null)
				reagents.remove_reagent(id,amount)
			else
				if(validexchange(id))
					reagents.trans_id_to(A, id, amount)
				else
					reagents.remove_reagent(id,amount)

	else if(href_list["main"])
		attack_hand(usr)
		return

	else if(href_list["eject"])
		if(beaker)
			A.forceMove(loc)
			beaker = null
			reagents.trans_to(A,reagents.total_volume)

	else if(href_list["synthcond"])
		if(href_list["type"])
			var/ID = text2num(href_list["type"])
			/*
			if(ID == 1)
				reagents.add_reagent("sprinkles",1)
				*/ //Sprinkles are now created by using the ice cream on the machine
			if(ID == 2 | ID == 3)
				var/brand = pick(1,2,3,4)
				if(brand == 1)
					if(ID == 2)
						reagents.add_reagent("cola",5)
					else
						reagents.add_reagent("kahlua",5)
				else if(brand == 2)
					if(ID == 2)
						reagents.add_reagent("dr_gibb",5)
					else
						reagents.add_reagent("vodka",5)
				else if(brand == 3)
					if(ID == 2)
						reagents.add_reagent("space_up",5)
					else
						reagents.add_reagent("rum",5)
				else if(brand == 4)
					if(ID == 2)
						reagents.add_reagent("spacemountainwind",5)
					else
						reagents.add_reagent("gin",5)
			else if(ID == 4)
				if(reagents.total_volume <= 500 & reagents.total_volume >= 15)
					reagents.add_reagent("cream",(30 - reagents.total_volume))
				else if(reagents.total_volume <= 15)
					reagents.add_reagent("cream",(15 - reagents.total_volume))
			else if(ID == 5)
				if(reagents.total_volume <= 500 & reagents.total_volume >= 15)
					reagents.add_reagent("water",(30 - reagents.total_volume))
				else if(reagents.total_volume <= 15)
					reagents.add_reagent("water",(15 - reagents.total_volume))

	else if(href_list["createcup"])
		var/name = generate_name(reagents.get_master_reagent_name())
		name += " Chocolate Cone"
		var/obj/item/reagent_containers/food/snacks/icecream/icecreamcup/C
		C = new/obj/item/reagent_containers/food/snacks/icecream/icecreamcup(loc)
		C.name = "[name]"
		C.pixel_x = rand(-8, 8)
		C.pixel_y = -16
		reagents.trans_to(C,30)
		if(reagents)
			reagents.clear_reagents()
		C.update_icon()

	else if(href_list["createcone"])
		var/name = generate_name(reagents.get_master_reagent_name())
		name += " Cone"
		var/obj/item/reagent_containers/food/snacks/icecream/icecreamcone/C
		C = new/obj/item/reagent_containers/food/snacks/icecream/icecreamcone(loc)
		C.name = "[name]"
		C.pixel_x = rand(-8, 8)
		C.pixel_y = -16
		reagents.trans_to(C,15)
		if(reagents)
			reagents.clear_reagents()
		C.update_icon()
	updateUsrDialog()


/obj/machinery/icemachine/attack_ai(mob/user)
	return attack_hand(user)


/obj/machinery/icemachine/proc/show_toppings()
	var/dat = ""
	if(reagents.total_volume <= 500)
		dat += "<hr>"
		dat += "<strong>Add fillings:</strong><br>"
		dat += "<a href='byond://?src=[UID()];synthcond=1;type=2'>Soda</a><br>"
		dat += "<a href='byond://?src=[UID()];synthcond=1;type=3'>Alcohol</a><br>"
		dat += "<strong>Finish With:</strong><br>"
		dat += "<a href='byond://?src=[UID()];synthcond=1;type=4'>Cream</a><br>"
		dat += "<a href='byond://?src=[UID()];synthcond=1;type=5'>Water</a><br>"
		dat += "<strong>Dispense in:</strong><br>"
		dat += "<a href='byond://?src=[UID()];createcup=1'>Chocolate Cone</a><br>"
		dat += "<a href='byond://?src=[UID()];createcone=1'>Cone</a><br>"
	dat += "</center>"
	return dat


/obj/machinery/icemachine/proc/show_reagents(container)
	//1 = beaker / 2 = internal
	var/dat = ""
	if(container == 1)
		var/obj/item/reagent_containers/glass/A = beaker
		var/datum/reagents/R = A.reagents
		dat += "The container has:<br>"
		for(var/datum/reagent/G in R.reagent_list)
			dat += "[G.volume] unit(s) of [G.name] | "
			dat += "<a href='byond://?src=[UID()];add=[G.id];amount=5'>(5)</a> "
			dat += "<a href='byond://?src=[UID()];add=[G.id];amount=10'>(10)</a> "
			dat += "<a href='byond://?src=[UID()];add=[G.id];amount=15'>(15)</a> "
			dat += "<a href='byond://?src=[UID()];add=[G.id];amount=[G.volume]'>(All)</a>"
			dat += "<br>"
	else if(container == 2)
		dat += "<br>The Cream-Master has:<br>"
		if(reagents.total_volume)
			for(var/datum/reagent/N in reagents.reagent_list)
				dat += "[N.volume] unit(s) of [N.name] | "
				dat += "<a href='byond://?src=[UID()];remove=[N.id];amount=5'>(5)</a> "
				dat += "<a href='byond://?src=[UID()];remove=[N.id];amount=10'>(10)</a> "
				dat += "<a href='byond://?src=[UID()];remove=[N.id];amount=15'>(15)</a> "
				dat += "<a href='byond://?src=[UID()];remove=[N.id];amount=[N.volume]'>(All)</a>"
				dat += "<br>"
	else
		dat += "<br>SOMEONE ENTERED AN INVALID REAGENT CONTAINER; QUICK, BUG REPORT!<br>"
	return dat


/obj/machinery/icemachine/attack_hand(mob/user)
	if(..()) return
	user.set_machine(src)
	var/dat = ""
	if(!beaker)
		dat += "No container is loaded into the machine, external transfer offline.<br>"
		dat += show_reagents(2)
		dat += show_toppings()
		dat += "<a href='byond://?src=[UID()];close=1'>Close</a>"
	else
		var/obj/item/reagent_containers/glass/A = beaker
		var/datum/reagents/R = A.reagents
		dat += "<a href='byond://?src=[UID()];eject=1'>Eject container and end transfer.</a><br>"
		if(!R.total_volume)
			dat += "Container is empty.<br><hr>"
		else
			dat += show_reagents(1)
		dat += show_reagents(2)
		dat += show_toppings()
	var/datum/browser/popup = new(user, "cream_master","Cream-Master Deluxe", 700, 400, src)
	popup.set_content(dat)
	popup.open()

/obj/machinery/icemachine/deconstruct(disassembled = TRUE)
	if(!(obj_flags & NODECONSTRUCT))
		new /obj/item/stack/sheet/metal(loc, 4)
	qdel(src)
