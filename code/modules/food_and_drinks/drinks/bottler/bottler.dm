
//adjust these to change the maximum capacity of the bottler for each container type
#define MAX_GLASS 10
#define MAX_PLAST 20
#define MAX_METAL 25

//adjust these to change the number of containers the bottler will make per sheet
#define RATIO_GLASS 1
#define RATIO_PLAST 2
#define RATIO_METAL 5

/obj/machinery/bottler
	name = "bottler unit"
	desc = "A machine that combines ingredients and bottles the resulting beverages."
	icon = 'icons/obj/kitchen.dmi'
	icon_state = "bottler_off"
	density = TRUE
	anchored = TRUE
	var/list/slots[3]
	var/list/datum/bottler_recipe/available_recipes
	var/list/acceptable_items
	var/list/containers = list("glass bottle" = 10, "plastic bottle" = 20, "metal can" = 25)
	var/bottling = FALSE

/obj/machinery/bottler/New()
	. = ..()
	if(!available_recipes)
		available_recipes = list()
		acceptable_items = list()
		//These are going to be acceptable even if they aren't in a recipe
		acceptable_items |= /obj/item/reagent_containers/food/snacks
		acceptable_items |= /obj/item/reagent_containers/food/drinks/cans
		//the rest is based on what is used in recipes so we don't have people destroying the nuke disc
		for(var/type in subtypesof(/datum/bottler_recipe))
			var/datum/bottler_recipe/recipe = new type
			if(recipe.result) // Ignore recipe subtypes that lack a result
				available_recipes += recipe
				for(var/i = 1, i <= recipe.ingredients.len, i++)
					acceptable_items |= recipe.ingredients[i]
			else
				qdel(recipe)


/obj/machinery/bottler/attackby(obj/item/I, mob/user, params)
	if(user.a_intent == INTENT_HARM)
		return ..()

	if(is_type_in_list(I, acceptable_items))
		add_fingerprint(user)
		if(istype(I, /obj/item/reagent_containers/food/snacks))
			var/obj/item/reagent_containers/food/snacks/snack = I
			//This prevents us from using empty foods, should one occur due to some sort of error
			if(snack.reagents && !snack.reagents.total_volume)
				to_chat(user, span_warning("The [snack.name] is incompatible."))
				return ATTACK_CHAIN_BLOCKED_ALL
			if(!user.drop_transfer_item_to_loc(snack, src))
				return ..()
			insert_item(snack, user)
			return ATTACK_CHAIN_BLOCKED_ALL

		if(istype(I, /obj/item/reagent_containers/food/drinks/cans))
			var/obj/item/reagent_containers/food/drinks/cans/can = I
			if(!can.reagents)
				to_chat(user, span_warning("The [can.name] is incompatible."))
				return ATTACK_CHAIN_PROCEED
			//This prevents us from using opened cans that still have something in them
			if(can.canopened && can.reagents.total_volume)
				to_chat(user, span_warning("Only unopened cans and bottles can be processed to ensure product integrity."))
				return ATTACK_CHAIN_PROCEED
			if(!user.drop_transfer_item_to_loc(can, src))
				return ..()
			if(can.reagents.total_volume)
				//Full cans that are unopened get inserted for processing as ingredients
				insert_item(can, user)
			else
				//Empty cans get recycled, even if they have somehow remained unopened due to some sort of error
				recycle_container(can)
			return ATTACK_CHAIN_BLOCKED_ALL

		if(!user.drop_transfer_item_to_loc(I, src))
			return ..()
		insert_item(I, user)
		return ATTACK_CHAIN_BLOCKED_ALL

	//Crushed cans (and bottles) are returnable still
	if(istype(I, /obj/item/trash/can))
		add_fingerprint(user)
		if(!user.drop_transfer_item_to_loc(I, src))
			return ..()
		recycle_container(I)
		return ATTACK_CHAIN_BLOCKED_ALL

	//Sheets of materials can replenish the machine's supply of drink containers (when people inevitably don't return them)
	if(istype(I, /obj/item/stack/sheet))
		add_fingerprint(user)
		if(!user.drop_transfer_item_to_loc(I, src))
			return ..()
		process_sheets(I)
		return ATTACK_CHAIN_BLOCKED_ALL

	//If it doesn't qualify in the above checks, we don't want it. Inform the person so they (ideally) stop trying to put the nuke disc in.
	to_chat(user, span_warning("You aren't sure this is able to be processed by the machine."))
	return ATTACK_CHAIN_PROCEED


/obj/machinery/bottler/wrench_act(mob/user, obj/item/I)
	. = TRUE
	if(!I.use_tool(src, user, 0, volume = I.tool_volume))
		return
	set_anchored(!anchored)
	if(anchored)
		WRENCH_ANCHOR_MESSAGE
	else
		WRENCH_UNANCHOR_MESSAGE

/obj/machinery/bottler/proc/insert_item(obj/item/O, mob/user)
	if(!O || !user)
		return
	if(slots[1] && slots[2] && slots[3])
		to_chat(user, "<span class='warning'>[src] is full, please remove or process the contents first.</span>")
		return
	var/slot_inserted = 0
	for(var/i = 1, i <= slots.len, i++)
		if(!slots[i])
			slots[i] = O
			slot_inserted = i
			break
	if(!slot_inserted)
		to_chat(user, "<span class='warning'>Something went wrong and the machine spits out [O].</span>")
		O.forceMove(loc)
	else
		to_chat(user, "<span class='notice'>You load [O] into the [slot_inserted]\th ingredient tray.</span>")
		O.forceMove(src)
	updateUsrDialog()

/obj/machinery/bottler/proc/eject_items(var/slot)
	var/obj/item/O = null
	if(!slot)
		for(var/i = 1, i <= slots.len, i++)
			if(slots[i])
				O = slots[i]
				O.forceMove(loc)
				slots[i] = null
		visible_message("<span class='notice'>[src] beeps as it ejects the contents of all the ingredient trays.</span>")
	else
		if(slots[slot])		//ensures the tray actually has something to eject so we don't runtime on trying to reference null
			O = slots[slot]
			O.forceMove(loc)
			slots[slot] = null
			visible_message("<span class='notice'>[src] beeps as it ejects [O.name] from the [slot]\th ingredient tray.</span>")
	updateUsrDialog()

/obj/machinery/bottler/proc/recycle_container(obj/item/O)
	if(!O)
		return
	var/con_type
	var/max_define
	if(istype(O, /obj/item/trash/can))
		var/obj/item/trash/can/C = O
		if(C.is_glass)
			con_type = "glass bottle"
			max_define = MAX_GLASS
		else if(C.is_plastic)
			con_type = "plastic bottle"
			max_define = MAX_PLAST
		else
			con_type = "metal can"
			max_define = MAX_METAL
	else if(istype(O, /obj/item/reagent_containers/food/drinks/cans))
		var/obj/item/reagent_containers/food/drinks/cans/C = O
		if(C.is_glass)
			con_type = "glass bottle"
			max_define = MAX_GLASS
		else if(C.is_plastic)
			con_type = "plastic bottle"
			max_define = MAX_PLAST
		else
			con_type = "metal can"
			max_define = MAX_METAL
	if(con_type)
		if(containers[con_type] < max_define)
			containers[con_type]++
			visible_message("<span class='notice'>[src] whirs briefly as it prepares the container for reuse.</span>")
			qdel(O)
			updateUsrDialog()
		else
			visible_message("<span class='warning'>[src] cannot store any more cans at this time. Please fill some before recycling more.</span>")
			O.forceMove(loc)

/obj/machinery/bottler/proc/process_sheets(obj/item/stack/sheet/S)
	if(!S)
		return
	S.forceMove(loc)
	var/con_type
	var/max_define
	var/mat_ratio
	//Glass sheets for glass bottles (1 bottle per sheet)
	if(istype(S, /obj/item/stack/sheet/glass))
		con_type = "glass bottle"
		max_define = MAX_GLASS
		mat_ratio = RATIO_GLASS
	else if(istype(S, /obj/item/stack/sheet/plastic))
		con_type = "plastic bottle"
		max_define = MAX_PLAST
		mat_ratio = RATIO_PLAST
	else if(istype(S, /obj/item/stack/sheet/metal))
		con_type = "metal can"
		max_define = MAX_METAL
		mat_ratio = RATIO_METAL
	else
		visible_message("<span class='warning'>[src] rejects the unusable materials.</span>")
		return
	var/missing
	var/sheets_needed
	var/sheets_to_use
	if(con_type)
		missing = max_define - containers[con_type]
		sheets_needed = round(missing / mat_ratio, 1)
		if(missing % mat_ratio)
			sheets_needed += 1
		sheets_to_use = min(sheets_needed, S.amount)
	if(missing)
		visible_message("<span class='notice'>[src] shudders as it converts [sheets_to_use] [S.singular_name]\s into new [con_type]s.</span>")
		containers[con_type] += sheets_to_use * mat_ratio
		containers[con_type] = min(containers[con_type], max_define)
		S.use(sheets_to_use)
	else
		visible_message("<span class='warning'>[src] rejects the [S] because it already is fully stocked with [con_type]s.</span>")

/obj/machinery/bottler/proc/select_recipe()
	for(var/datum/bottler_recipe/recipe in available_recipes)
		var/number_matches = 0
		for(var/i = 1, i <= slots.len, i++)
			var/obj/item/O = slots[i]
			if(istype(O, recipe.ingredients[i]))
				number_matches++
		if(number_matches == 3)
			return recipe
	return null

/obj/machinery/bottler/proc/dispense_empty_container(container)
	var/con_type
	var/obj/item/reagent_containers/food/drinks/cans/bottler/drink_container
	switch(container)
		if(1)	//glass bottle
			con_type = "glass bottle"
			drink_container = /obj/item/reagent_containers/food/drinks/cans/bottler/glass_bottle
		if(2)	//plastic bottle
			con_type = "plastic bottle"
			drink_container = /obj/item/reagent_containers/food/drinks/cans/bottler/plastic_bottle
		if(3)	//metal can
			con_type = "metal can"
			drink_container = /obj/item/reagent_containers/food/drinks/cans/bottler/metal_can
	if(containers[con_type])
		//empties aren't sealed, so let's open it quietly
		drink_container = new drink_container()
		drink_container.canopened = TRUE
		drink_container.container_type |= OPENCONTAINER
		drink_container.forceMove(loc)
		containers[con_type]--

/obj/machinery/bottler/proc/process_ingredients(container)
	//stop if we have ZERO ingredients (what would you process?)
	if(!slots[1] && !slots[2] && !slots[3])
		visible_message("<span class='warning'>There are no ingredients to process! Please insert some first.</span>")
		return
	//prep a container
	var/obj/item/reagent_containers/food/drinks/cans/bottler/drink_container
	var/con_type
	switch(container)
		if(1)	//glass bottle
			con_type = "glass bottle"
			drink_container = /obj/item/reagent_containers/food/drinks/cans/bottler/glass_bottle
		if(2)	//plastic bottle
			con_type = "plastic bottle"
			drink_container = /obj/item/reagent_containers/food/drinks/cans/bottler/plastic_bottle
		if(3)	//metal can
			con_type = "metal can"
			drink_container = /obj/item/reagent_containers/food/drinks/cans/bottler/metal_can

	if(!con_type)
		visible_message("<span class='warning'>Error 404: Drink Container Not Found.</span>")
		return
	if(!containers[con_type])
		visible_message("<span class='warning'>Error 503: Out of [con_type]s.</span>")
		return
	else
		drink_container = new drink_container()
		containers[con_type]--
	//select and process a recipe based on inserted ingredients
	visible_message("<span class='notice'>[src] hums as it processes the ingredients...</span>")
	bottling = TRUE
	update_icon(UPDATE_ICON_STATE)
	var/datum/bottler_recipe/recipe_to_use = select_recipe()
	if(!recipe_to_use)
		//bad recipe, ruins the drink
		var/contents = pick("thick goop", "pungent sludge", "unspeakable slurry", "gross-looking concoction", "eldritch abomination of liquids")
		visible_message("<span class='warning'>The [con_type] fills with \an [contents]...</span>")
		drink_container.reagents.add_reagent(pick("????", "toxic_slurry", "meatslurry", "glowing_slurry", "fishwater"), pick(30, 50))
		drink_container.name = "Liquid Mistakes"
		drink_container.desc = "WARNING: CONTENTS MAY BE AWFUL, DRINK AT OWN RISK."
	else
		//good recipe, make it
		visible_message("<span class='notice'>The [con_type] fills with a delicious-looking beverage!</span>")
		drink_container.reagents.add_reagent(recipe_to_use.result, 50)
		drink_container.name = "[recipe_to_use.name]"
		drink_container.desc = "[recipe_to_use.description]"
	flick("bottler_on", src)
	spawn(45)
		resetSlots()
		bottling = FALSE
		update_icon(UPDATE_ICON_STATE)
		drink_container.forceMove(loc)
		updateUsrDialog()

/obj/machinery/bottler/attack_ai(mob/user)
	attack_hand(user)

/obj/machinery/bottler/attack_ghost(mob/user)
	attack_hand(user)

/obj/machinery/bottler/attack_hand(mob/user)
	if(stat & BROKEN)
		return

	if(..())
		return TRUE

	add_fingerprint(user)
	interact(user)

/obj/machinery/bottler/interact(mob/user)
	user.set_machine(src)
	//html ahoy
	var/dat = {"<!DOCTYPE html><meta charset="UTF-8">"}
	if(bottling)
		dat = "<h2>Bottling in process, please wait...</h2>"
	else
		dat += "<table border='1' style='width:75%'>"
		dat += "<tr>"
		dat += "<th colspan='3'>Containers:</th>"
		dat += "</tr>"
		dat += "<tr>"
		dat += "<td>Glass Bottles: [containers["glass bottle"]]</td>"
		dat += "<td>Plastic Bottles: [containers["plastic bottle"]]</td>"
		dat += "<td>Metal Cans: [containers["metal can"]]</td>"
		dat += "</tr>"
		dat += "<tr>"
		if(containers["glass bottle"])
			dat += "<td><a href='byond://?src=[UID()];dispense=1'>Dispense</a></td>"
		else
			dat += "<td>Out of stock</td>"
		if(containers["plastic bottle"])
			dat += "<td><a href='byond://?src=[UID()];dispense=2'>Dispense</a></td>"
		else
			dat += "<td>Out of stock</td>"
		if(containers["metal can"])
			dat += "<td><a href='byond://?src=[UID()];dispense=3'>Dispense</a></td>"
		else
			dat += "<td>Out of stock</td>"
		dat += "</tr>"
		dat += "</table>"
		dat += "<hr>"
		dat += "<table border='1' style='width:75%'>"
		dat += "<tr>"
		dat += "<th colspan='4'>Ingredient Tray Contents:</th>"
		dat += "</tr>"

		dat += "<tr>"
		for(var/i = 1, i <= slots.len, i++)
			var/obj/O = slots[i]
			if(O)
				dat += "<td>[bicon(O)]<br>[O.name]</td>"
			else
				dat += "<td>Tray Empty</td>"

		if(slots[1] && slots[2] && slots[3])
			dat += "<td><a href='byond://?src=[UID()];process=1'>Process Ingredients</a></td>"
		else
			dat += "<td>Insufficient Ingredients</td>"
		dat += "</tr>"

		dat += "<tr>"
		for(var/i = 1, i <= slots.len, i++)
			if(slots[i])
				dat += "<td><a href='byond://?src=[UID()];eject=[i]'>Eject</a></td>"
			else
				dat += "<td>N/A</td>"
		dat += "<td><a href='byond://?src=[UID()];eject=0'>Eject All</a></td>"
		dat += "</tr>"
		dat += "</table>"
		dat += "<hr>"
		dat += "<p>Insert three ingredients and press process to create a beverage. You will be able to select a container for the beverage before processing begins.</p>"
		dat += "<p>Inserting empty bottles and cans, as well as sheets of glass, plastic, or metal will restock the appropriate container supply.</p>"
	var/datum/browser/popup = new(user, "bottler", "Bottler Menu", 575, 400)
	popup.set_content(dat)
	popup.open()

/obj/machinery/bottler/Topic(href, href_list)
	if(..())
		return 1
	if(bottling)
		return

	add_fingerprint(usr)
	usr.set_machine(src)

	if(href_list["process"])
		var/list/choices = list("Glass Bottle" = 1, "Plastic Bottle" = 2, "Metal Can" = 3)
		var/selection = tgui_input_list(usr, "Select a container for your beverage", "Container", choices)
		if(!selection)
			return
		else
			selection = choices[selection]
			process_ingredients(selection)

	if(href_list["eject"])
		var/slot = text2num(href_list["eject"])
		eject_items(slot)

	if(href_list["dispense"])
		var/container = text2num(href_list["dispense"])
		dispense_empty_container(container)

	updateUsrDialog()
	return

/obj/machinery/bottler/update_icon_state()
	if(stat & BROKEN)
		icon_state = "bottler_broken"
	else if(bottling)
		icon_state = "bottler_on"
	else
		icon_state = "bottler_off"

/obj/machinery/bottler/proc/resetSlots()
	QDEL_LIST_ASSOC_VAL(slots)
	slots.len = 3
