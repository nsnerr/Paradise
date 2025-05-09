//Cloning revival method.
//The pod handles the actual cloning while the computer manages the clone profiles

//Potential replacement for genetics revives or something I dunno (?)

#define CLONE_BIOMASS 150

#define BIOMASS_BASE_AMOUNT 50 // How much biomass a BIOMASSABLE item gives the cloning pod

// Not a comprehensive list: Further PRs should add appropriate items here.
// Meat as usual, monstermeat covers goliath, xeno, spider, bear meat
GLOBAL_LIST_INIT(cloner_biomass_items, list(\
/obj/item/reagent_containers/food/snacks/meat,\
/obj/item/reagent_containers/food/snacks/monstermeat,
/obj/item/reagent_containers/food/snacks/carpmeat,
/obj/item/reagent_containers/food/snacks/salmonmeat,
/obj/item/reagent_containers/food/snacks/catfishmeat,
/obj/item/reagent_containers/food/snacks/tofurkey))

#define MINIMUM_HEAL_LEVEL 40
#define CLONE_INITIAL_DAMAGE 190
#define BRAIN_INITIAL_DAMAGE 90 // our minds are too feeble for 190

/obj/machinery/clonepod
	anchored = TRUE
	name = "experimental biomass pod"
	desc = "Капсула, предназначенная для искусственного выращивания органической ткани. Оборудована электронным замком. Выглядит жутковато."
	ru_names = list(
		NOMINATIVE = "капсула клонирования",
		GENITIVE = "капсулы клонирования",
		DATIVE = "капсуле клонирования",
		ACCUSATIVE = "капсулу клонирования",
		INSTRUMENTAL = "капсулой клонирования",
		PREPOSITIONAL = "капсуле клонирования"
	)
	density = TRUE
	icon = 'icons/obj/machines/cloning.dmi'
	icon_state = "pod_idle"
	req_access = list(ACCESS_MEDICAL) //For premature unlocking.

	var/mob/living/carbon/human/occupant
	var/heal_level //The clone is released once its health reaches this level.
	var/obj/machinery/computer/cloning/connected = null //So we remember the connected clone machine.
	var/mess = FALSE //Need to clean out it if it's full of exploded clone.
	var/attempting = FALSE //One clone attempt at a time thanks
	var/biomass = 0
	var/speed_coeff
	var/efficiency

	var/datum/mind/clonemind
	var/grab_ghost_when = CLONER_MATURE_CLONE

	var/obj/item/radio/Radio
	var/radio_announce = TRUE

	var/obj/effect/countdown/clonepod/countdown

	var/list/brine_types = list("corazone", "perfluorodecalin", "epinephrine", "salglu_solution") //stops heart attacks, heart failure, shock, and keeps their O2 levels normal
	var/list/missing_organs
	var/organs_number = 0

	light_color = LIGHT_COLOR_PURE_GREEN


/obj/machinery/clonepod/power_change(forced = FALSE)
	..() //we don't check return here because we also care about the BROKEN flag
	if(!(stat & (BROKEN|NOPOWER)))
		set_light(2)
	else
		set_light_on(FALSE)


/obj/machinery/clonepod/biomass
	biomass = CLONE_BIOMASS

/obj/machinery/clonepod/New()
	..()

	if(is_taipan(z)) //Синдидоступ и никаких анонсов о клонированных при сборке на тайпане
		radio_announce = FALSE
		req_access = list(ACCESS_SYNDICATE)

	countdown = new(src)

	Radio = new /obj/item/radio(src)
	Radio.listening = 0
	Radio.config(list("Medical" = 0))

	component_parts = list()
	component_parts += new /obj/item/circuitboard/clonepod(null)
	component_parts += new /obj/item/stock_parts/scanning_module(null)
	component_parts += new /obj/item/stock_parts/scanning_module(null)
	component_parts += new /obj/item/stock_parts/manipulator(null)
	component_parts += new /obj/item/stock_parts/manipulator(null)
	component_parts += new /obj/item/stack/sheet/glass(null)
	component_parts += new /obj/item/stack/cable_coil(null, 1)
	component_parts += new /obj/item/stack/cable_coil(null, 1)
	component_parts += new /obj/item/stock_parts/capacitor/quadratic(null)
	component_parts += new /obj/item/stock_parts/capacitor/quadratic(null)
	component_parts += new /obj/item/stock_parts/capacitor/quadratic(null)
	component_parts += new /obj/item/stock_parts/capacitor/quadratic(null)
	component_parts += new /obj/item/stock_parts/capacitor/quadratic(null)
	RefreshParts()
	update_icon()

/obj/machinery/clonepod/upgraded/New()
	..()
	component_parts = list()
	component_parts += new /obj/item/circuitboard/clonepod(null)
	component_parts += new /obj/item/stock_parts/scanning_module/phasic(null)
	component_parts += new /obj/item/stock_parts/scanning_module/phasic(null)
	component_parts += new /obj/item/stock_parts/manipulator/pico(null)
	component_parts += new /obj/item/stock_parts/manipulator/pico(null)
	component_parts += new /obj/item/stack/sheet/glass(null)
	component_parts += new /obj/item/stack/cable_coil(null, 1)
	component_parts += new /obj/item/stack/cable_coil(null, 1)
	component_parts += new /obj/item/stock_parts/capacitor/quadratic(null)
	component_parts += new /obj/item/stock_parts/capacitor/quadratic(null)
	component_parts += new /obj/item/stock_parts/capacitor/quadratic(null)
	component_parts += new /obj/item/stock_parts/capacitor/quadratic(null)
	component_parts += new /obj/item/stock_parts/capacitor/quadratic(null)
	biomass = CLONE_BIOMASS
	RefreshParts()

/obj/machinery/clonepod/Destroy()
	if(connected)
		connected.pods -= src
	if(clonemind)
		UnregisterSignal(clonemind.current, COMSIG_LIVING_REVIVE)
		UnregisterSignal(clonemind, COMSIG_MIND_TRANSER_TO)
	QDEL_NULL(Radio)
	QDEL_NULL(countdown)
	QDEL_LIST(missing_organs)
	return ..()

/obj/machinery/clonepod/RefreshParts()
	speed_coeff = 0
	efficiency = 0
	for(var/obj/item/stock_parts/scanning_module/S in component_parts)
		efficiency += S.rating
	for(var/obj/item/stock_parts/manipulator/P in component_parts)
		speed_coeff += P.rating
	heal_level = max(min((efficiency * 15) + 10, 100), MINIMUM_HEAL_LEVEL)

//The return of data disks?? Just for transferring between genetics machine/cloning machine.
//TO-DO: Make the genetics machine accept them.
/obj/item/disk/data
	name = "Cloning Data Disk"
	desc = "Дискета, предназначенная для хранения данных ДНК-кода гуманоида."
	ru_names = list(
		NOMINATIVE = "ДНК-дискета",
		GENITIVE = "ДНК-дискеты",
		DATIVE = "ДНК-дискете",
		ACCUSATIVE = "ДНК-дискету",
		INSTRUMENTAL = "ДНК-дискетой",
		PREPOSITIONAL = "ДНК-дискете"
	)
	icon_state = "datadisk0" //Gosh I hope syndies don't mistake them for the nuke disk.
	var/datum/dna2/record/buf = null
	var/read_only = FALSE //Well,it's still a floppy disk

/obj/item/disk/data/proc/initialize()
	buf = new
	buf.dna=new

/obj/item/disk/data/Destroy()
	QDEL_NULL(buf)
	return ..()

/obj/item/disk/data/demo
	name = "data disk - 'Император Человечества'"
	read_only = TRUE

/obj/item/disk/data/demo/New()
	..()
	initialize()
	buf.types=DNA2_BUF_UE|DNA2_BUF_UI
	//data = "066000033000000000AF00330660FF4DB002690"
	//data = "0C80C80C80C80C80C8000000000000161FBDDEF" - Farmer Jeff
	buf.dna.real_name="Император Человечества"
	buf.dna.unique_enzymes = md5(buf.dna.real_name)
	buf.dna.UI=list(0x066,0x000,0x033,0x000,0x000,0x000,0x000,0x000,0x000,0x000,0x000,0x000,0xAF0,0x000,0x000,0x000,0x000,0x000,0x000,0x000,0x000,0x000,0x033,0x066,0x0FF,0x4DB,0x002,0x690,0x000,0x000,0x000,0x328,0x045,0x5FC,0x053,0x035,0x035,0x035)
	//buf.dna.UI=list(0x0C8,0x0C8,0x0C8,0x0C8,0x0C8,0x0C8,0x000,0x000,0x000,0x000,0x161,0xFBD,0xDEF) // Farmer Jeff
	if(buf.dna.UI.len != DNA_UI_LENGTH) //If there's a disparity b/w the dna UI string lengths, 0-fill the extra blocks in this UI.
		for(var/i in buf.dna.UI.len to DNA_UI_LENGTH)
			buf.dna.UI += 0x000
	buf.dna.ResetSE()
	buf.dna.UpdateUI()

/obj/item/disk/data/monkey
	name = "data disk - 'Мистер Магглс'"
	read_only = 1

/obj/item/disk/data/monkey/New()
	..()
	initialize()
	buf.types=DNA2_BUF_SE
	var/list/new_SE=list(0x098,0x3E8,0x403,0x44C,0x39F,0x4B0,0x59D,0x514,0x5FC,0x578,0x5DC,0x640,0x6A4)
	for(var/i=new_SE.len;i<=DNA_SE_LENGTH;i++)
		new_SE += rand(1,1024)
	buf.dna.SE=new_SE
	buf.dna.SetSEValueRange(GLOB.monkeyblock,0xDAC, 0xFFF)

//Disk stuff.
/obj/item/disk/data/New()
	..()
	var/diskcolor = pick(0,1,2)
	icon_state = "datadisk[diskcolor]"

/obj/item/disk/data/attack_self(mob/user as mob)
	read_only = !read_only
	balloon_alert(user, "защита от записи [read_only ? "включена" : "выключена"]")

/obj/item/disk/data/examine(mob/user)
	. = ..()
	. += span_notice("Механизм защиты от записи [read_only ? "включён" : "выключен"].")

//Clonepod

/obj/machinery/clonepod/examine(mob/user)
	. = ..()
	if(mess)
		. += span_warning("Она заполнена мессивом из крови и внутренностей. Вам кажется или оно сейчас сдвинулось..?")
	if(HAS_TRAIT(src, TRAIT_CMAGGED))
		. += span_warning("Из камеры хранения органического сырья сочится жёлтая слизь...")
	if(!occupant || stat & (NOPOWER|BROKEN))
		return
	if(occupant && occupant.stat != DEAD)
		. += span_notice("Процесс клонирования завершён на [round(get_completion())]%.")

/obj/machinery/clonepod/return_air() //non-reactive air
	var/datum/gas_mixture/GM = new
	GM.nitrogen = MOLES_O2STANDARD + MOLES_N2STANDARD
	GM.temperature = T20C
	return GM

/obj/machinery/clonepod/proc/get_completion()
	. = (100 * ((occupant.health + 100) / (heal_level + 100)))

/obj/machinery/clonepod/attack_ai(mob/user)
	return examine(user)

//Radio Announcement

/obj/machinery/clonepod/proc/announce_radio_message(message)
	if(radio_announce)
		Radio.autosay(message, name, "Medical", list(z))

/obj/machinery/clonepod/proc/spooky_devil_flavor()
	playsound(loc, pick('sound/goonstation/voice/male_scream.ogg', 'sound/goonstation/voice/female_scream.ogg'), 100, 1)
	mess = TRUE
	update_icon()
	connected_message("<font face=\"REBUFFED\" color=#600A0A>Если ты снова попытаешься украсть у Меня, то Я приду за тобой лично.</font>")

//Start growing a human clone in the pod!
/obj/machinery/clonepod/proc/growclone(datum/dna2/record/R)
	if(mess || attempting || panel_open || stat & (NOPOWER|BROKEN))
		return 0
	clonemind = locate(R.mind)
	if(!istype(clonemind))	//not a mind
		return 0
	if(clonemind.current && clonemind.current.stat != DEAD)	//mind is associated with a non-dead body
		return 0
	if(clonemind.damnation_type)
		spooky_devil_flavor()
		return 0
	if(!clonemind.is_revivable()) //Other reasons for being unrevivable
		return 0
	if(clonemind.active)	//somebody is using that mind
		if(ckey(clonemind.key) != R.ckey )
			return 0
		if(clonemind.suicided) // and stay out!
			malfunction(go_easy = 0)
			return -1 // Flush the record
	else
		// get_ghost() will fail if they're unable to reenter their body
		var/mob/dead/observer/G = clonemind.get_ghost()
		if(!G)
			return 0

/*
	if(clonemind.damnation_type) //Can't clone the damned.
		playsound('sound/hallucinations/veryfar_noise.ogg', 50, 0)
		malfunction()
 		return -1 // so that the record gets flushed out
	*/

	if(biomass >= CLONE_BIOMASS)
		biomass -= CLONE_BIOMASS
	else
		return 0

	attempting = TRUE // One at a time!!
	countdown.start()

	if(!R.dna)
		R.dna = new /datum/dna()

	var/mob/living/carbon/human/H = new /mob/living/carbon/human(src)
	H.set_species(R.dna.species.type)
	occupant = H

	if(!R.dna.real_name)	// to prevent null names
		R.dna.real_name = H.real_name
	else
		H.real_name = R.dna.real_name

	H.dna = R.dna.Clone()

	for(var/datum/language/L in R.languages)
		H.add_language(L.name)

	if(is_taipan(z))
		H.faction.Add("syndicate")	// So that Syndie guys remain Syndie guys after cloning


	H.check_genes(MUTCHK_FORCED) // Ensures species that get powers by the species proc handle_dna keep them

	if(efficiency > 2 && efficiency < 5 && prob(25))
		randmutb(H)
	if(efficiency > 5 && prob(20))
		randmutg(H)
	if(efficiency < 3 && prob(50))
		randmutb(H)

	H.dna.UpdateSE()
	H.dna.UpdateUI()

	H.sync_organ_dna(1) // It's literally a fresh body as you can get, so all organs properly belong to it
	H.UpdateAppearance()

	check_brine()
	//Get the clone body ready
	maim_clone(H)
	H.Paralyse(8 SECONDS)

	if(grab_ghost_when == CLONER_FRESH_CLONE)
		clonemind.transfer_to(H)
		H.ckey = R.ckey
		update_clone_antag(H) //Since the body's got the mind, update their antag stuff right now. Otherwise, wait until they get kicked out (as per the CLONER_MATURE_CLONE business) to do it.
		var/message
		message += "<b>Вы медленно обретаете сознание по мере того, как ваше тело восстанавливается.</b><br>"
		message += "<i>Так вот как ощущается клонирование...</i>"
		to_chat(H, span_notice("[message]"))
	else if(grab_ghost_when == CLONER_MATURE_CLONE)
		to_chat(clonemind.current, span_notice("Ваше тело начинает восстанавливаться в капсуле клонирования. Вы обретёте сознание после завершения."))
		// Set up a soul link with the dead body to catch a revival
		RegisterSignal(clonemind.current, COMSIG_LIVING_REVIVE, PROC_REF(occupant_got_revived))
		RegisterSignal(clonemind, COMSIG_MIND_TRANSER_TO, PROC_REF(occupant_got_revived))

	update_icon()

	H.suiciding = FALSE
	attempting = FALSE
	return 1

//Grow clones to maturity then kick them out. FREELOADERS
/obj/machinery/clonepod/process()
	var/show_message = FALSE
	for(var/obj/item/item in range(1, src))
		if(is_type_in_list(item, GLOB.cloner_biomass_items))
			qdel(item)
			biomass += BIOMASS_BASE_AMOUNT
			show_message = TRUE
	if(show_message)
		visible_message("[capitalize(declent_ru(NOMINATIVE))] всасывает и начинает обрабатывать полученную биомассу.")

	if(stat & NOPOWER) //Autoeject if power is lost
		if(occupant)
			go_out()
			connected_message("Клон извлечён: Недостаточно энергии.")

	else if((occupant) && (occupant.loc == src))
		if((occupant.stat == DEAD) || (occupant.suiciding) || (occupant.mind && !occupant.mind.is_revivable()))  //Autoeject corpses and suiciding dudes.
			announce_radio_message("Клонирование пациента <b>[occupant]</b>не было осуществлено из-за необратимого повреждения тканей организма.")
			go_out()
			connected_message("Клонирование невозможно: Смерть пациента.")

		else if(occupant.cloneloss > (100 - heal_level))
			occupant.Paralyse(8 SECONDS)

			 //Slowly get that clone healed and finished.
			occupant.adjustCloneLoss(-((speed_coeff/2)))

			// For human species that lack non-vital parts for some weird reason
			if(organs_number)
				var/progress = CLONE_INITIAL_DAMAGE - occupant.getCloneLoss()
				progress += (100 - MINIMUM_HEAL_LEVEL)
				var/milestone = CLONE_INITIAL_DAMAGE / organs_number
// Doing this as a #define so that the value can change when evaluated multiple times
#define INSTALLED (organs_number - LAZYLEN(missing_organs))

				while((progress / milestone) > INSTALLED && LAZYLEN(missing_organs))
					var/obj/item/organ/I = pick_n_take(missing_organs)
					I.safe_replace(occupant)

#undef INSTALLED

			//Premature clones may have brain damage.
			occupant.adjustBrainLoss(-((speed_coeff/20)*efficiency))

			check_brine()

			//Also heal some oxyloss ourselves just in case!!
			occupant.adjustOxyLoss(-10)

			use_power(7500) //This might need tweaking.

		else if((occupant.cloneloss <= (100 - heal_level)))
			connected_message("Процесс клонирования завершён..")
			announce_radio_message("Процесс клонирования пациента <b>[occupant]</b> завершён.")
			go_out()

	else if((!occupant) || (occupant.loc != src))
		occupant = null
		update_icon()
		use_power(200)


//Let's unlock this early I guess.  Might be too early, needs tweaking.
/obj/machinery/clonepod/attackby(obj/item/I, mob/user, params)
	if(user.a_intent == INTENT_HARM)
		return ..()

	if(exchange_parts(user, I))
		return ATTACK_CHAIN_PROCEED_SUCCESS

	if(I.GetID())
		add_fingerprint(user)
		if(!check_access(I))
			balloon_alert(user, "отказано в доступе!")
			return ATTACK_CHAIN_PROCEED
		if(!(occupant || mess))
			balloon_alert(user, "внутри пусто!")
			return ATTACK_CHAIN_PROCEED
		connected_message("Инициировано извлечение клона.")
		announce_radio_message("Инициировано извлечение клона [(occupant) ? occupant.real_name : ""].")
		balloon_alert(user, "клон извлечён")
		go_out()
		return ATTACK_CHAIN_PROCEED_SUCCESS

	if(HAS_TRAIT(src, TRAIT_CMAGGED))
		add_fingerprint(user)
		var/cleaning = FALSE
		if(istype(I, /obj/item/reagent_containers/spray/cleaner))
			var/obj/item/reagent_containers/spray/cleaner/cleaner = I
			if(cleaner.reagents.total_volume >= cleaner.amount_per_transfer_from_this)
				cleaning = TRUE
		else if(istype(I, /obj/item/soap))
			cleaning = TRUE
		if(!cleaning)
			return ..()
		user.visible_message(
			span_notice("[user] начина[pluralize_ru(user.gender, "ет", "ют")] счищать слизь с [declent_ru(GENITIVE)]."),
			span_notice("Вы начинаете счищать слизь с [declent_ru(GENITIVE)].")
		)
		if(!do_after(user, 5 SECONDS, src))
			return ATTACK_CHAIN_PROCEED
		user.visible_message(
			span_notice("[user] убира[pluralize_ru(user.gender, "ет", "ют")] слизь с [declent_ru(GENITIVE)]."),
			span_notice("Вы убрали слизь с [declent_ru(GENITIVE)].")
		)
		REMOVE_TRAIT(src, TRAIT_CMAGGED, CMAGGED)
		return ATTACK_CHAIN_PROCEED_SUCCESS

	// A user can feed in biomass sources manually.
	if(is_type_in_list(I, GLOB.cloner_biomass_items))
		if(!user.drop_transfer_item_to_loc(I, src))
			return ..()
		add_fingerprint(user)
		balloon_alert(user, "биомасса загружена")
		biomass += BIOMASS_BASE_AMOUNT
		qdel(I)
		return ATTACK_CHAIN_BLOCKED_ALL

	return ..()


/obj/machinery/clonepod/crowbar_act(mob/user, obj/item/I)
	. = TRUE
	default_deconstruction_crowbar(user, I)

/obj/machinery/clonepod/multitool_act(mob/user, obj/item/I)
	. = TRUE
	if(!I.use_tool(src, user, 0, volume = I.tool_volume))
		return
	if(!I.multitool_check_buffer(user))
		return
	var/obj/item/multitool/M = I
	M.set_multitool_buffer(user, src)

/obj/machinery/clonepod/screwdriver_act(mob/user, obj/item/I)
	. = TRUE
	// These icon states don't really matter since we need to call update_icon() to handle panel open/closed overlays anyway.
	default_deconstruction_screwdriver(user, null, null, I)
	update_icon(UPDATE_OVERLAYS)

/obj/machinery/clonepod/wrench_act(mob/user, obj/item/I)
	. = TRUE
	if(!I.use_tool(src, user, 0, volume = I.tool_volume))
		return
	if(occupant)
		balloon_alert(user, "внутри кто-то есть!")
		return
	set_anchored(!anchored)
	if(anchored)
		WRENCH_ANCHOR_MESSAGE
	else
		WRENCH_UNANCHOR_MESSAGE
		connected.pods -= src
		connected = null


/obj/machinery/clonepod/emag_act(mob/user)
	if(isnull(occupant))
		return
	go_out()

/obj/machinery/clonepod/cmag_act(mob/user)
	if(HAS_TRAIT(src, TRAIT_CMAGGED))
		return
	playsound(src, "sparks", 75, TRUE, SHORT_RANGE_SOUND_EXTRARANGE)
	balloon_alert(user, "хонкнуто!")
	ADD_TRAIT(src, TRAIT_CMAGGED, CMAGGED)

/obj/machinery/clonepod/proc/update_clone_antag(var/mob/living/carbon/human/H)
	// Check to see if the clone's mind is an antagonist of any kind and handle them accordingly to make sure they get their spells, HUD/whatever else back.
	if((H.mind in SSticker.mode:revolutionaries) || (H.mind in SSticker.mode:head_revolutionaries))
		SSticker.mode.update_rev_icons_added() //So the icon actually appears
	if(H.mind in SSticker.mode.syndicates)
		SSticker.mode.update_synd_icons_added()
	if(H.mind in SSticker.mode.cult)
		SSticker.mode.update_cult_icons_added(H.mind) // Adds the cult antag hud
		SSticker.mode.add_cult_actions(H.mind) // And all the actions
		if(SSticker.mode.cult_risen)
			SSticker.mode.rise(H)
			if(SSticker.mode.cult_ascendant)
				SSticker.mode.ascend(H)
 	if((H.mind in SSticker.mode.shadowling_thralls) || (H.mind in SSticker.mode.shadows))
 		SSticker.mode.update_shadow_icons_added(H.mind)

//Put messages in the connected computer's temp var for display.
/obj/machinery/clonepod/proc/connected_message(message)
	if((isnull(connected)) || (!istype(connected, /obj/machinery/computer/cloning)))
		return FALSE
	if(!message)
		return FALSE

	connected.temp = "[name] : [message]"
	connected.updateUsrDialog()
	return TRUE

/obj/machinery/clonepod/proc/go_out()
	countdown.stop()
	var/turf/T = get_turf(src)
	if(mess) //Clean that mess and dump those gibs!
		for(var/i in missing_organs)
			var/obj/I = i
			I.forceMove(T)
		missing_organs.Cut()
		mess = FALSE
		new /obj/effect/gibspawner/generic(get_turf(src), occupant)
		playsound(loc, 'sound/effects/splat.ogg', 50, 1)
		update_icon()
		return

	if(!occupant)
		return

	if(grab_ghost_when == CLONER_MATURE_CLONE)
		UnregisterSignal(clonemind.current, COMSIG_LIVING_REVIVE)
		UnregisterSignal(clonemind, COMSIG_MIND_TRANSER_TO)
		clonemind.transfer_to(occupant)
		occupant.grab_ghost()
		update_clone_antag(occupant)
		to_chat(occupant, span_userdanger("Вы не можете ничего вспомнить с момента вашей смерти!"))
		to_chat(occupant, span_notice("<b>Ваши глаза озаряет яркая вспышка!</b><br>\
			<i>Вы будто бы заново родились.</i>"))
		if(HAS_TRAIT(src, TRAIT_CMAGGED))
			playsound(loc, 'sound/items/bikehorn.ogg', 50, TRUE)
			occupant.force_gene_block(GLOB.clumsyblock, TRUE, TRUE)
			occupant.force_gene_block(GLOB.comicblock,, TRUE, TRUE)	//Until Genetics fixes you, this is your life now
		occupant.flash_eyes(visual = TRUE)
		clonemind = null


	for(var/i in missing_organs)
		qdel(i)
	missing_organs.Cut()
	occupant.SetLoseBreath(0) // Stop friggin' dying, gosh damn
	occupant.setOxyLoss(0)
	for(var/datum/disease/critical/crit in occupant.diseases)
		crit.cure()
	occupant.forceMove(T)
	occupant.update_body()
	occupant.check_genes() //Waiting until they're out before possible notransform.
	occupant.special_post_clone_handling()
	occupant = null
	update_icon()

/obj/machinery/clonepod/proc/malfunction(go_easy = FALSE)
	if(occupant)
		connected_message("Критическая ошибка!")
		announce_radio_message("Критическая ошибка! Свяжитесь со специалистом Thinktronic Systems, чтобы получить техническое обслуживание по гарантии!")
		UnregisterSignal(clonemind.current, COMSIG_LIVING_REVIVE)
		UnregisterSignal(clonemind, COMSIG_MIND_TRANSER_TO)
		if(!go_easy)
			if(occupant.mind != clonemind)
				clonemind.transfer_to(occupant)
			occupant.grab_ghost() // We really just want to make you suffer.
			var/message
			message += "<b>Ваше тело выворачивает наизнанку, волна агонизирующей боли заливает ваше сознание.</b><br>"
			message += "<i>Это и есть [pluralize_ru(occupant.gender, "моя", "наша")] смерть? Да, это она.</i>"
			to_chat(occupant, span_warning("[message]"))
			SEND_SOUND(occupant, sound('sound/hallucinations/veryfar_noise.ogg', 0, 1, 50))
		for(var/i in missing_organs)
			qdel(i)
		missing_organs.Cut()
		clonemind = null
		spawn(40)
			qdel(occupant)


	playsound(loc, 'sound/machines/warning-buzzer.ogg', 50, 0)
	mess = TRUE
	update_icon()


/obj/machinery/clonepod/update_icon_state()
	if(occupant && !(stat & NOPOWER))
		icon_state = "pod_cloning"
	else if(mess)
		icon_state = "pod_mess"
	else
		icon_state = "pod_idle"


/obj/machinery/clonepod/update_overlays()
	. = ..()
	if(panel_open)
		. += "panel_open"


/obj/machinery/clonepod/relaymove(mob/user)
	if(user.stat == CONSCIOUS)
		go_out()

/obj/machinery/clonepod/emp_act(severity)
	if(prob(100/(severity*efficiency))) malfunction()
	..()

/obj/machinery/clonepod/ex_act(severity)
	..()
	if(!QDELETED(src) && occupant)
		go_out()

/obj/machinery/clonepod/handle_atom_del(atom/A)
	if(A == occupant)
		occupant = null
		countdown.stop()

/obj/machinery/clonepod/deconstruct(disassembled = TRUE)
	if(occupant)
		go_out()
	..()

/obj/machinery/clonepod/proc/occupant_got_revived()
	// The old body's back in shape, time to ditch the cloning one
	malfunction(go_easy = TRUE)

/obj/machinery/clonepod/proc/maim_clone(mob/living/carbon/human/H)
	LAZYINITLIST(missing_organs)
	for(var/i in missing_organs)
		qdel(i)
	missing_organs.Cut()

	H.setCloneLoss(CLONE_INITIAL_DAMAGE, FALSE)
	H.setBrainLoss(BRAIN_INITIAL_DAMAGE)

	for(var/obj/item/organ/internal/organ as anything in H.internal_organs)
		if(organ.vital)
			continue

		// Let's non-specially remove all non-vital organs
		// What could possibly go wrong
		var/atom/movable/thing = organ.remove(H, ORGAN_MANIPULATION_NOEFFECT)
		// Make this support stuff that turns into items when removed
		if(!QDELETED(thing))
			thing.forceMove(src)
			missing_organs += thing

	var/static/list/zones = list(BODY_ZONE_L_ARM, BODY_ZONE_R_ARM, BODY_ZONE_L_LEG, BODY_ZONE_R_LEG)
	for(var/zone in zones)
		var/obj/item/organ/external/bodypart = H.get_organ(zone)
		var/atom/movable/thing = bodypart.remove(H)
		if(!QDELETED(thing))
			thing.forceMove(src)
			missing_organs += thing

	organs_number = LAZYLEN(missing_organs)
	H.updatehealth()

/obj/machinery/clonepod/proc/check_brine()
	// Clones are in a pickled bath of mild chemicals, keeping
	// them alive, despite their lack of internal organs
	for(var/bt in brine_types)
		if(occupant.reagents.get_reagent_amount(bt) < 1)
			occupant.reagents.add_reagent(bt, 1)

/*
 *	Diskette Box
 */

/obj/item/storage/box/disks
	name = "Diskette Box"
	desc = "Коробка для хранения дискет."
	ru_names = list(
		NOMINATIVE = "коробка с дискетами",
		GENITIVE = "коробки с дискетами",
		DATIVE = "коробке с дискетами",
		ACCUSATIVE = "коробку с дискетами",
		INSTRUMENTAL = "коробкой с дискетами",
		PREPOSITIONAL = "коробке с дискетами"
	)
	icon_state = "disk_kit"

/obj/item/storage/box/disks/populate_contents()
	for(var/I in 1 to 7)
		new /obj/item/disk/data(src)

/*
 *	Manual -- A big ol' manual.
 */

/obj/item/paper/Cloning
	name = "paper - 'H-87 Cloning Apparatus Manual"
	info = {"<h4>Getting Started</h4>
	Congratulations, your station has purchased the H-87 industrial cloning device!<br>
	Using the H-87 is almost as simple as brain surgery! Simply insert the target humanoid into the scanning chamber and select the scan option to create a new profile!<br>
	<b>That's all there is to it!</b><br>
	<i>Notice, cloning system cannot scan inorganic life or small primates.  Scan may fail if subject has suffered extreme brain damage.</i><br>
	<p>Clone profiles may be viewed through the profiles menu. Scanning implants a complementary HEALTH MONITOR IMPLANT into the subject, which may be viewed from each profile.
	Profile Deletion has been restricted to \[Station Head\] level access.</p>
	<h4>Cloning from a profile</h4>
	Cloning is as simple as pressing the CLONE option at the bottom of the desired profile.<br>
	Per your company's EMPLOYEE PRIVACY RIGHTS agreement, the H-87 has been blocked from cloning crewmembers while they are still alive.<br>
	<br>
	<p>The provided CLONEPOD SYSTEM will produce the desired clone.  Standard clone maturation times (With SPEEDCLONE technology) are roughly 90 seconds.
	The cloning pod may be unlocked early with any \[Medical Researcher\] ID after initial maturation is complete.</p><br>
	<i>Please note that resulting clones may have a small DEVELOPMENTAL DEFECT as a result of genetic drift.</i><br>
	<h4>Profile Management</h4>
	<p>The H-87 (as well as your station's standard genetics machine) can accept STANDARD DATA DISKETTES.
	These diskettes are used to transfer genetic information between machines and profiles.
	A load/save dialog will become available in each profile if a disk is inserted.</p><br>
	<i>A good diskette is a great way to counter aforementioned genetic drift!</i><br>
	<br>
	<font size=1>This technology produced under license from Thinktronic Systems, LTD.</font>"}

//SOME SCRAPS I GUESS
/* EMP grenade/spell effect
		if(istype(A, /obj/machinery/clonepod))
			A:malfunction()
*/

#undef MINIMUM_HEAL_LEVEL
