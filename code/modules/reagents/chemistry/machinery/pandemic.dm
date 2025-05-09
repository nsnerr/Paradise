/obj/machinery/computer/pandemic
	name = "PanD.E.M.I.C 220"
	desc = "Высокотехнологичная машина, предназначенная для исследования и работы с вирусными культурами. Лучший друг вирусолога!"
	ru_names = list(
		NOMINATIVE = "Панд.Е.М.И.К 220",
		GENITIVE = "Панд.Е.М.И.К 220",
		DATIVE = "Панд.Е.М.И.К 220",
		ACCUSATIVE = "Панд.Е.М.И.К 220",
		INSTRUMENTAL = "Панд.Е.М.И.К 220",
		PREPOSITIONAL = "Панд.Е.М.И.К 220"
	)
	density = TRUE
	anchored = TRUE
	icon = 'icons/obj/chemical.dmi'
	icon_state = "mixer0"
	circuit = /obj/item/circuitboard/pandemic
	use_power = IDLE_POWER_USE
	idle_power_usage = 20
	resistance_flags = ACID_PROOF
	var/temp_html = ""
	var/printing = null
	var/wait = null
	var/obj/item/reagent_containers/beaker = null

/obj/machinery/computer/pandemic/examine(mob/user)
	. = ..()
	if(panel_open)
		. += span_notice("Панель техобслуживания открыта.")

/obj/machinery/computer/pandemic/New()
	..()
	update_icon()

/obj/machinery/computer/pandemic/set_broken()
	stat |= BROKEN
	update_icon()

/obj/machinery/computer/pandemic/proc/GetDiseaseByIndex(index)
	if(beaker?.reagents?.reagent_list.len)
		for(var/datum/reagent/BL in beaker.reagents.reagent_list)
			if(BL?.data && BL.data["diseases"])
				var/list/diseases = BL.data["diseases"]
				return diseases[index]

/obj/machinery/computer/pandemic/proc/GetResistancesByIndex(index)
	if(beaker?.reagents?.reagent_list.len)
		for(var/datum/reagent/BL in beaker.reagents.reagent_list)
			if(BL?.data && BL.data["resistances"])
				var/list/resistances = BL.data["resistances"]
				return resistances[index]

/obj/machinery/computer/pandemic/proc/GetDiseaseTypeByIndex(index)
	var/datum/disease/D = GetDiseaseByIndex(index)
	if(D)
		return D.GetDiseaseID()

/obj/machinery/computer/pandemic/proc/replicator_cooldown(waittime)
	wait = 1
	update_icon()
	spawn(waittime)
		wait = null
		update_icon()
		playsound(loc, 'sound/machines/ping.ogg', 30, 1)


/obj/machinery/computer/pandemic/update_icon_state()
	if(stat & BROKEN)
		icon_state = "mixer[beaker ? "1" : "0"]_b"
		return
	icon_state = "mixer[beaker ? "1" : "0"][(powered()) ? "" : "_nopower"]"


/obj/machinery/computer/pandemic/update_overlays()
	. = ..()
	if(!(stat & BROKEN) && !wait)
		. += "waitlight"


/obj/machinery/computer/pandemic/Topic(href, href_list)
	if(..())
		return

	usr.set_machine(src)
	if(!beaker) return

	if(href_list["create_vaccine"])
		if(!wait)
			var/obj/item/reagent_containers/glass/bottle/B = new/obj/item/reagent_containers/glass/bottle(loc)
			if(B)
				B.pixel_x = rand(-3, 3)
				B.pixel_y = rand(-3, 3)
				var/path = GetResistancesByIndex(text2num(href_list["create_vaccine"]))
				var/vaccine_type = path
				var/vaccine_name = "Неизвестно"

				if(!ispath(vaccine_type))
					if(GLOB.archive_diseases[path])
						var/datum/disease/D = GLOB.archive_diseases[path]
						if(D)
							vaccine_name = D.name
							vaccine_type = path
				else if(vaccine_type)
					var/datum/disease/D = new vaccine_type
					if(D)
						vaccine_name = D.name

				if(vaccine_type)

					B.name = "бутылка вакцины \"[vaccine_name]\""
					B.ru_names = list(
						NOMINATIVE = "бутылка вакцины \"[vaccine_name]\"",
						GENITIVE = "бутылки вакцины \"[vaccine_name]\"",
						DATIVE = "бутылке вакцины \"[vaccine_name]\"",
						ACCUSATIVE = "бутылку вакцины \"[vaccine_name]\"",
						INSTRUMENTAL = "бутылкой вакцины \"[vaccine_name]\"",
						PREPOSITIONAL = "бутылке вакцины \"[vaccine_name]\""
					)
					B.reagents.add_reagent("vaccine", 15, list(vaccine_type))
					replicator_cooldown(200)
		else
			temp_html = "Репликатор ещё не готов."
		updateUsrDialog()
		return
	else if(href_list["create_disease_culture"])
		if(!wait)
			var/datum/disease/D = GetDiseaseByIndex(text2num(href_list["create_disease_culture"]))
			var/datum/disease/copy
			if(istype(D, /datum/disease/virus/advance))
				var/datum/disease/virus/advance/A = GLOB.archive_diseases[D.GetDiseaseID()]
				if(A)
					copy = A.Copy()
			if(!copy)
				copy = D.Copy()
			if(!copy)
				return
			var/name = tgui_input_text(usr, "Название:", "Введите название культуры", D.name, MAX_NAME_LEN)
			if(name == null || wait)
				return
			var/obj/item/reagent_containers/glass/bottle/B = new(loc)
			B.icon_state = "round_bottle"
			B.pixel_x = rand(-3, 3)
			B.pixel_y = rand(-3, 3)
			replicator_cooldown(50)
			var/list/data = list("diseases"=list(copy))
			B.name = "бутылка культуры \"[name]\""
			B.ru_names = list(
				NOMINATIVE = "бутылка культуры \"[name]\"",
				GENITIVE = "бутылки культуры \"[name]\"",
				DATIVE = "бутылке культуры \"[name]\"",
				ACCUSATIVE = "бутылку культуры \"[name]\"",
				INSTRUMENTAL = "бутылкой культуры \"[name]\"",
				PREPOSITIONAL = "бутылке культуры \"[name]\""
			)
			B.desc = "Небольшая бутылка. Содержит синтетическую кровь, заражённую культурой \"[copy.agent]\"."
			B.reagents.add_reagent("blood",20,data)
			updateUsrDialog()
		else
			temp_html = "Репликатор ещё не готов."
		updateUsrDialog()
		return
	else if(href_list["empty_beaker"])
		beaker.reagents.clear_reagents()
		eject_beaker()
		updateUsrDialog()
		return
	else if(href_list["eject"])
		eject_beaker()
		updateUsrDialog()
		return
	else if(href_list["clear"])
		temp_html = ""
		updateUsrDialog()
		return
	else if(href_list["name_disease"])
		var/new_name = tgui_input_text(usr, "Назовите вирус:", "Введите название вируса", max_length = MAX_NAME_LEN)
		if(!new_name)
			return
		if(..())
			return
		var/id = GetDiseaseTypeByIndex(text2num(href_list["name_disease"]))
		if(GLOB.archive_diseases[id])
			var/datum/disease/virus/advance/A = GLOB.archive_diseases[id]
			A.AssignName(new_name)
			for(var/datum/disease/virus/advance/AD in GLOB.active_diseases)
				AD.Refresh(update_properties = FALSE)
		updateUsrDialog()
	else if(href_list["print_form"])
		var/datum/disease/D = GetDiseaseByIndex(text2num(href_list["print_form"]))
		D = GLOB.archive_diseases[D.GetDiseaseID()]//We know it's advanced no need to check
		print_form(D, usr)


	else
		close_window(usr, "pandemic")
		updateUsrDialog()
		return

	add_fingerprint(usr)

/obj/machinery/computer/pandemic/proc/eject_beaker()
	beaker.forceMove(loc)
	beaker = null
	icon_state = "mixer0"

//Prints a nice virus release form. Props to Urbanliner for the layout
/obj/machinery/computer/pandemic/proc/print_form(var/datum/disease/virus/advance/D, mob/living/user)
	D = GLOB.archive_diseases[D.GetDiseaseID()]
	if(!(printing) && D)
		var/reason = tgui_input_text(user,"Укажите причину выпуска", "Указать", multiline = TRUE)
		reason += "<span class=\"paper_field\"></span>"
		var/symptoms_list = list()
		for(var/I in D.symptoms)
			var/datum/symptom/S = I
			symptoms_list += S.name
		var/symtoms = russian_list(symptoms_list)


		var/signature
		if(tgui_alert(user, "Вы хотите подписать этот документ?", "Подпись", list("Да","Нет")) == "Да")
			signature = "<span style='font-face: \"[SIGNFONT]\";'><i>[user ? user.real_name : "Неизвестный"]</i></span>"
		else
			signature = "<span class=\"paper_field\"></span>"

		printing = 1
		var/obj/item/paper/P = new /obj/item/paper(loc)
		visible_message(span_notice("[capitalize(declent_ru(NOMINATIVE))] дребезжит, после чего из окна печати выпадает лист бумаги."))
		playsound(loc, 'sound/goonstation/machines/printer_dotmatrix.ogg', 50, 1)

		P.info = "<u><span style='font-size: 4;'><b><center> Выпуск вируса </b></center></span></u>"
		P.info += "<hr>"
		P.info += "<u>Название вируса:</u> [D.name] <br>"
		P.info += "<u>Симптомы:</u> [symtoms]<br>"
		P.info += "<u>Путь передачи:</u> [D.additional_info]<br>"
		P.info += "<u>Лекарство от вируса:</u> [D.cure_text]<br>"
		P.info += "<br>"
		P.info += "<u>Причина выпуска:</u> [reason]"
		P.info += "<hr>"
		P.info += "Вирусолог, ответственный за любые биологические угрозы, возникшие вследствие выпуска вируса.<br>"
		P.info += "<u>Подпись вирусолога:</u> [signature]<br>"
		P.info += "Печать ответственного лица, разрешившего выпуск вируса:"
		P.populatefields()
		P.updateinfolinks()
		P.name = "Выпуск вируса «[D.name]»"
		P.update_icon()
		printing = null

/obj/machinery/computer/pandemic/attack_hand(mob/user)
	if(..())
		return
	user.set_machine(src)
	var/dat = ""
	if(temp_html)
		dat += "[temp_html]<br><br><a href='byond://?src=[UID()];clear=1'>Главное меню</a>"
	else if(!beaker)
		dat += "Пожалуйста, вставьте ёмкость.<br>"
		dat += "<a href='byond://?src=[user.UID()];mach_close=pandemic'>Закрыть</a>"
	else
		var/datum/reagents/R = beaker.reagents
		var/datum/reagent/Blood = null

		for(var/datum/reagent/B in R.reagent_list)
			if(B.id in GLOB.diseases_carrier_reagents)
				Blood = B
				if(!Blood.data)
					continue
				break
		if(!R.total_volume||!R.reagent_list.len)
			dat += "Ёмкость пуста<br>"
		else if(!Blood)
			dat += "В ёмкости отсутствует образец крови."
		else if(!Blood.data)
			dat += "В ёмкости отсутствует данные крови."
		else
			dat += "<h3>Данные образца крови:</h3>"
			dat += "<b>ДНК крови:</b> [(Blood.data["blood_DNA"]||"нет")]<br>"
			dat += "<b>Группа крови:</b> [(Blood.data["blood_type"]||"нет")]<br>"
			dat += "<b>Тип расовой крови:</b> [(Blood.data["blood_species"]||"нет")]<br>"

			dat += "<h3>Данные о заболеваниях:</h3>"
			if(Blood.data["diseases"])
				var/i = 0
				for(var/datum/disease/D in Blood.data["diseases"])
					i++
					if(!(D.visibility_flags & HIDDEN_PANDEMIC))

						dat += "<b>Общепринятое название: </b>"

						if(istype(D, /datum/disease/virus/advance))
							var/datum/disease/virus/advance/A = D
							D = GLOB.archive_diseases[A.GetDiseaseID()]
							if(D)
								if(D.name == "Unknown")
									dat += "<b><a href='byond://?src=[UID()];name_disease=[i]'>Назвать вирус</a></b><br>"
								else
									dat += "[D.name] <b><a href='byond://?src=[UID()];print_form=[i]'>Напечатать форму выпуска</a></b><br>"
						else
							dat += "[D.name]<br>"

						if(!D)
							CRASH("We weren't able to get the advance disease from the archive.")

						dat += "<b>Болезнетворный агент:</b> [D?"[D.agent] — <a href='byond://?src=[UID()];create_disease_culture=[i]'>Создать образец</a>":"нет"]<br>"
						dat += "<b>Описание: </b> [(D.desc||"нет")]<br>"
						dat += "<b>Путь передачи:</b> [(D.additional_info||"нет")]<br>"
						dat += "<b>Возможное лекарство:</b> [(D.cure_text||"нет")]<br>"
						dat += "<b>Возможность выработки антител:</b> [(D.can_immunity ? "Присутствует" : "Отсутствует")]<br>"

						if(istype(D, /datum/disease/virus/advance))
							var/datum/disease/virus/advance/A = D
							dat += "<br><b>Симптомы:</b> "
							var/symptoms_list = list()
							for(var/datum/symptom/S in A.symptoms)
								symptoms_list += S.name
							dat += russian_list(symptoms_list)
						dat += "<br>"
				if(i == 0)
					dat += "В образце не обнаружен вирус."
			else
				dat += "В образце не обнаружен вирус."

			if(Blood.data["resistances"])
				var/list/res = Blood.data["resistances"]
				if(res.len)
					dat += "<br><b>Содержит антитела к:</b><ul>"
					var/i = 0
					for(var/type in Blood.data["resistances"])
						i++
						var/disease_name = "Неизвестно"

						if(!ispath(type))
							var/datum/disease/virus/advance/A = GLOB.archive_diseases[type]
							if(A)
								disease_name = A.name
						else
							var/datum/disease/D = new type()
							disease_name = D.name

						dat += "<li>[disease_name] - <a href='byond://?src=[UID()];create_vaccine=[i]'>Создать бутылка с вакциной</a></li>"
					dat += "</ul><br>"
				else
					dat += "<br><b>Не содержит антител</b><br>"
			else
				dat += "<br><b>Не содержит антител</b><br>"
		dat += "<br><a href='byond://?src=[UID()];eject=1'>Извлечь ёмкость</a>[((R.total_volume&&R.reagent_list.len) ? "-- <a href='byond://?src=[UID()];empty_beaker=1'>Очистить и извлечь ёмкость</a>":"")]<br>"
		dat += "<a href='byond://?src=[user.UID()];mach_close=pandemic'>Закрыть</a>"

	var/datum/browser/popup = new(user, "pandemic", name, 575, 480)
	popup.set_content(dat)
	popup.open(0)
	onclose(user, "pandemic")


/obj/machinery/computer/pandemic/attackby(obj/item/I, mob/user, params)
	if(user.a_intent == INTENT_HARM || (stat & (NOPOWER|BROKEN)))
		return ..()

	if(istype(I, /obj/item/reagent_containers))
		add_fingerprint(user)
		if(!(I.container_type & OPENCONTAINER))
			balloon_alert(user, "несовместимо!")
			return ATTACK_CHAIN_PROCEED
		if(beaker)
			balloon_alert(user, "слот для ёмкости занят!")
			return ATTACK_CHAIN_PROCEED
		if(!user.drop_transfer_item_to_loc(I, src))
			return ..()
		beaker = I
		balloon_alert(user, "ёмкость вставлена")
		updateUsrDialog()
		update_icon(UPDATE_ICON_STATE)
		return ATTACK_CHAIN_BLOCKED_ALL

	return ..()


/obj/machinery/computer/pandemic/screwdriver_act(mob/user, obj/item/I)
	. = TRUE
	if(!beaker)
		add_fingerprint(user)
		balloon_alert(user, "ёмкость отсутствует!")
		to_chat(user, span_warning("There is no beaker installed."))
		return .
	if(!I.use_tool(src, user, volume = I.tool_volume))
		return .
	beaker.forceMove(drop_location())
	beaker = null
	updateUsrDialog()
	update_icon(UPDATE_ICON_STATE)


/obj/machinery/computer/pandemic/wrench_act(mob/living/user, obj/item/I)
	return default_unfasten_wrench(user, I)

