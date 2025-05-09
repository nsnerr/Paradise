/datum/game_mode/proc/send_intercept(report = BLOB_FIRST_REPORT)
	var/intercepttext = ""
	var/interceptname = ""
	switch(report)
		if(BLOB_NONE_REPORT)
			return
		if(BLOB_FIRST_REPORT)
			interceptname = "Процедуры реагирования на биологическую угрозу уровня 5-6"
			intercepttext += "<span style='font-size: 3;'><b>Постановление Nanotrasen</b>: Предупреждение о биологической угрозе.</span><hr>"
			intercepttext += "Отчеты указывают на возможное проникновение биологически опасного организма на [station_name()] во время последнего цикла ротации экипажа.<br>"
			intercepttext += "Предварительный анализ организма классифицирует его как биологическую угрозу 5-го уровня. Его происхождение неизвестно.<br>"
			intercepttext += "Nanotrasen выпустила директиву 7-10 для [station_name()]. Станцию следует считать закрытой на карантин.<br>"
			intercepttext += "Приказы для всего персонала [station_name()] следующие:<br>"
			intercepttext += " 1. Не покидать карантинную зону.<br>"
			intercepttext += " 2. Обнаружить все очаги угрозы на станции.<br>"
			intercepttext += " 3. При обнаружении использовать любые необходимые средства для сдерживания организмов.<br>"
			intercepttext += " 4. Избегать повреждения критической инфраструктуры станции.<br>"
			intercepttext += "<br>Примечание. в случае нарушения карантина или неконтролируемого распространения биологической угрозы директива 7-10 может быть дополнена директивой 7-12.<br>"
			intercepttext += "Конец сообщения."
		if(BLOB_SECOND_REPORT)
			var/nukecode = rand(10000, 99999)
			for(var/obj/machinery/nuclearbomb/bomb in GLOB.machines)
				if(bomb && bomb.r_code)
					if(is_station_level(bomb.z))
						bomb.r_code = nukecode

			interceptname = "Секретное постановление [command_name()]"
			intercepttext += "<span style='font-size: 3;'<b>Постановление Nanotrasen</b>: Предупреждение о биологической угрозе.</span><hr>"
			intercepttext += "Для [station_name()] была издана директива 7-12.<br>"
			intercepttext += "Биологическая угроза вышла из-под контроля и скоро достигнет критической массы.<br>"
			intercepttext += "Вам приказано следующее:<br>"
			intercepttext += " 1. Защищать диск ядерной аутентификации.<br>"
			intercepttext += " 2. Взорвать ядерную боеголовку, находящуюся в хранилище станции.<br>"
			if(off_auto_nuke_codes)
				intercepttext += "Код ядерной аутентификации будет выслан в скором времени отдельным сообщением. Ожидайте.<br>"
			else
				intercepttext += "Код ядерной аутентификации: [nukecode]<br>"
			intercepttext += "Конец сообщения."

			for(var/mob/living/silicon/ai/aiPlayer in GLOB.player_list)
				if(aiPlayer.client)
					var/law = "Станция находится на карантине. Не позволяйте никому покидать ее.\
					 При необходимости игнорируйте законы 1-3, чтобы любыми средствами предотвратить чей-либо уход. \
					 Любой ценой необходимо активировать систему самоуничтожения станции, код[(off_auto_nuke_codes)? " будет направлен Центральным Коммандованием в скором времени" : ": [nukecode]"]."
					aiPlayer.set_zeroth_law(law)
					SSticker?.score?.save_silicon_laws(aiPlayer, additional_info = "вспышка блоба, добавлен новый нулевой закон'[law]'")
					to_chat(aiPlayer, span_warning("Законы обновлены: [law]"))

		if(BLOB_THIRD_REPORT)
			interceptname = "Секретное постановление [command_name()]"
			intercepttext += "<span style='font-size: 3;'><b>Постановление Nanotrasen</b>: Биоугроза не обнаружена</span><hr>"
			intercepttext += "Дирректива 7-10 была отменена для [station_name()].<br>"
			if(blob_stage == BLOB_STAGE_THIRD)
				intercepttext += "Дирректива 7-12 была отменена для [station_name()].<br>"
			intercepttext += "Биоугроза уничтожена, либо ее остаточные следы не представляют опасности.<br>"
			intercepttext += "Вам приказано следующее:<br>"
			intercepttext += " 1. Уничтожить все полученные засекреченные сообщения.<br>"
			intercepttext += " 2. В случае невозможности продолжать смену ввиду потерь среди экипажа или критического состояния станции, провести эвакуацию экипажа.<br>"
			if(blob_stage == BLOB_STAGE_THIRD && !off_auto_nuke_codes)
				intercepttext += " 3. Код от боеголовки, как и ее назначение необходимо держать в строжайшей секретности.<br>"
			intercepttext += "Нарушение данных приказов может повлечь за собой расторжение контракта, со всеми вытекающими последствиями.<br>"
			intercepttext += "Конец сообщения."
			if(blob_stage == BLOB_STAGE_THIRD)
				for(var/mob/living/silicon/ai/aiPlayer in GLOB.player_list)
					if(aiPlayer.client)
						aiPlayer.laws.clear_zeroth_laws()
						SSticker?.score?.save_silicon_laws(aiPlayer, additional_info = "организм уничтожен, нулевой закон удален")
						to_chat(aiPlayer, span_warning("Законы обновлены"))

	special_directive(intercepttext, interceptname)
	GLOB.event_announcement.Announce("Отчёт был загружен и распечатан на всех консолях связи.", "Входящее засекреченное сообщение.", 'sound/AI/commandreport.ogg', from = "[command_name()] обновление")

/datum/station_state
	var/floor = 0
	var/wall = 0
	var/r_wall = 0
	var/window = 0
	var/door = 0
	var/grille = 0
	var/mach = 0


/datum/station_state/proc/count()
	for(var/turf/T in block(1,1,1, world.maxx,world.maxy,1))

		if(isfloorturf(T))
			if(!(T:burnt))
				src.floor += 12
			else
				src.floor += 1

		if(iswallturf(T))
			var/turf/simulated/wall/W = T
			if(W.intact)
				src.wall += 2
			else
				src.wall += 1

		if(isreinforcedwallturf(T))
			var/turf/simulated/wall/r_wall/R = T
			if(R.intact)
				src.r_wall += 2
			else
				src.r_wall += 1


		for(var/obj/O in T.contents)
			if(istype(O, /obj/structure/window))
				src.window += 1
			else if(istype(O, /obj/structure/grille))
				var/obj/structure/grille/GR = O
				if(!GR.broken)
					grille += 1
			else if(istype(O, /obj/machinery/door))
				src.door += 1
			else if(ismachinery(O))
				src.mach += 1

/datum/station_state/proc/score(var/datum/station_state/result)
	if(!result)	return 0
	var/output = 0
	output += (result.floor / max(floor,1))
	output += (result.r_wall/ max(r_wall,1))
	output += (result.wall / max(wall,1))
	output += (result.window / max(window,1))
	output += (result.door / max(door,1))
	output += (result.grille / max(grille,1))
	output += (result.mach / max(mach,1))
	return (output/7)
