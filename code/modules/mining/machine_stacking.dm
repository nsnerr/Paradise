/**********************Mineral stacking unit console**************************/

/obj/machinery/mineral/stacking_unit_console
	name = "stacking machine console"
	icon = 'icons/obj/machines/mining_machines.dmi'
	icon_state = "console"
	desc = "Controls a stacking machine... in theory."
	density = FALSE
	anchored = TRUE
	var/obj/machinery/mineral/stacking_machine/machine = null
	var/machinedir = SOUTHEAST

/obj/machinery/mineral/stacking_unit_console/Initialize(mapload)
	. = ..()
	machine = locate(/obj/machinery/mineral/stacking_machine, get_step(src, machinedir))
	if(machine)
		machine.CONSOLE = src
	else
		return INITIALIZE_HINT_QDEL

/obj/machinery/mineral/stacking_unit_console/attack_hand(mob/user)
	if(..())
		return TRUE

	add_fingerprint(user)

	var/obj/item/stack/sheet/s
	var/dat = ""

	dat += text("<b>Stacking unit console</b><br><br>")

	for(var/O in machine.stack_list)
		s = machine.stack_list[O]
		if(s.amount > 0)
			dat += "[capitalize(s.name)]: [s.amount] <a href='byond://?src=[UID()];release=[s.type]'>Release</a><br>"

	dat += "<br>Stacking: [machine.stack_amt]<br><br>"

	var/datum/browser/popup = new(user, "console_stacking_machine", "Stacking machine")
	popup.set_content(dat)
	popup.open(FALSE)

/obj/machinery/mineral/stacking_unit_console/Topic(href, href_list)
	if(..())
		return
	usr.set_machine(src)
	add_fingerprint(usr)
	if(href_list["release"])
		if(!(text2path(href_list["release"]) in machine.stack_list))
			return //someone tried to spawn materials by spoofing hrefs
		var/obj/item/stack/sheet/inp = machine.stack_list[text2path(href_list["release"])]
		var/obj/item/stack/sheet/out = new inp.type()
		out.amount = inp.amount
		inp.amount = 0
		machine.unload_mineral(out)

	updateUsrDialog()

/**********************Mineral stacking unit**************************/


/obj/machinery/mineral/stacking_machine
	name = "stacking machine"
	icon = 'icons/obj/machines/mining_machines.dmi'
	icon_state = "stacker"
	desc = "A machine that automatically stacks acquired materials. Controlled by a nearby console."
	density = TRUE
	anchored = TRUE
	var/obj/machinery/mineral/stacking_unit_console/CONSOLE
	var/stk_types = list()
	var/stk_amt   = list()
	var/stack_list[0] //Key: Type.  Value: Instance of type.
	var/stack_amt = 50; //ammount to stack before releassing
	input_dir = EAST
	output_dir = WEST
	speed_process = TRUE

/obj/machinery/mineral/stacking_machine/process()
	var/turf/T = get_step(src, input_dir)
	if(T)
		for(var/obj/item/stack/sheet/S in T)
			process_sheet(S)
			CHECK_TICK

/obj/machinery/mineral/stacking_machine/proc/process_sheet(obj/item/stack/sheet/inp)
	if(!(inp.type in stack_list)) //It's the first of this sheet added
		var/obj/item/stack/sheet/s = new inp.type(src,0)
		s.amount = 0
		stack_list[inp.type] = s
	var/obj/item/stack/sheet/storage = stack_list[inp.type]
	storage.amount += inp.amount //Stack the sheets
	inp.loc = null //Let the old sheet garbage collect
	while(storage.amount > stack_amt) //Get rid of excessive stackage
		var/obj/item/stack/sheet/out = new inp.type()
		out.amount = stack_amt
		unload_mineral(out)
		storage.amount -= stack_amt
