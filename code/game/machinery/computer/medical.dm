#define MED_DATA_R_LIST	2	// Record list
#define MED_DATA_MAINT	3	// Records maintenance
#define MED_DATA_RECORD	4	// Record
#define MED_DATA_V_DATA	5	// Virus database
#define MED_DATA_MEDBOT	6	// Medbot monitor

#define FIELD(N, V, E) list(field = N, value = V, edit = E)
#define MED_FIELD(N, V, E, LB) list(field = N, value = V, edit = E, line_break = LB)

/obj/machinery/computer/med_data //TODO:SANITY
	name = "medical records console"
	desc = "Консоль, подключённая к станционной базе данных. Позволяет просматривать и редактировать медицинские записи членов экипажа."
	ru_names = list(
		NOMINATIVE = "консоль медицинских записей",
		GENITIVE = "консоли медицинских записей",
		DATIVE = "консоли медицинских записей",
		ACCUSATIVE = "консоль медицинских записей",
		INSTRUMENTAL = "консолью медицинских записей",
		PREPOSITIONAL = "консоли медицинских записей"
	)
	icon_keyboard = "med_key"
	icon_screen = "medcomp"
	req_access = list(ACCESS_MEDICAL, ACCESS_FORENSICS_LOCKERS)
	circuit = /obj/item/circuitboard/med_data
	var/screen = null
	var/datum/data/record/active1 = null
	var/datum/data/record/active2 = null
	var/list/temp = null
	var/printing = null
	// The below are used to make modal generation more convenient
	var/static/list/field_edit_questions
	var/static/list/field_edit_choices

	light_color = LIGHT_COLOR_DARKBLUE

/obj/machinery/computer/med_data/Initialize()
	. = ..()
	field_edit_questions = list(
		// General
		"sex" = "Укажите пол:",
		"age" = "Укажите возраст:",
		"fingerprint" = "Введите код отпечатков пальцев:",
		"p_stat" = "Укажите физическое состояние:",
		"m_stat" = "Укажите психологическое состояние:",
		// Medical
		"blood_type" = "Укажите группу крови:",
		"b_dna" = "Введите ДНК-код:",
		"mi_dis" = "Укажите незначительные отклонения:",
		"mi_dis_d" = "Укажите детали незначительных отклонений:",
		"ma_dis" = "Укажите инвалидности:",
		"ma_dis_d" = "Укажите детали инвалидностей:",
		"alg" = "Укажите аллергии:",
		"alg_d" = "Укажите детали аллергий:",
		"cdi" = "Укажите текущие заболевания:",
		"cdi_d" = "Укажите детали текущих заболеваний:",
		"notes" = "Укажите дополнительную информацию:",
	)
	field_edit_choices = list(
		// General
		"sex" = list("Мужской", "Женский", "Небинарный", "Множественный"),
		"p_stat" = list("Смерть", "КРС", "Стабильное", "Нетрудоспособность", "Ограниченные возможности"),
		"m_stat" = list("Невменяемость", "Нестабильное", "Рекомендуется наблюдение", "Стабильное"),
		// Medical
		"blood_type" = list("A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-"),
	)

/obj/machinery/computer/med_data/Destroy()
	active1 = null
	active2 = null
	return ..()


/obj/machinery/computer/med_data/attackby(obj/item/I, mob/user, params)
	if(user.a_intent == INTENT_HARM)
		return ..()

	if(ui_login_attackby(I, user))
		add_fingerprint(user)
		return ATTACK_CHAIN_BLOCKED_ALL

	return ..()


/obj/machinery/computer/med_data/attack_hand(mob/user)
	if(..())
		return
	if(is_away_level(z))
		to_chat(user, span_danger("Удалённый сервер не отвечает на запросы") + ": база данных вне зоны досягаемости.")
		return
	add_fingerprint(user)
	ui_interact(user)

/obj/machinery/computer/med_data/ui_interact(mob/user, datum/tgui/ui = null)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "MedicalRecords", "Медицинские записи")
		ui.open()
		ui.set_autoupdate(FALSE)

/obj/machinery/computer/med_data/ui_data(mob/user)
	var/list/data = list()
	data["temp"] = temp
	data["screen"] = screen
	data["printing"] = printing
	// This proc appends login state to data.
	ui_login_data(data, user)
	if(data["loginState"]["logged_in"])
		switch(screen)
			if(MED_DATA_R_LIST)
				if(!isnull(GLOB.data_core.general))
					var/list/records = list()
					data["records"] = records
					for(var/datum/data/record/R in sortRecord(GLOB.data_core.general))
						records[++records.len] = list(
							"ref" = "\ref[R]",
							"name" = R.fields["name"],
							"id" = R.fields["id"],
							"rank" = R.fields["rank"],
							"p_stat" = R.fields["p_stat"],
							"m_stat" = R.fields["m_stat"])
			if(MED_DATA_RECORD)
				var/list/general = list()
				data["general"] = general
				if(istype(active1, /datum/data/record) && GLOB.data_core.general.Find(active1))
					var/list/fields = list()
					general["fields"] = fields
					fields[++fields.len] = FIELD("Имя", active1.fields["name"], null)
					fields[++fields.len] = FIELD("ID", active1.fields["id"], null)
					fields[++fields.len] = FIELD("Пол", active1.fields["sex"], "sex")
					fields[++fields.len] = FIELD("Возраст", active1.fields["age"], "age")
					fields[++fields.len] = FIELD("Отпечатки пальцев", active1.fields["fingerprint"], "fingerprint")
					fields[++fields.len] = FIELD("Физическое состояние", active1.fields["p_stat"], "p_stat")
					fields[++fields.len] = FIELD("Психологическое состояние", active1.fields["m_stat"], "m_stat")
					var/list/photos = list()
					general["photos"] = photos
					photos[++photos.len] = active1.fields["photo-south"]
					photos[++photos.len] = active1.fields["photo-west"]
					general["has_photos"] = (active1.fields["photo-south"] || active1.fields["photo-west"] ? 1 : 0)
					general["empty"] = 0
				else
					general["empty"] = 1

				var/list/medical = list()
				data["medical"] = medical
				if(istype(active2, /datum/data/record) && GLOB.data_core.medical.Find(active2))
					var/list/fields = list()
					medical["fields"] = fields
					fields[++fields.len] = MED_FIELD("Группа крови", active2.fields["blood_type"], "blood_type", FALSE)
					fields[++fields.len] = MED_FIELD("ДНК", active2.fields["b_dna"], "b_dna", TRUE)
					fields[++fields.len] = MED_FIELD("Незначительные отклонения", active2.fields["mi_dis"], "mi_dis", FALSE)
					fields[++fields.len] = MED_FIELD("Детали", active2.fields["mi_dis_d"], "mi_dis_d", FALSE)
					fields[++fields.len] = MED_FIELD("Инвалидности", active2.fields["ma_dis"], "ma_dis", FALSE)
					fields[++fields.len] = MED_FIELD("Детали", active2.fields["ma_dis_d"], "ma_dis_d", TRUE)
					fields[++fields.len] = MED_FIELD("Аллергии", active2.fields["alg"], "alg", FALSE)
					fields[++fields.len] = MED_FIELD("Детали", active2.fields["alg_d"], "alg_d", FALSE)
					fields[++fields.len] = MED_FIELD("Текущие заболевания", active2.fields["cdi"], "cdi", FALSE)
					fields[++fields.len] = MED_FIELD("Детали", active2.fields["cdi_d"], "cdi_d", TRUE)
					fields[++fields.len] = MED_FIELD("Дополнительная информация", active2.fields["notes"], "notes", FALSE)
					if(!active2.fields["comments"] || !islist(active2.fields["comments"]))
						active2.fields["comments"] = list()
					medical["comments"] = active2.fields["comments"]
					medical["empty"] = 0
				else
					medical["empty"] = 1
			if(MED_DATA_V_DATA)
				data["virus"] = list()
				for(var/D in typesof(/datum/disease))
					var/datum/disease/DS = new D(0)
					if(istype(DS, /datum/disease/virus/advance))
						continue
					if(!DS.desc)
						continue
					var/list/payload = list(
						"name" = DS.name,
						"max_stages" = "[DS.max_stages]", // This needs to be a string for sorting
						"severity" = DS.severity,
						"D" = D)
					data["virus"] += list(payload)
					qdel(DS)
			if(MED_DATA_MEDBOT)
				data["medbots"] = list()
				for(var/mob/living/simple_animal/bot/medbot/M in GLOB.bots_list)
					if(M.z != z)
						continue
					var/turf/T = get_turf(M)
					if(T)
						var/medbot = list()
						var/area/A = get_area(T)
						medbot["name"] = M.name
						medbot["area"] = A.name
						medbot["x"] = T.x
						medbot["y"] = T.y
						medbot["on"] = M.on
						if(!isnull(M.reagent_glass) && M.use_beaker)
							medbot["use_beaker"] = 1
							medbot["total_volume"] = M.reagent_glass.reagents.total_volume
							medbot["maximum_volume"] = M.reagent_glass.reagents.maximum_volume
						else
							medbot["use_beaker"] = 0
						data["medbots"] += list(medbot)

	data["modal"] = ui_modal_data(src)
	return data

/obj/machinery/computer/med_data/ui_act(action, params)
	if(..())
		return
	if(stat & (NOPOWER|BROKEN))
		return

	if(!GLOB.data_core.general.Find(active1))
		active1 = null
	if(!GLOB.data_core.medical.Find(active2))
		active2 = null

	. = TRUE
	if(ui_act_modal(action, params))
		return
	if(ui_login_act(action, params))
		return

	switch(action)
		if("cleartemp")
			temp = null
		else
			. = FALSE

	if(.)
		return

	if(ui_login_get().logged_in)
		. = TRUE
		switch(action)
			if("screen")
				screen = clamp(text2num(params["screen"]) || 0, MED_DATA_R_LIST, MED_DATA_MEDBOT)
				active1 = null
				active2 = null
			if("vir")
				var/type = text2path(params["vir"] || "")
				if(!ispath(type, /datum/disease))
					return

				var/datum/disease/D = new type(0)
				var/datum/disease/virus/V = D
				var/list/payload = list(
					name = D.name,
					max_stages = D.max_stages,
					spread_text = istype(V) ? V.spread_text() : "",
					cure = D.cure_text || "Н/Д",
					desc = D.desc,
					severity = D.severity
				)
				ui_modal_message(src, "virus", "", null, payload)
				qdel(D)
			if("del_all_med_records")
				for(var/datum/data/record/R in GLOB.data_core.medical)
					qdel(R)
				set_temp("База данных очищена.")
			if("del_med_record")
				if(active2)
					set_temp("Запись удалена.")
					qdel(active2)
			if("view_record")
				var/datum/data/record/general_record = locate(params["view_record"] || "")
				if(!GLOB.data_core.general.Find(general_record))
					set_temp("Запись не найдена.", "danger")
					return

				var/datum/data/record/medical_record
				for(var/datum/data/record/M in GLOB.data_core.medical)
					if(M.fields["name"] == general_record.fields["name"] && M.fields["id"] == general_record.fields["id"])
						medical_record = M
						break

				active1 = general_record
				active2 = medical_record
				screen = MED_DATA_RECORD
			if("new_med_record")
				if(istype(active1, /datum/data/record) && !istype(active2, /datum/data/record))
					var/datum/data/record/R = new /datum/data/record()
					R.fields["name"] = active1.fields["name"]
					R.fields["id"] = active1.fields["id"]
					R.name = "Медицинская запись №[R.fields["id"]]"
					R.fields["blood_type"] = "Неизвестно"
					R.fields["b_dna"] = "Неизвестно"
					R.fields["mi_dis"] = "Отсутствуют"
					R.fields["mi_dis_d"] = "Незначительные отклонения не указаны."
					R.fields["ma_dis"] = "Отсутствуют"
					R.fields["ma_dis_d"] = "Инвалидности не указаны."
					R.fields["alg"] = "Отсутствуют"
					R.fields["alg_d"] = "Аллергии не указаны."
					R.fields["cdi"] = "Отсутствуют"
					R.fields["cdi_d"] = "Текущие заболевания не указаны."
					R.fields["notes"] = "Дополнительная информация не указана."
					GLOB.data_core.medical += R
					active2 = R
					screen = MED_DATA_RECORD
					set_temp("Медицинская запись создана.", "success")
			if("del_comment")
				var/index = text2num(params["del_comment"] || "")
				if(!index || !istype(active2, /datum/data/record))
					return

				var/list/comments = active2.fields["comments"]
				index = clamp(index, 1, length(comments))
				if(comments[index])
					comments.Cut(index, index + 1)
			if("print_record")
				if(!printing)
					printing = TRUE
					playsound(loc, 'sound/goonstation/machines/printer_dotmatrix.ogg', 50, TRUE)
					SStgui.update_uis(src)
					addtimer(CALLBACK(src, PROC_REF(print_finish)), 5 SECONDS)
			else
				return FALSE

/**
  * Called in ui_act() to process modal actions
  *
  * Arguments:
  * * action - The action passed by tgui
  * * params - The params passed by tgui
  */
/obj/machinery/computer/med_data/proc/ui_act_modal(action, params)
	. = TRUE
	var/id = params["id"] // The modal's ID
	var/list/arguments = istext(params["arguments"]) ? json_decode(params["arguments"]) : params["arguments"]
	switch(ui_modal_act(src, action, params))
		if(UI_MODAL_OPEN)
			switch(id)
				if("edit")
					var/field = arguments["field"]
					if(!length(field) || !field_edit_questions[field])
						return
					var/question = field_edit_questions[field]
					var/choices = field_edit_choices[field]
					if(length(choices))
						ui_modal_choice(src, id, question, arguments = arguments, value = arguments["value"], choices = choices)
					else
						ui_modal_input(src, id, question, arguments = arguments, value = arguments["value"])
				if("add_comment")
					ui_modal_input(src, id, "Введите комментарий.")
				else
					return FALSE
		if(UI_MODAL_ANSWER)
			var/answer = params["answer"]
			switch(id)
				if("edit")
					var/field = arguments["field"]
					if(!length(field) || !field_edit_questions[field])
						return
					var/list/choices = field_edit_choices[field]
					if(length(choices) && !(answer in choices))
						return

					if(field == "age")
						if(!active1)
							return

						var/datum/species/species = active1.fields["species"]
						var/new_age = text2num(answer)
						var/age_limits = get_age_limits(species, list(SPECIES_AGE_MIN, SPECIES_AGE_MAX))
						if(new_age < age_limits[SPECIES_AGE_MIN] || new_age > age_limits[SPECIES_AGE_MAX])
							set_temp("Недопустимый возраст. Принимаются значения от [age_limits[SPECIES_AGE_MIN]] до [age_limits[SPECIES_AGE_MAX]] лет.", "danger")
							return

						answer = new_age

					if(istype(active2) && (field in active2.fields))
						active2.fields[field] = answer
					else if(istype(active1) && (field in active1.fields))
						active1.fields[field] = answer
				if("add_comment")
					var/datum/ui_login/state = ui_login_get()
					if(!length(answer) || !istype(active2) || !length(state.name))
						return
					active2.fields["comments"] += list(list(
						header = "Создатель записи - [state.name] ([state.rank]). Запись создана [GLOB.current_date_string] [station_time_timestamp()].",
						text = answer
					))
				else
					return FALSE
		else
			return FALSE

/**
  * Called when the print timer finishes
  */
/obj/machinery/computer/med_data/proc/print_finish()
	var/obj/item/paper/P = new /obj/item/paper(loc)
	P.info = "<center></b>Медицинская запись</b></center><br>"
	if(istype(active1, /datum/data/record) && GLOB.data_core.general.Find(active1))
		P.info += {"Имя: [active1.fields["name"]] ID: [active1.fields["id"]]
		<br>\nПол: [active1.fields["sex"]]
		<br>\nВозраст: [active1.fields["age"]]
		<br>\nОтпечатки пальцев: [active1.fields["fingerprint"]]
		<br>\nФизическое состояние: [active1.fields["p_stat"]]
		<br>\nПсихологическое состояние: [active1.fields["m_stat"]]<br>"}
	else
		P.info += "</b>Основная информация утрачена!</b><br>"
	if(istype(active2, /datum/data/record) && GLOB.data_core.medical.Find(active2))
		P.info += {"<br>\n<center></b>Медицинские данные</b></center>
		<br>\nГруппа крови: [active2.fields["blood_type"]]
		<br>\nДНК: [active2.fields["b_dna"]]<br>\n
		<br>\nНезначительные отклонения: [active2.fields["mi_dis"]]
		<br>\nДетали: [active2.fields["mi_dis_d"]]<br>\n
		<br>\nИнвалидности: [active2.fields["ma_dis"]]
		<br>\nДетали: [active2.fields["ma_dis_d"]]<br>\n
		<br>\nАллергии: [active2.fields["alg"]]
		<br>\nДетали: [active2.fields["alg_d"]]<br>\n
		<br>\nТекущие заболевания: [active2.fields["cdi"]]
		<br>\nДетали: [active2.fields["cdi_d"]]<br>\n
		<br>\nДополнительная информация:
		<br>\n\t[active2.fields["notes"]]<br>\n
		<br>\n
		<center></b>Комментарии</b></center>"}
		for(var/c in active2.fields["comments"])
			P.info += "<br>[c["header"]]<br>Комментарий: [c["text"]]<br>"
	else
		P.info += "</b>Медицинская информация утрачена!</b><br>"
	P.info += "</tt>"
	P.name = "Медицинская запись: [active1.fields["name"]]"
	printing = FALSE
	SStgui.update_uis(src)

/**
  * Sets a temporary message to display to the user
  *
  * Arguments:
  * * text - Text to display, null/empty to clear the message from the UI
  * * style - The style of the message: (color name), info, success, warning, danger, virus
  */
/obj/machinery/computer/med_data/proc/set_temp(text = "", style = "info", update_now = FALSE)
	temp = list(text = text, style = style)
	if(update_now)
		SStgui.update_uis(src)

/obj/machinery/computer/med_data/emp_act(severity)
	if(stat & (BROKEN|NOPOWER))
		return ..(severity)

	for(var/datum/data/record/R in GLOB.data_core.medical)
		if(prob(10/severity))
			switch(rand(1,6))
				if(1)
					R.fields["name"] = pick("[pick(GLOB.first_names_male)] [pick(GLOB.last_names)]", "[pick(GLOB.first_names_female)] [pick(GLOB.last_names_female)]")
				if(2)
					R.fields["sex"] = pick("Мужской", "Женский", "Небинарный", "Множественный")
				if(3)
					R.fields["age"] = rand(1, 999)
				if(4)
					R.fields["blood_type"] = pick("A-", "B-", "AB-", "O-", "A+", "B+", "AB+", "O+")
				if(5)
					R.fields["p_stat"] = pick("Смерть", "КРС", "Стабильное", "Нетрудоспособность", "Ограниченные возможности")
				if(6)
					R.fields["m_stat"] = pick("Невменяемость", "Нестабильное", "Рекомендуется наблюдение", "Стабильное")
			continue

		else if(prob(1))
			qdel(R)
			continue

	..(severity)

/obj/machinery/computer/med_data/ui_login_on_login(datum/ui_login/state)
	active1 = null
	active2 = null
	screen = MED_DATA_R_LIST

/obj/machinery/computer/med_data/laptop
	name = "medical laptop"
	desc = "Дешёвый ноутбук, произведённый Nanotrasen."
	ru_names = list(
		NOMINATIVE = "медицинский ноутбук",
		GENITIVE = "медицинского ноутбука",
		DATIVE = "медицинскому ноутбуку",
		ACCUSATIVE = "медицинский ноутбук",
		INSTRUMENTAL = "медицинским ноутбуком",
		PREPOSITIONAL = "медицинском ноутбуке"
	)
	icon_state = "laptop"
	icon_keyboard = "laptop_key"
	icon_screen = "medlaptop"
	density = FALSE

#undef MED_DATA_R_LIST
#undef MED_DATA_MAINT
#undef MED_DATA_RECORD
#undef MED_DATA_V_DATA
#undef MED_DATA_MEDBOT
#undef FIELD
#undef MED_FIELD
